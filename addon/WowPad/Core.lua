-- Core.lua - signal bindings, action-set switching, controller/desktop mode,
-- mouselook, open-window detection, events and the /wp slash command.
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

local WP = WowPad
local KEY = WP.KEY
WP.mode, WP.set, WP.pointer = "desktop", -1, false
WP.setupHooks = {}   -- module secure setup, run out of combat by SetupSecure
WP.overlays = {}     -- our own windows (radial, target menu, info): count as open windows

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WowPad|r: " .. tostring(msg)) end
WP.Print = Print

---------------------------------------------------------------------------
-- What each slot does per set: returns kind, target. kind "B" = binding
-- command, "C" = click a button by name.
---------------------------------------------------------------------------
local function SlotAction(set, i)
  -- The utility ring's button (Options > Bars), on any assignable slot.
  if WowPadDB and tonumber(WowPadDB.wpRingSlot) == set * 10 + i then return "C", "WowPadRingKey" end
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
  -- Bumper held + right stick flick: the friendly bumper cycles your party
  -- (RefreshInteract points these at the party buttons, following the LB/RB swap).
  { "LB_FLICK_DOWN", "C", "WowPadNoop" },
  { "LB_FLICK_UP",   "C", "WowPadNoop" },
  { "RB_FLICK_DOWN", "C", "WowPadNoop" },
  { "RB_FLICK_UP",   "C", "WowPadNoop" },
  -- Utility ring held: which wedge the right stick points at (header attribute "ringdir").
  { "RING_DIR_0",    "C", "WowPadRingDir0" },
  { "RING_DIR_1",    "C", "WowPadRingDir1" },
  { "RING_DIR_2",    "C", "WowPadRingDir2" },
  { "RING_DIR_3",    "C", "WowPadRingDir3" },
  { "RING_DIR_4",    "C", "WowPadRingDir4" },
  { "RING_DIR_5",    "C", "WowPadRingDir5" },
  { "RING_DIR_6",    "C", "WowPadRingDir6" },
  { "RING_DIR_7",    "C", "WowPadRingDir7" },
  { "RING_DIR_8",    "C", "WowPadRingDir8" },
}

-- A plain (insecure) named button that runs fn on key down.
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

  -- Healer mode (hold the ally bumper, flick the right stick): secure
  -- target buttons. The wrapped snippet runs in the game's secure code (works
  -- in combat): it steps you -> party1..4, skipping empty slots, and points the
  -- button at that unit just before it targets.
  local function PartyButton(name, step)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown")
    b:SetAttribute("type", "target")
    b:SetAttribute("unit", "player")
    b:SetAttribute("step", step)
    return b
  end
  WP.partyNext = PartyButton("WowPadPartyNext", 1)
  WP.partyPrev = PartyButton("WowPadPartyPrev", -1)
  -- Healer mode: tapping the ally bumper targets the member you last cycled
  -- to (you at first), instead of the nearest friendly.
  WP.partyCur = PartyButton("WowPadPartyCurrent", 0)

  -- Header: rebinds on mode / trigger changes.
  header = CreateFrame("Frame", "WowPadHeader", UIParent, "SecureHandlerAttributeTemplate")
  header:SetAttribute("mode", "desktop")
  header:SetAttribute("lt", 0)
  header:SetAttribute("rt", 0)
  header:SetAttribute("ctx", "action")
  -- Default set with a window open (out of combat): D-pad navigates,
  -- A = click, B = back/close, X = right-click, Y = preview (tap) / compare (hold),
  -- L3 = item actions for the selected bag item.
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
       and name ~= "editing" and name ~= "alwaysbar" and name ~= "lite" and name ~= "liteview" then return end
    -- Controller bar: always (default), or controller mode only; always while editing.
    local bar = self:GetFrameRef("bar")
    if bar then
      if self:GetAttribute("alwaysbar") == 1 or self:GetAttribute("mode") == "controller"
         or self:GetAttribute("editing") == 1 then bar:Show() else bar:Hide() end
    end
    -- Lite bar: only the set you're holding (else the default set, or the
    -- edit-mode tab) is shown. All four otherwise.
    do
      local lite = self:GetAttribute("lite") == 1
      local l, r = self:GetAttribute("lt") == 1, self:GetAttribute("rt") == 1
      local vs = 0
      if self:GetAttribute("mode") == "controller" then
        if l and r then vs = 3 elseif l then vs = 1 elseif r then vs = 2 end
      end
      if vs == 0 and self:GetAttribute("editing") == 1 then vs = self:GetAttribute("liteview") or 0 end
      for s = 0, 3 do
        local c = self:GetFrameRef("c" .. s)
        if c then if (not lite) or s == vs then c:Show() else c:Hide() end end
      end
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
      self:SetBindingClick(true, self:GetAttribute("kl3"), "WowPadNavDestroy") -- L3 = bag item actions
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
  for _, b in ipairs({ WP.partyNext, WP.partyPrev, WP.partyCur }) do
    SecureHandlerWrapScript(b, "OnClick", header, [=[
      local step = self:GetAttribute("step")
      local i = owner:GetAttribute("pidx") or 0
      if step == 0 then
        if i ~= 0 and not UnitExists("party" .. i) then i = 0 end   -- they left: back to you
      else
        for n = 1, 5 do
          i = (i + step) % 5
          if i == 0 or UnitExists("party" .. i) then break end
        end
      end
      owner:SetAttribute("pidx", i)
      if i == 0 then self:SetAttribute("unit", "player") else self:SetAttribute("unit", "party" .. i) end
    ]=])
  end
  StateButton("WowPadTrigLOn", "lt", "1")
  StateButton("WowPadTrigLOff", "lt", "0")
  StateButton("WowPadTrigROn", "rt", "1")
  StateButton("WowPadTrigROff", "rt", "0")
  local modeC = StateButton("WowPadModeCtrl", "mode", '"controller"')
  local modeD = StateButton("WowPadModeDesk", "mode", '"desktop"')
  for n = 0, 8 do StateButton("WowPadRingDir" .. n, "ringdir", tostring(n)) end

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
    elseif name == "ringdir" then
      if WP.Ring and WP.Ring.Highlight then WP.Ring.Highlight(value) end
      return
    end
    WP.UpdateStatus()
  end)
  WP.header = header
  for _, fn in ipairs(WP.setupHooks) do fn() end
  return true
