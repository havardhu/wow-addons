-- Taming Info - Beast journal
-- Records which skills individual beasts know, and which skills you already know how to teach.
--
-- Where beast skills come from (best source wins):
--   lore  Beast Lore results in the beast's tooltip (hunters, level 24+)
--   pet   Your newly tamed pet's spellbook
--   seen  The beast using the ability in front of you (when the game doesn't hide it)
-- Where your known skills come from:
--   "You have learned a new spell/ability: X (Rank N)" messages, and opening Beast Training.
-- The journal is account-wide, so data from your hunter shows on every character.

local ADDON, ns = ...
local D = ns.D
local T = _G.TamingInfo

local issecret = issecretvalue or function() return false end

-- Every ability name we care about, lower-case -> canonical.
local ABILITIES = {}
for name in pairs(D.SHARED) do ABILITIES[name:lower()] = name end
for _, f in pairs(D.FAMILIES) do ABILITIES[f.special.name:lower()] = f.special.name end
T.ABILITIES = ABILITIES

local SOURCE_RANK = { seen = 1, pet = 2, lore = 3 }
local SOURCE_TEXT = { seen = "seen in combat", pet = "from your tamed pet", lore = "from Beast Lore" }

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName() or "")
end

local function StripLinks(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("[%[%]]", "")
    return s
end

-- "Bite (Rank 3)" / "Bite" -> "Bite", 3
local function SplitRank(text)
    local name, rank = text:match("^(.-)%s*%(%s*[Rr]ank%s*(%d+)%s*%)%s*$")
    if name then return name, tonumber(rank) end
    return text:match("^%s*(.-)%s*$"), nil
end

local function ToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("%%%d%$", "%%")
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%s", "(.+)")
    fmt = fmt:gsub("%%d", "(%%d+)")
    return "^" .. fmt
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------

function T:InitJournal()
    local db = self.db
    db.beasts = db.beasts or {}     -- [key] = { name, family, minLevel, maxLevel, zone, speed, abilities = {[ability]=rank}, sources = {[ability]=src}, updated }
    db.names = db.names or {}       -- [name] = key
    db.chars = db.chars or {}       -- [charKey] = { known = {[ability]=rank} }
    self.char = db.chars[CharKey()] or { known = {} }
    db.chars[CharKey()] = self.char
    self.learnPatterns = { ToPattern(ERR_LEARN_SPELL_S), ToPattern(ERR_LEARN_ABILITY_S),
                           ToPattern(ERR_LEARN_RECIPE_S) }
end

function T:BeastKey(unit)
    local guid = UnitGUID(unit)
    if guid and not issecret(guid) then
        local kind, _, _, _, _, npcID = strsplit("-", guid)
        if (kind == "Creature" or kind == "Vehicle") and npcID then return "npc:" .. npcID end
    end
    local name = UnitName(unit)
    if name and not issecret(name) then
        return self.db.names[name] or ("name:" .. name)
    end
end

function T:LookupBeast(unit)
    local key = self:BeastKey(unit)
    local b = key and self.db.beasts[key]
    if b then return b end
    local name = UnitName(unit)
    if name and not issecret(name) and self.db.names[name] then
        return self.db.beasts[self.db.names[name]]
    end
end

function T:Record(unit, found, source, keyOverride)
    if not next(found) then return end
    local name = UnitName(unit)
    if not name or issecret(name) then return end
    local key = keyOverride or self:BeastKey(unit)
    if not key then return end
    local b = self.db.beasts[key]
    if not b then
        b = { abilities = {}, sources = {} }
        self.db.beasts[key] = b
    end
    b.name = name
    local family = UnitCreatureFamily(unit)
    if family and not issecret(family) then b.family = family end
    local level = UnitLevel(unit)
    if level and not issecret(level) and level > 0 and unit ~= "pet" then
        b.minLevel = math.min(b.minLevel or level, level)
        b.maxLevel = math.max(b.maxLevel or level, level)
    end
    if unit ~= "pet" then
        local zone = GetRealZoneText()
        if zone and zone ~= "" then b.zone = zone end
    end
    local changed = false
    for ability, rank in pairs(found) do
        local oldSrc = b.sources[ability]
        local better = not oldSrc or SOURCE_RANK[source] >= SOURCE_RANK[oldSrc]
        local oldRank = b.abilities[ability]
        if oldRank == nil or (rank or 0) > oldRank or (better and (rank or 0) >= oldRank) then
            b.abilities[ability] = math.max(rank or 0, oldRank or 0)
            if better then b.sources[ability] = source end
            changed = true
        end
    end
    b.updated = time()
    self.db.names[name] = key
    if changed then self:OnJournalChanged() end
end

function T:OnJournalChanged()
    self:UpdateButton()
    self:Refresh()
end

---------------------------------------------------------------------------
-- Source 1: Beast Lore results in tooltips
---------------------------------------------------------------------------

function T:ParseLines(lines)
    local found = {}
    local inAbilities = false
    for i, line in ipairs(lines) do
        local text = line.leftText
        if i > 1 and text and not issecret(text) then
            local low = StripLinks(text):lower()
            if low:find("abilit", 1, true) or low:find("rank", 1, true) or low:find("skill", 1, true) then
                inAbilities = true
            end
            if inAbilities then
                for lname, canon in pairs(ABILITIES) do
                    local s, e = low:find(lname, 1, true)
                    while s do
                        local after = low:sub(e + 1)
                        local r = after:match("^%s*%(?%s*rank%s*(%d+)") or after:match("^%s+(%d+)")
                        found[canon] = math.max(found[canon] or 0, tonumber(r) or 0)
                        s, e = low:find(lname, e + 1, true)
                    end
                end
            end
        end
    end
    return found
end

function T:ScanTooltipData(unit, data)
    if not data or not data.lines or UnitIsPlayer(unit) then return end
    local family = UnitCreatureFamily(unit)
    if not family or issecret(family) or not D.FAMILIES[family] then return end
    local found = self:ParseLines(data.lines)
    if next(found) then self:Record(unit, found, "lore") end
end

function T:ScanTargetTooltip()
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) or not UnitExists("target") then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, "target")
    if ok and data then self:ScanTooltipData("target", data) end
