#!/usr/bin/env python3
"""Generates WowPad's minimap button icon (a gamepad), our own art."""
from PIL import Image, ImageDraw
import sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else "addon/WowPad/Textures"
S = 8; N = 64 * S
im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
def P(*v): return [int(c * S) for c in v]
body, edge, dark = (232, 222, 200, 255), (40, 32, 22, 255), (55, 48, 40, 255)
# grips + body, drawn twice: dark outline then light fill
for col, g in ((edge, 2.2), (body, 0)):
    d.ellipse(P(4 - g, 22 - g, 26 + g, 56 + g), fill=col)      # left grip
    d.ellipse(P(38 - g, 22 - g, 60 + g, 56 + g), fill=col)     # right grip
    d.rounded_rectangle(P(8 - g, 16 - g, 56 + g, 42 + g), radius=12 * S, fill=col)
# d-pad
d.rectangle(P(13, 26, 23, 30), fill=dark); d.rectangle(P(16, 23, 20, 33), fill=dark)
# face buttons
for cx, cy, c in ((47, 23, (70, 160, 80, 255)), (52, 28, (200, 60, 50, 255)),
                  (42, 28, (60, 110, 200, 255)), (47, 33, (220, 180, 40, 255))):
    d.ellipse(P(cx - 2.6, cy - 2.6, cx + 2.6, cy + 2.6), fill=c)
# sticks
d.ellipse(P(23, 33, 31, 41), fill=dark); d.ellipse(P(33, 33, 41, 41), fill=dark)
im = im.resize((64, 64), Image.LANCZOS)
os.makedirs(OUT, exist_ok=True)
p = os.path.join(OUT, "minimap.tga")
im.save(p, compression="tga_rle")
print(p, os.path.getsize(p))
