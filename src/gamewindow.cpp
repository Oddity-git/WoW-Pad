#include "gamewindow.h"
#include "log.h"

namespace {
struct FindCtx { DWORD pid; HWND best; LONG area; };

BOOL CALLBACK EnumCb(HWND h, LPARAM lp) {
    auto* f = (FindCtx*)lp;
    DWORD pid = 0;
    GetWindowThreadProcessId(h, &pid);
    if (pid != f->pid || !IsWindowVisible(h) || GetWindow(h, GW_OWNER)) return TRUE;
    RECT r;
    if (!GetClientRect(h, &r)) return TRUE;
    LONG area = (r.right - r.left) * (r.bottom - r.top);
    if (area > f->area) { f->area = area; f->best = h; }
    return TRUE;
}

HWND  g_cached  = nullptr;
DWORD g_lastTry = 0;
bool  g_tried   = false;
}

HWND GameWindow_Get() {
    if (g_cached && IsWindow(g_cached)) return g_cached;
    if (g_cached) { Log_Write("Game window lost"); g_cached = nullptr; }

    DWORD now = GetTickCount();
    if (g_tried && now - g_lastTry < 1000) return nullptr;
    g_tried = true;
    g_lastTry = now;

    FindCtx f = { GetCurrentProcessId(), nullptr, 0 };
    EnumWindows(EnumCb, (LPARAM)&f);
    if (f.best && f.area > 0) {
        g_cached = f.best;
        char cls[128] = {};
        GetClassNameA(g_cached, cls, sizeof(cls)); // no message round-trip, safe off-thread
        RECT r; GetClientRect(g_cached, &r);
        Log_Write("Game window found: class '%s', client %ldx%ld", cls, r.right, r.bottom);
    }
    return g_cached;
}

bool GameWindow_IsForeground() {
    HWND h = GameWindow_Get();
    return h && GetForegroundWindow() == h;
}

bool GameWindow_ClientRectScreen(RECT* out) {
    HWND h = GameWindow_Get();
    if (!h || !GetClientRect(h, out)) return false;
    POINT tl = { out->left, out->top }, br = { out->right, out->bottom };
    ClientToScreen(h, &tl);
    ClientToScreen(h, &br);
    *out = { tl.x, tl.y, br.x, br.y };
    return true;
}
