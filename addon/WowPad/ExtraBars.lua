-- ExtraBars.lua - WowPad's own XP/reputation bar, pet bar and cast bar.
-- Each can be turned off (Options > WowPad > Bars) to use another addon's.
--
-- Blizzard's versions are hidden with the rest of the bottom UI (BlizzBars.lua)
-- and keep re-positioning themselves, so these are our own, Bartender-style.
-- Both move and scale independently in Edit Bar mode (drag the labelled box,
-- mouse wheel to resize). Positions/scales are account-wide (WowPadDB.extra).
--
-- Pet bar: secure buttons of type "pet" (cast) + "/petautocasttoggle" on right
-- click; shown only with a pet via a state driver, so it works in combat.

local WP = WowPad
local Extra = {}
WP.Extra = Extra
local movers = {}

---------------------------------------------------------------------------
-- Movable/scalable holders with an edit-mode box
---------------------------------------------------------------------------
local function DB(key)
  WowPadDB.extra = WowPadDB.extra or {}
  WowPadDB.extra[key] = WowPadDB.extra[key] or {}
  return WowPadDB.extra[key]
end

local function ApplyPos(holder)
  local p = DB(holder.key)
  holder:SetScale(p.scale or 1)
  holder:ClearAllPoints()
  if p.x then
    holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else
    holder:SetPoint(unpack(holder.defaultPoint))
  end
end

local function MakeMover(holder, label)
  local m = CreateFrame("Frame", nil, holder)
  m.holder = holder
  m:SetAllPoints()
  m:SetFrameLevel(holder:GetFrameLevel() + 20)
  local bg = m:CreateTexture(nil, "OVERLAY")
  bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  bg:SetVertexColor(0.2, 0.5, 1, 0.45)
  bg:SetAllPoints()
  local t = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("CENTER")
  t:SetText(label .. "  (drag / wheel)")
  m:EnableMouse(true)
  m:RegisterForDrag("LeftButton")
  m:SetScript("OnDragStart", function() WP.SnapDragStart(holder) end)
  m:SetScript("OnDragStop", function()
    WP.SnapDragStop()
    local x, y = holder:GetCenter()
    local p = DB(holder.key)
    p.x, p.y = x, y
  end)
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", function(_, delta)
    if InCombatLockdown() then return end
    local p = DB(holder.key)
    local old = holder:GetScale()
    local new = math.max(0.4, math.min(2.0, (p.scale or 1) + delta * 0.05))
    local x, y = holder:GetCenter()
    p.scale = new
    if x then p.x, p.y = x * old / new, y * old / new end
    ApplyPos(holder)
  end)
  m:Hide()
  table.insert(movers, m)
  holder.mover = m
end

local function MakeHolder(name, key, w, h, defaultPoint, template)
  local f = CreateFrame("Frame", name, UIParent, template)
  f:SetSize(w, h)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f.key, f.defaultPoint = key, defaultPoint
  return f
end

---------------------------------------------------------------------------
-- XP + reputation bar
---------------------------------------------------------------------------
local XP_W, XP_H, REP_H = 520, 12, 9
local xpHolder, repHolder, xpBar, restBar, xpText, repBar, repText

