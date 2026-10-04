-- ActionBar.lua - Phase 5: the controller action bar.
--
-- One object (WowPadBar) holding four clusters drawn like the pad, WoW
-- Forever style:
--     Default (no trigger)   top    : D-pad = 4 slots, face = fixed (jump/attack/back/menu)
--     Left    (LT held)      left   : D-pad + face = 8 slots
--     Right   (RT held)      right  : 8 slots
--     Bottom  (LT+RT held)   bottom : 8 slots
-- The slot buttons are the WowPadSlot<set>_<i> secure buttons the header binds
-- the pad keys to, so what you see is exactly what the pad fires.
--
-- Contents are saved per character and per spec (WowPadCharDB); the bar's
-- position and scale are account-wide (WowPadDB.bar). Real action bars are
-- never touched. Assigning/moving happens out of combat (secure attributes).

local WP = WowPad
local Bar = {}
WP.Bar = Bar

-- Compact WoW Forever proportions: buttons nearly touching, the left/right
-- sets sit half a row lower than the top set and half a row higher than the
-- bottom set, so the four sets interleave in a flat band.
local SIZE, STEP, HALF = 32, 26.5, 52.5  -- button size, spacing in a pad shape (~2px between rings), D-pad<->face offset
local SIDE, VERT = 189, 50               -- left/right and top/bottom set offsets from the centre
local LAYOUT_VERSION = 2                 -- bump when the shape changes (resets saved position/scale)
local CLUSTERS = {                       -- set -> centre offset inside the bar
  [0] = { 0, VERT },
  [1] = { -SIDE, 0 },
  [2] = { SIDE, 0 },
  [3] = { 0, -VERT },
}
-- slot index -> position inside a cluster (D-pad on the left, face on the right)
local SLOT_POS = {
  [1] = { -HALF, STEP }, [2] = { -HALF, -STEP }, [3] = { -HALF - STEP, 0 }, [4] = { -HALF + STEP, 0 }, -- U D L R
  [5] = { HALF, -STEP }, [6] = { HALF + STEP, 0 }, [7] = { HALF - STEP, 0 }, [8] = { HALF, STEP },     -- A B X Y
}
local TEX = "Interface\\AddOns\\WowPad\\Textures\\"  -- ring / glow / disc (round slots)

-- Round icon: SetPortraitToTexture circle-crops a texture (3.3.5 has no masks).
local function RoundIcon(tex, path)
  if path then SetPortraitToTexture(tex, path) else tex:SetTexture(nil) end
end
local FACE_LABEL = { [5] = "|cff55dd55A|r", [6] = "|cffff5555B|r", [7] = "|cff5599ffX|r", [8] = "|cffffdd33Y|r" }
-- One arrow (Textures/dpadarrow, points up) turned per direction with SetTexCoord.
local DPAD_ARROW = {
  [1] = { 0, 0, 0, 1, 1, 0, 1, 1 },   -- up
  [2] = { 1, 1, 1, 0, 0, 1, 0, 0 },   -- down (180)
  [3] = { 1, 0, 0, 0, 1, 1, 0, 1 },   -- left (90 counter-clockwise)
  [4] = { 0, 1, 1, 1, 0, 0, 1, 0 },   -- right (90 clockwise)
}
-- Default set face buttons are fixed functions (display only).
local FIXED = {
  [5] = { "Interface\\Icons\\Ability_Rogue_Sprint", "Jump" },
  [6] = { "Interface\\Icons\\Spell_Shadow_SacrificialShield", "Back / clear target" },
  [7] = { "Interface\\Icons\\Ability_MeleeDamage", "Interact + attack" },
  [8] = { "Interface\\Icons\\Ability_Hunter_SniperShot", "Target menu" },
}

local bar, clusters, slots = nil, {}, {}   -- slots["set_i"] = button
Bar.editing = false

local function Key(set, i) return set .. "_" .. i end
local function Shown(region, on) if on then region:Show() else region:Hide() end end
local function SpecTable()
  WowPadCharDB = WowPadCharDB or {}
  WowPadCharDB.specs = WowPadCharDB.specs or {}
  local spec = GetActiveTalentGroup and GetActiveTalentGroup() or 1
  WowPadCharDB.specs[spec] = WowPadCharDB.specs[spec] or {}
  return WowPadCharDB.specs[spec], spec
end

