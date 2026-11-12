-- Blessing Manager - UI
-- Assignment grid (paladins x classes) and the secure "cast next blessing" button.

local ADDON, ns = ...

local CELL, GAP, NAME_W, PAD = 30, 2, 130, 10
local TOP = 34          -- title area
local HEADER_H = 28     -- class icon row
local FOOTER_H = 62     -- status line + buttons

local WHITE = "Interface\\Buttons\\WHITE8X8"

function ns.CreateUI(BM)
    local UI = {}
    BM.UI = UI

    local nClasses = #BM.CLASSES
    local width = PAD * 2 + NAME_W + nClasses * (CELL + GAP)

    -----------------------------------------------------------------------
    -- Main frame
    -----------------------------------------------------------------------
    local f = CreateFrame("Frame", "BlessingManagerFrame", UIParent, "BackdropTemplate")
    f:SetSize(width, 160)
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.06, 0.05, 0.08, 0.94)
    f:SetBackdropBorderColor(0.96, 0.55, 0.73, 0.9)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        BM.db.point = { p, rp, x, y }
    end)
    local pt = BM.db.point
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER") end
    f:Hide()
    tinsert(UISpecialFrames, "BlessingManagerFrame")
    f:SetScript("OnShow", function() BM:RequestRefresh(); UI:Refresh() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 2, -10)
    title:SetText("Blessing Manager")
    title:SetTextColor(0.96, 0.55, 0.73)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -----------------------------------------------------------------------
    -- Class header
    -----------------------------------------------------------------------
    for i, class in ipairs(BM.CLASSES) do
        local x = PAD + NAME_W + (i - 1) * (CELL + GAP)
        local holder = CreateFrame("Frame", nil, f)
        holder:SetSize(CELL, CELL - 4)
        holder:SetPoint("TOPLEFT", f, "TOPLEFT", x, -TOP)
        local atlas = "classicon-" .. class:lower()
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
            local t = holder:CreateTexture(nil, "ARTWORK")
            t:SetSize(CELL - 8, CELL - 8)
            t:SetPoint("CENTER")
            t:SetAtlas(atlas)
        else
            local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("CENTER")
            fs:SetText(BM:ClassName(class):sub(1, 3))
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then fs:SetTextColor(c.r, c.g, c.b) end
        end
        holder:EnableMouse(true)
        holder:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(BM:ClassName(class))
            GameTooltip:Show()
        end)
        holder:SetScript("OnLeave", GameTooltip_Hide)
    end

    -----------------------------------------------------------------------
    -- Grid cells
    -----------------------------------------------------------------------
    local function Cycle(pal, class, dir)
        local list = { false }
        for _, k in ipairs(BM.ORDER) do
            if BM:Knows(pal, k) then list[#list + 1] = k end
        end
        local cur = BM:Get(pal, class) or false
        local idx = 1
        for i, k in ipairs(list) do if k == cur then idx = i end end
        idx = (idx - 1 + dir) % #list + 1
        BM:Set(pal, class, list[idx] or nil)
    end

    local function RoleValueText(v)
        if v == nil then return "|cff9d9d9ddefault|r" end
        if v == BM.SKIP then return "|cffff8080none|r" end
        return BM.BLESSINGS[v].short
    end

    local function OpenRoleMenu(cell)
        local pal, class = cell.pal, cell.class
        if not BM:CanEdit(BM.me, pal) then
            BM:Print("Only %s or a raid leader/assist can change that row.", BM:Short(pal))
            return
        end
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            BM:Print("Role menu unavailable on this client.")
            return
        end
        MenuUtil.CreateContextMenu(cell, function(_, root)
            root:CreateTitle(("%s > %s by role"):format(BM:Short(pal), BM:ClassName(class)))
            for _, role in ipairs(BM.ROLES) do
                local sub = root:CreateButton(("%s: %s"):format(BM.ROLE_LABEL[role], RoleValueText(BM:GetRole(pal, class, role))))
                local function add(text, value)
                    sub:CreateRadio(text,
                        function() return BM:GetRole(pal, class, role) == value end,
                        function() BM:SetRole(pal, class, role, value); UI:Refresh() end)
                end
                add("Use class default", nil)
                add("No blessing", BM.SKIP)
                for _, k in ipairs(BM.ORDER) do
                    if BM:Knows(pal, k) then add(BM.BLESSINGS[k].spell, k) end
                end
            end
            root:CreateDivider()
            root:CreateButton("Clear role overrides", function() BM:ClearRoles(pal, class); UI:Refresh() end)
        end)
    end

    local function CellClick(self, button)
        if InCombatLockdown() then return end
        if button == "RightButton" then
            GameTooltip:Hide()
            OpenRoleMenu(self)
            return
        end
        if IsShiftKeyDown() then
            BM:Set(self.pal, self.class, nil)
        else
            Cycle(self.pal, self.class, 1)
        end
        UI:Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end

    local function CellEnter(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(("%s  >  %s"):format(BM:Short(self.pal), BM:ClassName(self.class)))
        local key = BM:Get(self.pal, self.class)
        GameTooltip:AddDoubleLine("Default", key and BM.BLESSINGS[key].spell or "unassigned", 0.8, 0.8, 0.8, 1, 1, 1)
        for _, role in ipairs(BM.ROLES) do
            local v = BM:GetRole(self.pal, self.class, role)
            if v then GameTooltip:AddDoubleLine(BM.ROLE_LABEL[role], RoleValueText(v), 0.8, 0.8, 0.8, 1, 1, 1) end
        end
        if key or self.hasRoles then
            local c = BM.cells and BM.cells[self.pal] and BM.cells[self.pal][self.class]
            if c then
                GameTooltip:AddLine(("%d/%d buffed, %d expiring soon"):format(c.have, c.total, c.soon), 0.8, 0.8, 0.8)
                for _, n in ipairs(c.missing) do
                    GameTooltip:AddLine("   missing: " .. BM:Short(n), 1, 0.45, 0.45)
                end
            else
                GameTooltip:AddLine("Nobody of this class in the group", 0.6, 0.6, 0.6)
            end
            if self.conflict then
                GameTooltip:AddLine("Another paladin has the same blessing here.", 1, 0.2, 0.2)
            end
        end
        if BM:CanEdit(BM.me, self.pal) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: cycle default    Shift-click: clear", 0.5, 0.8, 1)
            GameTooltip:AddLine("Right-click: tank / healer / DPS overrides", 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end

    UI.rows = {}
    local function GetRow(i)
        if UI.rows[i] then return UI.rows[i] end
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(width - PAD * 2, CELL)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(TOP + HEADER_H + (i - 1) * (CELL + GAP)))

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT", 2, 0)
        row.name:SetWidth(NAME_W - 6)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.cells = {}
        for c, class in ipairs(BM.CLASSES) do
            local b = CreateFrame("Button", nil, row, "BackdropTemplate")
            b:SetSize(CELL, CELL)
            b:SetPoint("LEFT", row, "LEFT", NAME_W + (c - 1) * (CELL + GAP), 0)
            b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
            b:SetBackdropColor(0, 0, 0, 0.55)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2)
            b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.text:SetPoint("CENTER")
            b.badge = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.badge:SetPoint("BOTTOMRIGHT", -1, 1)
            b.badge:SetTextColor(1, 0.82, 0)
            b.badge:SetShadowOffset(1, -1)
            b.class = class
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", CellClick)
            b:SetScript("OnEnter", CellEnter)
            b:SetScript("OnLeave", GameTooltip_Hide)
            row.cells[c] = b
        end
        UI.rows[i] = row
        return row
    end

    UI.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    UI.empty:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -(TOP + HEADER_H + 8))
    UI.empty:SetText("No paladins in your group.")

    -----------------------------------------------------------------------
    -- Footer
    -----------------------------------------------------------------------
    UI.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.status:SetPoint("BOTTOMLEFT", PAD + 2, PAD + 30)

    local function MakeButton(text, w, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    local auto = MakeButton("Auto-assign", 96, function() BM:AutoAssign() end)
    auto:SetPoint("BOTTOMLEFT", PAD, PAD)
    local sync = MakeButton("Sync", 56, function() BM:Sync() end)
    sync:SetPoint("LEFT", auto, "RIGHT", 4, 0)
    local report = MakeButton("Post", 56, function() BM:Report() end)
    report:SetPoint("LEFT", sync, "RIGHT", 4, 0)
    local check = MakeButton("Check", 60, function() BM:Summary() end)
    check:SetPoint("LEFT", report, "RIGHT", 4, 0)


    -----------------------------------------------------------------------
    -- Refresh
    -----------------------------------------------------------------------
    function UI:Refresh()
        if not f:IsShown() then return end
        local pals = BM.paladins
        for i, pal in ipairs(pals) do
            local row = GetRow(i)
            row:Show()
            local label = BM:Short(pal)
            if pal == BM.me then
                label = label .. " |cff9d9d9d(you)|r"
            elseif not BM.hasAddon[pal] then
                label = label .. " |cff9d9d9d(no addon)|r"
            end
            row.name:SetText(label)
            row.name:SetTextColor(0.96, 0.55, 0.73)

            local editable = BM:CanEdit(BM.me, pal)
            for _, b in ipairs(row.cells) do
                b.pal = pal
                local key = BM:Get(pal, b.class)
                local badge, conflict = {}, false
                for _, role in ipairs(BM.ROLES) do
                    if BM:GetRole(pal, b.class, role) then badge[#badge + 1] = BM.ROLE_LETTER[role] end
                end
                -- Conflict: another paladin gives the same blessing to the same class+role.
                for _, other in ipairs(pals) do
                    if other ~= pal then
                        if key and BM:Get(other, b.class) == key then conflict = true end
                        for _, role in ipairs(BM.ROLES) do
                            local mineE = BM:Effective(pal, b.class, role)
                            if mineE and mineE == BM:Effective(other, b.class, role) then conflict = true end
                        end
                    end
                end
                b.conflict = conflict
                b.hasRoles = #badge > 0
                b.badge:SetText(table.concat(badge))

                if key or b.hasRoles then
                    local bl = key and BM.BLESSINGS[key]
                    local tex = bl and C_Spell.GetSpellTexture(bl.spell)
                    if not bl then
                        b.icon:Hide()
                        b.text:SetText("|cff9d9d9d-|r")
                    elseif tex then
                        b.icon:SetTexture(tex)
                        b.icon:Show()
                        b.text:SetText("")
                    else
                        b.icon:Hide()
                        b.text:SetText(bl.letter)
                    end
                    local r, g, bb = 0.35, 0.35, 0.35       -- nobody it applies to here
                    local c = BM.cells and BM.cells[pal] and BM.cells[pal][b.class]
                    if conflict then
                        r, g, bb = 1, 0, 0
                    elseif c then
                        if #c.missing > 0 then r, g, bb = 0.9, 0.2, 0.2
                        elseif c.soon > 0 then r, g, bb = 1, 0.6, 0
                        else r, g, bb = 0.2, 0.85, 0.3 end
                    end
                    b:SetBackdropBorderColor(r, g, bb, 1)
                else
                    b.icon:Hide()
                    b.text:SetText("")
                    b.badge:SetText("")
                    b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                end
                b:SetAlpha(editable and 1 or 0.7)
            end
        end
        for i = #pals + 1, #UI.rows do UI.rows[i]:Hide() end
        UI.empty:SetShown(#pals == 0)

        local n = math.max(#pals, 1)
        f:SetHeight(TOP + HEADER_H + n * (CELL + GAP) + FOOTER_H)

        if InCombatLockdown() then
            UI.status:SetText("|cffff6060In combat - tracking paused|r")
        else
            UI.status:SetText(("Missing in group: |cffffffff%d|r     Yours to cast: |cffffffff%d|r"):format(
                BM.missingTotal or 0, BM.mine and #BM.mine or 0))
        end
    end

    function UI:Toggle()
        f:SetShown(not f:IsShown())
    end

    -----------------------------------------------------------------------
    -- Secure "cast next blessing" button
    -- Attributes are only changed out of combat. Drag with right mouse button.
    -----------------------------------------------------------------------
    local cb = CreateFrame("Button", "BlessingManagerCastButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    cb:SetSize(40, 40)
    cb:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
    cb:SetBackdropBorderColor(0.96, 0.55, 0.73, 1)
    cb:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    cb:SetMovable(true)
    cb:SetClampedToScreen(true)
    cb:RegisterForDrag("RightButton")
    cb:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    cb:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        BM.db.castPoint = { p, rp, x, y }
    end)
    local cp = BM.db.castPoint
    if cp then cb:SetPoint(cp[1], UIParent, cp[2], cp[3], cp[4]) else cb:SetPoint("CENTER", 0, -180) end

    cb.icon = cb:CreateTexture(nil, "ARTWORK")
    cb.icon:SetPoint("TOPLEFT", 2, -2)
    cb.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("TOP", cb, "BOTTOM", 0, -2)
    cb.count = cb:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cb.count:SetPoint("BOTTOMRIGHT", -2, 2)

    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local e = self.target
        if e then
            GameTooltip:AddLine(BM:SpellFor(e.key))
            GameTooltip:AddLine("on " .. BM:Short(e.name) .. (e.role and (" (" .. BM.ROLE_LABEL[e.role] .. ")") or ""), 1, 1, 1)
            if e.left > 0 then
                GameTooltip:AddLine(("%d min left"):format(math.floor(e.left / 60)), 1, 0.6, 0)
            else
                GameTooltip:AddLine("missing", 1, 0.4, 0.4)
            end
        else
            GameTooltip:AddLine("Nothing to cast")
            GameTooltip:AddLine("Open /bm and assign blessings (or click Auto-assign).", 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-drag to move. Bind it under Key Bindings > AddOns.", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)

    function UI:UpdateCast()
        if InCombatLockdown() then return end
        local e = BM:PickTarget()
        cb.target = e
        if e then
            local spell = BM:SpellFor(e.key)
            cb:SetAttribute("type", "spell")
            cb:SetAttribute("spell", spell)
            cb:SetAttribute("unit", e.unit)
            cb.icon:SetTexture(C_Spell.GetSpellTexture(spell) or 134400)
            cb.icon:SetDesaturated(false)
            cb.label:SetText(BM:Short(e.name))
        else
            cb:SetAttribute("type", nil)
            cb:SetAttribute("spell", nil)
            cb:SetAttribute("unit", nil)
            cb.icon:SetTexture(C_Spell.GetSpellTexture(BM.BLESSINGS.KINGS.spell) or 134400)
            cb.icon:SetDesaturated(true)
            local assigned = false
            for _, m in ipairs(BM.roster) do
                if BM:Get(BM.me, m.class) then assigned = true break end
            end
            if BM.mine and #BM.mine > 0 then
                cb.label:SetText("|cffff8080out of range|r")
            elseif not assigned then
                cb.label:SetText("|cffffd100no assignments|r")
            else
                cb.label:SetText("all blessed")
            end
        end
        local n = BM.mine and #BM.mine or 0
        cb.count:SetText(n > 1 and n or "")
        cb:SetShown(BM.isPaladin and BM.db.showCast)
    end

    UI:UpdateCast()
end
