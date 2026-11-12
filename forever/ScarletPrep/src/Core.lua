-- Scarlet Prep - Core
-- Reads the quest log and works out where you are in each Scarlet Monastery quest chain.
--
-- A step is "done" when the game reports the quest as completed, when you turned it in
-- while the addon was running, when you marked it done yourself, or when a later step of
-- the same chain is done or in your log.

local ADDON, ns = ...
local S = {}
ns.S = S
_G.ScarletPrep = S

local ACCENT_HEX = "ff4d4d"

function S:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff" .. ACCENT_HEX .. "Scarlet Prep:|r " .. msg)
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

function S:InitDB()
    ScarletPrepCharDB = ScarletPrepCharDB or {}
    local db = ScarletPrepCharDB
    db.done = db.done or {}           -- [goalKey][stepIndex] = true (turned in or marked)
    db.marked = db.marked or {}       -- [goalKey][stepIndex] = true (marked by hand)
    db.turnedIn = db.turnedIn or {}   -- [questID] = true
    db.checks = db.checks or {}       -- [checkKey] = true
    self.db = db
end

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------

S.knownIds = {}
for _, g in ipairs(ns.GOALS) do
    for _, st in ipairs(g.steps) do
        for _, id in ipairs(st.ids or {}) do S.knownIds[id] = true end
    end
end

local function Completed(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
    end
    if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) and true or false end
    return false
end

local function PlayerInfo()
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    return UnitLevel("player") or 1, race, class, UnitFactionGroup("player")
end

-- Every quest in the log, by ID and by title.
function S:ScanLog()
    local log = { byId = {}, byTitle = {} }
    local function add(id, title, complete, idx)
        if not id or id == 0 then return end
        local e = { id = id, title = title, complete = complete and true or false, idx = idx }
        log.byId[id] = e
        if title then
            log.byTitle[title] = log.byTitle[title] or {}
            table.insert(log.byTitle[title], e)
        end
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                add(info.questID, info.title, C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID), i)
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, (GetNumQuestLogEntries()) do
            local title, _, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
            if not isHeader then add(qid, title, isComplete == 1 or isComplete == true, i) end
        end
    end
    -- Quests under collapsed headers don't show up above; ask for the known IDs directly.
    if C_QuestLog and C_QuestLog.IsOnQuest then
        for id in pairs(self.knownIds) do
            if not log.byId[id] and C_QuestLog.IsOnQuest(id) then
                local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
                add(id, title, C_QuestLog.IsComplete and C_QuestLog.IsComplete(id), nil)
            end
        end
    end
    return log
end

