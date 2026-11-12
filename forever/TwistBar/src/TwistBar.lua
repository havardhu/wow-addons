-- Twist Bar
-- One line for Retribution paladins in WoW: Forever:
--   [Seal] [Echo] [======= swing timer =======] [Judgement] [Strike]
--
-- What drives what:
--   Swing bar   PLAYER_SWING (Forever's own swing event) gives swing start + duration.
--   GCD marker  Shows where your global cooldown ends on the swing bar, so you can see
--               whether a reseal fits before the next swing.
--   Seal/Echo   Your seal, and the Echo that Twist of Light leaves when you replace
--               Command / Righteousness / Fury / Justice. Read from your buffs when the
--               client allows it, otherwise predicted from your own casts and swings.
--   Cooldowns   Judgement and Holy Strike via duration objects, which Cooldown frames
--               accept even when the values are secret.
--
-- It never tells you when to press anything. It shows state; you make the call.

local ADDON = ...
local T = CreateFrame("Frame", "TwistBarCore")
_G.TwistBar = T

local issecret = issecretvalue or function() return false end
local GetTime = GetTime

local MAINHAND = (Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand) or 0

-- Seals whose replacement leaves an Echo (Twist of Light).
local TWISTABLE = { Command = true, Righteousness = true, Fury = true, Justice = true }

local SEAL_COLORS = {
    Command       = { 1.00, 0.45, 0.15 },
    Righteousness = { 1.00, 0.82, 0.25 },
    Fury          = { 0.95, 0.20, 0.20 },
    Justice       = { 0.70, 0.45, 1.00 },
    Crusader      = { 1.00, 0.95, 0.60 },
    Light         = { 1.00, 1.00, 0.80 },
    Wisdom        = { 0.40, 0.65, 1.00 },
}
local NO_SEAL_COLOR = { 0.45, 0.45, 0.45 }

local DEFAULTS = {
    scale = 1,
    visibility = "smart",   -- smart | always | combat
    strike = true,          -- show Holy Strike / Crusader Strike cooldown
    gcdMarker = true,
    locked = true,
    learned = { seals = {}, echoes = {} },   -- [shortName] = spellId
}

local function Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cfff58cbaTwist Bar:|r " .. msg)
end

-- "Seal of Command" -> "Command"; "Echo of Command" -> "Command"
local function SealShort(name)
    if not name or issecret(name) then return nil end
    return name:match("^Seal of (.+)$")
end
local function EchoShort(name)
    if not name or issecret(name) then return nil end
    return name:match("^Echo of (.+)$")
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local ICON = 30
local BAR_W, BAR_H = 230, 20
local PADX = 4

local f = CreateFrame("Frame", "TwistBarFrame", UIParent, "BackdropTemplate")
f:SetSize(ICON * 4 + BAR_W + PADX * 6, ICON + 8)
f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
f:SetBackdropColor(0, 0, 0, 0.45)
f:SetBackdropBorderColor(0, 0, 0, 0.9)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) if not T.db.locked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    T.db.point = { p, rp, x, y }
end)
f:Hide()

local function MakeIcon(parent, label)
    local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    b:SetSize(ICON, ICON)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetDrawEdge(false)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.label:SetText(label or "")
    b.label:SetTextColor(0.8, 0.8, 0.8)
    b:EnableMouse(true)
    return b
end

local seal = MakeIcon(f)
seal:SetPoint("LEFT", PADX, 0)
seal.cd:SetReverse(true)
-- Stack count of the active seal (Echo stacks), bottom-right like an action button.
-- Parented to the cooldown so it draws above the swipe.
seal.count = seal.cd:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
seal.count:SetPoint("BOTTOMRIGHT", seal, "BOTTOMRIGHT", -1, 2)
seal.count:SetJustifyH("RIGHT")

local echo = MakeIcon(f)
echo:SetPoint("LEFT", seal, "RIGHT", PADX, 0)
echo.text = echo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
echo.text:SetPoint("CENTER", 0, 0)
echo.text:SetShadowOffset(1, -1)

