// worker.cpp - the background thread spawned from DllMain.
// Polls the controller, logs changes, and drives the controller-mode mapper.
#include <windows.h>
#include <math.h>
#include "addonsettings.h"
#include "controller.h"
#include "config.h"
#include "inject.h"
#include "mapper.h"
#include "names.h"
#include "hooks.h"
#include "log.h"
#include "worker.h"

#ifndef WOWPAD_VERSION
#define WOWPAD_VERSION "dev"
#endif

static volatile LONG g_stop = 0;

void Worker_RequestStop() { InterlockedExchange(&g_stop, 1); }

// Last LOGGED analog values (not last polled), so slow drifts still get logged
// once they accumulate past the step.
struct LoggedAnalog { float lx, ly, rx, ry, lt, rt; };

static bool Moved(float now, float logged, float step) {
    if ((now == 0.0f) != (logged == 0.0f)) return true; // entered/left deadzone
    return fabsf(now - logged) >= step;
}

static void LogChanges(const ControllerState& s, uint16_t prevButtons, LoggedAnalog& la, const Config& c) {
    if (c.logButtons) {
        uint16_t changed = s.buttons ^ prevButtons;
        for (int i = 0; i < kPadButtonNameCount; ++i) {
            const PadButtonName& b = kPadButtonNames[i];
            if (changed & b.bit)
                Log_Write("BTN %-9s %s", b.name, (s.buttons & b.bit) ? "down" : "up");
        }
    }
    if (!c.logSticks) return;
    float step = c.logStickStep;
    if (Moved(s.lx, la.lx, step) || Moved(s.ly, la.ly, step)) {
        Log_Write("LS  x=%+.2f y=%+.2f", s.lx, s.ly);
        la.lx = s.lx; la.ly = s.ly;
    }
    if (Moved(s.rx, la.rx, step) || Moved(s.ry, la.ry, step)) {
        Log_Write("RS  x=%+.2f y=%+.2f", s.rx, s.ry);
        la.rx = s.rx; la.ry = s.ry;
    }
    if (Moved(s.lt, la.lt, step)) { Log_Write("LT  %.2f", s.lt); la.lt = s.lt; }
    if (Moved(s.rt, la.rt, step)) { Log_Write("RT  %.2f", s.rt); la.rt = s.rt; }
}

DWORD WINAPI Worker_Main(LPVOID) {
    char exe[MAX_PATH * 3] = {};
    wchar_t exeW[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exeW, MAX_PATH);
    WideCharToMultiByte(CP_UTF8, 0, exeW, -1, exe, sizeof(exe), nullptr, nullptr);
    Log_Write("wowpad %s loaded into %s (pid %lu)", WOWPAD_VERSION, exe, GetCurrentProcessId());

    Config_Load();
    const Config& cfg = Config_Get();
    Inject_SetMode((InjectMode)cfg.injectMode);
    Hooks_Start();
    if (!Controller_Init()) {
        Log_Write("No controller backend available; worker exiting (game is unaffected).");
        return 0;
    }

    DeadzoneConfig dz = { cfg.stickDeadzone, cfg.triggerThreshold };

    bool            wasConnected = false;
    ControllerState raw, s;
    uint16_t        prevButtons = 0;
    LoggedAnalog    logged = {};

    LARGE_INTEGER freq, last, now;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last);

    Log_Write("Polling every %d ms. Waiting for a controller...", cfg.pollMs);
    while (!g_stop) {
        GetControllerState(&raw);
        ApplyDeadzones(raw, dz, &s);

        QueryPerformanceCounter(&now);
        double dt = (double)(now.QuadPart - last.QuadPart) / (double)freq.QuadPart;
        last = now;
        if (dt > 0.1) dt = 0.1; // after a stall, don't fling the cursor

        if (s.connected != wasConnected) {
            if (s.connected)
                Log_Write("Controller connected (%s slot %d)", Controller_BackendName(), s.deviceIndex);
            else
                Log_Write("Controller disconnected");
            wasConnected = s.connected;
            prevButtons  = 0;
            logged       = {};
        }
        if (s.connected) {
            LogChanges(s, prevButtons, logged, cfg);
            prevButtons = s.buttons;
        }
        AddonSettings_Poll();
        Mapper_Update(s, dt);
        Sleep((DWORD)cfg.pollMs);
    }
    Mapper_Reset();
    Controller_Shutdown();
    return 0;
}