---------------------------------------------------------------------------
-- Slot contents -> secure attributes / display info
---------------------------------------------------------------------------
local ATTRS = { "type", "spell", "item", "macro", "macrotext" }

local function ApplyAttributes(btn, d)
  for _, a in ipairs(ATTRS) do btn:SetAttribute(a, nil) end
  if not d or Bar.editing then return end -- editing: clicks don't cast
  if d.kind == "spell" then
    btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", d.name)
  elseif d.kind == "item" then
    btn:SetAttribute("type", "item"); btn:SetAttribute("item", "item:" .. d.id)
  elseif d.kind == "macro" then
    btn:SetAttribute("type", "macro"); btn:SetAttribute("macro", d.name)
  elseif d.kind == "macrotext" then
    btn:SetAttribute("type", "macro"); btn:SetAttribute("macrotext", d.text)
  end
end

-- The spell a slot effectively uses (for cooldown/range/usable).
local function SlotSpell(d)
  if not d then return end
  if d.kind == "spell" then return d.name end
  if d.kind == "macro" then return (GetMacroSpell(d.name)) end
end
local function SlotItem(d)
  if not d then return end
  if d.kind == "item" then return d.id end
  if d.kind == "macro" then
    local _, link = GetMacroItem(d.name)
    return link and tonumber(link:match("item:(%d+)"))
  end
end

local function SlotIcon(d)
  if not d then return nil end
  if d.kind == "spell" then return GetSpellTexture(d.name) or d.icon end
  if d.kind == "item" then return GetItemIcon(d.id) or d.icon end
  if d.kind == "macro" then local _, icon = GetMacroInfo(d.name); return icon or d.icon end
  return d.icon
end

---------------------------------------------------------------------------
-- Visual updates (safe in combat: only textures/text/cooldown frames)
---------------------------------------------------------------------------
local function UpdateButton(btn)
  local d = btn.data
  local icon = SlotIcon(d)
  if icon ~= btn.iconPath then RoundIcon(btn.icon, icon); btn.iconPath = icon end
  Shown(btn.icon, icon ~= nil)
  Shown(btn.empty, icon == nil)
  if btn.glyph then
    btn.glyph:ClearAllPoints()
    -- like the A/B/X/Y letters: small in the bottom-right corner over a skill,
    -- big in the middle of an empty slot
    if icon then btn.glyph:SetSize(12, 12); btn.glyph:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    else btn.glyph:SetSize(18, 18); btn.glyph:SetPoint("CENTER", btn, "CENTER") end
  end
  if btn.letter then
    btn.letter:ClearAllPoints()
    if icon then btn.letter:SetPoint("BOTTOMRIGHT", -1, 1) else btn.letter:SetPoint("CENTER") end
  end

  -- cooldown
  local start, duration, enable = 0, 0, 0
  local spell, item = SlotSpell(d), SlotItem(d)
  if spell then start, duration, enable = GetSpellCooldown(spell)
  elseif item then start, duration, enable = GetItemCooldown(item) end
  if start then CooldownFrame_SetTimer(btn.cooldown, start, duration, enable) end

  -- count (items, and macros that use an item)
  if item and (d.kind == "item" or IsConsumableItem(item)) then
    local n = GetItemCount(item, nil, true)
    btn.count:SetText((n and n > 1) and n or "")
  else
    btn.count:SetText("")
  end
  Bar.UpdateUsable(btn)
end

function Bar.UpdateUsable(btn)
  local d = btn.data
  if not d then return end
  local spell, item = SlotSpell(d), SlotItem(d)
  local usable, noMana, inRange = true, false, nil
  if spell then
    usable, noMana = IsUsableSpell(spell)
    if UnitExists("target") then inRange = IsSpellInRange(spell, "target") end
  elseif item then
    usable, noMana = IsUsableItem(item)
    if UnitExists("target") then inRange = IsItemInRange(item, "target") end
  end
  if inRange == 0 then
    btn.icon:SetVertexColor(0.85, 0.2, 0.2)
  elseif noMana then
    btn.icon:SetVertexColor(0.4, 0.4, 1.0)
  elseif usable then -- IsUsableSpell/IsUsableItem return nil (not false) when unusable
    btn.icon:SetVertexColor(1, 1, 1)
  else
    btn.icon:SetVertexColor(0.4, 0.4, 0.4)
  end
end

function Bar.UpdateAll()
  for _, btn in pairs(slots) do UpdateButton(btn) end
