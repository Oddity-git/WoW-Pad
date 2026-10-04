#!/usr/bin/env python3
"""Rounded bar end caps (WowPad's own art): left-facing half disc (barcap)
and half ring outline (barcapring), white, 32x64; the right end is the same
image mirrored with SetTexCoord."""
from PIL import Image, ImageDraw
import os, sys
OUT = sys.argv[1] if len(sys.argv) > 1 else "addon/WowPad/Textures"
S, W, H = 8, 32, 64
def cap(ring):
    im = Image.new("RGBA", (W * 2 * S, H * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    r = H * S / 2
    d.ellipse([0, 0, 2 * r, 2 * r], fill=(255, 255, 255, 255))
    if ring:
        t = 6 * S
        d.ellipse([t, t, 2 * r - t, 2 * r - t], fill=(0, 0, 0, 0))
    return im.crop((0, 0, W * S, H * S)).resize((W, H), Image.LANCZOS)
for name, ring in (("barcap", False), ("barcapring", True)):
    cap(ring).save(os.path.join(OUT, name + ".tga"), compression="tga_rle")
