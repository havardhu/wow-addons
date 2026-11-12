-- Forsaken Light
-- A skin for Undead paladins: grave-green and bone art, pale holy-gold trim,
-- Morpheus lettering, and a slow golden pulse around your own frame in combat.
--
-- Safety rules this addon follows:
--   * Never moves, resizes, shows, hides or replaces a Blizzard frame.
--   * Only tints existing textures, changes fonts, and adds its OWN textures/frames.
--   * Never reads health/power values (secret in combat) - bar colouring is a texture
--     anchored to the bar's fill, so it follows the fill without knowing the number.
--   * Everything it changes is remembered and restored by /forsaken off.
--
-- Forever reorganised these frames, so parts are found by searching each frame's
-- children by name (HealthBar, ManaBar, FrameTexture, Portrait, Name...).
-- /forsaken scan prints what was found.

local ADDON = ...
local FL = CreateFrame("Frame")
_G.ForsakenLight = FL

local issecret = issecretvalue or function() return false end
local MORPHEUS = "Fonts\\MORPHEUS.TTF"
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local C = {
    bone      = { 0.93, 0.89, 0.78 },
    gold      = { 1.00, 0.84, 0.45 },
    paleGold  = { 1.00, 0.93, 0.70 },
    grave     = { 0.55, 0.88, 0.38 },
    graveDark = { 0.16, 0.32, 0.13 },
    art       = { 0.72, 0.84, 0.66 },   -- tint for frame artwork (on desaturated art)
    spirit    = { 0.35, 0.80, 0.85 },   -- mana
    blood     = { 0.72, 0.13, 0.13 },
    amber     = { 0.95, 0.70, 0.22 },
    tapped    = { 0.50, 0.50, 0.50 },
}

local UNIT_FRAMES = {
    { frame = "PlayerFrame",    unit = "player" },
    { frame = "TargetFrame",    unit = "target" },
    { frame = "FocusFrame",     unit = "focus" },
    { frame = "PetFrame",       unit = "pet" },
    { frame = "TargetFrameToT", unit = "targettarget" },
    { frame = "FocusFrameToT",  unit = "focustarget" },
    { frame = "TotemFrame" },
}