end

---------------------------------------------------------------------------
-- Source 2: a freshly tamed pet's spellbook
---------------------------------------------------------------------------

function T:ScanPet()
    if not UnitExists("pet") or not self:IsHunter() then return end
    local SB = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    local found = {}
    if SB and SB.HasPetSpells and SB.GetSpellBookItemName and bank then
        local n = SB.HasPetSpells() or 0
        for i = 1, n do
            local ok, name, sub = pcall(SB.GetSpellBookItemName, i, bank)
            if ok and name and ABILITIES[name:lower()] then
                local rank = sub and tonumber(sub:match("%d+"))
                local canon = ABILITIES[name:lower()]
                found[canon] = math.max(found[canon] or 0, rank or 0)
            end
        end
    elseif HasPetSpells and GetSpellBookItemName then
        local n = HasPetSpells() or 0
        for i = 1, n do
            local name, sub = GetSpellBookItemName(i, BOOKTYPE_PET or "pet")
            if name and ABILITIES[name:lower()] then
                local canon = ABILITIES[name:lower()]
                found[canon] = math.max(found[canon] or 0, (sub and tonumber(sub:match("%d+"))) or 0)
            end
        end
    end
    if not next(found) then return end
    -- A pet keeps its creature name until renamed; file it under the wild beast's entry.
    local name = UnitName("pet")
    if not name or issecret(name) then return end
    local key = self.db.names[name] or ("name:" .. name)
    self:Record("pet", found, "pet", key)
end

---------------------------------------------------------------------------
-- Source 3: beasts using abilities in front of you
---------------------------------------------------------------------------

