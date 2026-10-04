-- Options.lua - Esc > Interface > AddOns > WowPad (or /wp options).
--
-- Two kinds of setting:
--  * addon settings (bar, crosshair, messages): apply immediately;
--  * DLL settings (stick speeds, invert, peek delay): the addon can't talk to
--    the DLL directly, so they are saved in WowPadDB (wp* keys) and the DLL
--    reads them from SavedVariables\WowPad.lua, which WoW writes on /reload.
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

local DLL_KEYS = { wpCamSens = 1, wpPtrSens = 1, wpZoomSens = 1, wpInvertY = false, wpPeekDelay = 250, wpWalkRun = false, wpCamSmooth = false }
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

-- Slider: opts = { min, max, step, fmt(v), get(), set(v) }
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

  -- Left column: the sticks (DLL, needs Apply)
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

  -- Right column: addon settings (immediate)
  Header("Buttons", R - 4, -56)
  Check("WowPadOptXAttack", "X also starts auto attack",
    "X interacts (your " .. (WowPadDB.interactKey or "F") .. " binding) and starts attacking a hostile target.",
    R - 4, -74, function() return WowPadDB.xAttack ~= false end,
    function(v) WowPadDB.xAttack = v; WP.RefreshInteract() end)

  Header("Messages", R - 4, -108)
  Check("WowPadOptStatus", "Show the status line", "Mode, set and context above the bar.",
    R - 4, -126, function() return WowPadDB.showStatus == true end,
    function(v) WowPadDB.showStatus = v; WP.UpdateStatus() end)
  Check("WowPadOptDebug", "Debug messages in chat", nil,
    R - 4, -150, function() return WowPadDB.debug == true end,
    function(v) WowPadDB.debug = v end)

  Header("|cffff9900Experimental|r", R - 4, -184)
  Check("WowPadOptWalk", "Walk/run by stick tilt*",
    "Slight tilt walks, full tilt runs, using the game's Run/Walk toggle. Stopping always returns to running. If you press the "
    .. "keyboard Run/Walk key yourself, slight and full tilt swap; press that key again to fix it.",
    R - 4, -202, DllGet("wpWalkRun"), DllSet("wpWalkRun"))
  Check("WowPadOptSmooth", "Smooth camera*",
    "Smooths right-stick camera turning, so it glides instead of stepping. Adds a little delay "
    .. "(about 60 ms, [Camera] SmoothMs in wowpad.ini). Camera only, not the pointer.",
    R - 4, -226, DllGet("wpCamSmooth"), DllSet("wpCamSmooth"))

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
      get = function() return (WowPadDB.bar and WowPadDB.bar.scale) or 1 end,
      set = function(v) if WP.Bar then WP.Bar.SetScale(v) end end })
  local edit = CreateFrame("Button", "WowPadOptEdit", barsPanel, "UIPanelButtonTemplate")
  edit:SetSize(150, 22)
  edit:SetPoint("TOPLEFT", L - 4, -168)
  edit:SetText("Edit bar layout")
  edit:SetScript("OnClick", function()
    if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
    if WP.ToggleEdit then WP.ToggleEdit() end
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