end

---------------------------------------------------------------------------
-- Insecure buttons: pointer mode, no-op, interact fallback, zoom hint
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
-- Also applies the X-attack setting, the LB/RB swap and healer mode.
-- Secure attributes: out of combat only.
---------------------------------------------------------------------------
function WP.RefreshInteract() -- re-run after combat via PLAYER_REGEN_ENABLED
  if not header or InCombatLockdown() then return end
  local idx
  for i, st in ipairs(STATIC) do if st[1] == "INTERACT" then idx = i end end
  local cmd = GetBindingAction(WowPadDB.interactKey or "F")
  local kind, target = "C", "WowPadNoInteract"
  if cmd and cmd ~= "" then kind, target = "B", cmd end
  local xKind, xTarget = SlotAction(0, 7)
  -- LB/RB targeting, optionally swapped (menus keep LB = previous, RB = next).
  local swap = WowPadDB.swapBumpers == true
  local lbT = swap and "TARGETNEARESTENEMY" or "TARGETNEARESTFRIEND"
  local rbT = swap and "TARGETNEARESTFRIEND" or "TARGETNEARESTENEMY"
  local lbK, rbK = "B", "B"
  -- Healer mode: the ally bumper targets your last-cycled party member.
  local healer = WowPadDB.wpBumperFlick == true   -- off by default
  if healer then
    if swap then rbK, rbT = "C", "WowPadPartyCurrent" else lbK, lbT = "C", "WowPadPartyCurrent" end
  end
  local lbIdx, rbIdx
  local flick = {}
  for i, st in ipairs(STATIC) do
    if st[1] == "LB" then lbIdx = i elseif st[1] == "RB" then rbIdx = i end
    if st[1]:find("_FLICK_") then flick[st[1]] = i end
  end
  -- Healer mode on the ally bumper (LB, or RB when swapped); the other
  -- bumper's flicks do nothing.
  local fr = swap and "RB" or "LB"
  local flickT = {}
  for sig in pairs(flick) do
    local b = sig:sub(1, 2)
    if b == fr then flickT[sig] = sig:find("DOWN") and "WowPadPartyNext" or "WowPadPartyPrev"
    else flickT[sig] = "WowPadNoop" end
  end
  WP.interactCmd = cmd
  local changed = header:GetAttribute("sy" .. idx) ~= kind or header:GetAttribute("st" .. idx) ~= target
                  or header:GetAttribute("y0_7") ~= xKind or header:GetAttribute("t0_7") ~= xTarget
                  or header:GetAttribute("st" .. lbIdx) ~= lbT or header:GetAttribute("st" .. rbIdx) ~= rbT
                  or header:GetAttribute("sy" .. lbIdx) ~= lbK or header:GetAttribute("sy" .. rbIdx) ~= rbK
  for sig, i in pairs(flick) do
    if header:GetAttribute("st" .. i) ~= flickT[sig] then changed = true end
  end
  if not changed then return end
  header:SetAttribute("sy" .. idx, kind)
  header:SetAttribute("st" .. idx, target)
  header:SetAttribute("y0_7", xKind)
  header:SetAttribute("t0_7", xTarget)
  header:SetAttribute("st" .. lbIdx, lbT)
  header:SetAttribute("st" .. rbIdx, rbT)
  header:SetAttribute("sy" .. lbIdx, lbK)
  header:SetAttribute("sy" .. rbIdx, rbK)
  for sig, i in pairs(flick) do header:SetAttribute("st" .. i, flickT[sig]) end
  header:SetAttribute("refresh", (header:GetAttribute("refresh") or 0) + 1) -- rebind now
