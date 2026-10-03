// dllmain.cpp - DllMain only spawns the worker thread. No other work here:
// we are under the loader lock, so no LoadLibrary, no waiting, no logging.
#include <windows.h>
#include "worker.h"

extern "C" BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved) {
    switch (reason) {
    case DLL_PROCESS_ATTACH: {
        DisableThreadLibraryCalls(hinst);
        HANDLE t = CreateThread(nullptr, 0, Worker_Main, nullptr, 0, nullptr);
        if (t) CloseHandle(t);
        break;
    }
    case DLL_PROCESS_DETACH:
        // Process exit (reserved != NULL): threads are already gone, do nothing.
        // FreeLibrary: just signal; never wait under the loader lock.
        if (!reserved) Worker_RequestStop();
        break;
    }
    return TRUE;
}
