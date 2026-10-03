# wowpad

Native-feel controller support for the WoW 3.3.5a (12340) client under Wine.
Client-side only. Current state: **Phase 5 + polish** (round controller action
bar, menus, quiet chat). Phase 6 (2026 Steam Controller) pending hardware. DLL `version.dll` + addon `WowPad`.

## Controls (controller mode)

| Pad | Does |
|---|---|
| Left stick | Move (W/S, Q/E strafe) |
| Right stick | Camera; moves the pointer when a window is open |
| A / B / Y | Jump / clear target / target menu |
| X | Interact (whatever is bound to F) + start attack (`/wp xattack` toggles the attack part) |
| L3 | Autorun |
| D-pad (no trigger) | 4 assignable slots on the controller bar |
| LT / RT / LT+RT held | Left / right / bottom set: D-pad + ABXY = 8 slots each |
| LB / RB | Target nearest friendly / hostile |
| LB + RB held | Right stick up/down zooms the camera (hint at top of screen) |
| Start | Close open windows (like Esc) and open the main menu wheel; again = close wheel |
| Back: tap / hold | World map / bags |
| R3 | Pointer mode on/off (right stick = pointer, RT/LT = left/right click) |
| Back + Start, hold 1 s | Kill switch |

Mode switches automatically: any pad input -> controller; a real key press,
mouse click or mouse movement -> desktop. In desktop mode the DLL sends nothing
and the addon removes all its numpad bindings, so your keyboard is untouched.

How signals work (from the Phase 3a probe): the DLL presses numpad keys the
addon has bound. Anything that can cast uses an unmodified numpad key; a secure
header re-points the 8 slot keys when triggers are held (works in combat).
`scripts/check_signals.py` keeps `src/signals.cpp` and
`addon/WowPad/Signals.lua` in sync (run by build.sh).

## Layout

```
src/controller.h          GetControllerState() interface (backend-neutral)
src/controller_xinput.cpp XInput backend (swap this file for SDL3 in Phase 6)
src/controller_filter.cpp Radial stick deadzone + trigger threshold
src/worker.cpp            Background thread: poll loop + change logging
src/mapper.cpp            Controller mode: mode detection, sets, nav, pointer mode
src/signals.cpp           Signal -> key table (must match addon/WowPad/Signals.lua)
src/hooks.cpp             Low-level hooks: detects real keyboard/mouse input
src/inject.cpp            SendInput / PostMessage injection, tagged, release-all
src/gamewindow.cpp        Finds the game window, focus check
src/names.cpp             Button/key names for wowpad.ini
src/dllmain.cpp           DllMain: spawns the worker thread, nothing else
src/version_proxy.cpp     Forwards the real version.dll API (lazy-loaded)
src/version.def           Export names
src/log.cpp, config.cpp   wowpad.log / wowpad.ini next to Wow.exe
scripts/check_wow_imports.sh  Confirms Wow.exe imports VERSION.dll
scripts/check_signals.py  DLL/addon signal table consistency
addon/WowPad/             The addon (copy to Interface/AddOns)
```

## Build

```sh
./build.sh            # -> build/version.dll (x86 PE, imports only KERNEL32, USER32, msvcrt)
make clean
```

Needs `i686-w64-mingw32-g++` (`g++-mingw-w64-i686` on Debian/Ubuntu,
`mingw32-gcc-c++` on Fedora, `mingw-w64-gcc` on Arch).

## Install

1. Check that your client actually imports VERSION.dll (once):
   ```sh
   scripts/check_wow_imports.sh "/path/to/WoW/Wow.exe"
   ```
2. Copy `build/version.dll` and (optional) `wowpad.ini` next to `Wow.exe`.
3. Set the DLL override `version=n,b` (native first, then builtin) for the
   game in your launcher (below).
4. Start the game and watch the log:
   ```sh
   tail -f "/path/to/WoW/wowpad.log"
   ```

To uninstall, delete `version.dll` from the game folder (the override can stay;
with no native DLL present Wine falls back to builtin).

## Launch line per launcher

The override must apply to the **game process**. Pick yours:

**Faugus Launcher** (verified)
Edit the game -> Tools -> Game Arguments: add `WINEDLLOVERRIDES=version=n,b`
at the end of the arguments line, then Ok. Faugus applies it as an environment
variable and Proton merges it with its own overrides.

**Plain Wine**
```sh
cd "/path/to/WoW"
WINEPREFIX="$HOME/.wine-wow" WINEDLLOVERRIDES="version=n,b" wine Wow.exe
```
Alternative that persists in the prefix: `WINEPREFIX=... winecfg` -> Libraries
-> add `version` -> Edit -> "Native then Builtin". (That applies to every app in
the prefix.)

