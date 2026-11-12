-- Ask AI - UI
-- Prompt window, template editor, and "Ask AI" buttons on the quest log / quest giver.

local ADDON, ns = ...
local A = ns.A

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 0.5, 0.83, 1 }

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function Window(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.06, 0.09, 0.96)
    f:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, name)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -11)
    f.title:SetPoint("RIGHT", -34, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.title:SetText(title)
    f.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    return f
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 22)
    b:SetText(text)
    return b
end

local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Boxed(frame)
    local bg = CreateFrame("Frame", nil, frame:GetParent(), "BackdropTemplate")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 5, -5)
    bg:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    bg:SetBackdropColor(0, 0, 0, 0.45)
    bg:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    bg:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    return bg
end

local function SingleLine(parent, w)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(w, 20)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    Boxed(eb)
    return eb
end

-- Multi-line edit box inside a scroll frame.
local function MultiLine(parent, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(w, h)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(w - 4)
    eb:SetTextInsets(2, 2, 2, 2)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    sf:SetScrollChild(eb)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
    eb:SetScript("OnCursorChanged", function(self, x, y, cw, ch)
        if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, x, y, cw, ch) end
    end)
    eb:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, sf) end
    end)
    local bg = Boxed(sf)
    bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 26, -5)
    sf.edit = eb
    return sf, eb
end

