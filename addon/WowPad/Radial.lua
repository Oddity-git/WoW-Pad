-- Radial.lua - Start: main menu wheel (fixed position and size).
--
-- 8 wedges per page, LB/RB change page, D-pad or right-stick pointer selects,
-- A opens, B or Start closes. Every wedge is a secure button that runs a
-- /macro or clicks a Blizzard micro button, so opening panels doesn't taint
-- the UI. (Character/Talents/Game Menu/Achievements/LFD/PvP micro buttons
-- react to mouse down/up, not :Click(), so those use their toggle functions.) Out of combat only for now (showing a frame full of
-- secure buttons is blocked in combat).

local WP = WowPad

local PAGES = {
  {
    { "Character",  "Interface\\Icons\\INV_Helmet_25",          macro = "/run ToggleCharacter('PaperDollFrame')" },
    { "Bags",       "Interface\\Icons\\INV_Misc_Bag_08",        macro = "/run OpenAllBags()" },
    { "Spellbook",  "Interface\\Icons\\INV_Misc_Book_09",       macro = "/run ToggleSpellBook(BOOKTYPE_SPELL)" },
    { "Talents",    "Interface\\Icons\\Ability_Marksmanship",   macro = "/run ToggleTalentFrame()" },
    { "Game Menu",  "Interface\\Icons\\INV_Misc_Gear_01",       macro = "/run if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) else ShowUIPanel(GameMenuFrame) end" },
    { "World Map",  "Interface\\Icons\\INV_Misc_Map_01",        macro = "/run ToggleFrame(WorldMapFrame)" },
    { "Social",     "Interface\\Icons\\INV_Letter_15",          macro = "/run ToggleFriendsFrame()" },
    { "Quest Log",  "Interface\\Icons\\INV_Misc_Note_01",       macro = "/run ToggleFrame(QuestLogFrame)" },
  },
  {
    { "Achievements",   "Interface\\Icons\\Achievement_General",    macro = "/run ToggleAchievementFrame()" },
    { "Dungeon Finder", "Interface\\Icons\\INV_Misc_GroupNeedMore",    macro = "/run ToggleLFDParentFrame()" },
    { "PvP",            "Interface\\Icons\\INV_BannerPVP_02",          macro = "/run TogglePVPFrame()" },
    { "Guild",          "Interface\\Icons\\INV_Shirt_GuildTabard_01",  macro = "/run ToggleFriendsFrame(3)" },
    { "Controller",     "Interface\\Icons\\INV_Misc_QuestionMark",     macro = "/run WowPad.ShowInfo()" },
    { "Calendar",       "Interface\\Icons\\INV_Misc_PocketWatch_01",
      macro = "/run if not IsAddOnLoaded('Blizzard_Calendar') then LoadAddOn('Blizzard_Calendar') end Calendar_Toggle()" },
    { "Macros",         "Interface\\Icons\\INV_Misc_Note_06",          macro = "/macro" },
    { "Chat",           "Interface\\Icons\\Spell_Holy_PrayerOfSpirit", macro = "/run ChatFrame_OpenChat('')" },
  },
  {
    { "Edit Bar",       "Interface\\Icons\\Trade_Engineering",          macro = "/run WowPad.ToggleEdit()" },
    { "Blizzard Bars",  "Interface\\Icons\\INV_Misc_EngGizmos_01",       macro = "/run WowPad.ToggleBlizzBars()" },
    { "Crosshair",      "Interface\\Icons\\Ability_Hunter_SniperShot",       macro = "/run WowPad.ToggleCrosshair()" },
    { "Bar Visibility", "Interface\\Icons\\Spell_Shadow_DetectInvisibility", macro = "/run WowPad.Bar.ToggleAlways()" },
  },
}
local RADIUS, WEDGE = 150, 54

local R = CreateFrame("Frame", "WowPadRadial", UIParent)
R:SetSize(420, 470)
R:SetPoint("CENTER", UIParent, "CENTER", 380, 30)
R:SetFrameStrata("DIALOG")
R:EnableMouse(true)
R:Hide()
WP.Radial = R
table.insert(WP.overlays, R)

local disc = R:CreateTexture(nil, "BACKGROUND")
disc:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
disc:SetVertexColor(0, 0, 0, 0.72)
disc:SetSize(RADIUS * 2 + WEDGE + 40, RADIUS * 2 + WEDGE + 40)
disc:SetPoint("CENTER", 0, 10)

