-- Snap.lua - dragging in edit mode with a soft snap to the screen's vertical
-- centre line: within SNAP pixels the frame's centre locks onto the line (a
-- gold guide shows), pull further and it lets go. Up/down stays free.

local WP = WowPad
local SNAP = 12   -- UI pixels

local guide = CreateFrame("Frame", nil, UIParent)
guide:SetFrameStrata("TOOLTIP")
guide:SetAllPoints(UIParent)
guide:Hide()
local line = guide:CreateTexture(nil, "OVERLAY")
line:SetTexture(1, 0.82, 0.2, 0.7)
line:SetWidth(2)
line:SetPoint("TOP", UIParent, "TOP", 0, 0)
line:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)

local dragging, offX, offY
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
  local f = dragging
  if not f then driver:Hide(); return end
  local eff = f:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local x, y = cx / eff + offX, cy / eff + offY
  -- screen centre and snap distance in the frame's own units
  local ui = UIParent:GetEffectiveScale()
  local mid = UIParent:GetWidth() * ui / 2 / eff
  local snapped = math.abs(x - mid) <= SNAP * ui / eff
  if snapped then x = mid end
  if snapped then guide:Show() else guide:Hide() end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end)

-- Start dragging frame f (call from OnDragStart).
function WP.SnapDragStart(f)
  if InCombatLockdown() then return end
  local eff = f:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local fx, fy = f:GetCenter()
  if not fx then return end
  offX, offY = fx - cx / eff, fy - cy / eff
  dragging = f
  driver:Show()
end

-- Stop dragging (call from OnDragStop). Returns the frame's centre (its own units).
function WP.SnapDragStop()
  local f = dragging
  dragging = nil
  driver:Hide()
  guide:Hide()
  if f then return f:GetCenter() end
end
