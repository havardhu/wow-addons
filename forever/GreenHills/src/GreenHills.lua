-- Green Hills Pages
-- Tracks the 15 Green Hills of Stranglethorn pages the quest needs, for a bank alt:
-- counts what you hold in bags and bank, and lets you tick off pages you've sent to your main.
-- It never looks at the quest log.

local ADDON, ns = ...
local GH = {}
_G.GreenHills = GH

local ACCENT = { 0.45, 0.85, 0.35 }

-- Pages each chapter needs.
GH.CHAPTERS = {
    { name = "Chapter I",   pages = { 1, 4, 6, 8 } },
    { name = "Chapter II",  pages = { 10, 11, 14, 16 } },
    { name = "Chapter III", pages = { 18, 20, 21, 24 } },
    { name = "Chapter IV",  pages = { 25, 26, 27 } },
}
GH.NEEDED = {}
for _, ch in ipairs(GH.CHAPTERS) do
    for _, p in ipairs(ch.pages) do GH.NEEDED[p] = ch.name end
end

-- Page N is item 2724 + N (Page 1 = 2725). Pages are also recognised by name,
-- so a wrong ID doesn't break anything on English clients.
local FIRST_ID = 2724
local function PageFromID(id)
    if id and id > FIRST_ID and id <= FIRST_ID + 27 then return id - FIRST_ID end
end
local function PageFromName(name)
    if not name then return nil end
    local n = name:match("^Green Hills of Stranglethorn %- Page (%d+)$")
    return n and tonumber(n)
end
local function PageFromLink(link)
    if not link then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local name = link:match("%[(.-)%]")
    return PageFromName(name) or PageFromID(id)
end

function GH:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff73d959Green Hills:|r " .. msg)
end

---------------------------------------------------------------------------
-- Bags and bank
---------------------------------------------------------------------------

local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.hyperlink, info.stackCount or 1 end
        return nil
    end
    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    return link, count or 1
end

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local BANK = BANK_CONTAINER or -1

local function ScanBags(list)
    local counts = {}
    for _, bag in ipairs(list) do
        for slot = 1, (NumSlots(bag) or 0) do
            local link, count = SlotInfo(bag, slot)
            local page = PageFromLink(link)
            if page then counts[page] = (counts[page] or 0) + count end
        end
    end
    return counts
end

