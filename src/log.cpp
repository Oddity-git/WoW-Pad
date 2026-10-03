#include <windows.h>
#include <stdarg.h>
#include <stdio.h>
#include "log.h"

static INIT_ONCE        g_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION g_lock;
static HANDLE           g_file = INVALID_HANDLE_VALUE;
static wchar_t          g_dirW[MAX_PATH];
static char             g_dirU8[MAX_PATH * 3];

static BOOL CALLBACK InitLog(PINIT_ONCE, PVOID, PVOID*) {
    InitializeCriticalSection(&g_lock);

    DWORD n = GetModuleFileNameW(nullptr, g_dirW, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) {
        g_dirW[0] = 0;
    } else {
        wchar_t* slash = wcsrchr(g_dirW, L'\\');
        if (!slash) slash = wcsrchr(g_dirW, L'/');
        if (slash) slash[1] = 0; else g_dirW[0] = 0;
    }
    WideCharToMultiByte(CP_UTF8, 0, g_dirW, -1, g_dirU8, sizeof(g_dirU8), nullptr, nullptr);

    wchar_t path[MAX_PATH + 16];
    _snwprintf(path, MAX_PATH + 16, L"%lswowpad.log", g_dirW);
    path[MAX_PATH + 15] = 0;
    // Truncate each launch; FILE_SHARE_READ so `tail -f` works from Linux.
    g_file = CreateFileW(path, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                         CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    return TRUE;
}

static void EnsureInit() { InitOnceExecuteOnce(&g_once, InitLog, nullptr, nullptr); }

const wchar_t* GameDirW()    { EnsureInit(); return g_dirW; }
const char*    GameDirUtf8() { EnsureInit(); return g_dirU8; }

void Log_Write(const char* fmt, ...) {
    EnsureInit();
    if (g_file == INVALID_HANDLE_VALUE) return;

    char line[1024];
    SYSTEMTIME t;
    GetLocalTime(&t);
    int len = snprintf(line, sizeof(line), "[%02u:%02u:%02u.%03u] ",
                       t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list ap;
    va_start(ap, fmt);
    int body = vsnprintf(line + len, sizeof(line) - len - 2, fmt, ap);
    va_end(ap);
    if (body < 0) body = 0;
    len += body;
    if (len > (int)sizeof(line) - 2) len = sizeof(line) - 2;
    line[len++] = '\n';

    EnterCriticalSection(&g_lock);
    DWORD written;
    WriteFile(g_file, line, (DWORD)len, &written, nullptr);
    LeaveCriticalSection(&g_lock);
}
