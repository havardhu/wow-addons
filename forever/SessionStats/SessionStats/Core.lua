-- Session Stats - Core
-- Records XP, gold, kills, quests, loot, reputation, dungeon runs and zones for
-- a session you start yourself.
--
-- How sources are told apart (no combat log needed):
--   XP    PLAYER_XP_UPDATE gives the total. QUEST_TURNED_IN reports quest XP,
--         "X dies, you gain N experience" chat lines give kill XP, exploration
--         system messages give discovery XP. Whatever is left is "other".
--   Gold  PLAYER_MONEY gives every change. QUEST_TURNED_IN reports quest money,
--         loot money chat lines give looted coin, and the window you have open
--         (vendor, mail, flight master, trainer, AH, trade) labels the rest.
-- Chat-based events are matched within a short window, so arrival order
-- doesn't matter. Secret values (Midnight-style restrictions) are never
-- inspected; if a chat line arrives secret, the addon falls back to a
-- "XP right after combat = kill" heuristic.

local ADDON, ns = ...

local SS = CreateFrame("Frame")
ns.SS = SS
_G.SessionStats = SS

local issecret = issecretvalue or function() return false end
local floor, min, max, abs, ceil = math.floor, math.min, math.max, math.abs, math.ceil

local HISTORY_MAX = 30
local NOTABLE_MAX = 40
local FLUSH_DELAY = 0.6

local function Secret(...)
    for i = 1, select("#", ...) do
        if issecret((select(i, ...))) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Formatting helpers (shared with UI)
---------------------------------------------------------------------------

