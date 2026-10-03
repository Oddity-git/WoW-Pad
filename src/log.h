// log.h - thread-safe line logger writing wowpad.log next to Wow.exe.
// Self-initialising: safe to call from any thread at any time (the game thread
// may hit the version.dll forwarders before our worker thread runs).
#pragma once

void Log_Write(const char* fmt, ...) __attribute__((format(printf, 1, 2)));

// Directory containing the host exe (Wow.exe), with trailing backslash.
const wchar_t* GameDirW();
// Same, UTF-8, for log output.
const char* GameDirUtf8();