function GH:ScanInventory()
    local bags = {}
    for b = 0, LAST_BAG do bags[#bags + 1] = b end
    self.bags = ScanBags(bags)
end

function GH:ScanBank()
    local bags = { BANK }
    for b = LAST_BAG + 1, LAST_BAG + (NUM_BANKBAGSLOTS or 7) do bags[#bags + 1] = b end
    self.char.bank = ScanBags(bags)
    self.char.bankSeen = time()
end

function GH:Count(page)
    return (self.bags[page] or 0) + ((self.char.bank or {})[page] or 0)
end

function GH:IsSent(page)
    return self.db.sent[page] and true or false
end

-- done = sent, ready = held and not sent, missing = neither
function GH:State(page)
    if self:IsSent(page) then return "sent" end
    if self:Count(page) > 0 then return "ready" end
    return "missing"
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local W
local ROW_H = 22

local function Build()
    W = CreateFrame("Frame", "GreenHillsFrame", UIParent, "BackdropTemplate")
    W:SetSize(360, 100)
    W:SetFrameStrata("DIALOG")
    W:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    W:SetBackdropColor(0.04, 0.07, 0.04, 0.96)
    W:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    W:EnableMouse(true)
    W:SetMovable(true)
    W:SetClampedToScreen(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving)
    W:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        GH.db.point = { p, rp, x, y }
    end)
    local pt = GH.db.point
    if pt then W:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else W:SetPoint("CENTER") end
    W:Hide()
    tinsert(UISpecialFrames, "GreenHillsFrame")
    W:SetScript("OnShow", function() GH:ScanInventory(); GH:Update() end)

    local title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetText("Green Hills of Stranglethorn")
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    local close = CreateFrame("Button", nil, W, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    W.summary = W:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    W.summary:SetPoint("TOPLEFT", 14, -34)
    W.summary:SetPoint("RIGHT", -14, 0)
    W.summary:SetJustifyH("LEFT")

    W.colHint = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    W.colHint:SetPoint("TOPLEFT", 14, -50)
    W.colHint:SetText("Tick a page once you've sent it to your main.")

    W.headers, W.rows = {}, {}
    local y = -70
    for _, ch in ipairs(GH.CHAPTERS) do
        local h = W:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 14, y)
        h.chapter = ch
        W.headers[#W.headers + 1] = h
        y = y - 18
        for _, page in ipairs(ch.pages) do
            local cb = CreateFrame("CheckButton", nil, W, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", 18, y)
            cb.page = page
            cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            cb.label:SetWidth(80)
            cb.label:SetJustifyH("LEFT")
            cb.label:SetText("Page " .. page)
            cb.status = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cb.status:SetPoint("LEFT", cb.label, "RIGHT", 6, 0)
            cb.status:SetWidth(210)
            cb.status:SetJustifyH("LEFT")
            cb:SetScript("OnClick", function(self)
                GH.db.sent[self.page] = self:GetChecked() and true or nil
                GH:Update()
            end)
            W.rows[#W.rows + 1] = cb
            y = y - ROW_H
        end
        y = y - 6
    end

    W.extra = W:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    W.extra:SetPoint("TOPLEFT", 14, y - 2)
    W.extra:SetPoint("RIGHT", -14, 0)
    W.extra:SetJustifyH("LEFT")
    W.extraTop = -y + 2

    local function Btn(text, w, onClick, tip)
        local b = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        if tip then
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(text)
                GameTooltip:AddLine(tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", GameTooltip_Hide)
        end
        return b
    end
    W.markHeld = Btn("Mark held as sent", 140, function()
        local n = 0
        for page in pairs(GH.NEEDED) do
            if not GH:IsSent(page) and GH:Count(page) > 0 then GH.db.sent[page] = true; n = n + 1 end
        end
        GH:Print("Marked %d page(s) as sent.", n)
        GH:Update()
    end, "Ticks every needed page you hold right now. Use it after mailing them to your main.")
    W.markHeld:SetPoint("BOTTOMLEFT", 12, 12)
    W.clear = Btn("Clear ticks", 96, function()
        wipe(GH.db.sent)
        GH:Update()
    end, "Unticks every page, for starting a new set.")
    W.clear:SetPoint("LEFT", W.markHeld, "RIGHT", 6, 0)
end

local function C(hex, s) return ("|cff%s%s|r"):format(hex, s) end

function GH:Update()
    if not (W and W:IsShown()) then return end
    local sent, ready, missingList = 0, 0, {}
    for _, cb in ipairs(W.rows) do
        local page = cb.page
        local n = self:Count(page)
        local st = self:State(page)
        cb:SetChecked(st == "sent")
        local b = self.bags[page] or 0
        local where = ""
        if n > 0 then
            local parts = {}
            if b > 0 then parts[#parts + 1] = b .. " in bags" end
            if n - b > 0 then parts[#parts + 1] = (n - b) .. " in bank" end
            where = " (" .. table.concat(parts, ", ") .. ")"
        end
        if st == "sent" then
            sent = sent + 1
            cb.label:SetTextColor(0.55, 0.55, 0.55)
            cb.status:SetText(C("73d959", "Sent") .. (n > 0 and C("9d9d9d", "  spare: " .. n .. where) or ""))
        elseif st == "ready" then
            ready = ready + 1
            cb.label:SetTextColor(1, 1, 1)
            cb.status:SetText(C("ffd100", "Have " .. n) .. C("9d9d9d", where .. " - send it"))
        else
            missingList[#missingList + 1] = page
            cb.label:SetTextColor(1, 0.45, 0.45)
            cb.status:SetText(C("ff7373", "Need"))
        end
    end
    for _, h in ipairs(W.headers) do
        local done = 0
        for _, p in ipairs(h.chapter.pages) do if self:IsSent(p) then done = done + 1 end end
        local total = #h.chapter.pages
        h:SetText(("%s  %s"):format(h.chapter.name,
            C(done == total and "73d959" or "9d9d9d", ("%d/%d sent"):format(done, total))))
    end

    local total = 0
    for _ in pairs(self.NEEDED) do total = total + 1 end
    local bankNote = self.char.bankSeen and "" or C("ff7373", "  ·  Open your bank once to count it")
    W.summary:SetText(("Sent %s  ·  Ready to send %s  ·  Still need %s%s"):format(
        C("73d959", sent .. "/" .. total), C("ffd100", ready), C("ff7373", #missingList), bankNote))

    -- Pages you hold that the quest never asks for (vendor or AH them).
    local spare = {}
    for page = 1, 27 do
        if not self.NEEDED[page] then
            local n = self:Count(page)
            if n > 0 then spare[#spare + 1] = ("%d (x%d)"):format(page, n) end
        end
    end
    local lines = {}
    if #missingList > 0 then
        lines[#lines + 1] = C("ff7373", "Still need: ") .. table.concat(missingList, ", ")
    else
        lines[#lines + 1] = C("73d959", "Every page is sent. Your main can finish the quest.")
    end
    if #spare > 0 then
        lines[#lines + 1] = C("9d9d9d", "Not needed by the quest (sell): ") .. table.concat(spare, ", ")
    end
    W.extra:SetText(table.concat(lines, "\n"))
    W:SetHeight(W.extraTop + W.extra:GetStringHeight() + 48)
end

function GH:Toggle()
    if not W then Build() end
    W:SetShown(not W:IsShown())
end

---------------------------------------------------------------------------
-- Tooltip: say whether a page is needed (handy at the auction house)
---------------------------------------------------------------------------

local function AddLine(tt, page)
    if not page or not GH.db then return end
    local chapter = GH.NEEDED[page]
    if not chapter then
        tt:AddLine("Green Hills: not needed for the quest", 0.6, 0.6, 0.6)
    elseif GH:IsSent(page) then
        tt:AddLine(("Green Hills: %s - already sent to your main"):format(chapter), 0.45, 0.85, 0.35)
    else
        local n = GH:Count(page)
        if n > 0 then
            tt:AddLine(("Green Hills: %s - you have %d, not sent yet"):format(chapter, n), 1, 0.82, 0)
        else
            tt:AddLine(("Green Hills: %s - NEEDED"):format(chapter), 1, 0.45, 0.45)
        end
    end
    tt:Show()
end

local function HookTooltips()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
            local page
            if data and data.id then page = PageFromID(data.id) end
            if tt.GetItem then
                local name, link = tt:GetItem()
                page = PageFromName(name) or PageFromLink(link) or page
            end
            AddLine(tt, page)
        end)
    else
        for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
            tt:HookScript("OnTooltipSetItem", function(self)
                local name, link = self:GetItem()
                AddLine(self, PageFromName(name) or PageFromLink(link))
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        GreenHillsDB = GreenHillsDB or {}
        GreenHillsDB.sent = GreenHillsDB.sent or {}   -- account-wide: [page] = true
        GreenHillsCharDB = GreenHillsCharDB or {}
        GH.db, GH.char = GreenHillsDB, GreenHillsCharDB
        GH.bags = {}
        HookTooltips()
    elseif event == "PLAYER_LOGIN" then
        GH:ScanInventory()
    elseif event == "BANKFRAME_OPENED" then
        GH.bankOpen = true
        GH:ScanBank()
        GH:ScanInventory()
        GH:Update()
    elseif event == "BANKFRAME_CLOSED" then
        GH.bankOpen = false
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" then
        if not GH.db then return end
        GH:ScanInventory()
        if GH.bankOpen then GH:ScanBank() end
        GH:Update()
    end
end)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                     "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
end

SLASH_GREENHILLS1 = "/greenhills"
SLASH_GREENHILLS2 = "/ghs"
SlashCmdList.GREENHILLS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "clear" then
        wipe(GH.db.sent)
        GH:Print("Cleared all ticks.")
        GH:Update()
    elseif msg == "list" then
        GH:ScanInventory()
        local need = {}
        for _, ch in ipairs(GH.CHAPTERS) do
            for _, p in ipairs(ch.pages) do
                if GH:State(p) == "missing" then need[#need + 1] = p end
            end
        end
        GH:Print(#need > 0 and ("Still need pages: " .. table.concat(need, ", ")) or "Nothing missing.")
    else
        GH:Toggle()
    end
end