local DEFAULTS = {
    enabled = true,
    art = true,       -- tint frame artwork
    bars = true,      -- recolour health / mana
    fonts = true,     -- Morpheus names
    glow = true,      -- combat pulse on the player frame
    portraits = true, -- faint grave tint on portraits
    minimap = true,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff8fe070Forsaken|r |cffffd77aLight:|r " .. msg)
end

local function NameOf(obj)
    local n = (obj.GetDebugName and obj:GetDebugName()) or (obj.GetName and obj:GetName()) or ""
    return (n or ""):lower()
end

local function Usable(obj)
    return obj and not (obj.IsForbidden and obj:IsForbidden())
end

-- Visit every region and child frame below `frame`.
local function Walk(frame, fn, depth)
    depth = depth or 0
    if depth > 10 or not Usable(frame) then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if Usable(r) then fn(r) end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if Usable(c) then
            fn(c)
            Walk(c, fn, depth + 1)
        end
    end
end

local function EndsWith(s, suffix) return s:sub(-#suffix) == suffix end

local function Has(s, ...)
    for i = 1, select("#", ...) do
        if s:find((select(i, ...)), 1, true) then return true end
    end
    return false
end

local function Gradient(tex, c, darken)
    local r, g, b = c[1], c[2], c[3]
    local d = darken or 0.55
    tex:SetVertexColor(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        local ok = pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(r * d, g * d, b * d, 1), CreateColor(r, g, b, 1))
        if ok then return end
    end
    tex:SetVertexColor(r, g, b, 1)
end

---------------------------------------------------------------------------
-- Discovery
---------------------------------------------------------------------------

-- Returns a table describing the parts of one unit frame.
local function Discover(frame)
    local parts = { health = nil, power = nil, art = {}, portraits = {}, names = {}, levels = {} }
    Walk(frame, function(obj)
        local t = obj.GetObjectType and obj:GetObjectType()
        local n = NameOf(obj)
        if t == "StatusBar" then
            if Has(n, "prediction", "absorb", "spell", "cast", "threat") then return end
            if not parts.health and (EndsWith(n, "healthbar") or EndsWith(n, ".healthbar")) then
                parts.health = obj
            elseif not parts.power and (EndsWith(n, "manabar") or EndsWith(n, "powerbar")) then
                parts.power = obj
            end
        elseif t == "Texture" then
            if EndsWith(n, "portrait") then
                parts.portraits[#parts.portraits + 1] = obj
            elseif Has(n, "frametexture", "textureframe", "border", "frameborder")
                and not Has(n, "portrait", "mask", "flash", "status", "glow", "highlight", "pvp", "icon",
                            "prestige", "leader", "role", "threat", "absorb") then
                parts.art[#parts.art + 1] = obj
            end
        elseif t == "FontString" then
            if EndsWith(n, "name") or EndsWith(n, "nametext") then
                parts.names[#parts.names + 1] = obj
            elseif Has(n, "leveltext") then
                parts.levels[#parts.levels + 1] = obj
            end
        end
    end)
    return parts
end

---------------------------------------------------------------------------
-- Change tracking (so /forsaken off can undo everything)
---------------------------------------------------------------------------

FL.saved = { tex = {}, font = {} }

local function TintTexture(tex, c, desaturate)
    if not FL.saved.tex[tex] then
        local r, g, b, a = tex:GetVertexColor()
        FL.saved.tex[tex] = { r, g, b, a, tex:IsDesaturated() }
    end
    if desaturate then tex:SetDesaturated(true) end
    tex:SetVertexColor(c[1], c[2], c[3], 1)
end

local function RestyleFont(fs, color)
    if not FL.saved.font[fs] then
        local font, size, flags = fs:GetFont()
        local r, g, b, a = fs:GetTextColor()
        FL.saved.font[fs] = { font, size, flags, r, g, b, a }
    end
    local _, size = fs:GetFont()
    if size then fs:SetFont(MORPHEUS, size, "OUTLINE") end
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

local function RestoreAll()
    for tex, s in pairs(FL.saved.tex) do
        tex:SetVertexColor(s[1], s[2], s[3], s[4])
        tex:SetDesaturated(s[5] and true or false)
    end
    for fs, s in pairs(FL.saved.font) do
        if s[1] then fs:SetFont(s[1], s[2], s[3]) end
        fs:SetTextColor(s[4], s[5], s[6], s[7])
    end
    FL.saved = { tex = {}, font = {} }
end

---------------------------------------------------------------------------
-- Overlays (our own textures/frames)
---------------------------------------------------------------------------

-- A texture laid over a status bar's fill. Anchored to the fill texture's corners,
-- so it grows and shrinks with the bar without ever reading the value.
local function FillOverlay(bar)
    if bar.__flOverlay then return bar.__flOverlay end
    local fill = bar:GetStatusBarTexture()
    if not fill then return nil end
    local ov = bar:CreateTexture(nil, "ARTWORK", nil, 7)
    ov:SetTexture(BAR_TEX)
    ov:SetPoint("TOPLEFT", fill, "TOPLEFT")
    ov:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    -- A soft bright line along the top edge: "light seeping through".
    local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 7)
    sheen:SetColorTexture(C.paleGold[1], C.paleGold[2], C.paleGold[3], 0.25)
    sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
    sheen:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    sheen:SetHeight(1)
    ov.sheen = sheen
    bar.__flOverlay = ov
    return ov
end

-- Thin holy-gold trim around the health + power bars.
local function Trim(holder, health, power)
    if holder.__flTrim then return holder.__flTrim end
    local t = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    t:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 2)
    t:SetPoint("BOTTOMRIGHT", power or health, "BOTTOMRIGHT", 2, -2)
    t:SetFrameLevel(health:GetFrameLevel() + 3)
    t:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    t:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.85)
    -- inner dark line for depth
    t.inner = CreateFrame("Frame", nil, t, "BackdropTemplate")
    t.inner:SetPoint("TOPLEFT", 1, -1)
    t.inner:SetPoint("BOTTOMRIGHT", -1, 1)
    t.inner:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    t.inner:SetBackdropBorderColor(C.graveDark[1], C.graveDark[2], C.graveDark[3], 0.9)
    holder.__flTrim = t
    return t
end

local function Glow(trim)
    if trim.__flGlow then return trim.__flGlow end
    local g = CreateFrame("Frame", nil, trim, "BackdropTemplate")
    g:SetPoint("TOPLEFT", -6, 6)
    g:SetPoint("BOTTOMRIGHT", 6, -6)
    g:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    g:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    g:SetAlpha(0)
    local ag = g:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.15)
    a:SetToAlpha(0.75)
    a:SetDuration(1.4)
    a:SetSmoothing("IN_OUT")
    g.anim = ag
    trim.__flGlow = g
    return g
end

---------------------------------------------------------------------------
-- Colours per unit
---------------------------------------------------------------------------

local function HealthColor(unit)
    if not unit or unit == "player" or unit == "pet" then return C.grave end
    if not UnitExists(unit) then return C.grave end
    local tapped = UnitIsTapDenied and UnitIsTapDenied(unit)
    if tapped and not issecret(tapped) then return C.tapped end
    local reaction = UnitReaction(unit, "player")
    if reaction and not issecret(reaction) then
        if reaction <= 3 then return C.blood end
        if reaction == 4 then return C.amber end
    end
    return C.grave
end

local function IsMana(unit)
    if not unit or not UnitExists(unit) then return false end
    local pt = UnitPowerType(unit)
    if issecret(pt) then return false end
    return pt == ((Enum and Enum.PowerType and Enum.PowerType.Mana) or 0)
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------

FL.found = {}

function FL:SkinUnitFrame(entry)
    local frame = _G[entry.frame]
    if not Usable(frame) then return end
    local parts = self.found[entry.frame]
    if not parts then
        parts = Discover(frame)
        self.found[entry.frame] = parts
    end
    local db = self.db

    if db.art then
        for _, tex in ipairs(parts.art) do TintTexture(tex, C.art, true) end
    end
    if db.portraits then
        for _, tex in ipairs(parts.portraits) do TintTexture(tex, { 0.88, 1, 0.86 }) end
    end
    if db.fonts then
        for _, fs in ipairs(parts.names) do RestyleFont(fs, C.bone) end
        for _, fs in ipairs(parts.levels) do RestyleFont(fs, C.paleGold) end
    end

    if parts.health and db.bars then
        local ov = FillOverlay(parts.health)
        if ov then
            Gradient(ov, HealthColor(entry.unit))
            ov:Show(); ov.sheen:Show()
        end
        if parts.power then
            local pov = FillOverlay(parts.power)
            if pov then
                if IsMana(entry.unit) then
                    Gradient(pov, C.spirit)
                    pov:Show(); pov.sheen:Show()
                else
                    pov:Hide(); pov.sheen:Hide()      -- keep rage/energy/focus colours
                end
            end
        end
        local trim = Trim(frame, parts.health, parts.power)
        trim:Show()
        if entry.unit == "player" and db.glow then Glow(trim) end
    end
end

function FL:SkinMinimap()
    local mc = _G.MinimapCluster
    if not Usable(mc) or not self.db.minimap then return end
    Walk(mc, function(obj)
        local t = obj.GetObjectType and obj:GetObjectType()
        local n = NameOf(obj)
        if t == "FontString" and Has(n, "zonetext", "zone") then
            RestyleFont(obj)                 -- keep Blizzard's PvP colouring, change the lettering
        elseif t == "Texture" and Has(n, "bordertop", "border", "compass", "header")
            and not Has(n, "icon", "highlight", "glow", "mail", "tracking", "calendar") then
            TintTexture(obj, C.art, true)
        end
    end)
end

function FL:UpdateGlow()
    local parts = self.found.PlayerFrame
    local trim = _G.PlayerFrame and _G.PlayerFrame.__flTrim
    local g = trim and trim.__flGlow
    if not g then return end
    if self.db.enabled and self.db.glow and UnitAffectingCombat("player") then
        if not g.anim:IsPlaying() then g.anim:Play() end
    else
        g.anim:Stop()
        g:SetAlpha(0)
    end
end

function FL:ApplyAll()
    if not self.db.enabled then return end
    for _, entry in ipairs(UNIT_FRAMES) do
        pcall(self.SkinUnitFrame, self, entry)
    end
    pcall(self.SkinMinimap, self)
    self:UpdateGlow()
end

-- Recolour just one unit's bars (target swaps, power type changes, ...).
function FL:RecolorUnit(unit)
    if not self.db.enabled or not self.db.bars then return end
    for _, entry in ipairs(UNIT_FRAMES) do
        if entry.unit == unit then pcall(self.SkinUnitFrame, self, entry) end
    end
end

function FL:RemoveAll()
    RestoreAll()
    for _, entry in ipairs(UNIT_FRAMES) do
        local frame = _G[entry.frame]
        local parts = self.found[entry.frame]
        if parts then
            for _, bar in ipairs({ parts.health, parts.power }) do
                if bar and bar.__flOverlay then bar.__flOverlay:Hide(); bar.__flOverlay.sheen:Hide() end
            end
        end
        if frame and frame.__flTrim then
            frame.__flTrim:Hide()
            if frame.__flTrim.__flGlow then frame.__flTrim.__flGlow.anim:Stop(); frame.__flTrim.__flGlow:SetAlpha(0) end
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function FL:PLAYER_LOGIN()
    ForsakenLightDB = ForsakenLightDB or {}
    self.db = ForsakenLightDB
    for k, v in pairs(DEFAULTS) do
        if self.db[k] == nil then self.db[k] = v end
    end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
                         "UNIT_PET", "UNIT_DISPLAYPOWER", "UNIT_FACTION", "UNIT_TARGET",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        pcall(self.RegisterEvent, self, e)
    end
end

function FL:PLAYER_ENTERING_WORLD(isLogin)
    -- Give Blizzard's frames a moment to finish building their children.
    C_Timer.After(1, function() FL:ApplyAll() end)
    if isLogin and self.db.enabled then
        local _, race = UnitRace("player")
        local _, class = UnitClass("player")
        if race == "Scourge" and class == "PALADIN" then
            Print("The Light remembers you, even now.")
        end
    end
end

function FL:PLAYER_TARGET_CHANGED()
    self:RecolorUnit("target")
    self:RecolorUnit("targettarget")
end

function FL:PLAYER_FOCUS_CHANGED()
    self:RecolorUnit("focus")
    self:RecolorUnit("focustarget")
end

function FL:UNIT_TARGET(unit)
    if unit == "target" then self:RecolorUnit("targettarget")
    elseif unit == "focus" then self:RecolorUnit("focustarget") end
end

function FL:UNIT_PET(unit)
    if unit == "player" then C_Timer.After(0.2, function() FL:RecolorUnit("pet") end) end
end

function FL:UNIT_DISPLAYPOWER(unit) self:RecolorUnit(unit) end
function FL:UNIT_FACTION(unit) self:RecolorUnit(unit) end
function FL:PLAYER_REGEN_DISABLED() self:UpdateGlow() end
function FL:PLAYER_REGEN_ENABLED() self:UpdateGlow() end

FL:SetScript("OnEvent", function(self, event, ...)
    if self[event] then self[event](self, ...) end
end)
FL:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local TOGGLES = { art = "frame art tint", bars = "health/mana colours", fonts = "Morpheus names",
                  glow = "combat glow", portraits = "portrait tint", minimap = "minimap header" }

SLASH_FORSAKENLIGHT1 = "/forsaken"
SLASH_FORSAKENLIGHT2 = "/forsakenlight"
SlashCmdList.FORSAKENLIGHT = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    local db = FL.db
    if cmd == "on" then
        db.enabled = true
        FL:ApplyAll()
        Print("On.")
    elseif cmd == "off" then
        db.enabled = false
        FL:RemoveAll()
        Print("Off. Everything restored.")
    elseif TOGGLES[cmd] then
        db[cmd] = not db[cmd]
        FL:RemoveAll()
        FL:ApplyAll()
        Print("%s: %s", TOGGLES[cmd], db[cmd] and "on" or "off")
    elseif cmd == "scan" then
        wipe(FL.found)
        for _, entry in ipairs(UNIT_FRAMES) do
            local frame = _G[entry.frame]
            if frame then
                local p = Discover(frame)
                FL.found[entry.frame] = p
                Print("%s: health %s, power %s, art %d, portraits %d, names %d, levels %d", entry.frame,
                    p.health and "yes" or "|cffff6060no|r", p.power and "yes" or "no",
                    #p.art, #p.portraits, #p.names, #p.levels)
            else
                Print("%s: |cff9d9d9dnot present|r", entry.frame)
            end
        end
        FL:ApplyAll()
    else
        Print("/forsaken [on | off | art | bars | fonts | glow | portraits | minimap | scan]")
    end
end
