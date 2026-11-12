-- Ask AI - Data
-- Gathers quest + character context and renders prompt templates.
-- Addons can't reach the internet, so the result is shown in a box for you to copy
-- into ChatGPT, Claude or any other assistant.

local ADDON, ns = ...
local A = {}
ns.A = A
_G.AskAI = A

BINDING_HEADER_ASKAI = "Ask AI"
BINDING_NAME_ASKAI_OPEN = "Open Ask AI for the selected quest"
BINDING_NAME_ASKAI_EDIT = "Open the prompt editor"

local issecret = issecretvalue or function() return false end

function A:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff7fd4ffAsk AI:|r " .. msg)
end

---------------------------------------------------------------------------
-- Built-in templates
---------------------------------------------------------------------------

A.PLACEHOLDERS = {
    { "context",     "Full quest + character block (recommended)" },
    { "quest",       "Quest title" },
    { "questID",     "Quest ID" },
    { "questLevel",  "Quest level" },
    { "questZone",   "Quest log zone/category" },
    { "status",      "In progress / ready to turn in / not accepted" },
    { "objectives",  "Objective list with progress" },
    { "description", "Quest text" },
    { "class",       "Your class" },
    { "race",        "Your race" },
    { "faction",     "Alliance / Horde" },
    { "playerLevel", "Your level" },
    { "zone",        "Where you are now (zone - subzone)" },
    { "position",    "Your map coordinates, if available" },
    { "wowhead",     "Wowhead link for the quest" },
    { "question",    "What you type in the question box" },
    { "game",        "One-line description of WoW: Forever" },
}

local GAME = "World of Warcraft: Forever (Blizzard's 2026 \"Classic+\" version of vanilla WoW: level cap 60, " ..
             "original Azeroth plus new zones, quests and class changes, so many quests differ from original Classic)"

A.BUILTIN = {
    {
        id = "help",
        name = "How do I do this?",
        body = [[I'm playing {game}.

{context}

How do I complete this quest? Be specific: where to go (with coordinates if you know them), which NPCs or mobs, and anything tricky. If this quest is new in Forever and you're not sure, say so instead of guessing. If you can browse, check Wowhead's WoW Forever database: {wowhead}

{question}]],
    },
    {
        id = "chain",
        name = "Quest chain",
        body = [[I'm playing {game}.

{context}

Tell me about the quest chain this quest belongs to:
1. The name of the chain/storyline and where it starts.
2. Every step in order, marking which one I'm on now.
3. Prerequisites or level requirements for the next steps.
4. Where and from whom I pick up the next quest after this one.
5. The final reward, and whether it's worth it for a level {playerLevel} {class}.
6. Any step that's easy to miss or that needs a group.

If parts of the chain are new in Forever and you don't know them, say which parts you're unsure of. If you can browse, start from: {wowhead}

{question}]],
    },
    {
        id = "route",
        name = "Where to go / what to do",
        body = [[I'm playing {game}.

{context}

Give me a step-by-step plan from where I am right now ({zone}{position}):
1. Where to go first, with coordinates and landmarks.
2. Which objectives to do in what order for the shortest route.
3. Exactly which NPCs to talk to and which mobs to kill or items to loot, and where they are.
4. Dangers for a level {playerLevel} {class} (elites, patrols, high-level areas) and how to handle them.
5. Other quests nearby I could do on the same trip.
6. Where to turn it in, and the nearest flight path or inn afterwards.

Keep it short and practical, like a leveling guide. Say so if you're unsure about Forever-specific details.

{question}]],
    },
}

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

local function CopyTemplate(t)
    return { id = t.id, name = t.name, body = t.body, builtin = t.builtin }
end

function A:InitDB()
    AskAIDB = AskAIDB or {}
    self.db = AskAIDB
    if not self.db.templates then
        self.db.templates = {}
        for _, t in ipairs(self.BUILTIN) do
            local c = CopyTemplate(t)
            c.builtin = t.id
            table.insert(self.db.templates, c)
        end
    end
    self.db.buttons = self.db.buttons or {}
    self.db.last = self.db.last or "help"
end

function A:GetTemplate(id)
    for _, t in ipairs(self.db.templates) do
        if t.id == id then return t end
    end
end

local function NewId()
    return ("custom%d%03d"):format(time(), math.random(0, 999))
end

