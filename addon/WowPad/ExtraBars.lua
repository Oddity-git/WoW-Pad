-- ExtraBars.lua - WowPad's own XP/reputation bar and pet bar.
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
  m:SetScript("OnDragStart", function() if not InCombatLockdown() then holder:StartMoving() end end)
  m:SetScript("OnDragStop", function()
    holder:StopMovingOrSizing()
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
local XP_W, XP_H, REP_H = 520, 12, 8
local xpHolder, xpBar, restBar, xpText, repBar, repText

local function StatusBar(parent, r, g, b)
  local s = CreateFrame("StatusBar", nil, parent)
  s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  s:SetStatusBarColor(r, g, b)
  s:SetMinMaxValues(0, 1)
  local bg = s:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(0, 0, 0, 0.55)
  bg:SetAllPoints()
  return s
end

local function AtMaxLevel()
  if IsXPUserDisabled and IsXPUserDisabled() then return true end
  local maxLevel = MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or 80
  return UnitLevel("player") >= maxLevel
end

function Extra.UpdateXP()
  if not xpHolder then return end
  local showXP = not AtMaxLevel()
  local name, reaction, minV, maxV, value = GetWatchedFactionInfo()
  local showRep = name ~= nil

  if showXP then
    local cur, max, rested = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() or 0
    max = math.max(max, 1)
    xpBar:SetMinMaxValues(0, max); xpBar:SetValue(cur)
    restBar:SetMinMaxValues(0, max); restBar:SetValue(math.min(cur + rested, max))
    xpText:SetText(("Level %d   %d / %d  (%d%%)%s"):format(UnitLevel("player"), cur, max,
                   math.floor(cur / max * 100), rested > 0 and ("   rested " .. rested) or ""))
    xpBar:Show(); restBar:Show()
  else
    xpBar:Hide(); restBar:Hide(); xpText:SetText("")
  end

  if showRep then
    local span = math.max(maxV - minV, 1)
    repBar:SetMinMaxValues(0, span); repBar:SetValue(value - minV)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then repBar:SetStatusBarColor(c.r, c.g, c.b) end
    repText:SetText(("%s   %d / %d"):format(name, value - minV, span))
    repBar:Show()
  else
    repBar:Hide(); repText:SetText("")
  end

  -- Rep sits under XP, or alone in XP's place at max level.
  repBar:ClearAllPoints()
  if showXP then repBar:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -2); repBar:SetPoint("TOPRIGHT", xpBar, "BOTTOMRIGHT", 0, -2)
  else repBar:SetPoint("TOPLEFT", xpHolder, "TOPLEFT"); repBar:SetPoint("TOPRIGHT", xpHolder, "TOPRIGHT") end
  if xpHolder.mover:IsShown() then return end -- keep full size while editing
  if showXP or showRep then xpHolder:Show() else xpHolder:Hide() end
end

local function BuildXP()
  xpHolder = MakeHolder("WowPadXPBar", "xp", XP_W, XP_H + REP_H + 2, { "BOTTOM", UIParent, "BOTTOM", 0, 4 })
  restBar = StatusBar(xpHolder, 0.0, 0.39, 0.88)
  restBar:SetAlpha(0.6)
  restBar:SetPoint("TOPLEFT"); restBar:SetPoint("TOPRIGHT"); restBar:SetHeight(XP_H)
  xpBar = StatusBar(xpHolder, 0.58, 0.0, 0.55)
  xpBar:SetFrameLevel(restBar:GetFrameLevel() + 1)
  xpBar:SetAllPoints(restBar)
  xpText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  xpText:SetPoint("CENTER")
  repBar = StatusBar(xpHolder, 0, 0.6, 0.1)
  repBar:SetHeight(REP_H)
  repText = repBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  repText:SetPoint("CENTER", 0, 0)
  repText:SetFont(repText:GetFont(), 9)
  MakeMover(xpHolder, "XP / Reputation")
  ApplyPos(xpHolder)
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
-- Edit mode (called from the controller bar's edit mode)
---------------------------------------------------------------------------
function Extra.SetEditing(on)
  if InCombatLockdown() then return end
  for _, m in ipairs(movers) do if on then m:Show() else m:Hide() end end
  if petHolder then
    if on then
      UnregisterStateDriver(petHolder, "visibility")
      petHolder:Show()
    else
      RegisterStateDriver(petHolder, "visibility", "[pet] show; hide")
    end
  end
  if xpHolder then
    if on then xpHolder:Show() else Extra.UpdateXP() end
  end
end

table.insert(WP.setupHooks, function()
  BuildXP()
  BuildPet()
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
  if event:find("XP") or event:find("EXHAUSTION") or event:find("LEVEL") or event == "UPDATE_FACTION" then
    Extra.UpdateXP()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Extra.UpdateXP(); Extra.UpdatePet()
  else
    Extra.UpdatePet()
  end
end)
