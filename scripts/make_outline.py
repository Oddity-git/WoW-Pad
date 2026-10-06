# make_outline.py - the set outline on the controller bar (Textures/outline.tga):
# a thin gold ring at the same radius as glow.tga's ring, with a soft edge.
# glow.tga stays as it is (it's also the buttons' mouse-over highlight).
from PIL import Image
import math, os

N = 128                  # texture size
R = N * 26 / 64          # ring radius: same place as glow.tga's ring
SIGMA = N * 1.6 / 64     # thickness (glow.tga is about 2.5x wider)
GOLD = (255, 210, 70)

im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = im.load()
c = (N - 1) / 2
for y in range(N):
    for x in range(N):
        d = math.hypot(x - c, y - c) - R
        a = math.exp(-(d * d) / (2 * SIGMA * SIGMA))
        if a > 0.01:
            px[x, y] = GOLD + (int(255 * a),)
out = os.path.join(os.path.dirname(__file__), "..", "addon", "WowPad", "Textures", "outline.tga")
im.save(out)
print("written", out)