end

---------------------------------------------------------------------------
-- Open-window detection (drives mouselook and the menu context)
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

-- Pop-ups that should take menu navigation when they appear (out of combat):
-- the dungeon-finder ready dialog and group loot rolls.
function WP.PopupRoots()
  local list = {}
  local d = LFDDungeonReadyDialog
  if d and d:IsVisible() then list[#list + 1] = d end
  for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
    local f = _G["GroupLootFrame" .. i]
    if f and f:IsVisible() then list[#list + 1] = f end
  end
  return list
end

-- Other addons' windows that don't register with the game's panel system
-- (so GetUIPanel/UISpecialFrames don't list them) but should count as open
-- windows. DialogUI: DGossipFrame (its quest frame is a normal UI panel).
-- Immersion: ImmersionFrame (it takes over the gossip and quest windows).
-- OpenMailFrame: the letter opened from the mailbox (a window of its own).
-- Also the Esc menu and its option windows, which aren't always listed either.
WP.EXTRA_WINDOWS = { "DGossipFrame", "DQuestFrame", "ImmersionFrame", "OpenMailFrame", "GameMenuFrame", "VideoOptionsFrame",
                     "AudioOptionsFrame", "InterfaceOptionsFrame", "KeyBindingFrame" }

-- A window some addon keeps "open" but out of sight (New Era cloaks Blizzard's
-- profession window: alpha 0, moved off-screen, still shown). It isn't a
-- window the player can use, so WowPad ignores it.
function WP.Cloaked(f)
  if not (f and f.GetLeft and f.GetEffectiveScale) then return false end
  local a = (f.GetEffectiveAlpha and f:GetEffectiveAlpha()) or (f.GetAlpha and f:GetAlpha()) or 1
  if a < 0.05 then return true end
  local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
  if not l then return false end
  local s = f:GetEffectiveScale()
  local us = UIParent:GetEffectiveScale()
  local W, H = (UIParent:GetWidth() or 0) * us, (UIParent:GetHeight() or 0) * us
  return r * s <= 0 or t * s <= 0 or l * s >= W or b * s >= H
end
local function Open(f) return f and f:IsShown() and not WP.Cloaked(f) end

local function AnyWindowOpen()
  if WP.Bar and WP.Bar.editing then return true end
  for _, name in ipairs(WP.EXTRA_WINDOWS) do
    local f = _G[name]
    if f and f.IsShown and Open(f) then return true end
  end
  -- Out of combat only: in combat these must not take the camera away.
  if not InCombatLockdown() and #WP.PopupRoots() > 0 then return true end
  for _, o in ipairs(WP.overlays) do
    if o:IsShown() then return true end
  end
  for _, side in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
    local p = GetUIPanel and GetUIPanel(side)
    if p and not WP.Cloaked(p) then return true end
  end
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = _G["ContainerFrame" .. i]
    if f and f:IsShown() then return true end
  end
  for _, name in ipairs(UISpecialFrames) do
    local f = WP.AsFrame(_G[name])
    if Open(f) then return true end
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

---------------------------------------------------------------------------
-- Utility ring key: bound to the ring's bar slot. Key down shows the ring;
-- key up copies the chosen wedge's action onto itself and fires it. All in
-- the game's secure code, so it works in combat. Centre = cancel.
---------------------------------------------------------------------------
function WP.SetupRingKey()
  if _G.WowPadRingKey or InCombatLockdown() then return end
  local k = CreateFrame("Button", "WowPadRingKey", UIParent, "SecureActionButtonTemplate")
  k:RegisterForClicks("AnyDown", "AnyUp")
  SecureHandlerWrapScript(k, "OnClick", header, [=[
    local ring = owner:GetFrameRef("ringframe")
    if down then
      owner:SetAttribute("ringdir", 0)
      if ring then ring:Show() end
      return false
    end
    if ring then ring:Hide() end
    local d = owner:GetAttribute("ringdir") or 0
    owner:SetAttribute("ringdir", 0)
    if d == 0 then return false end
    local w = owner:GetFrameRef("rw" .. d)
    if not w then return false end
    self:SetAttribute("type", w:GetAttribute("type"))
    self:SetAttribute("spell", w:GetAttribute("spell"))
    self:SetAttribute("item", w:GetAttribute("item"))
    self:SetAttribute("macro", w:GetAttribute("macro"))
    self:SetAttribute("macrotext", w:GetAttribute("macrotext"))
    if not self:GetAttribute("type") then return false end
  ]=])
end

---------------------------------------------------------------------------
-- Mouselook: on in controller mode unless something needs the pointer.
-- Also crosshair peek and the ground-targeting hint.
---------------------------------------------------------------------------
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
-- Ground-targeted spells (Blizzard, Flare, ...): while one waits for its
-- location, WowPad leaves the game's own cursor alone (the DLL recognises it)
-- and shows a hint; A or the same button places the spell, B cancels. With a
-- window open the addon blanks the cursor instead, so the DLL leaves A alone.
WP.groundTargeting = false
local function PeekCursor() return BLANK_CURSOR end
WP.PeekCursor = PeekCursor
function WP.EndPeek()
  if not WP.peeking then return end
  WP.peeking = false
  -- While aiming, leave the game's cast cursor alone (a reset would flash the
  -- normal pointer, which tells the DLL aiming is over).
  if not (SpellIsTargeting and SpellIsTargeting()) then ResetCursor() end
end
-- Hint under the crosshair while a ground spell waits.
local gtHint = CreateFrame("Frame", "WowPadGroundHint", UIParent)
gtHint:SetSize(10, 10)
gtHint:SetPoint("CENTER", 0, -90)
-- Sits just above the cast bar (wherever your UI put it); if the bar is hidden
-- away by another addon, under the crosshair instead.
local function PlaceHint()
  gtHint:ClearAllPoints()
  local bar = CastingBarFrame
  -- (Not WP.Cloaked: the cast bar fades itself to alpha 0 after every cast.)
  local l, b = bar and bar.GetLeft and bar:GetLeft(), bar and bar.GetBottom and bar:GetBottom()
  local onScreen = l and b and l * bar:GetEffectiveScale() < UIParent:GetWidth() * UIParent:GetEffectiveScale()
                   and b * bar:GetEffectiveScale() < UIParent:GetHeight() * UIParent:GetEffectiveScale()
                   and bar:GetRight() > 0 and bar:GetTop() > 0
  if onScreen then
    gtHint:SetPoint("BOTTOM", bar, "TOP", 0, 12)
  else
    gtHint:SetPoint("CENTER", 0, -90)
  end
end
gtHint:SetFrameStrata("HIGH")
gtHint:Hide()
local gtText = WP.NewKeyLine(gtHint, "GameFontHighlight", 20)   -- icons level with the words
gtText:SetPoint("CENTER")
gtText:SetParts({ { key = "A", text = "or same button: Place" }, { key = "B", text = "Cancel" } }, 14)
-- Called from the mouselook update loop below (every 0.05 s).
local reblank
function WP.GroundTargetTick()
  -- Only in the world (no window open, no pointer mode): in menus the buttons navigate.
  local aiming = SpellIsTargeting and SpellIsTargeting()
  local t = aiming and CameraWanted() and true or false
  -- Aiming with a window open (an enchant scroll from the bags): keep setting
  -- the blank cursor; the DLL reads that as "menu: A still navigates".
  if aiming and not t and WP.mode == "controller" and not WP.pointer then SetCursor(BLANK_CURSOR) end
  if t then
    WP.groundTargeting = true
    if not gtHint:IsShown() then PlaceHint(); gtHint:Show() end
  elseif WP.groundTargeting then
    WP.groundTargeting = false
    gtHint:Hide()
  end
  -- Aiming just ended: show the normal pointer first (that's how the DLL
  -- learns it's over), then blank it again on the next update if peeking.
  if aiming then
    reblank = 1
  elseif reblank == 1 then
    ResetCursor()
    reblank = 2
  elseif reblank == 2 then
    reblank = nil
    if WP.peeking then SetCursor(BLANK_CURSOR) end
  end
end
InsecureButton("WowPadCamIdle", function()
  -- Ground targeting always pauses camera look at rest (even with peek off),
  -- so the game's aiming cursor reaches the DLL; it isn't blanked then.
  local peek = WowPadDB.peek ~= false or (SpellIsTargeting and SpellIsTargeting())
  if peek and CameraWanted() and IsMouselooking() then
    WP.peeking = true
    MouselookStop()
    if not (SpellIsTargeting and SpellIsTargeting()) then SetCursor(BLANK_CURSOR) end
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
  WP.GroundTargetTick()
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
-- Status line (debug / troubleshooting aid; off by default, /wp status
-- toggles). Shows mode, action set, camera/pointer context.
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
  local set = WP.Keys(WP.SET_NAMES[WP.set] or "?")
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
    -- Settings version 2: debug chat output and the status line are off by
    -- default; settings saved before version 2 get them switched off once.
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
    -- ADDON_ACTION_BLOCKED / FORBIDDEN for WowPad: report it (troubleshooting).
    Print(("|cffff5555%s|r: %s%s"):format(event, tostring(func), InCombatLockdown() and " (combat)" or ""))
  end
end)

SLASH_WOWPAD1 = "/wp"
SlashCmdList.WOWPAD = function(msg)
  local rest = msg
  msg = (msg or ""):lower():match("^%s*(%S*)")
  if msg == "debug" then              -- debug aid: extra chat output
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
  elseif msg == "mlprobe" then        -- debug aid: mouselook / mouseover probe
    if WP.MouselookProbe then WP.MouselookProbe() end
  elseif msg == "blizz" then
    if WP.ToggleBlizzBars then WP.ToggleBlizzBars() end
  elseif msg == "edit" then
    if WP.ToggleEdit then WP.ToggleEdit() end
  elseif msg == "scale" then
    local v = tonumber(select(2, (rest or ""):match("^%s*(%S*)%s*(%S*)")))
    if v and WP.Bar then WP.Bar.SetScale(v) else Print("Usage: /wp scale 0.8") end
  elseif msg == "navinfo" then        -- debug aid: menu selection details
    if WP.Nav and WP.Nav.Info then WP.Nav.Info() end
  elseif msg == "firsttime" or msg == "setup" or msg == "welcome" then
    if WP.ShowFirstTime then WP.ShowFirstTime(1) end
  elseif msg == "options" or msg == "config" then
    if WP.OpenOptions then WP.OpenOptions() end
  elseif msg == "sens" then
    local v = tonumber(select(2, (rest or ""):match("^%s*(%S*)%s*(%S*)")))
    if v and WP.SetCamSens then WP.SetCamSens(v) else Print("Usage: /wp sens 0.5  (camera, 0.05-2, then /reload)") end
  elseif msg == "status" then         -- debug aid: status line on / off
    WowPadDB.showStatus = not WowPadDB.showStatus
    WP.UpdateStatus()
  else
    Print(("mode=%s set=%s context=%s pointer=%s"):format(WP.mode, tostring(WP.set), tostring(WP.context), tostring(WP.pointer)))
    Print("/wp firsttime | options | sens <0.05-2> | edit | bar | blizz | crosshair | scale <0.4-1.6> | xattack | interact [KEY] | status | debug")
  end
end
