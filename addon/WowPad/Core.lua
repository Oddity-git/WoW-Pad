-- Core.lua - WowPad: signal bindings, set switching, mode, mouselook.
--
-- How it fits together:
--  * The DLL presses signal keys (Signals.lua). Mode and pointer keys are bound
--    all the time; everything else is bound ONLY in controller mode, by a
--    secure header, so your keyboard numpad is untouched in desktop mode.
--  * The secure header re-points the 8 slot keys (D-pad + ABXY) whenever the
--    mode or trigger state changes. That runs in restricted code, so it works
--    in combat (verified approach: own protected frames, no frame refs to
--    ordinary UI windows).
--  * Insecure code only does display and mouselook. Mouselook on = camera on
--    the right stick; off when a window needs the pointer.
--  * Menu context (window open, out of combat): the header points D-pad at
--    Nav.lua, A/X/B at secure click buttons, LB/RB at window focus/pages.
--    PLAYER_REGEN_DISABLED forces action context right before combat lockdown.
--
-- Phase 3 slots are placeholders that print which set/slot fired. Phase 5
-- replaces them with real spells.

local WP = WowPad
local KEY = WP.KEY
WP.mode, WP.set, WP.pointer = "desktop", -1, false
WP.setupHooks = {}   -- module secure setup, run out of combat by SetupSecure
WP.overlays = {}     -- our own windows (radial, target menu, info): count as open windows

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WowPad|r: " .. tostring(msg)) end
WP.Print = Print

---------------------------------------------------------------------------
-- What each slot does per set: { kind, target }. kind "B" = binding command,
-- "C" = click a button by name.
---------------------------------------------------------------------------
local function SlotAction(set, i)
  if set == 0 then
    if i == 5 then return "B", "JUMP" end            -- A
    if i == 6 then return "C", "WowPadBackButton" end -- B (no window open): clear target
    if i == 7 then                                    -- X (interact is sent alongside)
      if WowPadDB and WowPadDB.xAttack == false then return "C", "WowPadNoop" end
      return "B", "STARTATTACK"
    end
    if i == 8 then return "C", "WowPadUnitMenu" end   -- Y
  end
  return "C", ("WowPadSlot%d_%d"):format(set, i)
end

-- Bound only in controller mode, independent of set.
local STATIC = {
  { "LT_ON",       "C", "WowPadTrigLOn" },
  { "LT_OFF",      "C", "WowPadTrigLOff" },
  { "RT_ON",       "C", "WowPadTrigROn" },
  { "RT_OFF",      "C", "WowPadTrigROff" },
  { "INTERACT",    "C", "WowPadNoInteract" },   -- replaced by your F binding (RefreshInteract)
  { "L3",          "B", "TOGGLEAUTORUN" },
  { "CAM_ACTIVE",  "C", "WowPadCamActive" },
  { "CAM_IDLE",    "C", "WowPadCamIdle" },
  { "ZOOM_ON",     "C", "WowPadZoomOn" },
  { "ZOOM_OFF",    "C", "WowPadZoomOff" },
  { "LB",          "B", "TARGETNEARESTFRIEND" },
  { "RB",          "B", "TARGETNEARESTENEMY" },
  { "START",       "C", "WowPadStart" },
  { "BACK_TAP",    "B", "TOGGLEWORLDMAP" },
  { "BACK_HOLD",   "B", "OPENALLBAGS" },
}

---------------------------------------------------------------------------
-- Debug output for placeholders
---------------------------------------------------------------------------
function WowPad_Slot(set, i)
  if WowPadDB and WowPadDB.debug then
    Print(("Slot fired: |cffffff00%s|r set, %s%s"):format(WP.SET_NAMES[set] or set, WP.SLOT_LABELS[i] or i,
          InCombatLockdown() and " |cffff5555(combat)|r" or ""))
  end
end

local function InsecureButton(name, fn)
  local b = CreateFrame("Button", name, UIParent)
  b:RegisterForClicks("AnyDown")
  b:SetScript("OnClick", fn)
  return b
end