end

function Bar.HighlightSet(set)
  for s, c in pairs(clusters) do
    for _, o in ipairs(c.outlines) do Shown(o, s == set) end
  end
end

---------------------------------------------------------------------------
-- Assigning (drag & drop, out of combat)
---------------------------------------------------------------------------
local function DataFromCursor()
  local kind, a1, a2 = GetCursorInfo()
  if kind == "spell" then
    if a2 ~= BOOKTYPE_SPELL and a2 ~= "spell" then return nil, "Pet abilities can't go on the controller bar yet." end
    local name = GetSpellName(a1, a2)
    return name and { kind = "spell", name = name, icon = GetSpellTexture(a1, a2) }
  elseif kind == "item" then
    return { kind = "item", id = a1, icon = GetItemIcon(a1) }
  elseif kind == "macro" then
    local name, icon = GetMacroInfo(a1)
    return name and { kind = "macro", name = name, icon = icon }
  elseif kind == "companion" then
    local _, _, spellID, icon = GetCompanionInfo(a2, a1)
    local name = spellID and GetSpellInfo(spellID)
    return name and { kind = "spell", name = name, icon = icon }
  elseif kind == "equipmentset" then
    local icon = GetEquipmentSetInfoByName and GetEquipmentSetInfoByName(a1)
    return { kind = "macrotext", text = "/equipset " .. a1, icon = icon, label = a1 }
  end
  return nil
end

local function SetSlot(btn, d)
  local tbl = SpecTable()
  tbl[btn.key] = d
  btn.data = d
  ApplyAttributes(btn, d)
  UpdateButton(btn)
end

local function PickupData(d)
  if not d then return end
  if d.kind == "spell" then
    local i = 1
    while true do
      local n = GetSpellName(i, BOOKTYPE_SPELL)
      if not n then break end
      if n == d.name then PickupSpell(i, BOOKTYPE_SPELL) return end
      i = i + 1
    end
  elseif d.kind == "item" then PickupItem(d.id)
  elseif d.kind == "macro" then PickupMacro(d.name)
  end
end

local function OnReceiveDrag(btn)
  if InCombatLockdown() then WP.Print("Can't change the controller bar in combat.") return end
  if not GetCursorInfo() then return end
  local d, err = DataFromCursor()
  if not d then if err then WP.Print(err) end return end
  local old = btn.data
  ClearCursor()
  SetSlot(btn, d)
  if old then PickupData(old) end -- swap, like normal action bars
end

local function OnDragStart(btn)
  if InCombatLockdown() or not (Bar.editing or IsShiftKeyDown()) then return end
  local d = btn.data
  if not d then return end
  SetSlot(btn, nil)
  PickupData(d)
end

local function ShowTooltip(btn)
  local d = btn.data
  GameTooltip:SetOwner(btn, "ANCHOR_TOP")
  if btn.fixed then
    GameTooltip:SetText(btn.fixed)
  elseif not d then
    GameTooltip:SetText(Bar.editing and "Empty: drop a spell, item or macro here" or "Empty")
  elseif d.kind == "spell" then
    local link = GetSpellLink(d.name)
    if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(d.name) end
  elseif d.kind == "item" then
    GameTooltip:SetHyperlink("item:" .. d.id)
  elseif d.kind == "macro" then
    GameTooltip:SetText(d.name)
    local spell = GetMacroSpell(d.name)
    if spell then GameTooltip:AddLine(spell, 1, 1, 1) end
  else
    GameTooltip:SetText(d.label or d.text or "?")
  end
  if Bar.editing and d then GameTooltip:AddLine("Drag out to remove, right-click to clear", 0.6, 0.8, 1) end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Loading the current spec's layout
---------------------------------------------------------------------------
function Bar.Load()
  if not bar or InCombatLockdown() then return end
  local tbl = SpecTable()
  for key, btn in pairs(slots) do
    btn.data = tbl[key]
    ApplyAttributes(btn, btn.data)
  end
  Bar.UpdateAll()
end

---------------------------------------------------------------------------
-- Position / scale (account-wide)
---------------------------------------------------------------------------
local function SavePosition()
  local x, y = bar:GetCenter()
  WowPadDB.bar = WowPadDB.bar or {}
  WowPadDB.bar.x, WowPadDB.bar.y = x, y
end

