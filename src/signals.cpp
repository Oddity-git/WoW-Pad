// signals.cpp - signal key table and the key presses that send a signal.
#include "signals.h"
#include "inject.h"

#define A_C  (SMOD_ALT | SMOD_CTRL)
#define A_CS (SMOD_ALT | SMOD_CTRL | SMOD_SHIFT)
#define C_S  (SMOD_CTRL | SMOD_SHIFT)

const SignalKey kSignals[SIG_COUNT] = {
    /* SIG_DPAD_UP        */ { "NUMPAD8",            VK_NUMPAD8,  0 },
    /* SIG_DPAD_DOWN      */ { "NUMPAD2",            VK_NUMPAD2,  0 },
    /* SIG_DPAD_LEFT      */ { "NUMPAD4",            VK_NUMPAD4,  0 },
    /* SIG_DPAD_RIGHT     */ { "NUMPAD6",            VK_NUMPAD6,  0 },
    /* SIG_A              */ { "NUMPAD1",            VK_NUMPAD1,  0 },
    /* SIG_B              */ { "NUMPAD3",            VK_NUMPAD3,  0 },
    /* SIG_X              */ { "NUMPAD7",            VK_NUMPAD7,  0 },
    /* SIG_Y              */ { "NUMPAD9",            VK_NUMPAD9,  0 },
    /* SIG_LT_ON          */ { "NUMPADDIVIDE",       VK_DIVIDE,   0 },
    /* SIG_LT_OFF         */ { "NUMPADMULTIPLY",     VK_MULTIPLY, 0 },
    /* SIG_RT_ON          */ { "NUMPADMINUS",        VK_SUBTRACT, 0 },
    /* SIG_RT_OFF         */ { "NUMPADPLUS",         VK_ADD,      0 },
    /* SIG_INTERACT       */ { "NUMPAD5",            VK_NUMPAD5,  0 },
    /* SIG_L3             */ { "NUMPADDECIMAL",      VK_DECIMAL,  0 },
    /* SIG_CAM_ACTIVE     */ { "NUMPAD0",            VK_NUMPAD0,  0 },
    /* SIG_LB             */ { "ALT-CTRL-NUMPAD7",   VK_NUMPAD7,  A_C },
    /* SIG_RB             */ { "ALT-CTRL-NUMPAD9",   VK_NUMPAD9,  A_C },
    /* SIG_ZOOM_ON        */ { "ALT-CTRL-SHIFT-F6",  VK_F6,       A_CS },
    /* SIG_ZOOM_OFF       */ { "ALT-CTRL-SHIFT-F7",  VK_F7,       A_CS },
    /* SIG_CAM_IDLE       */ { "ALT-CTRL-SHIFT-F8",  VK_F8,       A_CS },
    /* SIG_START          */ { "ALT-CTRL-NUMPAD5",   VK_NUMPAD5,  A_C },
    /* SIG_BACK_TAP       */ { "ALT-CTRL-NUMPAD0",   VK_NUMPAD0,  A_C },
    /* SIG_BACK_HOLD      */ { "ALT-CTRL-SHIFT-F5",  VK_F5,       A_CS },
    /* SIG_NAV_UP         */ { "ALT-CTRL-NUMPAD8",   VK_NUMPAD8,  A_C },
    /* SIG_NAV_DOWN       */ { "ALT-CTRL-NUMPAD2",   VK_NUMPAD2,  A_C },
    /* SIG_NAV_LEFT       */ { "ALT-CTRL-NUMPAD4",   VK_NUMPAD4,  A_C },
    /* SIG_NAV_RIGHT      */ { "ALT-CTRL-NUMPAD6",   VK_NUMPAD6,  A_C },
    /* SIG_NAV_CONFIRM    */ { "ALT-CTRL-NUMPAD1",   VK_NUMPAD1,  A_C },
    /* SIG_NAV_BACK       */ { "ALT-CTRL-NUMPAD3",   VK_NUMPAD3,  A_C },
    /* SIG_MODE_CONTROLLER*/ { "ALT-CTRL-SHIFT-F1",  VK_F1,       A_CS },
    /* SIG_MODE_DESKTOP   */ { "ALT-CTRL-SHIFT-F2",  VK_F2,       A_CS },
    /* SIG_POINTER_ON     */ { "ALT-CTRL-SHIFT-F3",  VK_F3,       A_CS },
    /* SIG_POINTER_OFF    */ { "ALT-CTRL-SHIFT-F4",  VK_F4,       A_CS },
    /* SIG_WALK_TOGGLE    */ { "ALT-CTRL-SHIFT-F9",  VK_F9,       A_CS },
    /* SIG_LB_FLICK_DOWN  */ { "ALT-CTRL-NUMPADDIVIDE",   VK_DIVIDE,   A_C },
    /* SIG_LB_FLICK_UP    */ { "ALT-CTRL-NUMPADMULTIPLY", VK_MULTIPLY, A_C },
    /* SIG_RB_FLICK_DOWN  */ { "ALT-CTRL-NUMPADMINUS",    VK_SUBTRACT, A_C },
    /* SIG_RB_FLICK_UP    */ { "ALT-CTRL-NUMPADPLUS",     VK_ADD,      A_C },
    /* SIG_RING_DIR_0     */ { "CTRL-SHIFT-F1",      VK_F1,       C_S },
    /* SIG_RING_DIR_1     */ { "CTRL-SHIFT-F2",      VK_F2,       C_S },
    /* SIG_RING_DIR_2     */ { "CTRL-SHIFT-F3",      VK_F3,       C_S },
    /* SIG_RING_DIR_3     */ { "CTRL-SHIFT-F4",      VK_F4,       C_S },
    /* SIG_RING_DIR_4     */ { "CTRL-SHIFT-F5",      VK_F5,       C_S },
    /* SIG_RING_DIR_5     */ { "CTRL-SHIFT-F6",      VK_F6,       C_S },
    /* SIG_RING_DIR_6     */ { "CTRL-SHIFT-F7",      VK_F7,       C_S },
    /* SIG_RING_DIR_7     */ { "CTRL-SHIFT-F8",      VK_F8,       C_S },
    /* SIG_RING_DIR_8     */ { "CTRL-SHIFT-F9",      VK_F9,       C_S },
};

