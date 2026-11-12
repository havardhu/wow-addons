-- Taming Info
-- A "Taming Info" button that's always on screen. Click it for a panel with everything
-- about the beast you're targeting: can it be tamed, family and type, attack speed,
-- every ability and rank it could teach, diet, whether it's a notable rare, and how
-- taming works. Works on every class, so you can scout pets on an alt.

local ADDON, ns = ...
local D = ns.D
local T = CreateFrame("Frame")
_G.TamingInfo = T

local issecret = issecretvalue or function() return false end
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 0.67, 0.83, 0.45 }   -- hunter green

local function Secret(...)
    for i = 1, select("#", ...) do
        if issecret((select(i, ...))) then return true end
    end
    return false
end

local function Fill(desc, value)
    local i = desc:find("%s", 1, true)
    if not i then return desc end
    return desc:sub(1, i - 1) .. tostring(value) .. desc:sub(i + 2)
end

local function Hex(c) return "|cff" .. c end

---------------------------------------------------------------------------
-- Target analysis
---------------------------------------------------------------------------

function T:IsHunter()
    return select(2, UnitClass("player")) == "HUNTER"
end

-- Returns status ("yes" | "high" | "no" | "dead" | "none" | "hidden"), message, info table
function T:Analyze()
    local unit = "target"
    if not UnitExists(unit) then return "none", "No target." end
    local name, level, family = UnitName(unit), UnitLevel(unit), UnitCreatureFamily(unit)
    local ctype, class = UnitCreatureType(unit), UnitClassification(unit)
    if Secret(name, level, family, ctype, class) then
        return "hidden", "Target details are hidden during combat. They update when combat ends."
    end
    local info = { name = name, level = level, family = family, ctype = ctype, class = class }

    if UnitIsPlayer(unit) then return "no", "Players can't be tamed.", info end
    local controlled = UnitPlayerControlled(unit)
    if controlled and not issecret(controlled) then
        return "no", "This is already someone's pet or a player-controlled unit.", info
    end
    if not family then return "no", "Not a tameable beast (it has no pet family).", info end
    if not D.FAMILIES[family] then
        return "no", ("%s isn't a tameable family in Forever (or isn't in this addon's data yet)."):format(family), info
    end
    local dead = UnitIsDead(unit)
    if dead and not issecret(dead) then return "dead", "It's dead. Find a living one.", info end
    if level == -1 then return "high", "Level ?? - far too high to tame.", info end

    local my = UnitLevel("player")
    if self:IsHunter() then
        if my < 10 then
            return "high", "Taming unlocks at level 10 (the hunter trainer's taming quest).", info
        end
        if level > my then
            return "high", ("You need to be level %d to tame this (you're %d)."):format(level, my), info
        end
        if UnitExists("pet") then
            return "yes", "Tameable! Stable or release your current pet first.", info
        end
        return "yes", "Tameable by you.", info
    end
    -- Test mode for non-hunters.
    local msg = ("Tameable by a level %d+ hunter."):format(math.max(level, 10))
    return (level <= my) and "yes" or "high", msg .. " |cff9d9d9d(Test mode: you're not a hunter.)|r", info
end

function T:AttackSpeed()
    if not UnitExists("target") then return nil end
    local ms = UnitAttackSpeed("target")
    if not ms or issecret(ms) or ms <= 0 then return nil end
    local label, color
    if ms < 1.95 then
        label, color = "Faster Attack - kept after taming!", "33ff55"
    elseif ms > 2.05 then
        label, color = "Slower Attack", "ff6060"
    else
        label, color = "Normal", "ffffff"
    end
    return ms, label, color
end

local STATUS_COLOR = { yes = "33ff55", high = "ffb000", no = "ff6060", dead = "9d9d9d", none = "9d9d9d", hidden = "9d9d9d" }

local CLASS_TEXT = {
    elite = "Elite", rare = "|cffc0c0ffRare|r", rareelite = "|cffc0c0ffRare Elite|r",
    worldboss = "Boss", minus = "Minor", trivial = "Trivial", normal = "",
}

---------------------------------------------------------------------------
-- Panel content (line builder with wrapping)
---------------------------------------------------------------------------

