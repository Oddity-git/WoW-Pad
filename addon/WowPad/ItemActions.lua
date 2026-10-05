-- ItemActions.lua - L3 on a bag item: a small menu with what you can do to it
-- (Disenchant when you know it and the item qualifies, Destroy, Cancel).
-- Cancel is selected first. Destroy still asks for confirmation.
-- Out of combat only, like the rest of menu navigation.

local WP = WowPad
local Nav = WP.Nav

local F = CreateFrame("Frame", "WowPadItemActions", UIParent)
F:SetWidth(200)
F:SetFrameStrata("DIALOG")
F:EnableMouse(true)
F:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
F:SetPoint("CENTER", 0, 80)
F:Hide()
table.insert(WP.overlays, F)

local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -10)
title:SetWidth(184)

local item = {}          -- { link, bag, slot } the menu was opened for
local rows = {}          -- buttons in display order

local function Row(b, label)
  b:SetSize(180, 20)
  b:RegisterForClicks("AnyUp")
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 10, 0)
  b.text:SetText(label)
  b:Hide()
  return b
end

-- Disenchant: a secure button (casting is protected), set up out of combat.
local de
table.insert(WP.setupHooks, function()
  de = Row(CreateFrame("Button", "WowPadItemActionsDisenchant", F, "SecureActionButtonTemplate"), "Disenchant")
  de:SetAttribute("type", "macro")
  de:HookScript("OnClick", function() if not InCombatLockdown() then F:Hide() end end)
end)

local destroy = Row(CreateFrame("Button", "WowPadItemActionsDestroy", F), DELETE or "Destroy")
destroy:SetScript("OnClick", function()
  F:Hide()
  Nav.Destroy(item.link, item.bag, item.slot)
end)
local cancel = Row(CreateFrame("Button", "WowPadItemActionsCancel", F), CANCEL or "Cancel")
cancel:SetScript("OnClick", function() F:Hide() end)

-- Can this item be disenchanted by you? (green to epic armor or weapon)
local DE_ID = 13262
local function KnowsDisenchant()
  if IsSpellKnown then return IsSpellKnown(DE_ID) end
  local name = GetSpellInfo(DE_ID)
  return name and GetSpellInfo(name) ~= nil
end
local function CanDisenchant(link)
  if not KnowsDisenchant() then return false end
  local _, _, quality, _, _, class = GetItemInfo(link)
  local weapon, armor = GetAuctionItemClasses()
  return quality and quality >= 2 and quality <= 4 and (class == weapon or class == armor)
end
WP.CanDisenchant = CanDisenchant

function WP.OpenItemActions()
  if InCombatLockdown() then return end
  if F:IsShown() then F:Hide() return end
  local link, bag, slot = Nav.FocusedItem()
  if not (link and bag) then return end
  item.link, item.bag, item.slot = link, bag, slot
  local _, count = GetContainerItemInfo(bag, slot)
  title:SetText(link .. ((count and count > 1) and (" x" .. count) or ""))

  wipe(rows)
  if de then
    if CanDisenchant(link) then
      de:SetAttribute("macrotext", ("/cast %s\n/use %d %d"):format(GetSpellInfo(DE_ID), bag, slot))
      rows[#rows + 1] = de
    else
      de:Hide()
    end
  end
  rows[#rows + 1] = destroy
  rows[#rows + 1] = cancel
  for i, b in ipairs(rows) do
    b:ClearAllPoints()
    b:SetPoint("TOP", F, "TOP", 0, -30 - (i - 1) * 22)
    b:Show()
  end
  F:SetHeight(40 + #rows * 22)
  F:Show()
end
