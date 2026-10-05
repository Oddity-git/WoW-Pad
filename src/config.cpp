// config.cpp - reads wowpad.ini and logs the values in use.
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include "config.h"
#include "names.h"
#include "log.h"

static Config g_cfg;
static wchar_t g_ini[MAX_PATH + 16];

static float ReadFloat(const wchar_t* sec, const wchar_t* key, float def, float lo, float hi) {
    wchar_t buf[64];
    GetPrivateProfileStringW(sec, key, L"", buf, 64, g_ini);
    if (!buf[0]) return def;
    float v = (float)wcstod(buf, nullptr);
    return v < lo ? lo : (v > hi ? hi : v);
}

static bool ReadBool(const wchar_t* sec, const wchar_t* key, bool def) {
    return GetPrivateProfileIntW(sec, key, def ? 1 : 0, g_ini) != 0;
}

static BYTE ReadKey(const wchar_t* sec, const wchar_t* key, BYTE def) {
    wchar_t buf[32];
    GetPrivateProfileStringW(sec, key, L"", buf, 32, g_ini);
    if (!buf[0]) return def;
    BYTE vk = VkFromName(buf);
    if (!vk) Log_Write("Config: [%ls] %ls=%ls is not a known key, keeping default", sec, key, buf);
    return vk ? vk : def;
}

static uint16_t ReadPadButton(const wchar_t* sec, const wchar_t* key, uint16_t def) {
    wchar_t buf[32];
    GetPrivateProfileStringW(sec, key, L"", buf, 32, g_ini);
    if (!buf[0]) return def;
    if (_wcsicmp(buf, L"None") == 0) return 0;
    uint16_t b = PadButtonFromName(buf);
    if (!b) Log_Write("Config: [%ls] %ls=%ls is not a known pad button, keeping default", sec, key, buf);
    return b ? b : def;
}

