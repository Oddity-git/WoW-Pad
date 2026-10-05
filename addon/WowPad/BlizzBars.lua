-- BlizzBars.lua - hide Blizzard's bottom UI (like Bartender / Dominos).
--
-- Frames are re-parented to a hidden frame instead of :Hide()-ing them, so
-- Blizzard code that calls :Show() on them later (vehicle exit, level up,
-- stance change...) can't bring them back. The vehicle bar and the Leave
-- Vehicle button are left alone so vehicles keep working. Your keybinds for the hidden bars still work.
-- Only changed out of combat (the bars contain protected buttons).

local WP = WowPad

local hider = CreateFrame("Frame", "WowPadBlizzHider", UIParent)
hider:Hide()

-- Everything on the bottom of the screen plus the side bars.
local FRAMES = {
  "MainMenuBar",            -- main action bar, art, XP/rep bars, bag buttons, micro menu
  "MultiBarBottomLeft", "MultiBarBottomRight",
  "MultiBarLeft", "MultiBarRight",
  "ShapeshiftBarFrame",     -- stance / form bar
  "PetActionBarFrame",
  "PossessBarFrame",
  "BonusActionBarFrame",    -- warrior stances, druid forms, rogue stealth bar
}
-- Kept visible: vehicles without the full vehicle UI only have this button
-- to get out. It may belong to MainMenuBar, so it is moved to UIParent.
local LEAVE = "MainMenuBarVehicleLeaveButton"

local original = {}         -- frame -> original parent

local function Apply(hide)
  if InCombatLockdown() then return false end
  for _, name in ipairs(FRAMES) do
    local f = _G[name]
    if f then
      if hide then
        if not original[f] then original[f] = f:GetParent() end
        f:SetParent(hider)
      elseif original[f] then
        f:SetParent(original[f])
      end
    end
  end
  local leave = _G[LEAVE]
  if leave then
    if hide then
      if not original[leave] then original[leave] = leave:GetParent() end
      leave:SetParent(UIParent)
    elseif original[leave] then
      leave:SetParent(original[leave])
    end
  end
  return true
end

function WP.ToggleBlizzBars()
  if InCombatLockdown() then WP.Print("Not in combat.") return end
  WowPadDB.hideBlizz = not WowPadDB.hideBlizz
  Apply(WowPadDB.hideBlizz)
  WP.Print("Blizzard bars and bottom art: " .. (WowPadDB.hideBlizz and "hidden" or "shown")
           .. (WowPadDB.hideBlizz and "" or " (a /reload tidies their positions)"))
end

table.insert(WP.setupHooks, function()
  if WowPadDB.hideBlizz == nil then WowPadDB.hideBlizz = true end
  if WowPadDB.hideBlizz then Apply(true) end
end)