local title = R:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, 0)
title:SetText("Main Menu")
local pageText = R:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pageText:SetPoint("TOP", title, "BOTTOM", 0, -4)
local hint = R:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("BOTTOM", 0, 0)
hint:SetText("A open    B close    LB/RB page")
local centerLabel = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
centerLabel:SetPoint("CENTER", 0, 10)

local wedges, page = {}, 1

function R.Page(step)
  if InCombatLockdown() then return end
  page = (page - 1 + step) % #PAGES + 1
  local entries = PAGES[page]
  for i, w in ipairs(wedges) do
    local e = entries[i]
    if e then
      w.icon:SetTexture(e[2])
      w.label:SetText(e[1])
      if e.click then
        w:SetAttribute("type", "click")
        w:SetAttribute("clickbutton", _G[e.click])
        w:SetAttribute("macrotext", nil)
      else
        w:SetAttribute("type", "macro")
        w:SetAttribute("macrotext", e.macro)
        w:SetAttribute("clickbutton", nil)
      end
      w:Show()
    else
      w:Hide()
    end
  end
  pageText:SetText(("LB   page %d / %d   RB"):format(page, #PAGES))
  if WP.Nav then WP.Nav.Select(nil) end
end

function R.Toggle()
  if InCombatLockdown() then
    WP.Print("The main menu isn't available in combat yet.")
    return
  end
  if R:IsShown() then R:Hide() return end
  page = 1
  R.Page(0)
  R:Show()
end

table.insert(WP.setupHooks, function()
  for i = 1, 8 do
    local angle = math.rad(90 - (i - 1) * 45)
    local w = CreateFrame("Button", "WowPadRadialWedge" .. i, R, "SecureActionButtonTemplate")
    w:SetSize(WEDGE, WEDGE)
    w:SetPoint("CENTER", R, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS + 10)
    w:RegisterForClicks("AnyUp") -- one toggle per click (Nav A uses :Click())
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetAllPoints()
    w.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.label:SetPoint("TOP", w, "BOTTOM", 0, -3)
    w:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    w:SetScript("OnEnter", function(self) centerLabel:SetText(self.label:GetText()) end)
    w:SetScript("OnLeave", function() centerLabel:SetText("") end)
    w:HookScript("OnClick", function() if not InCombatLockdown() then R:Hide() end end)
    wedges[i] = w
  end
  R.Page(0)
end)

-- Stick-direction selection: the DLL turns the right stick into pointer motion,
-- so the direction the pointer is moving = the direction the stick is held.
-- Hold a direction to highlight that wedge; it stays selected on release.
local hist, histN, SAMPLE_WINDOW, MIN_TRAVEL = {}, 0, 0.06, 10
R:SetScript("OnShow", function() histN = 0 end)
R:SetScript("OnUpdate", function()
  local x, y = GetCursorPosition()
  local now = GetTime()
  histN = histN + 1
  hist[histN] = { now, x, y }
  -- drop samples older than the window
  local first = 1
  while first < histN and now - hist[first][1] > SAMPLE_WINDOW do first = first + 1 end
  if first > 1 then
    for i = first, histN do hist[i - first + 1] = hist[i] end
    histN = histN - first + 1
  end
  local dx, dy = x - hist[1][2], y - hist[1][3]
  if dx * dx + dy * dy < MIN_TRAVEL * MIN_TRAVEL then return end
  local deg = math.deg(math.atan2(dy, dx))          -- 0 = right, 90 = up
  local idx = math.floor(((90 - deg) % 360 + 22.5) / 45) % 8 + 1
  local w = wedges[idx]
  if w and w:IsShown() and WP.Nav then WP.Nav.Select(w) end
end)

-- Start = Esc + menu: a secure macro closes open windows (untainted), then
-- the wheel opens. If the wheel was already open, Start just closes it.
table.insert(WP.setupHooks, function()
  local start = CreateFrame("Button", "WowPadStart", UIParent, "SecureActionButtonTemplate")
  start:RegisterForClicks("AnyDown")
  start:SetAttribute("type", "macro")
  start:SetAttribute("macrotext", "/run CloseAllWindows() CloseDropDownMenus()")
  local wasOpen
  start:SetScript("PreClick", function() wasOpen = R:IsShown() end)
  start:SetScript("PostClick", function()
    for _, o in ipairs(WP.overlays) do
      if o ~= R and o:IsShown() and not InCombatLockdown() then o:Hide() end
    end
    if InCombatLockdown() then return end
    if wasOpen then R:Hide() else R.Toggle() end
  end)
end)
