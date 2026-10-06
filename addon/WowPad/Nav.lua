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
--  * Y: tap = preview, hold = compare. L3 in bags: item actions. LB/RB:
--    switch window, or page the main menu / setup window / keyboard.

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
    if f and not seen[f] and f.IsVisible and f:IsVisible() and not WP.Cloaked(f) then
      seen[f] = true; roots[#roots + 1] = f
    end
  end
  for _, o in ipairs(WP.overlays) do add(o) end
  for level = (UIDROPDOWNMENU_MAXLEVELS or 2), 1, -1 do add(_G["DropDownList" .. level]) end
  for i = 1, STATICPOPUP_NUMDIALOGS or 4 do add(_G["StaticPopup" .. i]) end
  for _, f in ipairs(WP.PopupRoots()) do add(f) end   -- dungeon ready, loot rolls
  add(LootFrame)
  for _, name in ipairs(WP.EXTRA_WINDOWS) do add(_G[name]) end
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

-- Child button of a root by global name, else by its label text (in case a
-- client names it differently).
local function FindButton(root, suffix, text)
  local b = _G[(root:GetName() or "") .. suffix]
  if b then return b end
  if not text then return nil end
  for _, c in ipairs({ root:GetChildren() }) do
    if c.GetText and c:GetText() == text then return c end
  end
end

---------------------------------------------------------------------------
-- Nodes
---------------------------------------------------------------------------
-- Auction house rows (Browse / Bid / Auctions tabs): only the item icon is a
-- stop; clicking it selects its row, and the whole-row buttons would double
-- every step of the D-pad.
local function AuctionRow(f)
  local n = f:GetName()
  if not n then return false end
  for _, p in ipairs({ "^BrowseButton%d+$", "^BidButton%d+$", "^AuctionsButton%d+$" }) do
    if n:find(p) then return _G[n .. "Item"] ~= nil end
  end
  return false
end

-- Never stops: money displays (their gold / silver / copper buttons only pick
-- up coins) and the auction house's bid amount boxes (filled in for you when
-- you pick a listing).
local function Skipped(f)
  local n = f:GetName()
  if not n then return false end
  return n:find("MoneyFrameGoldButton$") or n:find("MoneyFrameSilverButton$")
      or n:find("MoneyFrameCopperButton$") or n:find("^BrowseBidPrice") ~= nil
end

local function Usable(f)
  local t = f:GetObjectType()
  if not NODE_TYPES[t] or not f:IsMouseEnabled() then return false end
  if AuctionRow(f) or Skipped(f) then return false end
  if t ~= "EditBox" and f.IsEnabled and not f:IsEnabled() then return false end
  local w, h = f:GetWidth(), f:GetHeight()
  return w and h and w >= 6 and h >= 6
end

-- Screen rect of a frame (left, bottom, right, top) in screen pixels.
local function Rect(f)
  local l, b, w, h = f:GetRect()
  if not l then return nil end
  local s = f:GetEffectiveScale()
  return l * s, b * s, (l + w) * s, (b + h) * s
end

local function CenterIn(n, sf)
  local l, b, w, h = n:GetRect()
  local L, B, R, T = Rect(sf)
  if not l or not L then return false end
  local s = n:GetEffectiveScale()
  local x, y = (l + w / 2) * s, (b + h / 2) * s
  return x >= L - 2 and x <= R + 2 and y >= B - 2 and y <= T + 2
end

