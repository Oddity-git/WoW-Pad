// names.cpp - pad button and key name tables for wowpad.ini and the log.
#include "names.h"
#include "controller.h"
#include <wchar.h>
#include <wctype.h>

const PadButtonName kPadButtonNames[] = {
    { PAD_DPAD_UP, "DPadUp" }, { PAD_DPAD_DOWN, "DPadDown" },
    { PAD_DPAD_LEFT, "DPadLeft" }, { PAD_DPAD_RIGHT, "DPadRight" },
    { PAD_START, "Start" }, { PAD_BACK, "Back" },
    { PAD_LSTICK, "LStick" }, { PAD_RSTICK, "RStick" },
    { PAD_LB, "LB" }, { PAD_RB, "RB" }, { PAD_GUIDE, "Guide" },
    { PAD_A, "A" }, { PAD_B, "B" }, { PAD_X, "X" }, { PAD_Y, "Y" },
};
const int kPadButtonNameCount = sizeof(kPadButtonNames) / sizeof(kPadButtonNames[0]);

static bool EqNoCase(const wchar_t* a, const char* b) {
    for (; *a && *b; ++a, ++b)
        if (towupper(*a) != towupper((wchar_t)(unsigned char)*b)) return false;
    return *a == 0 && *b == 0;
}

uint16_t PadButtonFromName(const wchar_t* s) {
    if (!s || !*s) return 0;
    for (int i = 0; i < kPadButtonNameCount; ++i)
        if (EqNoCase(s, kPadButtonNames[i].name)) return kPadButtonNames[i].bit;
    return 0;
}

BYTE VkFromName(const wchar_t* s) {
    if (!s || !*s) return 0;
    if (!s[1]) {
        wchar_t c = towupper(s[0]);
        if ((c >= L'A' && c <= L'Z') || (c >= L'0' && c <= L'9')) return (BYTE)c;
    }
    static const struct { const char* n; BYTE vk; } named[] = {
        { "SPACE", VK_SPACE }, { "TAB", VK_TAB }, { "ESCAPE", VK_ESCAPE }, { "ENTER", VK_RETURN },
        { "UP", VK_UP }, { "DOWN", VK_DOWN }, { "LEFT", VK_LEFT }, { "RIGHT", VK_RIGHT },
        { "SHIFT", VK_SHIFT }, { "CTRL", VK_CONTROL }, { "ALT", VK_MENU },
        { "INSERT", VK_INSERT }, { "DELETE", VK_DELETE }, { "HOME", VK_HOME }, { "END", VK_END },
        { "PAGEUP", VK_PRIOR }, { "PAGEDOWN", VK_NEXT },
    };
    for (auto& n : named) if (EqNoCase(s, n.n)) return n.vk;

    if ((s[0] == L'F' || s[0] == L'f') && iswdigit(s[1])) {
        int n = _wtoi(s + 1);
        if (n >= 1 && n <= 24) return (BYTE)(VK_F1 + n - 1);
    }
    if (_wcsnicmp(s, L"NUMPAD", 6) == 0 && iswdigit(s[6]) && !s[7])
        return (BYTE)(VK_NUMPAD0 + (s[6] - L'0'));
    return 0;
}
