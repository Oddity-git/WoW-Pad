-- FirstTime.lua - first-time setup / welcome window.
-- Opens once for new installs (setup check first) and once after each update
-- (on the "What's new" page). /wp firsttime or Options reopens it any time.
-- Pages: setup check, basics, make it yours, good to know, what's new.
-- Works with the pad (D-pad + A, LB/RB = pages, B = close) and the mouse.

local WP = WowPad

-- Newest first. Shown on the last page.
local WHATS_NEW = {
  { "1.3.1", {
    "This setup window: checks your setup and shows what's new (/wp firsttime)",
    "Works with DialogUI and DragonUI New Era windows",
    "Windows another addon hides (transparent / off-screen) no longer take the selection",
  } },
  { "1.3.0", {
    "Back + A / Back + B: send or close chat without a keyboard",
    "Dungeon queue and loot rolls work with the D-pad (out of combat)",
    "L3 in bags: Disenchant / Destroy / Cancel",
    "D-pad scrolls long lists (professions, auction house, quest log)",
    "Lite bar: one action set at a time (Options > Bars)",
    "Windows remember your selection; option to swap LB/RB targeting",
  } },
  { "1.2.0", {
    "Minimap button: left-click edit layout, right-click options",
    "Edit mode snaps bars to the screen's centre line",
    "Separate XP and reputation bars",
  } },
}

local OK   = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t "
local WARN = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:16|t "
local TIP  = "|TInterface\\GossipFrame\\ActiveQuestIcon:16|t "
local Y    = "|cffffd100%s|r"

local F = CreateFrame("Frame", "WowPadFirstTime", UIParent)
F:SetSize(660, 500)
F:SetPoint("CENTER", 0, 40)
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
WP.FirstTime = F

local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -22)
local pageNum = F:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pageNum:SetPoint("TOPRIGHT", -40, -26)

local body = F:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body:SetPoint("TOPLEFT", 30, -56)
body:SetWidth(600)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")
body:SetSpacing(4)

