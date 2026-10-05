// cursorhide.cpp - SetCursor hook, window subclass and cast-cursor detection.
#include "cursorhide.h"
#include "log.h"
#include <tlhelp32.h>
#include <string.h>
#include <stdint.h>

namespace {
const UINT     WM_WOWPAD_CURSOR = WM_APP + 0x5750;
const UINT_PTR TIMER_ID         = 0x5750;
const UINT     TIMER_MS         = 15;

HWND          g_hwnd     = nullptr;
WNDPROC       g_origProc = nullptr;
volatile LONG g_hide     = 0;

// WoW (and its D3D layer) re-set the attack cursor many times a second; the
// only flicker-free way is to intercept those calls. We patch the SetCursor
// entry in each loaded module's import table (no game memory addresses).
typedef HCURSOR(WINAPI* SetCursor_t)(HCURSOR);
SetCursor_t g_realSetCursor = nullptr;
volatile HCURSOR g_wanted = nullptr;   // what the game last asked for

// Ground targeting: while a spell waits for its location, the game shows its
// "cast" cursor (a blue glowing hand). Every cursor the game sets is checked
// for it by its look: about two thirds of the pixels visible, average colour
// blue (measured under Proton: 667 of 1024 pixels, average 5a7f93). The normal
// pointer is grey and the others are brown/grey, so nothing else matches.
//
// Aiming stays on from the first cast cursor until a cursor of another shape
// appears: over an invalid spot the game shows the same hand greyed out
// ("unable to cast"), which has the same shape. A fully transparent cursor is
// WowPad's own blank one: the addon sets it while you aim with a window open,
// meaning "menu: leave the buttons alone" (it never sets it while aiming in the world).
volatile LONG  g_aiming    = 0;
volatile DWORD g_aimAt     = 0;   // last cast cursor seen (safety: aiming expires after 30 s)
volatile LONG  g_aimShape  = 0;   // visible pixels of the cast cursor
volatile DWORD g_blankAt   = 0;   // last time the addon's blank cursor was set
volatile LONG  g_curImage  = -1;  // catalogue number of the last cursor (for the log)

// Debug aid: catalogue of distinct cursor images, each logged once as
// "Cursor image #n" (helps tune the detection if another client's cursors
// look different).
uint32_t g_imgHash[64];
int      g_imgCount = 0;

bool HasMark(HCURSOR c, long* visible) {
    ICONINFO ii;
    *visible = -1;
    if (!GetIconInfo(c, &ii)) return false;
    bool mark = false;
    if (ii.hbmColor) {
        BITMAP bm;
        if (GetObjectW(ii.hbmColor, sizeof(bm), &bm) && bm.bmWidth >= 8 && bm.bmWidth <= 256 &&
            bm.bmHeight >= 8 && bm.bmHeight <= 256) {
            int w = bm.bmWidth, h = bm.bmHeight;
            BITMAPINFO bi = {};
            bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
            bi.bmiHeader.biWidth = w;
            bi.bmiHeader.biHeight = -h;          // top-down
            bi.bmiHeader.biPlanes = 1;
            bi.bmiHeader.biBitCount = 32;
            bi.bmiHeader.biCompression = BI_RGB;
            static BYTE buf[256 * 256 * 4];
            HDC dc = GetDC(nullptr);
            if (GetDIBits(dc, ii.hbmColor, 0, h, buf, &bi, DIB_RGB_COLORS) == h) {
                unsigned long sr = 0, sg = 0, sb = 0, n = 0;
                uint32_t hv = 2166136261u;
                for (int k = 0; k < w * h; ++k) {
                    const BYTE* p = buf + k * 4;
                    for (int j = 0; j < 4; ++j) { hv ^= p[j]; hv *= 16777619u; }
                    if (p[3] > 128) { sb += p[0]; sg += p[1]; sr += p[2]; ++n; }
                }
                unsigned long total = (unsigned long)(w * h);
                *visible = (long)(n * 1024 / total);   // per 32x32
                unsigned long r = n ? sr / n : 0, g = n ? sg / n : 0, b = n ? sb / n : 0;
                // Cast cursor: 50-80 % visible, blue clearly above red, above green.
                mark = n * 10 >= total * 5 && n * 10 <= total * 8 && b >= r + 40 && b >= g + 10 && b >= 0x60;
                int idx = -1;
                for (int i = 0; i < g_imgCount; ++i) if (g_imgHash[i] == hv) { idx = i; break; }
                if (idx < 0 && g_imgCount < 64) idx = g_imgCount;
                g_curImage = idx;
                if (idx == g_imgCount && g_imgCount < 64) {
                    g_imgHash[g_imgCount++] = hv;
                    Log_Write("Cursor image #%d: %dx%d, %lu visible, average %02lx%02lx%02lx%s",
                              g_imgCount - 1, w, h, n, r, g, b, mark ? " = cast cursor (aiming)" : "");
                }
            }
            ReleaseDC(nullptr, dc);
        }
        DeleteObject(ii.hbmColor);
    }
    if (ii.hbmMask) DeleteObject(ii.hbmMask);
    return mark;
}

void Classify(HCURSOR c) {
    if (!c) return;                        // hidden: tells us nothing
    long n;
    bool cast = HasMark(c, &n);
    if (n < 0) return;                     // couldn't read it
    if (n == 0) { DWORD t = GetTickCount(); g_blankAt = t ? t : 1; return; }   // WowPad's blank
    if (cast) {
        if (!g_aiming) Log_Write("Aiming: cast cursor up");
        g_aiming = 1;
        g_aimShape = n;
        { DWORD t = GetTickCount(); g_aimAt = t ? t : 1; }
        return;
    }
    if (g_aiming) {
        long d = n - g_aimShape;
        if (d < 0) d = -d;
        if (d * 10 <= g_aimShape) return;  // same hand, greyed out: still aiming
        g_aiming = 0;
        Log_Write("Aiming: over (cursor image #%ld)", (long)g_curImage);
    }
}

HCURSOR WINAPI HookedSetCursor(HCURSOR c) {
    g_wanted = c;
    Classify(c);
    return g_realSetCursor(g_hide ? nullptr : c);
}

int PatchModule(HMODULE mod) {
    auto* base = (BYTE*)mod;
    auto* dos = (IMAGE_DOS_HEADER*)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return 0;
    auto* nt = (IMAGE_NT_HEADERS*)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return 0;
    auto& dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (!dir.VirtualAddress) return 0;
    int patched = 0;
    for (auto* imp = (IMAGE_IMPORT_DESCRIPTOR*)(base + dir.VirtualAddress); imp->Name; ++imp) {
        if (_stricmp((char*)(base + imp->Name), "user32.dll") != 0) continue;
        auto* thunk = (IMAGE_THUNK_DATA*)(base + imp->FirstThunk);
        for (; thunk->u1.Function; ++thunk) {
            if ((void*)thunk->u1.Function != (void*)g_realSetCursor) continue;
            DWORD old;
            if (VirtualProtect(&thunk->u1.Function, sizeof(void*), PAGE_READWRITE, &old)) {
                thunk->u1.Function = (ULONG_PTR)HookedSetCursor;
                VirtualProtect(&thunk->u1.Function, sizeof(void*), old, &old);
                ++patched;
            }
        }
    }
    return patched;
}

void PatchAllModules() {
    g_realSetCursor = (SetCursor_t)GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetCursor");
    if (!g_realSetCursor) return;
    HMODULE self = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       (LPCWSTR)(void*)&PatchAllModules, &self);
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, GetCurrentProcessId());
    if (snap == INVALID_HANDLE_VALUE) return;
    MODULEENTRY32W me = {};
    me.dwSize = sizeof(me);
    int total = 0;
    for (BOOL ok = Module32FirstW(snap, &me); ok; ok = Module32NextW(snap, &me)) {
        if (me.hModule == self) continue;
        int n = PatchModule(me.hModule);
        if (n) {
            char name[MAX_PATH];
            WideCharToMultiByte(CP_UTF8, 0, me.szModule, -1, name, sizeof(name), nullptr, nullptr);
            Log_Write("Cursor hide: hooked SetCursor in %s", name);
            total += n;
        }
    }
    CloseHandle(snap);
    if (!total) Log_Write("Cursor hide: no module imports SetCursor directly (subclass only)");
}

