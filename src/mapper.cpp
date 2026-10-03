// mapper.cpp - Phase 3 controller mode.
//
// Modes: DESKTOP (nothing injected) / CONTROLLER. Pad input -> controller;
// real keyboard press, mouse click/wheel, or real mouse travel while the
// pointer is visible -> desktop (hooks.cpp tells real from ours).
//
// Controller mode:
//   Left stick   -> movement keys
//   Right stick  -> relative mouse motion: turns the camera while the addon
//                   has mouselook on (pointer hidden), moves the pointer otherwise
//   D-pad/ABXY   -> slot signals; the addon maps them to the active set, or
//                   to menu navigation when a window is open (out of combat)
//   LT / RT      -> set switching (LT_ON/OFF, RT_ON/OFF edges)
//   LB / RB      -> target friendly / hostile (on press)
//   LB + RB held -> right stick up/down zooms the camera (mouse wheel), hint shown
//   Right stick  -> CAM_ACTIVE before the first motion, CAM_IDLE after it rests
//                   (the addon pauses camera look while idle so the crosshair
//                   can show what's under it: WoW ignores mouseover in mouselook)
//   Start        -> radial menu (sent on release, so Back+Start can't leak)
//   Back         -> tap: map, hold: bags
//   X (no trigger) -> INTERACT (your F binding) then the X slot (startattack)
//   L3           -> autorun
//   R3           -> pointer mode toggle (RT/LT click, right stick = pointer)
//   Back + Start held 1 s -> kill switch
//
// Menu-vs-action context is decided by the addon, not here: under Proton
// GetCursorInfo never reports the pointer hidden during mouselook (verified
// in Phase 3 testing), so the DLL can't tell.
#include <windows.h>
#include <math.h>
#include "addonsettings.h"
#include "mapper.h"
#include "config.h"
#include "inject.h"
#include "signals.h"
#include "hooks.h"
#include "gamewindow.h"
#include "cursorhide.h"
#include "log.h"

