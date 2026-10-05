// mapper.h - controller mode: pad -> movement, camera/pointer, clicks, signals.
#pragma once
#include "controller.h"

// Call once per poll tick with deadzoned state. dt in seconds.
void Mapper_Update(const ControllerState& s, double dt);
// Releases everything held (used on shutdown).
void Mapper_Reset();
