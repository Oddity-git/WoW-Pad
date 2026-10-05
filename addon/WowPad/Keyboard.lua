-- Keyboard.lua - a simple on-screen keyboard above the chat window.
--
-- WoW's chat box takes every key while it has focus, so the pad can't drive
-- it. Instead you type into this keyboard and WowPad hands the finished line
-- to the chat box to send (slash commands like /w name or /p work too).
--
-- Opening: Back + A (the DLL sends Enter, the game focuses the chat box, and
-- in controller mode we swap that for this keyboard). Out of combat only, like
-- the other menus. Navigated by Nav.lua like any window:
--   D-pad: move   A: type   X: type as capital   Y: space   B: delete (empty: close)
--   LB / RB: channel   Start or Back + A: send   Back + B: close

local WP = WowPad

local ROWS = {
  { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
  { "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
}
local SHIFTED = {
  ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&",
  ["8"] = "*", ["9"] = "(", ["0"] = ")", ["'"] = '"', [","] = ";", ["."] = ":", ["/"] = "?",
}
local CHANNELS = {
  { type = "SAY",     label = "Say" },
  { type = "PARTY",   label = "Party" },
  { type = "GUILD",   label = "Guild" },
  { type = "RAID",    label = "Raid" },
  { type = "WHISPER", label = "Reply" },
}
local KEY, GAP, PAD = 30, 3, 10
local MAXLEN = 255

local K      -- the keyboard frame: built on first use only (Build below)
local line   -- its text line
local M = {} -- its functions, copied onto the frame when it's built
local text, shift, chan = "", false, 1

local function Channel()
  local c = CHANNELS[chan]
  local target
  if c.type == "WHISPER" then
    target = ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget()
    if target == "" then target = nil end
  end
  return c, target
end

local keys = {}
local function Redraw()
  local c, target = Channel()
  local info = ChatTypeInfo and ChatTypeInfo[c.type]
  local col = info and ("|cff%02x%02x%02x"):format(info.r * 255, info.g * 255, info.b * 255) or "|cffffffff"
  local label = c.type == "WHISPER" and ("To " .. (target or "?")) or c.label
  -- Show the end of long lines.
  local shown = #text > 48 and ("..." .. text:sub(-45)) or text
  line:SetText(col .. "[" .. label .. "]|r " .. shown .. "|cffffd100_|r")
  for _, b in ipairs(keys) do
    if b.char then
      local ch = b.char
      if shift then ch = SHIFTED[ch] or ch:upper() end
      b:SetText(ch)
    end
  end
  if K.shiftKey then K.shiftKey:SetText(shift and "|cffffd100SHIFT|r" or "Shift") end
end

local function Type(ch, capital)
  if #text >= MAXLEN then return end
  if capital or shift then ch = SHIFTED[ch] or ch:upper() end
  text = text .. ch
  shift = false
  Redraw()
end

function M.Space() if #text < MAXLEN then text = text .. " "; Redraw() end end
function M.Delete()
  if text == "" then K:Hide() return end
  text = text:sub(1, -2)
  Redraw()
end
-- LB / RB: next / previous channel (Reply only when someone has whispered you).
function M.Page(step)
  for _ = 1, #CHANNELS do
    chan = (chan - 1 + step) % #CHANNELS + 1
    local c, target = Channel()
    if c.type ~= "WHISPER" or target then break end
  end
  Redraw()
end

-- Hand the line to the chat box and send it: it handles channels, whisper
-- targets and slash commands exactly as if you had typed it.
function M.Send()
  local msg = text:gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then K:Hide() return end
  local c, target = Channel()
  local eb = (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame1EditBox or _G.ChatFrameEditBox
  if eb and ChatEdit_SendText then
    eb:SetAttribute("chatType", c.type)
    if target then eb:SetAttribute("tellTarget", target) end
    eb:SetText(msg)
    ChatEdit_SendText(eb, 0)
    eb:SetText("")
  elseif msg:sub(1, 1) ~= "/" then
    SendChatMessage(msg, c.type, nil, target)
  end
  text, shift = "", false
  K:Hide()
end

---------------------------------------------------------------------------
-- Build (first use only; never when the keyboard option is off)
---------------------------------------------------------------------------
local function Build()
  if K then return end
  K = CreateFrame("Frame", "WowPadKeyboard", UIParent)
  K:SetFrameStrata("DIALOG")
  K:EnableMouse(true)
  K:SetClampedToScreen(true)
  K:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  K:SetSize(PAD * 2 + 10 * KEY + 9 * GAP, PAD * 2 + 26 + 5 * (KEY + GAP))
  K:Hide()
  table.insert(WP.overlays, K)
  tinsert(UISpecialFrames, "WowPadKeyboard")   -- Esc (Back + B) closes it

  -- Version label above the top-right corner.
  local ver = K:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ver:SetPoint("BOTTOMRIGHT", K, "TOPRIGHT", -4, 2)
  ver:SetText("WowPad " .. ((GetAddOnMetadata and GetAddOnMetadata("WowPad", "Version")) or ""))

  -- Text line: [Channel] what you typed|
  line = K:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
  line:SetPoint("TOPLEFT", PAD, -PAD - 4)
  line:SetPoint("TOPRIGHT", -PAD, -PAD - 4)
  line:SetJustifyH("LEFT")

  ---------------------------------------------------------------------------
  -- Keys
  ---------------------------------------------------------------------------
  local function MakeKey(name, label, w, onClick)
    local b = CreateFrame("Button", name, K, "UIPanelButtonTemplate")
    b:SetSize(w, KEY)
    b:SetText(label)
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnClick", onClick)
    keys[#keys + 1] = b
    return b
  end

  local top = -PAD - 26
  for r, row in ipairs(ROWS) do
    for c, ch in ipairs(row) do
      local b = MakeKey("WowPadKeyboardKey" .. r .. "_" .. c, ch, KEY, function(_, button)
        Type(ch, button == "RightButton")          -- X (right-click) = capital
      end)
      b.char = ch
      b:SetPoint("TOPLEFT", PAD + (c - 1) * (KEY + GAP), top - (r - 1) * (KEY + GAP))
    end
  end
  local function unit(n) return n * KEY + (n - 1) * GAP end
  local y = top - 4 * (KEY + GAP)
  K.shiftKey = MakeKey("WowPadKeyboardShift", "Shift", unit(2), function() shift = not shift; Redraw() end)
  K.shiftKey:SetPoint("TOPLEFT", PAD, y)
  local space = MakeKey("WowPadKeyboardSpace", "Space", unit(4), function() M.Space() end)
  space:SetPoint("TOPLEFT", PAD + 2 * (KEY + GAP), y)
  local del = MakeKey("WowPadKeyboardDelete", "Delete", unit(2), function() M.Delete() end)
  del:SetPoint("TOPLEFT", PAD + 6 * (KEY + GAP), y)
  local send = MakeKey("WowPadKeyboardSend", "Send", unit(2), function() M.Send() end)
  send:SetPoint("TOPLEFT", PAD + 8 * (KEY + GAP), y)
  K.deleteKey, K.firstKey = del, _G["WowPadKeyboardKey2_1"]   -- used by Nav.lua

  -- Copy M's functions onto the frame (Nav.lua and Radial.lua call them).
  for k, v in pairs(M) do K[k] = v end
  WP.Keyboard = K
end

function M.Open(initial)
  if InCombatLockdown() then WP.Print("The keyboard isn't available in combat.") return end
  Build()
  if initial and initial ~= "" then text = initial end
  K:ClearAllPoints()
  local cf = DEFAULT_CHAT_FRAME or ChatFrame1
  if cf then K:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -6, 30) else K:SetPoint("BOTTOM", 0, 200) end
  Redraw()
  K:Show()
end

-- The keyboard stays open when you use the mouse or a touchpad (Steam Deck):
-- its keys are ordinary buttons you can click (right-click = capital).

---------------------------------------------------------------------------
-- Back + A: the DLL presses Enter, which focuses the chat box. In controller
-- mode, take over: close the box and open (or, if open, send) the keyboard.
---------------------------------------------------------------------------
local function Hook(box)
  if not box or box.wowpadKeyboard then return end
  box.wowpadKeyboard = true
  box:HookScript("OnEditFocusGained", function(self)
    if WowPadDB and WowPadDB.keyboard == false then return end   -- option off: normal chat box
    -- Real Enter in desktop mode with the keyboard open: continue in the
    -- normal chat box with what you typed so far.
    if WP.mode ~= "controller" then
      if K and K:IsShown() then
        if text ~= "" then self:SetText(text) end
        text, shift = "", false
        K:Hide()
      end
      return
    end
    if InCombatLockdown() then return end
    local initial = self:GetText()
    self:SetText("")
    if ChatEdit_OnEscapePressed then ChatEdit_OnEscapePressed(self) else self:ClearFocus() end
    if K and K:IsShown() then M.Send() else M.Open(initial) end
  end)
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  Hook(_G.ChatFrameEditBox)
  for i = 1, NUM_CHAT_WINDOWS or 10 do Hook(_G["ChatFrame" .. i .. "EditBox"]) end
end)

-- For other parts of WowPad (and tests): open the keyboard if it's enabled.
function WP.OpenKeyboard(initial)
  if WowPadDB and WowPadDB.keyboard == false then return end
  M.Open(initial)
end
