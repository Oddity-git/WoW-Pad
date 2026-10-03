# WowPad 1.0.0

Native-feel controller support for the World of Warcraft **3.3.5a (build 12340)**
client, in the style of WoW's console version: move and look with the sticks,
a round controller action bar on the triggers, menus you can drive with the
D-pad, a radial main menu and a crosshair. Client-side only; nothing on the
server changes.

It has two parts that work together:
- `version.dll` reads the controller and sits next to `Wow.exe`;
- the `WowPad` addon (bar, menus, options) goes in `Interface/AddOns`.

Made and tested on Linux (CachyOS, Faugus Launcher / Proton) with an Xbox-style
pad and the 2026 Steam Controller. Windows should work but is untested.

> Using a DLL with a game is your own call. Ask your server's staff before
> using or sharing it.


## Download

Get **WowPad-1.0.0.zip** from the
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
- **Hardware Cursor** turned on: Esc > Video > Hardware Cursor. The crosshair
  needs it to hide the hand/sword cursor.
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

   Windows needs no setting (untested on Windows; an antivirus may question
   the DLL because it reads input and sends key presses).
4. **Start the game.** A `wowpad.log` appears next to `Wow.exe`; its first
   line says `wowpad 1.0.0 loaded`.

Your WoW folder should end up like this:
```
Wow.exe
version.dll        <- from the zip
wowpad.ini         <- from the zip
Interface/AddOns/WowPad/   (or interface/addons/WowPad on Linux)
```

### First time in game

1. Esc > Video > **Hardware Cursor** on.
2. Pick up the controller: WowPad switches to controller mode by itself.
3. Start > page 3 > **Edit Bar** (or `/wp edit`): drag spells, items, macros
   and mounts onto the round slots. Drag the bar to move it, mouse wheel to
   resize. `/wp edit` again to finish.
4. Esc > Interface > AddOns > **WowPad** for sensitivity and other options.


## Controls

| Button | Does |
|---|---|
| Left stick | Move (optional: slight tilt walks, full tilt runs) |
| Right stick | Camera. In menus and pointer mode: the pointer |
| A | Jump |
| B | Clear target / back out of menus |
| X | Interact + start attacking a hostile target |
| Y | Target menu |
| LB / RB | Target nearest friendly / enemy |
| LB + RB held | Right stick zooms the camera |
| D-pad | 4 action slots |
| LT / RT / LT+RT held | Left / right / bottom set: D-pad + A/B/X/Y = 8 more slots each |
| L3 | Autorun |
| R3 | Pointer mode: right stick moves a cursor, RT = left click, LT = right click |
| Start | Close windows, open the radial main menu |
| Back | Tap = map, hold = bags |
| Back + Start held 1 s | Kill switch: WowPad stops sending anything |

Mouse or keyboard input switches back to normal desktop control at once;
any controller input switches to controller mode.

### In menus (a window open, out of combat)

| Button | Does |
|---|---|
| D-pad / right stick | Move the selection |
| A | Click |
| X | Right-click (use, equip, sell) |
| Y tap / hold | Preview gear in the dressing room / compare with what you wear |
| L3 (in bags) | Destroy the selected item (asks first, Cancel is preselected) |
| LB / RB | Switch between open windows |
| B | Close / cancel |

A hint bar under the window shows what the buttons do for the selected item.
Works with default bags and with bag addons such as Bagnon.

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
- **Crosshair:** dot on/off.
- **Controller bar:** always visible, hide Blizzard's bars, size, edit layout.
- **Buttons:** X also starts auto attack.
- **Messages:** status line, debug messages.
- **Experimental:** walk/run by stick tilt, crosshair tooltips ("peek"),
  peek delay. Keep **crosshair tooltips on**: with it off the camera can
  jump after closing a menu.

Advanced settings (deadzones, key names, speeds) are in `wowpad.ini` next to
`Wow.exe`; restart the game after editing it.

Chat commands: `/wp options`, `/wp edit`, `/wp scale 0.8`, `/wp bar`,
`/wp blizz`, `/wp crosshair`, `/wp peek`, `/wp sens 0.5`, `/wp interact KEY`,
`/wp xattack`, `/wp status`, `/wp debug`, `/wp navinfo`.


## Troubleshooting

- **Nothing happens with the controller:** check `wowpad.log` exists. No log =
  the DLL isn't loading: the `WINEDLLOVERRIDES=version=n,b` setting is missing
  or in the wrong place. Log says no controller: close Steam, reconnect the pad.
- **Hand/sword cursor visible over the crosshair:** turn on Hardware Cursor.
- **Camera jumps after closing a menu:** turn crosshair tooltips (peek) on.
- **X doesn't interact:** `/wp interact` shows what F is bound to.
- **A Lua error mentions WowPad:** send the error text and `wowpad.log`.
- **Stuck input / something odd:** hold Back + Start for 1 second (kill
  switch), or touch the mouse/keyboard.


## Uninstall

Delete `version.dll` next to `Wow.exe` and the `WowPad` folder in
`Interface/AddOns`. On Linux, remove the `WINEDLLOVERRIDES` launch setting
too. Your `wowpad.ini` and `wowpad.log` stay
until you delete them.


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
