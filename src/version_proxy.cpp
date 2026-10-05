// version_proxy.cpp - forwards the real version.dll API.
//
// Why wrappers instead of PE forwarder strings: a forwarder like
// "version.GetFileVersionInfoA" would resolve back to *this* DLL (same base
// name), and forwarders cannot carry an absolute path. So each export is a
// typed stdcall wrapper that lazily loads the real DLL on first use.
//
// Load order for the real DLL (first one that is not ourselves wins):
//   1. <game dir>\version_orig.dll   (escape hatch, see README)
//   2. <system dir>\version.dll
// Under Wine with WINEDLLOVERRIDES="version=n,b", LoadLibrary on
// system32\version.dll may hand back our own already-loaded module instead of
// Wine's builtin; TryLoad rejects that. wowpad.log says which path was used.
// If (2) fails, use (1).
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include "log.h"

static INIT_ONCE g_once = INIT_ONCE_STATIC_INIT;
static HMODULE   g_real = nullptr;

static HMODULE TryLoad(const wchar_t* path, HMODULE self) {
    HMODULE h = LoadLibraryW(path);
    if (!h) return nullptr;
    if (h == self) { FreeLibrary(h); return nullptr; }
    return h;
}

static BOOL CALLBACK LoadReal(PINIT_ONCE, PVOID, PVOID*) {
    HMODULE self = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       (LPCWSTR)(void*)&LoadReal, &self);

    wchar_t path[MAX_PATH + 32];
    const char* used = nullptr;

    _snwprintf(path, MAX_PATH + 32, L"%lsversion_orig.dll", GameDirW());
    path[MAX_PATH + 31] = 0;
    if (GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES && (g_real = TryLoad(path, self)))
        used = "game dir version_orig.dll";

    if (!g_real) {
        wchar_t sys[MAX_PATH];
        UINT n = GetSystemDirectoryW(sys, MAX_PATH);
        if (n > 0 && n < MAX_PATH) {
            _snwprintf(path, MAX_PATH + 32, L"%ls\\version.dll", sys);
            path[MAX_PATH + 31] = 0;
            if ((g_real = TryLoad(path, self))) used = "system version.dll";
        }
    }

    if (g_real) Log_Write("version proxy: real API from %s", used);
    else        Log_Write("version proxy: ERROR could not load a real version.dll; "
                          "version API calls will fail (see README, version_orig.dll)");
    return TRUE;
}

static FARPROC Real(const char* name) {
    InitOnceExecuteOnce(&g_once, LoadReal, nullptr, nullptr);
    FARPROC p = g_real ? GetProcAddress(g_real, name) : nullptr;
    if (!p) Log_Write("version proxy: %s unavailable", name);
    return p;
}

// FWD(ret, failValue, name, (params), (args))
#define FWD(RET, FAIL, NAME, PARAMS, ARGS)                                 \
    extern "C" RET WINAPI proxy_##NAME PARAMS {                            \
        typedef RET(WINAPI * fn_t) PARAMS;                                 \
        static fn_t real_fn = (fn_t)Real(#NAME);                           \
        if (!real_fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FAIL; } \
        return real_fn ARGS;                                               \
    }

FWD(BOOL,  FALSE, GetFileVersionInfoA,
    (LPCSTR f, DWORD h, DWORD l, LPVOID d), (f, h, l, d))
FWD(BOOL,  FALSE, GetFileVersionInfoW,
    (LPCWSTR f, DWORD h, DWORD l, LPVOID d), (f, h, l, d))
FWD(BOOL,  FALSE, GetFileVersionInfoExA,
    (DWORD fl, LPCSTR f, DWORD h, DWORD l, LPVOID d), (fl, f, h, l, d))
FWD(BOOL,  FALSE, GetFileVersionInfoExW,
    (DWORD fl, LPCWSTR f, DWORD h, DWORD l, LPVOID d), (fl, f, h, l, d))
FWD(DWORD, 0,     GetFileVersionInfoSizeA,
    (LPCSTR f, LPDWORD h), (f, h))
FWD(DWORD, 0,     GetFileVersionInfoSizeW,
    (LPCWSTR f, LPDWORD h), (f, h))
FWD(DWORD, 0,     GetFileVersionInfoSizeExA,
    (DWORD fl, LPCSTR f, LPDWORD h), (fl, f, h))
FWD(DWORD, 0,     GetFileVersionInfoSizeExW,
    (DWORD fl, LPCWSTR f, LPDWORD h), (fl, f, h))
FWD(DWORD, 0,     VerFindFileA,
    (DWORD fl, LPCSTR fn, LPCSTR wd, LPCSTR ad, LPSTR cd, PUINT cdl, LPSTR dd, PUINT ddl),
    (fl, fn, wd, ad, cd, cdl, dd, ddl))
FWD(DWORD, 0,     VerFindFileW,
    (DWORD fl, LPCWSTR fn, LPCWSTR wd, LPCWSTR ad, LPWSTR cd, PUINT cdl, LPWSTR dd, PUINT ddl),
    (fl, fn, wd, ad, cd, cdl, dd, ddl))
FWD(DWORD, 0,     VerInstallFileA,
    (DWORD fl, LPCSTR sf, LPCSTR df, LPCSTR sd, LPCSTR dd, LPCSTR cd, LPSTR tf, PUINT tfl),
    (fl, sf, df, sd, dd, cd, tf, tfl))
FWD(DWORD, 0,     VerInstallFileW,
    (DWORD fl, LPCWSTR sf, LPCWSTR df, LPCWSTR sd, LPCWSTR dd, LPCWSTR cd, LPWSTR tf, PUINT tfl),
    (fl, sf, df, sd, dd, cd, tf, tfl))
FWD(DWORD, 0,     VerLanguageNameA,
    (DWORD lang, LPSTR buf, DWORD cch), (lang, buf, cch))
FWD(DWORD, 0,     VerLanguageNameW,
    (DWORD lang, LPWSTR buf, DWORD cch), (lang, buf, cch))
FWD(BOOL,  FALSE, VerQueryValueA,
    (LPCVOID blk, LPCSTR sub, LPVOID* buf, PUINT len), (blk, sub, buf, len))
FWD(BOOL,  FALSE, VerQueryValueW,
    (LPCVOID blk, LPCWSTR sub, LPVOID* buf, PUINT len), (blk, sub, buf, len))
