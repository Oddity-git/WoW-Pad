-- Options.lua - the options pages: Esc > Interface > AddOns > WowPad (or
-- /wp options), with a Bars sub-page.
--
-- Two kinds of setting:
--  * addon settings (bars, crosshair, buttons, messages): apply immediately;
--  * DLL settings (marked *: stick speeds, invert, peek delay, healer mode,
--    walk/run, smooth camera, utility ring): the addon can't talk to the DLL
--    directly, so they are saved in WowPadDB (wp* keys) and the DLL reads them
--    from SavedVariables\WowPad.lua, which WoW writes on /reload.
--    "Apply" does the /reload.

local WP = WowPad

local panel = CreateFrame("Frame", "WowPadOptions", UIParent)
panel.name = "WowPad"
panel:Hide()
-- Sub-page: Esc > Interface > AddOns > WowPad > Bars
local barsPanel = CreateFrame("Frame", "WowPadOptionsBars", UIParent)
barsPanel.name = "Bars"
barsPanel.parent = "WowPad"
barsPanel:Hide()
local target = panel   -- page the helpers below add controls to

local DLL_KEYS = { wpCamSens = 1, wpPtrSens = 1, wpZoomSens = 1, wpInvertY = false, wpPeekDelay = 250, wpWalkRun = false, wpCamSmooth = false, wpBumperFlick = false, wpRingSlot = 0 }
local saved = {}   -- DLL values as of the last reload

local function DllValue(k)
  local v = WowPadDB[k]
  if v == nil then v = DLL_KEYS[k] end
  return v
end

local function Pending()
  for k in pairs(DLL_KEYS) do
    if DllValue(k) ~= saved[k] then return true end
  end
  return false
end

local applyBtn, pendingText
local function Refresh()
  if not applyBtn then return end
  if Pending() then
    pendingText:SetText("|cffffd100Changes marked * need Apply|r")
    applyBtn:Enable()
  else
    pendingText:SetText("|cff888888In use.|r")
    applyBtn:Disable()
  end
end

local controls = {}

-- Slider: o = { min, max, step, fmt(v), get(), set(v) }
local function Slider(name, label, tip, x, y, o)
  local s = CreateFrame("Slider", name, target, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", x, y)
  s:SetWidth(170)
  s:SetMinMaxValues(o.min, o.max)
  s:SetValueStep(o.step)
  _G[name .. "Low"]:SetText(o.fmt(o.min))
  _G[name .. "High"]:SetText(o.fmt(o.max))
  s.tooltipText = tip
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / o.step + 0.5) * o.step
    _G[name .. "Text"]:SetText(label .. ": " .. o.fmt(v))
    if self.loading then return end
    o.set(v)
    Refresh()
  end)
  s.get = o.get
  table.insert(controls, s)
  return s
end

local function Check(name, label, tip, x, y, get, set)
  local c = CreateFrame("CheckButton", name, target, "InterfaceOptionsCheckButtonTemplate")
  c:SetPoint("TOPLEFT", x, y)
  _G[name .. "Text"]:SetText(label)
  c.tooltipText = tip
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Refresh() end)
  c.get = get
  c.isCheck = true
  table.insert(controls, c)
  return c
end

local function Header(text, x, y)
  local h = target:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h:SetPoint("TOPLEFT", x, y)
  h:SetText(text)
end

local function Pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
local function Ms(v) return ("%d ms"):format(math.floor(v + 0.5)) end
local function X(v) return ("%.2fx"):format(v) end
local function DllSet(k) return function(v) WowPadDB[k] = v end end
local function DllGet(k) return function() return DllValue(k) end end

