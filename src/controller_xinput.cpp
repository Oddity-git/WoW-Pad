// controller_xinput.cpp - XInput backend for GetControllerState().
//
// XInput is loaded dynamically so the DLL has no static import on it and we can
// log exactly which xinput DLL Wine gave us.
#include <windows.h>
#include <xinput.h>
#include "controller.h"
#include "log.h"

typedef DWORD(WINAPI* XInputGetState_t)(DWORD, XINPUT_STATE*);

static HMODULE          g_xinput     = nullptr;
static XInputGetState_t g_getState   = nullptr;
static const char*      g_backend    = "none";
static int              g_slot       = -1;
static DWORD            g_lastScanMs = 0;
static bool             g_scannedOnce = false;

// Rescanning empty slots is slow on real Windows, so only do it once a second
// while nothing is connected.
static const DWORD kRescanIntervalMs = 1000;

bool Controller_Init() {
    static const char* candidates[] = { "xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll" };
    for (const char* name : candidates) {
        HMODULE h = LoadLibraryA(name);
        if (!h) continue;
        auto fn = (XInputGetState_t)GetProcAddress(h, "XInputGetState");
        if (!fn) { FreeLibrary(h); continue; }
        g_xinput   = h;
        g_getState = fn;
        g_backend  = name;
        Log_Write("XInput backend: loaded %s", name);
        return true;
    }
    Log_Write("XInput backend: no xinput DLL could be loaded (tried 1_4, 1_3, 9_1_0)");
    return false;
}

const char* Controller_BackendName() { return g_backend; }

static float NormStick(SHORT v) { return v < 0 ? v / 32768.0f : v / 32767.0f; }

static void Fill(const XINPUT_STATE& xs, int slot, ControllerState* out) {
    const XINPUT_GAMEPAD& g = xs.Gamepad;
    out->connected   = true;
    out->deviceIndex = slot;
    out->buttons     = g.wButtons;
    out->lx = NormStick(g.sThumbLX);
    out->ly = NormStick(g.sThumbLY);
    out->rx = NormStick(g.sThumbRX);
    out->ry = NormStick(g.sThumbRY);
    out->lt = g.bLeftTrigger / 255.0f;
    out->rt = g.bRightTrigger / 255.0f;
}

bool GetControllerState(ControllerState* out) {
    *out = ControllerState{};
    if (!g_getState) return false;

    XINPUT_STATE xs;
    if (g_slot >= 0) {
        ZeroMemory(&xs, sizeof(xs));
        if (g_getState((DWORD)g_slot, &xs) == ERROR_SUCCESS) {
            Fill(xs, g_slot, out);
            return true;
        }
        g_slot = -1; // disconnected; fall through to a (rate-limited) rescan
    }

    DWORD now = GetTickCount();
    if (g_scannedOnce && now - g_lastScanMs < kRescanIntervalMs) return false;
    g_scannedOnce = true;
    g_lastScanMs  = now;

    for (DWORD i = 0; i < XUSER_MAX_COUNT; ++i) {
        ZeroMemory(&xs, sizeof(xs));
        if (g_getState(i, &xs) == ERROR_SUCCESS) {
            g_slot = (int)i;
            Fill(xs, g_slot, out);
            return true;
        }
    }
    return false;
}

void Controller_Shutdown() {
    // Intentionally do not FreeLibrary: may be called during process teardown.
    g_getState = nullptr;
}
