# TESTING

What to verify in-game after each phase. Paste anything odd from
`wowpad.log` back to me. (fish: `set -U G /path/to/WoW`
once, then `$G/wowpad.log` works in every terminal.)

## Phase 1: DLL scaffold and XInput logging — PASSED 2026-10-02

- wow.exe imports VERSION.dll; proxy loads via Faugus Game Arguments
  `WINEDLLOVERRIDES=version=n,b` (does not load without it).
- Real version API from system32 (no version_orig.dll needed).
- xinput1_4.dll, pad on slot 0. All 15 buttons, both sticks (full range, clean
  return, no drift at 0.24 deadzone), both triggers, unplug/replug OK.
- Pad input keeps arriving while the game is unfocused -> DLL gates on focus.

## Phase 2: Virtual cursor and camera — PASSED 2026-10-02

Result: SendInput works under Proton (no PostMessage fallback needed). Window
class `GxWindowClassD3d`, 1920x1080. Pointer, RT/LT clicks, RB mouselook
(camera turns), left-stick movement incl. diagonals, kill switch, and
release-on-alt-tab all behave as designed.


Install: copy the new `dist/version.dll` and `wowpad.ini` over the old ones
(your old wowpad.ini lacks the new sections; defaults apply if you keep it).

Start: `head -n 12 $G/wowpad.log` should show `0.2.0-phase2`, the config
block, `Injection mode: SendInput`, and `Game window found: class '...'`.
Note the class name.

In-game, pad only:
- [ ] Log shows `Injection active (game focused)` once you're in the game.
- [ ] Right stick moves the mouse pointer; slow near centre, fast at the edge.
      Hold LB: pointer slows down. Pointer stops at the window edges.
- [ ] RT clicks UI buttons (open the spellbook/bags from the micro menu).
- [ ] LT right-clicks: talk to an NPC, loot a corpse, use a bag item.
- [ ] Hold RB + right stick: camera turns with the character (mouselook),
      pointer hidden. Release RB: pointer comes back.
- [ ] Left stick: forward/back with W/S, strafe left/right with Q/E.
      Diagonals work (forward + strafe).
- [ ] Hold RB + RT together = both mouse buttons = run forward (WoW feature).
- [ ] Back + Start held 1 s: log says `Kill switch: injection DISABLED`, pad
      does nothing. Again: `ENABLED`.
- [ ] Alt-tab away while holding the left stick forward: character stops
      (keys released), log says `paused (game not focused)`.
- [ ] Keyboard and mouse still work normally the whole time.

If something does nothing at all:
- Pointer/keys don't react -> set `[Inject] Mode=PostMessage`, restart, retry.
  Tell me which mode worked.
- Pointer moves but camera doesn't turn during RB look -> tell me; mouselook
  may read the mouse differently under Wine (DirectInput).
- Too fast/slow: `[Cursor] Speed`, `[Camera] Speed`, `Curve` in wowpad.ini.

Record for later phases: injection mode that worked, window class name,
whether mouselook turned the camera.

## Phase 3a: Probe (one test session) — 0.3.0-probe

Install (fish, WoW closed):
```fish
cp dist/version.dll $G/
cp -r addon/WowPadProbe $G/interface/addons/
```
Make sure "WowPad Probe" is enabled on the character select AddOns screen
(and "Load out of date AddOns" if it shows as out of date).

In game:
1. Chat should say `N candidate keys bound`. Focus the game, hold **L3 + R3**
   (both stick clicks) for 1 s. Wait ~10 s; chat prints `Keys received: X / 52`.
2. `/wpp all` — prints the binding scan and mouselook result, runs the secure
   test. Your view will briefly switch to mouselook for 2 s; that's expected.
3. Target any NPC/mob, `/wpp menu`, then click **Set Focus** in the menu.
4. Get into combat (any mob). While fighting: open bag 1, press
   **Ctrl+Shift+J**; close bag 1, press **Ctrl+Shift+J** again.
   Then hold L3 + R3 once more during combat.
5. Out of combat, type more on the keyboard / move the real mouse for a few
   seconds (the DLL counts real vs injected events; no keys are recorded).
6. `/reload` (writes the results file), then in a terminal:
   ```fish
   cat $G/WTF/Account/*/SavedVariables/WowPadProbe.lua
   grep -E 'HOOK|PROBE (start|done|abort)' $G/wowpad.log
   ```
   Paste both outputs, plus any red "blocked" lines you saw in chat.