namespace {
enum Mode { MODE_DESKTOP, MODE_CONTROLLER };

Mode     g_mode        = MODE_DESKTOP;
bool     g_enabled     = true;
bool     g_focused     = false;
bool     g_pointerMode = false;
uint16_t g_prev        = 0;
bool     g_lt = false, g_rt = false;
bool     g_moveHeld[4]  = {};
bool     g_walking      = false;   // we toggled the game to walk (walk/run option)
DWORD    g_walkWantSince = 0;
bool     g_clickHeld[2] = {};
double   g_accX = 0, g_accY = 0;
int      g_heldSig[8];               // signal held per face/dpad button, -1 none
bool     g_interactHeld = false;
bool     g_zoom         = false;     // LB+RB held
double   g_zoomAcc      = 0;
bool     g_camActive    = false;     // CAM_ACTIVE sent, CAM_IDLE not yet
DWORD    g_stickIdleAt  = 0;
POINT    g_activeStartPt = {};       // pointer when the stick started moving
bool     g_prevNoCursor = false;     // camera look was on at the last tick
bool     g_movedMotion  = false;     // we sent motion during this active period
DWORD    g_lastModeSend = 0;
DWORD    g_backDownAt   = 0;
bool     g_backHoldSent = false;
bool     g_chordUsed    = false;     // Back+Start used together: suppress both
DWORD    g_chordStart   = 0;
bool     g_chordFired   = false;
bool     g_initDone     = false;

const DWORD kToggleHoldMs = 1000;
const DWORD kModeResendMs = 10000;

struct FaceMap { uint16_t bit; Signal slot; int nav; const char* name; };
const FaceMap kFace[8] = {
    { PAD_DPAD_UP,    SIG_DPAD_UP,    SIG_NAV_UP,      "DPadUp" },
    { PAD_DPAD_DOWN,  SIG_DPAD_DOWN,  SIG_NAV_DOWN,    "DPadDown" },
    { PAD_DPAD_LEFT,  SIG_DPAD_LEFT,  SIG_NAV_LEFT,    "DPadLeft" },
    { PAD_DPAD_RIGHT, SIG_DPAD_RIGHT, SIG_NAV_RIGHT,   "DPadRight" },
    { PAD_A,          SIG_A,          SIG_NAV_CONFIRM, "A" },
    { PAD_B,          SIG_B,          SIG_NAV_BACK,    "B" },
    { PAD_X,          SIG_X,          -1,              "X" },
    { PAD_Y,          SIG_Y,          -1,              "Y" },
};

bool Hyst(bool held, float v, float on, float off) { return held ? v > off : v >= on; }

void InitOnce() {
    if (g_initDone) return;
    for (int& h : g_heldSig) h = -1;
    g_initDone = true;
}

// Release everything we hold and reset trigger state on the addon side.
void ReleaseWarp();
void SetWalking(bool walk);
void ReleaseControllerState(bool tellAddon) {
    for (int i = 0; i < 8; ++i)
        if (g_heldSig[i] >= 0) { Signal_Up((Signal)g_heldSig[i]); g_heldSig[i] = -1; }
    if (g_interactHeld) { Signal_Up(SIG_INTERACT); g_interactHeld = false; }
    if (tellAddon) {
        if (g_lt) Signal_Tap(SIG_LT_OFF);
        if (g_rt) Signal_Tap(SIG_RT_OFF);
        if (g_zoom) Signal_Tap(SIG_ZOOM_OFF);
    }
    if (g_walking && tellAddon && GameWindow_IsForeground()) SetWalking(false); // leave the game running
    g_walkWantSince = 0;
    g_lt = g_rt = false;
    g_zoom = false;
    g_zoomAcc = 0;
    g_camActive = false;
    CursorHide_Set(false);
    ReleaseWarp();
    Inject_ReleaseAll();
    for (bool& b : g_moveHeld) b = false;
    for (bool& b : g_clickHeld) b = false;
    g_accX = g_accY = 0;
}

// Pointer mode under Wayland: relative SendInput moves WoW's pointer, but the
// compositor keeps drawing the hardware cursor where it was. A pointer that is
// confined (ClipCursor) can be warped, and the drawn cursor follows, so while
// the stick moves the pointer we keep it in a 1-pixel box and move the box.
bool g_warpClip = false;
void ReleaseWarp() {
    if (!g_warpClip) return;
    ClipCursor(nullptr);
    g_warpClip = false;
}
void WarpPointer(long x, long y) {
    RECT box = { x, y, x + 1, y + 1 };
    ClipCursor(&box);
    SetCursorPos(x, y);
    g_warpClip = true;
}

void SendMode() {
    Signal_Tap(g_mode == MODE_CONTROLLER ? SIG_MODE_CONTROLLER : SIG_MODE_DESKTOP);
    Signal_Tap(g_pointerMode ? SIG_POINTER_ON : SIG_POINTER_OFF);
    g_lastModeSend = GetTickCount();
}

// Park the pointer where the crosshair should be: WoW freezes its hidden
// pointer wherever it is when camera look starts.
// SetCursorPos can be ignored under Wine (Wayland pointer warping), so move
// there with relative SendInput motion, which is proven to work.
void ParkPointer(const Config& c) {
    RECT r;
    if (!GameWindow_ClientRectScreen(&r)) return;
    long tx = (r.left + r.right) / 2, ty = (r.top + r.bottom) / 2 - c.crosshairY;
    // Wayland/XWayland only lets a program move a *confined* pointer, so confine
    // it to a 1-pixel box at the target for a moment (forces it there), then free it.
    RECT box = { tx, ty, tx + 1, ty + 1 };
    ClipCursor(&box);
    SetCursorPos(tx, ty);
    Sleep(40);
    ClipCursor(nullptr);
    POINT p;
    GetCursorPos(&p);
    Log_Write("Crosshair: pointer parked at %ld,%ld (target %ld,%ld)", p.x, p.y, tx, ty);
    Sleep(150);
    GetCursorPos(&p);
    Log_Write("Crosshair: 150 ms later pointer at %ld,%ld", p.x, p.y);
}

void SetMode(Mode m, const char* why) {
    if (m == g_mode) return;
    if (g_mode == MODE_CONTROLLER) ReleaseControllerState(true);
    g_mode = m;
    if (m == MODE_CONTROLLER) ParkPointer(Config_Get());
    if (m == MODE_DESKTOP) g_pointerMode = false;
    Log_Write("MODE %s (%s)", m == MODE_CONTROLLER ? "controller" : "desktop", why);
    SendMode();
}

bool UpdateKillSwitch(const ControllerState& s) {
    bool chord = s.connected && (s.buttons & PAD_BACK) && (s.buttons & PAD_START);
    if (chord) g_chordUsed = true;
    if (!chord) { g_chordStart = 0; g_chordFired = false; return false; }
    DWORD now = GetTickCount();
    if (!g_chordStart) g_chordStart = now;
    if (!g_chordFired && now - g_chordStart >= kToggleHoldMs) {
        g_chordFired = true;
        g_enabled = !g_enabled;
        Log_Write("Kill switch: controller input %s (Back+Start)", g_enabled ? "ENABLED" : "DISABLED");
        if (!g_enabled) SetMode(MODE_DESKTOP, "kill switch");
        return true;
    }
    return false;
}

// Walk/run option: the game has one Run/Walk toggle, so we track what we set.
// Slight tilt walks, full tilt runs; stick at rest always goes back to run, so
// the game is left in its normal state whenever you stop.
void SetWalking(bool walk) {
    if (walk == g_walking) return;
    Signal_Tap(SIG_WALK_TOGGLE);
    g_walking = walk;
    if (Config_Get().logButtons) Log_Write("MOVE %s", walk ? "walk" : "run");
}

void UpdateWalkRun(const ControllerState& s, const Config& c) {
    bool moving = g_moveHeld[0] || g_moveHeld[1] || g_moveHeld[2] || g_moveHeld[3];
    if (!c.walkRun || !moving) { g_walkWantSince = 0; SetWalking(false); return; }
    float mag = sqrtf(s.lx * s.lx + s.ly * s.ly);
    if (mag > c.runAbove) { g_walkWantSince = 0; SetWalking(false); return; }
    if (g_walking || mag >= c.walkBelow) { g_walkWantSince = 0; return; }
    DWORD now = GetTickCount();
    if (!g_walkWantSince) g_walkWantSince = now ? now : 1;
    if (now - g_walkWantSince >= (DWORD)c.walkDelayMs) SetWalking(true);
}

void UpdateMovement(const ControllerState& s, const Config& c) {
    const float v[4]  = { s.ly, -s.ly, -s.lx, s.lx };
    const BYTE  vk[4] = { c.keyForward, c.keyBack, c.keyLeft, c.keyRight };
    for (int i = 0; i < 4; ++i) {
        bool want = Hyst(g_moveHeld[i], v[i], c.movePressAt, c.moveReleaseAt);
        if (want != g_moveHeld[i]) { g_moveHeld[i] = want; Inject_Key(vk[i], want); }
    }
    UpdateWalkRun(s, c);
}

void UpdateTriggers(const ControllerState& s, const Config& c) {
    bool lt = Hyst(g_lt || g_clickHeld[MOUSE_RIGHT], s.lt, c.clickPressAt, c.clickReleaseAt);
    bool rt = Hyst(g_rt || g_clickHeld[MOUSE_LEFT],  s.rt, c.clickPressAt, c.clickReleaseAt);
    if (g_pointerMode) {
        // Pointer mode: RT = left click, LT = right click (Phase 2 behaviour).
        if (rt != g_clickHeld[MOUSE_LEFT])  { g_clickHeld[MOUSE_LEFT]  = rt; Inject_MouseButton(MOUSE_LEFT, rt); }
        if (lt != g_clickHeld[MOUSE_RIGHT]) { g_clickHeld[MOUSE_RIGHT] = lt; Inject_MouseButton(MOUSE_RIGHT, lt); }
        return;
    }
    if (lt != g_lt) { g_lt = lt; Signal_Tap(lt ? SIG_LT_ON : SIG_LT_OFF); }
    if (rt != g_rt) { g_rt = rt; Signal_Tap(rt ? SIG_RT_ON : SIG_RT_OFF); }
}

void UpdateButtons(const ControllerState& s, const Config& c) {
    uint16_t pressed  = s.buttons & ~g_prev;
    uint16_t released = g_prev & ~s.buttons;
    DWORD now = GetTickCount();

    // Self-heal after an addon /reload: re-announce the mode now and then.
    if (pressed && now - g_lastModeSend > kModeResendMs) SendMode();

    if (pressed & PAD_RSTICK) {
        g_pointerMode = !g_pointerMode;
        if (g_pointerMode) {           // leave set switching cleanly
            // Wayland keeps drawing the hardware cursor where it was (programs
            // can't move it), so hide it; the addon draws one at WoW's pointer.
            CursorHide_Set(true);
            g_camActive = false;
            if (g_lt) Signal_Tap(SIG_LT_OFF);
            if (g_rt) Signal_Tap(SIG_RT_OFF);
            g_lt = g_rt = false;
        } else {
            ReleaseWarp();
            Inject_MouseButton(MOUSE_LEFT, false);
            Inject_MouseButton(MOUSE_RIGHT, false);
            g_clickHeld[0] = g_clickHeld[1] = false;
            ParkPointer(c);   // camera look resumes with the pointer under the crosshair
        }
        Signal_Tap(g_pointerMode ? SIG_POINTER_ON : SIG_POINTER_OFF);
        if (!g_pointerMode) {
            // Pointer is back under the crosshair, where the desktop still draws
            // the cursor, so the real cursor can show again (once camera look,
            // which hides it anyway, has resumed).
            Sleep(60);
            CursorHide_Set(false);
        }
        Log_Write("MAP pointer mode %s", g_pointerMode ? "on" : "off");
    }
    if (pressed & PAD_LSTICK) Signal_Tap(SIG_L3);
    // LB / RB: target on press. Holding both also switches the right stick to zoom.
    if (pressed & PAD_LB) Signal_Tap(SIG_LB);
    if (pressed & PAD_RB) Signal_Tap(SIG_RB);
    bool both = (s.buttons & PAD_LB) && (s.buttons & PAD_RB);
    if (both != g_zoom) {
        g_zoom = both;
        g_zoomAcc = 0;
        Signal_Tap(both ? SIG_ZOOM_ON : SIG_ZOOM_OFF);
    }

    // Back: tap = map, hold = bags. Start: on release. Both suppressed when
    // used together as the kill-switch chord.
    if (pressed & PAD_BACK) { g_backDownAt = now; g_backHoldSent = false; }
    if ((s.buttons & PAD_BACK) && !g_chordUsed && !g_backHoldSent && now - g_backDownAt >= (DWORD)c.backHoldMs) {
        Signal_Tap(SIG_BACK_HOLD);
        g_backHoldSent = true;
    }
    if ((released & PAD_BACK) && !g_chordUsed && !g_backHoldSent) Signal_Tap(SIG_BACK_TAP);
    if ((released & PAD_START) && !g_chordUsed) Signal_Tap(SIG_START);
    if (!(s.buttons & (PAD_BACK | PAD_START))) g_chordUsed = false;

    // Face buttons and D-pad: always slot signals (the addon decides what they do).
    for (int i = 0; i < 8; ++i) {
        const FaceMap& f = kFace[i];
        if (pressed & f.bit) {
            // X in the default set: interact first (it may change target), then attack.
            if (f.slot == SIG_X && !g_lt && !g_rt) { Signal_Down(SIG_INTERACT); g_interactHeld = true; }
            Signal_Down(f.slot);
            g_heldSig[i] = f.slot;
        }
        if ((released & f.bit) && f.slot == SIG_X && g_interactHeld) {
            Signal_Up(SIG_INTERACT);
            g_interactHeld = false;
        }
        if ((released & f.bit) && g_heldSig[i] >= 0) {
            Signal_Up((Signal)g_heldSig[i]);
            g_heldSig[i] = -1;
        }
    }
}

void UpdatePointer(const ControllerState& s, const Config& c, double dt) {
    if (g_zoom) {
        // Zoom instead of turning: right stick up = zoom in (wheel away).
        g_accX = g_accY = 0;
        g_zoomAcc += s.ry * c.zoomSpeed * dt;
        int notches = (int)g_zoomAcc;
        g_zoomAcc -= notches;
        Inject_MouseWheel(notches);
        return;
    }
    float x = s.rx, y = s.ry;
    float mag = sqrtf(x * x + y * y);
    DWORD now = GetTickCount();
    if (mag <= 0.0f) {
        g_accX = g_accY = 0;
        ReleaseWarp();   // stick at rest: give the real mouse its freedom back
        if (g_camActive && c.peekDelayMs > 0 && now - g_stickIdleAt >= (DWORD)c.peekDelayMs) {
            // Camera look freezes WoW's pointer; in menus our motion moves it.
            POINT p = {};
            GetCursorPos(&p);
            // Verified under Proton: during camera look Windows reports no cursor
            // (hCursor NULL); in menus there is one. Pointer-frozen as a fallback.
            CURSORINFO ci = {};
            ci.cbSize = sizeof(ci);
            GetCursorInfo(&ci);
            bool camera = ci.hCursor == nullptr ||
                          (g_movedMotion && p.x == g_activeStartPt.x && p.y == g_activeStartPt.y);
            if (c.logButtons)
                Log_Write("PEEK %s (pointer %ld,%ld -> %ld,%ld, hCursor %p)", camera ? "camera: hiding cursor" : "menu: no peek",
                          g_activeStartPt.x, g_activeStartPt.y, p.x, p.y, (void*)ci.hCursor);
            if (camera) { CursorHide_Set(true); Sleep(20); } // hide BEFORE the game shows its cursor
            Signal_Tap(SIG_CAM_IDLE);
            g_camActive = false;
        }
        return;
    }
    g_stickIdleAt = now;
    if (!g_camActive && !g_pointerMode && c.peekDelayMs > 0) {
        CursorHide_Set(false);
        Signal_Tap(SIG_CAM_ACTIVE); // camera look back on before any motion arrives
        g_camActive = true;
        g_movedMotion = false;
        GetCursorPos(&g_activeStartPt);
    }
    if (mag > 1.0f) { x /= mag; y /= mag; mag = 1.0f; }

    bool pointer = g_pointerMode; // menus without pointer mode use camera speed
    float shaped = powf(mag, c.cursorCurve) / mag;
    float speed  = pointer ? c.cursorSpeed : c.cameraSpeed;
    if (pointer && c.precisionButton && (s.buttons & c.precisionButton)) speed *= c.precisionScale;
    float yDir = (!pointer && c.cameraInvertY) ? 1.0f : -1.0f;

    g_accX += x * shaped * speed * dt;
    g_accY += y * yDir * shaped * speed * dt;
    int dx = (int)g_accX, dy = (int)g_accY;
    g_accX -= dx; g_accY -= dy;
    if (!dx && !dy) return;

    RECT r;
    bool haveRect = GameWindow_ClientRectScreen(&r);
    POINT p;
    GetCursorPos(&p);
    long tx = p.x + dx, ty = p.y + dy;
    if (haveRect && (c.clampToWindow || pointer)) {
        if (tx < r.left) tx = r.left; else if (tx > r.right - 1) tx = r.right - 1;
        if (ty < r.top) ty = r.top;   else if (ty > r.bottom - 1) ty = r.bottom - 1;
        dx = (int)(tx - p.x); dy = (int)(ty - p.y);
    }
    if (pointer && c.pointerWarp) WarpPointer(tx, ty);   // visible cursor follows (Wayland)
    else Inject_MouseMove(dx, dy);
    g_movedMotion = true;
}

bool PadActive(const ControllerState& s) {
    return s.connected && (s.buttons || s.lx || s.ly || s.rx || s.ry || s.lt > 0.0f || s.rt > 0.0f);
}
}