-- Objective lines with progress for a quest in the log.
function S:Objectives(e)
    local out = {}
    if not e then return out end
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objs = C_QuestLog.GetQuestObjectives(e.id)
        if objs then
            for _, o in ipairs(objs) do
                if o.text and o.text ~= "" then out[#out + 1] = { text = o.text, done = o.finished } end
            end
            if #out > 0 then return out end
        end
    end
    if e.idx and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for o = 1, (GetNumQuestLeaderBoards(e.idx) or 0) do
            local text, _, finished = GetQuestLogLeaderBoard(o, e.idx)
            if text and text ~= "" then out[#out + 1] = { text = text, done = finished } end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Evaluation
---------------------------------------------------------------------------

-- Step states: done, turnin, active, available, low, locked, na
S.STATE_TEXT = {
    done = "Done", turnin = "Turn in", active = "In log", available = "Pick up",
    low = "Too low", locked = "Earlier step first", na = "Not for you",
}

function S:GoalApplies(g)
    local _, race, class, faction = PlayerInfo()
    if g.class and g.class ~= class then return false, "hidden" end
    if g.notRace and g.notRace[race] then return false, g.notRaceText or "Not available to your race." end
    return true
end

function S:EvaluateGoal(g, log, claimed)
    local level = PlayerInfo()
    local db = self.db
    local states = {}
    local applies, why = self:GoalApplies(g)

    for i, st in ipairs(g.steps) do
        local s = { step = st }
        for _, id in ipairs(st.ids or {}) do
            if log.byId[id] then s.entry = log.byId[id] break end
        end
        for _, id in ipairs(st.ids or {}) do
            if Completed(id) or db.turnedIn[id] then s.done = true end
        end
        if db.done[g.key] and db.done[g.key][i] then s.done = true end
        if s.entry then claimed[s.entry.id] = true end
        states[i] = s
    end

    local function Implicit()
        local last = 0
        for i, s in ipairs(states) do
            if s.done or s.entry then last = i end
        end
        for i = 1, last - 1 do
            if not states[i].entry then states[i].done = true end
        end
    end
    Implicit()

    -- Title fallback: a quest in the log with the right title but an unknown ID
    -- belongs to the first unfinished step with that title.
    for _, s in ipairs(states) do
        if not s.done and not s.entry then
            for _, e in ipairs(log.byTitle[s.step.title] or {}) do
                if not self.knownIds[e.id] and not claimed[e.id] then
                    s.entry, claimed[e.id] = e, true
                    break
                end
            end
            if s.entry then break end
        end
    end
    Implicit()

    local prevDone = true
    local cur
    for i, s in ipairs(states) do
        if s.done then
            s.state = "done"
        elseif s.entry then
            s.state = s.entry.complete and "turnin" or "active"
        elseif not applies then
            s.state = "na"
        elseif not prevDone then
            s.state = "locked"
        elseif level < (s.step.level or 1) then
            s.state = "low"
        else
            s.state = "available"
        end
        if s.entry then self.logStep[s.entry.id] = { g.key, i } end
        if not s.done and not cur then cur = i end
        prevDone = prevDone and s.done
    end

    local result = { goal = g, steps = states, cur = cur, applies = applies, why = why }
    if not applies then
        result.state = "na"
    elseif not cur then
        result.state = "done"
    else
        result.state = states[cur].state
    end
    -- Ready for the dungeon: the current step is the SM one and it's in your log.
    result.ready = cur and g.steps[cur].sm and states[cur].state == "active" or false
    return result
end

function S:Evaluate()
    local log = self:ScanLog()
    local claimed = {}
    self.logStep = {}
    local out = {}
    for _, g in ipairs(ns.GOALS) do
        local applies, why = self:GoalApplies(g)
        if why ~= "hidden" then
            out[#out + 1] = self:EvaluateGoal(g, log, claimed)
        end
    end
    self.results = out
    return out
end

function S:CheckDone(c)
    if c.item and GetItemCount then
        if (GetItemCount(c.item, true) or 0) > 0 then return true, true end
    end
    return self.db.checks[c.key] and true or false, false
end

-- Where to go next, grouped by place. Returns { {hub=..., lines={...}}, ... } in first-seen order.
function S:NextStops(results)
    local order, byHub = {}, {}
    local function add(hub, line)
        if not byHub[hub] then
            byHub[hub] = {}
            order[#order + 1] = hub
        end
        table.insert(byHub[hub], line)
    end
    for _, r in ipairs(results) do
        local s = r.cur and r.steps[r.cur]
        if s and r.applies then
            local st = s.step
            if s.state == "available" then
                -- Quests that start inside the dungeon are listed under "inside" instead.
                if not st.startsInside then
                    add(st.hub, ("Pick up |cffffd100%s|r from %s%s."):format(st.title, st.who, st.where and (", " .. st.where) or ""))
                end
            elseif s.state == "turnin" then
                add(st.toHub or st.hub, ("Turn in |cffffd100%s|r to %s."):format(st.title, st.to or st.who))
            elseif s.state == "active" and not st.sm then
                add(st.doHub or st.toHub or st.hub, ("Do |cffffd100%s|r: %s"):format(st.title, st.text))
            end
        end
    end
    local out = {}
    for _, hub in ipairs(order) do out[#out + 1] = { hub = hub, lines = byHub[hub] } end
    return out
end

---------------------------------------------------------------------------
-- Marking steps by hand
---------------------------------------------------------------------------

function S:MarkCurrent(key)
    for _, r in ipairs(self.results or {}) do
        if r.goal.key == key and r.cur then
            self.db.done[key] = self.db.done[key] or {}
            self.db.marked[key] = self.db.marked[key] or {}
            self.db.done[key][r.cur] = true
            self.db.marked[key][r.cur] = true
            return r.goal.steps[r.cur].title
        end
    end
end

function S:UnmarkGoal(key)
    local marked = self.db.marked[key]
    if not marked then return false end
    for i in pairs(marked) do
        if self.db.done[key] then self.db.done[key][i] = nil end
    end
    self.db.marked[key] = nil
    return true
end

function S:HasMarks(key)
    return self.db.marked[key] and next(self.db.marked[key]) ~= nil
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
S.frame = f
local pending = false

function S:Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        if not S.db then return end
        local old = {}
        for _, r in ipairs(S.results or {}) do old[r.goal.key] = r.state end
        local results = S:Evaluate()
        if S.ready then
            for _, r in ipairs(results) do
                local was = old[r.goal.key]
                local s = r.cur and r.steps[r.cur]
                if was and was ~= r.state and s then
                    if r.state == "turnin" then
                        S:Print("%s is complete. Turn it in to %s (%s).", s.step.title, s.step.to or s.step.who, s.step.toHub or s.step.hub)
                    elseif r.ready and was ~= "active" then
                        S:Print("%s is ready for Scarlet Monastery (%s).", r.goal.name, s.step.wing or "any wing")
                    end
                end
            end
        end
        S.ready = true
        if S.UpdateUI then S:UpdateUI() end
    end)
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then S:InitDB() end
    elseif event == "QUEST_TURNED_IN" then
        local id = ...
        if id then
            S.db.turnedIn[id] = true
            local ls = S.logStep and S.logStep[id]
            if ls then
                S.db.done[ls[1]] = S.db.done[ls[1]] or {}
                S.db.done[ls[1]][ls[2]] = true
            end
        end
        S:Refresh()
    else
        S:Refresh()
    end
end)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED",
                     "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED" }) do
    pcall(f.RegisterEvent, f, e)
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

function S:Report()
    local results = self:Evaluate()
    for _, r in ipairs(results) do
        local s = r.cur and r.steps[r.cur]
        local extra = ""
        if r.state == "na" then extra = r.why or ""
        elseif s then extra = ("%s: %s"):format(s.step.title, self.STATE_TEXT[s.state] or s.state) end
        self:Print("%s - %s%s", r.goal.name, r.ready and "|cff40ff40ready|r " or "", extra)
    end
end

SLASH_SCARLETPREP1 = "/scarletprep"
SLASH_SCARLETPREP2 = "/smprep"
SLASH_SCARLETPREP3 = "/smp"
SlashCmdList.SCARLETPREP = function(msg)
    if not S.db then return end
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "report" then
        S:Report()
    elseif msg == "reset" then
        for k in pairs(S.db.marked) do S:UnmarkGoal(k) end
        S:Print("Cleared the steps you marked by hand.")
        S:Refresh()
    elseif msg == "help" then
        S:Print("/smprep opens the checklist. /smprep report prints a summary. /smprep reset clears steps you marked by hand.")
    else
        if S.Toggle then S:Toggle() end
    end
end
