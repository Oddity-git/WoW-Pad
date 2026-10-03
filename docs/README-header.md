# WowPad {VERSION}
<img width="1607" height="903" alt="image" src="https://github.com/user-attachments/assets/8fe0f72d-28ee-492f-8766-9f8e3f9f0095" />
<img width="1607" height="903" alt="image" src="https://github.com/user-attachments/assets/414e0d42-7377-497b-8b6f-e3fb1183e59a" />


Native-feel controller support for the World of Warcraft **3.3.5a (build 12340)**
client, in the style of WoW's console version: move and look with the sticks,
a round controller action bar on the triggers, menus you can drive with the
D-pad, a radial main menu and a crosshair. Client-side only; nothing on the
server changes.
<img width="1438" height="861" alt="image" src="https://github.com/user-attachments/assets/216b429f-eb42-46eb-bd63-ce6780bfaa50" />

<img width="1915" height="1085" alt="image" src="https://github.com/user-attachments/assets/8ffb7ffd-28e9-41a9-a5bc-c61bbc352df7" />

It has two parts that work together:
- `version.dll` reads the controller and sits next to `Wow.exe`;
- the `WowPad` addon (bar, menus, options) goes in `Interface/AddOns`.

Made and tested on Linux (CachyOS, Faugus Launcher / Proton) with an Xbox-style
pad and the 2026 Steam Controller. Windows should work but is untested.

> Using a DLL with a game is your own call. Ask your server's staff before
> using or sharing it.

## Compatibility
It is currently being tested which addons this is compatible with, but so far
these addons have been either fixed to work or were working by default:
- AIO
- Auctionator
- Bagnon
- Postal
- Questie-335

