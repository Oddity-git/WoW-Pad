-- Signals.lua - the key the wowpad DLL presses for each signal, plus the slot
-- and set names shared by the other files.
-- MUST match kSignals in src/signals.cpp (scripts/check_signals.py verifies).
-- Order here mirrors the C enum.

WowPad = WowPad or {}

WowPad.SIGNAL_KEYS = {
  { "DPAD_UP",         "NUMPAD8" },
  { "DPAD_DOWN",       "NUMPAD2" },
  { "DPAD_LEFT",       "NUMPAD4" },
  { "DPAD_RIGHT",      "NUMPAD6" },
  { "A",               "NUMPAD1" },
  { "B",               "NUMPAD3" },
  { "X",               "NUMPAD7" },
  { "Y",               "NUMPAD9" },
  { "LT_ON",           "NUMPADDIVIDE" },
  { "LT_OFF",          "NUMPADMULTIPLY" },
  { "RT_ON",           "NUMPADMINUS" },
  { "RT_OFF",          "NUMPADPLUS" },
  { "INTERACT",        "NUMPAD5" },
  { "L3",              "NUMPADDECIMAL" },
  { "CAM_ACTIVE",      "NUMPAD0" },
  { "LB",              "ALT-CTRL-NUMPAD7" },
  { "RB",              "ALT-CTRL-NUMPAD9" },
  { "ZOOM_ON",         "ALT-CTRL-SHIFT-F6" },
  { "ZOOM_OFF",        "ALT-CTRL-SHIFT-F7" },
  { "CAM_IDLE",        "ALT-CTRL-SHIFT-F8" },
  { "START",           "ALT-CTRL-NUMPAD5" },
  { "BACK_TAP",        "ALT-CTRL-NUMPAD0" },
  { "BACK_HOLD",       "ALT-CTRL-SHIFT-F5" },
  { "NAV_UP",          "ALT-CTRL-NUMPAD8" },
  { "NAV_DOWN",        "ALT-CTRL-NUMPAD2" },
  { "NAV_LEFT",        "ALT-CTRL-NUMPAD4" },
  { "NAV_RIGHT",       "ALT-CTRL-NUMPAD6" },
  { "NAV_CONFIRM",     "ALT-CTRL-NUMPAD1" },
  { "NAV_BACK",        "ALT-CTRL-NUMPAD3" },
  { "MODE_CONTROLLER", "ALT-CTRL-SHIFT-F1" },
  { "MODE_DESKTOP",    "ALT-CTRL-SHIFT-F2" },
  { "POINTER_ON",      "ALT-CTRL-SHIFT-F3" },
  { "POINTER_OFF",     "ALT-CTRL-SHIFT-F4" },
  { "WALK_TOGGLE",     "ALT-CTRL-SHIFT-F9" },
  { "LB_FLICK_DOWN",   "ALT-CTRL-NUMPADDIVIDE" },
  { "LB_FLICK_UP",     "ALT-CTRL-NUMPADMULTIPLY" },
  { "RB_FLICK_DOWN",   "ALT-CTRL-NUMPADMINUS" },
  { "RB_FLICK_UP",     "ALT-CTRL-NUMPADPLUS" },
  { "RING_DIR_0",      "CTRL-SHIFT-F1" },
  { "RING_DIR_1",      "CTRL-SHIFT-F2" },
  { "RING_DIR_2",      "CTRL-SHIFT-F3" },
  { "RING_DIR_3",      "CTRL-SHIFT-F4" },
  { "RING_DIR_4",      "CTRL-SHIFT-F5" },
  { "RING_DIR_5",      "CTRL-SHIFT-F6" },
  { "RING_DIR_6",      "CTRL-SHIFT-F7" },
  { "RING_DIR_7",      "CTRL-SHIFT-F8" },
  { "RING_DIR_8",      "CTRL-SHIFT-F9" },
}

-- Signal name -> key, e.g. WowPad.KEY.LB.
WowPad.KEY = {}
for _, e in ipairs(WowPad.SIGNAL_KEYS) do WowPad.KEY[e[1]] = e[2] end

-- The 8 slot buttons, in the order the secure header uses (1..8).
WowPad.SLOT_SIGNALS = { "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT", "A", "B", "X", "Y" }
WowPad.SLOT_LABELS  = { "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right", "A", "B", "X", "Y" }
WowPad.SET_NAMES    = { [0] = "Default", [1] = "Left (LT)", [2] = "Right (RT)", [3] = "Bottom (LT+RT)" }
