// addonsettings.h - settings chosen in the addon's Interface Options panel.
//
// An addon can't talk to the DLL directly, but WoW writes the addon's account
// SavedVariables (WTF\Account\<name>\SavedVariables\WowPad.lua) on /reload and
// logout. We watch that file and read a few plain numbers from it.
#pragma once

struct AddonSettings {
    float camScale    = 1.0f;  // x [Camera] Speed
    float ptrScale    = 1.0f;  // x [Cursor] Speed
    float zoomScale   = 1.0f;  // x [Camera] ZoomSpeed
    int   invertY     = -1;    // -1 = use wowpad.ini, 0/1 = override
    int   peekDelayMs = 0;     // 0 = use wowpad.ini
    bool  walkRun     = false; // walk on slight tilt, run on full tilt (experimental)
    bool  camSmooth   = false; // smooth camera turning (experimental)
    int   ringSlot    = 0;     // utility ring on bar slot set*10+i (0 = none)
    bool  bumperFlick = false; // healer mode: bumper held + right stick flicks pick party members
};

// Starts a background thread that re-reads the file when it changes (once a
// second). File access under Wine can take milliseconds; doing it in the
// controller poll loop caused a small hitch every second.
void          AddonSettings_Start();
AddonSettings AddonSettings_Get();   // a copy, safe from any thread