void Config_Load() {
    _snwprintf(g_ini, MAX_PATH + 16, L"%lswowpad.ini", GameDirW());
    g_ini[MAX_PATH + 15] = 0;

    bool exists = GetFileAttributesW(g_ini) != INVALID_FILE_ATTRIBUTES;
    Config c;
    if (exists) {
        int poll = (int)GetPrivateProfileIntW(L"Input", L"PollMs", c.pollMs, g_ini);
        c.pollMs           = poll < 1 ? 1 : (poll > 100 ? 100 : poll);
        c.stickDeadzone    = ReadFloat(L"Input", L"StickDeadzone", c.stickDeadzone, 0.0f, 0.9f);
        c.triggerThreshold = ReadFloat(L"Input", L"TriggerThreshold", c.triggerThreshold, 0.0f, 0.9f);

        wchar_t mode[32];
        GetPrivateProfileStringW(L"Inject", L"Mode", L"SendInput", mode, 32, g_ini);
        c.injectMode = _wcsicmp(mode, L"PostMessage") == 0 ? 1 : 0;

        c.keyForward    = ReadKey(L"Move", L"Forward", c.keyForward);
        c.keyBack       = ReadKey(L"Move", L"Back", c.keyBack);
        c.keyLeft       = ReadKey(L"Move", L"Left", c.keyLeft);
        c.keyRight      = ReadKey(L"Move", L"Right", c.keyRight);
        c.movePressAt   = ReadFloat(L"Move", L"PressAt", c.movePressAt, 0.05f, 0.95f);
        c.moveReleaseAt = ReadFloat(L"Move", L"ReleaseAt", c.moveReleaseAt, 0.01f, c.movePressAt);
        c.walkBelow     = ReadFloat(L"Move", L"WalkBelow", c.walkBelow, 0.1f, 0.95f);
        c.runAbove      = ReadFloat(L"Move", L"RunAbove", c.runAbove, c.walkBelow, 1.0f);
        c.walkDelayMs   = (int)GetPrivateProfileIntW(L"Move", L"WalkDelayMs", c.walkDelayMs, g_ini);

        c.cursorSpeed     = ReadFloat(L"Cursor", L"Speed", c.cursorSpeed, 50.0f, 10000.0f);
        c.cursorCurve     = ReadFloat(L"Cursor", L"Curve", c.cursorCurve, 1.0f, 4.0f);
        c.precisionButton = ReadPadButton(L"Cursor", L"PrecisionButton", c.precisionButton);
        c.precisionScale  = ReadFloat(L"Cursor", L"PrecisionScale", c.precisionScale, 0.05f, 1.0f);
        c.clampToWindow   = ReadBool(L"Cursor", L"ClampToWindow", c.clampToWindow);
        c.pointerWarp     = ReadBool(L"Cursor", L"PointerWarp", c.pointerWarp);

        c.cameraSpeed   = ReadFloat(L"Camera", L"Speed", c.cameraSpeed, 50.0f, 10000.0f);
        c.cameraInvertY = ReadBool(L"Camera", L"InvertY", c.cameraInvertY);
        c.zoomSpeed     = ReadFloat(L"Camera", L"ZoomSpeed", c.zoomSpeed, 1.0f, 40.0f);
        c.smoothMs      = ReadFloat(L"Camera", L"SmoothMs", c.smoothMs, 10.0f, 300.0f);
        c.peekDelayMs   = (int)GetPrivateProfileIntW(L"Camera", L"PeekDelayMs", c.peekDelayMs, g_ini);
        c.crosshairY    = (int)GetPrivateProfileIntW(L"Camera", L"CrosshairY", c.crosshairY, g_ini);

        c.clickPressAt   = ReadFloat(L"Click", L"PressAt", c.clickPressAt, 0.05f, 0.95f);
        c.clickReleaseAt = ReadFloat(L"Click", L"ReleaseAt", c.clickReleaseAt, 0.01f, c.clickPressAt);

        c.mouseTravel = (long)GetPrivateProfileIntW(L"Mode", L"MouseTravel", c.mouseTravel, g_ini);
        if (c.mouseTravel < 5) c.mouseTravel = 5;
        c.backHoldMs  = (int)GetPrivateProfileIntW(L"Mode", L"BackHoldMs", c.backHoldMs, g_ini);
        if (c.backHoldMs < 150) c.backHoldMs = 150;

        c.logStickStep = ReadFloat(L"Log", L"StickStep", c.logStickStep, 0.01f, 1.0f);
        c.logSticks    = ReadBool(L"Log", L"Sticks", c.logSticks);
        c.logButtons   = ReadBool(L"Log", L"Buttons", c.logButtons);
    }
    g_cfg = c;
    Log_Write("Config: %s", exists ? "wowpad.ini" : "defaults, no wowpad.ini");
    Log_Write("  Input  PollMs=%d StickDeadzone=%.2f TriggerThreshold=%.2f",
              c.pollMs, c.stickDeadzone, c.triggerThreshold);
    Log_Write("  Move   keys F/B/L/R=0x%02X/0x%02X/0x%02X/0x%02X PressAt=%.2f ReleaseAt=%.2f",
              c.keyForward, c.keyBack, c.keyLeft, c.keyRight, c.movePressAt, c.moveReleaseAt);
    Log_Write("  Cursor Speed=%.0f Curve=%.2f PrecisionBtn=0x%04X x%.2f Clamp=%d",
              c.cursorSpeed, c.cursorCurve, c.precisionButton, c.precisionScale, c.clampToWindow);
    Log_Write("  Camera Speed=%.0f InvertY=%d  Trigger PressAt=%.2f ReleaseAt=%.2f",
              c.cameraSpeed, c.cameraInvertY, c.clickPressAt, c.clickReleaseAt);
    Log_Write("  Mode   MouseTravel=%ld BackHoldMs=%d", c.mouseTravel, c.backHoldMs);
}

const Config& Config_Get() { return g_cfg; }
