// hooks.h - low-level keyboard/mouse hooks for desktop-mode detection.
// Runs on its own thread with a message loop (LL hooks require one).
// Only records THAT real input happened; never which keys.
// Verified in testing: real input has no injected flag, ours carries
// WOWPAD_INPUT_TAG, nothing else injects.
#pragma once

void Hooks_Start();
// Real key press / mouse button / wheel since last call.
bool Hooks_TakeRealPress();
// Real mouse travel in pixels (|dx|+|dy|) since last call.
long Hooks_TakeRealMouseTravel();
