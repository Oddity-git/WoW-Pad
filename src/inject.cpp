// inject.cpp - synthetic input via SendInput (default) or PostMessage.
//
// SendInput reaches the game under Proton, including relative motion during
// mouselook. PostMessage mode ([Inject] Mode=PostMessage) is a fallback:
// keys/clicks are posted to the game window and motion uses SetCursorPos.
#include "inject.h"
#include "gamewindow.h"
#include "log.h"

static InjectMode g_mode = INJECT_SENDINPUT;
static bool       g_keys[256];
static bool       g_btn[2];
static bool       g_loggedFail = false;

void Inject_SetMode(InjectMode m) {
    g_mode = m;
    Log_Write("Injection mode: %s", m == INJECT_SENDINPUT ? "SendInput" : "PostMessage");
}

static void Send(INPUT* in) {
    if (SendInput(1, in, sizeof(INPUT)) != 1 && !g_loggedFail) {
        g_loggedFail = true;
        Log_Write("SendInput failed (error %lu). Try [Inject] Mode=PostMessage", GetLastError());
    }
}

static bool IsExtendedVk(BYTE vk) {
    switch (vk) {
    case VK_LEFT: case VK_RIGHT: case VK_UP: case VK_DOWN:
    case VK_INSERT: case VK_DELETE: case VK_HOME: case VK_END:
    case VK_PRIOR: case VK_NEXT: case VK_DIVIDE: case VK_RCONTROL: case VK_RMENU:
        return true;
    }
    return false;
}

void Inject_Key(BYTE vk, bool down) {
    if (!vk || g_keys[vk] == down) return;
    g_keys[vk] = down;
    UINT sc  = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC);
    bool ext = IsExtendedVk(vk);

    if (g_mode == INJECT_SENDINPUT) {
        INPUT in = {};
        in.type           = INPUT_KEYBOARD;
        in.ki.wVk         = vk;
        in.ki.wScan       = (WORD)sc;
        in.ki.dwFlags     = (down ? 0 : KEYEVENTF_KEYUP) | (ext ? KEYEVENTF_EXTENDEDKEY : 0);
        in.ki.dwExtraInfo = WOWPAD_INPUT_TAG;
        Send(&in);
    } else {
        HWND h = GameWindow_Get();
        if (!h) return;
        LPARAM lp = 1 | ((LPARAM)(sc & 0xFF) << 16) | (ext ? (1L << 24) : 0);
        if (!down) lp |= (LPARAM)0xC0000000u; // previous-state + transition bits
        PostMessageW(h, down ? WM_KEYDOWN : WM_KEYUP, vk, lp);
    }
}

void Inject_MouseButton(MouseBtn b, bool down) {
    if (g_btn[b] == down) return;
    g_btn[b] = down;

    if (g_mode == INJECT_SENDINPUT) {
        INPUT in = {};
        in.type           = INPUT_MOUSE;
        in.mi.dwFlags     = b == MOUSE_LEFT ? (down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP)
                                            : (down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP);
        in.mi.dwExtraInfo = WOWPAD_INPUT_TAG;
        Send(&in);
    } else {
        HWND h = GameWindow_Get();
        if (!h) return;
        POINT p; GetCursorPos(&p); ScreenToClient(h, &p);
        WPARAM mk = (g_btn[MOUSE_LEFT] ? MK_LBUTTON : 0) | (g_btn[MOUSE_RIGHT] ? MK_RBUTTON : 0);
        UINT msg = b == MOUSE_LEFT ? (down ? WM_LBUTTONDOWN : WM_LBUTTONUP)
                                   : (down ? WM_RBUTTONDOWN : WM_RBUTTONUP);
        PostMessageW(h, msg, mk, MAKELPARAM(p.x, p.y));
    }
}

void Inject_MouseMove(int dx, int dy) {
    if (!dx && !dy) return;
    if (g_mode == INJECT_SENDINPUT) {
        INPUT in = {};
        in.type           = INPUT_MOUSE;
        in.mi.dx          = dx;
        in.mi.dy          = dy;
        in.mi.dwFlags     = MOUSEEVENTF_MOVE;
        in.mi.dwExtraInfo = WOWPAD_INPUT_TAG;
        Send(&in);
    } else {
        POINT p;
        GetCursorPos(&p);
        SetCursorPos(p.x + dx, p.y + dy);
    }
}

void Inject_MouseWheel(int notches) {
    if (!notches) return;
    if (g_mode == INJECT_SENDINPUT) {
        INPUT in = {};
        in.type           = INPUT_MOUSE;
        in.mi.mouseData   = (DWORD)(notches * WHEEL_DELTA);
        in.mi.dwFlags     = MOUSEEVENTF_WHEEL;
        in.mi.dwExtraInfo = WOWPAD_INPUT_TAG;
        Send(&in);
    } else {
        HWND h = GameWindow_Get();
        if (!h) return;
        POINT p; GetCursorPos(&p);
        PostMessageW(h, WM_MOUSEWHEEL, MAKEWPARAM(0, (short)(notches * WHEEL_DELTA)), MAKELPARAM(p.x, p.y));
    }
}

void Inject_ReleaseAll() {
    for (int vk = 0; vk < 256; ++vk)
        if (g_keys[vk]) Inject_Key((BYTE)vk, false);
    Inject_MouseButton(MOUSE_LEFT, false);
    Inject_MouseButton(MOUSE_RIGHT, false);
}
