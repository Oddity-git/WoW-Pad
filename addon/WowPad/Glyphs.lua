-- Glyphs.lua - button names and icons in the chosen style (Xbox or PlayStation).
--
-- Face buttons are icons (Textures/btn_xb_*.tga, btn_ps_*.tga, drawn by
-- scripts/make_button_glyphs.py); the other buttons are short names:
--   Xbox:        A B X Y   LB RB   LT RT   Back   Start
--   PlayStation: ✕ ○ □ △   L1 R1   L2 R2   Share  Options
-- Option: Options > Buttons, or the setup window (WowPadDB.buttonStyle).
--
--   WP.Keys(s)  a string of button names ("LB / RB", "Back + A", "LT+RT"):
--               every name in it becomes the chosen style's icon / name.
--   WP.Text(s)  ordinary text with button names in braces ("press {A} to jump").
--   WP.KeyText(fontString, raw, isText)  set a label now and again whenever
--               the style changes.

local WP = WowPad
WP.styleHooks = WP.styleHooks or {}   -- called when the style changes (bar icons, open windows...)
local TEX = "Interface\\AddOns\\WowPad\\Textures\\"

local FACE = {
  xbox = { A = "btn_xb_a", B = "btn_xb_b", X = "btn_xb_x", Y = "btn_xb_y" },
  ps   = { A = "btn_ps_cross", B = "btn_ps_circle", X = "btn_ps_square", Y = "btn_ps_triangle" },
}
local NAMES = {
  xbox = {},
  ps   = { LB = "L1", RB = "R1", LT = "L2", RT = "R2", Back = "Share", Start = "Options" },
}

function WP.ButtonStyle()
  return (WowPadDB and WowPadDB.buttonStyle == "ps") and "ps" or "xbox"
end

-- Texture path of a face button's icon ("A", "B", "X" or "Y").
function WP.FaceTexture(name)
  local f = FACE[WP.ButtonStyle()][name]
  return f and (TEX .. f)
end

-- How far inline icons are lifted (see Key). The game still keeps room for
-- the icon's unlifted position, so a line with icons draws this much above
-- its middle: boxes around such a line move the text down by it.
function WP.GlyphLift(size) return math.floor((size or 20) * 0.3 + 0.5) + 2 end

-- Vertical nudge for a single-line label placed by its middle (CENTER /
-- LEFT / RIGHT anchors): text with icons draws high, this moves it back.
-- Same correction as the menu hint bar (measured in play).
function WP.IconNudge(text)
  return (text and text:find("|T", 1, true)) and (2 - WP.GlyphLift()) or 0
end

-- Face buttons as words, for places that can't hold icons well (dropdown menus).
local PLAIN = {
  xbox = { A = "A", B = "B", X = "X", Y = "Y" },
  ps   = { A = "Cross", B = "Circle", X = "Square", Y = "Triangle" },
}
function WP.KeysPlain(s)
  if not s then return s end
  local style = WP.ButtonStyle()
  return (s:gsub("%a%w*", function(w) return PLAIN[style][w] or NAMES[style][w] end))
end