function A:NewTemplate(from)
    local t = {
        id = NewId(),
        name = from and (from.name .. " (copy)") or "New prompt",
        body = from and from.body or "I'm playing {game}.\n\n{context}\n\n{question}",
    }
    table.insert(self.db.templates, t)
    return t
end

function A:DeleteTemplate(id)
    for i, t in ipairs(self.db.templates) do
        if t.id == id then
            table.remove(self.db.templates, i)
            return true
        end
    end
end

function A:MoveTemplate(id, dir)
    local list = self.db.templates
    for i, t in ipairs(list) do
        if t.id == id then
            local j = i + dir
            if j >= 1 and j <= #list then list[i], list[j] = list[j], list[i] end
            return
        end
    end
end

-- Resets a built-in to its shipped text; re-adds any built-in that was deleted.
function A:RestoreBuiltin(id)
    for _, b in ipairs(self.BUILTIN) do
        if not id or b.id == id then
            local t = self:GetTemplate(b.id)
            if t then
                t.name, t.body = b.name, b.body
            else
                local c = CopyTemplate(b)
                c.builtin = b.id
                table.insert(self.db.templates, c)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Gathering context
---------------------------------------------------------------------------

local function Clean(s)
    if not s or issecret(s) then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("%$[Bb]", "\n"):gsub("%$[Nn]", "adventurer")
    s = s:gsub("%$[Cc]", UnitClass("player") or "class"):gsub("%$[Rr]", UnitRace("player") or "race")
    return (s:gsub("\n\n\n+", "\n\n"))
end

-- Which quest is the player looking at? `source` hints where the click came from.
function A:CurrentQuestID(source)
    if source == "npc" and GetQuestID then
        local id = GetQuestID()
        if id and id > 0 then return id, "npc" end
    end
    if source and type(source) == "table" and source.questID and source.questID > 0 then
        return source.questID
    end
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local id = C_QuestLog.GetSelectedQuest()
        if id and id > 0 then return id end
    end
    if GetQuestLogSelection and GetQuestLogTitle then
        local idx = GetQuestLogSelection()
        if idx and idx > 0 then
            local id = select(8, GetQuestLogTitle(idx))
            if id and id > 0 then return id end
        end
    end
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = C_SuperTrack.GetSuperTrackedQuestID()
        if id and id > 0 then return id end
    end
    if QuestFrame and QuestFrame:IsShown() and GetQuestID then
        local id = GetQuestID()
        if id and id > 0 then return id, "npc" end
    end
end