Afterwards: disable WowPad Probe (it borrows the numpad and Print Screen keys
while enabled). The Phase 2 controls still work in this build.

Phase 3a result (2026-10-02): see project doc phase3-probe-results.md.
38/52 keys usable (numpad + Alt/Ctrl combos); F13-F24 unusable. Hooks tell
real from injected input. Mouselook from addon works. Secure code can't read
ordinary windows in combat -> context handled by the DLL via the pointer.

## Phase 3: Signals, mode switching, trigger sets — 0.3.1-phase3 — PASSED 2026-10-02

Result: all checks pass incl. trigger sets and camera in combat, no blocked
actions, combat-start-with-bags-open, desktop numpad, LB/RB, Back tap/hold,
R3 pointer mode, kill switch.

0.3.0 finding: under Proton the DLL can't see the pointer hide during
mouselook (GetCursorInfo always 'showing'), so A sent Nav Confirm. 0.3.1: the
addon decides menu vs action (out of combat; forced to action at combat start).

Install (fish, WoW closed):
```fish
cp dist/version.dll wowpad.ini $G/
rm -rf $G/interface/addons/WowPadProbe
cp -r addon/WowPad $G/interface/addons/
```
Enable **WowPad** at character select. A status line appears near the top of
the screen (drag it anywhere; `/wp status` hides it). Slot presses print in
chat (`/wp debug` toggles).

Checks (pad unless stated):
1. [ ] Touch the pad: status shows **CONTROLLER**, `set: Default`, `camera`.
       Right stick turns the camera with no button held.
2. [ ] Move the real mouse or press a key: status shows **DESKTOP**; your
       keyboard numpad works normally (e.g. NumPad0 jumps if bound).
3. [ ] Default set: A jumps, X starts auto-attack, B clears target,
       Y prints "target menu arrives in Phase 4", D-pad prints
       `Slot fired: Default set, D-pad Up` (etc).
4. [ ] Hold LT: status `set: Left (LT)`, D-pad and ABXY print Left-set slots.
       Same for RT (Right) and LT+RT (Bottom). Release: back to Default.
5. [ ] LB / RB target the nearest friendly / hostile.
6. [ ] Back tap opens the map, Back held opens bags. Start prints a Phase 4 note.
7. [ ] Open bags (out of combat): status shows `pointer  menu buttons`,
       right stick moves the pointer, D-pad/A print "Nav ..." in chat, B closes
       the bags and A jumps again. Hold LT with bags open: D-pad prints
       Left-set slots. In combat with bags open: A jumps, D-pad = slots.
8. [ ] R3: `pointer mode`; RT = left click, LT = right click. R3 again: off.
9. [ ] **In combat**: steps 3, 4 and 5 all still work. Any red
       "ADDON_ACTION_BLOCKED" / "FORBIDDEN" lines in chat? Note them.
10. [ ] Back + Start held 1 s: DESKTOP, pad does nothing; again: back on.

Then paste:
```fish
grep -E 'MODE|Kill|HOOK|focused' $G/wowpad.log | tail -n 40
```
and tell me which checks failed. A Lua error popup is likely the most useful
thing to paste if something breaks.

### 0.3.2 additions (interact + autorun)
- [ ] X on an NPC / corpse / object: your interact addon fires (same as F).
- [ ] X on an enemy: you attack. Does your interact addon start combat by
      itself? If yes, `/wp xattack` turns the extra attack off.