-- Rounded bar: half-disc caps (Textures/barcap, mirrored on the right) + flat
-- middle, a thin bronze outline, and a fill whose left cap shows once there is
-- any progress and whose right cap shows when full.
local CAP = "Interface\\AddOns\\WowPad\\Textures\\barcap"
local RING = "Interface\\AddOns\\WowPad\\Textures\\barcapring"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local EDGE = { 0.72, 0.56, 0.33, 1 }
local function RoundBar(parent, w, h, r, g, b)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  local cw = h / 2
  local function Cap(frame, layer, tex, side, color)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(tex)
    t:SetSize(cw, h)
    t:SetPoint(side)
    if side == "RIGHT" then t:SetTexCoord(1, 0, 0, 1) end
    if color then t:SetVertexColor(unpack(color)) end
    return t
  end
  local function Mid(frame, layer)
    local t = frame:CreateTexture(nil, layer)
    t:SetPoint("TOPLEFT", cw, 0)
    t:SetPoint("BOTTOMRIGHT", -cw, 0)
    return t
  end
  local dark = { 0, 0, 0, 0.6 }
  Cap(f, "BACKGROUND", CAP, "LEFT", dark); Cap(f, "BACKGROUND", CAP, "RIGHT", dark)
  Mid(f, "BACKGROUND"):SetTexture(0, 0, 0, 0.6)

  local function Fill(level, cr, cg, cb, alpha)
    local s = CreateFrame("StatusBar", nil, f)
    s:SetPoint("TOPLEFT", cw, 0)
    s:SetPoint("BOTTOMRIGHT", -cw, 0)
    s:SetFrameLevel(f:GetFrameLevel() + level)
    s:SetStatusBarTexture(FLAT)
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    s.capL = Cap(s, "ARTWORK", CAP, "LEFT")
    s.capL:ClearAllPoints(); s.capL:SetPoint("RIGHT", s, "LEFT")
    s.capR = Cap(s, "ARTWORK", CAP, "RIGHT")
    s.capR:ClearAllPoints(); s.capR:SetPoint("LEFT", s, "RIGHT")
    function s:SetColor(cr2, cg2, cb2)
      self:SetStatusBarColor(cr2, cg2, cb2, alpha)
      self.capL:SetVertexColor(cr2, cg2, cb2, alpha)
      self.capR:SetVertexColor(cr2, cg2, cb2, alpha)
    end
    function s:SetProgress(max, v)
      max = math.max(max, 1)
      v = math.max(0, math.min(v, max))
      self:SetMinMaxValues(0, max)
      self:SetValue(v)
      if v > 0 then self.capL:Show() else self.capL:Hide() end
      if v >= max then self.capR:Show() else self.capR:Hide() end
    end
    s:SetColor(cr, cg, cb)
    return s
  end
  f.Fill = Fill

  local edge = CreateFrame("Frame", nil, f)
  edge:SetAllPoints()
  edge:SetFrameLevel(f:GetFrameLevel() + 5)
  Cap(edge, "OVERLAY", RING, "LEFT", EDGE); Cap(edge, "OVERLAY", RING, "RIGHT", EDGE)
  local lw = math.max(1, h * 6 / 64)
  local top = edge:CreateTexture(nil, "OVERLAY")
  top:SetTexture(unpack(EDGE)); top:SetHeight(lw)
  top:SetPoint("TOPLEFT", cw, 0); top:SetPoint("TOPRIGHT", -cw, 0)
  local bot = edge:CreateTexture(nil, "OVERLAY")
  bot:SetTexture(unpack(EDGE)); bot:SetHeight(lw)
  bot:SetPoint("BOTTOMLEFT", cw, 0); bot:SetPoint("BOTTOMRIGHT", -cw, 0)
  f.text = edge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER", 0, 0)
  return f
end

local function AtMaxLevel()
  if IsXPUserDisabled and IsXPUserDisabled() then return true end
  local maxLevel = MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or 80
  return UnitLevel("player") >= maxLevel
end

local function On(key) return WowPadDB[key] ~= false end

local function Editing(holder) return holder.mover and holder.mover:IsShown() end

function Extra.UpdateXP()
  if not xpHolder then return end
  -- XP
  if On("showXP") and not AtMaxLevel() then
    local cur, max, rested = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() or 0
    max = math.max(max, 1)
    xpBar:SetProgress(max, cur)
    restBar:SetProgress(max, cur + rested)
    xpText:SetText(("Level %d   %d / %d  (%d%%)%s"):format(UnitLevel("player"), cur, max,
                   math.floor(cur / max * 100), rested > 0 and ("   rested " .. rested) or ""))
    xpHolder:Show()
  elseif not Editing(xpHolder) then
    xpHolder:Hide()
  end
  -- Reputation
  local name, reaction, minV, maxV, value = GetWatchedFactionInfo()
  if On("showRep") and name then
    local span = math.max(maxV - minV, 1)
    repBar:SetProgress(span, value - minV)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then repBar:SetColor(c.r, c.g, c.b) end
    repText:SetText(("%s   %d / %d"):format(name, value - minV, span))
    repHolder:Show()
  elseif not Editing(repHolder) then
    repHolder:Hide()
  end
end

