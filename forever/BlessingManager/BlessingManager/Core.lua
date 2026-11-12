-- Blessing Manager - Core
-- Assignment data, raid sync and buff scanning.
--
-- Design note (WoW: Forever / Midnight-style addon restrictions):
-- Every decision here (who is missing a blessing, who to cast on next) is made
-- OUT OF COMBAT, when aura and unit data are not secret. In combat the addon
-- simply freezes its last state and stops scanning. Nothing in this file
-- compares or branches on secret values; issecretvalue() guards bail out if
-- secret data shows up anyway.

local ADDON, ns = ...

local BM = CreateFrame("Frame")
ns.BM = BM
_G.BlessingManager = BM

local PREFIX = "BLESSMGR"
local issecret = issecretvalue or function() return false end

BINDING_HEADER_BLESSINGMANAGER = "Blessing Manager"
BINDING_NAME_BLESSINGMANAGER_TOGGLE = "Toggle window"
_G["BINDING_NAME_CLICK BlessingManagerCastButton:LeftButton"] = "Cast next blessing"

---------------------------------------------------------------------------
-- Static data
---------------------------------------------------------------------------

-- ids are the Classic Era spell IDs; they are only used to look up localized
-- names on non-English clients. English clients use the names as written.
BM.BLESSINGS = {
    MIGHT     = { letter = "M", short = "Might",  spell = "Blessing of Might",     id = 19740, greaterId = 25782 },
    WISDOM    = { letter = "W", short = "Wisdom", spell = "Blessing of Wisdom",    id = 19742, greaterId = 25894 },
    KINGS     = { letter = "K", short = "Kings",  spell = "Blessing of Kings",     id = 20217, greaterId = 25898 },
    SALVATION = { letter = "S", short = "Salv",   spell = "Blessing of Salvation", id = 1038,  greaterId = 25895 },
    LIGHT     = { letter = "L", short = "Light",  spell = "Blessing of Light",     id = 19977, greaterId = 25890 },
    SANCTUARY = { letter = "Y", short = "Sanc",   spell = "Blessing of Sanctuary", id = 20911, greaterId = 25899 },
}
BM.ORDER = { "MIGHT", "WISDOM", "KINGS", "SALVATION", "LIGHT", "SANCTUARY" }
BM.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- What we assume another paladin knows when they don't run the addon.
BM.DEFAULT_KNOWN = { MIGHT = true, WISDOM = true, KINGS = true, SALVATION = true, LIGHT = true }

-- Auto-assign priorities per class. Edit to taste once Forever's numbers settle.
BM.PRIORITY = {
    WARRIOR = { "MIGHT", "KINGS", "SALVATION", "LIGHT", "SANCTUARY" },
    ROGUE   = { "MIGHT", "KINGS", "SALVATION", "LIGHT" },
    HUNTER  = { "WISDOM", "KINGS", "SALVATION", "MIGHT", "LIGHT" },
    PALADIN = { "WISDOM", "KINGS", "SALVATION", "MIGHT", "LIGHT" },
    SHAMAN  = { "WISDOM", "KINGS", "SALVATION", "MIGHT", "LIGHT" },
    DRUID   = { "WISDOM", "KINGS", "SALVATION", "MIGHT", "LIGHT" },
    PRIEST  = { "WISDOM", "KINGS", "SALVATION", "LIGHT" },
    MAGE    = { "WISDOM", "KINGS", "SALVATION", "LIGHT" },
    WARLOCK = { "WISDOM", "KINGS", "SALVATION", "LIGHT" },
}