---------------------------------------------------------------------------
-- Secure setup (must run out of combat)
---------------------------------------------------------------------------
local header
local function SetupSecure()
  if header then return true end
  if InCombatLockdown() then return false end

  -- The slot buttons (WowPadSlot<set>_<i>) are created by ActionBar.lua.
  -- B with nothing open: clear target.
  local back = CreateFrame("Button", "WowPadBackButton", UIParent, "SecureActionButtonTemplate")
  back:RegisterForClicks("AnyDown")
  back:SetAttribute("type", "macro")
  back:SetAttribute("macrotext", "/cleartarget")

  -- Header: rebinds on mode / trigger changes.
  header = CreateFrame("Frame", "WowPadHeader", UIParent, "SecureHandlerAttributeTemplate")
  header:SetAttribute("mode", "desktop")
  header:SetAttribute("lt", 0)
  header:SetAttribute("rt", 0)
  header:SetAttribute("ctx", "action")
  -- Default set with a window open (out of combat): D-pad navigates,
  -- A = click, B = back/close, X = right-click, Y = preview (tap) / compare (hold),
  -- L3 = destroy the selected bag item (asks first).
  -- LB/RB = window focus / page.
  -- Interact is muted so X in a menu doesn't also interact with the world.
  for i, target in ipairs({ "WowPadNavUp", "WowPadNavDown", "WowPadNavLeft", "WowPadNavRight",
                            "WowPadNavA", "WowPadNavB", "WowPadNavX", "WowPadNavCompare" }) do
    header:SetAttribute("m_" .. i, target)
  end
  header:SetAttribute("mb_7", "RightButton")
  header:SetAttribute("klb", KEY.LB)
  header:SetAttribute("krb", KEY.RB)
  header:SetAttribute("kint", KEY.INTERACT)
  header:SetAttribute("kl3", KEY.L3)
  for i, sig in ipairs(WP.SLOT_SIGNALS) do header:SetAttribute("key" .. i, KEY[sig]) end
  for set = 0, 3 do
    for i = 1, 8 do
      local kind, target = SlotAction(set, i)
      header:SetAttribute(("y%d_%d"):format(set, i), kind)
      header:SetAttribute(("t%d_%d"):format(set, i), target)
    end
  end
  header:SetAttribute("nstatic", #STATIC)
  for i, s in ipairs(STATIC) do
    header:SetAttribute("sk" .. i, KEY[s[1]])
    header:SetAttribute("sy" .. i, s[2])
    header:SetAttribute("st" .. i, s[3])
  end
  header:SetAttribute("_onattributechanged", [=[
    if name ~= "lt" and name ~= "rt" and name ~= "mode" and name ~= "ctx" and name ~= "refresh"
       and name ~= "editing" and name ~= "alwaysbar" then return end
    -- Controller bar: always (default), or controller mode only; always while editing.
    local bar = self:GetFrameRef("bar")
    if bar then
      if self:GetAttribute("alwaysbar") == 1 or self:GetAttribute("mode") == "controller"
         or self:GetAttribute("editing") == 1 then bar:Show() else bar:Hide() end
    end
    self:ClearBindings()
    if self:GetAttribute("mode") ~= "controller" then
      self:SetAttribute("set", -1)
      return
    end
    local lt = self:GetAttribute("lt") == 1
    local rt = self:GetAttribute("rt") == 1
    local set = 0
    if lt and rt then set = 3 elseif lt then set = 1 elseif rt then set = 2 end
    for i = 1, self:GetAttribute("nstatic") do
      local key, kind, target = self:GetAttribute("sk" .. i), self:GetAttribute("sy" .. i), self:GetAttribute("st" .. i)
      if kind == "B" then self:SetBinding(true, key, target) else self:SetBindingClick(true, key, target) end
    end
    local menu = set == 0 and self:GetAttribute("ctx") == "menu"
    for i = 1, 8 do
      local key = self:GetAttribute("key" .. i)
      local kind = self:GetAttribute("y" .. set .. "_" .. i)
      local target = self:GetAttribute("t" .. set .. "_" .. i)
      local mb
      if menu and self:GetAttribute("m_" .. i) then
        kind, target, mb = "C", self:GetAttribute("m_" .. i), self:GetAttribute("mb_" .. i)
      end
      if kind == "B" then self:SetBinding(true, key, target)
      elseif mb then self:SetBindingClick(true, key, target, mb)
      else self:SetBindingClick(true, key, target) end
    end
    if menu then
      self:SetBindingClick(true, self:GetAttribute("klb"), "WowPadNavPrev")
      self:SetBindingClick(true, self:GetAttribute("krb"), "WowPadNavNext")
      self:SetBindingClick(true, self:GetAttribute("kint"), "WowPadNoop")
      self:SetBindingClick(true, self:GetAttribute("kl3"), "WowPadNavDestroy") -- L3 = destroy bag item
    end
    self:SetAttribute("set", set)
  ]=])

  -- Small secure buttons that change header state (work in combat).
  local function StateButton(name, attr, valueLua)
    local b = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    b:RegisterForClicks("AnyDown")
    SecureHandlerSetFrameRef(b, "h", header)
    b:SetAttribute("_onclick", ('self:GetFrameRef("h"):SetAttribute("%s", %s)'):format(attr, valueLua))
    return b
  end
  StateButton("WowPadTrigLOn", "lt", "1")
  StateButton("WowPadTrigLOff", "lt", "0")
  StateButton("WowPadTrigROn", "rt", "1")
  StateButton("WowPadTrigROff", "rt", "0")
  local modeC = StateButton("WowPadModeCtrl", "mode", '"controller"')
  local modeD = StateButton("WowPadModeDesk", "mode", '"desktop"')

  -- Mode and pointer signals are always bound.
  SetOverrideBindingClick(modeC, true, KEY.MODE_CONTROLLER, "WowPadModeCtrl")
  SetOverrideBindingClick(modeD, true, KEY.MODE_DESKTOP, "WowPadModeDesk")
  SetOverrideBindingClick(WowPadPointerOn, true, KEY.POINTER_ON, "WowPadPointerOn")
  SetOverrideBindingClick(WowPadPointerOff, true, KEY.POINTER_OFF, "WowPadPointerOff")
  -- Walk on slight stick tilt (optional, DLL decides): the game's own Run/Walk toggle.
  SetOverrideBinding(WowPadPointerOff, true, KEY.WALK_TOGGLE, "TOGGLERUN")

  -- Display follows the header (insecure hook, read-only).
  header:HookScript("OnAttributeChanged", function(_, name, value)
    if name == "mode" then
      WP.mode = value
      if WowPadDB.debug then Print("Mode: |cffffff00" .. tostring(value) .. "|r") end
    elseif name == "set" then
      WP.set = value
      if WP.Bar then WP.Bar.HighlightSet(value) end
    elseif name == "ctx" then
      WP.ctx = value
    end
    WP.UpdateStatus()
  end)
  WP.header = header
  for _, fn in ipairs(WP.setupHooks) do fn() end
  return true
end

---------------------------------------------------------------------------
-- Insecure buttons: pointer mode, placeholders, navigation stubs
---------------------------------------------------------------------------
InsecureButton("WowPadPointerOn",  function() WP.pointer = true;  WP.UpdateStatus() end)
InsecureButton("WowPadPointerOff", function() WP.pointer = false; WP.UpdateStatus() end)
InsecureButton("WowPadNoop", function() end)
InsecureButton("WowPadNoInteract", function()
  Print(("Interact: nothing is bound to |cffffff00%s|r. Bind your interact addon there, or /wp interact <KEY>.")
        :format(WowPadDB.interactKey or "F"))
end)
WP.InsecureButton = InsecureButton

-- Hide "There is nothing to attack." (X = interact + start attack fires it on
-- anything that isn't hostile). Every other error message still shows.
do
  local MUTED = { ["There is nothing to attack."] = true }
  if ERR_NO_ATTACK_TARGET then MUTED[ERR_NO_ATTACK_TARGET] = true end
  local orig = UIErrorsFrame.AddMessage
  UIErrorsFrame.AddMessage = function(self, msg, ...)
    if msg and MUTED[msg] then return end
    return orig(self, msg, ...)
  end
end

-- LB+RB held: hint at the top centre that the right stick zooms.
local zoomHint = CreateFrame("Frame", "WowPadZoomHint", UIParent)
zoomHint:SetSize(360, 30)
zoomHint:SetPoint("TOP", UIParent, "TOP", 0, -60)
zoomHint:SetFrameStrata("HIGH")
zoomHint:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                       edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                       tile = true, tileSize = 16, edgeSize = 12,
                       insets = { left = 3, right = 3, top = 3, bottom = 3 } })
