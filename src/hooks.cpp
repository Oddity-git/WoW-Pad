#include <windows.h>
#include <stdlib.h>
#include "hooks.h"
#include "inject.h"
#include "log.h"

namespace {
volatile LONG g_realPress  = 0;
volatile LONG g_realTravel = 0;
POINT g_lastPt = { LONG_MIN, LONG_MIN };

bool IsOurs(ULONG_PTR extra, bool injected) {
    return extra == WOWPAD_INPUT_TAG || injected;
}

LRESULT CALLBACK KbProc(int code, WPARAM wp, LPARAM lp) {
    if (code == HC_ACTION && (wp == WM_KEYDOWN || wp == WM_SYSKEYDOWN)) {
        auto* k = (KBDLLHOOKSTRUCT*)lp;
        if (!IsOurs(k->dwExtraInfo, k->flags & LLKHF_INJECTED)) InterlockedExchange(&g_realPress, 1);
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

LRESULT CALLBACK MsProc(int code, WPARAM wp, LPARAM lp) {
    if (code == HC_ACTION) {
        auto* m = (MSLLHOOKSTRUCT*)lp;
        if (!IsOurs(m->dwExtraInfo, m->flags & LLMHF_INJECTED)) {
            switch (wp) {
            case WM_MOUSEMOVE:
                if (g_lastPt.x != LONG_MIN)
                    InterlockedExchangeAdd(&g_realTravel, labs(m->pt.x - g_lastPt.x) + labs(m->pt.y - g_lastPt.y));
                g_lastPt = m->pt;
                break;
            case WM_LBUTTONDOWN: case WM_RBUTTONDOWN: case WM_MBUTTONDOWN:
            case WM_XBUTTONDOWN: case WM_MOUSEWHEEL: case WM_MOUSEHWHEEL:
                InterlockedExchange(&g_realPress, 1);
                break;
            }
        } else if (wp == WM_MOUSEMOVE) {
            g_lastPt = m->pt; // our motion moves the pointer too; don't count it later
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

DWORD WINAPI HookThread(LPVOID) {
    HMODULE self = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       (LPCWSTR)(void*)&KbProc, &self);
    HHOOK kb = SetWindowsHookExW(WH_KEYBOARD_LL, KbProc, self, 0);
    HHOOK ms = SetWindowsHookExW(WH_MOUSE_LL, MsProc, self, 0);
    Log_Write("HOOK keyboard LL %s, mouse LL %s",
              kb ? "installed" : "FAILED", ms ? "installed" : "FAILED");
    if (!kb && !ms) return 0;
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return 0;
}
}

void Hooks_Start() {
    HANDLE t = CreateThread(nullptr, 0, HookThread, nullptr, 0, nullptr);
    if (t) CloseHandle(t);
}

bool Hooks_TakeRealPress()       { return InterlockedExchange(&g_realPress, 0) != 0; }
long Hooks_TakeRealMouseTravel() { return InterlockedExchange(&g_realTravel, 0); }
