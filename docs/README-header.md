# <h1 align="center">WowPad {VERSION}</h1>



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
pad and the 2026 Steam Controller. Windows should work but is untested.

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