-- A string of button names as separate pieces, for layouts that place icons
-- themselves (the menu hint bar): { tex = path } for face buttons,
-- { text = "..." } for everything else (names in the chosen style).
function WP.KeyPieces(s)
  local out, i = {}, 1
  local style = WP.ButtonStyle()
  local function addText(t)
    if t == "" then return end
    local last = out[#out]
    if last and last.text then last.text = last.text .. t else out[#out + 1] = { text = t } end
  end
  while true do
    local a, b = s:find("%a%w*", i)
    if not a then addText(s:sub(i)); break end
    addText(s:sub(i, a - 1))
    local w = s:sub(a, b)
    local f = FACE[style][w]
    if f then out[#out + 1] = { tex = TEX .. f } else addText(NAMES[style][w] or w) end
    i = b + 1
  end
  return out
end

-- A line of hints ({ key = "A", text = "Select" }, ...) laid out piece by
-- piece: icon, button name, words, each placed by its middle on the line's
-- centre. Icons inside text sit a few pixels off, differently in different
-- windows; this keeps them level everywhere. The frame sizes itself to fit.
--   local line = WP.NewKeyLine(parent, "GameFontHighlightSmall", 18)
--   line:SetPoint(...); line:SetParts(parts)
function WP.NewKeyLine(parent, font, icon)
  local line = CreateFrame("Frame", nil, parent)
  line:SetHeight(icon or 18)
  local pool = { tex = {}, fs = {} }
  local function Piece(kind, n)
    if not pool[kind][n] then
      if kind == "tex" then
        pool.tex[n] = line:CreateTexture(nil, "OVERLAY")
        pool.tex[n]:SetSize(icon or 18, icon or 18)
      else
        pool.fs[n] = line:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
      end
    end
    return pool[kind][n]
  end
  function line:SetParts(parts, gap)
    self.parts, self.gap = parts, gap
    local nt, nf, x = 0, 0, 0
    for pi, part in ipairs(parts) do
      if pi > 1 then x = x + (gap or 4) end
      local pieces = WP.KeyPieces(part.key)
      pieces[#pieces + 1] = { text = " " .. part.text, plain = true }
      for _, pc in ipairs(pieces) do
        local r
        if pc.tex then
          nt = nt + 1; r = Piece("tex", nt)
          r:SetTexture(pc.tex)
        else
          nf = nf + 1; r = Piece("fs", nf)
          r:SetText(pc.plain and pc.text or ("|cffffd100" .. pc.text .. "|r"))
        end
        r:ClearAllPoints()
        r:SetPoint("LEFT", self, "LEFT", x, 0)
        r:Show()
        x = x + (pc.tex and ((icon or 18) + 1) or (r:GetStringWidth() or 0))
      end
    end
    for i = nt + 1, #pool.tex do pool.tex[i]:Hide() end
    for i = nf + 1, #pool.fs do pool.fs[i]:Hide() end
    self:SetWidth(math.max(x, 1))
    return x
  end
  -- Redraw in the new style when it changes.
  table.insert(WP.styleHooks, function() if line.parts then line:SetParts(line.parts, line.gap) end end)
  return line
end

-- One button: icon (face buttons) or name; anything else comes back unchanged.
local function Key(name, size)
  local style = WP.ButtonStyle()
  local f = FACE[style][name]
  if f then
    size = size or 20
    -- The game draws an inline picture taller than the text too low (measured
    -- in play: an 18 px icon at offset 0 sat ~6 px below the text's middle),
    -- so lift it to centre it on the line.
    local up = WP.GlyphLift(size)
    return ("|T%s%s:%d:%d:0:%d|t"):format(TEX, f, size, size, up)
  end
  return NAMES[style][name]
end

function WP.Keys(s, size)
  if not s then return s end
  return (s:gsub("%a%w*", function(w) return Key(w, size) end))
end

function WP.Text(s, size)
  if not s then return s end
  return (s:gsub("{(%a%w*)}", function(w) return Key(w, size) or w end))
end

local registered = {}
function WP.KeyText(fs, raw, isText, size)
  registered[fs] = { raw, isText, size }
  fs:SetText(isText and WP.Text(raw, size) or WP.Keys(raw, size))
end

-- (WP.styleHooks: see the top of the file.)

local function Refresh()
  for fs, r in pairs(registered) do
    fs:SetText(r[2] and WP.Text(r[1], r[3]) or WP.Keys(r[1], r[3]))
  end
  for _, fn in ipairs(WP.styleHooks) do pcall(fn) end
  if WP.UpdateStatus then WP.UpdateStatus() end
end

function WP.SetButtonStyle(style)
  WowPadDB.buttonStyle = (style == "ps") and "ps" or "xbox"
  Refresh()
end

-- Labels made while the addon loads come before the saved settings: redo
-- them once those are in.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", Refresh)