zoomHint:SetBackdropColor(0, 0, 0, 0.8)
local zoomText = zoomHint:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
zoomText:SetPoint("CENTER")
zoomText:SetText("|cffffd100Right stick|r  up / down to zoom the camera")
zoomHint:Hide()
InsecureButton("WowPadZoomOn",  function() zoomHint:Show() end)
InsecureButton("WowPadZoomOff", function() zoomHint:Hide() end)

---------------------------------------------------------------------------
-- Interact: follow whatever is bound to your interact key (default F).
-- Also applies the X-attack setting. Secure attributes: out of combat only.
---------------------------------------------------------------------------
function WP.RefreshInteract() -- re-run after combat via PLAYER_REGEN_ENABLED
  if not header or InCombatLockdown() then return end
  local idx
  for i, st in ipairs(STATIC) do if st[1] == "INTERACT" then idx = i end end
  local cmd = GetBindingAction(WowPadDB.interactKey or "F")
  local kind, target = "C", "WowPadNoInteract"
  if cmd and cmd ~= "" then kind, target = "B", cmd end
  local xKind, xTarget = SlotAction(0, 7)
  local changed = header:GetAttribute("sy" .. idx) ~= kind or header:GetAttribute("st" .. idx) ~= target
                  or header:GetAttribute("y0_7") ~= xKind or header:GetAttribute("t0_7") ~= xTarget
  if not changed then return end
  header:SetAttribute("sy" .. idx, kind)
  header:SetAttribute("st" .. idx, target)
  header:SetAttribute("y0_7", xKind)
  header:SetAttribute("t0_7", xTarget)
  header:SetAttribute("refresh", (header:GetAttribute("refresh") or 0) + 1) -- rebind now
  WP.interactCmd = cmd
