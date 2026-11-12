-- Session Stats - UI
-- Main window (Overview / Dungeons / Zones / History) and a small live tracker.

local ADDON, ns = ...
local SS = ns.SS
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

local W, H = 400, 520
local LINE_H = 16
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 0.4, 0.8, 1 }

local Money, Dur, Short, Commas

local INCOME_LABELS = {
    { "LOOT", "Looted coin" }, { "QUEST", "Quest rewards" }, { "MERCHANT", "Vendor sales" },
    { "MAIL", "Mail" }, { "AUCTION", "Auction house" }, { "TRADE", "Trades" }, { "OTHER", "Other" },
}
local EXPENSE_LABELS = {
    { "MERCHANT", "Vendor purchases" }, { "REPAIR", "Repairs" }, { "TAXI", "Flights" },
    { "TRAINER", "Training" }, { "MAIL", "Mail / postage" }, { "AUCTION", "Auction house" },
    { "TRADE", "Trades" }, { "OTHER", "Other" },
}

local function QColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex end
    if C_Item and C_Item.GetItemQualityColor then
        local _, _, _, hex = C_Item.GetItemQualityColor(q)
        if hex then return "|c" .. hex end
    end
    return "|cffffffff"
end

local function QName(q)
    return _G["ITEM_QUALITY" .. q .. "_DESC"] or ("Quality " .. q)
end

local function Pct(part, total)
    if not total or total <= 0 then return "" end
    return (" |cff9d9d9d(%d%%)|r"):format(floor(part / total * 100 + 0.5))
end

---------------------------------------------------------------------------
-- Line builder
---------------------------------------------------------------------------