local function BuildXP()
  xpHolder = MakeHolder("WowPadXPBar", "xp", XP_W, XP_H, { "BOTTOM", UIParent, "BOTTOM", 0, 2 })
  local xp = RoundBar(xpHolder, XP_W, XP_H)
  xp:SetAllPoints()
  restBar = xp.Fill(1, 0.0, 0.39, 0.88, 0.55)
  xpBar = xp.Fill(2, 0.58, 0.0, 0.55, 1)
  xpText = xp.text
  MakeMover(xpHolder, "XP")
  ApplyPos(xpHolder)

  repHolder = MakeHolder("WowPadRepBar", "rep", XP_W, REP_H, { "BOTTOM", xpHolder, "TOP", 0, 4 })
  local rep = RoundBar(repHolder, XP_W, REP_H)
  rep:SetAllPoints()
  repBar = rep.Fill(1, 0, 0.6, 0.1, 1)
  repText = rep.text
  repText:SetFont(repText:GetFont(), 9)
  MakeMover(repHolder, "Reputation")
  ApplyPos(repHolder)
  Extra.UpdateXP()
end

---------------------------------------------------------------------------
-- Pet bar
---------------------------------------------------------------------------
local PET_SIZE, PET_GAP = 30, 4
local petHolder, petButtons = nil, {}

function Extra.UpdatePet()
  if not petHolder then return end
  for i, b in ipairs(petButtons) do
    local name, _, texture, isToken, isActive, autoAllowed, autoEnabled = GetPetActionInfo(i)
    if isToken and texture then texture = _G[texture] end
    b.icon:SetTexture(texture)
    if texture then b.icon:Show() else b.icon:Hide() end
    b:SetChecked(isActive and true or false)
    if autoAllowed then b.autocastable:Show() else b.autocastable:Hide() end
    if autoEnabled then AutoCastShine_AutoCastStart(b.shine) else AutoCastShine_AutoCastStop(b.shine) end
    local start, duration, enable = GetPetActionCooldown(i)
    if start then CooldownFrame_SetTimer(b.cooldown, start, duration, enable) end
    -- Right click toggles autocast by name (secure macro; out of combat only).
    if not InCombatLockdown() then
      b:SetAttribute("macrotext2", (name and autoAllowed) and ("/petautocasttoggle " .. name) or nil)
    end
  end
end

local function BuildPet()
  local w = 10 * PET_SIZE + 9 * PET_GAP
  petHolder = MakeHolder("WowPadPetBar", "pet", w, PET_SIZE, { "BOTTOM", UIParent, "BOTTOM", 0, 330 },
                         "SecureHandlerStateTemplate")
  for i = 1, 10 do
    local name = "WowPadPetButton" .. i
    local b = CreateFrame("CheckButton", name, petHolder, "SecureActionButtonTemplate, ActionButtonTemplate")
    b:SetSize(PET_SIZE, PET_SIZE)
    b:SetPoint("LEFT", petHolder, "LEFT", (i - 1) * (PET_SIZE + PET_GAP), 0)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type1", "pet")
    b:SetAttribute("action", i)
    b:SetAttribute("type2", "macro")
    local s = PET_SIZE / 36
    local normal = b:GetNormalTexture()
    if normal then normal:SetSize(66 * s, 66 * s) end
    b.icon = _G[name .. "Icon"]
    b.cooldown = _G[name .. "Cooldown"]
    b.autocastable = b:CreateTexture(nil, "OVERLAY")
    b.autocastable:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
    b.autocastable:SetSize(PET_SIZE * 2, PET_SIZE * 2)
    b.autocastable:SetPoint("CENTER")
    b.autocastable:Hide()
    b.shine = CreateFrame("Frame", name .. "Shine", b, "AutoCastShineTemplate")
    b.shine:SetAllPoints()
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetPetAction(i)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:HookScript("PostClick", function() Extra.UpdatePet() end)
    petButtons[i] = b
  end
  MakeMover(petHolder, "Pet bar")
  ApplyPos(petHolder)
  RegisterStateDriver(petHolder, "visibility", "[pet] show; hide")
  Extra.UpdatePet()
end

---------------------------------------------------------------------------
-- Cast bar: WowPad's own player cast bar (game textures only), in a movable
-- holder. Blizzard's fixed one is switched off while ours is on.
---------------------------------------------------------------------------
local castHolder, castBar
local blizzCastOff = false   -- we switched Blizzard's off (only then switch it back on)
local CAST_W, CAST_H = 195, 13
local COLOR_CAST, COLOR_CHANNEL, COLOR_FAIL, COLOR_DONE = { 1, 0.7, 0 }, { 0, 1, 0 }, { 1, 0, 0 }, { 0, 1, 0 }
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
  "PLAYER_ENTERING_WORLD" }

