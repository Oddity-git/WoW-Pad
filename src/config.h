// config.h - settings read from wowpad.ini next to Wow.exe (all optional).
#pragma once
#include <stdint.h>
#include <windows.h>

struct Config {
    // [Input]
    int   pollMs           = 10;    // controller poll interval
    float stickDeadzone    = 0.24f; // radial, fraction of full deflection
    float triggerThreshold = 0.12f; // fraction of full pull

    // [Inject]
    int   injectMode       = 0;     // 0 = SendInput, 1 = PostMessage

    // [Move] left stick -> keys
    BYTE  keyForward = 'W', keyBack = 'S', keyLeft = 'Q', keyRight = 'E';
    float movePressAt   = 0.40f;   // per axis, after deadzone
    float moveReleaseAt = 0.30f;
    float walkBelow     = 0.60f;   // walk/run option: stick tilt below this walks...
    float runAbove      = 0.80f;   // ...and above this runs (gap = no flicker)
    bool  walkRun       = false;   // set from the addon's options (wpWalkRun)
    int   walkDelayMs   = 150;     // tilt must stay low this long before walking (no walk blip when pushing to full)

    // [Cursor] right stick -> mouse pointer
    float    cursorSpeed     = 1200.0f; // px/s at full deflection
    float    cursorCurve     = 2.0f;    // 1 = linear, higher = finer near centre
    uint16_t precisionButton = 0;       // pad button for slow pointer (default None); pointer mode only
    float    precisionScale  = 0.35f;
    bool     clampToWindow   = true;
    bool     pointerWarp     = false;   // experimental: warp the real cursor in pointer mode (didn't move the drawn cursor on Wayland)

    // [Camera] right stick while the game is mouselooking (cursor hidden)
    float    cameraSpeed   = 1000.0f;   // px/s at full deflection
    bool     cameraInvertY = false;
    float    smoothMs      = 60.0f;     // smooth camera option: time constant (ms)
    bool     camSmooth     = false;     // set from the addon's options (wpCamSmooth)
    int      ringSlot      = 0;         // utility ring button: bar slot set*10+i (wpRingSlot), 0 = none
    bool     bumperFlick   = false;     // healer mode, set from the addon's options (wpBumperFlick)
    float    zoomSpeed     = 8.0f;      // wheel notches/s at full deflection (LB+RB held)
    int      peekDelayMs   = 250;       // right stick idle this long -> CAM_IDLE (crosshair peek); 0 = off
    int      crosshairY    = 95;        // pointer parked this many px above window centre on entering controller mode

    // [Click] trigger press/release points: set switching, and clicks in pointer mode
    float clickPressAt   = 0.50f;
    float clickReleaseAt = 0.35f;

    // [Mode] automatic controller/desktop switching
    long  mouseTravel = 40;      // px of real mouse movement that means "desktop"
    int   backHoldMs  = 400;     // Back held this long = bags instead of map

    // [Log] troubleshooting aids for wowpad.log
    float logStickStep = 0.10f;  // stick/trigger change that gets a new LS/RS/LT/RT line
    bool  logSticks    = false;  // log stick and trigger values
    bool  logButtons   = true;   // log button presses plus extra MOVE/PEEK/Crosshair lines
};

void          Config_Load();
const Config& Config_Get();