void Mapper_Reset() {
    InitOnce();
    ReleaseControllerState(false);
}

void Mapper_Update(const ControllerState& s, double dt) {
    InitOnce();
    // wowpad.ini, adjusted by the addon's options panel
    Config c = Config_Get();
    const AddonSettings& as = AddonSettings_Get();
    c.cameraSpeed *= as.camScale;
    c.cursorSpeed *= as.ptrScale;
    c.zoomSpeed   *= as.zoomScale;
    if (as.invertY >= 0)   c.cameraInvertY = as.invertY != 0;
    if (as.peekDelayMs > 0) c.peekDelayMs  = as.peekDelayMs;
    c.walkRun = as.walkRun;
    GameWindow_Get();

    CursorHide_Install(GameWindow_Get());
    bool focused = GameWindow_IsForeground();
    if (focused != g_focused) {
        g_focused = focused;
        if (!focused) ReleaseControllerState(g_mode == MODE_CONTROLLER);
        Hooks_TakeRealPress(); Hooks_TakeRealMouseTravel(); // drop alt-tab noise
        Log_Write("Game %s", focused ? "focused" : "not focused: input paused");
    }
    if (!focused) { g_prev = s.buttons; return; }

    if (UpdateKillSwitch(s)) { g_prev = s.buttons; return; }

    // Mode detection.
    bool realPress  = Hooks_TakeRealPress();
    long realTravel = Hooks_TakeRealMouseTravel();
    bool realMove   = realTravel >= c.mouseTravel;
    bool padActive  = PadActive(s);

    if (!g_enabled) { g_prev = s.buttons; return; }
    if (g_mode == MODE_CONTROLLER && (realPress || realMove) && !padActive)
        SetMode(MODE_DESKTOP, realPress ? "keyboard/mouse button" : "mouse moved");
    else if (g_mode == MODE_DESKTOP && padActive)
        SetMode(MODE_CONTROLLER, "pad input");

    if (g_mode != MODE_CONTROLLER) { g_prev = s.buttons; return; }

    // Camera look just switched back on (a window closed): WoW froze its pointer
    // wherever the menu left it. Pause camera look (peek), park the pointer at
    // the crosshair, so the crosshair re-centres. Only while the stick rests.
    {
        CURSORINFO ci = {};
        ci.cbSize = sizeof(ci);
        bool noCursor = GetCursorInfo(&ci) && ci.hCursor == nullptr && !CursorHide_IsOn();
        if (noCursor && !g_prevNoCursor && !g_camActive && !g_pointerMode && c.peekDelayMs > 0) {
            CursorHide_Set(true);      // hide first so the hand never shows
            Sleep(20);
            Signal_Tap(SIG_CAM_IDLE);
            Sleep(60);                 // let the game stop camera look
            ParkPointer(c);
            if (c.logButtons) Log_Write("Crosshair: camera resumed, re-centred");
        }
        g_prevNoCursor = noCursor;
    }

    UpdateMovement(s, c);
    UpdateTriggers(s, c);
    UpdateButtons(s, c);
    UpdatePointer(s, c, dt);
    g_prev = s.buttons;
}
