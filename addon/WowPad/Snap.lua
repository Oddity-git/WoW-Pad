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

---------------------------------------------------------------------------
-- Edit-mode mover for a frame that isn't one of the bars (the radial menu,
-- the utility ring): a blue "drag / wheel" box, `size` square in the frame's
-- middle (default: over the whole frame). Drag moves the frame (with the centre-line snap), the mouse
-- wheel resizes it. Saved account-wide in WowPadDB.movers[key]; the frame is
-- kept on screen. Only out of combat (edit mode is out of combat anyway).
---------------------------------------------------------------------------
local function MoverDB(key)
  WowPadDB.movers = WowPadDB.movers or {}
  WowPadDB.movers[key] = WowPadDB.movers[key] or {}
  return WowPadDB.movers[key]
end

-- Put the frame where it was saved (or at its default spot), at its size.
function WP.ApplyMoverPos(f)
  if InCombatLockdown() or not WowPadDB then return end
  local p = MoverDB(f.moverKey)
  f:SetScale(p.scale or 1)
  f:ClearAllPoints()
  if p.x then f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else f:SetPoint(unpack(f.moverDefault)) end
end

function WP.MakeMover(f, key, label, size, minScale, maxScale)
  f.moverKey = key
  f.moverDefault = { f:GetPoint(1) }
  f:SetClampedToScreen(true)
  local m = CreateFrame("Frame", nil, f)
  if size then m:SetPoint("CENTER"); m:SetSize(size, size) else m:SetAllPoints() end
  m:SetFrameLevel(f:GetFrameLevel() + 30)
  m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                  tile = true, tileSize = 16, edgeSize = 14,
                  insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  m:SetBackdropColor(0.2, 0.5, 1, 0.35)
  m:SetBackdropBorderColor(0.35, 0.7, 1, 0.8)
  local t = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("CENTER")
  t:SetText(label .. "\n(drag / wheel)")
  m:EnableMouse(true)
  m:RegisterForDrag("LeftButton")
  m:SetScript("OnDragStart", function() WP.SnapDragStart(f) end)
  m:SetScript("OnDragStop", function()
    WP.SnapDragStop()
    local p = MoverDB(key)
    p.x, p.y = f:GetCenter()
  end)
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", function(_, delta)
    if InCombatLockdown() then return end
    local p = MoverDB(key)
    local old = f:GetScale()
    local new = math.max(minScale or 0.5, math.min(maxScale or 1.5, (p.scale or 1) + delta * 0.05))
    local x, y = f:GetCenter()
    p.scale = new
    if x then p.x, p.y = x * old / new, y * old / new end
    WP.ApplyMoverPos(f)
  end)
  m:Hide()
  f.mover = m
  return m
end