**Lutris**
Right-click the game -> Configure -> Runner options -> DLL overrides -> add
key `version`, value `n,b`. Or System options -> Environment variables ->
`WINEDLLOVERRIDES` = `version=n,b`.

**Bottles**
Bottle -> Settings -> DLL Overrides -> add `version`, set to "Native, then
Builtin". Or set `WINEDLLOVERRIDES=version=n,b` in the program's environment
variables.

**Proton (WoW added as a non-Steam game)**
Properties -> Launch options:
```
WINEDLLOVERRIDES="version=n,b" %command%
```
While testing, set the game's Steam Input to **Disabled** (Properties ->
Controller). Otherwise Wine sees Steam's virtual pad, and your existing
template may also be sending keys, which muddies the log.

## The real version.dll

The proxy loads the real API from `system32\version.dll`. Under Wine 9.0 that
was verified to give Wine's builtin (not the proxy itself). If your
`wowpad.log` says `ERROR could not load a real version.dll`, copy Wine's own
32-bit DLL next to Wow.exe as `version_orig.dll`, e.g.

```sh
cp /usr/lib/i386-linux-gnu/wine/i386-windows/version.dll "/path/to/WoW/version_orig.dll"
# path varies by distro/runner: /usr/lib/wine/i386-windows/, /usr/lib32/wine/i386-windows/,
# or <runner dir>/lib/wine/i386-windows/ (Lutris/Bottles/Proton ship their own)
```

`version_orig.dll` is always tried first when it exists.

## In menus (window open, out of combat)

D-pad moves the gold selection box, A clicks, X right-clicks (use/sell items),
B closes/cancels, LB/RB switch between open windows (or radial pages). The
right stick moves the pointer, and whatever it hovers becomes the selection.
Clicks go through secure buttons, so protected actions (using items, selling)
work. Radial menu and target menu are out of combat only for now.

## Controller action bar

Shown in controller mode. Four pad-shaped clusters: top (no trigger: D-pad
slots + fixed A/B/X/Y), LT, RT and LT+RT (8 slots each). The cluster you're
holding lights up. Start > page 3 > Edit Bar (or `/wp edit`) to drag spells,
items, macros and mounts onto slots, move the bar and resize it (mouse wheel or
`/wp scale 0.8`). Slots are saved per character and per spec; position and
size are account-wide. Your real action bars are never changed.

## Blizzard bars

By default WowPad hides Blizzard's bottom UI (main bar and art, XP/rep, bag
buttons, micro menu, bottom/side bars, stance/pet/possess bars) the way
Bartender does, by re-parenting them to a hidden frame. The vehicle bar is kept.
`/wp blizz` toggles. WowPad has its own XP/reputation bar and pet bar instead,
both movable and resizable in Edit Bar mode. The controller bar is always visible (`/wp bar` switches to
controller-mode-only).

## Crosshair

In controller mode a dot marks where WoW's hidden pointer is. When the right
stick rests, camera look pauses briefly ("peek") so WoW shows the tooltip of
the unit under the dot; the cursor itself stays hidden. Requires WoW's
**Hardware Cursor** (Video options). The pointer snaps to the crosshair spot
(`[Camera] CrosshairY`) when you leave mouse mode, R3 pointer mode or a menu.
`/wp crosshair`, `/wp peek` toggle.

## Options panel
Esc > Interface > AddOns > WowPad (or `/wp options`).
- **Sticks** (need **Apply**, which reloads the UI): camera sensitivity, pointer speed, zoom speed (percent of the `wowpad.ini` values), invert camera up/down. The DLL reads these from `WTF\Account\<name>\SavedVariables\WowPad.lua`, which WoW writes on /reload or logout. `/wp sens 0.5` sets the camera one from chat.
- **Crosshair**: dot on/off, peek mode (experimental, tooltips at the crosshair), peek delay (experimental, needs Apply).
- **Controller bar**: always visible, hide Blizzard bars, bar size, edit layout.
- **Buttons**: X also starts auto attack. **Messages**: status line, debug messages.

## Walk / run on stick tilt (experimental, off by default)
Options > Sticks > "Walk on slight tilt, run on full tilt", then Apply. A slight left-stick tilt walks, full tilt runs, using the game's own Run/Walk toggle (bound by the addon to Alt-Ctrl-Shift-F9). Stopping always returns to running. Thresholds: `[Move] WalkBelow / RunAbove / WalkDelayMs` in wowpad.ini. If you press the keyboard Run/Walk key yourself, slight and full tilt swap until you press it again.

## Menus: preview and destroy
With a window open (no trigger held): **Y tap** previews the selected item in the dressing room (gear only), **Y hold** compares it with what you wear. In bags, **L3** destroys the selected item after a confirmation popup with *Cancel* selected (A on Destroy to confirm, B cancels). The hint bar under the window shows what Y and L3 do for the selected item.
