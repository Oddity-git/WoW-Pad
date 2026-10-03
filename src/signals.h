// signals.h - DLL -> addon signal keys.
//
// Each signal is a key the addon has bound. MUST match SIGNAL_KEYS in
// addon/WowPad/Signals.lua (scripts/check_signals.py verifies).
//
// Rules from the Phase 3a probe:
//  - Anything that can CAST uses an unmodified numpad key (Alt = self-cast,
//    modifiers would also flip [mod:] macro conditions).
//  - F13-F24 / ScrollLock / Pause never arrive; not used.
//  - Modified combos (ALT-CTRL-...) only for non-cast signals.
#pragma once
#include <windows.h>

enum Signal {
    // Slot keys: the addon re-points these 8 per trigger set (unmodified).
    SIG_DPAD_UP, SIG_DPAD_DOWN, SIG_DPAD_LEFT, SIG_DPAD_RIGHT,
    SIG_A, SIG_B, SIG_X, SIG_Y,
    // Trigger edges (unmodified, controller mode only).
    SIG_LT_ON, SIG_LT_OFF, SIG_RT_ON, SIG_RT_OFF,
    // Interact (your F binding) and autorun (unmodified, controller mode only).
    SIG_INTERACT, SIG_L3,
    // Right stick started moving: camera look must be on before motion (unmodified = fast).
    SIG_CAM_ACTIVE,
    // Non-cast signals (modified, controller mode only).
    SIG_LB, SIG_RB, SIG_ZOOM_ON, SIG_ZOOM_OFF, SIG_CAM_IDLE, SIG_START, SIG_BACK_TAP, SIG_BACK_HOLD,
    SIG_NAV_UP, SIG_NAV_DOWN, SIG_NAV_LEFT, SIG_NAV_RIGHT, SIG_NAV_CONFIRM, SIG_NAV_BACK,
    // Always bound.
    SIG_MODE_CONTROLLER, SIG_MODE_DESKTOP, SIG_POINTER_ON, SIG_POINTER_OFF,
    // Game's Run/Walk toggle (TOGGLERUN), for walk-on-slight-tilt (optional).
    SIG_WALK_TOGGLE,
    SIG_COUNT
};

struct SignalKey { const char* wowName; BYTE vk; int mods; };
enum { SMOD_ALT = 1, SMOD_CTRL = 2, SMOD_SHIFT = 4 };
extern const SignalKey kSignals[SIG_COUNT];

void Signal_Down(Signal s);  // unmodified signals only: key held until Signal_Up
void Signal_Up(Signal s);
void Signal_Tap(Signal s);   // press + release, with modifiers if any
