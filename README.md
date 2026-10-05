# <h1 align="center">WowPad 1.4.0</h1>



Native-feel controller support for the World of Warcraft **3.3.5a (build 12340)**
client, resembling WoW Forever's controller support: move and look with the
sticks, a round controller action bar on the triggers, menus you can drive with
the D-pad, a radial main menu and a crosshair. Client-side only; nothing on the
server changes.

<img width="1913" height="1075" alt="image" src="https://github.com/user-attachments/assets/b38129df-c066-4ca3-9277-1b6577fad361" />

<p align="center">Full D-Pad Menu Navigation</p>
<img width="1910" height="891" alt="image" src="https://github.com/user-attachments/assets/8f643d12-50d5-40cc-ac97-765e88f880cd" />

<p align="center">Radial menu tied to right stick movement selection</p>
<img width="1913" height="1075" alt="image" src="https://github.com/user-attachments/assets/d7ccb686-51ae-4688-9ced-95b79016fdbc" />

<p align="center">Proper Mini Map cursor</p>
<img width="1224" height="810" alt="image" src="https://github.com/user-attachments/assets/0a0acb75-8201-4eab-af09-96ef0768e864" />

<p align="center">Edit Mode with center line snapping</p>
<img width="1398" height="685" alt="image" src="https://github.com/user-attachments/assets/40645374-f35d-4e4f-9b0b-350db39f92c5" />


It has two parts that work together:
- `version.dll` reads the controller and sits next to `Wow.exe`;
- the `WowPad` addon (bar, menus, options) goes in `Interface/AddOns`.

Made and tested on Linux (CachyOS, Faugus Launcher / Proton) with an Xbox-style
pad and the 2026 Steam Controller. Windows has been tested as well.

> Using a DLL with a game is your own call. Ask your server's staff before
> using or sharing it.

## Compatibility
It is currently being tested which addons this is compatible with, but so far
these addons have been either fixed to work or were working by default:
- AIO
- Auctionator
- Bagnon
- DialogUI
- DragonUI and DragonUI New Era (with !!!ClassicAPI)
- Postal
- Questie-335

## Download

Get **WowPad-1.4.0.zip** from the
[Releases page](https://github.com/Oddity-git/WoW-Pad/releases) (not the green
"Code" button: that is the source code). Unzip it and follow **Install** below.

## Requirements

- WoW 3.3.5a client (build 12340).
- An Xbox-style controller (XInput). On Linux under Proton most pads show up
  as one. **Steam Controller:** close Steam while playing, otherwise Steam
  Input takes the controller.
- **WoW's default key bindings.** WowPad is tested with them, with only
  **F** changed (bound to interact, see below). It moves your character by
  pressing W/S and Q/E (strafe); if you moved those, set your keys in
  `wowpad.ini` under `[Move]`. Its own signals use numpad keys and some
  Alt+Ctrl+Shift combos as temporary bindings, so they don't change yours.
- **Windows:** reported working by players (including the Steam Controller
  through Steam). Windows Defender may remove `version.dll`, see Install.
