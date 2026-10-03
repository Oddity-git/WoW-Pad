-- MapCursor.lua - a visible cursor on the world map in controller mode,
-- like WoW's console version: gold diamond, crosshair lines across the map,
-- cursor and player coordinates.
--
-- The right stick already moves WoW's (hidden) pointer while a window is open;
-- on Wayland the real cursor can't follow it, so we draw one here and blank the
-- real one. A clicks what's under it (zone = zoom in, pin = click the pin),
-- X right-clicks (zoom out), B goes back a level (Nav.lua). With the D-pad the
-- diamond sits on the selected pin/button instead.

local WP = WowPad
local BLANK = "Interface\\AddOns\\WowPad\\Textures\\blank"

local holder, diamond, hLine, vLine, coords
local active = false

local function Build()
  local detail = WorldMapDetailFrame
  if not detail or holder then return holder ~= nil end
  holder = CreateFrame("Frame", "WowPadMapCursor", detail)
  holder:SetAllPoints(detail)
  holder:SetFrameStrata("TOOLTIP")       -- above pins; tooltips still draw on top of it
  holder:SetFrameLevel(1)
  holder:EnableMouse(false)

  hLine = holder:CreateTexture(nil, "OVERLAY")
  hLine:SetTexture(1, 0.82, 0.1, 0.85)
  hLine:SetHeight(2)
  vLine = holder:CreateTexture(nil, "OVERLAY")
  vLine:SetTexture(1, 0.82, 0.1, 0.85)
  vLine:SetWidth(2)

  diamond = holder:CreateTexture(nil, "OVERLAY", nil, 7)
  diamond:SetTexture("Interface\\AddOns\\WowPad\\Textures\\mapcursor")
  diamond:SetSize(30, 30)

  coords = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  coords:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 8, 8)
  coords:SetJustifyH("LEFT")
  holder:Hide()
  return true
end

local function MapShown()
  return WorldMapFrame and WorldMapFrame:IsShown()
end

-- Is the map cursor wanted right now?
local function Wanted()
  return WP.mode == "controller" and MapShown()
end
WP.MapCursorWanted = Wanted

-- Where the cursor is, in the detail frame's coordinates (origin bottom-left).
local function CursorSpot(detail)
  local s = detail:GetEffectiveScale()
  local left, bottom = detail:GetLeft(), detail:GetBottom()
  if not left then return end
  local Nav = WP.Nav
  local n = Nav and Nav.byDpad and Nav.cur
  if n and n ~= WorldMapButton and n.GetCenter then
    local cx, cy = n:GetCenter()
    if cx then
      local k = n:GetEffectiveScale() / s
      return cx * k - left, cy * k - bottom
    end
  end
  local x, y = GetCursorPosition()
  return x / s - left, y / s - bottom
end

local acc = 0
local function Update(_, elapsed)
  acc = acc + elapsed
  if acc < 0.016 then return end
  acc = 0
  local want = Wanted()
  if not want then
    if active then
      active = false
      if holder then holder:Hide() end
      ResetCursor()
    end
    return
  end
  if not Build() then return end
  local detail = WorldMapDetailFrame
  local x, y = CursorSpot(detail)
  if not x then return end
  if not active then active = true; holder:Show() end
  SetCursor(BLANK)  -- keep the real (frozen) cursor invisible; WoW resets it over pins

  local w, h = detail:GetWidth(), detail:GetHeight()
  diamond:ClearAllPoints()
  diamond:SetPoint("CENTER", detail, "BOTTOMLEFT", x, y)

  local inside = x >= 0 and x <= w and y >= 0 and y <= h
  if inside then
    hLine:ClearAllPoints()
    hLine:SetPoint("LEFT", detail, "BOTTOMLEFT", 0, y)
    hLine:SetPoint("RIGHT", detail, "BOTTOMRIGHT", 0, y)
    vLine:ClearAllPoints()
    vLine:SetPoint("BOTTOM", detail, "BOTTOMLEFT", x, 0)
    vLine:SetPoint("TOP", detail, "TOPLEFT", x, 0)
    hLine:Show(); vLine:Show()
  else
    hLine:Hide(); vLine:Hide()
  end

  local lines = {}
  if inside then
    lines[#lines + 1] = ("Cursor: %.1f, %.1f"):format(x / w * 100, (1 - y / h) * 100)
  end
  local px, py = GetPlayerMapPosition("player")
  if px and (px > 0 or py > 0) then
    lines[#lines + 1] = ("Player: %.1f, %.1f"):format(px * 100, py * 100)
  end
  coords:SetText(table.concat(lines, "\n"))
end

local f = CreateFrame("Frame")
f:SetScript("OnUpdate", Update)
