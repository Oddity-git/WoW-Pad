#!/usr/bin/env python3
"""D-pad arrow glyph for the controller bar (WowPad's own art): a gold
triangle pointing up with a dark outline, 32x32. Other directions are the
same image turned with SetTexCoord."""
from PIL import Image, ImageDraw
import os, sys
OUT = sys.argv[1] if len(sys.argv) > 1 else "addon/WowPad/Textures"
S = 8; N = 32 * S
im = Image.new("RGBA", (N, N), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
def tri(inset):
    i = inset * S
    return [(N / 2, 5 * S + i * 1.2), (N - 4 * S - i, N - 7 * S - i * 0.6), (4 * S + i, N - 7 * S - i * 0.6)]
d.polygon(tri(0), fill=(20, 14, 6, 230))
d.polygon(tri(2.6), fill=(255, 214, 70, 255))
im.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT, "dpadarrow.tga"), compression="tga_rle")
