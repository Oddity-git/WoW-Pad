#include "cursorhide.h"
#include "log.h"
#include <tlhelp32.h>
#include <string.h>

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

HCURSOR WINAPI HookedSetCursor(HCURSOR c) {
    g_wanted = c;
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
}

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

void CursorHide_Set(bool hide) {
    if (InterlockedExchange(&g_hide, hide ? 1 : 0) == (hide ? 1 : 0)) return;
    if (g_hwnd) PostMessageW(g_hwnd, WM_WOWPAD_CURSOR, 0, 0);
}
