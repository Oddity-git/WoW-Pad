// cursorhide.h - hide WoW's cursor while the crosshair "peeks".
//
// WoW keeps re-applying its own hand/sword cursor over anything an addon sets,
// so the DLL subclasses the game window (runs in WoW's UI thread) and blanks
// the cursor itself while hiding is on: on WM_SETCURSOR, on a short timer, and
// immediately when hiding starts.
#pragma once
#include <windows.h>

void CursorHide_Install(HWND hwnd);   // once the game window exists (idempotent)
void CursorHide_Set(bool hide);
bool CursorHide_IsOn();
