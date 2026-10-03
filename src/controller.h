// controller.h - backend-neutral controller interface.
//
// Everything above this header (mouse emulation, key injection, mode logic)
// must only use these types and functions. Swapping XInput for SDL3 or a
// native Linux helper (Phase 6) means writing a new controller_<backend>.cpp
// that implements the four functions below - nothing else should change.
#pragma once
#include <stdint.h>

// Bit layout intentionally matches XInput so the XInput backend is a straight
// copy, but other backends must map into these bits explicitly.
enum PadButton : uint16_t {
    PAD_DPAD_UP    = 0x0001,
    PAD_DPAD_DOWN  = 0x0002,
    PAD_DPAD_LEFT  = 0x0004,
    PAD_DPAD_RIGHT = 0x0008,
    PAD_START      = 0x0010,
    PAD_BACK       = 0x0020,
    PAD_LSTICK     = 0x0040,
    PAD_RSTICK     = 0x0080,
    PAD_LB         = 0x0100,
    PAD_RB         = 0x0200,
    PAD_GUIDE      = 0x0400, // not reported by XInputGetState; reserved for SDL3
    PAD_A          = 0x1000,
    PAD_B          = 0x2000,
    PAD_X          = 0x4000,
    PAD_Y          = 0x8000,
};

struct ControllerState {
    bool     connected   = false;
    int      deviceIndex = -1;   // backend-specific slot, for logging only
    uint16_t buttons     = 0;    // PadButton bits
    float    lx = 0, ly = 0;     // left stick,  -1..1, +y = up
    float    rx = 0, ry = 0;     // right stick, -1..1, +y = up
    float    lt = 0, rt = 0;     // triggers, 0..1
};

// Returns false if no backend could be initialised (e.g. no xinput DLL).
bool        Controller_Init();
const char* Controller_BackendName();
// Fills *out with RAW normalised values (no deadzones). Returns out->connected.
// Cheap to call every poll tick; the backend rate-limits device rescans itself.
bool        GetControllerState(ControllerState* out);
void        Controller_Shutdown();

// ---- shared, backend-independent processing (controller_filter.cpp) ----
struct DeadzoneConfig {
    float stick;    // radial deadzone, fraction of full deflection (0..0.9)
    float trigger;  // trigger threshold, fraction of full pull (0..0.9)
};
// Radial stick deadzone with rescale (output still reaches 1.0), trigger
// threshold with rescale. Buttons are copied unchanged.
void ApplyDeadzones(const ControllerState& in, const DeadzoneConfig& cfg, ControllerState* out);