local function CastColor(c) castBar:SetStatusBarColor(c[1], c[2], c[3]) end

local function CastFadeOut()
  castBar.casting, castBar.channeling = nil, nil
  castBar.spark:Hide()
  castBar.fading = true
end

local function CastBegin(channel)
  local name, _, text, texture, startMs, endMs
  if channel then name, _, text, texture, startMs, endMs = UnitChannelInfo("player")
  else name, _, text, texture, startMs, endMs = UnitCastingInfo("player") end
  if not name then return end
  castBar.startT, castBar.endT = startMs / 1000, endMs / 1000
  castBar:SetMinMaxValues(0, castBar.endT - castBar.startT)
  castBar.casting, castBar.channeling, castBar.fading = not channel, channel, nil
  CastColor(channel and COLOR_CHANNEL or COLOR_CAST)
  castBar.text:SetText(text or name)
  castBar.icon:SetTexture(texture)
  castBar.flash:Hide()
  castBar.spark:Show()
  castBar:SetAlpha(1)
  castBar:Show()
end

local function CastEvent(self, event, unit)
  if event == "PLAYER_ENTERING_WORLD" then
    if UnitChannelInfo("player") then CastBegin(true)
    elseif UnitCastingInfo("player") then CastBegin(false)
    else castBar:Hide() end
    return
  end
  if unit ~= "player" then return end
  if event == "UNIT_SPELLCAST_START" then CastBegin(false)
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then CastBegin(true)
  elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
    if castBar.casting or castBar.channeling then CastBegin(castBar.channeling) end
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if castBar.casting or castBar.channeling then
      local _, max = castBar:GetMinMaxValues()
      castBar:SetValue(castBar.casting and max or 0)
      CastColor(COLOR_DONE)
      castBar.flash:Show()
      CastFadeOut()
    end
  elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    if castBar.casting or castBar.channeling or castBar:IsShown() then
      local _, max = castBar:GetMinMaxValues()
      castBar:SetValue(max)
      CastColor(COLOR_FAIL)
      castBar.text:SetText(event == "UNIT_SPELLCAST_FAILED" and (FAILED or "Failed") or (INTERRUPTED or "Interrupted"))
      castBar.timer:SetText("")
      CastFadeOut()
    end
  end
end

local function CastUpdate(self, elapsed)
  local now = GetTime()
  if self.casting or self.channeling then
    local dur = self.endT - self.startT
    local v = self.casting and (now - self.startT) or (self.endT - now)
    if (self.casting and v >= dur) or (self.channeling and v <= 0) then
      v = self.casting and dur or 0
    end
    self:SetValue(v)
    local left = self.casting and (dur - v) or v
    self.timer:SetText(("%.1f"):format(math.max(left, 0)))
    local pos = dur > 0 and (v / dur) or 0
    self.spark:SetPoint("CENTER", self, "LEFT", pos * CAST_W, 2)
  elseif self.fading then
    local a = self:GetAlpha() - elapsed * 2
    if a <= 0 then self.fading = nil; self:Hide(); self:SetAlpha(1) else self:SetAlpha(a) end
  end
end

local function BuildCast()
  castHolder = MakeHolder("WowPadCastHolder", "cast", 240, 32, { "BOTTOM", UIParent, "BOTTOM", 0, 190 })
  castBar = CreateFrame("StatusBar", "WowPadCastBar", castHolder)
  castBar:SetSize(CAST_W, CAST_H)
  castBar:SetPoint("CENTER", castHolder, "CENTER", 10, 0)
  castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  castBar:SetMinMaxValues(0, 1)
  local bg = castBar:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(0, 0, 0, 0.5)
  bg:SetAllPoints()
  local border = castBar:CreateTexture(nil, "ARTWORK")
  border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
  border:SetSize(256, 64)
  border:SetPoint("TOP", castBar, "TOP", 0, 28)
  castBar.flash = castBar:CreateTexture(nil, "OVERLAY")
  castBar.flash:SetTexture("Interface\\CastingBar\\UI-CastingBar-Flash")
  castBar.flash:SetBlendMode("ADD")
  castBar.flash:SetSize(256, 64)
  castBar.flash:SetPoint("TOP", castBar, "TOP", 0, 28)
  castBar.flash:Hide()
  castBar.spark = castBar:CreateTexture(nil, "OVERLAY")
  castBar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  castBar.spark:SetBlendMode("ADD")
  castBar.spark:SetSize(32, 32)
  castBar.text = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  castBar.text:SetPoint("TOP", castBar, "TOP", 0, 5)
  castBar.text:SetWidth(185); castBar.text:SetHeight(16)
  castBar.timer = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  castBar.timer:SetPoint("LEFT", castBar, "RIGHT", 6, 1)
  castBar.icon = castBar:CreateTexture(nil, "ARTWORK")
  castBar.icon:SetSize(20, 20)
  castBar.icon:SetPoint("RIGHT", castBar, "LEFT", -8, 1)
  castBar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  castBar:SetScript("OnEvent", CastEvent)
  castBar:SetScript("OnUpdate", CastUpdate)
  castBar:Hide()
  MakeMover(castHolder, "Cast bar")
  ApplyPos(castHolder)