LRESULT CALLBACK Proc(HWND h, UINT msg, WPARAM wp, LPARAM lp) {
    bool hide = g_hide != 0;
    switch (msg) {
    case WM_WOWPAD_CURSOR:
        if (hide) { SetCursor(nullptr); SetTimer(h, TIMER_ID, TIMER_MS, nullptr); }  // backup if a call bypasses the hook
        else {
            // Showing again: do what a real mouse touch does. Put back the
            // cursor the game wanted and let it re-apply its own (WM_SETCURSOR).
            KillTimer(h, TIMER_ID);
            if (g_wanted) SetCursor(g_wanted);
            POINT p; GetCursorPos(&p);
            CallWindowProcW(g_origProc, h, WM_SETCURSOR, (WPARAM)h, MAKELPARAM(HTCLIENT, WM_MOUSEMOVE));
            ScreenToClient(h, &p);
            PostMessageW(h, WM_MOUSEMOVE, 0, MAKELPARAM(p.x, p.y));
        }
        return 0;
    case WM_TIMER:
        if (wp == TIMER_ID) {
            if (hide) SetCursor(nullptr); else KillTimer(h, TIMER_ID);
            return 0;
        }
        break;
    case WM_SETCURSOR:
        if (hide && LOWORD(lp) == HTCLIENT) { SetCursor(nullptr); return TRUE; }
        break;
    }
    return CallWindowProcW(g_origProc, h, msg, wp, lp);
}
} // namespace

void CursorHide_Install(HWND hwnd) {
    if (!hwnd || hwnd == g_hwnd) return;
    WNDPROC orig = (WNDPROC)SetWindowLongPtrW(hwnd, GWLP_WNDPROC, (LONG_PTR)Proc);
    if (!orig) { Log_Write("Cursor hide: could not subclass the game window (%lu)", GetLastError()); return; }
    g_origProc = orig;
    g_hwnd = hwnd;
    Log_Write("Cursor hide: installed");
    PatchAllModules();
}

bool CursorHide_IsOn() { return g_hide != 0; }

// A spell is waiting for its location: the game's cursor is the cast cursor.
// (The game sets a new cursor as soon as targeting ends, placed or not.)
bool CursorHide_GroundTargeting() {
    if (g_aiming && GetTickCount() - g_aimAt > 30000) g_aiming = 0;
    return g_aiming != 0;
}

// The addon set its blank cursor in the last 300 ms (a window is open).
bool CursorHide_MenuVeto() {
    DWORD at = g_blankAt;
    return at && GetTickCount() - at < 300;
}

void CursorHide_Set(bool hide) {
    if (InterlockedExchange(&g_hide, hide ? 1 : 0) == (hide ? 1 : 0)) return;
    if (g_hwnd) PostMessageW(g_hwnd, WM_WOWPAD_CURSOR, 0, 0);
}
