-- Scarlet Prep - UI
-- Checklist window: overview, before-you-go checklist and one page per quest chain.

local ADDON, ns = ...
local S = ns.S

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 1, 0.3, 0.3 }

local ICON = {
    done      = "Interface\\RaidFrame\\ReadyCheck-Ready",
    turnin    = "Interface\\GossipFrame\\ActiveQuestIcon",
    active    = "Interface\\RaidFrame\\ReadyCheck-Waiting",
    available = "Interface\\GossipFrame\\AvailableQuestIcon",
    low       = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    locked    = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    na        = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}
local COLOR = {
    done = "ff40ff40", turnin = "ffffd100", active = "ff7fd4ff", available = "ffffd100",
    low = "ff9d9d9d", locked = "ff9d9d9d", na = "ff9d9d9d",
}

local function Icon(state, size)
    return ("|T%s:%d|t"):format(ICON[state] or ICON.locked, size or 14)
end

local function C(hex, text) return ("|c%s%s|r"):format(hex, text) end
local GOLD, GREY, WHITE_T, GREEN = "ffffd100", "ff9d9d9d", "ffffffff", "ff40ff40"

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local W
local selected = "overview"

local function Build()
    W = CreateFrame("Frame", "ScarletPrepFrame", UIParent, "BackdropTemplate")
    W:SetSize(680, 480)
    W:SetPoint("CENTER")
    W:SetFrameStrata("DIALOG")
    W:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    W:SetBackdropColor(0.06, 0.04, 0.04, 0.96)
    W:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    W:EnableMouse(true)
    W:SetMovable(true)
    W:SetClampedToScreen(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving)
    W:SetScript("OnDragStop", W.StopMovingOrSizing)
    W:Hide()
    tinsert(UISpecialFrames, "ScarletPrepFrame")
    W:SetScript("OnShow", function() S:Refresh() end)

    local title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetText("Scarlet Prep: Scarlet Monastery (Horde)")
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    local close = CreateFrame("Button", nil, W, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    W.summary = W:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    W.summary:SetPoint("TOPLEFT", 14, -36)
    W.summary:SetPoint("RIGHT", -14, 0)
    W.summary:SetJustifyH("LEFT")

    -- Left: page list
    local list = CreateFrame("Frame", nil, W, "BackdropTemplate")
    list:SetPoint("TOPLEFT", 12, -56)
    list:SetSize(206, 380)
    list:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    list:SetBackdropColor(0, 0, 0, 0.45)
    list:SetBackdropBorderColor(0.35, 0.2, 0.2, 1)
    W.list = list
    W.rows = {}

    -- Right: page content
    local sf = CreateFrame("ScrollFrame", nil, W, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 230, -60)
    sf:SetSize(410, 372)
    local bg = CreateFrame("Frame", nil, W, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", sf, "TOPLEFT", -6, 4)
    bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 28, -4)
    bg:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    bg:SetBackdropColor(0, 0, 0, 0.45)
    bg:SetBackdropBorderColor(0.35, 0.2, 0.2, 1)
    bg:SetFrameLevel(math.max(sf:GetFrameLevel() - 1, 0))
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(400, 10)
    sf:SetScrollChild(content)
    W.scroll, W.content = sf, content

    W.heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    W.heading:SetPoint("TOPLEFT", 2, -2)
    W.heading:SetWidth(396)
    W.heading:SetJustifyH("LEFT")

    W.checks = {}
    W.body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    W.body:SetWidth(396)
    W.body:SetJustifyH("LEFT")
    W.body:SetJustifyV("TOP")
    W.body:SetSpacing(2)

    -- Bottom buttons
    local mark = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
    mark:SetSize(150, 22)
    mark:SetPoint("BOTTOMLEFT", 230, 12)
    mark:SetText("Mark step done")
    mark:SetScript("OnClick", function()
        local t = S:MarkCurrent(selected)
        if t then S:Print("Marked %s as done.", t) end
        S:Refresh()
    end)
    mark:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Mark step done")
        GameTooltip:AddLine("For steps you did before installing the addon, or that the game doesn't report.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mark:SetScript("OnLeave", GameTooltip_Hide)
    W.mark = mark

    local undo = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
    undo:SetSize(130, 22)
    undo:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    undo:SetText("Undo my marks")
    undo:SetScript("OnClick", function()
        S:UnmarkGoal(selected)
        S:Refresh()
    end)
    W.undo = undo

    local hint = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 17)
    hint:SetText("/smprep report  ·  /smprep reset")
end

local function Row(i)
    local r = W.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, W.list)
    r:SetSize(198, 22)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 23)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 4, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        selected = self.key
        W.scroll:SetVerticalScroll(0)
        S:UpdateUI()
    end)
    W.rows[i] = r
    return r
