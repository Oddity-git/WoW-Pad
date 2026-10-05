// worker.h - the background thread started from DllMain.
#pragma once
#include <windows.h>

DWORD WINAPI Worker_Main(LPVOID);
void Worker_RequestStop();
