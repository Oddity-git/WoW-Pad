// cursorhide.h - hide WoW's cursor while the crosshair "peeks", and watch the
// cursors the game sets (ground-target aiming, the addon's blank cursor).
//
// WoW keeps re-applying its own hand/sword cursor over anything an addon sets,
// so the DLL hooks SetCursor in the game's import tables and subclasses the
// game window (runs in WoW's UI thread). While hiding is on it blanks the
// cursor: in the SetCursor hook, on WM_SETCURSOR, on a short timer, and
// immediately when hiding starts.
#pragma once
#include <windows.h>

void CursorHide_Install(HWND hwnd);   // once the game window exists (idempotent)
void CursorHide_Set(bool hide);
bool CursorHide_IsOn();
// A spell is waiting for its location (the game shows its cast cursor).
bool CursorHide_GroundTargeting();
// The addon says a window is open (it keeps setting its blank cursor while you aim).
bool CursorHide_MenuVeto();
