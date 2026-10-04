-- MinimapButton.lua - round button on the minimap edge.
-- Left-click: Edit bar layout. Right-click: WowPad options. Drag: move it
-- around the minimap (angle saved in WowPadDB.minimap). Hide it in
-- Options > WowPad > Bars.

local WP = WowPad
local RADIUS = 80

local b = CreateFrame("Button", "WowPadMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
b:Hide()

local bg = b:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(20, 20)
bg:SetPoint("TOPLEFT", 7, -5)
local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\WowPad\\Textures\\minimap")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -6)
local border = b:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

local function DB()
  WowPadDB.minimap = WowPadDB.minimap or {}
  return WowPadDB.minimap
end

local function Place()
  local a = math.rad(DB().angle or 225)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

b:SetScript("OnClick", function(_, button)
  GameTooltip:Hide()
  if button == "RightButton" then
    if WP.OpenOptions then WP.OpenOptions() end
  else
    if WP.ToggleEdit then WP.ToggleEdit() end
  end
end)

b:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("WowPad")
  GameTooltip:AddLine("|cffffd100Left-click:|r Edit bar layout", 1, 1, 1)
  GameTooltip:AddLine("|cffffd100Right-click:|r Options", 1, 1, 1)
  GameTooltip:AddLine("|cffffd100Drag:|r Move this button", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Dragging()
  local mx, my = Minimap:GetCenter()
  local s = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  DB().angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
  Place()
end
b:SetScript("OnDragStart", function(self)
  GameTooltip:Hide()
  self:SetScript("OnUpdate", Dragging)
end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- Show or hide per the option (default shown).
function WP.UpdateMinimapButton()
  if WowPadDB and DB().hide then b:Hide() else Place(); b:Show() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() WowPadDB = WowPadDB or {}; WP.UpdateMinimapButton() end)