local function GatherModern(q, id)
    local idx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    if not idx then return false end
    local info = C_QuestLog.GetInfo(idx)
    if info then
        q.title, q.level, q.group = info.title, info.level, info.suggestedGroup
    end
    for i = idx, 1, -1 do
        local h = C_QuestLog.GetInfo(i)
        if h and h.isHeader then q.header = h.title break end
    end
    q.complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
    local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
    if objs then
        for _, o in ipairs(objs) do
            q.objectives[#q.objectives + 1] = { text = o.text, done = o.finished }
        end
    end
    -- Quest text needs the quest selected; restore the old selection afterwards.
    if C_QuestLog.SetSelectedQuest and GetQuestLogQuestText then
        local prev = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(id)
        q.description, q.objectivesText = GetQuestLogQuestText()
        if prev and prev ~= id and prev > 0 then C_QuestLog.SetSelectedQuest(prev) end
    end
    q.inLog = true
    return true
end

local function GatherClassic(q, id)
    if not (GetNumQuestLogEntries and GetQuestLogTitle) then return false end
    local header
    for i = 1, GetNumQuestLogEntries() do
        local title, level, group, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
        if isHeader then
            header = title
        elseif qid == id then
            q.title, q.level, q.group, q.header = title, level, group, header
            q.complete = isComplete == 1 or isComplete == true
            local prev = GetQuestLogSelection and GetQuestLogSelection()
            if SelectQuestLogEntry then SelectQuestLogEntry(i) end
            q.description, q.objectivesText = GetQuestLogQuestText()
            if GetNumQuestLeaderBoards then
                for o = 1, GetNumQuestLeaderBoards(i) do
                    local text, _, finished = GetQuestLogLeaderBoard(o, i)
                    q.objectives[#q.objectives + 1] = { text = text, done = finished }
                end
            end
            if prev and prev > 0 and SelectQuestLogEntry then SelectQuestLogEntry(prev) end
            q.inLog = true
            return true
        end
    end
    return false
end

-- Quest offered by an NPC (not accepted yet).
local function GatherNPC(q)
    if not (QuestFrame and QuestFrame:IsShown()) then return false end
    q.title = GetTitleText and GetTitleText()
    q.description = GetQuestText and GetQuestText()
    q.objectivesText = GetObjectiveText and GetObjectiveText()
    q.offered = true
    return q.title ~= nil
end

function A:GatherQuest(id, origin)
    if not id then return nil end
    local q = { id = id, objectives = {} }
    local ok = false
    if origin ~= "npc" then
        if C_QuestLog and C_QuestLog.GetInfo then ok = GatherModern(q, id) end
        if not ok then ok = GatherClassic(q, id) end
    end
    if not ok then ok = GatherNPC(q) end
    if not ok and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        q.title = C_QuestLog.GetTitleForQuestID(id)
        ok = q.title ~= nil
    end
    return ok and q or nil
end

function A:Position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return "" end
    local ok, text = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        if not map then return "" end
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return "" end
        local x, y = pos:GetXY()
        if issecret(x) or not x or (x == 0 and y == 0) then return "" end
        return (" at %.1f, %.1f"):format(x * 100, y * 100)
    end)
    return ok and text or ""
end

function A:Vars(q, question)
    local v = {}
    local className = UnitClass("player")
    local raceName = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local zone, sub = GetRealZoneText() or "", GetSubZoneText() or ""
    v.game = GAME
    v.class, v.race, v.faction = className or "?", raceName or "?", faction or "?"
    v.playerLevel = tostring(UnitLevel("player"))
    v.zone = (sub ~= "" and sub ~= zone) and (zone .. " - " .. sub) or zone
    v.position = self:Position()
    v.question = (question and question ~= "") and ("My question: " .. question) or ""

    if q then
        v.quest = Clean(q.title) ~= "" and Clean(q.title) or "Unknown quest"
        v.questID = tostring(q.id)
        v.questLevel = q.level and tostring(q.level) or "?"
        if q.group and q.group > 1 then v.questLevel = v.questLevel .. (" (suggested group: %d)"):format(q.group) end
        v.questZone = Clean(q.header) ~= "" and Clean(q.header) or "?"
        v.status = q.offered and "Offered by an NPC, not accepted yet"
            or (q.complete and "Objectives done, ready to turn in" or "In progress")
        local lines = {}
        for _, o in ipairs(q.objectives) do
            lines[#lines + 1] = ("- %s%s"):format(Clean(o.text), o.done and " (done)" or "")
        end
        if #lines == 0 and q.objectivesText and q.objectivesText ~= "" then lines[1] = "- " .. Clean(q.objectivesText) end
        v.objectives = #lines > 0 and table.concat(lines, "\n") or "- (none listed)"
        v.description = Clean(q.description) ~= "" and Clean(q.description) or "(no quest text available)"
        v.wowhead = ("https://www.wowhead.com/forever/quest=%d"):format(q.id)
        v.context = table.concat({
            ("Quest: %s (ID %s, quest level %s)"):format(v.quest, v.questID, v.questLevel),
            "Quest log zone: " .. v.questZone,
            "Status: " .. v.status,
            "Objectives:\n" .. v.objectives,
            "Quest text:\n" .. v.description,
            "",
            ("Me: level %s %s %s (%s), currently in %s%s."):format(v.playerLevel, v.race, v.class, v.faction, v.zone, v.position),
        }, "\n")
    else
        v.quest, v.questID, v.questLevel, v.questZone = "(no quest selected)", "?", "?", "?"
        v.status, v.objectives, v.description = "-", "-", "-"
        v.wowhead = "https://www.wowhead.com/forever"
        v.context = ("Me: level %s %s %s (%s), currently in %s%s. (No specific quest selected.)"):format(
            v.playerLevel, v.race, v.class, v.faction, v.zone, v.position)
    end
    return v
end

function A:Render(template, q, question)
    local v = self:Vars(q, question)
    local body = template.body or ""
    if question and question ~= "" and not body:find("{question}", 1, true) then
        body = body .. "\n\n{question}"
    end
    local out = body:gsub("{(%w+)}", function(k)
        local val = v[k]
        if val == nil then return "{" .. k .. "}" end
        return tostring(val)       -- function replacements are inserted literally
    end)
    out = out:gsub("\n\n\n+", "\n\n"):gsub("%s+$", "")
    return out, v
end
