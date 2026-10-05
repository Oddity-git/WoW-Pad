// inject.h - synthetic keyboard/mouse input into the game.
//
// Every event carries dwExtraInfo = WOWPAD_INPUT_TAG so hooks.cpp can tell
// our events apart from the user's real keyboard/mouse.
// Held keys/buttons are tracked so Inject_ReleaseAll() can never leave
// anything stuck (focus loss, kill switch, mode switch, shutdown).
#pragma once
#include <windows.h>

#define WOWPAD_INPUT_TAG ((ULONG_PTR)0x57504144) // 'WPAD'

enum InjectMode { INJECT_SENDINPUT = 0, INJECT_POSTMESSAGE = 1 };
enum MouseBtn   { MOUSE_LEFT = 0, MOUSE_RIGHT = 1 };

void Inject_SetMode(InjectMode m);
void Inject_Key(BYTE vk, bool down);           // no-op if already in that state
void Inject_MouseButton(MouseBtn b, bool down); // no-op if already in that state
void Inject_MouseMove(int dx, int dy);          // relative, pixels
void Inject_MouseWheel(int notches);            // + = away from you (zoom in)
void Inject_ReleaseAll();
