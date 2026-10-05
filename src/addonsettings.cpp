// addonsettings.cpp - watches the addon's SavedVariables file for its options.
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "addonsettings.h"
#include "log.h"

namespace {
AddonSettings g_s;
CRITICAL_SECTION g_lock;
FILETIME      g_lastWrite = {};
wchar_t       g_lastPath[MAX_PATH * 2] = {};

// Newest WTF\Account\*\SavedVariables\WowPad.lua (the account last played).
bool FindNewest(wchar_t* out, size_t outLen, FILETIME* ft) {
    wchar_t pat[MAX_PATH * 2];
    _snwprintf(pat, MAX_PATH * 2, L"%lsWTF\\Account\\*", GameDirW());
    pat[MAX_PATH * 2 - 1] = 0;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(pat, &fd);
    if (h == INVALID_HANDLE_VALUE) return false;
    bool found = false;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || fd.cFileName[0] == L'.') continue;
        wchar_t p[MAX_PATH * 2];
        _snwprintf(p, MAX_PATH * 2, L"%lsWTF\\Account\\%ls\\SavedVariables\\WowPad.lua", GameDirW(), fd.cFileName);
        p[MAX_PATH * 2 - 1] = 0;
        WIN32_FILE_ATTRIBUTE_DATA a;
        if (!GetFileAttributesExW(p, GetFileExInfoStandard, &a)) continue;
        if (!found || CompareFileTime(&a.ftLastWriteTime, ft) > 0) {
            *ft = a.ftLastWriteTime;
            wcsncpy(out, p, outLen - 1);
            out[outLen - 1] = 0;
            found = true;
        }
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return found;
}

// Finds `["key"] = <value>` and returns the text after '='.
const char* FindValue(const char* text, const char* key) {
    char pat[64];
    snprintf(pat, sizeof(pat), "[\"%s\"]", key);
    const char* p = strstr(text, pat);
    if (!p) return nullptr;
    p = strchr(p + strlen(pat), '=');
    if (!p) return nullptr;
    ++p;
    while (*p == ' ' || *p == '\t') ++p;
    return p;
}

float ReadNum(const char* text, const char* key, float def, float lo, float hi) {
    const char* v = FindValue(text, key);
    if (!v) return def;
    char* end;
    float f = strtof(v, &end);
    if (end == v) return def;
    return f < lo ? lo : (f > hi ? hi : f);
}

int ReadBool(const char* text, const char* key) {
    const char* v = FindValue(text, key);
    if (!v) return -1;
    if (!strncmp(v, "true", 4)) return 1;
    if (!strncmp(v, "false", 5)) return 0;
    return -1;
}

void Load(const wchar_t* path) {
    HANDLE f = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           nullptr, OPEN_EXISTING, 0, nullptr);
    if (f == INVALID_HANDLE_VALUE) return;
    DWORD size = GetFileSize(f, nullptr);
    if (size == INVALID_FILE_SIZE || size > 4 * 1024 * 1024) { CloseHandle(f); return; }
    char* buf = (char*)malloc(size + 1);
    DWORD got = 0;
    if (buf && ReadFile(f, buf, size, &got, nullptr)) {
        buf[got] = 0;
        AddonSettings s;
        s.camScale    = ReadNum(buf, "wpCamSens", 1.0f, 0.05f, 3.0f);
        s.ptrScale    = ReadNum(buf, "wpPtrSens", 1.0f, 0.05f, 3.0f);
        s.zoomScale   = ReadNum(buf, "wpZoomSens", 1.0f, 0.05f, 3.0f);
        s.invertY     = ReadBool(buf, "wpInvertY");
        s.walkRun     = ReadBool(buf, "wpWalkRun") == 1;
        s.camSmooth   = ReadBool(buf, "wpCamSmooth") == 1;
        s.bumperFlick = ReadBool(buf, "wpBumperFlick") == 1;   // default off
        s.ringSlot    = (int)ReadNum(buf, "wpRingSlot", 0.0f, 0.0f, 38.0f);
        s.peekDelayMs = (int)ReadNum(buf, "wpPeekDelay", 0.0f, 0.0f, 2000.0f);
        if (s.peekDelayMs && s.peekDelayMs < 50) s.peekDelayMs = 50;
        EnterCriticalSection(&g_lock);
        g_s = s;
        LeaveCriticalSection(&g_lock);
        Log_Write("Addon settings: camera x%.2f, pointer x%.2f, zoom x%.2f, invert Y %s, peek delay %s",
                  s.camScale, s.ptrScale, s.zoomScale, s.invertY < 0 ? "(ini)" : (s.invertY ? "on" : "off"),
                  s.peekDelayMs ? "set" : "(ini)");
        if (s.peekDelayMs) Log_Write("  peek delay %d ms", s.peekDelayMs);
        Log_Write("  walk/run on stick tilt: %s, smooth camera: %s, healer mode: %s",
                  s.walkRun ? "on" : "off", s.camSmooth ? "on" : "off", s.bumperFlick ? "on" : "off");
        if (s.ringSlot) Log_Write("  utility ring on slot %d_%d", s.ringSlot / 10, s.ringSlot % 10);
    }
    free(buf);
    CloseHandle(f);
}
} // namespace

static void Poll() {
    wchar_t path[MAX_PATH * 2];
    FILETIME ft = {};
    if (!FindNewest(path, MAX_PATH * 2, &ft)) return;
    if (CompareFileTime(&ft, &g_lastWrite) == 0 && wcscmp(path, g_lastPath) == 0) return;
    g_lastWrite = ft;
    wcscpy(g_lastPath, path);
    Load(path);
}

static DWORD WINAPI SettingsThread(LPVOID) {
    for (;;) { Poll(); Sleep(1000); }
    return 0;
}

void AddonSettings_Start() {
    static bool started = false;
    if (started) return;
    started = true;
    InitializeCriticalSection(&g_lock);
    Poll();   // settings in place before the first controller update
    HANDLE t = CreateThread(nullptr, 0, SettingsThread, nullptr, 0, nullptr);
    if (t) { SetThreadPriority(t, THREAD_PRIORITY_BELOW_NORMAL); CloseHandle(t); }
}

AddonSettings AddonSettings_Get() {
    EnterCriticalSection(&g_lock);
    AddonSettings s = g_s;
    LeaveCriticalSection(&g_lock);
    return s;
}