end

---------------------------------------------------------------------------
-- Mouselook: on in controller mode unless something needs the pointer
---------------------------------------------------------------------------
-- Other addons put odd things in UISpecialFrames (Questie: an AceGUI widget
-- table, whose real frame is .frame). Returns a real frame or nil.
function WP.AsFrame(x)
  if type(x) ~= "table" then return nil end
  if type(x.GetObjectType) == "function" and type(x.IsShown) == "function" then return x end
  local f = rawget(x, "frame")
  if type(f) == "table" and type(f.GetObjectType) == "function" and type(f.IsShown) == "function" then return f end
  return nil
end

local function AnyWindowOpen()
  if WP.Bar and WP.Bar.editing then return true end
  for _, o in ipairs(WP.overlays) do
    if o:IsShown() then return true end
  end
  for _, side in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
    if GetUIPanel and GetUIPanel(side) then return true end
  end
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = _G["ContainerFrame" .. i]
    if f and f:IsShown() then return true end
  end
  for _, name in ipairs(UISpecialFrames) do
    local f = WP.AsFrame(_G[name])
    if f and f:IsShown() then return true end
  end
  for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
    local f = _G["StaticPopup" .. i]
    if f and f:IsShown() then return true end
  end
  if (LootFrame and LootFrame:IsShown()) or (WorldMapFrame and WorldMapFrame:IsShown())
     or (DropDownList1 and DropDownList1:IsShown()) then return true end
  if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return true end
  if ChatFrameEditBox and ChatFrameEditBox:IsShown() then return true end
  if GetCursorInfo() then return true end -- holding an item/spell
  return false
end
WP.AnyWindowOpen = AnyWindowOpen

local weStarted, mlElapsed = false, 0