-- Nodes, plus the visible scroll frames (lists) found on the way. Nodes
-- inside a real scroll frame that are scrolled out of view are skipped.
local function Collect(frame, out, depth, scrolls, clip)
  if depth > 14 then return end
  local kids = { frame:GetChildren() }
  for _, c in ipairs(kids) do
    if c:IsVisible() then
      if Usable(c) and not (clip and not CenterIn(c, clip)) then out[#out + 1] = c end
      local isScroll = c.GetObjectType and c:GetObjectType() == "ScrollFrame"
      if isScroll and scrolls then scrolls[#scrolls + 1] = c end
      -- A scroll bar sits beside its list: keep its arrow buttons selectable.
      local isBar = c.GetObjectType and c:GetObjectType() == "Slider"
      Collect(c, out, depth + 1, scrolls, isScroll and c or (not isBar and clip) or nil)
    end
  end
end

local function IsBags(root)
  local n = root and root:GetName()
  return n and n:find("^ContainerFrame") ~= nil
end

-- Side panels other addons keep as separate frames next to a window (so they
-- aren't its children): navigated as part of that window. New Era's
-- profession tabs sit beside both its profession windows.
local ATTACHED = {
  NE_ProfessionsBookFrame     = { "NE_ProfessionsTabs" },
  NE_ProfessionsCraftingFrame = { "NE_ProfessionsTabs" },
}

-- The frames a root stands for (all open bags for the bags root).
-- Immersion's main frame has no size of its own: its talk box and option list
-- are what you see (used for the selection box and the hint bar).
local function ImmersionParts(root)
  local list = { root.TalkBox }
  local t = root.TitleButtons
  if t and t:IsVisible() and (t.GetNumActive and t:GetNumActive() or 0) > 0 then list[#list + 1] = t end
  return list
end

local function RootFrames(root)
  local extra = ATTACHED[root:GetName() or ""]
  if extra then
    local list = { root }
    for _, n in ipairs(extra) do
      local f = _G[n]
      if f and f:IsVisible() then list[#list + 1] = f end
    end
    return list
  end
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

-- Nearest node from cur in direction (dx, dy), favouring nodes straight ahead.
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
-- Selection box and window outline: the game's tooltip border (rounded
-- corners), tinted gold / blue.
local ROUNDED = "Interface\\Tooltips\\UI-Tooltip-Border"
local hl = CreateFrame("Frame", "WowPadNavHighlight", UIParent)
hl:SetFrameStrata("FULLSCREEN_DIALOG")
hl:SetBackdrop({ edgeFile = ROUNDED, edgeSize = 16 })
hl:SetBackdropBorderColor(1, 0.82, 0.1, 1)
hl:Hide()

local function CallScript(f, script)
  local fn = f and f:GetScript(script)
  if fn then pcall(fn, f) end
end

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

-- The item on the selected button: bag slots directly, anything else (vendor,
-- loot, quest rewards, character...) from the tooltip its OnEnter showed.
-- Returns link, and bag, slot when the item is in your bags.
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

-- /wp navinfo (debug / troubleshooting aid): what the selection is, for bug reports.
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

-- Destroy the selected bag item, after a confirmation (Cancel is preselected).
-- Used by the L3 item-actions window (or directly by L3 if that isn't loaded).
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
function Nav.Destroy(link, bag, slot)
  if InCombatLockdown() then return end
  if not link then link, bag, slot = Nav.FocusedItem() end
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

-- Selection memory while a window stays open: per window, the last selected
-- node and where it was (so a vanished node, e.g. a sold item, is replaced by
-- its nearest neighbour instead of jumping back to the top-left).
Nav.memory = {}
function Nav.Select(node)
  if node == Nav.cur then return end
  if Nav.cur then CallScript(Nav.cur, "OnLeave") end
  Nav.cur = node
  if node and Nav.root then
    local x, y = Center(node)
    Nav.memory[Nav.root] = { node = node, x = x, y = y }
  end
  if node then
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", node, "TOPLEFT", -6, 6)
    hl:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", 6, -6)
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
focus:SetFrameStrata("FULLSCREEN_DIALOG")
focus:SetBackdrop({ edgeFile = ROUNDED, edgeSize = 20 })
focus:SetBackdropBorderColor(0.35, 0.7, 1, 0.7)
focus:Hide()

local hints = CreateFrame("Frame", "WowPadNavHints", UIParent)
hints:SetFrameStrata("FULLSCREEN_DIALOG")
hints:SetHeight(28)
hints:SetClampedToScreen(true)
hints:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
hints:SetBackdropColor(0, 0, 0, 0.85)
hints:Hide()
-- The hint line is laid out piece by piece (WP.NewKeyLine, Glyphs.lua) so
-- icons and words line up in every window. hintText keeps the whole line as
-- text (hidden; read by the tests and /wp navinfo).
local hintText = hints:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hintText:Hide()
local HINT_PAD, HINT_GAP = 10, 4   -- gap between hints: about one space
local hintLine = WP.NewKeyLine(hints, "GameFontHighlightSmall", 18)
hintLine:SetPoint("LEFT", hints, "LEFT", HINT_PAD, 0)
local function LayoutHints(parts)
  hints:SetWidth(hintLine:SetParts(parts, HINT_GAP) + 2 * HINT_PAD)
end

local FRIENDLY = {
  MerchantFrame = "Vendor", CharacterFrame = "Character", SpellBookFrame = "Spellbook",
  PlayerTalentFrame = "Talents", QuestLogFrame = "Quest Log", WorldMapFrame = "Map",
  FriendsFrame = "Social", GossipFrame = "Gossip", QuestFrame = "Quest", LootFrame = "Loot",
  BankFrame = "Bank", MailFrame = "Mail", TradeFrame = "Trade", AuctionFrame = "Auction House",
  ClassTrainerFrame = "Trainer", TaxiFrame = "Flight Map", GameMenuFrame = "Game Menu",
  DressUpFrame = "Preview", WowPadRadial = "Main Menu", WowPadUnitMenuFrame = "Target Menu",
  WowPadInfo = "Controller Map", WowPadItemActions = "Item", WowPadFirstTime = "Setup",
  WowPadKeyboard = "Keyboard", DGossipFrame = "Gossip", DQuestFrame = "Quest", ImmersionFrame = "Dialog", OpenMailFrame = "Letter",
}
local function WindowName(f)
  local n = f and f:GetName()
  if not n then return "window" end
  if n:find("^ContainerFrame") then return "Bags" end
  if n:find("^Bagnon") then return n:lower():find("bank") and "Bank" or "Bags" end
  if n:find("^StaticPopup") then return "Popup" end
  if n:find("^GroupLootFrame") then return "Loot Roll" end
  if n == "LFDDungeonReadyDialog" then return "Dungeon" end
  if n:find("^DropDownList") then return "Menu" end
  return FRIENDLY[n] or (n:gsub("Frame$", ""))
end

local K = "|cffffd100%s|r %s"
-- One hint: the button(s) in the chosen style (icons / names), then what it does.
local function H(key, text) return { key = key, text = text } end
function Nav.UpdateHints()
  local root = Nav.root
  if not root then focus:Hide(); hints:Hide(); return end
  if root == WP.Radial then focus:Hide(); hints:Hide(); return end -- wheel has its own hints

  local parts
  if root == WorldMapFrame then
    local onPin = Nav.byDpad and Nav.cur and Nav.cur ~= WorldMapButton
    parts = { H("A", onPin and "Select" or "Zoom In"), H("X", onPin and "Right-click" or "Zoom Out"),
              H("D-pad", "Pins"),
              H("B", (GetCurrentMapContinent() or 0) > 0 and "Back" or "Close") }
  elseif root == MerchantFrame then
    -- Vendor: always show what X/Y do, so you know before hovering anything.
    parts = { H("A", "Select"), H("X", "Buy"), H("Y", "Preview, hold: Compare"),
              H("B", "Close") }
  elseif InBags(root) then
    -- Bags (default, bank, bag addons): X/Y/L3 always listed.
    local vendorOpen = MerchantFrame and MerchantFrame:IsShown()
    parts = { H("A", "Select"), H("X", vendorOpen and "Sell" or "Use"),
              H("Y", "Preview, hold: Compare"), H("L3", "Item actions"), H("B", "Close") }
  elseif root == WP.Keyboard then
    if WP.Keyboard.IsField() then
      parts = { H("A", "Type"), H("X", "Capital"), H("Y", "Space"),
                H("B", "Delete (empty: close)"), H("Start", "Done") }
    else
      parts = { H("A", "Type"), H("X", "Capital"), H("Y", "Space"), H("B", "Delete"),
                H("LB/RB", "Channel"), H("Start", "Send") }
    end
  elseif root == LFDDungeonReadyDialog then
    parts = { H("A", "Select"), H("B", "Leave Queue") }
  elseif (root:GetName() or ""):find("^GroupLootFrame%d") then
    parts = { H("A", "Roll"), H("Y", "Preview, hold: Compare"), H("B", "Pass") }
  elseif root:GetName() == "ImmersionFrame" then
    if Nav.cur and Nav.cur == root.TalkBox then
      parts = { H("A", "Continue / Accept"), H("X", "Skip / repeat text"), H("B", "Close") }
    else
      parts = { H("A", "Select"), H("B", "Close") }
    end
  elseif root == QuestLogFrame then
    parts = { H("A", "Select"), H("X", "Track / untrack"), H("B", "Close") }
  else
    -- Everything else: only what applies everywhere.
    parts = { H("A", "Select"), H("B", "Close") }
  end
  if #Nav.roots > 1 then
    local idx = 1
    for i, r in ipairs(Nav.roots) do if r == root then idx = i end end
    parts[#parts + 1] = H("LB/RB", "Swap window")
  end
  local flat = {}
  for i, p in ipairs(parts) do flat[i] = K:format(WP.Keys(p.key), p.text) end
  LayoutHints(parts)
  hintText:SetText(table.concat(flat, "     "))

  -- Bounding box of the focused window (all bags together), in UIParent units.
  local uiScale = UIParent:GetEffectiveScale()
  local L, B, R, T
  local parts = (root:GetName() == "ImmersionFrame" and root.TalkBox) and ImmersionParts(root) or RootFrames(root)
  for _, f in ipairs(parts) do
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
    focus:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", L - 6, T + 6)
    focus:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", R + 6, B - 6)
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

-- Some addon windows (DialogUI) keep invisible, clickable buttons around
-- (unused option slots, helper buttons). In those windows, only buttons that
-- show something (text or a visible picture) count as stops.
local SHOWS_ONLY = { DGossipFrame = true, DQuestFrame = true }
local function ShowsSomething(b)
  if b.GetText then
    local t = b:GetText()
    if t and t ~= "" then return true end
  end
  if b:GetObjectType() == "EditBox" then return true end
  for _, r in ipairs({ b:GetRegions() }) do
    if r:IsShown() and (r.GetAlpha == nil or r:GetAlpha() > 0.05) then
      local layer = r.GetDrawLayer and r:GetDrawLayer()
      if layer ~= "HIGHLIGHT" then
        if r:GetObjectType() == "Texture" and r:GetTexture() then return true end
        if r:GetObjectType() == "FontString" and (r:GetText() or "") ~= "" then return true end
      end
    end
  end
  return false
end

-- DialogUI's quest frame grabs the keyboard for its own shortcuts (Space,
-- 1-9), which swallows the pad's keys. In controller mode, let them through.
local function ReleaseKeyboardGrabs()
  if WP.mode ~= "controller" then return end
  local q = _G.DQuestFrame
  if q and q:IsShown() and q.IsKeyboardEnabled and q:IsKeyboardEnabled() then q:EnableKeyboard(false) end
end

function Nav.Refresh()
  ReleaseKeyboardGrabs()
  Nav.roots = CollectRoots()
  local open = {}
  for _, r in ipairs(Nav.roots) do open[r] = true end
  for r in pairs(Nav.memory) do if not open[r] then Nav.memory[r] = nil end end
  local top = Nav.roots[1]
  local stillOpen = false
  for _, r in ipairs(Nav.roots) do if r == Nav.root then stillOpen = true end end
  if top ~= lastTop or not stillOpen then
    Nav.root = top                       -- new window on top grabs focus
    -- Start on the window's default button, not wherever the hidden pointer
    -- happens to be (the crosshair spot).
    Nav.byDpad = true
    Nav.Select(nil)
    lastMX, lastMY = GetCursorPosition()
  end
  lastTop = top

  local nodes, scrolls = {}, {}
  if Nav.root then
    for _, f in ipairs(RootFrames(Nav.root)) do Collect(f, nodes, 0, scrolls) end
    if SHOWS_ONLY[Nav.root:GetName() or ""] then
      local kept = {}
      for _, n in ipairs(nodes) do if ShowsSomething(n) then kept[#kept + 1] = n end end
      nodes = kept
    end
  end
  Nav.nodes, Nav.nodeSet, Nav.scrolls = nodes, {}, scrolls
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
    -- Back to where this window was: the same node, else the nearest one.
    local mem = Nav.root and Nav.memory[Nav.root]
    if mem then
      local pick = Nav.nodeSet[mem.node] and mem.node
      if not pick and mem.x then
        local bd
        for _, n in ipairs(nodes) do
          local x, y = Center(n)
          if x then
            local d = (x - mem.x) ^ 2 + (y - mem.y) ^ 2
            if not bd or d < bd then pick, bd = n, d end
          end
        end
      end
      if pick then Nav.Select(pick); Nav.UpdateHints(); return end
    end
    local pref
    local rn = Nav.root and Nav.root:GetName()
    if Nav.root and Nav.root.which == "WOWPAD_DESTROY" then pref = { _G[rn .. "Button2"] }
    elseif rn == "WowPadItemActions" then pref = { WowPadItemActionsCancel }
    elseif rn == "WowPadFirstTime" then pref = { WowPadFirstTimeNext }
    elseif rn == "WowPadKeyboard" then pref = { WP.Keyboard.firstKey }
    elseif rn == "DGossipFrame" then pref = { _G.DGossipTitleButton1 }
    elseif rn == "OpenMailFrame" then    -- the attachment, else the money, else Reply
      pref = { _G.OpenMailAttachmentButton1, _G.OpenMailMoneyButton, _G.OpenMailLetterButton, _G.OpenMailReplyButton }
    elseif rn == "ImmersionFrame" then   -- first option, else the talk box (continue / accept)
      local t = Nav.root.TitleButtons
      pref = { t and t.Buttons and t.Buttons[1], Nav.root.TalkBox }
    elseif rn == "DQuestFrame" then
      pref = { _G.DQuestFrameAcceptButton, _G.DQuestFrameCompleteButton, _G.DQuestFrameCompleteQuestButton }
    elseif rn == "LFDDungeonReadyDialog" then pref = { FindButton(Nav.root, "EnterDungeonButton", ENTER_DUNGEON) }
    elseif rn and rn:find("^GroupLootFrame%d") then
      -- Need if allowed, else Greed (disabled buttons aren't nodes).
      pref = { _G[rn .. "RollButton"], _G[rn .. "GreedButton"], _G[rn .. "DisenchantButton"] }
    end
    local pick
    for _, p in ipairs(pref or {}) do
      if p and Nav.nodeSet[p] then pick = p; break end
    end
    Nav.Select(pick or DefaultNode(nodes))
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
    -- Paused (trigger held, combat...): keep memory of windows still open.
    for r in pairs(Nav.memory) do if not r:IsVisible() then Nav.memory[r] = nil end end
    Nav.Select(nil)
    Nav.root, lastTop = nil, nil
    Nav.UpdateHints()
  end
end)

-- The scroll bar of a list (Blizzard names it <scrollframe>ScrollBar).
local function ScrollBarOf(sf)
  local n = sf:GetName()
  local bar = (n and _G[n .. "ScrollBar"]) or sf.ScrollBar
  if not bar then
    for _, c in ipairs({ sf:GetChildren() }) do
      if c.GetObjectType and c:GetObjectType() == "Slider" then bar = c; break end
    end
  end
  if bar and bar:IsVisible() and bar.GetValue then return bar end
end

-- D-pad up/down at the edge of a list: scroll the list one row instead of
-- leaving it (auction house, professions, quest log...). Returns true if it did.
-- The list the selected row belongs to, as (scroll bar, inList(node)):
--  1. a scroll frame the row sits inside (most lists), or
--  2. Blizzard's "faux" lists (auction house): the rows sit beside their scroll
--     frame, so take the nearest scroll bar to the row's right, at its height.
-- Only when the D-pad would otherwise leave the list (nxt isn't in it).
local function ListOf(cur, nxt)
  for _, sf in ipairs(Nav.scrolls) do
    if CenterIn(cur, sf) and not (nxt and CenterIn(nxt, sf)) then
      local bar = ScrollBarOf(sf)
      if bar then return bar, function(n) return CenterIn(n, sf) end end
    end
  end
  local x, y = Center(cur)
  if not x then return nil end
  -- The row's right end (an auction icon: its whole row) must sit right next
  -- to the bar, so a list without a scroll bar of its own (the auction
  -- categories) never scrolls the list beside it.
  local row = cur.GetParent and cur:GetParent()
  local _, _, rowRight = Rect((row and AuctionRow(row)) and row or cur)
  if not rowRight then return nil end
  local best, bestD, bestRect
  for _, sf in ipairs(Nav.scrolls) do
    local bar = ScrollBarOf(sf)
    local L, B, R, T
    if bar then L, B, R, T = Rect(bar) end
    if L and y >= B - 2 and y <= T + 2 and L >= x and L - rowRight <= 40
       and (not bestD or L - x < bestD) then
      best, bestD, bestRect = bar, L - x, { L, B, T }
    end
  end
  if not best then return nil end
  local L, B, T = bestRect[1], bestRect[2], bestRect[3]
  local function inList(n)
    local nx, ny = Center(n)
    return nx and nx < L and ny >= B - 2 and ny <= T + 2
  end
  if nxt and inList(nxt) then return nil end
  return best, inList
end

-- D-pad up/down at the edge of a list: scroll the list one row instead of
-- leaving it (auction house, professions, quest log...). Returns true if it did.
local function TryScroll(cur, nxt, dy)
  if dy == 0 or not Nav.scrolls then return false end
  local bar, inList = ListOf(cur, nxt)
  if not bar then return false end
  local lo, hi = bar:GetMinMaxValues()
  local v = bar:GetValue()
  -- One row: an auction icon steps by its row's height (the list counts rows).
  local row = cur.GetParent and cur:GetParent()
  local step = math.max(((row and AuctionRow(row)) and row:GetHeight()) or cur:GetHeight() or 16, 8)
  local nv = v - dy * step               -- D-pad down (dy = -1) = scroll down
  nv = math.max(lo, math.min(hi, nv))
  if math.abs(nv - v) <= 0.5 then return false end
  local x, y = Center(cur)
  bar:SetValue(nv)
  -- Stay on the same screen row: same button for Blizzard's row lists, the
  -- next item for lists that really move.
  Nav.Refresh()
  local best, bd
  for _, n in ipairs(Nav.nodes) do
    local nx, ny = Center(n)
    if nx and inList(n) then
      local d = (nx - x) ^ 2 + (ny - y) ^ 2
      if not bd or d < bd then best, bd = n, d end
    end
  end
  if best then
    if best == Nav.cur then CallScript(best, "OnLeave"); Nav.cur = nil end
    Nav.Select(best)                    -- re-select: refreshes the tooltip
  end
  return true
end

function Nav.Move(dx, dy)
  if not Active() then return end
  Nav.Refresh()
  local nxt = Nav.cur and Pick(Nav.cur, Nav.nodes, dx, dy)
  if Nav.cur and TryScroll(Nav.cur, nxt, dy) then Nav.byDpad = true; return end
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

-- Quest log, X: track / untrack the quest on the selected row (or, off the
-- list, the quest shown on the right). Same as the log's Track button.
function Nav.TrackQuest(n)
  local idx
  local nm = n and n.GetName and n:GetName() or ""
  if n and n.GetID and (nm:find("^QuestLogScrollFrameButton%d") or nm:find("^QuestLogTitle%d")) then
    idx = n:GetID()
  end
  if not idx or idx < 1 then idx = GetQuestLogSelection() end
  if not idx or idx < 1 then return end
  local title, _, _, _, isHeader = GetQuestLogTitle(idx)
  if not title or isHeader then return end
  if SelectQuestLogEntry then SelectQuestLogEntry(idx) end
  if IsQuestWatched(idx) then
    RemoveQuestWatch(idx)
  else
    local max = MAX_WATCHABLE_QUESTS or 25
    if GetNumQuestWatches() >= max then
      if UIErrorsFrame and QUEST_WATCH_TOO_MANY then
        UIErrorsFrame:AddMessage(QUEST_WATCH_TOO_MANY:format(max), 1, 0.1, 0.1, 1)
      end
      return
    end
    AddQuestWatch(idx)
  end
  if WatchFrame_Update then WatchFrame_Update() end
  if QuestLog_Update then QuestLog_Update() end
end

-- What B should press. Closes our own windows / dropdowns directly.
function Nav.BackTarget()
  -- Keyboard: B deletes a letter (on an empty line it closes).
  if WP.Keyboard and WP.Keyboard:IsShown() then return WP.Keyboard.deleteKey end
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
    -- DialogUI quest window: B = Goodbye / Decline / Cancel, whichever shows.
    if name == "DQuestFrame" then
      for _, n in ipairs({ "DQuestFrameGoodbyeButton", "DQuestFrameGreetingGoodbyeButton",
                           "DQuestFrameDeclineButton", "DQuestFrameCancelButton" }) do
        local b = _G[n]
        if b and b:IsVisible() then return b end
      end
    end
    -- Immersion: B = its close button (in the talk box).
    if name == "ImmersionFrame" then
      local mf = root.TalkBox and root.TalkBox.MainFrame
      local cb = mf and rawget(mf, "CloseButton")
      if cb and cb:IsVisible() then return cb end
    end
    -- Dungeon ready: B = Leave Queue. Loot roll: B = Pass.
    local special = (name == "LFDDungeonReadyDialog" and FindButton(root, "LeaveButton", LEAVE_QUEUE))
                 or (name:find("^GroupLootFrame%d") and _G[name .. "PassButton"])
    if special and special:IsVisible() then return special end
    if name:find("^StaticPopup%d") then
      local b2 = _G[name .. "Button2"]
      if b2 and b2:IsVisible() then return b2 end
      local b1 = _G[name .. "Button1"]
      if b1 and b1:IsVisible() then return b1 end
    end
    -- Named <window>CloseButton, else the window's .CloseButton field (New
    -- Era and modern templates leave it unnamed), else a child named *CloseButton.
    local close = _G[name .. "CloseButton"]
    if not (close and close:IsVisible()) then
      local cb = rawget(root, "CloseButton")
      if type(cb) == "table" and cb.IsVisible and cb:IsVisible() then close = cb end
    end
    if not (close and close:IsVisible()) then
      close = nil
      for _, c in ipairs({ root:GetChildren() }) do
        local n = c:GetName()
        if n and n:find("CloseButton$") and c:IsVisible() then close = c; break end
      end
    end
    if close then return close end
    -- Esc menu: B = Return to Game. Options windows: B = Cancel.
    local cancel = (name == "GameMenuFrame" and _G.GameMenuButtonContinue)
                or _G[name .. "Cancel"] or _G[name .. "CancelButton"]
    if not (cancel and cancel:IsVisible()) then
      cancel = nil
      for _, c in ipairs({ root:GetChildren() }) do
        local n = c:GetName()
        if n and (n:find("Cancel$") or n:find("CancelButton$")) and c:IsVisible()
           and c:GetObjectType() == "Button" then cancel = c; break end
      end
    end
    if cancel then return cancel end
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
    if WP.Keyboard and WP.Keyboard:IsShown() then   -- keyboard: Y = space
      if down ~= false and Active() then WP.Keyboard.Space() end
      return
    end
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
  if WowPadDB.debug then WP.Print("L3 in menu: item actions") end
  if not Active() then return end
  if WP.OpenItemActions then WP.OpenItemActions() else Nav.Destroy() end
end)
-- LB/RB: pages of the main menu / setup window (channel on the keyboard),
-- else switch windows.
local function Paged() return (WP.Radial and WP.Radial:IsShown() and WP.Radial)
                           or (WP.FirstTime and WP.FirstTime:IsShown() and WP.FirstTime)
                           or (WP.Keyboard and WP.Keyboard:IsShown() and WP.Keyboard) end
IB("WowPadNavPrev",  function() local p = Paged() if p then p.Page(-1) else Nav.CycleRoot(-1) end end)
IB("WowPadNavNext",  function() local p = Paged() if p then p.Page(1) else Nav.CycleRoot(1) end end)

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
      -- Quest log: X tracks / untracks the quest (selecting its row first).
      if button == "RightButton" and QuestLogFrame and Nav.root == QuestLogFrame then
        Nav.TrackQuest(n)
        self:SetAttribute("clickbutton", nil)
        return
      end
      -- Text field: the on-screen keyboard types into it (option off: focus it).
      if n and n:GetObjectType() == "EditBox" then
        if not (WP.OpenKeyboardFor and WP.OpenKeyboardFor(n)) then n:SetFocus() end
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
