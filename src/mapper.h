// mapper.h - Phase 2 "desktop emulation": pad -> cursor, clicks, camera, movement.
#pragma once
#include "controller.h"

// Call once per poll tick with deadzoned state. dt in seconds.
void Mapper_Update(const ControllerState& s, double dt);
// Releases everything held (used on shutdown/disconnect).
void Mapper_Reset();