-- Swing bar
local bar = CreateFrame("StatusBar", nil, f, "BackdropTemplate")
bar:SetSize(BAR_W, BAR_H)
bar:SetPoint("LEFT", echo, "RIGHT", PADX + 2, 0)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
bar:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
bar:SetBackdropBorderColor(0, 0, 0, 1)

bar.spark = bar:CreateTexture(nil, "OVERLAY")
bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
bar.spark:SetBlendMode("ADD")
bar.spark:SetSize(14, BAR_H * 2)
bar.spark:Hide()

bar.gcd = bar:CreateTexture(nil, "OVERLAY")
bar.gcd:SetColorTexture(1, 1, 1, 0.9)
bar.gcd:SetSize(2, BAR_H)
bar.gcd:Hide()

bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bar.left:SetPoint("LEFT", 4, 0)
bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bar.right:SetPoint("RIGHT", -4, 0)
bar.center = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bar.center:SetPoint("CENTER", 0, 0)

bar.stats = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bar.stats:SetPoint("TOP", bar, "BOTTOM", 0, -3)
bar.stats:SetTextColor(0.8, 0.8, 0.8)

local judge = MakeIcon(f)
judge:SetPoint("LEFT", bar, "RIGHT", PADX + 2, 0)

local strike = MakeIcon(f)
strike:SetPoint("LEFT", judge, "RIGHT", PADX, 0)

local function Tooltip(frame, fn)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        fn(GameTooltip)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

T.seal = nil          -- short name of the active seal, e.g. "Command"
T.echo = nil          -- short name of the pending Echo
T.swingStart, T.swingDur = 0, 0
T.swings, T.twisted = 0, 0

function T:HasTwist()
    if self.db.forceTwist ~= nil then return self.db.forceTwist end
    if self.db.sawEcho then return true end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo("Twist of Light")
    if info and info.spellID and IsPlayerSpell then return IsPlayerSpell(info.spellID) end
    return false
end

-- Full scan of the player's buffs by name. Returns false if names are secret.
function T:ScanAuras()
    local foundSeal, foundEcho
    local sealAura
    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not a then break end
        if issecret(a.name) then return false end
        local s, e = SealShort(a.name), EchoShort(a.name)
        if s then
            foundSeal, sealAura = s, a
            if a.spellId and not issecret(a.spellId) then self.db.learned.seals[s] = a.spellId end
        elseif e then
            foundEcho = e
            self.db.sawEcho = true
            if a.spellId and not issecret(a.spellId) then self.db.learned.echoes[e] = a.spellId end
        end
    end
    self.seal, self.echo = foundSeal, foundEcho
    self.sealAuraInstance = sealAura and sealAura.auraInstanceID
    self.sealStacks = sealAura and sealAura.applications
    return true
end

-- In-combat fallback: check auras by the spell IDs learned earlier.
local function HasAura(spellId)
    if not spellId or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    if not ok then return nil end
    return a or false
end

function T:CheckLearned()
    local learned = self.db.learned
    local any = false
    local foundSeal, foundEcho, inst
    for s, id in pairs(learned.seals) do
        local a = HasAura(id)
        if a == nil then return false end
        any = true
        if a then foundSeal, inst, self.sealStacks = s, a.auraInstanceID, a.applications end
    end
    for e, id in pairs(learned.echoes) do
        local a = HasAura(id)
        if a then foundEcho = e end
    end
    if not any then return false end
    self.seal = foundSeal
    self.sealAuraInstance = inst
    if not foundSeal then self.sealStacks = nil end
    -- Only trust echo absence if we know at least one echo ID.
    if next(learned.echoes) then self.echo = foundEcho end
    return true
end

function T:RefreshAuras()
    if not self:ScanAuras() then self:CheckLearned() end
    self:UpdateSeal()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function SetCooldownSafe(cd, spell, ignoreGCD)
    if C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spell, ignoreGCD)
        if ok and dur then
            cd:SetCooldownFromDurationObject(dur)
            return
        end
    end
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spell)
    if info and not issecret(info.startTime) and not issecret(info.duration) then
        if info.duration > 1.5 or not ignoreGCD then
            cd:SetCooldown(info.startTime, info.duration)
        else
            cd:Clear()
        end
    end