- **Recommended: [Awesome WotLK](https://github.com/someweirdhuman/awesome_wotlk)**
  (client mod by someweirdhuman, based on FrostAtom's original). Its
  interaction keybind is what makes X loot, skin, gather, open doors and
  mailboxes and talk to NPCs. Bind it to **F** (see "X = interact" below).
  WowPad works without it, but then X only starts attacking.


## Install

The release zip mirrors your WoW folder: everything in it goes into the folder
that contains `Wow.exe`.

1. **Copy `version.dll` and `wowpad.ini`** next to `Wow.exe`.
   (Already have a `wowpad.ini` you edited? Keep yours.)
2. **Copy the `WowPad` folder** from `Interface/AddOns/` in the zip into
   your game's `Interface/AddOns/` folder.
   - **Linux:** folder names are case-sensitive. If your game folder has
     `interface/addons` in lowercase, put `WowPad` in *that* folder. Don't
     create a second `Interface/AddOns` next to it.
3. **Linux only: tell Wine to load the DLL.** Add `WINEDLLOVERRIDES=version=n,b`
   to the game's launch settings:

   | Launcher | Where |
   |---|---|
   | **Faugus** | Edit the game > Game Arguments: add `WINEDLLOVERRIDES=version=n,b` at the end |
   | **Lutris** | Configure > Runner options > DLL overrides: `version` = `n,b` |
   | **Bottles** | Bottle > Settings > DLL Overrides: add `version`, "Native, then Builtin" |
   | **Steam (non-Steam game)** | Properties > Launch options: `WINEDLLOVERRIDES="version=n,b" %command%` |
   | **Plain Wine** | `WINEDLLOVERRIDES="version=n,b" wine Wow.exe` |

   Windows needs no setting.

   **Windows Defender may delete `version.dll`.** It reads the controller and
   sends key presses, which antivirus programs sometimes flag. If the game won't
   start with WowPad, or the file disappears: Windows Security > Virus & threat
   protection > **Protection history**, find the item and choose **Restore** /
   **Allow on device**. Adding your WoW folder as an exclusion stops it
   happening again. Scan results: [VirusTotal](https://www.virustotal.com/gui/file/bf24eb36348f25fd63cd9022f1059013810329307207b0106cb7827f7964e258). Its SHA-256 is
   `bf24eb36348f25fd63cd9022f1059013810329307207b0106cb7827f7964e258`, so you can check yours is the original.
4. **Start the game.** A `wowpad.log` appears next to `Wow.exe`; its first
   line says `wowpad 1.4.0 loaded`.

**Updating from an older version?** Replace `version.dll` and the whole
`WowPad` folder, then restart the game fully (a `/reload` doesn't pick up new
addon files).

Your WoW folder should end up like this:
```
Wow.exe
version.dll        <- from the zip
wowpad.ini         <- from the zip
Interface/AddOns/WowPad/   (or interface/addons/WowPad on Linux)
```

### First time in game

1. The **setup window** opens: it checks your controller, movement keys,
   interact key and camera setting, and shows where everything lives. Reopen
   it any time with `/wp firsttime` (or Options > First-time setup).
2. Pick up the controller: WowPad switches to controller mode by itself.
3. Left-click the **gamepad button on the minimap** (or Start > page 3 >
   **Edit Bar**, or `/wp edit`): drag spells, items, macros and mounts onto
   the round slots. Drag bars to move them (they snap to the screen's centre
   line; pull further to let go), mouse wheel to resize. Click again to finish.
4. Right-click the minimap button (or Esc > Interface > AddOns > **WowPad**)
   for sensitivity and other options.


## Controls

| Button | Does |
|---|---|
| Left stick | Move (optional: slight tilt walks, full tilt runs) |
| Right stick | Camera. In menus and pointer mode: the pointer |
| A | Jump |
| B | Clear target / back out of menus |
| X | Interact + start attacking a hostile target |
| Y | Target menu |
| LB / RB | Target nearest friendly / enemy (can be swapped in Options; see Healer mode) |
| LB + RB held | Right stick zooms the camera |
| D-pad | 4 action slots |
| LT / RT / LT+RT held | Left / right / bottom set: D-pad + A/B/X/Y = 8 more slots each |
| L3 | Autorun |
| R3 | Pointer mode: right stick moves a cursor, RT = left click, LT = right click |
| Start | Close windows, open the radial main menu |
| Back | Tap = map, hold = bags |
| Back + A | On-screen keyboard (see Chat); in the keyboard or chat box: send |
| Back + B | Esc: close the keyboard or chat (elsewhere: like the Esc key) |
| Back + Start held 1 s | Kill switch: WowPad stops sending anything |

Mouse or keyboard input switches back to normal desktop control at once;
any controller input switches to controller mode.

### In menus (a window open, out of combat)

| Button | Does |
|---|---|
| D-pad / right stick | Move the selection (at the end of a list, the D-pad scrolls it) |
| A | Click |
| X | Right-click (use, equip, sell). Quest log: track / untrack the quest |
| Y tap / hold | Preview gear in the dressing room / compare with what you wear |
| L3 (in bags) | Item actions: Disenchant (if you can), Destroy (asks first), Cancel (preselected) |
| LB / RB | Switch between open windows |
| B | Close / cancel (Esc menu: Return to Game, option windows: Cancel) |

A hint bar under the window shows what the buttons do for the selected item.
Works with default bags and with bag addons such as Bagnon. Each open window
remembers its selection, so switching windows or selling an item doesn't send
you back to the top.

**Dungeon finder and loot rolls:** when a dungeon is ready, the window gets the
selection with **Enter Dungeon** selected (B = Leave Queue). Group loot rolls
get it too, with Need (or Greed) selected (B = Pass, Y = preview / compare the
item). In combat these windows leave your controls alone; roll when the fight
is over.

### Chat: on-screen keyboard

**Back + A** opens a small keyboard above the chat window (controller mode, out
of combat). It's meant for short messages and commands like `/reload`; a real
keyboard (or the Steam Deck's) works as usual.

| Button | Does |
|---|---|
| D-pad | Move between keys |
| A / X | Type / type a capital |
| Y | Space |
| B | Delete a letter (on an empty line: close) |
| LB / RB | Channel: Say, Party, Guild, Raid, Reply |
| Start or Back + A | Send |
| Back + B | Close |

Slash commands work (`/reload`, `/w name ...`). You can also click the keys
with the mouse or a touchpad. Don't need it? Turn off **On-screen keyboard** in
Options: Back + A then just opens the normal chat box, and Back + A / Back + B
send or close it while you type.

### World map

The map gets its own cursor: a gold diamond with crosshair lines, plus cursor
and player coordinates.

| Button | Does |
|---|---|
| Right stick | Move the cursor |
| A | Zoom in on the zone under the cursor (on a pin: click the pin) |
| X | Zoom out |
| D-pad | Jump between pins and map buttons |
| B | Back a level (zone, continent, world), then close |

### Ground-targeted spells

Spells you aim at the ground (Blizzard, Flare, Death and Decay, ...): aim with
the camera, then press **A** or **the same button again** to place the spell at
the crosshair. **B** cancels. A hint above the cast bar shows this while you
aim. Let the camera come to rest before placing; placing while it's still
turning can cause a small hiccup. Needs Hardware Cursor (Esc > Video, on by
default).

### Healer mode

Off by default: Options > Buttons > **Healer mode**, then **Apply**.

- **Tap** your ally bumper (LB, or RB if you swapped them) to target your last
  party pick (you at first).
- **Hold** it and flick the right stick **down / up** for the next / previous
  party member (you, then party 1-4). Left / right still turns the camera.
- A gold frame briefly marks the picked member's unit frame.

Works in combat. With healer mode off, the ally bumper targets the nearest
friendly as before.

### Utility ring

Eight spells, items or macros on one button. Options > WowPad > Bars >
**Utility ring**: pick the button that opens it (a D-pad button, or any slot
in the LT, RT or LT+RT set), then **Apply**. Fill its eight wedges in **Edit bar layout** (the ring shows in
the middle of the screen). In game: hold the button, point the right stick at a
wedge, let go to use it. Let go in the middle to cancel. Works in combat.

### Lite bar

Options > WowPad > Bars > **Lite mode** shows one cluster instead of four: your
default set, and while you hold LT, RT or both, that set in its place (a small
badge says which). It has its own position and size, and can sit right on the
bottom edge of the screen. In **Edit bar layout**, tabs above it (Default / LT /
RT / LT+RT) pick which set you're filling.

### Main menu (Start)

A radial wheel with three pages (LB / RB). Point the right stick at a wedge
and press A; B or Start closes it.

### X = interact

X presses whatever is bound to your **F** key, plus starts auto attack on a
hostile target. 3.3.5 has no retail-style interact key ("interact with
what's in front of me"); [Awesome WotLK](https://github.com/someweirdhuman/awesome_wotlk)
adds one. It loots and skins mobs and interacts with nearby objects (veins,
chairs, doors, mailboxes) and NPCs.

1. Install Awesome WotLK: unpack its release into the WoW folder, then run
   `AwesomeWotlkPatch.exe` once (or drag `Wow.exe` onto it). On Linux, run
   it with the same Wine/Proton your launcher uses.
2. In game: Esc > Key Bindings, find Awesome WotLK's **interaction** binding
   and set it to **F**. (Or make a macro with `/interact` and bind that to F.)
3. Type `/wp interact`. It should say
   `Interact follows key F -> INTERACTIONKEYBIND`.

Prefer another key? `/wp interact KEY` makes X follow that key instead.
Awesome WotLK's `interactionMode` and `interactionAngle` settings tune what
it picks; see its page.


## Options

Esc > Interface > AddOns > WowPad (or `/wp options`). Settings marked `*`
need **Apply** (reloads the UI).

- **Sticks:** camera sensitivity, pointer speed, zoom speed, invert camera.
- **Crosshair:** dot on/off, crosshair tooltips ("peek") and peek delay.
  Keep **crosshair tooltips on**: turning it off is experimental, the camera
  can jump after closing a window.
- **Buttons:** X also starts auto attack; swap LB / RB targeting; healer mode;
  on-screen keyboard.
- **Messages:** status line, debug messages.
- **Experimental:** walk/run by stick tilt, smooth camera (glides the camera;
  `[Camera] SmoothMs` in `wowpad.ini` sets how much).

**WowPad > Bars** (click the `+` next to WowPad in the list):

- **Controller bar:** always visible, hide Blizzard's bars, size, edit layout.
- **Lite mode:** one cluster at a time (see "Lite bar" above).
- **Utility ring:** which button opens it (see "Utility ring" above).
- **Extra bars:** WowPad's own XP bar, reputation bar, pet bar and movable
  cast bar. Each can be turned off, e.g. to use another addon's version
  instead. Move and resize them in **Edit bar layout**.
- **Minimap:** show or hide the minimap button (left-click: edit layout,
  right-click: options, drag to move it around the minimap).

Advanced settings (deadzones, key names, speeds) are in `wowpad.ini` next to
`Wow.exe`; restart the game after editing it.

Chat commands: `/wp firsttime`, `/wp options`, `/wp edit`, `/wp scale 0.8`, `/wp bar`,
`/wp blizz`, `/wp crosshair`, `/wp peek`, `/wp sens 0.5`, `/wp interact KEY`,
`/wp xattack`, `/wp status`, `/wp debug`, `/wp navinfo`.


## Troubleshooting

- **Nothing happens with the controller:** check `wowpad.log` exists. No log =
  the DLL isn't loading: the `WINEDLLOVERRIDES=version=n,b` setting is missing
  or in the wrong place. Log says no controller: close Steam, reconnect the pad.
- **Hand/sword cursor visible over the crosshair:** turn on Hardware Cursor
  (Esc > Video).
- **Game won't start, or `version.dll` vanished (Windows):** Windows Defender
  removed it, see Install.
- **Camera jumps after closing a menu:** turn crosshair tooltips (peek) on.
- **X doesn't interact:** `/wp interact` shows what F is bound to.
- **Ground-targeted spells don't place:** turn on Hardware Cursor (Esc > Video)
  and let the camera come to rest before pressing.
- **A Lua error mentions WowPad:** send the error text and `wowpad.log`.
- **Crosshair stuck somewhere other than its usual spot:** press R3 twice
  (pointer mode on, then off). That puts it back.
- **Steam Deck (or another low resolution) with UI scale maxed: the radial menu
  goes partly off the right edge:** turn off UI scaling (Esc > Video) until
  this is fixed.
- **Stuck input / something odd:** hold Back + Start for 1 second (kill
  switch), or touch the mouse/keyboard.


## Planned / TODO
- radial menu customization, currently on steam deck if you max out UI scale the radial goes off screen a bit
- Turning crosshair tooltips (peek) off without the camera jumping after
  closing a window.
- Assigning action bar slots with the controller (picking from the
  spellbook) instead of dragging with the mouse.
- Steam Controller extras: trackpads, gyro and back buttons.

Have an idea or found a bug? Open an issue with your `wowpad.log`.


## Uninstall

Delete `version.dll` next to `Wow.exe` and the `WowPad` folder in
`Interface/AddOns`. On Linux, remove the `WINEDLLOVERRIDES` launch setting
too. Your `wowpad.ini` and `wowpad.log` stay
until you delete them.

## How this was made

WowPad is 100% vibe-coded. Every line of the DLL and the addon was written by
Claude (Anthropic's AI) in one long conversation, while I played the game and
said what I wanted: "the bar should be round", "B should back out of menus",
"the hand cursor flickers when the camera stops". I tested each build in game
and sent back logs, screenshots and Lua errors; Claude read them, fixed things
and sent the next version. Many versions later, this is the one that plays
the way I wanted.

What that means for you: the design and testing are a player's, the code is
an AI's, and it has only been tested on one setup (Linux, Faugus/Proton, an
Xbox-style pad and the Steam Controller). It works well for me. If something
breaks on yours, open an issue with your `wowpad.log` and what you were
doing; that's exactly how it got built.

## Credits

- WowPad: made for a private AzerothCore setup, with Claude (Anthropic).
- Interact: [Awesome WotLK](https://github.com/someweirdhuman/awesome_wotlk)
  by someweirdhuman, based on [FrostAtom's awesome_wotlk](https://github.com/FrostAtom/awesome_wotlk).
  Not included in this package; get it from its page.
- Icons and cursors used by the addon are the game's own files; nothing from
  Blizzard is bundled.


## Building from source

The DLL is built on Linux with MinGW (`i686-w64-mingw32-g++`): run `./build.sh`,
the result is `build/version.dll`. Code layout, signal design and launcher
details are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md); the test checklist
history is in [docs/TESTING.md](docs/TESTING.md).

## License

[MIT](LICENSE). Awesome WotLK is a separate project with its own license.
