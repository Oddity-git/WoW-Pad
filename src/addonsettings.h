// addonsettings.h - settings chosen in the addon's Interface Options panel.
//
// An addon can't talk to the DLL directly, but WoW writes the addon's account
// SavedVariables (WTF\Account\<name>\SavedVariables\WowPad.lua) on /reload and
// logout. We watch that file and read a few plain numbers from it.
#pragma once

struct AddonSettings {
    float camScale   = 1.0f;  // x [Camera] Speed
    float ptrScale   = 1.0f;  // x [Cursor] Speed
    float zoomScale  = 1.0f;  // x [Camera] ZoomSpeed
    int   invertY    = -1;    // -1 = use wowpad.ini, 0/1 = override
    int   peekDelayMs = 0;    // 0 = use wowpad.ini
    bool  walkRun    = false; // walk on slight tilt, run on full tilt (experimental)
};

void                 AddonSettings_Poll();   // cheap; re-reads at most once a second when the file changed
const AddonSettings& AddonSettings_Get();