local L
local function Header(text) L[#L + 1] = { header = true, left = text } end
local function Line(left, right, opts)
    L[#L + 1] = { left = left, right = right, onClick = opts and opts.onClick, link = opts and opts.link }
end
local function Gap() L[#L + 1] = { gap = true } end

---------------------------------------------------------------------------
-- Tab content
---------------------------------------------------------------------------

local function BuildOverview(s, live)
    local d = SS:Derive(s, live)

    Header(s.name .. (live and "" or "  |cff9d9d9d(archived)|r"))
    Line("Started", date("%Y-%m-%d %H:%M", s.startedAt))
    Line("Active time", Dur(s.active) .. (s.paused and "  |cffff8080paused|r" or ""))
    local lv = d.level - s.startLevel
    Line("Level", ("%d -> %d"):format(s.startLevel, d.level) .. (lv > 0 and ("  |cff33ff33+%d|r"):format(lv) or ""))
    if #s.levels > 0 then
        Line("Avg time per level", Dur(s.active / #s.levels))
    end
    Gap()

    Header("Experience")
    if d.maxLevel and s.xp.total == 0 then
        Line("Max level", "-")
    else
        local t = s.xp.total
        local function XPLine(label, v, showPct)
            Line(label, ("%s  |cff9d9d9d%s/hr|r%s"):format(Commas(v), Short(v / d.hrs), showPct and Pct(v, t) or ""))
        end
        XPLine("From kills", s.xp.kill, true)
        XPLine("From quests", s.xp.quest, true)
        XPLine("|cffffffffTotal|r", t)
        local rest = s.xp.explore + s.xp.other
        if rest > 0 then
            Line("|cff9d9d9d  (total includes exploration/other)|r", "|cff9d9d9d" .. Commas(rest) .. "|r")
        end
        if d.avgKill then Line("Avg XP per kill", Commas(d.avgKill)) end
        if d.avgQuestXP then Line("Avg XP per quest", Commas(d.avgQuestXP)) end
        if d.toLevel then
            Line("To next level", ("%s  |cff9d9d9d(%d%% done)|r"):format(Commas(d.toLevel), floor(d.curXP / d.maxXP * 100)))
            if d.rested and d.rested > 0 then Line("Rested XP", Commas(d.rested)) end
            if d.ttl then Line("Time to level", Dur(d.ttl)) end
            if d.killsToLevel then Line("Kills to level", "~" .. Commas(d.killsToLevel)) end
            if d.questsToLevel then Line("Quests to level", "~" .. Commas(d.questsToLevel)) end
        end
    end
    Gap()

    Header("Gold")
    local function GoldLine(label, v, showPct)
        Line(label, ("%s  |cff9d9d9d%s/hr|r%s"):format(Money(v), Money(v / d.hrs, true), showPct and Pct(v, d.income) or ""))
    end
    GoldLine("From kills", s.income.LOOT or 0, true)
    GoldLine("From quests", s.income.QUEST or 0, true)
    GoldLine("|cffffffffTotal earned|r", d.income)
    local otherIncome = false
    for _, e in ipairs(INCOME_LABELS) do
        local v = s.income[e[1]]
        if v and v > 0 and e[1] ~= "LOOT" and e[1] ~= "QUEST" then
            if not otherIncome then
                Line("|cff9d9d9d  total also includes:|r", "")
                otherIncome = true
            end
            Line("|cff9d9d9d    " .. e[2] .. "|r", Money(v))
        end
    end
    local netColor = d.net >= 0 and "|cff33ff33+|r" or ""
    Line("Net change (after spending)", netColor .. Money(d.net))
    if d.expenses > 0 then
        Line("|cffff6060Spent|r", Money(d.expenses))
        for _, e in ipairs(EXPENSE_LABELS) do
            local v = s.expense[e[1]]
            if v and v > 0 then Line("  " .. e[2], Money(v)) end
        end
    end
    if d.avgQuestGold and d.avgQuestGold > 0 then Line("Avg gold per quest", Money(d.avgQuestGold)) end
    if s.loot.value > 0 then Line("Vendor value of looted items", Money(s.loot.value)) end
    Gap()

    Header("Combat")
    Line("Kills (XP-giving)", Commas(s.kills))
    Line("Kills per hour", ("%.1f"):format(s.kills / d.hrs))
    Line("Corpses looted", Commas(s.corpses))
    Line("Deaths", Commas(s.deaths))
    if s.flights > 0 then Line("Flights taken", Commas(s.flights)) end
    Gap()

    Header("Quests")
    Line("Completed", Commas(s.quests.completed))
    Line("Accepted", Commas(s.quests.accepted))
    Line("Completed per hour", ("%.1f"):format(s.quests.completed / d.hrs))
    Gap()

    Header("Loot")
    Line("Items looted", Commas(s.loot.items))
    for q = 0, 7 do
        local n = s.loot.byQuality[q]
        if n and n > 0 then Line("  " .. QColor(q) .. QName(q) .. "|r", Commas(n)) end
    end
    if #s.loot.notable > 0 then
        Line("|cffffd100Notable drops|r", "")
        for i = 1, min(#s.loot.notable, 12) do
            local n = s.loot.notable[i]
            Line("  " .. n.link .. (n.count > 1 and (" x" .. n.count) or ""), n.zone or "", { link = n.link })
        end
    end

    local reps = {}
    for f, v in pairs(s.rep) do reps[#reps + 1] = { f, v } end
    if #reps > 0 then
        table.sort(reps, function(a, b) return abs(a[2]) > abs(b[2]) end)
        Gap()
        Header("Reputation")
        for i = 1, min(#reps, 10) do
            local v = reps[i][2]
            Line(reps[i][1], (v >= 0 and "|cff33ff33+" or "|cffff6060") .. Commas(v) .. "|r")
        end
    end

    local skills = {}
    for k, v in pairs(s.skills) do skills[#skills + 1] = { k, v } end
    if #skills > 0 then
        table.sort(skills, function(a, b) return a[2].gained > b[2].gained end)
        Gap()
        Header("Skill ups")
        for _, e in ipairs(skills) do
            Line(e[1], ("+%d  |cff9d9d9d(now %s)|r"):format(e[2].gained, e[2].rank or "?"))
        end
    end
end

local function RunLines(r)
    Line("  Time", Dur(r.duration))
    if r.xp > 0 then Line("  XP", ("%s  |cff9d9d9d(%s/hr)|r"):format(Commas(r.xp), Short(r.xp / max(r.duration, 1) * 3600))) end
    Line("  Gold (net)", Money(r.gold))
    Line("  Kills / deaths", ("%d / %d"):format(r.kills, r.deaths))
    Line("  Items looted", ("%d  |cff9d9d9d(%s vendor)|r"):format(r.items, Money(r.value)))
end

local function BuildRuns(s, live)
    local runs = {}
    if live and s.activeRun then
        local r = {}
        for k, v in pairs(s.activeRun) do r[k] = v end
        for k, v in pairs(SS:RunDelta(s, s.activeRun)) do r[k] = v end
        r.inProgress = true
        runs[1] = r
    end
    for i = #s.runs, 1, -1 do runs[#runs + 1] = s.runs[i] end

    if #runs == 0 then
        Header("Dungeons & raids")
        Line("|cff9d9d9dNo runs yet this session.|r", "")
        Line("|cff9d9d9dA run starts when you zone into an instance.|r", "")
        return
    end

    local done, totalTime, totalXP, totalGold = 0, 0, 0, 0
    for _, r in ipairs(s.runs) do
        done = done + 1
        totalTime, totalXP, totalGold = totalTime + r.duration, totalXP + r.xp, totalGold + r.gold
    end
    if done > 0 then
        Header(("Completed runs: %d"):format(done))
        Line("Avg run time", Dur(totalTime / done))
        if totalXP > 0 then Line("Avg XP per run", Commas(totalXP / done)) end
        Line("Avg gold per run", Money(totalGold / done))
        Gap()
    end

    for _, r in ipairs(runs) do
        local title = r.name .. (r.difficulty and r.difficulty ~= "" and ("  |cff9d9d9d" .. r.difficulty .. "|r") or "")
        if r.inProgress then title = title .. "  |cff33ff33(in progress)|r" end
        Header(title)
        Line("  Entered", date("%H:%M", r.startedAt))
        RunLines(r)
        Gap()
    end
end

local function BuildZones(s)
    local zones = {}
    for name, z in pairs(s.zones) do zones[#zones + 1] = { name, z } end
    table.sort(zones, function(a, b) return a[2].time > b[2].time end)
    if #zones == 0 then
        Header("Zones")
        Line("|cff9d9d9dNothing yet.|r", "")
        return
    end
    for _, e in ipairs(zones) do
        local z = e[2]
        Header(e[1])
        Line("  Time", Dur(z.time))
        if z.xp > 0 then
            Line("  XP", ("%s  |cff9d9d9d(%s/hr)|r"):format(Commas(z.xp), Short(z.xp / max(z.time, 1) * 3600)))
        end
        Line("  Kills / quests", ("%d / %d"):format(z.kills, z.quests))
        if z.gold > 0 then Line("  Gold earned", Money(z.gold)) end
        Gap()
    end
end

local function BuildHistory(UI)
    local hist = SS.db.history
    Header("Past sessions")
    if #hist == 0 then
        Line("|cff9d9d9dEnded sessions show up here.|r", "")
        return
    end
    Line("|cff9d9d9dClick a session to view it.|r", "")
    Gap()
    for _, s in ipairs(hist) do
        local net = (s.endMoney or s.startMoney) - s.startMoney
        local open = function() UI:Show("Overview", s) end
        Line(("|cffffffff%s|r"):format(s.name), date("%b %d", s.startedAt), { onClick = open })
        Line(("  %s  |cff9d9d9dLv %d->%d|r"):format(Dur(s.active), s.startLevel, s.endLevel or s.startLevel),
            ("%s XP  %s"):format(Short(s.xp.total), Money(net)), { onClick = open })
    end
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local function Backdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.06, 0.08, 0.94)
    f:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
end

local function Movable(f, key)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        SS.db.settings[key] = { p, rp, x, y }
    end)
end

local function Restore(f, key, default)
    local pt = SS.db.settings[key]
    f:ClearAllPoints()
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint(unpack(default)) end
end

local function PopupEditBox(self)
    return (self.GetEditBox and self:GetEditBox()) or self.editBox or self.EditBox
end

StaticPopupDialogs["SESSIONSTATS_NEW"] = {
    text = "Start a new session?\nThe current one will be saved to History.",
    button1 = "Start",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local eb = PopupEditBox(self)
        if eb then eb:SetText(date("Session %b %d, %H:%M")); eb:HighlightText() end
    end,
    OnAccept = function(self)
        local eb = PopupEditBox(self)
        SS:StartSession(eb and eb:GetText() or nil)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        SS:StartSession(self:GetText())
        parent:Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["SESSIONSTATS_END"] = {
    text = "End the current session and move it to History?",
    button1 = "End",
    button2 = "Cancel",
    OnAccept = function() SS:EndSession() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function ns.CreateUI()
    Money, Dur, Short, Commas = SS.Money, SS.Duration, SS.Short, SS.Commas
    local UI = { tab = "Overview" }
    SS.UI = UI

    -----------------------------------------------------------------------
    -- Main window
    -----------------------------------------------------------------------
    local f = CreateFrame("Frame", "SessionStatsFrame", UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetFrameStrata("MEDIUM")
    Backdrop(f)
    Movable(f, "point")
    Restore(f, "point", { "CENTER" })
    f:Hide()
    tinsert(UISpecialFrames, "SessionStatsFrame")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetText("Session Stats")
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    UI.tabs = {}
    local prev
    for _, name in ipairs({ "Overview", "Dungeons", "Zones", "History" }) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(86, 20)
        b:SetText(name)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -36) end
        b:SetScript("OnClick", function() UI:Show(name) end)
        UI.tabs[name] = b
        prev = b
    end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -62)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(W - 46, 10)
    scroll:SetScrollChild(content)

    UI.rows = {}
    local function Row(i)
        local r = UI.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, content)
        r:SetHeight(LINE_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * LINE_H)
        r:SetPoint("RIGHT", content, "RIGHT")
        r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.left:SetPoint("LEFT", 4, 0)
        r.left:SetJustifyH("LEFT")
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.right:SetPoint("RIGHT", -4, 0)
        r.right:SetJustifyH("RIGHT")
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.08)
        r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
        r:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        UI.rows[i] = r
        return r
    end

    local function Render(lines)
        for i, e in ipairs(lines) do
            local r = Row(i)
            r:Show()
            r.onClick, r.link = e.onClick, e.link
            r:EnableMouse(e.onClick ~= nil or e.link ~= nil)
            if e.gap then
                r.left:SetText("")
                r.right:SetText("")
            elseif e.header then
                r.left:SetFontObject("GameFontNormal")
                r.left:SetText(e.left)
                r.right:SetText("")
            else
                r.left:SetFontObject("GameFontHighlightSmall")
                r.left:SetText(e.left or "")
                r.right:SetText(e.right or "")
            end
        end
        for i = #lines + 1, #UI.rows do UI.rows[i]:Hide() end
        content:SetHeight(max(#lines * LINE_H, 10))
    end

    -----------------------------------------------------------------------
    -- Footer buttons
    -----------------------------------------------------------------------
    local function Btn(text, w, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    UI.newBtn = Btn("New session", 100, function()
        if SS:Current() then StaticPopup_Show("SESSIONSTATS_NEW") else SS:StartSession() end
    end)
    UI.newBtn:SetPoint("BOTTOMLEFT", 12, 12)
    UI.pauseBtn = Btn("Pause", 70, function()
        local s = SS:Current()
        if s then SS:SetPaused(not s.paused) end
    end)
    UI.pauseBtn:SetPoint("LEFT", UI.newBtn, "RIGHT", 4, 0)
    UI.endBtn = Btn("End", 60, function()
        if SS:Current() then StaticPopup_Show("SESSIONSTATS_END") end
    end)
    UI.endBtn:SetPoint("LEFT", UI.pauseBtn, "RIGHT", 4, 0)
    UI.reportBtn = Btn("Report", 70, function()
        SS:Report((IsInGroup() and not IsInRaid()) and "PARTY" or nil)
    end)
    UI.reportBtn:SetPoint("LEFT", UI.endBtn, "RIGHT", 4, 0)
    UI.reportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Report")
        GameTooltip:AddLine("Posts a one-line summary to party chat when grouped, otherwise to your chat window.", 1, 1, 1, true)
        GameTooltip:AddLine("/ss report guild  - post to guild", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    UI.reportBtn:SetScript("OnLeave", GameTooltip_Hide)

    -----------------------------------------------------------------------
    -- Mini tracker
    -----------------------------------------------------------------------
    local mini = CreateFrame("Frame", "SessionStatsMini", UIParent, "BackdropTemplate")
    mini:SetSize(190, 58)
    Backdrop(mini)
    mini:SetBackdropColor(0.05, 0.06, 0.08, 0.75)
    Movable(mini, "miniPoint")
    Restore(mini, "miniPoint", { "TOPRIGHT", UIParent, "TOPRIGHT", -220, -200 })
    mini.lines = {}
    for i = 1, 3 do
        local fs = mini:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 9, -8 - (i - 1) * 14)
        fs:SetPoint("RIGHT", -9, 0)
        fs:SetJustifyH("LEFT")
        mini.lines[i] = fs
    end
    mini:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local s = SS:Current()
            if s then SS:SetPaused(not s.paused) else SS:StartSession() end
        end
    end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Session Stats")
        GameTooltip:AddLine("Drag to move. Double-click to open.", 1, 1, 1)
        GameTooltip:AddLine("Right-click: pause / resume (or start).", 1, 1, 1)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", GameTooltip_Hide)
    mini:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            local now = GetTime()
            if UI.lastMiniClick and now - UI.lastMiniClick < 0.35 then UI:Toggle() end
            UI.lastMiniClick = now
        end
    end)

    local function UpdateMini()
        if not SS.db.settings.mini then mini:Hide() return end
        mini:Show()
        local s = SS:Current()
        if not s then
            mini.lines[1]:SetText("|cff66ccffSession Stats|r")
            mini.lines[2]:SetText("|cff9d9d9dNo session running|r")
            mini.lines[3]:SetText("|cff9d9d9dRight-click to start|r")
            return
        end
        local d = SS:Derive(s, true)
        local state = s.paused and "|cffff8080paused|r" or Dur(s.active)
        if d.maxLevel and s.xp.total == 0 then
            mini.lines[1]:SetText(("%s  |cff9d9d9d%d kills|r"):format(state, s.kills))
        else
            mini.lines[1]:SetText(("%s  |cff9d9d9dTTL|r %s"):format(state, d.ttl and Dur(d.ttl) or "-"))
        end
        if d.maxLevel and s.xp.total == 0 then
            mini.lines[2]:SetText(("|cff9d9d9dEarned/hr|r %s"):format(Money(d.earned / d.hrs)))
        else
            mini.lines[2]:SetText(("|cff9d9d9dXP/hr|r %s  |cff9d9d9dkills|r %d"):format(Short(d.xph), s.kills))
        end
        mini.lines[3]:SetText(("|cff9d9d9dNet|r %s  |cff9d9d9dq|r %d"):format(Money(d.net), s.quests.completed))
    end

    -----------------------------------------------------------------------
    -- Public
    -----------------------------------------------------------------------
    function UI:Show(tab, viewing)
        self.tab = tab or self.tab
        self.viewing = viewing
        f:Show()
        self:Refresh()
    end

    function UI:Toggle()
        if f:IsShown() then f:Hide() else self:Show(self.tab) end
    end

    function UI:Refresh()
        UpdateMini()
        if not f:IsShown() then return end
        local cur = SS:Current()
        local s = self.viewing or cur
        local live = s ~= nil and s == cur

        for name, b in pairs(self.tabs) do
            if name == self.tab then b:LockHighlight() else b:UnlockHighlight() end
        end
        UI.pauseBtn:SetText(cur and cur.paused and "Resume" or "Pause")
        UI.pauseBtn:SetEnabled(cur ~= nil)
        UI.endBtn:SetEnabled(cur ~= nil)

        L = {}
        if self.tab == "History" then
            BuildHistory(self)
        elseif not s then
            Header("No session running")
            Line("Click |cffffffffNew session|r to start tracking.", "")
            Line("|cff9d9d9dTracks XP, gold, kills, quests, loot, dungeon runs and zones.|r", "")
        elseif self.tab == "Overview" then
            BuildOverview(s, live)
        elseif self.tab == "Dungeons" then
            BuildRuns(s, live)
        elseif self.tab == "Zones" then
            BuildZones(s)
        end
        Render(L)
    end

    function UI:Tick()
        self.ticks = (self.ticks or 0) + 1
        UpdateMini()
        if f:IsShown() and self.ticks % 2 == 0 then self:Refresh() end
    end

    UI:Refresh()
end