- [ ] L3 toggles autorun.
- [ ] `/wp interact` shows what X is using (should be your addon's F binding).

## Phase 4: Menus — PASSED 2026-10-02 (addon 0.4.5, DLL 0.3.2)

Result: radial (stick-direction select + A), all entries, Start = Esc + wheel,
bag/vendor/quest/loot/popup navigation, Y target menu, LB/RB window switching
with focus outline + hint line all working.

0.4.1-0.4.5: stick-direction radial select; toggle functions for micro-button
entries; Start closes windows; hints + focus outline; bags as one window.

0.4.1: radial selects by holding the right stick toward a wedge (selection
stays on release), like WoW Forever.

Install (fish, WoW closed). Only the addon changed:
```fish
rm -rf $G/interface/addons/WowPad
cp -r addon/WowPad $G/interface/addons/
```

All of this is out of combat (menus close themselves when combat starts).

Radial menu
1. [ ] Start opens the Main Menu wheel (right of centre). Gold box = selection.
2. [ ] D-pad moves around the wheel; the right stick pointer also selects
       whatever it hovers. LB / RB switch page 1 / 2.
3. [ ] A opens the selected entry and closes the wheel. Try every entry on
       both pages (Calendar and Macros load on first use).
4. [ ] B or Start closes the wheel. Page 2 > Controller shows the controls.

Window navigation
5. [ ] Open bags (Back hold): gold box on a bag slot. D-pad moves between
       slots; hovering an item shows its tooltip.
6. [ ] X (right-click) on a usable item uses it. A picks it up; A again on
       another slot drops it there.
7. [ ] At a vendor: X on an item in your bags sells it; A on a vendor item
       buys it. LB / RB switch focus between the vendor window and bags.
8. [ ] Quest giver / gossip: D-pad + A pick options and accept/complete.
9. [ ] Character, spellbook, talents, quest log, map: D-pad reaches tabs and
       buttons; B closes each one.
10. [ ] A popup (e.g. destroy an item / leave party confirmation): B cancels,
        A on the accept button accepts.
11. [ ] Loot window: D-pad + A loot items.

Target menu
12. [ ] Target a player or NPC, press Y: menu next to the target frame.
        Set Focus works (focus frame appears). Whisper/Invite/Trade etc. on a
        player. B closes.

Combat
13. [ ] Open the wheel or target menu, then get into combat: it closes, the
        camera works, A jumps. Start/Y in combat print "not available in combat".

Note anything that can't be reached with the D-pad, or where the gold box
jumps somewhere odd, and any red "blocked" lines or Lua errors.

## Phase 5: Controller action bar — addon 0.5.1 (DLL unchanged, 0.3.2)

0.5.1: compact WoW Forever layout (interleaved rows, no boxes), gold outline
on the buttons of the set you hold; bar position/size reset once.

Install (fish, WoW closed). Only the addon changed:
```fish
rm -rf $G/interface/addons/WowPad
cp -r addon/WowPad $G/interface/addons/
```

Setup
1. [ ] Pick up the pad: the controller bar appears (bottom centre): four
       pad-shaped clusters. Touch the keyboard/mouse: it hides.
2. [ ] Start > page 3 > **Edit Bar** (or `/wp edit`): bar turns blue-tinted
       and stays visible while you use the mouse.
3. [ ] Drag spells from the spellbook onto slots: top cluster D-pad (4),
       LT / RT / LT+RT clusters (8 each). Also try an item, a macro and a
       mount. Drop onto an occupied slot: the old one goes onto your cursor.
4. [ ] Drag the bar to move it; mouse wheel over it to resize. Right-click a
       slot to clear it; drag a slot off to remove it.
5. [ ] `/wp edit` again: "Controller bar saved."

Playing
6. [ ] With the pad: D-pad casts the top cluster's spells. Hold LT: the LT
       cluster lights up gold, D-pad + ABXY cast from it. Same for RT and
       LT+RT.
7. [ ] **In combat**: all four sets cast. Cooldown sweeps, red icon when out
       of range, blue when out of mana, grey when unusable, item counts.
8. [ ] Hover a slot with the mouse: tooltip.
9. [ ] `/reload` and relog: layout and bar position are kept.
10. [ ] Dual spec: switch spec -> the bar shows that spec's (empty) layout;
        fill it, switch back -> the first layout returns.
11. [ ] Switch to keyboard: your normal action bars and keybinds are exactly
        as before.

Report anything that doesn't cast, looks wrong, or any Lua error.

### 0.5.2 changes
- Tighter sets (D-pad and face buttons 24px apart).
- Bar always visible, also in mouse/keyboard mode (`/wp bar` or Start > page 3 >
  Bar Visibility switches to controller-mode-only). Mouse clicks on it cast.
- Blizzard bottom UI hidden by default: main bar + art, XP/rep, bag buttons,
  micro menu, bottom/side bars, stance, pet and possess bars. Vehicle bar kept.
  `/wp blizz` or Start > page 3 > Blizzard Bars toggles it.
Checks:
- [ ] Bottom of the screen is clear except the controller bar.
- [ ] Your normal keybinds (1-0 etc.) still cast with the bars hidden.
- [ ] Enter and leave a vehicle: vehicle bar appears, Blizzard bars stay hidden.
- [ ] Spellbook, Social, Quest Log on the wheel still open (now toggle functions).
- [ ] Pet classes: pet bar is hidden; tell me if you want it kept.

### 0.5.3 (DLL + addon): LB+RB zoom
- [ ] Hold LB+RB: hint at the top centre; right stick up zooms in, down zooms
      out; camera doesn't turn meanwhile. Release: hint goes away.
- [ ] LB / RB target on press (0.5.4; LB+RB together also targets, as wanted).
- [ ] Zoom speed: `[Camera] ZoomSpeed` in wowpad.ini (default 8).

## Polish pass — addon 0.6.0 (DLL 0.5.4)
- [ ] Round slots: icons cropped to circles with a bronze ring; empty slots are
      dark discs; the set you hold gets a round gold glow; mouse-over glows.
      Cooldown sweeps still show (slightly inset; square in this WoW version).
- [ ] "There is nothing to attack." no longer appears when pressing X on
      non-hostile things. Other errors (out of range, not enough mana) still do.
- [ ] No WowPad chat messages during normal play (`/wp debug` turns them on).
- [ ] No "WowPad: DESKTOP/CONTROLLER" line (`/wp status` shows it).

### 0.6.1: compare items
- [ ] Bags or vendor open: hover an equippable item with the gold box, hold Y:
      comparison tooltips with your equipped item appear. Move the D-pad while
      holding: they follow. Release Y: they close.
- [ ] Hint line shows "Y Compare". No window open: Y still opens the target menu.

## 0.7.0: XP/reputation bar and pet bar (addon only)
- [ ] XP bar at the bottom: purple XP, blue rested part, text "Level N  cur / max (%)".
      Track a reputation (character sheet > Reputation > "Show as experience
      bar"): thin rep bar appears under it.
- [ ] Pet class: pet bar appears when the pet is out, hides when it's gone.
      Left-click casts, right-click toggles autocast (sparkles), cooldowns and
      the active stance (Aggressive/Defensive/Passive, Follow/Stay) highlight.
      Works in combat.
- [ ] Edit Bar mode: blue labelled boxes on the XP bar and pet bar (the pet bar
      shows even without a pet). Drag to move, mouse wheel to resize, each on
      its own. Finish edit mode: positions kept after /reload.

## 0.7.1: B icon, crosshair (addon only)
- [ ] B (top set) shows the red-X icon from your macro (shipped in the addon).
- [ ] Controller mode, camera active: a small dot in the screen centre. Turn
      the camera so the dot sits on a mob/NPC: its tooltip appears (bottom
      right, like mouse hover) and the dot turns red (enemy) / green
      (friendly) / yellow (neutral). Off a unit: tooltip goes, dot white.
- [ ] Open a window / use the mouse: dot disappears.
- [ ] If the tooltip shows for a unit that is NOT under the dot, tell me
      roughly where on screen the "real" spot is (the hidden pointer may not
      sit at the centre under Wine).
- [ ] `/wp crosshair` or Start > page 3 > Crosshair toggles it.

## 0.7.3: crosshair peek (DLL + ini + addon)
Probe result 0.7.2: WoW 3.3.5 reports no mouseover unit during camera look,
even with the hidden pointer under the dot -> peek design.
- [ ] Pick up the pad: dot appears (pointer parked CrosshairY px above centre).
- [ ] Turn the camera so the dot is on an NPC, let go of the right stick:
      ~0.25 s later WoW's cursor appears on the dot, the tooltip shows, dot
      colours red/green/yellow.
- [ ] Move the right stick again: camera turns immediately, no jump or drift.
- [ ] Feels weird? `/wp peek` turns peeking off (dot stays).
- [ ] Height: `CrosshairY` in wowpad.ini (pixels above centre, default 95).

## 0.7.4 (addon only)
- [ ] Peek: no hand/sword cursor on the dot, tooltips still appear. Opening a
      window or moving the stick brings the normal cursor back.
- [ ] Tighter action sets (D-pad / face buttons close together, sets closer).

## 0.7.10: cursor returns in pointer mode (DLL only)
- [ ] Rest the right stick until the crosshair peeks, then press R3: the normal cursor shows straight away (no need to touch the mouse) and the right stick moves it.
- [ ] R3 again: cursor hides, crosshair is back at its spot, camera works.
- [ ] Camera stop still has no hand flash (0.7.9 fix).

## 0.7.11: pointer mode moves the visible cursor (DLL + ini)
Wayland only lets a program move a confined pointer, so while the right stick moves the pointer in R3 mode the DLL keeps it in a 1-pixel ClipCursor box and moves the box. Released as soon as the stick rests. **Depends on unverified Wine/XWayland behaviour.**
- [ ] R3, move the right stick: the cursor art follows the stick; hovering an NPC shows hand/sword; RT/LT clicks land where the art is.
- [ ] Stick at rest, then move the real mouse: switches to desktop mode normally (not stuck).
- [ ] If the cursor gets stuck or jumps, set PointerWarp=0 in wowpad.ini and report.

## 0.7.12: addon-drawn cursor in pointer mode (DLL + addon + ini)
0.7.11's ClipCursor warp did not move the drawn cursor (Wayland), so it is off (PointerWarp=0). Instead, in R3 pointer mode the DLL hides the hardware cursor and the addon draws the game's cursor art (Interface\Cursor\Point / Attack / Speak) at WoW's own pointer.
- [ ] R3, move the stick: the arrow follows; over an enemy it becomes the sword, over an NPC the speech bubble; clicks land under it.
- [ ] R3 off: arrow gone, crosshair back, camera works, no hand left on screen.
- [ ] Touch the real mouse in pointer mode: normal cursor comes back (desktop mode).

## 0.8.0: options panel, camera/pointer sensitivity (DLL + addon)
- [ ] Esc > Interface > AddOns > WowPad shows the panel (`/wp options` opens it too).
- [ ] Camera sensitivity to 30%, Apply: UI reloads, log shows `Addon settings: camera x0.30`, camera turns slower.
- [ ] Pointer speed changes R3 pointer speed; Invert flips camera up/down.
- [ ] Crosshair and tooltip checkboxes take effect without Apply.

## 0.8.1: more options (DLL + addon)
- [ ] Panel shows two columns: Sticks/Crosshair (left), Controller bar/Buttons/Messages (right). Nothing overlaps.
- [ ] Zoom speed and Peek delay change after Apply (log: `Addon settings: ... zoom x0.50 ...`, `peek delay 400 ms`).
- [ ] Bar checkboxes, bar size slider, Edit bar layout, X attack, status line, debug act immediately.

## 0.8.7: walk/run on stick tilt (DLL + addon)
Built on 0.8.1 (the stable one; 0.8.2-0.8.6 shelved). Only addition: walk/run option, default off.
- [ ] Option off: movement exactly as before, no `MOVE` lines in the log.
- [ ] Option on + Apply: log shows `walk/run on stick tilt: on`. Slight tilt walks (`MOVE walk`), full tilt runs (`MOVE run`); pushing straight to full never blips into walk; letting go returns to run.
- [ ] Works mounted, in combat, strafing and backpedalling.
- [ ] Touch the mouse/keyboard while walking: game is left in run mode.

## 0.8.8: preview / destroy in menus, options layout (addon only; DLL stays 0.8.7)
- [ ] Options panel fits: Apply is top right, nothing runs past the bottom or into the right column.
- [ ] Bags, gear selected: hint shows `Y Preview, hold: Compare` and `L3 Destroy`. Y tap opens the dressing room with the item; B closes it. Y held still compares (after ~0.25 s).
- [ ] Non-gear item: hint shows `Y hold: Compare`; Y tap does nothing.
- [ ] Vendor / loot / quest reward gear: Y tap previews too (no L3 hint outside bags).
- [ ] L3 on a bag item: popup "Destroy [item] x N?", Cancel selected. B or A-on-Cancel keeps it; A on Destroy deletes it. Move the item before confirming: nothing destroyed.
- [ ] L3 outside menus is still autorun.

## 0.8.9: options fit, L3 destroy fix attempt (addon only; DLL stays 0.8.7)
0.8.8 report: panel still spilled right (panel is only ~415 wide: two 250-wide columns didn't fit); L3 showed no hint and did nothing in bags, preview worked.
- Two narrow columns (sliders 170 wide), "Experimental" section for walk/run, crosshair tooltips, peek delay.
- Bag item lookup: uses the tooltip's item, then the bag/slot IDs, then searches the bags for that item.
- `/wp navinfo` prints the selection, its IDs, the item found and what the L3 key is bound to. With `/wp debug` on, L3 in a menu prints "L3 in menu: destroy".
- [ ] Panel fits. [ ] L3 hint + destroy popup in bags. If not: send `/wp navinfo` output with a bag item selected, and check wowpad.log shows `BTN LStick down` on L3.

## 0.8.10: L3 destroy with bag addons (addon only; DLL stays 0.8.7)
0.8.9 report: L3 failed because Bagnon was on (works with default bags). Bag buttons are now recognised by frame names (container/bag/inventory/bank/combuctor), bag from GetBag() or the parent's ID, checked against the slot's real item, else a search of the bags for the tooltip's item.
- [ ] With Bagnon: L3 hint on bag items, destroy popup names the right item, destroy works. Bank items in Bagnon too.
- [ ] Vendor/character windows: no L3 hint.

## 0.8.11: Questie Lua error (addon only; DLL stays 0.8.7)
Questie puts an AceGUI widget table (not a frame) in UISpecialFrames as QuestieConfigFrame; Nav.lua:41 called :GetName() on it. Both window checks (Nav roots, Core AnyWindowOpen) now use WP.AsFrame(): real frames as-is, AceGUI widgets via their .frame, anything else skipped.
- [ ] Questie on: no Lua errors with gossip/quest/bags open. Questie's config window (/questie) can be navigated and closed with B.

## 1.0.1: no camera stutter on LB/RB (DLL only)
Signal taps for Ctrl/Alt combos (LB, RB, Start, Back, nav, walk toggle) wait 5-15 ms between key events, ~40-80 ms in total under Wine; the poll loop stopped sending camera motion meanwhile, then caught up in one jump. Now the waits keep sending camera motion (camera look only: not pointer mode, zoom or peek pause), and that time isn't sent again on the next tick.
- [ ] Spin the camera with the right stick and tap LB/RB repeatedly: smooth turning, targeting still works.
- [ ] Same with Start (radial) and Back (map): no stutter before the window opens.
- [ ] R3 on/off a few times: no crash (pointer-mode code untouched).

## 1.0.2: smooth camera option, no settings-file hitch (DLL + addon + ini)
- The addon-settings file (SavedVariables\WowPad.lua) was checked from the controller poll loop once a second (directory scan + file stat under Wine): a possible small hitch every second. Now a background thread does it.
- Options > Experimental > "Smooth camera*": exponential smoothing of the right stick for camera turning, [Camera] SmoothMs=60 (time constant). Not applied in pointer mode or zoom. The tail of the glide keeps the camera active, so peek starts after it settles.
- Peek checkbox moved back under Crosshair with a note "Turning it off is experimental."
- [ ] Smooth camera off: turning feels like 1.0.1. On + Apply: log `smooth camera: on`, turning glides; stop is soft but not floaty. Try SmoothMs 30-120.
- [ ] LB/RB while turning: still no stutter. R3 on/off: no crash. Peek tooltips still appear after the glide stops.

## 1.0.3 (addon only, test): bar toggles + own cast bar; DLL stays 1.0.2
- Options > WowPad > **Bars** (new sub-page): controller bar settings moved here, plus toggles for WowPad's XP/rep bar, pet bar and a new movable cast bar (all default on). Main page right column now: Buttons, Messages, Experimental.
- Cast bar: CastingBarFrameTemplate (Blizzard's own cast bar code) in a holder that moves/scales in Edit bar layout ("Cast bar" box). While on, Blizzard's CastingBarFrame is unregistered and hidden; turning ours off gives Blizzard's back (only if we were the ones who switched it off).
- Pet bar toggle in combat applies after combat (secure).
- [ ] Bars page shows; toggles hide/show each bar at once. Edit mode shows boxes only for enabled bars.
- [ ] Cast something: WowPad cast bar shows (icon/text/spark, channel and interrupt work), Blizzard's doesn't. Move/resize it in edit mode; position kept after /reload.
- [ ] Cast bar off: Blizzard's comes back at its usual place.

## 1.0.4 (addon only, test): world map cursor; includes 1.0.3; DLL stays 1.0.2
WoW-Forever-style map cursor (screenshots from the user): gold diamond (own texture Textures/mapcursor.tga), gold crosshair lines across WorldMapDetailFrame, "Cursor: x, y" / "Player: x, y" bottom-left. Shown in controller mode while the world map is open; the real cursor is blanked (SetCursor blank, like peek); pointer-mode arrow is hidden on the map.
- Right stick moves it (WoW's pointer). D-pad jumps between pins/buttons and the diamond sits on the selection until the stick moves again.
- A clicks the selection: on the map itself = zoom in on the zone under the cursor; on a pin = click the pin. X = right-click (zoom out on the map).
- B: zoom out (WorldMapZoomOutButton) while on a continent/zone; closes at world level. Hint bar: A Change Map / Select, X Zoom Out, D-pad Pins, B Back/Close.
- [ ] Open map with Back: diamond + lines + coords; no stray arrow/hand.
- [ ] Stick moves diamond; A on a zone zooms in there (check it's the zone under the diamond). B backs out to continent, world, then closes.
- [ ] D-pad onto a Questie pin: diamond jumps to it, tooltip shows; A clicks it.
- [ ] Close map: crosshair/camera normal. Touch the mouse with the map open: normal cursor.

## 1.0.5 (DLL + addon, test): map cursor start/close fixes; includes 1.0.3/1.0.4
Report: map cursor started at the crosshair spot, and after closing the map the crosshair stayed where the map cursor was.
- Addon: a newly opened window starts on its default button again (diamond there), not at the hidden pointer; the pointer only takes over when the stick moves.
- DLL: camera look is now detected as "no cursor image AND pointer at the window centre" (WoW keeps it there during camera look). The addon's blank cursor on the map also reports no image, which made the DLL think the camera was on while the map was open (re-centre fired on open, not on close; peek hid the cursor in the map).
- [ ] Open map: diamond on the default button; stick takes it from there. Close map: crosshair back at its spot (log: "Crosshair: camera resumed, re-centred" after closing, not on opening).
- [ ] Other windows (bags, vendor): unchanged; closing them re-centres as before. Peek tooltips still work.

## 1.0.6 (addon only, test): map A/X click the map itself; DLL stays 1.0.5
Report: X didn't zoom out, A didn't zoom in. A/X clicked the Nav selection, which on the map never became WorldMapButton (likely an addon overlay, e.g. Questie, under the pointer). Now on the world map A/X secure-click WorldMapButton (left = zoom in at the cursor, right = zoom out), unless the D-pad put the cursor on a pin/button (then that is clicked). Hints: "A Zoom In / X Zoom Out", or "A Select / X Right-click" on a pin.
- [ ] Stick somewhere on a zone, A: zooms into that zone. X: zooms out. Works again after zooming out.
- [ ] D-pad onto a Questie pin, A: clicks the pin. Move the stick: A zooms again.

## 1.0.7 (addon only, test): map clicks done directly; DLL stays 1.0.5
1.0.6 report: A/X still didn't zoom (crosshair re-centre after closing the map works). Now A/X on the map don't go through a secure click of WorldMapButton at all: the PreClick calls the map code directly (WorldMapButton_OnClick(WorldMapButton, "LeftButton") / WorldMapZoomOutButton_OnClick, fallbacks ProcessMapClick / ZoomOut) and clears clickbutton. With /wp debug on, each map click prints "map LeftButton click: ok (continent c, zone z)"; errors always print.
- [ ] A zooms in under the diamond, X zooms out. If not: /wp debug, try again, send the chat lines.

## 1.0.8 (addon only, test): own cast bar; DLL stays 1.0.5
1.0.3-1.0.7 cast bar (CastingBarFrameTemplate) showed nothing when casting. Now WowPad draws its own: StatusBar with the game's UI-StatusBar texture, UI-CastingBar-Border / -Spark / -Flash, spell name, remaining time, spell icon; casts (yellow), channels (green, counting down), pushback, success flash + fade, failed/interrupted (red text) + fade. Player events filtered by unit. Edit bar layout shows a preview bar ("Cast bar", 60%) to place it. No new art files.
- [ ] Cast a spell with a cast time: bar fills, spark moves, name + timer + icon. Blizzard's bar doesn't show.
- [ ] Channel (e.g. a drain or Arcane Missiles): bar empties. Move while casting: "Interrupted" in red.
- [ ] Edit bar layout: preview bar visible in the box; move/resize; /reload keeps it.

## 1.0.9 (addon only, test): new radial look; DLL stays 1.0.5
WoW-Forever-style wheel (user's screenshots): 8 translucent dark wedges, bronze rim/spokes/hub ring, empty hub, "Main Menu" + LB o o o RB page dots, icons and labels inside the wedges, stronger gold glow + lighter fill on the selected wedge. Art generated by scripts/make_radial_art.py (radial_frame quarter 256x256, 2 wedge + 2 glow shapes 256x256, RLE TGA, ~121 KB total), turned into place with SetTexCoord in 90 degree steps. Empty wedges on page 3 stay plain (not dimmed).
- [ ] Start: wheel looks right (no gaps/offsets between quarters; wedges line up with spokes; glow sits inside the selected wedge).
- [ ] Stick direction lights the matching wedge; A opens it; LB/RB move the gold dot; B/Start close.

## 1.0.10 (addon only, test): radial page dots light up
Dots used Textures/disc (dark), so the gold tint never showed. Now Textures/dot (white): current page gold and larger, others grey.

## 1.1.1 (addon only, test): minimap button + soft snap
- Minimap button (own gamepad icon, Textures/minimap.tga ~7 KB, scripts/make_minimap_icon.py): left-click Edit bar layout, right-click Options, drag around the minimap (WowPadDB.minimap.angle). Options > Bars > Minimap button (default on).
- Edit mode drag (controller bar, XP, pet, cast bar) uses Snap.lua: within 12 UI px of the screen's vertical centre the bar's centre locks to it and a gold guide line shows; pulling further releases. Vertical position free.
- [ ] Button sits on the minimap edge, tooltip shows, clicks work, drag moves it, position kept after /reload. Option hides/shows it.
- [ ] Drag each bar across the middle: snaps with guide line, can be pulled off, saved position stays centred after /reload.

## 1.1.2 (addon only, test): separate rounded XP and reputation bars
- XP and reputation are separate holders ("xp", "rep"), each movable/scalable with centre snap, own toggles (Options > Bars: XP bar, Reputation bar; default on). Rep starts just above the XP bar until moved. XP holder is only the bar's height, so it can sit flush on the bottom edge.
- Rounded style: half-disc caps (Textures/barcap, barcapring; scripts/make_bar_caps.py, ~6 KB) + flat middle, thin bronze outline; fill shows its left cap once there's progress and its right cap when full. Rested XP is a translucent blue fill under the XP fill. Cast bar unchanged.
- [ ] Both bars rounded, text readable; XP fill/rested correct; rep colour by standing.
- [ ] Drag XP to the very bottom edge; rep moves independently; toggles hide each.

## 1.1.3 (addon only, test): hint bar per window
Bags (default, bank, bag addons): A Select, X Use (Sell with a vendor open), Y Preview/hold Compare, L3 Destroy, B Close - always, without hovering. Vendor list: A Select, X Buy, Y Preview/Compare, B Close. Every other window: A Select, B Close. Map unchanged; LB/RB switch hint when several windows are open.
- [ ] Talents, spellbook, quest log, game menu: only A/B. Bags and vendor: full set.

## 1.1.4 (addon only, test): D-pad slot arrows
One arrow glyph (Textures/dpadarrow, scripts/make_dpad_arrow.py, 1.5 KB) turned per direction; on its own child frame above ring/cooldown. Over a skill: small, bottom-right corner (like A/B/X/Y); empty slot: big, centred.
- [ ] Arrows visible on assigned D-pad slots, all four the same style.

## 1.1.5 (addon only, test): press feedback
Blizzard-style recess when a slot fires: icon inset 2 px and darkened to 55% for 0.12 s, then back (usable tint restored). Slots: PostClick hook. Fixed default-set face buttons: A = hooksecurefunc JumpOrAscendStart, X = StartAttack / WowPadNoop, B = WowPadBackButton, Y = WowPadUnitMenu (controller mode, default set only).
- [ ] Press D-pad and trigger-set slots: each icon dips. A jump, B clear target, X attack, Y menu: top-cluster icons dip.
- [ ] Works in combat, no Lua errors.

## 1.1.6 (addon only, test): slot press feedback fix
Slots set their own PostClick later in MakeSlot, which replaced the hook; the press now runs inside that handler.
