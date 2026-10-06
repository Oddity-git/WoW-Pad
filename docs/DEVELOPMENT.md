# wowpad

Native-feel controller support for the WoW 3.3.5a (12340) client under Wine.
Client-side only. DLL `version.dll` + addon `WowPad`. Player-facing documentation is in
the README; this file covers how it works inside.

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

How signals work (found by testing in the client): the DLL presses numpad keys the
addon has bound. Anything that can cast uses an unmodified numpad key; a secure
header re-points the 8 slot keys when triggers are held (works in combat).
`scripts/check_signals.py` keeps `src/signals.cpp` and
`addon/WowPad/Signals.lua` in sync (run by build.sh).

## Layout

```
src/controller.h          GetControllerState() interface (backend-neutral)
src/controller_xinput.cpp XInput backend (an SDL3 backend could replace this file)
src/controller_filter.cpp Radial stick deadzone + trigger threshold
src/worker.cpp            Background thread: poll loop + change logging
src/mapper.cpp            Controller mode: mode detection, sets, pointer mode, healer flicks,
                          utility ring, Back+A/B, ground-target place/cancel
src/cursorhide.cpp        SetCursor hook: hides the cursor while peeking, recognises the
                          game's cast cursor (ground targeting)
src/addonsettings.cpp     Reads the addon's wp* settings from SavedVariables
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
./build.sh            # -> build/version.dll (x86 PE, imports only KERNEL32, USER32, GDI32, msvcrt)
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

## 1.3.0 notes
- **Chat (Back + A / Back + B):** while a chat edit box has focus, WoW gives it every key: the addon's
  bindings never fire and the box doesn't report the pad's keys to addons (no OnKeyDown/OnChar for them).
  So the DLL sends real `VK_RETURN` / `VK_ESCAPE` for Back+A / Back+B (mapper.cpp); the chord eats the A/B
  slot press and Back's own map/bags action. The addon only shows a hint above the chat box.
- **Menu roots added:** `LFDDungeonReadyDialog` and `GroupLootFrame1-4` (WP.PopupRoots in Core.lua). They
  count as open windows only out of combat, so in combat they never take the camera or rebind the pad.
- **Selection memory:** Nav.memory[root] = last node + screen position, kept while the window is open;
  if the node disappears the nearest node is picked.
- **List scrolling:** Collect() also gathers visible ScrollFrames; nodes scrolled out of a real ScrollFrame
  are skipped (scroll-bar buttons exempt). D-pad up/down at a list edge moves the list's scroll bar by one
  row height (TryScroll in Nav.lua).
- **Item actions (ItemActions.lua):** L3 in bags opens Disenchant (secure macro button, only if
  IsSpellKnown(13262) and the item is green-epic armor/weapon) / Destroy (existing confirm) / Cancel.
- **Lite bar:** the four clusters are SecureHandlerBaseTemplate frames; in lite mode they all sit at the bar
  centre and the header's attribute snippet shows only the active one (works in combat). Position/scale are
  saved separately in WowPadDB.bar.lite; edit-mode tabs set the header attribute `liteview`.
- **New addon file** (ItemActions.lua): WoW reads the TOC file list at game start; a /reload is not enough.

## 1.3.1 notes
- **FirstTime.lua:** setup/welcome window. Opens once per addon version (WowPadDB.firstTimeSeen = TOC version):
  new installs on the setup check, people with existing settings on "What's new" (WHATS_NEW table, newest
  first). Live checks: controller seen, movement binds W/S/Q/E, interact key binding, cameraSmoothStyle
  (button sets 0), Hardware Cursor (gxCursor) only as a tip. /wp firsttime; Options button. New file: needs
  a full game restart after updating.
- **Other addons' windows:**
  - `WP.EXTRA_WINDOWS` (Core.lua): windows that aren't UI panels or in UISpecialFrames (DialogUI's
    DGossipFrame). DialogUI's DQuestFrame grabs the keyboard; Nav releases it in controller mode.
  - `SHOWS_ONLY` (Nav.lua): in those windows only buttons with visible text/texture count (DialogUI keeps
    invisible clickable buttons).
  - `WP.Cloaked(f)`: windows with effective alpha < 0.05 or entirely off-screen are ignored (New Era
    "cloaks" Blizzard's TradeSkillFrame instead of hiding it, and it stays a UI panel).
  - B uses `root.CloseButton` when the close button has no name (New Era, modern templates).
  - `ATTACHED` (Nav.lua): separate side frames navigated with a window (New Era's NE_ProfessionsTabs).

## 1.4.0 notes
- **On-screen keyboard (Keyboard.lua):** Back + A makes the DLL press Enter; the chat box takes focus and, in
  controller mode, the addon closes it and opens its own keyboard instead (lazy-built, never created when the
  option is off). Sends through `ChatEdit_SendText`, so slash commands work. In UISpecialFrames, so Back + B
  (Esc) closes it. New file: needs a full game restart after updating.
- **Healer mode (wpBumperFlick, off by default):** the DLL engages it only after a bumper is held alone for
  150 ms (taps never stop the camera), then sends LB/RB_FLICK_DOWN/UP for right-stick flicks and zeroes the
  camera's vertical axis. The addon binds the ally bumper's flicks to secure WowPadPartyNext/Prev buttons
  (stepping player, party1-4) and its tap to WowPadPartyCurrent. PartyHighlight.lua finds unit frames by
  their `unit` attribute and draws a gold frame (driver frame for OnUpdate: a hidden frame never updates).
- **Utility ring (wpRingSlot = set*10 + button):** while that slot's button is held, the DLL turns the right
  stick into RING_DIR_0..8 signals (CTRL-SHIFT-F1..F9; centre only after 200 ms) instead of camera motion.
  The addon's WowPadRingKey is clicked on key down and up; a wrapped snippet shows the ring on down and on up
  copies the chosen wedge's type/spell/item/macro onto itself and fires. Wedges are bar slots of set 9.
  Shares its art with the main radial (`WP.BuildWheelArt`).
- **Ground-targeted spells:** the addon can't click the world in combat, so the DLL does it. cursorhide.cpp
  checks every cursor the game sets for the game's own cast cursor by its look (50-80 % of pixels visible,
  average colour blue); aiming stays on until a cursor of another shape appears (the greyed "unable to cast"
  hand has the same shape). While aiming, A or the same slot button = injected left click at the crosshair,
  B = Esc; that press is eaten. If camera look is on, the DLL pauses it first (CAM_IDLE), because a left
  click during camera look counts as both mouse buttons (a step forward). Menus: while aiming with a window
  open, the addon keeps setting its fully transparent blank cursor, which the DLL reads as "leave A alone".
  An addon-set marker cursor was tried first: WoW delivered it fully transparent.
- **Menus:** GameMenuFrame and the option windows are in `WP.EXTRA_WINDOWS`; B presses Return to Game /
  Cancel (generic fallback: a visible child named `*Cancel` / `*CancelButton`). Quest log: X toggles the
  watch on the selected quest (`Nav.TrackQuest`). Loot-roll hint includes Y (preview / compare).
- **Leave Vehicle button** stays visible when Blizzard's bars are hidden (moved to UIParent).

- **Keyboard in text fields:** A on an EditBox in a window calls `WP.OpenKeyboardFor` (Nav's A/X clicker)
  instead of focusing it. Field mode types into the box as you go (`IsNumeric` boxes take digits only,
  `GetMaxLetters` is respected); Start / Back + A sets the text and runs the box's OnEnterPressed; closing
  without it (Esc) puts the old text back (OnHide). The chat line you had started is kept for later.
- **Immersion:** `ImmersionFrame` is in `WP.EXTRA_WINDOWS`. It has no size of its own, so the selection box
  and hint bar use its TalkBox and TitleButtons. Starts on the first option, else the TalkBox (A = left click:
  continue / accept / complete, X = right click: skip / repeat text). B = TalkBox.MainFrame.CloseButton.
- **Mailbox:** `OpenMailFrame` is its own window (in `WP.EXTRA_WINDOWS`), so opening a letter takes the
  selection (attachment, money, letter, Reply).
- **Auction house:** rows (Browse / Bid / Auctions buttons) aren't stops, only their `...Item` icons. The
  listing rows sit beside their faux scroll frame, so TryScroll also accepts the nearest scroll bar right
  beside the row (within 40 px of the row's right end, so the categories never scroll the listings). Money
  displays (`*MoneyFrameGold/Silver/CopperButton`) and `BrowseBidPrice*` are never stops.
- **Set outline:** `Textures/outline.tga` (scripts/make_outline.py), thinner than glow.tga; 45 % alpha on the
  default set.

## 1.4.1 notes (addon only; version.dll unchanged from 1.4.0)
- **Set outline:** same strength on all four sets. It sits on its own holder frame (level +5) above the slot ring: textures in the same draw
  layer have no fixed order, so the ring could cover it. Button icons / D-pad arrows sit at +6.
- **Queued / auto-repeat glow:** the slot's CheckedTexture is the glow; `Bar.UpdateState` checks
  `IsCurrentSpell` / `IsAutoRepeatSpell` on CURRENT_SPELL_CAST_CHANGED etc. (Heroic Strike, Auto Shot).
- **Rounded corners:** selection box, window outline and edit-mode bar box use a tooltip-style rounded
  backdrop border.
- **Button styles (Glyphs.lua):** `WowPadDB.buttonStyle` = "xbox" / "ps". Face buttons are icons
  (`Textures/btn_xb_*`, `btn_ps_*`, scripts/make_button_glyphs.py), the rest are names (L1/R1, L2/R2,
  Share, Options). `WP.Keys("LB / RB")`, `WP.Text("press {A}")`, `WP.KeyText(fs, raw)` (relabels on style
  change), `WP.KeysPlain` (dropdowns). Inline icons drift up / down differently per window, so hint bars,
  the radial hint, the ground-target hint and the setup window lay text out piece by piece (icon / words,
  each placed by its middle): `WP.NewKeyLine`, and FirstTime.lua's own wrapping layout.
- **Radial art:** WoW Forever-style separate rounded tiles (scripts/make_radial_art.py), warm translucent
  fill; shared by the main menu and the utility ring.
- **Movable radials:** `WP.MakeMover(frame, key, label, size)` / `WP.ApplyMoverPos` (Snap.lua) save
  `WowPadDB.movers[key] = {x, y, scale}`, clamped to the screen, mouse wheel 0.5-1.5. The main menu shows in
  Edit bar layout with a full mover box; the ring gets a hub-only handle so its wedges still take drops.