end

-- Stack text for the seal. Uses the game's display helper when it exists, because the
-- count can be a secret value in combat; otherwise shows the plain count when readable.
function T:SealStackText()
    local inst = self.sealAuraInstance
    if inst and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", inst, 1, 99)
        if ok and text ~= nil then return text end
    end
    local n = self.sealStacks
    if n == nil then return "" end
    if issecret(n) then return n end      -- FontStrings may display secret values as-is
    return n > 0 and tostring(n) or ""
end

function T:UpdateSeal()
    local s = self.seal
    if s then
        seal.icon:SetTexture(C_Spell.GetSpellTexture("Seal of " .. s) or 134400)
        seal.icon:SetDesaturated(false)
        local c = SEAL_COLORS[s] or NO_SEAL_COLOR
        seal:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        bar:SetStatusBarColor(c[1], c[2], c[3])
        seal.label:SetText(s)
        local ok = pcall(seal.count.SetText, seal.count, self:SealStackText())
        if not ok then seal.count:SetText("") end
        -- Seal duration swipe (duration objects are fine with secret values).
        local inst = self.sealAuraInstance
        if inst and C_UnitAuras.GetAuraDuration and seal.cd.SetCooldownFromDurationObject then
            local ok, dur = pcall(C_UnitAuras.GetAuraDuration, "player", inst)
            if ok and dur then seal.cd:SetCooldownFromDurationObject(dur) else seal.cd:Clear() end
        else
            seal.cd:Clear()
        end
    else
        seal.icon:SetTexture(C_Spell.GetSpellTexture("Seal of Righteousness") or 134400)
        seal.icon:SetDesaturated(true)
        seal:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
        bar:SetStatusBarColor(NO_SEAL_COLOR[1], NO_SEAL_COLOR[2], NO_SEAL_COLOR[3])
        seal.label:SetText("|cffff6060no seal|r")
        seal.count:SetText("")
        seal.cd:Clear()
    end

    local hasTwist = self:HasTwist()
    echo:SetShown(hasTwist)
    if self.echo then
        echo.icon:SetTexture(C_Spell.GetSpellTexture("Seal of " .. self.echo) or 134400)
        echo.icon:SetDesaturated(false)
        echo.icon:SetAlpha(1)
        echo:SetBackdropBorderColor(0.2, 1, 0.3, 1)
        echo.label:SetText("|cff33ff55echo|r")
        echo.text:SetText("")
    else
        echo.icon:SetTexture(C_Spell.GetSpellTexture("Seal of Command") or 134400)
        echo.icon:SetDesaturated(true)
        echo.icon:SetAlpha(0.35)
        echo:SetBackdropBorderColor(0, 0, 0, 1)
        echo.label:SetText("")
        echo.text:SetText("")
    end
    self:UpdateStats()
end

function T:UpdateStats()
    if self:HasTwist() and self.swings > 0 then
        bar.stats:SetText(("twisted %d/%d swings (%d%%)"):format(self.twisted, self.swings,
            math.floor(self.twisted / self.swings * 100 + 0.5)))
    else
        bar.stats:SetText("")
    end
end

function T:UpdateCooldowns()
    SetCooldownSafe(judge.cd, "Judgement", true)
    if self.strikeSpell then SetCooldownSafe(strike.cd, self.strikeSpell, true) end
end

function T:PickStrike()
    self.strikeSpell = nil
    if not self.db.strike then strike:Hide() return end
    for _, name in ipairs({ "Holy Strike", "Crusader Strike", "Hammer of the Righteous" }) do
        local info = C_Spell.GetSpellInfo(name)
        if info and (not IsPlayerSpell or IsPlayerSpell(info.spellID)) then
            self.strikeSpell = name
            break
        end
    end
    strike:SetShown(self.strikeSpell ~= nil)
    if self.strikeSpell then
        strike.icon:SetTexture(C_Spell.GetSpellTexture(self.strikeSpell) or 134400)
    end