-- Crosshair peek: WoW ignores what's under the pointer during camera look, so
-- when the right stick rests (CAM_IDLE from the DLL) camera look pauses and
-- WoW sees the unit under the crosshair. CAM_ACTIVE arrives before the first
-- stick motion and turns camera look straight back on. /wp peek toggles.
WP.peeking = false
local function CameraWanted()
  return WP.mode == "controller" and not WP.pointer and not AnyWindowOpen()
end
-- While peeking the cursor is an invisible image, so WoW's hand/sword icons
-- don't show on the crosshair (tooltips and mouseover still work).
local BLANK_CURSOR = "Interface\\AddOns\\WowPad\\Textures\\blank"
function WP.EndPeek()
  if not WP.peeking then return end
  WP.peeking = false
  ResetCursor()
end
InsecureButton("WowPadCamIdle", function()
  if WowPadDB.peek ~= false and CameraWanted() and IsMouselooking() then
    WP.peeking = true
    MouselookStop()
    SetCursor(BLANK_CURSOR)
  end
end)
InsecureButton("WowPadCamActive", function()
  if WP.peeking then
    WP.EndPeek()
    if CameraWanted() then MouselookStart(); weStarted = true end
  end
end)
WP.BLANK_CURSOR = BLANK_CURSOR
local mlFrame = CreateFrame("Frame")
mlFrame:SetScript("OnUpdate", function(_, elapsed)
  mlElapsed = mlElapsed + elapsed
  if mlElapsed < 0.05 then return end
  mlElapsed = 0
  if WP.peeking and not CameraWanted() then WP.EndPeek() end
  local want = CameraWanted() and not WP.peeking
  local looking = IsMouselooking()
  if want and not looking then
    MouselookStart(); weStarted = true
  elseif not want and looking and weStarted then
    MouselookStop(); weStarted = false
  elseif not looking then
    weStarted = false
  end
  local ctx = looking and "camera" or "pointer"
  if ctx ~= WP.context then WP.context = ctx; WP.UpdateStatus() end

  -- Menu context for the D-pad/A/B. Secure state can only change out of
  -- combat; PLAYER_REGEN_DISABLED forces "action" just before lockdown.
  if header and not InCombatLockdown() then
    local wantCtx = (WP.pointer or AnyWindowOpen()) and "menu" or "action"
    if header:GetAttribute("ctx") ~= wantCtx then header:SetAttribute("ctx", wantCtx) end
  end
end)

---------------------------------------------------------------------------
-- Status display (Phase 3 testing aid; /wp status to hide)
---------------------------------------------------------------------------
local status = CreateFrame("Frame", "WowPadStatus", UIParent)
status:SetSize(420, 22)
status:SetPoint("TOP", 0, -110)
status:SetMovable(true); status:EnableMouse(true); status:RegisterForDrag("LeftButton")
status:SetScript("OnDragStart", status.StartMoving)
status:SetScript("OnDragStop", status.StopMovingOrSizing)
local statusText = status:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("CENTER")

function WP.UpdateStatus()
  if not WowPadDB or not WowPadDB.showStatus then status:Hide(); return end
  status:Show()
  if WP.mode ~= "controller" then
    statusText:SetText("WowPad: |cffaaaaaaDESKTOP|r")
    return
  end
  local set = WP.SET_NAMES[WP.set] or "?"
  local buttons = (WP.ctx == "menu" and WP.set == 0) and "  |cff66ccffmenu buttons|r" or ""
  statusText:SetText(("WowPad: |cff55ff55CONTROLLER|r  set: |cffffff00%s|r  %s%s%s"):format(
    set, WP.context or "?", buttons, WP.pointer and "  |cffff9900pointer mode|r" or ""))
end

