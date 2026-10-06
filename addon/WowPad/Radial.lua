-- Radial.lua - the Start button's main menu wheel (fixed position and size).
--
-- 8 wedges per page, LB/RB change page, D-pad or right-stick pointer selects,
-- A opens, B or Start closes. Every wedge is a secure button that runs a
-- macro (or, for entries with a click field, clicks a named button), so
-- opening panels doesn't taint the UI. Out of combat only (showing a frame
-- full of secure buttons is blocked in combat). Also provides the wheel art
-- shared with the utility ring (WP.BuildWheelArt).

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
local RADIUS, WEDGE = 120, 44     -- icon distance from the centre, icon size
local WHEEL = 400                 -- wheel diameter
local TEX = "Interface\\AddOns\\WowPad\\Textures\\"

local R = CreateFrame("Frame", "WowPadRadial", UIParent)
R:SetSize(420, 470)
R:SetPoint("CENTER", UIParent, "CENTER", 380, 30)
R:SetFrameStrata("DIALOG")
R:EnableMouse(true)
R:Hide()
WP.Radial = R
table.insert(WP.overlays, R)

-- Edit bar layout: the wheel shows with a mover box (drag to move, mouse
-- wheel to resize; Snap.lua). Saved in WowPadDB.movers.radial.
WP.MakeMover(R, "radial", "Main menu")
local shownForEdit = false
function WP.RadialSetEditing(on)
  if InCombatLockdown() then return end
  if on then
    if not R:IsShown() then R:Show(); shownForEdit = true end
    R.mover:Show()
  else
    R.mover:Hide()
    if shownForEdit then R:Hide(); shownForEdit = false end
  end
end
table.insert(WP.setupHooks, function() WP.ApplyMoverPos(R) end)

