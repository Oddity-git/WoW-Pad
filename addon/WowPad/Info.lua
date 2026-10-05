-- Info.lua - the Controller Map window: what every button does (main menu,
-- page 2 > Controller). Labels follow the LB/RB swap and healer mode. B closes.

local WP = WowPad

local LEFT = {
  { "Left stick",   "Move" },
  { "L3",           "Autorun" },
  { "LB",           "Target friendly" },
  { "LB + RB",      "Right stick zooms" },
  { "LB + R stick", "Healer mode (down / up)" },
  { "LT (hold)",    "Left action set" },
  { "LT + RT",      "Bottom action set" },
  { "D-pad",        "Action slots" },
  { "Back",         "Map (hold: bags)" },
  { "Back+A / B",   "Keyboard / close" },
}
local RIGHT = {
  { "Right stick",  "Camera / pointer" },
  { "R3",           "Pointer mode" },
  { "RB",           "Target hostile" },
  { "RT (hold)",    "Right action set" },
  { "A / B",        "Jump / Back" },
  { "X / Y",        "Interact + attack / Target menu" },
  { "Y in menus",   "Hold to compare items" },
  { "Start",        "Close windows + main menu" },
}

local F = CreateFrame("Frame", "WowPadInfo", UIParent)
F:SetSize(560, 352)
F:SetPoint("CENTER", 0, 60)
F:SetFrameStrata("DIALOG")
F:EnableMouse(true)
F:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
F:Hide()
table.insert(WP.overlays, F)

local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -20)
title:SetText("Controller Map")

-- One column of rows; keeps the font strings (by key label) so ShowInfo can
-- relabel them.
local valueText, keyText = {}, {}
local function Column(list, x)
  for i, row in ipairs(list) do
    local k = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    k:SetPoint("TOPLEFT", x, -56 - (i - 1) * 26)
    k:SetText(row[1])
    keyText[row[1]] = k
    local v = F:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    v:SetPoint("TOPLEFT", x + 100, -56 - (i - 1) * 26)
    v:SetText(row[2])
    valueText[row[1]] = v
  end
end
Column(LEFT, 30)
Column(RIGHT, 290)

local foot = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
foot:SetPoint("BOTTOM", 0, 18)
foot:SetText("Reopen from Start > page 2 > Controller.   B to close.")

local close = CreateFrame("Button", "WowPadInfoCloseButton", F, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

-- Opened from the main menu's Controller wedge.
function WP.ShowInfo()
  local swap = WowPadDB and WowPadDB.swapBumpers
  if valueText.LB then valueText.LB:SetText(swap and "Target hostile" or "Target friendly") end
  if valueText.RB then valueText.RB:SetText(swap and "Target friendly" or "Target hostile") end
  if keyText["LB + R stick"] then keyText["LB + R stick"]:SetText(swap and "RB + R stick" or "LB + R stick") end
  local healer = WowPadDB and WowPadDB.wpBumperFlick == true
  local ally = swap and valueText.RB or valueText.LB
  if ally and healer then ally:SetText("Target last party pick") end
  F:Show()
end
