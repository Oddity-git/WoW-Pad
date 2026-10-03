// gamewindow.h - locate wow.exe's main window and check focus.
#pragma once
#include <windows.h>

// Largest visible, unowned top-level window of this process. Cached; retried
// at most once a second while not found. May return nullptr early in startup.
HWND GameWindow_Get();
// True when the game window exists and is the foreground window.
bool GameWindow_IsForeground();
// Client area in screen coordinates. False if no window.
bool GameWindow_ClientRectScreen(RECT* out);