function T:OnUnitCast(unit, spellID)
    if not unit or not spellID or issecret(spellID) or issecret(unit) then return end
    if unit == "player" then
        local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        if name == "Beast Lore" then C_Timer.After(0.3, function() T:ScanTargetTooltip() end) end
        return
    end
    if not (unit == "target" or unit == "focus" or unit == "mouseover" or unit:find("^nameplate")) then return end
    if UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
    local family = UnitCreatureFamily(unit)
    if not family or issecret(family) or not D.FAMILIES[family] then return end
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name or issecret(name) then return end
    local canon = ABILITIES[name:lower()]
    if not canon then return end
    local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    local rank = sub and not issecret(sub) and tonumber(sub:match("%d+")) or 0
    self:Record(unit, { [canon] = rank }, "seen")
end

---------------------------------------------------------------------------
-- What you already know how to teach
---------------------------------------------------------------------------

function T:Known()
    return self.char and self.char.known or {}
end

function T:SetKnown(ability, rank)
    local k = self:Known()
    if rank == false then k[ability] = nil return end
    k[ability] = math.max(k[ability] or 0, rank or 1)
end

function T:OnSystemMessage(msg)
    if not msg or issecret(msg) then return end
    for _, p in ipairs(self.learnPatterns) do
        local what = p and msg:match(p)
        if what then
            local name, rank = SplitRank(StripLinks(what))
            local canon = name and ABILITIES[name:lower()]
            if canon then
                self:SetKnown(canon, rank or 1)
                self:OnJournalChanged()
            end
            return
        end
    end
end

-- Beast Training uses the craft window in classic-style clients.
function T:ScanBeastTraining()
    if not (GetNumCrafts and GetCraftInfo) then return end
    local any = false
    for i = 1, GetNumCrafts() do
        local name, sub = GetCraftInfo(i)
        local canon = name and ABILITIES[name:lower()]
        if canon then
            self:SetKnown(canon, (sub and tonumber(sub:match("%d+"))) or 1)
            any = true
        end
    end
    if any then self:OnJournalChanged() end
end

---------------------------------------------------------------------------
-- Status of one beast skill for you
---------------------------------------------------------------------------

-- Returns label, colour hex
function T:SkillStatus(ability, rank)
    local known = self:Known()[ability]
    if known == nil then return "NEW", "33ff55" end
    if rank and rank > 0 and rank > known then return ("rank up (you: %d)"):format(known), "ffd100" end
    if not rank or rank == 0 then return "known", "9d9d9d" end
    return "known", "9d9d9d"
end

-- Sorted list of { ability, rank, label, color } for a journal entry, family ability first.
function T:SkillList(b)
    local list = {}
    if not b then return list end
    local special = b.family and D.FAMILIES[b.family] and D.FAMILIES[b.family].special.name
    for ability, rank in pairs(b.abilities) do
        local label, color = self:SkillStatus(ability, rank)
        list[#list + 1] = { ability = ability, rank = rank, label = label, color = color,
                            special = ability == special, source = b.sources[ability] }
    end
    table.sort(list, function(a, c)
        if a.special ~= c.special then return a.special end
        return a.ability < c.ability
    end)
    return list
end

function T:SourceText(src) return SOURCE_TEXT[src] or "" end

-- "Could know" hints from family + level when nothing is recorded.
function T:CouldKnow(family, level)
    local f = D.FAMILIES[family]
    if not f or not level or level < 1 then return {} end
    local out = {}
    local function best(ranks)
        local b
        for i, r in ipairs(ranks) do if r[1] <= level then b = i end end
        return b
    end
    local s = best(f.special.ranks)
    if s then out[#out + 1] = { ability = f.special.name, rank = s, special = true } end
    for _, ab in ipairs(f.secondary) do
        local sh = D.SHARED[ab]
        if sh and sh.ranks then
            local r = best(sh.ranks)
            if r then out[#out + 1] = { ability = ab, rank = r } end
        elseif sh then
            out[#out + 1] = { ability = ab }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Journal page for the panel
---------------------------------------------------------------------------

function T:JournalEntries()
    local byFamily = {}
    for _, b in pairs(self.db.beasts) do
        if b.family and b.abilities and next(b.abilities) then
            byFamily[b.family] = byFamily[b.family] or {}
            table.insert(byFamily[b.family], b)
        end
    end
    return byFamily
end
