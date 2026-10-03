-- Info.lua - Controller Info screen (radial menu > Controller). B closes.

local WP = WowPad

local LEFT = {
  { "Left stick",  "Move" },
  { "L3",          "Autorun" },
  { "LB",          "Target friendly" },
  { "LB + RB",     "Right stick zooms" },
  { "LT (hold)",   "Left action set" },
  { "LT + RT",     "Bottom action set" },
  { "D-pad",       "Action slots" },
  { "Back",        "Map (hold: bags)" },
}
local RIGHT = {
  { "Right stick", "Camera / pointer" },
  { "R3",          "Pointer mode" },
  { "RB",          "Target hostile" },
  { "RT (hold)",   "Right action set" },
  { "A / B",       "Jump / Back" },
  { "X / Y",       "Interact + attack / Target menu" },
  { "Y in menus",  "Hold to compare items" },
  { "Start",       "Close windows + main menu" },
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

local function Column(list, x)
  for i, row in ipairs(list) do
    local k = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    k:SetPoint("TOPLEFT", x, -56 - (i - 1) * 26)
    k:SetText(row[1])
    local v = F:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    v:SetPoint("TOPLEFT", x + 100, -56 - (i - 1) * 26)
    v:SetText(row[2])
  end
end
Column(LEFT, 30)
Column(RIGHT, 290)

local foot = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
foot:SetPoint("BOTTOM", 0, 18)
foot:SetText("Reopen from Start > page 2 > Controller.   B to close.")

local close = CreateFrame("Button", "WowPadInfoCloseButton", F, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

function WP.ShowInfo() F:Show() end