local function ApplyPosition()
  if not WowPadDB.bar or WowPadDB.bar.layout ~= LAYOUT_VERSION then
    WowPadDB.bar = { layout = LAYOUT_VERSION }
  end
  local p = WowPadDB.bar
  bar:SetScale(p.scale or 1)
  bar:ClearAllPoints()
  if p.x then
    bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
  else
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
  end
end

function Bar.SetScale(scale)
  if InCombatLockdown() or not bar then return end
  scale = math.max(0.4, math.min(1.6, scale))
  local x, y = bar:GetCenter()
  local old = bar:GetScale()
  WowPadDB.bar = WowPadDB.bar or {}
  WowPadDB.bar.scale = scale
  if x then WowPadDB.bar.x, WowPadDB.bar.y = x * old / scale, y * old / scale end
  ApplyPosition()
end

---------------------------------------------------------------------------
-- Edit mode
---------------------------------------------------------------------------
local editHelp
function Bar.SetEditing(on)
  if InCombatLockdown() or not bar then
    if on then WP.Print("Can't edit the controller bar in combat.") end
    return
  end
  Bar.editing = on
  for _, btn in pairs(slots) do ApplyAttributes(btn, btn.data) end -- no casting while editing
  bar:EnableMouse(on)
  bar:EnableMouseWheel(on) -- only while editing, so camera zoom works over the bar
  Shown(bar.editBg, on)
  Shown(editHelp, on)
  WP.header:SetAttribute("editing", on and 1 or 0) -- keeps the bar visible in desktop mode
  if WP.Extra then WP.Extra.SetEditing(on) end     -- XP and pet bar movers
  if on then
    WP.Print("Edit mode: drag spells, items or macros onto slots; drag the bar to move it; "
             .. "mouse wheel over it to resize; right-click a slot to clear. /wp edit to finish.")
  else
    WP.Print("Controller bar saved.")
  end
end
function WP.ToggleEdit() Bar.SetEditing(not Bar.editing) end

-- /wp bar: always visible (default) vs controller mode only.
function Bar.ToggleAlways()
  if InCombatLockdown() or not bar then WP.Print("Not in combat.") return end
  WowPadDB.barAlways = (WowPadDB.barAlways == false)
  WP.header:SetAttribute("alwaysbar", WowPadDB.barAlways and 1 or 0)
  WP.Print("Controller bar: " .. (WowPadDB.barAlways and "always visible" or "controller mode only"))
end

---------------------------------------------------------------------------
-- Construction (out of combat, via setup hook)
---------------------------------------------------------------------------
local function MakeCluster(set)
  local c = CreateFrame("Frame", "WowPadBarCluster" .. set, bar)
  c:SetSize(2 * (HALF + STEP) + SIZE, 2 * STEP + SIZE)
  c:SetPoint("CENTER", bar, "CENTER", CLUSTERS[set][1], CLUSTERS[set][2])
  c.outlines = {}
  clusters[set] = c
  return c
end

-- Gold outline shown on every button of the set you're holding.
local function AddOutline(parent, set)
  local o = parent:CreateTexture(nil, "OVERLAY")
  o:SetTexture(TEX .. "glow")
  o:SetBlendMode("ADD")
  o:SetSize(SIZE * 1.15, SIZE * 1.15)   -- hugs the ring
  o:SetPoint("CENTER")
  o:Hide()
  table.insert(clusters[set].outlines, o)
end

---------------------------------------------------------------------------
-- Press feedback (Blizzard-style "recess"): the icon sinks in and darkens for
-- a moment whenever the slot fires. Visual only: textures, so fine in combat.
---------------------------------------------------------------------------
local PRESS_TIME, PRESS_INSET, PRESS_DARK = 0.12, 2, 0.55
local pressed = {}
local pressDriver = CreateFrame("Frame")
pressDriver:Hide()
local function Release(btn)
  pressed[btn] = nil
  btn.icon:ClearAllPoints()
  btn.icon:SetAllPoints(btn)
  if btn.data then UpdateButton(btn) else btn.icon:SetVertexColor(1, 1, 1) end  -- back to its usable tint