void Signal_Down(Signal s) {
    const SignalKey& k = kSignals[s];
    if (k.mods) { Signal_Tap(s); return; } // never hold modifiers
    Inject_Key(k.vk, true);
}

void Signal_Up(Signal s) {
    const SignalKey& k = kSignals[s];
    if (!k.mods) Inject_Key(k.vk, false);
}

static void (*g_wait)(DWORD) = nullptr;
void Signal_SetWait(void (*wait)(DWORD ms)) { g_wait = wait; }
static void Wait(DWORD ms) { if (g_wait) g_wait(ms); else Sleep(ms); }

void Signal_Tap(Signal s) {
    const SignalKey& k = kSignals[s];
    if (k.mods & SMOD_CTRL)  { Inject_Key(VK_CONTROL, true); Wait(5); }
    if (k.mods & SMOD_ALT)   { Inject_Key(VK_MENU, true);    Wait(5); }
    if (k.mods & SMOD_SHIFT) { Inject_Key(VK_SHIFT, true);   Wait(5); }
    Inject_Key(k.vk, true);  Wait(15);
    Inject_Key(k.vk, false);
    if (k.mods) Wait(5);
    if (k.mods & SMOD_SHIFT) { Inject_Key(VK_SHIFT, false);  Wait(5); }
    if (k.mods & SMOD_ALT)   { Inject_Key(VK_MENU, false);   Wait(5); }
    if (k.mods & SMOD_CTRL)  { Inject_Key(VK_CONTROL, false); }
}