---------------------------------------------------------------------------
-- Events & slash
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:SetScript("OnEvent", function(_, event, addon, func)
  if event == "PLAYER_LOGIN" then
    WowPadDB = WowPadDB or {}
    -- Settings version 2: testing-era chat output and status line off by default.
    if (WowPadDB.version or 1) < 2 then
      WowPadDB.debug, WowPadDB.showStatus, WowPadDB.version = false, false, 2
    end
    if WowPadDB.debug == nil then WowPadDB.debug = false end
    if WowPadDB.showStatus == nil then WowPadDB.showStatus = false end
    if WowPadDB.xAttack == nil then WowPadDB.xAttack = true end
    WowPadDB.interactKey = WowPadDB.interactKey or "F"
    if SetupSecure() then WP.RefreshInteract() else Print("Logged in during combat; controller bindings will be set up when combat ends.") end
    WP.UpdateStatus()
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Last chance before combat lockdown: buttons back to Jump/slots, and
    -- close our menus (they hold secure buttons, so they can't be hidden later).
    if header and header:GetAttribute("ctx") ~= "action" then header:SetAttribute("ctx", "action") end
    for _, o in ipairs(WP.overlays) do if o:IsShown() then o:Hide() end end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if SetupSecure() then WP.RefreshInteract(); WP.UpdateStatus() end
  elseif event == "UPDATE_BINDINGS" then
    if WowPadDB then WP.RefreshInteract() end
  elseif addon == "WowPad" then
    Print(("|cffff5555%s|r: %s%s"):format(event, tostring(func), InCombatLockdown() and " (combat)" or ""))
  end
end)

SLASH_WOWPAD1 = "/wp"
SlashCmdList.WOWPAD = function(msg)
  local rest = msg
  msg = (msg or ""):lower():match("^%s*(%S*)")
  if msg == "debug" then
    WowPadDB.debug = not WowPadDB.debug
    Print("Debug messages " .. (WowPadDB.debug and "on" or "off"))
  elseif msg == "xattack" then
    WowPadDB.xAttack = not WowPadDB.xAttack
    WP.RefreshInteract()
    Print("X also starts attack: " .. (WowPadDB.xAttack and "on" or "off")
          .. (InCombatLockdown() and " (applies after combat)" or ""))
  elseif msg == "interact" then
    local key = (select(2, (rest or ""):match("^%s*(%S*)%s*(%S*)")) or ""):upper()
    if key ~= "" then WowPadDB.interactKey = key; WP.RefreshInteract() end
    local cmd = GetBindingAction(WowPadDB.interactKey)
    Print(("Interact follows key |cffffff00%s|r -> %s"):format(WowPadDB.interactKey,
          (cmd and cmd ~= "") and cmd or "|cffff5555nothing bound|r"))
  elseif msg == "bar" then
    if WP.Bar then WP.Bar.ToggleAlways() end
  elseif msg == "crosshair" then
    if WP.ToggleCrosshair then WP.ToggleCrosshair() end
  elseif msg == "peek" then
    WowPadDB.peek = (WowPadDB.peek == false)
    Print("Crosshair peek (tooltips when the right stick rests): " .. (WowPadDB.peek and "on" or "off"))
  elseif msg == "mlprobe" then
    if WP.MouselookProbe then WP.MouselookProbe() end
  elseif msg == "blizz" then
    if WP.ToggleBlizzBars then WP.ToggleBlizzBars() end
  elseif msg == "edit" then
    if WP.ToggleEdit then WP.ToggleEdit() end
  elseif msg == "scale" then
    local v = tonumber(select(2, (rest or ""):match("^%s*(%S*)%s*(%S*)")))
    if v and WP.Bar then WP.Bar.SetScale(v) else Print("Usage: /wp scale 0.8") end
  elseif msg == "navinfo" then
    if WP.Nav and WP.Nav.Info then WP.Nav.Info() end
  elseif msg == "options" or msg == "config" then
    if WP.OpenOptions then WP.OpenOptions() end
  elseif msg == "sens" then
    local v = tonumber(select(2, (rest or ""):match("^%s*(%S*)%s*(%S*)")))
    if v and WP.SetCamSens then WP.SetCamSens(v) else Print("Usage: /wp sens 0.5  (camera, 0.05-2, then /reload)") end
  elseif msg == "status" then
    WowPadDB.showStatus = not WowPadDB.showStatus
    WP.UpdateStatus()
  else
    Print(("mode=%s set=%s context=%s pointer=%s"):format(WP.mode, tostring(WP.set), tostring(WP.context), tostring(WP.pointer)))
    Print("/wp options | sens <0.05-2> | edit | bar | blizz | crosshair | scale <0.4-1.6> | xattack | interact [KEY] | status | debug")
  end
end