end

local function Check(i)
    local cb = W.checks[i]
    if cb then return cb end
    cb = CreateFrame("CheckButton", nil, W.content, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetWidth(360)
    cb.label:SetJustifyH("LEFT")
    cb.note = cb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cb.note:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -2)
    cb.note:SetWidth(360)
    cb.note:SetJustifyH("LEFT")
    cb:SetScript("OnClick", function(self)
        if self.auto then self:SetChecked(true) return end
        S.db.checks[self.key] = self:GetChecked() and true or nil
        S:UpdateUI()
    end)
    W.checks[i] = cb
    return cb
end

---------------------------------------------------------------------------
-- Page text
---------------------------------------------------------------------------

local function StepLine(i, s, isCur)
    local st = s.step
    local lines = {}
    local name = C(isCur and GOLD or WHITE_T, ("%d. %s"):format(i, st.title))
    if s.state == "done" then name = C(GREY, ("%d. %s"):format(i, st.title)) end
    local status = C(COLOR[s.state] or GREY, S.STATE_TEXT[s.state] or s.state)
    if s.state == "low" then status = C(GREY, ("Level %d"):format(st.level or 1)) end
    lines[#lines + 1] = ("%s %s  %s%s"):format(Icon(s.state), name, status,
        st.sm and C("ffff6060", "  [Scarlet Monastery]") or "")
    if s.state ~= "done" then
        local from = st.who .. (st.where and (", " .. st.where) or "") .. (st.hub and (" - " .. st.hub) or "")
        lines[#lines + 1] = "      " .. C(GREY, "From: ") .. from
        if st.to then
            lines[#lines + 1] = "      " .. C(GREY, "Turn in: ") .. st.to .. " - " .. (st.toHub or st.hub)
        end
        if st.wing then lines[#lines + 1] = "      " .. C(GREY, "Wing: ") .. st.wing end
        if isCur or s.entry then
            lines[#lines + 1] = "      " .. st.text
        end
        if s.entry then
            for _, o in ipairs(S:Objectives(s.entry)) do
                lines[#lines + 1] = "      " .. C(o.done and GREEN or "ffffffff", "- " .. o.text)
            end
        end
    end
    return table.concat(lines, "\n")
end

local function GoalPage(r)
    local g = r.goal
    local out = {}
    out[#out + 1] = C(GREY, g.summary)
    out[#out + 1] = ""
    if r.state == "na" then
        out[#out + 1] = C("ffff6060", r.why or "Not available to you.")
        out[#out + 1] = ""
    elseif r.state == "done" then
        out[#out + 1] = C(GREEN, "All done.")
        out[#out + 1] = ""
    elseif r.ready then
        out[#out + 1] = C(GREEN, "Ready: this quest is in your log. Finish it inside Scarlet Monastery.")
        out[#out + 1] = ""
    end
    for i, s in ipairs(r.steps) do
        out[#out + 1] = StepLine(i, s, i == r.cur)
        out[#out + 1] = ""
    end
    out[#out + 1] = C(GOLD, "Rewards: ") .. (g.rewards or "-")
    out[#out + 1] = C(GOLD, "Shareable: ") .. (g.share and "yes" or "no")
    return table.concat(out, "\n")
end

local function OverviewPage(results)
    local out = {}
    local level = UnitLevel("player")

    -- Inside the dungeon
    local inside, other = {}, {}
    for _, r in ipairs(results) do
        local s = r.cur and r.steps[r.cur]
        if r.ready then
            inside[#inside + 1] = r
        elseif s and s.state == "available" and s.step.startsInside then
            other[#other + 1] = ("%s Pick up %s from %s (%s)."):format(Icon("available"), C(GOLD, s.step.title), s.step.who, s.step.where)
        end
    end
    out[#out + 1] = C(GOLD, "To do inside Scarlet Monastery")
    if #inside == 0 and #other == 0 then
        out[#out + 1] = C(GREY, "Nothing yet. Pick up the quests below first.")
    end
    for _, r in ipairs(inside) do
        local s = r.steps[r.cur]
        out[#out + 1] = ("%s %s  %s"):format(Icon("active"), C(WHITE_T, s.step.title), C(GREY, "(" .. (s.step.wing or "") .. ")"))
        for _, o in ipairs(S:Objectives(s.entry)) do
            out[#out + 1] = "      " .. C(o.done and GREEN or "ffffffff", "- " .. o.text)
        end
    end
    for _, line in ipairs(other) do out[#out + 1] = line end
    out[#out + 1] = ""

    -- Where to go
    out[#out + 1] = C(GOLD, "Next stops")
    local stops = S:NextStops(results)
    if #stops == 0 then out[#out + 1] = C(GREY, "Nothing to pick up or turn in right now.") end
    for _, stop in ipairs(stops) do
        out[#out + 1] = C(WHITE_T, stop.hub)
        for _, line in ipairs(stop.lines) do out[#out + 1] = "   " .. line end
    end
    out[#out + 1] = ""

    -- Later
    local later = {}
    for _, r in ipairs(results) do
        local s = r.cur and r.steps[r.cur]
        if s and s.state == "low" then
            later[#later + 1] = ("%s %s: %s at level %d"):format(Icon("low"), r.goal.name, s.step.title, s.step.level)
        end
    end
    if #later > 0 then
        out[#out + 1] = C(GOLD, "Later") .. C(GREY, (" (you are level %d)"):format(level))
        for _, l in ipairs(later) do out[#out + 1] = l end
        out[#out + 1] = ""
    end

    out[#out + 1] = C(GOLD, "Wings")
    for _, w in ipairs(ns.WINGS) do
        out[#out + 1] = ("%s %s  %s"):format(C(WHITE_T, w.name), C(GREY, "level " .. w.levels), w.note)
    end
    out[#out + 1] = C(GREY, "Every quest book is in the Library, so one Library run covers most of the list.")
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function S:UpdateUI()
    if not (W and W:IsShown()) then return end
    local results = self.results or self:Evaluate()

    -- Summary line
    local level, faction = UnitLevel("player"), UnitFactionGroup("player")
    local ready, total = 0, 0
    for _, r in ipairs(results) do
        if r.applies then
            total = total + 1
            if r.ready or r.state == "done" then ready = ready + 1 end
        end
    end
    local key = false
    for _, c in ipairs(ns.CHECKS) do
        if c.item then key = self:CheckDone(c) end
    end
    local summary = ("Level %d  ·  Ready or done: %s  ·  Scarlet Key: %s"):format(
        level, C(ready == total and GREEN or GOLD, ("%d of %d"):format(ready, total)),
        key and C(GREEN, "yes") or C(GREY, "no"))
    if faction ~= "Horde" then summary = summary .. C("ffff6060", "  ·  These are Horde quests") end
    W.summary:SetText(summary)

    -- Page list
    local pages = {
        { key = "overview", text = "Overview", state = ready == total and "done" or "available" },
        { key = "checklist", text = "Before you go" },
    }
    for _, r in ipairs(results) do
        local label = r.goal.name
        local st = r.ready and "active" or r.state
        if r.ready then label = label .. C(GREEN, "  ready") end
        pages[#pages + 1] = { key = r.goal.key, text = label, state = st, result = r }
    end
    local doneChecks, nChecks = 0, #ns.CHECKS
    for _, c in ipairs(ns.CHECKS) do if self:CheckDone(c) then doneChecks = doneChecks + 1 end end
    pages[2].state = doneChecks == nChecks and "done" or "active"
    pages[2].text = ("Before you go (%d/%d)"):format(doneChecks, nChecks)

    local found = false
    for i, p in ipairs(pages) do
        local row = Row(i)
        row.key = p.key
        row.text:SetText(p.text)
        row.icon:SetTexture(ICON[p.state] or ICON.available)
        row.bg:SetShown(p.key == selected)
        local dim = p.result and (p.result.state == "na" or p.result.state == "locked" or p.result.state == "low")
        row.text:SetTextColor(dim and 0.6 or 1, dim and 0.6 or 1, dim and 0.6 or 1)
        row:Show()
        if p.key == selected then found = p end
    end
    for i = #pages + 1, #W.rows do W.rows[i]:Hide() end
    if not found then selected, found = "overview", pages[1] end

    -- Page content
    for _, cb in ipairs(W.checks) do cb:Hide() end
    local top = 30
    local text
    if selected == "overview" then
        W.heading:SetText("Overview")
        text = OverviewPage(results)
    elseif selected == "checklist" then
        W.heading:SetText("Before you go")
        local y = -30
        for i, c in ipairs(ns.CHECKS) do
            local cb = Check(i)
            local done, auto = self:CheckDone(c)
            cb.key, cb.auto = c.key, auto
            cb:SetChecked(done)
            cb.label:SetText(c.name .. (c.item and C(GREY, auto and "  (in your bags)" or "  (checked automatically)") or ""))
            cb.note:SetText(c.text)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", 0, y)
            cb:Show()
            y = y - 22 - cb.note:GetStringHeight() - 10
        end
        top = -y + 6
        local lines = { C(GOLD, "Quests to have in your log before you go") }
        for _, r in ipairs(results) do
            if r.applies then
                local s = r.cur and r.steps[r.cur]
                local note
                if r.state == "done" then note = C(GREEN, "done")
                elseif r.ready then note = C(GREEN, "in your log")
                elseif s then note = C(COLOR[s.state] or GREY, ("%s: %s"):format(s.step.title, S.STATE_TEXT[s.state] or s.state)) end
                lines[#lines + 1] = ("%s %s  %s"):format(Icon(r.ready and "done" or r.state), r.goal.name, note or "")
            end
        end
        text = table.concat(lines, "\n")
    else
        W.heading:SetText(found.result.goal.name)
        text = GoalPage(found.result)
    end
    W.body:ClearAllPoints()
    W.body:SetPoint("TOPLEFT", 2, -top)
    W.body:SetText(text)
    W.content:SetHeight(top + W.body:GetStringHeight() + 10)

    local isGoal = found.result ~= nil
    W.mark:SetShown(isGoal)
    W.undo:SetShown(isGoal)
    if isGoal then
        W.mark:SetEnabled(found.result.cur ~= nil and found.result.applies)
        W.undo:SetEnabled(self:HasMarks(selected) and true or false)
    end
end

function S:Toggle()
    if not W then Build() end
    if W:IsShown() then W:Hide() else W:Show() end
end

---------------------------------------------------------------------------
-- Button on the quest log
---------------------------------------------------------------------------

local function AddQuestLogButton()
    local parent = QuestLogFrame or QuestMapFrame or WorldMapFrame
    if not parent or S.qlButton then return end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(96, 20)
    b:SetText("Scarlet Prep")
    if QuestLogFrame and parent == QuestLogFrame then
        b:SetPoint("TOPRIGHT", QuestLogFrame, "TOPRIGHT", -150, -14)
    else
        b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -30)
    end
    b:SetScript("OnClick", function() S:Toggle() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Scarlet Prep")
        GameTooltip:AddLine("Your Scarlet Monastery quest checklist. Shift-drag to move this button.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    b:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    S.qlButton = b
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() pcall(AddQuestLogButton) end)
