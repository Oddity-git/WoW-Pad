#!/usr/bin/env python3
"""Generates the radial menu art (WowPad's own, no game or third-party art).

Geometry is in wheel units: outer radius 1.0 = edge of the texture square.
  radial_frame.tga   256x256  top-right quarter of the bronze rim / spokes / hub ring
  radial_wedge0.tga  256x256  wedge fill centred straight up   (white, tinted in Lua)
  radial_wedge45.tga 256x256  wedge fill centred up-right
  radial_glow0.tga / radial_glow45.tga  selection glow along the wedge edge (white, ADD)
Other wedges are these rotated by 90 degree steps with SetTexCoord.
"""
import numpy as np
from PIL import Image
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "addon/WowPad/Textures"
R_OUT, RIM = 1.0, 0.09         # outer radius, rim width
R_HUB, HUB_W = 0.30, 0.055     # hub ring (outer radius of the ring), ring width
SPOKE_W = 0.06                 # spoke width (wheel units)
SS = 4                         # supersampling

def grid(px):
    n = px * SS
    c = (np.arange(n) + 0.5) / n * 2 - 1          # -1..1
    x, y = np.meshgrid(c, -c)                     # y up
    r = np.hypot(x, y)
    a = np.degrees(np.arctan2(x, y)) % 360        # 0 = up, clockwise
    return x, y, r, a

def down(img, px):
    im = Image.fromarray(img, "RGBA")
    return im.resize((px, px), Image.LANCZOS)

def spoke_dist(x, y, a):
    """Perpendicular distance to the nearest spoke line (spokes at 22.5 + k*45 deg)."""
    best = np.full(x.shape, 9.0)
    for k in range(8):
        t = np.radians(22.5 + 45 * k)
        dx, dy = np.sin(t), np.cos(t)              # direction (0 deg = up)
        along = x * dx + y * dy
        perp = np.abs(x * dy - y * dx)
        d = np.where(along > 0, perp, 9.0)
        best = np.minimum(best, d)
    return best

def bevel(d, half):
    """1 at the centre line of a band, 0 at its edges."""
    return np.clip(1 - np.abs(d) / half, 0, 1)

def frame(px=512, quadrant=False):
    x, y, r, a = grid(px)
    rim_c = R_OUT - RIM / 2
    rim = bevel(r - rim_c, RIM / 2)
    hub_c = R_HUB - HUB_W / 2
    hub = bevel(r - hub_c, HUB_W / 2)
    sd = spoke_dist(x, y, a)
    spoke = np.where((r > R_HUB - HUB_W * 0.5) & (r < R_OUT - RIM * 0.5), bevel(sd, SPOKE_W / 2), 0)
    m = np.maximum(np.maximum(rim, hub), spoke)
    alpha = np.clip(m * 6, 0, 1)                  # solid inside, soft 1/6 edge
    # bronze: dark edges, light ridge, a little top-left light
    light = 0.6 + 0.4 * m
    base = np.array([96, 70, 44]) / 255.0
    hi = np.array([182, 140, 88]) / 255.0
    col = base[None, None, :] * (1 - m[..., None]) * 0.6 + hi[None, None, :] * m[..., None]
    col = np.clip(col * light[..., None], 0, 1)
    img = np.dstack([col * 255, alpha * 255]).astype(np.uint8)
    im = down(img, px)
    if quadrant:   # top-right quarter only; Lua rotates it into the other three
        im = im.crop((px // 2, 0, px, px // 2))
    return im

def wedge(center_deg, px=256, glow=False):
    x, y, r, a = grid(px)
    da = (a - center_deg + 180) % 360 - 180       # angle from wedge centre
    inside_ang = np.abs(da) <= 22.5
    sd = spoke_dist(x, y, a)
    r_in, r_out = R_HUB - HUB_W * 0.2, R_OUT - RIM * 0.6
    inside = inside_ang & (r > r_in) & (r < r_out)
    if not glow:
        alpha = inside.astype(float)
    else:
        # distance to the wedge border (spokes, hub, rim), glow fading inward
        edge = np.minimum(np.minimum(sd, r - r_in), r_out - r)
        alpha = np.where(inside, np.clip(1 - edge / 0.07, 0, 1) ** 1.6, 0)
    img = np.dstack([np.ones_like(alpha) * 255] * 3 + [alpha * 255]).astype(np.uint8)
    return down(img, px)

os.makedirs(OUT, exist_ok=True)
def save(im, name):
    im.save(os.path.join(OUT, name), compression="tga_rle")
save(frame(quadrant=True), "radial_frame.tga")   # 256x256 quarter of a 512 wheel
save(wedge(0), "radial_wedge0.tga")
save(wedge(45), "radial_wedge45.tga")
save(wedge(0, glow=True), "radial_glow0.tga")
save(wedge(45, glow=True), "radial_glow45.tga")
for f in sorted(os.listdir(OUT)):
    if f.startswith("radial_"):
        print(f, os.path.getsize(os.path.join(OUT, f)))