-- Scrollable list of templates.
local function TemplateList(parent, w, h, onSelect)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(w, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w, 10)
    sf:SetScrollChild(content)
    Boxed(sf):SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 26, -5)
    local list = { buttons = {}, frame = sf }

    local function Get(i)
        local b = list.buttons[i]
        if b then return b end
        b = CreateFrame("Button", nil, content)
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 23)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 6, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self) onSelect(self.id) end)
        list.buttons[i] = b
        return b
    end

    function list:Refresh(selected)
        local items = A.db.templates
        for i, t in ipairs(items) do
            local b = Get(i)
            b.id = t.id
            b.text:SetText((t.builtin and "" or "|cffffd100*|r ") .. (t.name ~= "" and t.name or "(unnamed)"))
            b.bg:SetShown(t.id == selected)
            b:Show()
        end
        for i = #items + 1, #self.buttons do self.buttons[i]:Hide() end
        content:SetHeight(math.max(#items * 23, 10))
    end
    return list
end

---------------------------------------------------------------------------
-- Prompt window
---------------------------------------------------------------------------

local P   -- prompt window
local E   -- editor window

local function BuildPromptWindow()
    P = Window("AskAIFrame", 640, 470, "Ask AI")

    local listLabel = Label(P, "Prompt")
    listLabel:SetPoint("TOPLEFT", 16, -40)
    P.list = TemplateList(P, 150, 300, function(id)
        A.db.last = id
        A:RefreshPrompt()
    end)
    local listSF = P.list.frame
    listSF:SetPoint("TOPLEFT", 16, -58)

    local edit = Button(P, "Edit prompts", 150)
    edit:SetPoint("TOPLEFT", listSF, "BOTTOMLEFT", 0, -12)
    edit:SetScript("OnClick", function() A:OpenEditor(A.db.last) end)

    local qLabel = Label(P, "Your question (optional) - press Enter to add it")
    qLabel:SetPoint("TOPLEFT", 210, -40)
    P.question = SingleLine(P, 400)
    P.question:SetPoint("TOPLEFT", 214, -58)
    P.question:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        A:RefreshPrompt()
    end)

    local pLabel = Label(P, "Prompt - select all is automatic, just press Ctrl+C")
    pLabel:SetPoint("TOPLEFT", 210, -90)
    local sf, eb = MultiLine(P, 380, 270)
    sf:SetPoint("TOPLEFT", 214, -108)
    P.prompt = eb
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local copyHint = Label(P, "", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -10)
    copyHint:SetText("|cff9d9d9dCtrl+C, then paste into ChatGPT, Claude or another assistant.|r")

    local selBtn = Button(P, "Select all", 90)
    selBtn:SetPoint("TOPRIGHT", sf, "BOTTOMRIGHT", 22, -6)
    selBtn:SetScript("OnClick", function()
        P.prompt:SetFocus()
        P.prompt:HighlightText()
    end)

    local wLabel = Label(P, "Wowhead")
    wLabel:SetPoint("BOTTOMLEFT", 214, 18)
    P.wowhead = SingleLine(P, 330)
    P.wowhead:SetPoint("LEFT", wLabel, "RIGHT", 10, 0)
    P.wowhead:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    P.wowhead:SetScript("OnTextChanged", function(self, user)
        if user and self.url then self:SetText(self.url); self:HighlightText() end
    end)
end

function A:RefreshPrompt()
    if not P then return end
    local t = self:GetTemplate(self.db.last) or self.db.templates[1]
    if not t then
        P.prompt:SetText("No prompts. Click 'Edit prompts' to add one.")
        return
    end
    self.db.last = t.id
    P.list:Refresh(t.id)
    local text, v = self:Render(t, self.quest, P.question:GetText())
    P.prompt:SetText(text)
    P.prompt:SetCursorPosition(0)
    P.wowhead.url = v.wowhead
    P.wowhead:SetText(v.wowhead)
    P.title:SetText("Ask AI - " .. (self.quest and v.quest or "no quest selected"))
    P.prompt:SetFocus()
    P.prompt:HighlightText()
end

-- Opens the prompt window. `source` is "npc", a frame with .questID, or nil.
function A:Open(source, templateId)
    if not P then BuildPromptWindow() end
    local id, origin = self:CurrentQuestID(source)
    self.quest = self:GatherQuest(id, origin)
    if templateId then self.db.last = templateId end
    P:Show()
    self:RefreshPrompt()
end

---------------------------------------------------------------------------
-- Editor
---------------------------------------------------------------------------

local function BuildEditor()
    E = Window("AskAIEditor", 720, 520, "Ask AI - Prompt editor")

    E.list = TemplateList(E, 170, 330, function(id) A:EditSelect(id) end)
    local listSF = E.list.frame
    listSF:SetPoint("TOPLEFT", 16, -42)

    local new = Button(E, "New", 82)
    new:SetPoint("TOPLEFT", listSF, "BOTTOMLEFT", 0, -12)
    new:SetScript("OnClick", function() A:EditSelect(A:NewTemplate().id) end)
    local dup = Button(E, "Duplicate", 82)
    dup:SetPoint("LEFT", new, "RIGHT", 6, 0)
    dup:SetScript("OnClick", function()
        local t = A:GetTemplate(E.selected)
        if t then A:EditSelect(A:NewTemplate(t).id) end
    end)
    local up = Button(E, "Up", 82)
    up:SetPoint("TOPLEFT", new, "BOTTOMLEFT", 0, -4)
    up:SetScript("OnClick", function() A:MoveTemplate(E.selected, -1); E.list:Refresh(E.selected) end)
    local down = Button(E, "Down", 82)
    down:SetPoint("LEFT", up, "RIGHT", 6, 0)
    down:SetScript("OnClick", function() A:MoveTemplate(E.selected, 1); E.list:Refresh(E.selected) end)
    local del = Button(E, "Delete", 82)
    del:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -4)
    del:SetScript("OnClick", function()
        local t = A:GetTemplate(E.selected)
        if t then StaticPopup_Show("ASKAI_DELETE", t.name, nil, t.id) end
    end)
    E.reset = Button(E, "Reset", 82)
    E.reset:SetPoint("LEFT", del, "RIGHT", 6, 0)
    E.reset:SetScript("OnClick", function()
        local t = A:GetTemplate(E.selected)
        if t and t.builtin then A:RestoreBuiltin(t.builtin); A:EditSelect(t.id) end
    end)

    local nLabel = Label(E, "Name")
    nLabel:SetPoint("TOPLEFT", 222, -42)
    E.name = SingleLine(E, 300)
    E.name:SetPoint("LEFT", nLabel, "RIGHT", 10, 0)
    E.name:SetScript("OnTextChanged", function(self, user)
        if not user then return end
        local t = A:GetTemplate(E.selected)
        if t then t.name = self:GetText(); E.list:Refresh(E.selected) end
    end)

    local preview = Button(E, "Preview", 90)
    preview:SetPoint("LEFT", E.name, "RIGHT", 12, 0)
    preview:SetScript("OnClick", function() A:Open(nil, E.selected) end)

    local bLabel = Label(E, "Prompt text (saved as you type). Placeholders in {braces} are filled in from the game.")
    bLabel:SetPoint("TOPLEFT", 222, -72)
    local sf, eb = MultiLine(E, 450, 250)
    sf:SetPoint("TOPLEFT", 226, -92)
    E.body = eb
    eb:SetScript("OnTextChanged", function(self, user)
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, sf) end
        if not user then return end
        local t = A:GetTemplate(E.selected)
        if t then t.body = self:GetText() end
    end)

    -- Placeholder reference: click one to insert it at the cursor.
    local pLabel = Label(E, "Placeholders (click to insert)")
    pLabel:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", -4, -14)
    local col, row = 0, 0
    for _, ph in ipairs(A.PLACEHOLDERS) do
        local b = CreateFrame("Button", nil, E)
        b:SetSize(112, 16)
        b:SetPoint("TOPLEFT", pLabel, "BOTTOMLEFT", col * 116, -4 - row * 17)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT")
        fs:SetText("|cff7fd4ff{" .. ph[1] .. "}|r")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function()
            E.body:SetFocus()
            E.body:Insert("{" .. ph[1] .. "}")
            local t = A:GetTemplate(E.selected)
            if t then t.body = E.body:GetText() end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("{" .. ph[1] .. "}")
            GameTooltip:AddLine(ph[2], 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        col = col + 1
        if col == 4 then col, row = 0, row + 1 end
    end

    local foot = Label(E, "|cffffd100*|r = your own prompt.  Built-in prompts can be edited too; Reset restores them.", "GameFontHighlightSmall")
    foot:SetPoint("BOTTOMLEFT", 16, 14)
end

function A:EditSelect(id)
    local t = self:GetTemplate(id) or self.db.templates[1]
    E.selected = t and t.id
    E.list:Refresh(E.selected)
    E.name:SetText(t and t.name or "")
    E.body:SetText(t and t.body or "")
    E.body:SetCursorPosition(0)
    E.reset:SetEnabled(t and t.builtin ~= nil)
end

function A:OpenEditor(id)
    if not E then BuildEditor() end
    E:Show()
    self:EditSelect(id or self.db.last)
end

StaticPopupDialogs["ASKAI_DELETE"] = {
    text = "Delete the prompt \"%s\"?",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, id)
        A:DeleteTemplate(id)
        if E and E:IsShown() then A:EditSelect(nil) end
        if P and P:IsShown() then A:RefreshPrompt() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

---------------------------------------------------------------------------
-- "Ask AI" buttons on Blizzard quest frames
---------------------------------------------------------------------------

local TARGETS = {
    -- key, frame getter, default anchor, source passed to Open
    { key = "map",    get = function() return QuestMapFrame and QuestMapFrame.DetailsFrame end,
      point = { "TOPRIGHT", -40, -4 } },
    { key = "popup",  get = function() return QuestLogPopupDetailFrame end,
      point = { "TOPRIGHT", -30, -30 }, source = function(f) return f end },
    { key = "log",    get = function() return QuestLogFrame end,
      point = { "TOPRIGHT", -80, -48 } },
    { key = "detail", get = function() return QuestLogDetailFrame end,
      point = { "TOPRIGHT", -40, -48 } },
    { key = "npc",    get = function() return QuestFrame end,
      point = { "TOPRIGHT", -40, -50 }, source = function() return "npc" end },
}

local function MakeAskButton(target, parent)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(70, 20)
    b:SetText("Ask AI")
    b:SetFrameLevel(parent:GetFrameLevel() + 20)
    local saved = A.db.buttons[target.key]
    local p = saved or target.point
    b:SetPoint(p[1], parent, p[1], p[2], p[3])
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save relative to the parent's same corner.
        local pr, pt = parent:GetRight(), parent:GetTop()
        local r, t = self:GetRight(), self:GetTop()
        if pr and pt and r and t then
            A.db.buttons[target.key] = { "TOPRIGHT", r - pr, t - pt }
            self:ClearAllPoints()
            self:SetPoint("TOPRIGHT", parent, "TOPRIGHT", r - pr, t - pt)
        end
    end)
    b:SetScript("OnClick", function(_, button)
        local src = target.source and target.source(parent) or nil
        if button == "RightButton" then A:OpenEditor() else A:Open(src) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Ask AI")
        GameTooltip:AddLine("Build a ready-to-paste prompt about this quest.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click: edit prompts", 0.6, 0.8, 1)
        GameTooltip:AddLine("Shift-drag: move this button", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

A.attached = {}
function A:AttachButtons()
    for _, target in ipairs(TARGETS) do
        if not self.attached[target.key] then
            local ok, parent = pcall(target.get)
            if ok and parent and not (parent.IsForbidden and parent:IsForbidden()) then
                self.attached[target.key] = MakeAskButton(target, parent)
            end
        end
    end
end

function A:ResetButtons()
    wipe(self.db.buttons)
    for _, target in ipairs(TARGETS) do
        local b = self.attached[target.key]
        if b then
            local parent = b:GetParent()
            b:ClearAllPoints()
            b:SetPoint(target.point[1], parent, target.point[1], target.point[2], target.point[3])
        end
    end
end

---------------------------------------------------------------------------
-- Events + slash
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        A:InitDB()
        A:AttachButtons()
    elseif event == "ADDON_LOADED" and A.db and name ~= ADDON then
        A:AttachButtons()          -- Blizzard quest UIs that load on demand
    end
end)

SLASH_ASKAI1 = "/askai"
SLASH_ASKAI2 = "/ai"
SlashCmdList.ASKAI = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local lower = msg:lower()
    if lower == "edit" then
        A:OpenEditor()
    elseif lower == "resetbuttons" then
        A:ResetButtons()
        A:Print("Buttons moved back to their default spots.")
    elseif lower == "restore" then
        A:RestoreBuiltin()
        A:Print("Built-in prompts restored.")
    elseif lower == "help" then
        A:Print("/askai [prompt name] - open (optionally with a specific prompt)")
        A:Print("/askai edit - prompt editor   /askai restore - restore built-ins   /askai resetbuttons")
    elseif msg ~= "" then
        for _, t in ipairs(A.db.templates) do
            if t.name:lower():find(lower, 1, true) then A:Open(nil, t.id) return end
        end
        A:Print("No prompt matching '%s'.", msg)
    else
        A:Open()
    end
end