local function Commas(n)
    n = floor((n or 0) + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    local s = tostring(abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. s
end
SS.Commas = Commas

function SS.Short(n)
    n = n or 0
    if abs(n) >= 1e6 then return ("%.2fm"):format(n / 1e6) end
    if abs(n) >= 1e4 then return ("%.1fk"):format(n / 1e3) end
    return Commas(n)
end

function SS.Money(c, plain)
    c = floor((c or 0) + 0.5)
    local neg = c < 0
    c = abs(c)
    local g, s, cp = floor(c / 10000), floor(c / 100) % 100, c % 100
    local G, S, C = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
    if plain then G, S, C = "g", "s", "c" end
    local t = {}
    if g > 0 then t[#t + 1] = Commas(g) .. G end
    if g > 0 or s > 0 then t[#t + 1] = s .. S end
    t[#t + 1] = cp .. C
    return (neg and "-" or "") .. table.concat(t, " ")
end

function SS.Duration(sec)
    sec = floor(sec or 0)
    local h, m, s = floor(sec / 3600), floor(sec / 60) % 60, sec % 60
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    if m > 0 then return ("%dm %02ds"):format(m, s) end
    return ("%ds"):format(s)
end

function SS:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff66ccffSession Stats:|r " .. msg)
end

---------------------------------------------------------------------------
-- Chat patterns built from the client's own global strings
---------------------------------------------------------------------------

local function ToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("%%%d%$", "%%")                        -- %1$s -> %s
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")   -- escape magic chars
    fmt = fmt:gsub("%%s", "(.+)")
    fmt = fmt:gsub("%%d", "(%%d+)")
    return "^" .. fmt
end

local P = {}
SS.P = P

local function BuildPatterns()
    P.XP_KILL      = ToPattern(COMBATLOG_XPGAIN_FIRSTPERSON)   -- "%s dies, you gain %d experience."
    P.EXPLORE      = ToPattern(ERR_ZONE_EXPLORED_XP)           -- "Discovered %s: %d experience gained"
    P.LOOT_MULTI   = ToPattern(LOOT_ITEM_SELF_MULTIPLE)        -- "You receive loot: %sx%d."
    P.LOOT_SELF    = ToPattern(LOOT_ITEM_SELF)                 -- "You receive loot: %s."
    P.MONEY_SELF   = ToPattern(YOU_LOOT_MONEY)                 -- "You loot %s"
    P.MONEY_SPLIT  = ToPattern(LOOT_MONEY_SPLIT)               -- "Your share of the loot is %s."
    P.MONEY_GUILD  = ToPattern(YOU_LOOT_MONEY_GUILD)
    P.REP_UP       = ToPattern(FACTION_STANDING_INCREASED)     -- "Reputation with %s increased by %d."
    P.REP_DOWN     = ToPattern(FACTION_STANDING_DECREASED)
    P.SKILL        = ToPattern(SKILL_RANK_UP)                  -- "Your skill in %s has increased to %d."
    local function amt(s) return s and ("(%d+)%s*" .. s:gsub("%%d%s*", ""):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")) end
    P.GOLD   = amt(GOLD_AMOUNT)   or "(%d+)%s*Gold"
    P.SILVER = amt(SILVER_AMOUNT) or "(%d+)%s*Silver"
    P.COPPER = amt(COPPER_AMOUNT) or "(%d+)%s*Copper"
end

local function M(text, pattern)
    if not pattern or not text then return nil end
    return text:match(pattern)
end

function SS:ParseMoney(text)
    text = text:gsub("(%d)[,%.](%d%d%d)", "%1%2")
    local g = tonumber(text:match(P.GOLD) or text:match("(%d+)%s*|T[^|]*GoldIcon")) or 0
    local s = tonumber(text:match(P.SILVER) or text:match("(%d+)%s*|T[^|]*SilverIcon")) or 0
    local c = tonumber(text:match(P.COPPER) or text:match("(%d+)%s*|T[^|]*CopperIcon")) or 0
    return g * 10000 + s * 100 + c
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------

local function NewSession(name)
    return {
        name = name,
        char = UnitName("player"),
        startedAt = time(),
        active = 0,
        paused = false,
        startLevel = UnitLevel("player"),
        startXP = UnitXP("player"),
        startMoney = GetMoney(),
        xp = { total = 0, kill = 0, quest = 0, explore = 0, other = 0 },
        kills = 0, corpses = 0, deaths = 0, flights = 0,
        income = {}, expense = {},
        quests = { completed = 0, accepted = 0 },
        loot = { items = 0, value = 0, byQuality = {}, notable = {} },
        rep = {}, skills = {}, levels = {}, zones = {}, runs = {},
    }
end

-- The session that should record right now (nil when none or paused).
function SS:S()
    local s = self.db and self.db.current
    if s and not s.paused then return s end
end

function SS:Current()
    return self.db and self.db.current
end

function SS:StartSession(name)
    if self.db.current then self:EndSession(true) end
    if not name or name == "" then name = date("Session %b %d, %H:%M") end
    self.db.current = NewSession(name)
    self:ResetPending()
    self:CheckInstance()
    self:Print("Started |cffffffff%s|r.", name)
    self:Changed()
end

function SS:EndSession(quiet)
    local s = self.db.current
    if not s then return end
    self:Flush()
    self:EndRun(s)
    s.endedAt = time()
    s.endLevel = UnitLevel("player")
    s.endMoney = GetMoney()
    s.paused = false
    if s.active >= 60 then
        table.insert(self.db.history, 1, s)
        while #self.db.history > HISTORY_MAX do table.remove(self.db.history) end
    end
    self.db.current = nil
    if not quiet then self:Print("Ended |cffffffff%s|r after %s.", s.name, SS.Duration(s.active)) end
    self:Changed()
end

function SS:SetPaused(paused)
    local s = self.db.current
    if not s then return end
    if paused then self:Flush() end
    s.paused = paused and true or false
    self:Print(paused and "Session paused." or "Session resumed.")
    self:Changed()
end

function SS:Zone(s)
    local name = self.zoneName or "Unknown"
    local z = s.zones[name]
    if not z then
        z = { time = 0, xp = 0, kills = 0, quests = 0, gold = 0 }
        s.zones[name] = z
    end
    return z
end

function SS:UpdateZone()
    local n = GetRealZoneText and GetRealZoneText()
    if n and not issecret(n) and n ~= "" then self.zoneName = n end
end

function SS:Changed()
    if self.UI then self.UI:Refresh() end
end

---------------------------------------------------------------------------
-- Pending matcher
---------------------------------------------------------------------------

function SS:ResetPending()
    self.pend = {
        xp = 0, questXP = 0, killXP = 0, exploreXP = 0, secretKills = 0,
        deltas = {}, questMoney = 0, lootMoney = 0, repair = 0,
    }
end

function SS:ScheduleFlush()
    if self.flushTimer then return end
    self.flushTimer = C_Timer.NewTimer(FLUSH_DELAY, function()
        self.flushTimer = nil
        self:Flush()
    end)
end

function SS:RecentCombat()
    return InCombatLockdown() or (GetTime() - (self.lastCombatEnd or 0) < 3)
end

local INCOME_CTX = { LOOT = true, MERCHANT = true, MAIL = true, AUCTION = true, TRADE = true }
local EXPENSE_CTX = { MERCHANT = true, TAXI = true, TRAINER = true, MAIL = true, AUCTION = true, TRADE = true }

local function Add(t, k, v)
    if v and v > 0 then t[k] = (t[k] or 0) + v end
end

function SS:ApplyMoney(s, d, ctx)
    local p = self.pend
    local z = self:Zone(s)
    if d > 0 then
        local q = min(d, p.questMoney); p.questMoney = p.questMoney - q; d = d - q
        local l = min(d, p.lootMoney);  p.lootMoney  = p.lootMoney  - l; d = d - l
        Add(s.income, "QUEST", q)
        Add(s.income, "LOOT", l)
        z.gold = z.gold + q + l
        if d > 0 then
            local cat = (ctx == "QUESTUI" and "QUEST") or (INCOME_CTX[ctx] and ctx) or "OTHER"
            Add(s.income, cat, d)
            if cat == "LOOT" or cat == "QUEST" then z.gold = z.gold + d end
        end
    elseif d < 0 then
        d = -d
        local r = min(d, p.repair); p.repair = p.repair - r; d = d - r
        Add(s.expense, "REPAIR", r)
        if d > 0 then
            local cat = EXPENSE_CTX[ctx] and ctx or "OTHER"
            Add(s.expense, cat, d)
            if cat == "TAXI" then s.flights = s.flights + 1 end
        end
    end
end

function SS:Flush()
    if self.flushTimer then self.flushTimer:Cancel(); self.flushTimer = nil end
    local p = self.pend
    local s = self:S()
    if s then
        local d = p.xp
        if d > 0 then
            local z = self:Zone(s)
            s.xp.total = s.xp.total + d
            z.xp = z.xp + d
            local q = min(d, p.questXP);   d = d - q; s.xp.quest   = s.xp.quest + q
            local k = min(d, p.killXP);    d = d - k; s.xp.kill    = s.xp.kill + k
            local e = min(d, p.exploreXP); d = d - e; s.xp.explore = s.xp.explore + e
            if d > 0 then
                if p.secretKills > 0 or (not self.xpChatSeen and k == 0 and q == 0 and self:RecentCombat()) then
                    local n = max(p.secretKills, 1)
                    s.xp.kill = s.xp.kill + d
                    s.kills = s.kills + n
                    z.kills = z.kills + n
                else
                    s.xp.other = s.xp.other + d
                end
            end
        end
        for _, m in ipairs(p.deltas) do self:ApplyMoney(s, m[1], m[2]) end
    end
    self:ResetPending()
    self:Changed()
end

---------------------------------------------------------------------------
-- Window context (who's responsible for a money change)
---------------------------------------------------------------------------

function SS:OpenCtx(name) self.ctx = name end

function SS:CloseCtx(name)
    if self.ctx == name then self.ctx = nil end
    self.lastCtx, self.lastCtxUntil = name, GetTime() + 2
end

function SS:Context()
    if self.ctx then return self.ctx end
    if self.lastCtx and GetTime() < (self.lastCtxUntil or 0) then return self.lastCtx end
end

local CTX_EVENTS = {
    MERCHANT_SHOW = { true, "MERCHANT" },        MERCHANT_CLOSED = { false, "MERCHANT" },
    MAIL_SHOW = { true, "MAIL" },                MAIL_CLOSED = { false, "MAIL" },
    AUCTION_HOUSE_SHOW = { true, "AUCTION" },    AUCTION_HOUSE_CLOSED = { false, "AUCTION" },
    TRADE_SHOW = { true, "TRADE" },              TRADE_CLOSED = { false, "TRADE" },
    TAXIMAP_OPENED = { true, "TAXI" },           TAXIMAP_CLOSED = { false, "TAXI" },
    TRAINER_SHOW = { true, "TRAINER" },          TRAINER_CLOSED = { false, "TRAINER" },
    QUEST_COMPLETE = { true, "QUESTUI" },        QUEST_FINISHED = { false, "QUESTUI" },
}

---------------------------------------------------------------------------
-- Dungeon / raid runs
---------------------------------------------------------------------------

function SS:Snapshot(s)
    return {
        active = s.active, xp = s.xp.total, money = GetMoney(), kills = s.kills,
        items = s.loot.items, value = s.loot.value, deaths = s.deaths, quests = s.quests.completed,
    }
end

function SS:RunDelta(s, r)
    local now = self:Snapshot(s)
    local b = r.snap
    return {
        duration = now.active - b.active, xp = now.xp - b.xp, gold = now.money - b.money,
        kills = now.kills - b.kills, items = now.items - b.items, value = now.value - b.value,
        deaths = now.deaths - b.deaths, quests = now.quests - b.quests,
    }
end

function SS:EndRun(s)
    local r = s.activeRun
    if not r then return end
    for k, v in pairs(self:RunDelta(s, r)) do r[k] = v end
    r.endedAt = time()
    s.runs[#s.runs + 1] = r
    s.activeRun = nil
end

function SS:CheckInstance()
    local s = self.db and self.db.current
    if not s then return end
    local inInstance, itype = IsInInstance()
    local name, _, _, difficultyName = GetInstanceInfo()
    if Secret(inInstance, itype, name) then return end

    if inInstance and (itype == "party" or itype == "raid") then
        if s.activeRun and s.activeRun.name ~= name then self:EndRun(s) end
        if not s.activeRun then
            local last = s.runs[#s.runs]
            if last and last.name == name and last.endedAt and time() - last.endedAt < 900 then
                s.activeRun = table.remove(s.runs)      -- corpse run / quick hop out: resume
                s.activeRun.endedAt = nil
            else
                s.activeRun = {
                    name = name, difficulty = difficultyName, kind = itype,
                    startedAt = time(), snap = self:Snapshot(s),
                }
            end
        end
    elseif s.activeRun then
        self:EndRun(s)
    end
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

function SS:PLAYER_XP_UPDATE(unit)
    if unit and unit ~= "player" then return end
    local xp, maxXP, lvl = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if Secret(xp, maxXP, lvl) then return end
    local d
    if lvl > self.lastLevel then
        if self.wrapPending then d = xp - self.lastXP else d = (self.lastMax - self.lastXP) + xp end
        self.wrapPending = false
    elseif xp < self.lastXP then
        d = (self.lastMax - self.lastXP) + xp     -- level-up seen before UnitLevel updated
        self.wrapPending = true
    else
        d = xp - self.lastXP
    end
    self.lastXP, self.lastMax, self.lastLevel = xp, maxXP, lvl
    if d > 0 and self:S() then
        self.pend.xp = self.pend.xp + d
        self:ScheduleFlush()
    end
end

function SS:PLAYER_LEVEL_UP(level)
    local s = self:S()
    if not s then return end
    s.levels[#s.levels + 1] = { level = level, at = s.active, t = time() }
    self:Changed()
end

function SS:PLAYER_MONEY()
    local m = GetMoney()
    local d = m - (self.lastMoney or m)
    self.lastMoney = m
    if d ~= 0 and self:S() then
        table.insert(self.pend.deltas, { d, self:Context() })
        self:ScheduleFlush()
    end
end

function SS:QUEST_TURNED_IN(_, xpReward, moneyReward)
    local s = self:S()
    if not s then return end
    s.quests.completed = s.quests.completed + 1
    local z = self:Zone(s)
    z.quests = z.quests + 1
    if not Secret(xpReward, moneyReward) then
        self.pend.questXP = self.pend.questXP + (tonumber(xpReward) or 0)
        self.pend.questMoney = self.pend.questMoney + (tonumber(moneyReward) or 0)
    end
    self:ScheduleFlush()
end

function SS:QUEST_ACCEPTED()
    local s = self:S()
    if s then s.quests.accepted = s.quests.accepted + 1; self:Changed() end
end

function SS:PLAYER_DEAD()
    local s = self:S()
    if s then s.deaths = s.deaths + 1; self:Changed() end
end

function SS:CHAT_MSG_COMBAT_XP_GAIN(msg)
    local s = self:S()
    if not s then return end
    if issecret(msg) then
        self.pend.secretKills = self.pend.secretKills + 1
        self:ScheduleFlush()
        return
    end
    local mob, amount = M(msg, P.XP_KILL)
    if mob and amount then
        self.xpChatSeen = true
        self.pend.killXP = self.pend.killXP + tonumber(amount)
        s.kills = s.kills + 1
        local z = self:Zone(s)
        z.kills = z.kills + 1
        self:ScheduleFlush()
    end
end

function SS:CHAT_MSG_SYSTEM(msg)
    if issecret(msg) or not self:S() then return end
    local _, amount = M(msg, P.EXPLORE)
    if amount then
        self.pend.exploreXP = self.pend.exploreXP + tonumber(amount)
        self:ScheduleFlush()
    end
end

function SS:CHAT_MSG_MONEY(msg)
    if issecret(msg) or not self:S() then return end
    local part = M(msg, P.MONEY_SPLIT) or M(msg, P.MONEY_GUILD) or M(msg, P.MONEY_SELF)
    if not part then return end
    local c = self:ParseMoney(part)
    if c > 0 then
        self.pend.lootMoney = self.pend.lootMoney + c
        self:ScheduleFlush()
    end
end

local function QualityOf(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, _, quality, _, _, _, _, _, _, _, sellPrice = getInfo(link)
    return quality, sellPrice
end

function SS:RecordItem(s, link, count)
    s.loot.items = s.loot.items + count
    local zone = self.zoneName
    local function finish()
        local q, price = QualityOf(link)
        if not q then return end
        s.loot.byQuality[q] = (s.loot.byQuality[q] or 0) + count
        s.loot.value = s.loot.value + (price or 0) * count
        if q >= 3 then
            table.insert(s.loot.notable, 1, { link = link, count = count, zone = zone, t = time() })
            while #s.loot.notable > NOTABLE_MAX do table.remove(s.loot.notable) end
        end
        self:Changed()
    end
    if QualityOf(link) then
        finish()
    elseif Item and Item.CreateFromItemLink then
        Item:CreateFromItemLink(link):ContinueOnItemLoad(finish)
    end
end

function SS:CHAT_MSG_LOOT(msg)
    if issecret(msg) then return end
    local s = self:S()
    if not s then return end
    local link, n = M(msg, P.LOOT_MULTI)
    if not link then link, n = M(msg, P.LOOT_SELF), 1 end
    if not link then return end
    link = link:match("(|c.-|h|r)") or link:match("(|H.-|h.-|h)") or link
    self:RecordItem(s, link, tonumber(n) or 1)
    self:Changed()
end

function SS:CHAT_MSG_COMBAT_FACTION_CHANGE(msg)
    if issecret(msg) then return end
    local s = self:S()
    if not s then return end
    local faction, amount = M(msg, P.REP_UP)
    local sign = 1
    if not faction then faction, amount = M(msg, P.REP_DOWN); sign = -1 end
    if faction and amount then
        s.rep[faction] = (s.rep[faction] or 0) + sign * tonumber(amount)
        self:Changed()
    end
end

function SS:CHAT_MSG_SKILL(msg)
    if issecret(msg) then return end
    local s = self:S()
    if not s then return end
    local skill, rank = M(msg, P.SKILL)
    if skill then
        local t = s.skills[skill] or { gained = 0 }
        t.gained, t.rank = t.gained + 1, tonumber(rank)
        s.skills[skill] = t
        self:Changed()
    end
end

function SS:LOOT_OPENED()
    self:OpenCtx("LOOT")
    local s = self:S()
    if not s or not GetLootSourceInfo then return end
    for slot = 1, GetNumLootItems() do
        local src = { GetLootSourceInfo(slot) }
        for i = 1, #src, 2 do
            local guid = src[i]
            if guid and not issecret(guid) and guid:find("^Creature") and not self.seenCorpses[guid] then
                self.seenCorpses[guid] = true
                self.seenCount = self.seenCount + 1
                s.corpses = s.corpses + 1
            end
        end
    end
    if self.seenCount > 1000 then self.seenCorpses, self.seenCount = {}, 0 end
end

function SS:LOOT_CLOSED() self:CloseCtx("LOOT") end

function SS:PLAYER_REGEN_DISABLED() end
function SS:PLAYER_REGEN_ENABLED() self.lastCombatEnd = GetTime() end

function SS:ZONE_CHANGED_NEW_AREA()
    self:UpdateZone()
    self:CheckInstance()
    self:Changed()
end
SS.PLAYER_ENTERING_WORLD = SS.ZONE_CHANGED_NEW_AREA

function SS:OnTick()
    local s = self:S()
    if s then
        s.active = s.active + 1
        local z = self:Zone(s)
        z.time = z.time + 1
    end
    if self.UI then self.UI:Tick() end
end

function SS:PLAYER_LOGIN()
    SessionStatsCharDB = SessionStatsCharDB or {}
    self.db = SessionStatsCharDB
    self.db.history = self.db.history or {}
    self.db.settings = self.db.settings or { mini = true }

    BuildPatterns()
    self:ResetPending()
    self.seenCorpses, self.seenCount = {}, 0
    self.lastXP, self.lastMax, self.lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    self.lastMoney = GetMoney()
    self:UpdateZone()

    local events = {
        "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
        "PLAYER_DEAD", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "CHAT_MSG_LOOT",
        "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SKILL", "LOOT_OPENED", "LOOT_CLOSED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    }
    for e in pairs(CTX_EVENTS) do events[#events + 1] = e end
    for _, e in ipairs(events) do pcall(self.RegisterEvent, self, e) end   -- skip events this client lacks

    if RepairAllItems then
        hooksecurefunc("RepairAllItems", function(guildBank)
            if guildBank or not GetRepairAllCost then return end
            local cost = GetRepairAllCost()
            if cost and not issecret(cost) and cost > 0 then self.pend.repair = self.pend.repair + cost end
        end)
    end

    if ns.CreateUI then ns.CreateUI() end
    C_Timer.NewTicker(1, function() self:OnTick() end)

    local s = self.db.current
    if s then
        self:Print("Continuing |cffffffff%s|r (%s so far)%s. /ss to open.", s.name, SS.Duration(s.active),
            s.paused and " - |cffff8080paused|r" or "")
    end
end

SS:SetScript("OnEvent", function(self, event, ...)
    local ctx = CTX_EVENTS[event]
    if ctx then
        if ctx[1] then self:OpenCtx(ctx[2]) else self:CloseCtx(ctx[2]) end
        return
    end
    if self[event] then self[event](self, ...) end
end)
SS:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Derived numbers (used by the UI and reports)
---------------------------------------------------------------------------

function SS:Derive(s, live)
    local d = {}
    d.hrs = max(s.active, 1) / 3600
    d.level = live and UnitLevel("player") or (s.endLevel or s.startLevel)
    d.money = live and GetMoney() or (s.endMoney or s.startMoney)
    d.net = d.money - s.startMoney
    d.xph = s.xp.total / d.hrs
    d.income, d.expenses = 0, 0
    for _, v in pairs(s.income) do d.income = d.income + v end
    for _, v in pairs(s.expense) do d.expenses = d.expenses + v end
    d.earned = (s.income.LOOT or 0) + (s.income.QUEST or 0)
    d.avgKill = s.kills > 0 and s.xp.kill / s.kills or nil
    d.avgQuestXP = s.quests.completed > 0 and s.xp.quest / s.quests.completed or nil
    d.avgQuestGold = s.quests.completed > 0 and (s.income.QUEST or 0) / s.quests.completed or nil
    d.maxLevel = GetMaxPlayerLevel and d.level >= GetMaxPlayerLevel()

    if live and not d.maxLevel then
        local xp, maxXP = UnitXP("player"), UnitXPMax("player")
        if not Secret(xp, maxXP) and maxXP and maxXP > 0 then
            d.curXP, d.maxXP, d.toLevel = xp, maxXP, maxXP - xp
            d.rested = GetXPExhaustion and GetXPExhaustion()
            if d.xph > 0 then d.ttl = d.toLevel / d.xph * 3600 end
            if d.avgKill and d.avgKill > 0 then d.killsToLevel = ceil(d.toLevel / d.avgKill) end
            if d.avgQuestXP and d.avgQuestXP > 0 then d.questsToLevel = ceil(d.toLevel / d.avgQuestXP) end
        end
    end
    return d
end

function SS:ReportLine(s, live)
    local d = self:Derive(s, live)
    local parts = { ("%s: %s"):format(s.name, SS.Duration(s.active)) }
    if s.xp.total > 0 then
        parts[#parts + 1] = ("%s XP (%s/hr)"):format(SS.Short(s.xp.total), SS.Short(d.xph))
    end
    parts[#parts + 1] = ("%d kills"):format(s.kills)
    parts[#parts + 1] = ("%d quests"):format(s.quests.completed)
    parts[#parts + 1] = ("%s net"):format(SS.Money(d.net, true))
    return table.concat(parts, " | ")
end

function SS:Report(channel)
    local s = self:Current()
    if not s then self:Print("No session running. /ss new to start one.") return end
    local line = self:ReportLine(s, true)
    channel = channel and channel:upper()
    if channel == "PARTY" or channel == "RAID" or channel == "GUILD" or channel == "INSTANCE_CHAT" then
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        send("[Session] " .. line, channel)
    else
        self:Print(line)
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_SESSIONSTATS1 = "/ss"
SLASH_SESSIONSTATS2 = "/sessionstats"
SlashCmdList.SESSIONSTATS = function(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "show" then
        SS.UI:Toggle()
    elseif cmd == "new" or cmd == "start" then
        SS:StartSession(arg)
    elseif cmd == "end" or cmd == "stop" then
        SS:EndSession()
    elseif cmd == "pause" then
        SS:SetPaused(true)
    elseif cmd == "resume" then
        SS:SetPaused(false)
    elseif cmd == "mini" then
        SS.db.settings.mini = not SS.db.settings.mini
        SS:Changed()
    elseif cmd == "report" then
        SS:Report(arg ~= "" and arg or nil)
    else
        SS:Print("/ss [show | new <name> | pause | resume | end | mini | report [party|raid|guild]]")
    end
end