end
pressDriver:SetScript("OnUpdate", function(self, e)
  local any = false
  for btn, t in pairs(pressed) do
    t = t - e
    if t <= 0 then Release(btn) else pressed[btn] = t; any = true end
  end
  if not any then self:Hide() end
end)
function Bar.Press(btn)
  if not btn or not btn.icon or not btn:IsVisible() then return end
  btn.icon:ClearAllPoints()
  btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", PRESS_INSET, -PRESS_INSET)
  btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -PRESS_INSET, PRESS_INSET)
  local r, g, b = btn.icon:GetVertexColor()
  btn.icon:SetVertexColor(r * PRESS_DARK, g * PRESS_DARK, b * PRESS_DARK)
  pressed[btn] = PRESS_TIME
  pressDriver:Show()
end

-- The fixed A/B/X/Y of the default set aren't buttons that get clicked, so
-- watch what they trigger: jump, start attack, our back / target menu buttons.
local function HookFixedPresses()
  local function F(i) return function() if WP.mode == "controller" and WP.set == 0 then Bar.Press(Bar.fixedFrames and Bar.fixedFrames[i]) end end end
  if not Bar.hookedJump then
    Bar.hookedJump = true
    if JumpOrAscendStart then hooksecurefunc("JumpOrAscendStart", F(5)) end
    if StartAttack then hooksecurefunc("StartAttack", F(7)) end
  end
  for i, name in pairs({ [6] = "WowPadBackButton", [7] = "WowPadNoop", [8] = "WowPadUnitMenu" }) do
    local b = _G[name]
    if b and not b.wpPressHooked then b.wpPressHooked = true; b:HookScript("PostClick", F(i)) end
  end
end
Bar.HookFixedPresses = HookFixedPresses

