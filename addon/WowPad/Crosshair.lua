-- Crosshair.lua - centre dot while the camera is active (controller mode,
-- mouselook on), plus mouseover tooltips like a mouse cursor would give.
--
-- WoW (3.3.5) doesn't track units under the pointer during camera look
-- (verified with /wp mlprobe), so tooltips appear when the right stick rests
-- and camera look briefly pauses ("peek", see Core.lua).
-- Dot colour: red = attackable, green = friendly, yellow = neutral, white = nothing.
-- /wp crosshair toggles it, /wp peek toggles the idle peek.

local WP = WowPad

local C = CreateFrame("Frame", "WowPadCrosshair", UIParent)
C:SetSize(10, 10)
C:SetFrameStrata("HIGH")
C:Hide()
local dot = C:CreateTexture(nil, "OVERLAY")
dot:SetAllPoints()
dot:SetTexture("Interface\\AddOns\\WowPad\\Textures\\dot")

local ownTooltip, lastGUID, acc = false, nil, 0

local function HideOurTooltip()
  if ownTooltip and GameTooltip:IsOwned(UIParent) then GameTooltip:Hide() end
  ownTooltip, lastGUID = false, nil
end
C:SetScript("OnHide", HideOurTooltip)

-- The dot sits exactly on WoW's (hidden, frozen) pointer: that is the spot
-- WoW checks for units when camera look pauses (peek). The DLL parks the
-- pointer at [Camera] CrosshairY in wowpad.ini when you pick up the pad.
local function FollowPointer()
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  C:ClearAllPoints()
  C:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 0.03 then return end
  acc = 0
  local active = WowPadDB and WowPadDB.crosshair ~= false and WP.mode == "controller"
                 and (IsMouselooking() or WP.peeking)
  if not active then
    if C:IsShown() then C:Hide() end
    return
  end
  FollowPointer()
  if not C:IsShown() then C:Show() end
  -- WoW swaps in its hand/sword cursor when the mouseover changes; keep ours invisible.
  if WP.peeking and UnitExists("mouseover") then SetCursor(WP.BLANK_CURSOR) end

  if UnitExists("mouseover") then
    if UnitCanAttack("player", "mouseover") then dot:SetVertexColor(1, 0.25, 0.2)
    elseif UnitIsFriend("player", "mouseover") then dot:SetVertexColor(0.3, 1, 0.3)
    else dot:SetVertexColor(1, 0.85, 0.2) end
    local guid = UnitGUID("mouseover")
    if not ownTooltip or guid ~= lastGUID or not GameTooltip:IsShown() then
      GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
      GameTooltip:SetUnit("mouseover")
      ownTooltip, lastGUID = true, guid
    end
  else
    dot:SetVertexColor(1, 1, 1)
    HideOurTooltip()
  end
end)

-- Pointer mode (R3): on Wayland the desktop keeps drawing the hardware cursor
-- where it was (programs can't move it), so the DLL hides it and we draw one
-- at WoW's own pointer, using the game's cursor art.
local P = CreateFrame("Frame", "WowPadPointer", UIParent)
P:SetFrameStrata("TOOLTIP")
P:SetFrameLevel(100)
P:Hide()
local ptex = P:CreateTexture(nil, "OVERLAY")
ptex:SetAllPoints()
local ART = {
  point    = "Interface\\Cursor\\Point",
  attack   = "Interface\\Cursor\\Attack",
  speak    = "Interface\\Cursor\\Speak",
  interact = "Interface\\Cursor\\Interact",
}
local function PhysHeight()
  local h = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
  return h or 768
end
local curArt
local pdriver = CreateFrame("Frame")
pdriver:SetScript("OnUpdate", function()
  -- Only needed with the hardware cursor; WoW's software cursor already follows its pointer.
  if not (WP.pointer and WP.mode == "controller" and WowPadDB and WowPadDB.drawPointer ~= false
          and GetCVar("gxCursor") == "1") then
    if P:IsShown() then P:Hide() end
    return
  end
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  local size = 32 * 768 / (PhysHeight() * s)   -- 32 screen pixels, like the real cursor
  P:SetSize(size, size)
  P:ClearAllPoints()
  P:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
  local art = ART.point
  if UnitExists("mouseover") then
    if UnitCanAttack("player", "mouseover") then art = ART.attack
    elseif not UnitIsPlayer("mouseover") then art = ART.speak end
  end
  if curArt ~= art then ptex:SetTexture(art); curArt = art end
  if not P:IsShown() then P:Show() end
end)

-- /wp mlprobe: where is WoW's hidden pointer, and is there a mouseover unit?
function WP.MouselookProbe()
  local t, n = 0, 0
  local f = CreateFrame("Frame")
  WP.Print("Probe: keep the dot on an NPC for a few seconds...")
  f:SetScript("OnUpdate", function(self, e)
    t = t + e
    if t < 0.5 then return end
    t, n = 0, n + 1
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    local cx, cy = UIParent:GetCenter()
    WP.Print(("pointer %d,%d  centre %d,%d  mouselook=%s  peek=%s  mouseover=%s"):format(
      x / s, y / s, cx, cy, IsMouselooking() and 1 or 0, WP.peeking and 1 or 0, tostring(UnitName("mouseover"))))
    if n >= 16 then self:SetScript("OnUpdate", nil) end
  end)
end

-- The crosshair's cursor hiding needs WoW's hardware cursor (Video options).
local hint = CreateFrame("Frame")
hint:RegisterEvent("PLAYER_ENTERING_WORLD")
hint:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if GetCVar("gxCursor") == "0" and WowPadDB and WowPadDB.peek ~= false then
    WP.Print("Tip: turn on |cffffff00Hardware Cursor|r in Video options so the crosshair can hide the hand/sword cursor.")
  end
end)

function WP.ToggleCrosshair()
  WowPadDB.crosshair = (WowPadDB.crosshair == false)
  WP.Print("Crosshair: " .. (WowPadDB.crosshair and "on" or "off"))
end