local DEFAULTS = {
    assignments = {},   -- [paladinFullName] = { rev = n, [CLASS] = BLESSINGKEY }
    known = {},         -- [paladinFullName] = { [BLESSINGKEY] = true }
    threshold = 300,    -- seconds left before a blessing counts as "needs rebuff"
    alerts = true,
    sound = true,
    showCast = true,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function BM:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cfff58cbaBlessing Manager:|r " .. msg)
end

local function Normalize(name)
    if name and not issecret(name) and not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName()
        if realm then name = name .. "-" .. realm end
    end
    return name
end

function BM:FullName(unit)
    local name, realm = UnitFullName(unit)
    if not name or issecret(name) then return nil end
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    return realm and (name .. "-" .. realm) or name
end

function BM:Short(name)
    return name and Ambiguate(name, "short") or "?"
end

function BM:ClassName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

function BM:LocalizeNames()
    local getName = C_Spell and C_Spell.GetSpellName
    local useIds = GetLocale() ~= "enUS" and GetLocale() ~= "enGB" and getName
    for _, b in pairs(self.BLESSINGS) do
        if useIds then
            local n = getName(b.id)
            if n and n ~= "" then b.spell = n end
            local g = getName(b.greaterId)
            if g and g ~= "" then b.greater = g end
        end
        b.greater = b.greater or ("Greater " .. b.spell)
    end
    self.BY_LETTER, self.BY_SPELL = {}, {}
    for key, b in pairs(self.BLESSINGS) do
        self.BY_LETTER[b.letter] = key
        self.BY_SPELL[b.spell] = key
        self.BY_SPELL[b.greater] = key
    end
end

-- Collect the names of every spell in the player's spellbook.
function BM:ScanSpellbook()
    local names = {}
    local SB = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemName and bank then
        for line = 1, SB.GetNumSpellBookSkillLines() do
            local info = SB.GetSpellBookSkillLineInfo(line)
            if info then
                local offset, count = info.itemIndexOffset or 0, info.numSpellBookItems or 0
                for slot = offset + 1, offset + count do
                    local ok, name = pcall(SB.GetSpellBookItemName, slot, bank)
                    if ok and name then names[name] = true end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then   -- older API
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for slot = offset + 1, offset + count do
                local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL or "spell")
                if name then names[name] = true end
            end
        end
    end
    self.spellbook = names
    self.spellbookSize = 0
    for _ in pairs(names) do self.spellbookSize = self.spellbookSize + 1 end
end

function BM:KnowsSpell(spellName)
    if not spellName then return false end
    if self.spellbook and self.spellbookSize > 0 then
        return self.spellbook[spellName] or false
    end
    -- Spellbook couldn't be read: fall back to a name lookup.
    return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellName) ~= nil or false
end

function BM:Knows(pal, key)
    local k = self.db.known[pal]
    if not k or next(k) == nil then return self.DEFAULT_KNOWN[key] or false end
    return k[key] or false
end

function BM:SpellFor(key)
    return self.BLESSINGS[key].spell
end

---------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------