end

-- Swing bar animation (our own numbers from PLAYER_SWING; nothing secret here).
local throttle = 0
f:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    local dur = T.swingDur
    local p = 0
    if dur > 0 then p = (now - T.swingStart) / dur end

    if dur > 0 and p < 1.25 then
        local v = math.min(p, 1)
        bar:SetValue(v)
        bar.spark:Show()
        bar.spark:SetPoint("CENTER", bar, "LEFT", v * BAR_W, 0)
        local left = math.max(dur - (now - T.swingStart), 0)
        bar.right:SetText(("%.1f"):format(left))
        bar.left:SetText(("%.2f"):format(dur))
    else
        bar:SetValue(0)
        bar.spark:Hide()
        bar.right:SetText("")
        local speed = UnitAttackSpeed and UnitAttackSpeed("player")
        bar.left:SetText((speed and not issecret(speed)) and ("%.2f"):format(speed) or "")
    end

    throttle = throttle + elapsed
    if throttle < 0.05 then return end
    throttle = 0

    -- GCD marker: where your GCD ends relative to the current swing.
    bar.gcd:Hide()
    if T.db.gcdMarker and dur > 0 and p < 1 and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(61304)   -- the global cooldown spell
        if info and not issecret(info.startTime) and not issecret(info.duration) and info.duration > 0 then
            local gcdEnd = info.startTime + info.duration
            local pos = (gcdEnd - T.swingStart) / dur
            if pos > p and pos < 1 then
                bar.gcd:SetPoint("CENTER", bar, "LEFT", pos * BAR_W, 0)
                bar.gcd:Show()
            end
        end
    end

    -- Out of melee range tint.
    if C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange then
        local ok, inRange = pcall(C_SwingTimer.IsTargetWithinSwingRange, MAINHAND)
        if ok and inRange == false and not issecret(inRange) then
            bar.center:SetText("|cffff5050out of range|r")
        else
            bar.center:SetText("")
        end
    end
end)

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------

function T:UpdateVisibility()
    if not self.isPaladin then f:Hide() return end
    local mode = self.db.visibility
    local show
    if mode == "always" then
        show = true
    elseif mode == "combat" then
        show = UnitAffectingCombat("player")
    else
        show = UnitAffectingCombat("player") or (UnitExists("target") and UnitCanAttack("player", "target"))
            or not self.db.locked
    end
    if issecret(show) then show = true end
    f:SetShown(show and true or false)
    f:SetAlpha(UnitAffectingCombat("player") and 1 or 0.75)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function T:PLAYER_SWING(dur, swingType)
    if not issecret(swingType) and swingType ~= MAINHAND then return end
    if issecret(dur) or not dur or dur <= 0 then
        local speed = UnitAttackSpeed and UnitAttackSpeed("player")
        dur = (speed and not issecret(speed)) and speed or self.swingDur
    end
    self.swingStart, self.swingDur = GetTime(), dur or 0

    -- This swing applied any pending Echo.
    self.swings = self.swings + 1
    if self.echo then
        self.twisted = self.twisted + 1
        self.echoConsumedAt = GetTime()
        self.echo = nil
    end
    self:UpdateSeal()
end

function T:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if unit ~= "player" or not spellID or issecret(spellID) then return end
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    local s = SealShort(name)
    if s then
        self.db.learned.seals[s] = self.db.learned.seals[s] or spellID
        local old = self.seal
        if old and old ~= s and TWISTABLE[old] and self:HasTwist() then
            self.echo = old            -- predicted; the aura check below corrects it
        end
        self.seal = s
        self.sealAuraInstance, self.sealStacks = nil, nil
        C_Timer.After(0.1, function() T:RefreshAuras() end)
        self:UpdateSeal()
    end
    self:UpdateCooldowns()
end

function T:UNIT_AURA(unit)
    if unit ~= "player" then return end
    self:RefreshAuras()
end

function T:SPELL_UPDATE_COOLDOWN() self:UpdateCooldowns() end