local L
local function Header(text) L[#L + 1] = { header = true, left = text } end
local function Line(left, right) L[#L + 1] = { left = left, right = right } end
local function Text(text) L[#L + 1] = { wrap = true, left = text } end
local function Gap() L[#L + 1] = { gap = true } end

local function RankLine(i, lvl, value, desc, teach)
    local mark = ""
    if teach ~= nil then
        mark = teach and " |cff33ff55<|r" or ""
    end
    local v = (value ~= "" and Fill(desc, value)) or desc
    Text(("|cffffd100Rank %d|r  |cff9d9d9d(pet lvl %d)|r  %s%s"):format(i, lvl, v, mark))
end

-- Best rank a beast of `level` could teach.
local function BestRank(ranks, level)
    local best
    for i, r in ipairs(ranks) do
        if r[1] <= level then best = i end
    end
    return best
end

local function BuildFamily(name, level)
    local f = D.FAMILIES[name]
    local t = D.TYPES[f.type]
    Header(("%s  %s%s|r%s"):format(name, Hex(t.color), f.type, f.newFamily and "  |cff33ff55NEW family|r" or ""))
    Line("Type", t.desc)
    Line("Diet", table.concat(f.diet, ", "))
    Gap()

    local s = f.special
    Header(("Unique ability: %s%s"):format(s.name,
        s.new and "  |cff33ff55new|r" or (s.updated and "  |cffffd100updated|r" or "")))
    if level then
        local best = BestRank(s.ranks, level)
        if best then
            Text(("A level %d beast can teach up to |cff33ff55rank %d|r, |cffffffffif it knows the ability|r."):format(level, best))
        else
            Text(("|cffff8080A level %d beast is too low to know this (first rank is pet level %d).|r"):format(level, s.ranks[1][1]))
        end
    end
    for i, r in ipairs(s.ranks) do
        RankLine(i, r[1], r[2], s.desc, level and r[1] <= level or nil)
    end
    if s.note then Text("|cff9d9d9d" .. s.note .. "|r") end
    if s.autocast then Text("|cff9d9d9dGuides report this may not autocast; cast it manually.|r") end
    Gap()

    Header("Other abilities")
    for _, ab in ipairs(f.secondary) do
        local sh = D.SHARED[ab]
        if sh and sh.ranks then
            local parts = {}
            for _, r in ipairs(sh.ranks) do parts[#parts + 1] = tostring(r[1]) end
            local extra = ""
            if level then
                local best = BestRank(sh.ranks, level)
                if best then
                    local r = sh.ranks[best]
                    extra = ("  |cff33ff55best from this beast: rank %d (%s)|r"):format(best, tostring(r[2]))
                else
                    extra = "  |cffff8080too low|r"
                end
            end
            Text(("|cffffffff%s|r - %s |cff9d9d9dRanks at pet level %s.|r%s"):format(
                ab, sh.short or "", table.concat(parts, "/"), extra))
        elseif sh then
            Text(("|cffffffff%s|r - %s"):format(ab, sh.desc))
        end
    end
    if f.notes then
        for _, n in ipairs(f.notes) do Text("|cff9d9d9d" .. n .. "|r") end
    end

    local rares = {}
    for rn, r in pairs(D.RARES) do
        if r.family == name then rares[#rares + 1] = { rn, r } end
    end
    if #rares > 0 then
        table.sort(rares, function(a, b) return (tonumber(a[2].level:match("%d+")) or 0) < (tonumber(b[2].level:match("%d+")) or 0) end)
        Gap()
        Header("Notable " .. name .. " to tame")
        for _, e in ipairs(rares) do
            Text(("|cffffd100%s|r |cff9d9d9d(lvl %s, %s)|r - %s"):format(e[1], e[2].level, e[2].zone, e[2].why))
        end
    end
end

local function BuildTarget()
    local status, msg, info = T:Analyze()
    if status == "none" then
        Header("No target")
        Text("Target a beast to see whether it can be tamed, its family, attack speed, and every ability it could teach.")
        Text("Or pick a family on the left to browse.")
        return
    end
    if status == "hidden" then
        Header("In combat")
        Text(msg)
        return
    end

    Header(info.name)
    local lvl = info.level == -1 and "??" or tostring(info.level)
    local ctext = CLASS_TEXT[info.class or "normal"] or ""
    Line("Level", lvl .. (ctext ~= "" and ("  " .. ctext) or ""))
    Line("Creature type", info.ctype or "?")
    Line("Pet family", info.family or "none")
    Text(Hex(STATUS_COLOR[status]) .. msg .. "|r")

    local rare = D.RARES[info.name]
    if rare then
        Text(("|cffffd100Notable beast:|r %s"):format(rare.why))
    end

    local ms, label, color = T:AttackSpeed()
    if ms then
        Line("Attack speed", ("|cff%s%.2f sec|r"):format(color, ms))
        Text(("|cff%s%s|r |cff9d9d9d(Debuffs like Thunder Clap slow it temporarily.)|r"):format(color, label))
    end
    local hp = UnitHealthMax("target")
    if hp and not issecret(hp) and hp > 0 then Line("Max health", tostring(hp)) end

    if info.family and D.FAMILIES[info.family] then
        Gap()
        Header("This beast's skills")
        local b = T:LookupBeast("target")
        local skills = T:SkillList(b)
        if #skills > 0 then
            for _, sk in ipairs(skills) do
                Text(("%s%s|r%s  |cff%s%s|r  |cff9d9d9d%s|r"):format(sk.special and "|cffffd100" or "|cffffffff", sk.ability,
                    (sk.rank and sk.rank > 0) and (" " .. sk.rank) or "", sk.color, sk.label, T:SourceText(sk.source)))
            end
        else
            Text("|cff9d9d9dNot recorded yet. Beast Lore (hunters, level 24+), taming it, or watching it fight will record them.|r")
            local could = T:CouldKnow(info.family, info.level)
            local parts = {}
            for _, c in ipairs(could) do
                parts[#parts + 1] = c.ability .. (c.rank and (" up to " .. c.rank) or "")
            end
            if #parts > 0 then Text("Could know: " .. table.concat(parts, ", ")) end
        end
        if not T:IsHunter() then
            Text("|cff9d9d9dTest mode: NEW / known is compared with this character's teachable skills.|r")
        end
        Gap()
        BuildFamily(info.family, info.level ~= -1 and info.level or nil)
    end
end

local function BuildJournal()
    Header("Skills this character can teach")
    local known, list = T:Known(), {}
    for ab, r in pairs(known) do list[#list + 1] = { ab, r } end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    if #list == 0 then
        Text("|cff9d9d9dNone recorded yet. Open Beast Training once, or learn a skill from a tamed beast, and it fills in. You can also add one by hand: /taming know Bite 3|r")
    else
        local parts = {}
        for _, e in ipairs(list) do parts[#parts + 1] = ("%s %d"):format(e[1], e[2]) end
        Text(table.concat(parts, ", "))
    end
    Gap()
    local byFamily = T:JournalEntries()
    local fams = {}
    for f in pairs(byFamily) do fams[#fams + 1] = f end
    table.sort(fams)
    if #fams == 0 then
        Header("Recorded beasts")
        Text("|cff9d9d9dNothing recorded yet. Cast Beast Lore on beasts, tame them, or watch them fight.|r")
        return
    end
    for _, fam in ipairs(fams) do
        Header(fam)
        table.sort(byFamily[fam], function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)
        for _, b in ipairs(byFamily[fam]) do
            local lvl = b.minLevel and (b.minLevel == b.maxLevel and tostring(b.minLevel) or (b.minLevel .. "-" .. b.maxLevel)) or "?"
            local parts = {}
            for _, sk in ipairs(T:SkillList(b)) do
                parts[#parts + 1] = ("%s%s |cff%s%s|r"):format(sk.ability, (sk.rank and sk.rank > 0) and (" " .. sk.rank) or "",
                    sk.color, sk.label == "known" and "" or sk.label)
            end
            Text(("|cffffffff%s|r |cff9d9d9d(lvl %s%s)|r: %s"):format(b.name or "?", lvl, b.zone and (", " .. b.zone) or "",
                table.concat(parts, ", ")))
        end
        Gap()
    end
end

local function BuildGuide()
    Header("Taming rules")
    for _, s in ipairs(D.RULES) do Text("- " .. s) end
    Gap()
    Header("Attack speed")
    for _, s in ipairs(D.SPEED) do Text("- " .. s) end
    Gap()
    Header("Learning abilities from wild beasts")
    for _, s in ipairs(D.LEARNING) do Text(s) end
    Gap()
    Header("Happiness & loyalty")
    for _, s in ipairs(D.HAPPY) do Text("- " .. s) end
    Gap()
    Header("Pet types")
    for _, k in ipairs({ "Offensive", "Balanced", "Defensive" }) do
        Line(Hex(D.TYPES[k].color) .. k .. "|r", D.TYPES[k].desc)
    end
    Gap()
    Text("|cff9d9d9dData from WoW: Forever beta-era guides. Numbers may change with patches.|r")
end

local function BuildRares()
    Header("Notable beasts")
    local list = {}
    for name, r in pairs(D.RARES) do list[#list + 1] = { name, r } end
    table.sort(list, function(a, b)
        local la, lb = tonumber(a[2].level:match("%d+")) or 0, tonumber(b[2].level:match("%d+")) or 0
        if la ~= lb then return la < lb end
        return a[1] < b[1]
    end)
    for _, e in ipairs(list) do
        Text(("|cffffd100%s|r  %s, lvl %s, %s"):format(e[1], e[2].family, e[2].level, e[2].zone))
        Text("|cff9d9d9d   " .. e[2].why .. "|r")
    end
    Gap()
    Text("|cff9d9d9dPopular rares get camped. Some, like The Rake and Ghostfang, respawn in about 30 minutes.|r")
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local panel, rows, content, list
local PANEL_W, PANEL_H, LIST_W = 600, 560, 150
local selected = "target"

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, content)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.left:SetJustifyH("LEFT")
    r.left:SetJustifyV("TOP")
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetJustifyH("RIGHT")
    rows[i] = r
    return r
end

local function Render()
    local width = content:GetWidth()
    local y = 0
    for i, e in ipairs(L) do
        local r = Row(i)
        r:Show()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetWidth(width)
        r.left:ClearAllPoints()
        r.right:ClearAllPoints()
        r.left:SetPoint("TOPLEFT", 4, -2)
        local h = 16
        if e.gap then
            r.left:SetText("")
            r.right:SetText("")
            h = 8
        elseif e.header then
            r.left:SetFontObject("GameFontNormal")
            r.left:SetWidth(width - 8)
            r.left:SetWordWrap(true)
            r.left:SetText(e.left)
            r.right:SetText("")
            h = math.max(18, r.left:GetStringHeight() + 4)
        elseif e.wrap then
            r.left:SetFontObject("GameFontHighlightSmall")
            r.left:SetWidth(width - 12)
            r.left:SetWordWrap(true)
            r.left:SetText(e.left)
            r.right:SetText("")
            h = math.max(16, r.left:GetStringHeight() + 4)
        else
            r.left:SetFontObject("GameFontNormalSmall")
            r.left:SetWidth(120)
            r.left:SetWordWrap(false)
            r.left:SetText(e.left)
            r.right:SetPoint("TOPLEFT", 128, -2)
            r.right:SetWidth(width - 134)
            r.right:SetJustifyH("LEFT")
            r.right:SetWordWrap(true)
            r.right:SetText(e.right or "")
            h = math.max(16, r.right:GetStringHeight() + 4)
        end
        r:SetHeight(h)
        y = y + h
    end
    for i = #L + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(y, 10))
end

local LIST_ITEMS

local function RefreshList()
    for _, b in ipairs(list.buttons) do b.bg:SetShown(b.key == selected) end
end

function T:Refresh()
    if not panel or not panel:IsShown() then return end
    L = {}
    if selected == "target" then
        BuildTarget()
    elseif selected == "guide" then
        BuildGuide()
    elseif selected == "rares" then
        BuildRares()
    elseif selected == "journal" then
        BuildJournal()
    elseif D.FAMILIES[selected] then
        BuildFamily(selected, nil)
    end
    Render()
    RefreshList()
end

local function BuildPanel()
    panel = CreateFrame("Frame", "TamingInfoPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.05, 0.06, 0.05, 0.96)
    panel:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        T.db.panelPoint = { p, rp, x, y }
    end)
    local pp = T.db.panelPoint
    if pp then panel:SetPoint(pp[1], UIParent, pp[2], pp[3], pp[4]) else panel:SetPoint("CENTER") end
    panel:Hide()
    tinsert(UISpecialFrames, "TamingInfoPanel")
    panel:SetScript("OnShow", function() T:Refresh() end)

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 12, -9)
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("Taming Info")
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- Left list
    list = { buttons = {} }
    LIST_ITEMS = { { "target", "|cff33ff55Current target|r" }, { "guide", "How taming works" },
                   { "rares", "Notable beasts" },
                   { "journal", "Beast journal" }, { "-", "" } }
    for _, name in ipairs(D.ORDER) do LIST_ITEMS[#LIST_ITEMS + 1] = { name, name } end
    local listFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 10, -40)
    listFrame:SetPoint("BOTTOMLEFT", 10, 12)
    listFrame:SetWidth(LIST_W)
    listFrame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    listFrame:SetBackdropColor(0, 0, 0, 0.35)
    listFrame:SetBackdropBorderColor(0.25, 0.3, 0.25, 1)
    local y = -4
    for _, item in ipairs(LIST_ITEMS) do
        if item[1] == "-" then
            y = y - 8
        else
            local b = CreateFrame("Button", nil, listFrame)
            b:SetSize(LIST_W - 8, 20)
            b:SetPoint("TOPLEFT", 4, y)
            b.key = item[1]
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", 6, 0)
            local fam = D.FAMILIES[item[1]]
            if fam then
                fs:SetText(item[2] .. " " .. Hex(D.TYPES[fam.type].color) .. "\194\183|r")
            else
                fs:SetText(item[2])
            end
            b:SetScript("OnClick", function(self)
                selected = self.key
                T:Refresh()
            end)
            list.buttons[#list.buttons + 1] = b
            y = y - 20
        end
    end

    -- Right scroll area
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 12, 0)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    content = CreateFrame("Frame", nil, sf)
    content:SetSize(PANEL_W - LIST_W - 62, 10)
    sf:SetScrollChild(content)
    rows = {}
end

function T:Toggle()
    if not panel then BuildPanel() end
    if panel:IsShown() then panel:Hide() else
        selected = "target"
        panel:Show()
    end
end

function T:ShowFamily(name)
    if not panel then BuildPanel() end
    selected = name
    panel:Show()
    self:Refresh()
end

---------------------------------------------------------------------------
-- Always-visible button
---------------------------------------------------------------------------

local button

local function BuildButton()
    button = CreateFrame("Button", "TamingInfoButton", UIParent, "BackdropTemplate")
    button:SetSize(112, 26)
    button:SetFrameStrata("MEDIUM")
    button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    button:SetBackdropColor(0.05, 0.07, 0.04, 0.85)
    button:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        T.db.buttonPoint = { p, rp, x, y }
    end)
    local bp = T.db.buttonPoint
    if bp then button:SetPoint(bp[1], UIParent, bp[2], bp[3], bp[4]) else button:SetPoint("TOP", 0, -120) end

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("LEFT", 3, 0)
    button.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
    button.text:SetText("Taming Info")
    button.dot = button:CreateTexture(nil, "OVERLAY")
    button.dot:SetSize(8, 8)
    button.dot:SetPoint("RIGHT", -5, 0)
    button.dot:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Skills box under the button.
    local mini = CreateFrame("Frame", nil, button, "BackdropTemplate")
    mini:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    mini:SetWidth(220)
    mini:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    mini:SetBackdropColor(0.04, 0.05, 0.03, 0.85)
    mini:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
    mini.lines = {}
    mini:Hide()
    button.mini = mini

    button:SetScript("OnClick", function() T:Toggle() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Taming Info")
        local status, msg, info = T:Analyze()
        if info and info.family then
            GameTooltip:AddLine(("%s - %s"):format(info.name, info.family), 1, 1, 1)
        end
        local c = STATUS_COLOR[status]
        GameTooltip:AddLine(msg, tonumber(c:sub(1, 2), 16) / 255, tonumber(c:sub(3, 4), 16) / 255, tonumber(c:sub(5, 6), 16) / 255, true)
        local ms = T:AttackSpeed()
        if ms then GameTooltip:AddLine(("Attack speed: %.2f"):format(ms), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: open panel   Drag: move", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetShown(T.db.showButton)
end

function T:UpdateMini()
    local mini = button and button.mini
    if not mini then return end
    local status, _, info = self:Analyze()
    if status == "hidden" then return end            -- keep showing the last target in combat
    if not self.db.showSkills or not button:IsShown() or not info or not info.family
        or not D.FAMILIES[info.family] or UnitIsPlayer("target") then
        mini:Hide()
        return
    end
    local controlled = UnitPlayerControlled("target")
    if controlled and not issecret(controlled) then mini:Hide() return end

    local texts = {}
    local b = self:LookupBeast("target")
    local skills = self:SkillList(b)
    texts[#texts + 1] = ("|cffaad372Skills|r |cff9d9d9d%s, level %s|r"):format(info.family, info.level == -1 and "??" or info.level)
    if #skills > 0 then
        for _, sk in ipairs(skills) do
            texts[#texts + 1] = ("%s%s|r%s  |cff%s%s|r"):format(sk.special and "|cffffd100" or "|cffffffff", sk.ability,
                (sk.rank and sk.rank > 0) and (" " .. sk.rank) or "", sk.color, sk.label)
        end
        texts[#texts + 1] = "|cff9d9d9d" .. self:SourceText(skills[1].source) .. "|r"
    else
        texts[#texts + 1] = "|cff9d9d9dNo skills recorded for this beast yet.|r"
        if self:IsHunter() and UnitLevel("player") >= 24 then
            texts[#texts + 1] = "|cff9d9d9dCast Beast Lore on it to reveal them.|r"
        elseif self:IsHunter() then
            texts[#texts + 1] = "|cff9d9d9dTame it or watch it fight to record them.|r"
        end
        local parts = {}
        for _, c in ipairs(self:CouldKnow(info.family, info.level)) do
            parts[#parts + 1] = c.ability .. (c.rank and (" <=" .. c.rank) or "")
        end
        if #parts > 0 then texts[#texts + 1] = "Could know: " .. table.concat(parts, ", ") end
    end
    if not self:IsHunter() then texts[#texts + 1] = "|cff9d9d9dTest mode (not a hunter)|r" end

    local y = -5
    for i, t in ipairs(texts) do
        local fs = mini.lines[i]
        if not fs then
            fs = mini:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetWidth(208)
            mini.lines[i] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 6, y)
        fs:SetText(t)
        fs:Show()
        y = y - fs:GetStringHeight() - 3
    end
    for i = #texts + 1, #mini.lines do mini.lines[i]:Hide() end
    mini:SetHeight(-y + 3)
    mini:Show()
end

function T:UpdateButton()
    if not button then return end
    self:UpdateMini()
    local status = self:Analyze()
    local c = STATUS_COLOR[status] or "666666"
    if status == "none" then c = "666666" end
    button.dot:SetColorTexture(tonumber(c:sub(1, 2), 16) / 255, tonumber(c:sub(3, 4), 16) / 255, tonumber(c:sub(5, 6), 16) / 255, 1)
end

---------------------------------------------------------------------------
-- Tooltip hint on beasts
---------------------------------------------------------------------------

local function AddTooltipLine(tt, data)
    if not T.db or not tt.GetUnit then return end
    local ok, _, unit = pcall(tt.GetUnit, tt)
    if not ok or not unit or issecret(unit) then return end
    if data and T.ScanTooltipData then pcall(T.ScanTooltipData, T, unit, data) end
    if not T.db.tooltip then return end
    local family = UnitCreatureFamily(unit)
    if not family or issecret(family) or UnitIsPlayer(unit) then return end
    local f = D.FAMILIES[family]
    if not f then return end
    local controlled = UnitPlayerControlled(unit)
    if controlled and not issecret(controlled) then return end
    local line = ("|cffaad372Tameable|r %s %s%s|r"):format(family, Hex(D.TYPES[f.type].color), f.type)
    local name = UnitName(unit)
    if name and not issecret(name) and D.RARES[name] then line = line .. "  |cffffd100notable|r" end
    local ms = UnitAttackSpeed(unit)
    if ms and not issecret(ms) and ms > 0 and (ms < 1.95 or ms > 2.05) then
        line = line .. (ms < 1.95 and ("  |cff33ff55%.1f speed|r") or ("  |cffff6060%.1f speed|r")):format(ms)
    end
    tt:AddLine(line)
    local b = T.LookupBeast and T:LookupBeast(unit)
    if b then
        local parts = {}
        for _, sk in ipairs(T:SkillList(b)) do
            parts[#parts + 1] = ("%s%s%s"):format(sk.ability, (sk.rank and sk.rank > 0) and (" " .. sk.rank) or "",
                sk.label == "known" and "" or (" |cff" .. sk.color .. sk.label .. "|r"))
        end
        if #parts > 0 then tt:AddLine("Teaches: " .. table.concat(parts, ", "), 1, 1, 1, true) end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function T:PLAYER_LOGIN()
    TamingInfoDB = TamingInfoDB or {}
    self.db = TamingInfoDB
    if self.db.showButton == nil then self.db.showButton = true end
    if self.db.tooltip == nil then self.db.tooltip = true end
    if self.db.showSkills == nil then self.db.showSkills = true end
    self:InitJournal()

    BuildButton()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddTooltipLine)
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", AddTooltipLine)
    end
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "UNIT_PET", "PLAYER_LEVEL_UP",
                         "UNIT_CLASSIFICATION_CHANGED", "CHAT_MSG_SYSTEM", "CRAFT_SHOW", "CRAFT_UPDATE",
                         "UNIT_SPELLCAST_SUCCEEDED", "PET_BAR_UPDATE" }) do
        pcall(self.RegisterEvent, self, e)
    end
    self:UpdateButton()
end

function T:PLAYER_TARGET_CHANGED()
    if self.ScanTargetTooltip then self:ScanTargetTooltip() end
    self:UpdateButton()
    if selected == "target" then self:Refresh() end
end
T.PLAYER_REGEN_ENABLED = T.PLAYER_TARGET_CHANGED

function T:UNIT_PET(unit)
    if unit == "player" then C_Timer.After(1, function() T:ScanPet() end) end
    self:PLAYER_TARGET_CHANGED()
end
function T:PET_BAR_UPDATE() C_Timer.After(0.5, function() T:ScanPet() end) end
function T:CHAT_MSG_SYSTEM(msg) self:OnSystemMessage(msg) end
function T:CRAFT_SHOW() self:ScanBeastTraining() end
T.CRAFT_UPDATE = T.CRAFT_SHOW
function T:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID) self:OnUnitCast(unit, spellID) end
T.PLAYER_LEVEL_UP = T.PLAYER_TARGET_CHANGED
function T:UNIT_CLASSIFICATION_CHANGED(unit) if unit == "target" then self:PLAYER_TARGET_CHANGED() end end

T:SetScript("OnEvent", function(self, event, ...)
    if self[event] then self[event](self, ...) end
end)
T:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_TAMINGINFO1 = "/taming"
SLASH_TAMINGINFO2 = "/tame"
SlashCmdList.TAMINGINFO = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local lower = msg:lower()
    if lower == "" then
        T:Toggle()
    elseif lower == "button" then
        T.db.showButton = not T.db.showButton
        button:SetShown(T.db.showButton)
    elseif lower == "skills" then
        T.db.showSkills = not T.db.showSkills
        T:UpdateButton()
    elseif lower:match("^know ") or lower:match("^forget ") then
        local verb, rest = msg:match("^(%S+)%s+(.+)$")
        local rank = tonumber(rest:match("(%d+)%s*$"))
        local name = rest:gsub("%s*%d+%s*$", "")
        local canon = T.ABILITIES[name:lower()]
        if not canon then print("Taming Info: unknown ability '" .. name .. "'.") return end
        if verb:lower() == "forget" then T:SetKnown(canon, false) else T:SetKnown(canon, rank or 1) end
        T:OnJournalChanged()
        print(("Taming Info: %s %s."):format(canon, verb:lower() == "forget" and "removed" or ("rank " .. (rank or 1) .. " marked as known")))
    elseif lower == "tooltip" then
        T.db.tooltip = not T.db.tooltip
        print("Taming Info tooltip hint: " .. (T.db.tooltip and "on" or "off"))
    elseif lower == "reset" then
        T.db.buttonPoint, T.db.panelPoint = nil, nil
        button:ClearAllPoints()
        button:SetPoint("TOP", 0, -120)
    else
        for _, name in ipairs(D.ORDER) do
            if name:lower():find(lower, 1, true) then T:ShowFamily(name) return end
        end
        print("Taming Info: /taming [family name | button | skills | tooltip | know <ability> <rank> | forget <ability> | reset]")
    end
end