local function MakeFixed(c, i)
  local f = CreateFrame("Button", nil, c)
  f:SetSize(SIZE, SIZE)
  f:SetPoint("CENTER", c, "CENTER", SLOT_POS[i][1], SLOT_POS[i][2])
  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  RoundIcon(tex, FIXED[i][1])
  local ring = f:CreateTexture(nil, "OVERLAY")
  ring:SetTexture(TEX .. "ring")
  ring:SetSize(SIZE * 1.12, SIZE * 1.12)
  ring:SetPoint("CENTER")
  local label = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  label:SetPoint("BOTTOMRIGHT", -1, 1)
  label:SetText(FACE_LABEL[i])
  AddOutline(f, 0)
  f.fixed = FIXED[i][2]
  f.icon = tex
  Bar.fixedFrames = Bar.fixedFrames or {}
  Bar.fixedFrames[i] = f
  f:SetScript("OnEnter", ShowTooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeSlot(c, set, i)
  local name = ("WowPadSlot%d_%d"):format(set, i)
  -- ActionButtonTemplate is a CheckButton template (Blizzard's bars are CheckButtons too).
  local btn = CreateFrame("CheckButton", name, c, "SecureActionButtonTemplate, ActionButtonTemplate")
  btn:SetSize(SIZE, SIZE)
  btn:SetPoint("CENTER", c, "CENTER", SLOT_POS[i][1], SLOT_POS[i][2])
  btn:RegisterForClicks("AnyDown")      -- key bindings click on press only (no double cast)
  btn:RegisterForDrag("LeftButton")
  btn.key = Key(set, i)
  btn.icon = _G[name .. "Icon"]
  btn.count = _G[name .. "Count"]
  btn.cooldown = _G[name .. "Cooldown"]
  -- Round look: drop the template's square frame/pressed/checked art, add a ring.
  for _, t in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture(), btn:GetCheckedTexture(), _G[name .. "Border"] }) do
    if t then t:SetTexture(nil) end
  end
  local ring = btn:CreateTexture(nil, "OVERLAY")
  ring:SetTexture(TEX .. "ring")
  ring:SetSize(SIZE * 1.12, SIZE * 1.12)
  ring:SetPoint("CENTER")
  btn:SetHighlightTexture(TEX .. "glow", "ADD")
  -- The cooldown sweep is always square in 3.3.5: inset it so the ring hides the corners.
  btn.cooldown:ClearAllPoints()
  btn.cooldown:SetPoint("TOPLEFT", 3, -3)
  btn.cooldown:SetPoint("BOTTOMRIGHT", -3, 3)
  local hotkey = _G[name .. "HotKey"]
  if hotkey then hotkey:SetText(""); hotkey:Hide() end
  if DPAD_ARROW[i] then
    -- on its own child frame so it always draws above the ring and cooldown
    local gf = CreateFrame("Frame", nil, btn)
    gf:SetAllPoints()
    gf:SetFrameLevel(btn:GetFrameLevel() + 4)
    btn.glyph = gf:CreateTexture(nil, "OVERLAY")
    btn.glyph:SetTexture(TEX .. "dpadarrow")
    btn.glyph:SetTexCoord(unpack(DPAD_ARROW[i]))
  else
    btn.letter = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.letter:SetText(FACE_LABEL[i])
  end
  btn.empty = btn:CreateTexture(nil, "BACKGROUND")
  btn.empty:SetTexture(TEX .. "disc")
  btn.empty:SetAllPoints()
  AddOutline(btn, set)
  btn:SetScript("OnReceiveDrag", OnReceiveDrag)
  btn:SetScript("OnDragStart", OnDragStart)
  btn:SetScript("OnEnter", ShowTooltip)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Mouse click with something on the cursor = place it (don't cast the old one first).
  btn:SetScript("PreClick", function(self)
    if not InCombatLockdown() and GetCursorInfo() then self:SetAttribute("type", nil) end
  end)
  btn:SetScript("PostClick", function(self, mouse)
    self:SetChecked(false)
    if not Bar.editing then Bar.Press(self) end   -- press feedback (before the combat return)
    if InCombatLockdown() then return end
    if GetCursorInfo() then OnReceiveDrag(self)
    elseif Bar.editing and mouse == "RightButton" then SetSlot(self, nil)
    else ApplyAttributes(self, self.data) end
  end)
  slots[btn.key] = btn
end

table.insert(WP.setupHooks, function()
  bar = CreateFrame("Frame", "WowPadBar", UIParent, "SecureHandlerBaseTemplate")
  bar:SetSize(2 * SIDE + 2 * (HALF + STEP) + SIZE + 20, 2 * VERT + 2 * STEP + SIZE + 20)
  bar:SetFrameStrata("MEDIUM")
  bar:SetMovable(true)
  bar:SetClampedToScreen(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function(self) if Bar.editing then WP.SnapDragStart(self) end end)
  bar:SetScript("OnDragStop", function(self) WP.SnapDragStop(); SavePosition() end)
  bar:SetScript("OnMouseWheel", function(_, delta)
    if Bar.editing then Bar.SetScale(((WowPadDB.bar and WowPadDB.bar.scale) or 1) + delta * 0.05) end
  end)
  bar.editBg = bar:CreateTexture(nil, "BACKGROUND")
  bar.editBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  bar.editBg:SetVertexColor(0.2, 0.5, 1, 0.25)
  bar.editBg:SetAllPoints()
  bar.editBg:Hide()
  editHelp = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  editHelp:SetPoint("BOTTOM", bar, "TOP", 0, 6)
  editHelp:SetText("EDIT MODE - drag spells here, drag bar to move, wheel to resize, right-click to clear  (/wp edit to finish)")
  editHelp:Hide()
  bar:Hide()
  Bar.frame = bar

  for set = 0, 3 do
    local c = MakeCluster(set)
    for i = 1, 8 do
      if set == 0 and i >= 5 then MakeFixed(c, i) else MakeSlot(c, set, i) end
    end
  end
  ApplyPosition()

  -- The header shows/hides the bar (always, or controller/edit mode only); works in combat.
  SecureHandlerSetFrameRef(WP.header, "bar", bar)
  WP.header:SetAttribute("alwaysbar", WowPadDB.barAlways == false and 0 or 1)
  WP.header:SetAttribute("refresh", (WP.header:GetAttribute("refresh") or 0) + 1)

  Bar.Load()
  Bar.HighlightSet(WP.set)
  HookFixedPresses()
end)

-- Some of the buttons the fixed A/B/X/Y watch are made by other files' setup.
local pressHookEv = CreateFrame("Frame")
pressHookEv:RegisterEvent("PLAYER_ENTERING_WORLD")
pressHookEv:SetScript("OnEvent", function() if Bar.frame then HookFixedPresses() end end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ACTIVE_TALENT_GROUP_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
                     "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED",
                     "UPDATE_MACROS", "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event)
  if not bar then return end
  if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    Bar.Load()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if Bar.editing then Bar.SetEditing(false) end -- last moment before lockdown
  else
    Bar.UpdateAll()
  end
end)

-- Range / usability poll.
local acc = 0
local poll = CreateFrame("Frame")
poll:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 0.2 or not bar or not bar:IsVisible() then return end
  acc = 0
  for _, btn in pairs(slots) do Bar.UpdateUsable(btn) end
end)
