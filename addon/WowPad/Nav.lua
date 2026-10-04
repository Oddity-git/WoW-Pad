-- Nav.lua - menu navigation with the D-pad (out of combat, window open).
--
--  * "Roots" are open windows: our overlays, dropdowns, popups, loot, Blizzard
--    panels, bags. The highest-priority visible root has focus; LB/RB cycle.
--  * "Nodes" are visible, mouse-enabled, enabled Buttons / CheckButtons /
--    EditBoxes inside the focused root. The D-pad moves to the nearest node in
--    that direction. The pointer (right stick) also selects whatever it hovers.
--  * A / X click the selected node through secure buttons (type "click"), so
--    protected things like using a bag item or selling to a vendor work.
--    B presses the window's own close button the same way.

local WP = WowPad
local Nav = { roots = {}, nodes = {}, nodeSet = {} }
WP.Nav = Nav

local NODE_TYPES = { Button = true, CheckButton = true, EditBox = true }

---------------------------------------------------------------------------
-- Roots
---------------------------------------------------------------------------
local function CollectRoots()
  local roots, seen = {}, {}
  local function add(f)
    if f and not seen[f] and f.IsVisible and f:IsVisible() then seen[f] = true; roots[#roots + 1] = f end
  end
  for _, o in ipairs(WP.overlays) do add(o) end
  for level = (UIDROPDOWNMENU_MAXLEVELS or 2), 1, -1 do add(_G["DropDownList" .. level]) end
  for i = 1, STATICPOPUP_NUMDIALOGS or 4 do add(_G["StaticPopup" .. i]) end
  add(LootFrame)
  if GetUIPanel then
    for _, side in ipairs({ "center", "left", "right", "doublewide", "fullscreen" }) do add(GetUIPanel(side)) end
  end
  add(WorldMapFrame)
  -- All open bags act as one window, represented by the first visible one.
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = _G["ContainerFrame" .. i]
    if f and f:IsVisible() then add(f); break end
  end
  for _, name in ipairs(UISpecialFrames) do
    local f = WP.AsFrame(_G[name])
    local n = f and f:GetName()
    if f and not (n and n:find("^ContainerFrame")) then add(f) end
  end
  return roots
end

---------------------------------------------------------------------------
-- Nodes
---------------------------------------------------------------------------
local function Usable(f)
  local t = f:GetObjectType()
  if not NODE_TYPES[t] or not f:IsMouseEnabled() then return false end
  if t ~= "EditBox" and f.IsEnabled and not f:IsEnabled() then return false end
  local w, h = f:GetWidth(), f:GetHeight()
  return w and h and w >= 6 and h >= 6
end

local function Collect(frame, out, depth)
  if depth > 14 then return end
  local kids = { frame:GetChildren() }
  for _, c in ipairs(kids) do
    if c:IsVisible() then
      if Usable(c) then out[#out + 1] = c end
      Collect(c, out, depth + 1)
    end
  end
end

local function IsBags(root)
  local n = root and root:GetName()
  return n and n:find("^ContainerFrame") ~= nil
end

-- The frames a root stands for (all open bags for the bags root).
local function RootFrames(root)
  if not IsBags(root) then return { root } end
  local list = {}
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = _G["ContainerFrame" .. i]
    if f and f:IsVisible() then list[#list + 1] = f end
  end
  return list
end

local function Center(f)
  local l, b, w, h = f:GetRect()
  if not l then return nil end
  local s = f:GetEffectiveScale()
  return (l + w / 2) * s, (b + h / 2) * s
end

-- Top-left-most node: highest first, then leftmost.
local function DefaultNode(nodes)
  local best, bx, by
  for _, n in ipairs(nodes) do
    local x, y = Center(n)
    if x and (not best or y > by + 4 or (math.abs(y - by) <= 4 and x < bx)) then best, bx, by = n, x, y end
  end
  return best
end

local function Pick(cur, nodes, dx, dy)
  local cx, cy = Center(cur)
  if not cx then return nil end
  local best, bestScore
  for _, n in ipairs(nodes) do
    if n ~= cur then
      local x, y = Center(n)
      if x then
        local vx, vy = x - cx, y - cy
        local primary = vx * dx + vy * dy
        if primary > 2 then
          local secondary = math.abs(vx * dy - vy * dx)
          local score = primary + secondary * 2.5
          if not bestScore or score < bestScore then best, bestScore = n, score end
        end
      end
    end
  end
  return best
end

---------------------------------------------------------------------------
-- Highlight + tooltip
---------------------------------------------------------------------------
local hl = CreateFrame("Frame", "WowPadNavHighlight", UIParent)
hl:SetFrameStrata("TOOLTIP")
hl:Hide()
local function Edge(p1, p2, w, h)
  local t = hl:CreateTexture(nil, "OVERLAY")
  t:SetTexture(1, 0.82, 0.1, 0.95)
  t:SetPoint(p1); t:SetPoint(p2)
  if w then t:SetWidth(w) end
  if h then t:SetHeight(h) end
end
Edge("TOPLEFT", "TOPRIGHT", nil, 2)
Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
Edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)

local function CallScript(f, script)
  local fn = f and f:GetScript(script)
  if fn then pcall(fn, f) end
end

-- The item on the selected button: bag slots directly, anything else (vendor,
-- loot, quest rewards, character...) from the tooltip its OnEnter showed.
-- Is this button part of a bag window? Default bags, the bank, and bag
-- addons (Bagnon, Combuctor, ArkInventory, AdiBags...) by their frame names.
local function InBags(n)
  local f, depth = n, 0
  while f and depth < 8 do
    local name = f.GetName and f:GetName()
    if name then
      local l = name:lower()
      if l:find("container") or l:find("bag") or l:find("inventory") or l:find("^bankframe")
         or l:find("combuctor") then return true end
    end
    f, depth = f.GetParent and f:GetParent(), depth + 1
  end
  return false
end

function Nav.FocusedItem()
  local n = Nav.cur
  if not n then return end
  local link
  if GameTooltip:IsShown() and GameTooltip:IsOwned(n) then
    local _, l = GameTooltip:GetItem()
    link = l
  end
  if not InBags(n) then return link end
  -- bag = the button's GetBag() (Bagnon) or its parent's ID (default bags,
  -- and Bagnon's per-bag holders); slot = the button's ID. Checked against
  -- what's really in that slot.
  local p = n.GetParent and n:GetParent()
  local bag = (type(n.GetBag) == "function" and n:GetBag()) or (p and p.GetID and p:GetID())
  local slot = n.GetID and n:GetID()
  if bag and slot then
    local bl = GetContainerItemLink(bag, slot)
    if bl and (not link or bl == link) then return bl, bag, slot end
  end
  -- Otherwise find the tooltip's item in the bags.
  if link then
    for b = 0, NUM_BAG_SLOTS or 4 do
      for sl = 1, GetContainerNumSlots(b) or 0 do
        if GetContainerItemLink(b, sl) == link then return link, b, sl end
      end
    end
  end
  return link
end

-- /wp navinfo: what the selection is (for bug reports).
function Nav.Info()
  local n = Nav.cur
  local p = n and n.GetParent and n:GetParent()
  local link, bag, slot = Nav.FocusedItem()
  WP.Print(("selected=%s id=%s parent=%s pid=%s link=%s bag=%s slot=%s ctx=%s set=%s"):format(
    tostring(n and n:GetName()), tostring(n and n.GetID and n:GetID()),
    tostring(p and p:GetName()), tostring(p and p.GetID and p:GetID()),
    tostring(link), tostring(bag), tostring(slot), tostring(WP.ctx), tostring(WP.set)))
  local key = WP.KEY and WP.KEY.L3
  if key then WP.Print(("L3 key %s -> %s"):format(key, tostring(GetBindingAction(key, true)))) end
end

-- Left/right click on the world map at WoW's pointer, like the mouse would.
function Nav.MapClick(button)
  local ok, err = pcall(function()
    if button == "RightButton" then
      if WorldMapZoomOutButton_OnClick then WorldMapZoomOutButton_OnClick(WorldMapZoomOutButton)
      elseif ZoomOut then ZoomOut() end
    elseif WorldMapButton_OnClick and WorldMapButton then
      WorldMapButton_OnClick(WorldMapButton, "LeftButton")
    elseif WorldMapButton and ProcessMapClick then
      local x, y = GetCursorPosition()
      local s = WorldMapButton:GetEffectiveScale()
      x, y = x / s, y / s
      local l, b, w, h = WorldMapButton:GetLeft(), WorldMapButton:GetBottom(), WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
      ProcessMapClick((x - l) / w, (b + h - y) / h)
      if WorldMapFrame_Update then WorldMapFrame_Update() end
    end
  end)
  if WowPadDB.debug or not ok then
    WP.Print(("map %s click: %s (continent %s, zone %s)"):format(tostring(button), ok and "ok" or ("error: " .. tostring(err)),
      tostring(GetCurrentMapContinent()), tostring(GetCurrentMapZone())))
  end
end

local function Dressable(link)
  if not link then return false end
  if IsDressableItem then return IsDressableItem(link) and true or false end
  local loc = select(9, GetItemInfo(link))
  return loc ~= nil and loc ~= "" and loc ~= "INVTYPE_BAG" and loc ~= "INVTYPE_QUIVER"
end
Nav.Dressable = Dressable

-- Y tap: preview in the dressing room.
function Nav.Preview()
  local link = Nav.FocusedItem()
  if Dressable(link) then DressUpItemLink(link) end
end

-- L3: destroy the selected bag item, after a confirmation (Cancel is selected).
StaticPopupDialogs.WOWPAD_DESTROY = {
  text = "Destroy %s?",
  button1 = DELETE or "Destroy",
  button2 = CANCEL or "Cancel",
  OnAccept = function(self, d)
    if not d or GetContainerItemLink(d.bag, d.slot) ~= d.link then
      WP.Print("That item moved; nothing was destroyed.")
      return
    end
    ClearCursor()
    PickupContainerItem(d.bag, d.slot)
    if CursorHasItem() then DeleteCursorItem() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}
function Nav.Destroy()
  if InCombatLockdown() then return end
  local link, bag, slot = Nav.FocusedItem()
  if not (link and bag) then return end
  local _, count = GetContainerItemInfo(bag, slot)
  local what = link .. ((count and count > 1) and (" x" .. count) or "")
  StaticPopup_Show("WOWPAD_DESTROY", what, nil, { bag = bag, slot = slot, link = link })
end

-- Item comparison (like holding Shift): shown while Y is held in a menu.
Nav.comparing = false
local function ShowCompare()
  if Nav.comparing and GameTooltip:IsShown() and GameTooltip_ShowCompareItem then
    pcall(GameTooltip_ShowCompareItem, GameTooltip, 1)
  end
end
local function HideCompare()
  for i = 1, 3 do
    local t = _G["ShoppingTooltip" .. i]
    if t then t:Hide() end
  end
end
-- Blizzard's item buttons rebuild their tooltip several times a second while
-- hovered, which dropped our comparison (flicker). Re-add it every time an
-- item lands on the tooltip, in the same frame.
GameTooltip:HookScript("OnTooltipSetItem", function(self)
  if Nav.comparing and GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, self, 1) end
end)

function Nav.Select(node)
  if node == Nav.cur then return end
  if Nav.cur then CallScript(Nav.cur, "OnLeave") end
  Nav.cur = node
  if node then
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", node, "TOPLEFT", -3, 3)
    hl:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", 3, -3)
    hl:Show()
    CallScript(node, "OnEnter")
    ShowCompare()
  else
    hl:Hide()
  end
end

---------------------------------------------------------------------------
-- Focus outline + button hints (which window has focus, what LB/RB does)
---------------------------------------------------------------------------
local focus = CreateFrame("Frame", "WowPadNavFocus", UIParent)
focus:SetFrameStrata("TOOLTIP")
focus:Hide()
local function FocusEdge(p1, p2, w, h)
  local t = focus:CreateTexture(nil, "OVERLAY")
  t:SetTexture(0.35, 0.7, 1, 0.8)
  t:SetPoint(p1); t:SetPoint(p2)
  if w then t:SetWidth(w) end
  if h then t:SetHeight(h) end
end
FocusEdge("TOPLEFT", "TOPRIGHT", nil, 2)
FocusEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
FocusEdge("TOPLEFT", "BOTTOMLEFT", 2, nil)
FocusEdge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)

local hints = CreateFrame("Frame", "WowPadNavHints", UIParent)
hints:SetFrameStrata("TOOLTIP")
hints:SetHeight(24)
hints:SetClampedToScreen(true)
hints:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
hints:SetBackdropColor(0, 0, 0, 0.85)
hints:Hide()
local hintText = hints:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hintText:SetPoint("CENTER")

local FRIENDLY = {
  MerchantFrame = "Vendor", CharacterFrame = "Character", SpellBookFrame = "Spellbook",
  PlayerTalentFrame = "Talents", QuestLogFrame = "Quest Log", WorldMapFrame = "Map",
  FriendsFrame = "Social", GossipFrame = "Gossip", QuestFrame = "Quest", LootFrame = "Loot",
  BankFrame = "Bank", MailFrame = "Mail", TradeFrame = "Trade", AuctionFrame = "Auction House",
  ClassTrainerFrame = "Trainer", TaxiFrame = "Flight Map", GameMenuFrame = "Game Menu",
  DressUpFrame = "Preview", WowPadRadial = "Main Menu", WowPadUnitMenuFrame = "Target Menu", WowPadInfo = "Controller Map",
}
local function WindowName(f)
  local n = f and f:GetName()
  if not n then return "window" end
  if n:find("^ContainerFrame") then return "Bags" end
  if n:find("^StaticPopup") then return "Popup" end
  if n:find("^DropDownList") then return "Menu" end
  return FRIENDLY[n] or (n:gsub("Frame$", ""))
end

local K = "|cffffd100%s|r %s"
function Nav.UpdateHints()
  local root = Nav.root
  if not root then focus:Hide(); hints:Hide(); return end
  if root == WP.Radial then focus:Hide(); hints:Hide(); return end -- wheel has its own hints

  local parts
  if root == WorldMapFrame then
    local onPin = Nav.byDpad and Nav.cur and Nav.cur ~= WorldMapButton
    parts = { K:format("A", onPin and "Select" or "Zoom In"), K:format("X", onPin and "Right-click" or "Zoom Out"),
              K:format("D-pad", "Pins"),
              K:format("B", (GetCurrentMapContinent() or 0) > 0 and "Back" or "Close") }
  elseif root == MerchantFrame then
    -- Vendor: always show what X/Y do, so you know before hovering anything.
    parts = { K:format("A", "Select"), K:format("X", "Buy"), K:format("Y", "Preview, hold: Compare"),
              K:format("B", "Close") }
  elseif InBags(root) then
    -- Bags (default, bank, bag addons): X/Y/L3 always listed.
    local vendorOpen = MerchantFrame and MerchantFrame:IsShown()
    parts = { K:format("A", "Select"), K:format("X", vendorOpen and "Sell" or "Use"),
              K:format("Y", "Preview, hold: Compare"), K:format("L3", "Destroy"), K:format("B", "Close") }
  else
    -- Everything else: only what applies everywhere.
    parts = { K:format("A", "Select"), K:format("B", "Close") }
  end
  if #Nav.roots > 1 then
    local idx = 1
    for i, r in ipairs(Nav.roots) do if r == root then idx = i end end
    parts[#parts + 1] = K:format("LB/RB", "Switch to " .. WindowName(Nav.roots[idx % #Nav.roots + 1]))
  end
  hintText:SetText(table.concat(parts, "     "))
  hints:SetWidth(hintText:GetStringWidth() + 24)

  -- Bounding box of the focused window (all bags together), in UIParent units.
  local uiScale = UIParent:GetEffectiveScale()
  local L, B, R, T
  for _, f in ipairs(RootFrames(root)) do
    local l, b, w, h = f:GetRect()
    if l then
      -- Blizzard panels are bigger than their artwork; trim the transparent
      -- padding they declare as hit-rect insets.
      local il, ir, it, ib = 0, 0, 0, 0
      if f.GetHitRectInsets then il, ir, it, ib = f:GetHitRectInsets() end
      l, b, w, h = l + il, b + ib, w - il - ir, h - it - ib
      local k = f:GetEffectiveScale() / uiScale
      l, b, w, h = l * k, b * k, w * k, h * k
      L = L and math.min(L, l) or l
      B = B and math.min(B, b) or b
      R = R and math.max(R, l + w) or l + w
      T = T and math.max(T, b + h) or b + h
    end
  end
  if not L then focus:Hide(); hints:Hide(); return end

  hints:ClearAllPoints()
  hints:SetPoint("TOP", UIParent, "BOTTOMLEFT", (L + R) / 2, B - 4)
  hints:Show()

  if #Nav.roots > 1 then
    focus:ClearAllPoints()
    focus:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", L - 2, T + 2)
    focus:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", R + 2, B - 2)
    focus:Show()
  else
    focus:Hide()
  end
end

---------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------
local elapsedAcc, lastTop, lastMX, lastMY = 0, nil, 0, 0

local function Active()
  return WP.mode == "controller" and WP.ctx == "menu" and WP.set == 0 and not InCombatLockdown()
end

function Nav.Refresh()
  Nav.roots = CollectRoots()
  local top = Nav.roots[1]
  local stillOpen = false
  for _, r in ipairs(Nav.roots) do if r == Nav.root then stillOpen = true end end
  if top ~= lastTop or not stillOpen then
    Nav.root = top                       -- new window on top grabs focus
    -- Start on the window's default button (as before the map cursor), not
    -- wherever the hidden pointer happens to be (the crosshair spot).
    Nav.byDpad = true
    Nav.Select(nil)
    lastMX, lastMY = GetCursorPosition()
  end
  lastTop = top

  local nodes = {}
  if Nav.root then
    for _, f in ipairs(RootFrames(Nav.root)) do Collect(f, nodes, 0) end
  end
  Nav.nodes, Nav.nodeSet = nodes, {}
  for _, n in ipairs(nodes) do Nav.nodeSet[n] = true end

  -- Follow the pointer when it moves onto a node.
  local mx, my = GetCursorPosition()
  -- (Not on the radial: it selects by stick direction instead.)
  if Nav.root ~= WP.Radial and math.abs(mx - lastMX) + math.abs(my - lastMY) > 2 then
    Nav.byDpad = false   -- the stick moved the pointer: the map cursor follows it again
    local mf = GetMouseFocus()
    if mf and Nav.nodeSet[mf] then Nav.Select(mf) end
  end
  lastMX, lastMY = mx, my

  if not Nav.cur or not Nav.nodeSet[Nav.cur] then
    local pref
    if Nav.root and Nav.root.which == "WOWPAD_DESTROY" then pref = _G[Nav.root:GetName() .. "Button2"] end
    Nav.Select((pref and Nav.nodeSet[pref]) and pref or DefaultNode(nodes))
  end
  Nav.UpdateHints()
end

local nf = CreateFrame("Frame")
nf:SetScript("OnUpdate", function(_, elapsed)
  elapsedAcc = elapsedAcc + elapsed
  if elapsedAcc < 0.1 then return end
  elapsedAcc = 0
  if Active() then
    Nav.Refresh()
  elseif Nav.cur or hl:IsShown() or hints:IsShown() then
    Nav.Select(nil)
    Nav.root, lastTop = nil, nil
    Nav.UpdateHints()
  end
end)

function Nav.Move(dx, dy)
  if not Active() then return end
  Nav.Refresh()
  local nxt = Nav.cur and Pick(Nav.cur, Nav.nodes, dx, dy)
  if nxt then Nav.Select(nxt); Nav.byDpad = true end
end

function Nav.CycleRoot(step)
  if #Nav.roots < 2 then return end
  local idx = 1
  for i, r in ipairs(Nav.roots) do if r == Nav.root then idx = i end end
  idx = (idx - 1 + step) % #Nav.roots + 1
  Nav.root = Nav.roots[idx]
  Nav.Select(nil)
  Nav.Refresh()
end

-- What B should press. Closes our own windows / dropdowns directly.
function Nav.BackTarget()
  for _, o in ipairs(WP.overlays) do
    if o:IsShown() then o:Hide(); return nil end
  end
  if DropDownList1 and DropDownList1:IsShown() then CloseDropDownMenus(); return nil end
  local root = Nav.root
  local name = root and root:GetName()
  -- World map: B backs out a level (zone > continent > world), then closes.
  if root and root == WorldMapFrame then
    local z = WorldMapZoomOutButton
    if z and z:IsVisible() and z:IsEnabled() and (GetCurrentMapContinent() or 0) > 0 then return z end
  end
  if name then
    if name:find("^StaticPopup%d") then
      local b2 = _G[name .. "Button2"]
      if b2 and b2:IsVisible() then return b2 end
      local b1 = _G[name .. "Button1"]
      if b1 and b1:IsVisible() then return b1 end
    end
    local close = _G[name .. "CloseButton"]
    if not (close and close:IsVisible()) then
      close = nil
      for _, c in ipairs({ root:GetChildren() }) do
        local n = c:GetName()
        if n and n:find("CloseButton$") and c:IsVisible() then close = c; break end
      end
    end
    if close then return close end
  end
  if name and name:find("^ContainerFrame") then CloseAllBags() end
  return nil
end

---------------------------------------------------------------------------
-- Buttons the header binds in menu context
---------------------------------------------------------------------------
local IB = WP.InsecureButton
IB("WowPadNavUp",    function() Nav.Move(0, 1) end)
IB("WowPadNavDown",  function() Nav.Move(0, -1) end)
IB("WowPadNavLeft",  function() Nav.Move(-1, 0) end)
IB("WowPadNavRight", function() Nav.Move(1, 0) end)
do
  local cmp = CreateFrame("Button", "WowPadNavCompare", UIParent)
  cmp:RegisterForClicks("AnyDown", "AnyUp")   -- key down = start, key up = stop
  -- Y: tap = preview (dressing room), hold = compare (starts after a moment).
  local HOLD = 0.25
  local heldFor
  cmp:SetScript("OnUpdate", function(self, e)
    if not heldFor then return end
    heldFor = heldFor + e
    if heldFor >= HOLD and not Nav.comparing then
      Nav.comparing = true
      if Nav.cur then CallScript(Nav.cur, "OnEnter") end -- rebuild tooltip, then compare
      ShowCompare()
    end
  end)
  cmp:SetScript("OnClick", function(_, _, down)
    if down ~= false then
      heldFor = 0
    else
      local wasCompare = Nav.comparing
      heldFor = nil
      Nav.comparing = false
      HideCompare()
      if not wasCompare and Active() then Nav.Preview() end
    end
  end)
end
IB("WowPadNavDestroy", function()
  if WowPadDB.debug then WP.Print("L3 in menu: destroy") end
  if Active() then Nav.Destroy() end
end)
IB("WowPadNavPrev",  function() if WP.Radial and WP.Radial:IsShown() then WP.Radial.Page(-1) else Nav.CycleRoot(-1) end end)
IB("WowPadNavNext",  function() if WP.Radial and WP.Radial:IsShown() then WP.Radial.Page(1) else Nav.CycleRoot(1) end end)

table.insert(WP.setupHooks, function()
  -- A / X: secure click on the selected node (left / right button).
  local function Clicker(name)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown")
    b:SetAttribute("type", "click")
    b:SetScript("PreClick", function(self, button)
      if InCombatLockdown() then return end
      local n = Nav.cur
      -- World map: A/X act on the map itself at the cursor (left = zoom in,
      -- right = zoom out), unless the D-pad put the cursor on a pin/button.
      -- Done here directly (the map isn't protected), not via a click.
      if Nav.root == WorldMapFrame and not (Nav.byDpad and n and n ~= WorldMapButton) then
        Nav.MapClick(button)
        self:SetAttribute("clickbutton", nil)
        return
      end
      if n and n:GetObjectType() == "EditBox" then
        n:SetFocus()
        n = nil
      end
      self:SetAttribute("clickbutton", n)
    end)
    return b
  end
  Clicker("WowPadNavA")
  Clicker("WowPadNavX")

  -- B: secure click on the window's close / cancel button.
  local back = CreateFrame("Button", "WowPadNavB", UIParent, "SecureActionButtonTemplate")
  back:RegisterForClicks("AnyDown")
  back:SetAttribute("type", "click")
  back:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    self:SetAttribute("clickbutton", Nav.BackTarget())
  end)
end)
