-- PartyHighlight.lua - healer mode: after a bumper tap or flick (hold the ally
-- bumper, flick the right stick), a gold frame briefly marks the targeted member's
-- unit frame, then fades. Works with any unit frames that say which unit they
-- show (Blizzard's, DragonUI, ShadowedUnitFrames, ...). Only pictures, so it
-- works in combat too.

local WP = WowPad
local SHOW_FOR, FADE = 1.5, 0.3
local UNITS = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }

local hl = CreateFrame("Frame", "WowPadPartyHighlight", UIParent)
hl:SetFrameStrata("HIGH")
hl:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
hl:SetBackdropBorderColor(1, 0.82, 0.1, 1)
local glow = hl:CreateTexture(nil, "BACKGROUND")
glow:SetTexture(1, 0.82, 0.1, 0.12)
glow:SetPoint("TOPLEFT", 3, -3)
glow:SetPoint("BOTTOMRIGHT", -3, 3)
hl:Hide()

-- Unit frames on screen for you and your party, found by their "unit"
-- attribute (or .unit field). Re-scanned at most every few seconds.
local frames, scannedAt = {}, -100
local function Scan()
  wipe(frames)
  local f = EnumerateFrames()
  while f do
    if f.IsVisible and f:IsVisible() then
      local u = (f.GetAttribute and f:GetAttribute("unit")) or rawget(f, "unit")
      if type(u) == "string" and UNITS[u] and f:GetWidth() > 20 and f:GetHeight() > 10 then
        frames[#frames + 1] = f
      end
    end
    f = EnumerateFrames(f)
  end
  scannedAt = GetTime()
end

-- The frame showing your current target; if several do, the biggest one.
local function TargetFrame()
  if not UnitExists("target") then return nil end
  if GetTime() - scannedAt > 3 then Scan() end
  local best, area
  for _, f in ipairs(frames) do
    local u = (f.GetAttribute and f:GetAttribute("unit")) or rawget(f, "unit")
    if f:IsVisible() and u and UnitIsUnit(u, "target") then
      local a = f:GetWidth() * f:GetHeight()
      if not best or a > area then best, area = f, a end
    end
  end
  return best
end

-- The updater must be a separate, shown frame: a hidden frame's OnUpdate never
-- runs, so the highlight couldn't switch itself on.
local driver = CreateFrame("Frame", nil, UIParent)
local until_ = 0
local function Update()
  local left = until_ - GetTime()
  if left <= 0 then hl:Hide(); driver:SetScript("OnUpdate", nil); return end
  local f = TargetFrame()
  if not f then hl:Hide(); return end
  if hl.on ~= f then
    hl.on = f
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
    hl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
  end
  hl:SetAlpha(left < FADE and left / FADE or 1)
  hl:Show()
end

local function Flicked()
  until_ = GetTime() + SHOW_FOR
  hl.on = nil
  driver:SetScript("OnUpdate", Update)
  Update()
end

WP.PartyFlicked, WP.PartyHighlightTick = Flicked, Update   -- (also used by tests)

-- The party-cycle buttons are made during secure setup; hook them once they exist.
table.insert(WP.setupHooks, function()
  for _, b in ipairs({ WP.partyNext, WP.partyPrev, WP.partyCur }) do
    if b and not b.wowpadHighlight then
      b.wowpadHighlight = true
      b:HookScript("PostClick", Flicked)
    end
  end
end)
