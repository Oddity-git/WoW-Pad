// controller_filter.cpp - stick and trigger deadzones (backend-independent).
#include "controller.h"
#include <math.h>

static void RadialDeadzone(float x, float y, float dz, float* ox, float* oy) {
    float mag = sqrtf(x * x + y * y);
    if (mag <= dz || mag <= 0.0f) { *ox = 0; *oy = 0; return; }
    float clamped = mag > 1.0f ? 1.0f : mag;
    float scale = ((clamped - dz) / (1.0f - dz)) / mag;
    *ox = x * scale;
    *oy = y * scale;
}

static float TriggerDeadzone(float v, float th) {
    if (v <= th) return 0.0f;
    float r = (v - th) / (1.0f - th);
    return r > 1.0f ? 1.0f : r;
}

void ApplyDeadzones(const ControllerState& in, const DeadzoneConfig& cfg, ControllerState* out) {
    *out = in;
    RadialDeadzone(in.lx, in.ly, cfg.stick, &out->lx, &out->ly);
    RadialDeadzone(in.rx, in.ry, cfg.stick, &out->rx, &out->ry);
    out->lt = TriggerDeadzone(in.lt, cfg.trigger);
    out->rt = TriggerDeadzone(in.rt, cfg.trigger);
}