end

local function SetCast(on)
  if not castBar then return end
  if on then
    for _, e in ipairs(CAST_EVENTS) do castBar:RegisterEvent(e) end
    castHolder:Show()
    if CastingBarFrame and not blizzCastOff then
      CastingBarFrame:UnregisterAllEvents()
      CastingBarFrame:Hide()
      blizzCastOff = true
    end
  else
    castBar:UnregisterAllEvents()
    castBar:Hide()
    castHolder:Hide()
    if CastingBarFrame and blizzCastOff then
      CastingBarFrame_OnLoad(CastingBarFrame, "player", true)
      blizzCastOff = false
    end
  end
end

local petPending = false
local function SetPet(on)
  if not petHolder then return end
  if InCombatLockdown() then petPending = true; return end  -- secure: after combat
  petPending = false
  if on then
    RegisterStateDriver(petHolder, "visibility", "[pet] show; hide")
  else
    UnregisterStateDriver(petHolder, "visibility")
    petHolder:Hide()
  end
end

-- Apply the Bars options (called on login and when a checkbox changes).
function Extra.ApplyShown()
  Extra.UpdateXP()
  SetPet(On("showPet"))
  SetCast(On("castBar"))
end

---------------------------------------------------------------------------
-- Edit mode (called from the controller bar's edit mode)
---------------------------------------------------------------------------
function Extra.SetEditing(on)
  if InCombatLockdown() then return end
  local enabled = { xp = On("showXP"), rep = On("showRep"), pet = On("showPet"), cast = On("castBar") }
  for _, m in ipairs(movers) do
    local holder = m.holder
    if on and enabled[holder.key] then m:Show() else m:Hide() end
  end
  if petHolder and enabled.pet then
    if on then
      UnregisterStateDriver(petHolder, "visibility")
      petHolder:Show()
    else
      RegisterStateDriver(petHolder, "visibility", "[pet] show; hide")
    end
  end
  if xpHolder then
    if on and enabled.xp then xpHolder:Show() end
    if on and enabled.rep then repHolder:Show() end
    if not on then Extra.UpdateXP() end
  end
  if castBar and enabled.cast and not (castBar.casting or castBar.channeling) then
    if on then   -- preview, so you can see what you're placing
      castBar:SetMinMaxValues(0, 1); castBar:SetValue(0.6); CastColor(COLOR_CAST)
      castBar.text:SetText("Cast bar"); castBar.timer:SetText("1.2")
      castBar.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
      castBar.fading = nil; castBar:SetAlpha(1); castBar:Show()
    else
      castBar:Hide()
    end
  end
end

table.insert(WP.setupHooks, function()
  BuildXP()
  BuildPet()
  BuildCast()
  Extra.ApplyShown()
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
                     "PLAYER_ENTERING_WORLD", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN",
                     "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "UNIT_PET", "PET_UI_UPDATE",
                     "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "UNIT_FLAGS", "UNIT_AURA",
                     "PLAYER_REGEN_ENABLED" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" or event == "UNIT_FLAGS" then
    if unit ~= "pet" then return end
  end
  if event == "PLAYER_REGEN_ENABLED" and petPending then SetPet(On("showPet")) end
  if event:find("XP") or event:find("EXHAUSTION") or event:find("LEVEL") or event == "UPDATE_FACTION" then
    Extra.UpdateXP()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Extra.UpdateXP(); Extra.UpdatePet()
  else
    Extra.UpdatePet()
  end
end)