function BM:RebuildRoster()
    if InCombatLockdown() then self.rosterDirty = true return end
    self.rosterDirty = false
    wipe(self.roster); wipe(self.paladins); wipe(self.unitByName)

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = self:FullName(unit)
            local _, class = UnitClass(unit)
            if name and class and not issecret(class) then
                self.roster[#self.roster + 1] = { unit = unit, name = name, class = class }
                self.unitByName[name] = unit
                if class == "PALADIN" then self.paladins[#self.paladins + 1] = name end
            end
        end
    end
    table.sort(self.paladins)
    self:RequestRefresh()
end

function BM:InGroup(name)
    return self.unitByName[name] ~= nil
end

-- In a party (or solo) anyone may edit any row. In a raid you may edit your
-- own row, and the leader/assists may edit every row.
function BM:IsOfficer(name)
    if not IsInRaid() then return true end
    local unit = self.unitByName[name]
    if not unit then return false end
    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit) or false
end

function BM:CanEdit(editor, pal)
    return editor == pal or self:IsOfficer(editor)
end

---------------------------------------------------------------------------
-- Assignments
---------------------------------------------------------------------------

function BM:Row(pal)
    local r = self.db.assignments[pal]
    if not r then
        r = { rev = 0 }
        self.db.assignments[pal] = r
    end
    return r
end

function BM:Get(pal, class)
    local r = self.db.assignments[pal]
    return r and r[class]
end

BM.ROLES = { "TANK", "HEALER", "DAMAGER" }
BM.ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
BM.ROLE_LETTER = { TANK = "T", HEALER = "H", DAMAGER = "D" }
BM.SKIP = "SKIP"   -- role override meaning "don't bless this role"

function BM:GetRole(pal, class, role)
    local r = self.db.assignments[pal]
    return r and r.roles and r.roles[class] and r.roles[class][role]
end

-- The blessing pal should give to a member of `class` with group role `role`.
-- A role override replaces the class default.
function BM:Effective(pal, class, role)
    local o = role and self:GetRole(pal, class, role)
    if o == self.SKIP then return nil end
    return o or self:Get(pal, class)
end

function BM:UnitRole(unit)
    if not UnitGroupRolesAssigned then return nil end
    local role = UnitGroupRolesAssigned(unit)
    if not role or issecret(role) or role == "NONE" or role == "" then return nil end
    return role
end

local function Bump(r)
    r.rev = math.max((r.rev or 0) + 1, GetServerTime())
end

function BM:Set(pal, class, key)
    if not self:CanEdit(self.me, pal) then
        self:Print("Only %s or a raid leader/assist can change that row.", self:Short(pal))
        return false
    end
    local r = self:Row(pal)
    r[class] = key
    Bump(r)
    self:SendRow(pal)
    self:RequestRefresh()
    return true
end

function BM:SetRole(pal, class, role, value)
    if not self:CanEdit(self.me, pal) then
        self:Print("Only %s or a raid leader/assist can change that row.", self:Short(pal))
        return false
    end
    local r = self:Row(pal)
    r.roles = r.roles or {}
    local t = r.roles[class] or {}
    t[role] = value
    r.roles[class] = next(t) and t or nil
    Bump(r)
    self:SendRow(pal)
    self:RequestRefresh()
    return true
end

function BM:ClearRoles(pal, class)
    if not self:CanEdit(self.me, pal) then return end
    local r = self:Row(pal)
    if r.roles then r.roles[class] = nil end
    Bump(r)
    self:SendRow(pal)
    self:RequestRefresh()
end

function BM:AutoAssign()
    if InCombatLockdown() then self:Print("Can't auto-assign in combat.") return end
    local pals = {}
    for _, p in ipairs(self.paladins) do
        if self:CanEdit(self.me, p) then pals[#pals + 1] = p end
    end
    if #pals == 0 then
        self:Print("There are no paladin rows you're allowed to assign.")
        return
    end

    local editable = {}
    for _, p in ipairs(pals) do
        editable[p] = true
        local r = self:Row(p)
        for _, class in ipairs(self.CLASSES) do r[class] = nil end
    end

    -- Paladins who know the fewest blessings get first pick, so the one with
    -- Sanctuary isn't spent on Kings when someone else could cover Kings.
    local function flexibility(p)
        local n = 0
        for _, k in ipairs(self.ORDER) do if self:Knows(p, k) then n = n + 1 end end
        return n
    end
    table.sort(pals, function(a, b)
        local fa, fb = flexibility(a), flexibility(b)
        if fa ~= fb then return fa < fb end
        return a < b
    end)

    for _, class in ipairs(self.CLASSES) do
        local taken, used = {}, {}
        -- Respect rows we can't edit.
        for _, p in ipairs(self.paladins) do
            if not editable[p] then
                local k = self:Get(p, class)
                if k then taken[k] = true end
            end
        end
        for _, key in ipairs(self.PRIORITY[class]) do
            if not taken[key] then
                for _, p in ipairs(pals) do
                    if not used[p] and self:Knows(p, key) then
                        self:Row(p)[class] = key
                        used[p], taken[key] = true, true
                        break
                    end
                end
            end
        end
    end

    for _, p in ipairs(pals) do
        Bump(self:Row(p))
        self:SendRow(p)
    end
    self:Print("Assigned blessings for %d paladin(s).", #pals)
    self:RequestRefresh()
end

function BM:ClearAll()
    for _, p in ipairs(self.paladins) do
        if self:CanEdit(self.me, p) then
            local r = self:Row(p)
            for _, class in ipairs(self.CLASSES) do r[class] = nil end
            r.roles = nil
            Bump(r)
            self:SendRow(p)
        end
    end
    self:RequestRefresh()
end

---------------------------------------------------------------------------
-- Comms
--   H:<letters>                 hello, with the blessings I know
--   Q                           please send me your hello + rows
--   A:<rev>:<paladin>:<9 chars> one assignment row, one letter per class
---------------------------------------------------------------------------

function BM:Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

function BM:Send(msg)
    local ch = self:Channel()
    if not ch then return end
    if InCombatLockdown() then
        self.outbox[#self.outbox + 1] = msg
        return
    end
    C_ChatInfo.SendAddonMessage(PREFIX, msg, ch)
end

function BM:FlushOutbox()
    local box = self.outbox
    self.outbox = {}
    for _, msg in ipairs(box) do self:Send(msg) end
end

function BM:KnownLetters(pal)
    local s = {}
    for _, key in ipairs(self.ORDER) do
        if self:Knows(pal, key) then s[#s + 1] = self.BLESSINGS[key].letter end
    end
    return table.concat(s)
end

function BM:SendHello()
    if not self.isPaladin then return end
    self:Send("H:" .. self:KnownLetters(self.me))
end

function BM:SendRow(pal)
    local r = self.db.assignments[pal] or {}
    local t = {}
    for i, class in ipairs(self.CLASSES) do
        local key = r[class]
        t[i] = key and self.BLESSINGS[key].letter or "-"
    end
    local rt = {}
    for _, class in ipairs(self.CLASSES) do
        for _, role in ipairs(self.ROLES) do
            local v = r.roles and r.roles[class] and r.roles[class][role]
            rt[#rt + 1] = (v == self.SKIP and "X") or (v and self.BLESSINGS[v].letter) or "-"
        end
    end
    self:Send(("A:%d:%s:%s:%s"):format(r.rev or 0, pal, table.concat(t), table.concat(rt)))
end

function BM:SendAll()
    for _, pal in ipairs(self.paladins) do
        if self.db.assignments[pal] and self:CanEdit(self.me, pal) then self:SendRow(pal) end
    end
end

function BM:Sync()
    if not IsInGroup() then self:Print("You're not in a group.") return end
    self:SendHello()
    self:SendAll()
    self:Send("Q")
    self:Print("Sync requested.")
end

function BM:CHAT_MSG_ADDON(prefix, msg, _, sender)
    if prefix ~= PREFIX or issecret(msg) or issecret(sender) then return end
    sender = Normalize(sender)
    if not sender or sender == self.me then return end

    local kind, a, b, c, d = strsplit(":", msg)
    if kind == "H" then
        local k = {}
        for i = 1, #(a or "") do
            local key = self.BY_LETTER[a:sub(i, i)]
            if key then k[key] = true end
        end
        self.db.known[sender] = k
        self.hasAddon[sender] = true
        self:RequestRefresh()
    elseif kind == "Q" then
        self:SendHello()
        self:SendAll()
    elseif kind == "A" then
        local rev, pal, letters = tonumber(a), b, c
        if not rev or not pal or not letters or #letters ~= #self.CLASSES then return end
        self.hasAddon[sender] = true
        if not self:CanEdit(sender, pal) then return end
        local r = self:Row(pal)
        if rev <= (r.rev or 0) then return end
        for i, class in ipairs(self.CLASSES) do
            r[class] = self.BY_LETTER[letters:sub(i, i)]
        end
        r.roles = nil
        if d and #d == #self.CLASSES * #self.ROLES then
            local i = 0
            for _, class in ipairs(self.CLASSES) do
                for _, role in ipairs(self.ROLES) do
                    i = i + 1
                    local ch = d:sub(i, i)
                    local v = (ch == "X" and self.SKIP) or self.BY_LETTER[ch]
                    if v then
                        r.roles = r.roles or {}
                        r.roles[class] = r.roles[class] or {}
                        r.roles[class][role] = v
                    end
                end
            end
        end
        r.rev = rev
        self:RequestRefresh()
    end
end

---------------------------------------------------------------------------
-- Scanning (out of combat only)
---------------------------------------------------------------------------

-- Returns { [BLESSINGKEY] = secondsLeft } or nil if data is secret.
function BM:ScanUnit(unit)
    local found = {}
    local now = GetTime()
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local name = aura.name
        if issecret(name) then return nil end
        local key = self.BY_SPELL[name]
        if key then
            local exp = aura.expirationTime
            local left = math.huge
            if exp and not issecret(exp) and exp > 0 then left = exp - now end
            found[key] = math.max(found[key] or 0, left)
        end
    end
    return found
end

function BM:InRange(unit)
    if UnitIsUnit(unit, "player") then return true end
    if not UnitIsVisible(unit) then return false end
    local inRange, checked = UnitInRange(unit)
    if issecret(inRange) or not checked then return true end
    return inRange
end

function BM:Evaluate()
    if InCombatLockdown() then return end
    local threshold = self.db.threshold
    local cells, mine, missingTotal = {}, {}, 0

    for _, m in ipairs(self.roster) do
        if UnitIsConnected(m.unit) and not UnitIsDeadOrGhost(m.unit) then
            local buffs = self:ScanUnit(m.unit)
            local role = self:UnitRole(m.unit)
            if buffs then
                for _, pal in ipairs(self.paladins) do
                    local key = self:Effective(pal, m.class, role)
                    if key then
                        cells[pal] = cells[pal] or {}
                        local c = cells[pal][m.class]
                        if not c then
                            c = { have = 0, total = 0, soon = 0, missing = {} }
                            cells[pal][m.class] = c
                        end
                        c.total = c.total + 1
                        local left = buffs[key]
                        if left then
                            c.have = c.have + 1
                            if left < threshold then c.soon = c.soon + 1 end
                        else
                            missingTotal = missingTotal + 1
                            c.missing[#c.missing + 1] = m.name
                        end
                        if pal == self.me and (not left or left < threshold) then
                            mine[#mine + 1] = { unit = m.unit, name = m.name, class = m.class, role = role, key = key, left = left or 0 }
                        end
                    end
                end
            end
        end
    end

    table.sort(mine, function(x, y) return x.left < y.left end)
    self.cells, self.mine, self.missingTotal = cells, mine, missingTotal

    self:MaybeAlert()
    if self.UI then
        self.UI:UpdateCast()
        self.UI:Refresh()
    end
end

function BM:PickTarget()
    for _, e in ipairs(self.mine or {}) do
        if self:InRange(e.unit) then return e end
    end
end

function BM:MaybeAlert()
    local n = #self.mine
    if not self.db.alerts or n == 0 or not self.isPaladin then
        self.lastCount = n
        return
    end
    if IsResting() and not IsInRaid() then self.lastCount = n return end
    local now = GetTime()
    local grew = n > (self.lastCount or 0)
    if (grew and now - (self.lastAlert or 0) > 15) or now - (self.lastAlert or 0) > 120 then
        self.lastAlert = now
        UIErrorsFrame:AddMessage(("Blessings: %d need your attention"):format(n), 1, 0.82, 0)
        if self.db.sound then PlaySound(SOUNDKIT.RAID_WARNING) end
    end
    self.lastCount = n
end

function BM:Summary()
    self:Evaluate()
    if (self.missingTotal or 0) == 0 then
        self:Print("All assigned blessings are up.")
        return
    end
    local parts = {}
    for _, pal in ipairs(self.paladins) do
        local n = 0
        for _, c in pairs(self.cells[pal] or {}) do n = n + #c.missing end
        if n > 0 then parts[#parts + 1] = ("%s (%d)"):format(self:Short(pal), n) end
    end
    self:Print("Missing blessings: %s", table.concat(parts, ", "))
end

function BM:Report()
    local ch = IsInRaid() and "RAID" or (IsInGroup() and "PARTY")
    if not ch then self:Print("You're not in a group.") return end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    for _, pal in ipairs(self.paladins) do
        local parts = {}
        for _, key in ipairs(self.ORDER) do
            local classes = {}
            for _, class in ipairs(self.CLASSES) do
                if self:Get(pal, class) == key then classes[#classes + 1] = self:ClassName(class) end
            end
            if #classes > 0 then
                parts[#parts + 1] = self.BLESSINGS[key].short .. ": " .. table.concat(classes, "/")
            end
        end
        if #parts > 0 then
            send(("[Blessings] %s - %s"):format(self:Short(pal), table.concat(parts, "; ")), ch)
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function BM:RequestRefresh()
    self.dirty = true
end

function BM:OnTick()
    if InCombatLockdown() then return end
    local now = GetTime()
    if self.dirty or now - (self.lastEval or 0) > 5 then
        self.dirty = false
        self.lastEval = now
        self:Evaluate()
    end
end

function BM:UpdateMyKnown()
    if not self.isPaladin then return end
    self:ScanSpellbook()
    local k = {}
    for key, b in pairs(self.BLESSINGS) do
        if self:KnowsSpell(b.spell) then k[key] = true end
    end
    self.db.known[self.me] = k
    local letters = self:KnownLetters(self.me)
    if letters ~= self.lastKnownLetters then
        self.lastKnownLetters = letters
        self:SendHello()
    end
end

function BM:PLAYER_LOGIN()
    BlessingManagerDB = BlessingManagerDB or {}
    self.db = BlessingManagerDB
    for k, v in pairs(DEFAULTS) do
        if self.db[k] == nil then self.db[k] = type(v) == "table" and {} or v end
    end

    self.me = self:FullName("player")
    self.isPaladin = select(2, UnitClass("player")) == "PALADIN"
    self.roster, self.paladins, self.unitByName = {}, {}, {}
    self.outbox, self.hasAddon, self.mine, self.cells = {}, {}, {}, {}
    self.missingTotal = 0

    self:LocalizeNames()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                         "UNIT_AURA", "CHAT_MSG_ADDON", "READY_CHECK", "SPELLS_CHANGED",
                         "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED" }) do
        pcall(self.RegisterEvent, self, e)
    end

    self:RebuildRoster()
    self:UpdateMyKnown()
    self.wasInGroup = IsInGroup()
    if ns.CreateUI then ns.CreateUI(self) end

    C_Timer.NewTicker(1, function() self:OnTick() end)
    if IsInGroup() then
        self:SendHello()
        self:Send("Q")
    end
end

function BM:GROUP_ROSTER_UPDATE()
    self:RebuildRoster()
    local inGroup = IsInGroup()
    if inGroup and not self.wasInGroup then
        self:SendHello()
        self:Send("Q")
    end
    self.wasInGroup = inGroup
end

BM.PARTY_LEADER_CHANGED = BM.GROUP_ROSTER_UPDATE

function BM:PLAYER_ROLES_ASSIGNED()
    self:RequestRefresh()
end

function BM:PLAYER_REGEN_ENABLED()
    if self.rosterDirty then self:RebuildRoster() end
    self:FlushOutbox()
    self:RequestRefresh()
end

function BM:PLAYER_REGEN_DISABLED()
    if self.UI then self.UI:Refresh() end
end

function BM:UNIT_AURA(unit)
    if unit == "player" or (unit and (unit:find("^raid%d") or unit:find("^party%d"))) then
        self.dirty = true
    end
end

function BM:READY_CHECK()
    if #self.paladins == 0 then return end
    if self.isPaladin or self:IsOfficer(self.me) then self:Summary() end
end

function BM:SPELLS_CHANGED()
    if self.db then self:UpdateMyKnown() end
end

BM:SetScript("OnEvent", function(self, event, ...)
    if self[event] then self[event](self, ...) end
end)
BM:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

function BM:Debug()
    self:UpdateMyKnown()
    self:RebuildRoster()
    self:Print("me=%s paladin=%s spellbook=%d spells", tostring(self.me), tostring(self.isPaladin), self.spellbookSize or -1)
    local known = {}
    for _, key in ipairs(self.ORDER) do
        local b = self.BLESSINGS[key]
        known[#known + 1] = ("%s:%s"):format(b.short, self:KnowsSpell(b.spell) and "Y" or "n")
    end
    self:Print("known: %s", table.concat(known, " "))
    local row = self.db.assignments[self.me]
    local a = {}
    for _, class in ipairs(self.CLASSES) do
        if row and row[class] then a[#a + 1] = class:sub(1, 3) .. "=" .. self.BLESSINGS[row[class]].short end
    end
    self:Print("my assignments: %s", #a > 0 and table.concat(a, ", ") or "|cffff6060none|r")
    for _, m in ipairs(self.roster) do
        local buffs = self:ScanUnit(m.unit)
        local seen, other = {}, {}
        if buffs then
            for key, left in pairs(buffs) do
                seen[#seen + 1] = self.BLESSINGS[key].short .. (left < math.huge and ("(" .. math.floor(left / 60) .. "m)") or "")
            end
            for i = 1, 40 do
                local aura = C_UnitAuras.GetAuraDataByIndex(m.unit, i, "HELPFUL")
                if not aura then break end
                if not issecret(aura.name) and aura.name:find("lessing") then other[#other + 1] = aura.name end
            end
        end
        self:Print("  %s (%s, role %s): matched [%s] raw [%s]", self:Short(m.name), m.class, self:UnitRole(m.unit) or "none",
            buffs and table.concat(seen, ", ") or "secret", table.concat(other, ", "))
    end
    self:Print("needs my blessing: %d", self.mine and #self.mine or 0)
end

SLASH_BLESSINGMANAGER1 = "/bm"
SLASH_BLESSINGMANAGER2 = "/blessings"
SlashCmdList.BLESSINGMANAGER = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "show" then
        BM.UI:Toggle()
    elseif cmd == "auto" then
        BM:AutoAssign()
    elseif cmd == "sync" then
        BM:Sync()
    elseif cmd == "clear" then
        BM:ClearAll()
    elseif cmd == "check" then
        BM:Summary()
    elseif cmd == "report" then
        BM:Report()
    elseif cmd == "alerts" then
        BM.db.alerts = not BM.db.alerts
        BM:Print("Alerts: %s", BM.db.alerts and "on" or "off")
    elseif cmd == "sound" then
        BM.db.sound = not BM.db.sound
        BM:Print("Alert sound: %s", BM.db.sound and "on" or "off")
    elseif cmd == "button" then
        if InCombatLockdown() then BM:Print("Not in combat.") return end
        BM.db.showCast = not BM.db.showCast
        BM.UI:UpdateCast()
    elseif cmd == "debug" then
        BM:Debug()
    elseif cmd == "threshold" and tonumber(arg) then
        BM.db.threshold = math.max(0, tonumber(arg) * 60)
        BM:Print("Rebuff warning at %d min left.", BM.db.threshold / 60)
        BM:RequestRefresh()
    else
        BM:Print("Commands: /bm [show | auto | sync | clear | check | report | alerts | sound | button | threshold <min>]")
    end
end