-- Wheel art (WowPad's own, scripts/make_radial_art.py): translucent wedges,
-- bronze frame. One quarter frame and two wedge shapes, turned into place in
-- 90 degree steps with SetTexCoord.
local ROT = {
  [0] = { 0, 0, 0, 1, 1, 0, 1, 1 },
  [1] = { 0, 1, 1, 1, 0, 0, 1, 0 },   -- 90 degrees clockwise
  [2] = { 1, 1, 1, 0, 0, 1, 0, 0 },
  [3] = { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local function Turn(tex, k) tex:SetTexCoord(unpack(ROT[k % 4])) end

-- Shared wheel art: also used by the utility ring (ActionBar.lua). Returns
-- the hub frame and a Highlight(index or nil) function (1 = top, clockwise).
-- Tile colours (art: scripts/make_radial_art.py): warm translucent dark
-- brown, lighter on the selected tile, plus a soft gold glow inside its border.
local FILL, FILL_SEL, GLOW = { 0.17, 0.085, 0.05, 0.82 }, { 0.30, 0.17, 0.07, 0.90 }, { 1, 0.78, 0.25, 0.75 }
function WP.BuildWheelArt(parent, size)
  local hub = CreateFrame("Frame", nil, parent)
  hub:SetSize(size, size)
  hub:SetFrameLevel(parent:GetFrameLevel())   -- under the wedge buttons
  local fills, glows = {}, {}
  for i = 1, 8 do                       -- 1 = top, clockwise
    local k, shape = math.floor((i - 1) / 2), (i % 2 == 1) and "0" or "45"
    local f = hub:CreateTexture(nil, "BACKGROUND")
    f:SetTexture(TEX .. "radial_wedge" .. shape)
    f:SetAllPoints()
    Turn(f, k)
    f:SetVertexColor(unpack(FILL))
    fills[i] = f
    local g = hub:CreateTexture(nil, "BORDER")
    g:SetTexture(TEX .. "radial_glow" .. shape)
    g:SetAllPoints()
    g:SetBlendMode("ADD")
    Turn(g, k)
    g:SetVertexColor(unpack(GLOW))
    g:Hide()
    glows[i] = g
  end
  for _, spot in ipairs({ { "TOPRIGHT", 0 }, { "BOTTOMRIGHT", 1 }, { "BOTTOMLEFT", 2 }, { "TOPLEFT", 3 } }) do
    local t = hub:CreateTexture(nil, "ARTWORK")
    t:SetTexture(TEX .. "radial_frame")
    t:SetSize(size / 2, size / 2)
    t:SetPoint(spot[1])
    Turn(t, spot[2])
  end
  local selected
  local function Highlight(idx)
    if idx == selected then return end
    if selected then fills[selected]:SetVertexColor(unpack(FILL)); glows[selected]:Hide() end
    selected = idx
    if idx then fills[idx]:SetVertexColor(unpack(FILL_SEL)); glows[idx]:Show() end
  end
  return hub, Highlight
end

local hub, Highlight = WP.BuildWheelArt(R, WHEEL)
hub:SetPoint("CENTER", 0, 10)

local title = R:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, 0)
title:SetText("Main Menu")
-- LB  o o o  RB   (current page in gold)
local pageBar = CreateFrame("Frame", nil, R)
pageBar:SetSize(10, 14)
pageBar:SetPoint("TOP", title, "BOTTOM", 0, -6)
local dots = {}
local lbText = pageBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local rbText = pageBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
WP.KeyText(lbText, "LB"); WP.KeyText(rbText, "RB")
local function LayoutDots(n)
  local gap = 14
  pageBar:SetWidth(n * gap)
  for i = 1, n do
    local d = dots[i]
    if not d then
      d = pageBar:CreateTexture(nil, "OVERLAY")
      d:SetTexture(TEX .. "dot")   -- white, so the colour below shows (disc is dark)
      d:SetSize(9, 9)
      dots[i] = d
    end
    d:ClearAllPoints()
    d:SetPoint("CENTER", pageBar, "LEFT", (i - 0.5) * gap, 0)
  end
  lbText:SetPoint("RIGHT", pageBar, "LEFT", -6, 0)
  rbText:SetPoint("LEFT", pageBar, "RIGHT", 6, 0)
end
local hint = WP.NewKeyLine(R, "GameFontHighlightSmall", 18)   -- icons level with the words (Glyphs.lua)
hint:SetPoint("BOTTOM", 0, 2)
hint:SetParts({ { key = "A", text = "open" }, { key = "B", text = "close" }, { key = "LB/RB", text = "page" } }, 10)

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
  LayoutDots(#PAGES)
  for i, d in ipairs(dots) do
    if i == page then d:SetVertexColor(1, 0.82, 0.2, 1); d:SetSize(11, 11)
    else d:SetVertexColor(0.55, 0.55, 0.55, 0.8); d:SetSize(8, 8) end
  end
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
    w:SetPoint("CENTER", R, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS + 18)
    w:RegisterForClicks("AnyUp") -- one toggle per click (Nav A uses :Click())
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetAllPoints()
    w.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.label:SetPoint("TOP", w, "BOTTOM", 0, -3)
    w.index = i
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
R:SetScript("OnHide", function() Highlight(nil) end)
R:SetScript("OnUpdate", function()
  local cur = WP.Nav and WP.Nav.cur
  Highlight(cur and cur.index and wedges[cur.index] == cur and cur.index or nil)
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
  local wasOpen, kbSend
  start:SetScript("PreClick", function(self)
    wasOpen = R:IsShown()
    -- Keyboard open: Start sends the line instead of closing everything.
    kbSend = WP.Keyboard and WP.Keyboard:IsShown() and not InCombatLockdown()
    if kbSend then self:SetAttribute("type", nil) end
  end)
  start:SetScript("PostClick", function(self)
    if kbSend then
      kbSend = false
      if not InCombatLockdown() then self:SetAttribute("type", "macro") end
      WP.Keyboard.Send()
      return
    end
    for _, o in ipairs(WP.overlays) do
      if o ~= R and o:IsShown() and not InCombatLockdown() then o:Hide() end
    end
    if InCombatLockdown() then return end
    if wasOpen then R:Hide() else R.Toggle() end
  end)
end)
