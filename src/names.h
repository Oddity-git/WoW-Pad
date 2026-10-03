// names.h - name <-> value tables for pad buttons and keys (ini + logging).
#pragma once
#include <stdint.h>
#include <windows.h>

struct PadButtonName { uint16_t bit; const char* name; };
extern const PadButtonName kPadButtonNames[];
extern const int           kPadButtonNameCount;

// "RB", "lb", "A", "DPadUp"... -> PadButton bit, 0 if unknown/empty/"None".
uint16_t PadButtonFromName(const wchar_t* s);
// "W", "q", "SPACE", "UP", "F13", "NUMPAD5" -> VK code, 0 if unknown.
BYTE     VkFromName(const wchar_t* s);