local built = false
local function Build()
  built = true
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("WowPad")
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Stick speeds: 100% = wowpad.ini.   |cffffd100*|r = needs Apply (reloads the UI).")

  -- Left column: sticks (DLL, needs Apply) and crosshair
  local L, R = 20, 220   -- the panel is only ~415 wide
  Header("Sticks", L - 4, -56)
  Slider("WowPadOptCam", "Camera sensitivity*",
    "How fast the right stick turns the camera. Stacks with WoW's Mouse Look Speed.", L, -86,
    { min = 0.05, max = 2, step = 0.05, fmt = Pct, get = DllGet("wpCamSens"), set = DllSet("wpCamSens") })
  Slider("WowPadOptPtr", "Pointer speed*",
    "How fast the right stick moves the pointer in pointer mode (R3) and menus.", L, -126,
    { min = 0.05, max = 2, step = 0.05, fmt = Pct, get = DllGet("wpPtrSens"), set = DllSet("wpPtrSens") })
  Slider("WowPadOptZoom", "Zoom speed*",
    "How fast LB+RB + right stick zooms the camera.", L, -166,
    { min = 0.25, max = 3, step = 0.25, fmt = Pct, get = DllGet("wpZoomSens"), set = DllSet("wpZoomSens") })
  Check("WowPadOptInv", "Invert camera up/down*", nil, L - 4, -190,
    DllGet("wpInvertY"), DllSet("wpInvertY"))

  Header("Crosshair", L - 4, -222)
  Check("WowPadOptCross", "Show the crosshair dot", "A dot in the middle while the camera is under stick control.",
    L - 4, -240, function() return WowPadDB.crosshair ~= false end,
    function(v) WowPadDB.crosshair = v end)
  Check("WowPadOptPeek", "Crosshair tooltips (peek)",
    "When the right stick rests, camera look pauses for a moment so WoW shows the tooltip of whatever is "
    .. "under the crosshair. Works best with Hardware Cursor on (Video options). Turning it off is "
    .. "experimental: the camera can jump after closing a window.",
    L - 4, -264, function() return WowPadDB.peek ~= false end,
    function(v) WowPadDB.peek = v end)
  local peekNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  peekNote:SetPoint("TOPLEFT", L + 26, -290)
  peekNote:SetText("|cffff9900Turning it off is experimental.|r")
  Slider("WowPadOptPeekDelay", "Peek delay*",
    "How long the right stick must rest before peek mode pauses the camera.", L, -332,
    { min = 100, max = 1000, step = 50, fmt = Ms, get = DllGet("wpPeekDelay"), set = DllSet("wpPeekDelay") })

  applyBtn = CreateFrame("Button", "WowPadOptApply", panel, "UIPanelButtonTemplate")
  applyBtn:SetSize(100, 22)
  applyBtn:SetPoint("TOPRIGHT", -16, -16)
  applyBtn:SetText("Apply")
  applyBtn:SetScript("OnClick", function()
    if InCombatLockdown() then WP.Print("Leave combat first."); return end
    ReloadUI()
  end)
  pendingText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  pendingText:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)

  -- Right column: buttons, messages, experimental (* = DLL, needs Apply)
  Header("Buttons", R - 4, -56)
  Check("WowPadOptXAttack", "X also starts auto attack",
    "X interacts (your " .. (WowPadDB.interactKey or "F") .. " binding) and starts attacking a hostile target.",
    R - 4, -74, function() return WowPadDB.xAttack ~= false end,
    function(v) WowPadDB.xAttack = v; WP.RefreshInteract() end)
  Check("WowPadOptSwapLBRB", "Swap LB / RB targeting",
    "LB targets enemies and RB targets friends. In menus LB/RB still switch windows as before.",
    R - 4, -98, function() return WowPadDB.swapBumpers == true end,
    function(v)
      WowPadDB.swapBumpers = v
      if InCombatLockdown() then WP.Print("Swap applies after combat.") end
      WP.RefreshInteract()
    end)

  Check("WowPadOptKeyboard", "On-screen keyboard (Back + A)",
    "Back + A opens WowPad's keyboard above the chat window. Off: Back + A opens the normal chat box, "
    .. "and the keyboard is never loaded.",
    R - 4, -122, function() return WowPadDB.keyboard ~= false end,
    function(v)
      WowPadDB.keyboard = v
      if not v and WP.Keyboard and WP.Keyboard:IsShown() then WP.Keyboard:Hide() end
    end)
  Check("WowPadOptBumperFlick", "Healer mode*",
    "Tapping your ally-target bumper (LB, or RB if swapped) targets the party member you last picked (you at first). "
    .. "Hold it and flick the right stick down / up for the next / previous member (you, then party 1-4); a gold frame "
    .. "marks them on your unit frames. Works in combat. While the bumper is held, the right stick's up/down is used "
    .. "for this (left/right still turns the camera). Off: the bumper targets the nearest friendly.",
    R - 4, -146, DllGet("wpBumperFlick"), DllSet("wpBumperFlick"))
  Header("Messages", R - 4, -180)
  Check("WowPadOptStatus", "Show the status line", "Mode, set and context above the bar.",
    R - 4, -198, function() return WowPadDB.showStatus == true end,
    function(v) WowPadDB.showStatus = v; WP.UpdateStatus() end)
  Check("WowPadOptDebug", "Debug messages in chat", nil,
    R - 4, -222, function() return WowPadDB.debug == true end,
    function(v) WowPadDB.debug = v end)

  Header("|cffff9900Experimental|r", R - 4, -256)
  Check("WowPadOptWalk", "Walk/run by stick tilt*",
    "Slight tilt walks, full tilt runs, using the game's Run/Walk toggle. Stopping always returns to running. If you press the "
    .. "keyboard Run/Walk key yourself, slight and full tilt swap; press that key again to fix it.",
    R - 4, -274, DllGet("wpWalkRun"), DllSet("wpWalkRun"))
  Check("WowPadOptSmooth", "Smooth camera*",
    "Smooths right-stick camera turning, so it glides instead of stepping. Adds a little delay "
    .. "(about 60 ms, [Camera] SmoothMs in wowpad.ini). Camera only, not the pointer.",
    R - 4, -298, DllGet("wpCamSmooth"), DllSet("wpCamSmooth"))

  local ft = CreateFrame("Button", "WowPadOptFirstTime", panel, "UIPanelButtonTemplate")
  ft:SetSize(170, 22)
  ft:SetPoint("TOPLEFT", R - 4, -334)
  ft:SetText("First-time setup")
  ft:SetScript("OnClick", function()
    if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
    if WP.ShowFirstTime then WP.ShowFirstTime(1) end
  end)

  -- Bars page
  target = barsPanel
  local bt = barsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  bt:SetPoint("TOPLEFT", 16, -16)
  bt:SetText("WowPad: Bars")
  local bs = barsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  bs:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -6)
  bs:SetText("Changes apply right away. Move and resize bars with Edit bar layout.")
  Header("Controller bar", L - 4, -56)
  Check("WowPadOptAlways", "Always visible", "Off: the bar shows only in controller mode.",
    L - 4, -74, function() return WowPadDB.barAlways ~= false end,
    function(v)
      if (WowPadDB.barAlways ~= false) ~= v and WP.Bar then WP.Bar.ToggleAlways() end
    end)
  Check("WowPadOptBlizz", "Hide Blizzard action bars", "Hides the default bottom bars and art.",
    L - 4, -98, function() return WowPadDB.hideBlizz ~= false end,
    function(v) if (WowPadDB.hideBlizz ~= false) ~= v and WP.ToggleBlizzBars then WP.ToggleBlizzBars() end end)
  Slider("WowPadOptScale", "Bar size", "Size of the controller bar.", L, -140,
    { min = 0.4, max = 1.6, step = 0.05, fmt = X,
      get = function()
        local p = WowPadDB.bar
        if WowPadDB.barLite and p and p.lite then return p.lite.scale or 1 end
        return (p and p.scale) or 1
      end,
      set = function(v) if WP.Bar then WP.Bar.SetScale(v) end end })
  local edit = CreateFrame("Button", "WowPadOptEdit", barsPanel, "UIPanelButtonTemplate")
  edit:SetSize(150, 22)
  edit:SetPoint("TOPLEFT", L - 4, -168)
  edit:SetText("Edit bar layout")
  edit:SetScript("OnClick", function()
    if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
    if WP.ToggleEdit then WP.ToggleEdit() end
  end)

  Header("Lite mode", R - 4, -56)
  Check("WowPadOptLite", "Show one set at a time",
    "One cluster instead of four: it shows your default set, and holding LT, RT or both shows that set in "
    .. "its place. Has its own position and size (move it in Edit bar layout; it can sit on the bottom edge). "
    .. "In Edit bar layout, tabs above it pick which set you're assigning.",
    R - 4, -74, function() return WowPadDB.barLite == true end,
    function(v)
      if InCombatLockdown() then WP.Print("Leave combat first."); return end
      if WP.Bar and WP.Bar.SetLite then WP.Bar.SetLite(v) end
      if WowPadOptScale and WowPadOptScale.get then
        WowPadOptScale.loading = true; WowPadOptScale:SetValue(WowPadOptScale.get()); WowPadOptScale.loading = false
      end
    end)

  -- Utility ring: which bar slot opens it (the DLL needs it too: Apply).
  Header("Utility ring", R - 4, -116)
  local SETS = { [0] = "Default", "LT", "RT", "LT+RT" }
  local function SlotName(v)
    if not v or v <= 0 then return "None" end
    local set, i = math.floor(v / 10), v % 10
    return SETS[set] .. ": " .. WP.SLOT_LABELS[i]
  end
  local dd = CreateFrame("Frame", "WowPadOptRing", barsPanel, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", R - 20, -134)
  UIDropDownMenu_SetWidth(dd, 150)
  local function Pick(_, v)
    WowPadDB.wpRingSlot = v
    UIDropDownMenu_SetText(dd, SlotName(v))
    CloseDropDownMenus()
    Refresh()   -- main page: "Changes marked * need Apply" + its Apply button
  end
  UIDropDownMenu_Initialize(dd, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    if (level or 1) == 1 then
      info.text, info.arg1, info.func = "None", 0, Pick
      info.checked = (tonumber(WowPadDB.wpRingSlot) or 0) == 0
      UIDropDownMenu_AddButton(info, 1)
      for set = 0, 3 do
        info = UIDropDownMenu_CreateInfo()
        info.text, info.hasArrow, info.notCheckable, info.value = SETS[set] .. " set", true, true, set
        UIDropDownMenu_AddButton(info, 1)
      end
    else
      local set = tonumber(UIDROPDOWNMENU_MENU_VALUE)
      if not set then return end
      for i = 1, (set == 0 and 4 or 8) do       -- default set: A/B/X/Y are fixed
        info = UIDropDownMenu_CreateInfo()
        info.text, info.arg1, info.func = WP.SLOT_LABELS[i], set * 10 + i, Pick
        info.checked = tonumber(WowPadDB.wpRingSlot) == set * 10 + i
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end)
  UIDropDownMenu_SetText(dd, SlotName(tonumber(WowPadDB.wpRingSlot)))
  local rn = barsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  rn:SetPoint("TOPLEFT", R, -166)
  rn:SetWidth(180)
  rn:SetJustifyH("LEFT")
  rn:SetText("Hold that button, point the right stick, let go to use. Fill the wedges in Edit bar layout. Needs Apply.")
  local ap = CreateFrame("Button", "WowPadOptRingApply", barsPanel, "UIPanelButtonTemplate")
  ap:SetSize(80, 22)
  ap:SetPoint("TOPLEFT", R, -204)
  ap:SetText("Apply")
  ap:SetScript("OnClick", function()
    if InCombatLockdown() then WP.Print("Leave combat first."); return end
    ReloadUI()
  end)

  Header("Extra bars", L - 4, -206)
  Check("WowPadOptXP", "XP bar", "WowPad's own XP bar. Turn off to use another addon's.",
    L - 4, -224, function() return WowPadDB.showXP ~= false end,
    function(v) WowPadDB.showXP = v; if WP.Extra then WP.Extra.ApplyShown() end end)
  Check("WowPadOptRep", "Reputation bar", "WowPad's own reputation bar (the faction you watch). Turn off to use another addon's.",
    L - 4, -248, function() return WowPadDB.showRep ~= false end,
    function(v) WowPadDB.showRep = v; if WP.Extra then WP.Extra.ApplyShown() end end)
  Check("WowPadOptPet", "Pet bar", "WowPad's own pet bar (mouse). Turn off to use another addon's. Changes after combat if you're fighting.",
    L - 4, -272, function() return WowPadDB.showPet ~= false end,
    function(v) WowPadDB.showPet = v; if WP.Extra then WP.Extra.ApplyShown() end end)
  Check("WowPadOptCast", "Cast bar (movable)", "WowPad's own player cast bar, movable in Edit bar layout; hides Blizzard's. "
    .. "Turn off to get Blizzard's back, or to use another cast bar addon.",
    L - 4, -296, function() return WowPadDB.castBar ~= false end,
    function(v) WowPadDB.castBar = v; if WP.Extra then WP.Extra.ApplyShown() end end)
  local note = barsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", L + 26, -326)
  note:SetJustifyH("LEFT")
  note:SetText("Using another addon for one of these? Turn WowPad's off.")

  Header("Minimap", L - 4, -350)
  Check("WowPadOptMinimap", "Minimap button", "Left-click: Edit bar layout. Right-click: these options. Drag it around the minimap.",
    L - 4, -368, function() return not (WowPadDB.minimap and WowPadDB.minimap.hide) end,
    function(v)
      WowPadDB.minimap = WowPadDB.minimap or {}
      WowPadDB.minimap.hide = not v
      if WP.UpdateMinimapButton then WP.UpdateMinimapButton() end
    end)
  target = panel
end

local function OnShowPage()
  if not built then Build() end
  for _, c in ipairs(controls) do
    if c.isCheck then c:SetChecked(c.get())
    else c.loading = true; c:SetValue(c.get()); c.loading = false end
  end
  Refresh()
end
panel:SetScript("OnShow", OnShowPage)
barsPanel:SetScript("OnShow", OnShowPage)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  WowPadDB = WowPadDB or {}
  for k in pairs(DLL_KEYS) do saved[k] = DllValue(k) end
  InterfaceOptions_AddCategory(panel)
  InterfaceOptions_AddCategory(barsPanel)
end)

function WP.OpenOptions()
  InterfaceOptionsFrame_OpenToCategory(panel)
  InterfaceOptionsFrame_OpenToCategory(panel) -- 3.3.5 sometimes needs a second call
end

-- /wp sens 0.5  (camera, applies after /reload)
function WP.SetCamSens(v)
  v = math.max(0.05, math.min(2, v))
  WowPadDB.wpCamSens = v
  WP.Print(("Camera sensitivity %s - type /reload to apply."):format(Pct(v)))
end