function T:PLAYER_REGEN_DISABLED()
    self.swings, self.twisted = 0, 0
    self:UpdateStats()
    self:UpdateVisibility()
end

function T:PLAYER_REGEN_ENABLED() self:UpdateVisibility() end
function T:PLAYER_TARGET_CHANGED() self:UpdateVisibility() end

function T:SPELLS_CHANGED()
    self:PickStrike()
    self:UpdateSeal()
end

function T:PLAYER_LOGIN()
    TwistBarDB = TwistBarDB or {}
    self.db = TwistBarDB
    for k, v in pairs(DEFAULTS) do
        if self.db[k] == nil then
            if type(v) == "table" then
                self.db[k] = { seals = {}, echoes = {} }
            else
                self.db[k] = v
            end
        end
    end
    self.isPaladin = select(2, UnitClass("player")) == "PALADIN"
    if not self.isPaladin then return end

    local pt = self.db.point
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("CENTER", 0, -220) end
    f:SetScale(self.db.scale)
    f:EnableMouse(not self.db.locked)

    judge.icon:SetTexture(C_Spell.GetSpellTexture("Judgement") or 134400)
    Tooltip(judge, function(tt) tt:AddLine("Judgement") end)
    Tooltip(strike, function(tt) tt:AddLine(T.strikeSpell or "Strike") end)
    Tooltip(seal, function(tt)
        tt:AddLine(T.seal and ("Seal of " .. T.seal) or "No seal")
    end)
    Tooltip(echo, function(tt)
        tt:AddLine("Echo (Twist of Light)")
        if T.echo then
            tt:AddLine("Your next melee attack also applies Seal of " .. T.echo .. ".", 1, 1, 1, true)
        else
            tt:AddLine("No Echo pending. Replacing Command, Righteousness, Fury or Justice creates one.", 1, 1, 1, true)
        end
    end)

    for _, e in ipairs({ "PLAYER_SWING", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "SPELL_UPDATE_COOLDOWN",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
                         "SPELLS_CHANGED" }) do
        pcall(self.RegisterEvent, self, e)
    end

    self:PickStrike()
    self:RefreshAuras()
    self:UpdateCooldowns()
    self:UpdateVisibility()
end

T:SetScript("OnEvent", function(self, event, ...)
    if self[event] then self[event](self, ...) end
end)
T:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_TWISTBAR1 = "/twist"
SLASH_TWISTBAR2 = "/twistbar"
SlashCmdList.TWISTBAR = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db = T.db
    if not T.isPaladin then Print("Only loads for paladins.") return end
    if cmd == "unlock" or cmd == "lock" or cmd == "" then
        db.locked = (cmd == "lock") or (cmd == "" and not db.locked)
        f:EnableMouse(not db.locked)
        Print(db.locked and "Locked." or "Unlocked: drag the bar to move it. /twist lock when done.")
    elseif cmd == "scale" and tonumber(arg) then
        db.scale = math.min(math.max(tonumber(arg), 0.5), 2.5)
        f:SetScale(db.scale)
    elseif cmd == "show" and (arg == "always" or arg == "combat" or arg == "smart") then
        db.visibility = arg
        Print("Visibility: %s", arg)
    elseif cmd == "strike" then
        db.strike = not db.strike
        T:PickStrike()
    elseif cmd == "gcd" then
        db.gcdMarker = not db.gcdMarker
        Print("GCD marker: %s", db.gcdMarker and "on" or "off")
    elseif cmd == "echo" then
        if arg == "on" then db.forceTwist = true elseif arg == "off" then db.forceTwist = false else db.forceTwist = nil end
        Print("Echo tracking: %s", db.forceTwist == nil and "auto" or (db.forceTwist and "on" or "off"))
    elseif cmd == "reset" then
        db.point = nil
        f:ClearAllPoints()
        f:SetPoint("CENTER", 0, -220)
    else
        Print("/twist [unlock | lock | scale <n> | show always|combat|smart | strike | gcd | echo on|off|auto | reset]")
        return
    end
    T:UpdateSeal()
    T:UpdateVisibility()
end