local close = CreateFrame("Button", "WowPadFirstTimeCloseButton", F, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local function Button(name, label, w)
  local b = CreateFrame("Button", name, F, "UIPanelButtonTemplate")
  b:SetSize(w or 110, 24)
  b:SetText(label)
  return b
end
local prev = Button("WowPadFirstTimeBack", "Back")
prev:SetPoint("BOTTOMLEFT", 24, 20)
local nxt = Button("WowPadFirstTimeNext", "Next")
nxt:SetPoint("BOTTOMRIGHT", -24, 20)
local foot = F:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("BOTTOM", 0, 26)
foot:SetText("LB / RB: pages    B: close    /wp firsttime reopens this")

-- Page-specific action buttons (above Back/Next).
local actCamera = Button("WowPadFirstTimeCamera", "Set camera following to Never", 230)
local actEdit = Button("WowPadFirstTimeEdit", "Edit bar layout", 150)
local actOptions = Button("WowPadFirstTimeOptions", "Open options", 150)
actCamera:SetPoint("BOTTOMLEFT", 30, 56)
actEdit:SetPoint("BOTTOMLEFT", 30, 56)
actOptions:SetPoint("LEFT", actEdit, "RIGHT", 10, 0)

---------------------------------------------------------------------------
-- Setup checks (live)
---------------------------------------------------------------------------
local padSeen = false
local function HasKey(action, key)
  local k1, k2 = GetBindingKey(action)
  return k1 == key or k2 == key
end
local function KeyOf(action)
  return (GetBindingKey(action)) or "not bound"
end

local function SetupText()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  if padSeen or WP.mode == "controller" then
    add(OK .. Y:format("Controller detected."))
  else
    add(WARN .. Y:format("Press any button on your controller.") .. " If nothing changes, version.dll isn't")
    add("     loading: check it's next to Wow.exe and, on Linux, that WINEDLLOVERRIDES=version=n,b is set.")
    add("     On Windows, antivirus (Windows Defender) may have removed it: check Protection history.")
  end

  -- Hardware Cursor: only a troubleshooting tip (some setups need it, some don't).
  if GetCVar("gxCursor") ~= "1" then
    add(TIP .. "|cffaaaaaaTip: if a hand / sword cursor shows over the crosshair, turn on|r")
    add("     |cffaaaaaaHardware Cursor (Esc > Video).|r")
  end

  if HasKey("MOVEFORWARD", "W") and HasKey("MOVEBACKWARD", "S")
     and HasKey("STRAFELEFT", "Q") and HasKey("STRAFERIGHT", "E") then
    add(OK .. Y:format("Movement keys are the defaults") .. " (W/S, Q/E strafe), which WowPad presses.")
  else
    add(WARN .. Y:format("Your movement keys aren't the defaults:") .. (" forward %s, back %s, strafe %s / %s.")
        :format(KeyOf("MOVEFORWARD"), KeyOf("MOVEBACKWARD"), KeyOf("STRAFELEFT"), KeyOf("STRAFERIGHT")))
    add("     WowPad presses W/S/Q/E unless you set your keys in wowpad.ini under [Move]")
    add("     (next to Wow.exe), then restart the game. Fine if you've already done that.")
  end

  local key = (WowPadDB and WowPadDB.interactKey) or "F"
  local action = GetBindingAction(key)
  if action and action ~= "" then
    local nice = _G["BINDING_NAME_" .. action] or action
    add(OK .. Y:format("X interacts using your " .. key .. " key") .. " (" .. nice .. ").")
    add("     Interacting with what's in front of you (loot, NPCs, objects) needs the Awesome WotLK")
    add("     client mod, with its interaction key bound to " .. key .. " (or another key you pick with /wp interact KEY).")
  else
    add(WARN .. Y:format("Nothing is bound to " .. key .. ", so X only attacks.") .. " For looting, talking to NPCs")
    add("     etc., install Awesome WotLK and bind its interaction key to " .. key .. " (see README),")
    add("     or use /wp interact KEY to follow another key.")
  end

  if GetCVar("cameraSmoothStyle") == "0" then
    add(OK .. Y:format("Camera following: Never.") .. " The right stick is in charge of the camera.")
  else
    add(WARN .. Y:format("Recommended: camera following set to Never,") .. " so the camera doesn't swing")
    add("     behind you while you steer it with the right stick (button below).")
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function WhatsNewText()
  local lines = {}
  for _, v in ipairs(WHATS_NEW) do
    lines[#lines + 1] = Y:format("Version " .. v[1])
    for _, l in ipairs(v[2]) do lines[#lines + 1] = "  -  " .. l end
    lines[#lines + 1] = " "
  end
  return table.concat(lines, "\n")
end

local PAGES = {
  { title = "WowPad: setup check", text = SetupText, live = true, buttons = { actCamera } },
  { title = "The basics", text = function() return table.concat({
      Y:format("Left stick") .. " moves,  " .. Y:format("right stick") .. " turns the camera (a dot marks the crosshair).",
      Y:format("A") .. " jump,  " .. Y:format("B") .. " clear target / back,  " .. Y:format("X") .. " interact + attack,  "
        .. Y:format("Y") .. " target menu.",
      Y:format("D-pad") .. ": 4 action slots.  Hold " .. Y:format("LT") .. ", " .. Y:format("RT") .. " or "
        .. Y:format("both") .. " for 8 more slots each.",
      Y:format("LB / RB") .. ": target nearest friend / enemy.  Hold both: right stick zooms.",
      Y:format("Start") .. ": close windows, radial main menu.  " .. Y:format("Back") .. ": map (hold: bags).",
      Y:format("R3") .. ": pointer mode (RT / LT click).  " .. Y:format("L3") .. ": autorun.",
      " ",
      "With a window open (out of combat) the D-pad moves a gold selection, A clicks, X right-clicks,",
      "Y previews / compares gear, B closes, LB / RB switch windows. A hint bar shows what applies.",
      " ",
      "Touching the mouse or keyboard switches back to normal control at once; the pad switches back.",
      "Full button list: Start > page 2 > " .. Y:format("Controller") .. ".",
    }, "\n") end },
  { title = "Make it yours", text = function() return table.concat({
      Y:format("Edit bar layout") .. " (left-click the minimap button): drag spells, items, macros and mounts",
      "onto the round slots, drag bars to move them, mouse wheel to resize.",
      " ",
      Y:format("Options") .. " (right-click the minimap button, or /wp options):",
      "  -  Camera sensitivity, pointer speed, invert camera, smooth camera",
      "  -  Walk on slight stick tilt, run on full tilt",
      "  -  Swap LB / RB targeting,  X also starts attacking",
      "  -  Crosshair dot and crosshair tooltips",
      " ",
      Y:format("Options > WowPad > Bars") .. ":",
      "  -  Lite mode: one action set on screen, triggers swap it in",
      "  -  Hide Blizzard's action bars, bar size, always visible",
      "  -  WowPad's XP, reputation, pet and cast bars (turn off to use another addon's)",
      "  -  Minimap button",
    }, "\n") end, buttons = { actEdit, actOptions } },
  { title = "Good to know", text = function() return table.concat({
      Y:format("Chat:") .. " Back + A sends (or opens chat), Back + B closes it. There's no on-screen keyboard;",
      "type with a keyboard or your system's own (e.g. Steam Deck).",
      " ",
      Y:format("Bags:") .. " L3 on an item: Disenchant / Destroy / Cancel.  Y: preview, hold to compare.",
      " ",
      Y:format("Crosshair stuck somewhere odd?") .. " Press R3 twice.",
      Y:format("Something stuck?") .. " Hold Back + Start for 1 second (kill switch), or touch mouse / keyboard.",
      Y:format("Keep crosshair tooltips (peek) on:") .. " off is experimental and the camera can jump.",
      Y:format("Hand / sword cursor over the crosshair?") .. " Turn on Hardware Cursor (Esc > Video).",
      " ",
      Y:format("After updating WowPad,") .. " restart the game fully: /reload doesn't load new addon files.",
      "Bug or idea? Open an issue on GitHub (Oddity-git/WoW-Pad) with your wowpad.log.",
      " ",
      Y:format("Setup commands") .. " (type in chat):",
    }, "\n") end },
  { title = "What's new", text = WhatsNewText },
}
PAGES[4].commands = true

-- Setup commands as two aligned columns (command | what it does), under page 4's text.
local COMMANDS = {
  { "/wp interact KEY", "X follows that key instead of F" },
  { "/wp options",      "settings" },
  { "/wp edit",         "edit bar layout" },
  { "/wp blizz",        "show / hide Blizzard's action bars" },
  { "/wp bar",          "controller bar always, or only in controller mode" },
  { "/wp firsttime",    "this window" },
}
local cmdCol = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cmdCol:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 16, -6)
cmdCol:SetJustifyH("LEFT")
cmdCol:SetSpacing(4)
local descCol = F:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
descCol:SetPoint("TOPLEFT", cmdCol, "TOPLEFT", 150, 0)
descCol:SetJustifyH("LEFT")
descCol:SetSpacing(4)
do
  local a, b = {}, {}
  for i, c in ipairs(COMMANDS) do a[i], b[i] = c[1], c[2] end
  cmdCol:SetText(table.concat(a, "\n"))
  descCol:SetText(table.concat(b, "\n"))
end

local page = 1
local ALL_ACTIONS = { actCamera, actEdit, actOptions }

local function Render()
  local p = PAGES[page]
  title:SetText(p.title)
  pageNum:SetText(page .. " / " .. #PAGES)
  body:SetText(p.text())
  if p.commands then cmdCol:Show(); descCol:Show() else cmdCol:Hide(); descCol:Hide() end
  for _, b in ipairs(ALL_ACTIONS) do b:Hide() end
  for _, b in ipairs(p.buttons or {}) do b:Show() end
  if page == 1 and GetCVar("cameraSmoothStyle") == "0" then actCamera:Hide() end
  if page > 1 then prev:Show() else prev:Hide() end
  nxt:SetText(page < #PAGES and "Next" or "Done")
end

function F.Page(step)
  page = math.max(1, math.min(#PAGES, page + step))
  Render()
end

prev:SetScript("OnClick", function() F.Page(-1) end)
nxt:SetScript("OnClick", function() if page < #PAGES then F.Page(1) else F:Hide() end end)
actCamera:SetScript("OnClick", function()
  SetCVar("cameraSmoothStyle", "0")
  WP.Print("Camera following set to Never (Interface > Camera to change it back).")
  Render()
end)
actEdit:SetScript("OnClick", function() F:Hide(); if WP.ToggleEdit then WP.ToggleEdit() end end)
actOptions:SetScript("OnClick", function() F:Hide(); if WP.OpenOptions then WP.OpenOptions() end end)

-- Live refresh of the setup checks.
local acc = 0
F:SetScript("OnUpdate", function(_, e)
  if WP.mode == "controller" then padSeen = true end
  acc = acc + e
  if acc < 0.5 then return end
  acc = 0
  if PAGES[page].live then Render() end
end)

local function Version()
  return GetAddOnMetadata and GetAddOnMetadata("WowPad", "Version") or "?"
end
F:SetScript("OnHide", function()
  if WowPadDB then WowPadDB.firstTimeSeen = Version() end
end)

function WP.ShowFirstTime(startPage)
  if InCombatLockdown() then WP.Print("After combat."); return end
  page = startPage or 1
  Render()
  F:Show()
end

---------------------------------------------------------------------------
-- Auto-open: new install -> setup check; update -> what's new. Once per version.
---------------------------------------------------------------------------
local existingUser
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
local pending, delay = false, 0
ev:SetScript("OnEvent", function(self, event, arg)
  if event == "ADDON_LOADED" and arg == "WowPad" then
    -- Saved settings from before this window existed = someone updating.
    existingUser = WowPadDB ~= nil and (WowPadDB.bar ~= nil or WowPadDB.firstTimeSeen ~= nil)
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    if WowPadDB and WowPadDB.firstTimeSeen ~= Version() and not F:IsShown() then
      pending, delay = true, 0
    end
  end
end)
ev:SetScript("OnUpdate", function(_, e)
  if not pending then return end
  delay = delay + e
  if delay < 3 or InCombatLockdown() then return end   -- let the UI settle first
  pending = false
  WP.ShowFirstTime(existingUser and #PAGES or 1)
end)
