-- UnitMenu.lua - Y: a target menu like right-clicking a unit frame.
--
-- Blizzard's own unit menu can't do protected things (Set Focus) when an
-- addon opens it, so this is our own list of secure buttons. Out of combat
-- only.

local WP = WowPad
local MAX_ITEMS = 12

local M = CreateFrame("Frame", "WowPadUnitMenuFrame", UIParent)
M:SetWidth(170)
M:SetFrameStrata("DIALOG")
M:EnableMouse(true)
M:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
M:Hide()
table.insert(WP.overlays, M)
WP.UnitMenu = M

local title = M:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -10)

-- { label, shown-when(unit) -> bool, secure button attributes }
local function isOtherPlayer(u) return UnitIsPlayer(u) and not UnitIsUnit(u, "player") end
local function isFriendlyPlayer(u) return isOtherPlayer(u) and UnitIsFriend("player", u) end
local ITEMS = {
  { "Set Focus",       function(u) return true end,                     { type = "focus", unit = "target" } },
  { "Clear Focus",     function(u) return UnitExists("focus") end,      { type = "macro", macrotext = "/clearfocus" } },
  { "Assist",          function(u) return UnitIsFriend("player", u) and not UnitIsUnit(u, "player") end,
                                                                        { type = "macro", macrotext = "/assist" } },
  { "Whisper",         isFriendlyPlayer, { type = "macro", macrotext = "/run ChatFrame_SendTell(UnitName('target'))" } },
  { "Invite",          function(u) return isFriendlyPlayer(u) and not UnitInParty(u) and not UnitInRaid(u) end,
                                         { type = "macro", macrotext = "/invite" } },
  { "Inspect",         isOtherPlayer,    { type = "macro", macrotext = "/inspect" } },
  { "Trade",           isFriendlyPlayer, { type = "macro", macrotext = "/run InitiateTrade('target')" } },
  { "Follow",          isFriendlyPlayer, { type = "macro", macrotext = "/follow" } },
  { "Duel",            isFriendlyPlayer, { type = "macro", macrotext = "/duel" } },
  { "Mark: Skull",     function(u) return true end, { type = "macro", macrotext = "/run SetRaidTarget('target', 8)" } },
  { "Clear Target",    function(u) return true end, { type = "macro", macrotext = "/cleartarget" } },
}
local CLEAR_ATTRS = { "unit", "macrotext" }

local buttons = {}

function M.Open()
  if InCombatLockdown() then WP.Print("The target menu isn't available in combat yet.") return end
  if M:IsShown() then M:Hide() return end
  if not UnitExists("target") then WP.Print("No target.") return end
  title:SetText(UnitName("target") or "Target")
  local n = 0
  for _, item in ipairs(ITEMS) do
    if n < MAX_ITEMS and item[2]("target") then
      n = n + 1
      local b = buttons[n]
      for _, a in ipairs(CLEAR_ATTRS) do b:SetAttribute(a, nil) end
      for k, v in pairs(item[3]) do b:SetAttribute(k, v) end
      b.text:SetText(item[1])
      b:Show()
    end
  end
  for i = n + 1, MAX_ITEMS do buttons[i]:Hide() end
  M:SetHeight(34 + n * 22)
  M:ClearAllPoints()
  if TargetFrame and TargetFrame:IsVisible() then
    M:SetPoint("TOPLEFT", TargetFrame, "TOPRIGHT", -20, -8)
  else
    M:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  end
  M:Show()
end

table.insert(WP.setupHooks, function()
  for i = 1, MAX_ITEMS do
    local b = CreateFrame("Button", "WowPadUnitMenuItem" .. i, M, "SecureActionButtonTemplate")
    b:SetSize(150, 20)
    b:SetPoint("TOP", M, "TOP", 0, -28 - (i - 1) * 22)
    b:RegisterForClicks("AnyUp")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 10, 0)
    b:HookScript("OnClick", function() if not InCombatLockdown() then M:Hide() end end)
    b:Hide()
    buttons[i] = b
  end
end)

WP.InsecureButton("WowPadUnitMenu", function() M.Open() end)
