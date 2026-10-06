#!/usr/bin/env python3
"""Generates the radial menu art (WowPad's own, no game or third-party art).

Style: eight separate rounded tiles with a small gap between them, each with a
dark metal border and a fine light inner line, around a slim metal hub ring
(after WoW Forever's controller wheel).

Geometry is in wheel units: outer radius 1.0 = edge of the texture square.
  radial_frame.tga   256x256  top-right quarter: tile borders, hub ring, hub fill
  radial_wedge0.tga  256x256  tile fill centred straight up   (white, tinted in Lua)
  radial_wedge45.tga 256x256  tile fill centred up-right
  radial_glow0.tga / radial_glow45.tga  selection glow inside the tile border (white, ADD)
Other wedges are these rotated by 90 degree steps with SetTexCoord.
"""
import numpy as np
from PIL import Image
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "addon/WowPad/Textures"
R_OUT, R_IN = 0.985, 0.335     # tile outer / inner radius
GAP = 0.034                    # gap between neighbouring tiles
BW = 0.038                     # tile border width
CORNER = 0.05                  # tile corner rounding
HUB_OUT, HUB_IN = 0.300, 0.250 # hub ring
SS = 4                         # supersampling

METAL_DARK = np.array([22, 20, 17])
METAL = np.array([62, 58, 50])
METAL_LIGHT = np.array([128, 120, 102])
HUB_FILL = np.array([62, 32, 18])

def grid(px):
    n = px * SS
    c = (np.arange(n) + 0.5) / n * 2 - 1          # -1..1
    x, y = np.meshgrid(c, -c)                     # y up
    r = np.hypot(x, y)
    a = np.degrees(np.arctan2(x, y)) % 360        # 0 = up, clockwise
    return x, y, r, a

def down(img, px):
    return Image.fromarray(img, "RGBA").resize((px, px), Image.LANCZOS)

def side_dist(x, y, t_deg):
    """Distance from a spoke line through the centre at angle t (0 = up)."""
    t = np.radians(t_deg)
    return np.abs(x * np.cos(t) - y * np.sin(t))

def tile_edge(x, y, r, a, center):
    """Signed distance inside the tile centred at `center` degrees (>0 inside),
    with rounded corners. Points outside the tile's sector get -1."""
    da = (a - center + 180) % 360 - 180
    sector = np.abs(da) < 22.5 + 5
    d_left = side_dist(x, y, center - 22.5) - GAP / 2
    d_right = side_dist(x, y, center + 22.5) - GAP / 2
    d_side = np.minimum(d_left, d_right)
    d_rad = np.minimum(r - R_IN, R_OUT - r)
    d1, d2 = np.minimum(d_side, d_rad), np.maximum(d_side, d_rad)
    rc = CORNER
    corner = (d1 < rc) & (d2 < rc)
    e = np.where(corner, rc - np.hypot(rc - d1, rc - d2), d1)
    inside_wedge = np.abs(da) <= 22.5
    return np.where(sector & inside_wedge, e, -1.0)

def band_colour(t):
    """Border profile across the band: t = 0 outer edge .. 1 inner edge."""
    col = np.where(t[..., None] < 0.18, METAL_DARK,
          np.where(t[..., None] < 0.62, METAL,
          np.where(t[..., None] < 0.82, METAL_LIGHT, METAL_DARK)))
    return col

def frame(px=512):
    x, y, r, a = grid(px)
    rgb = np.zeros(x.shape + (3,))
    alpha = np.zeros(x.shape)
    for k in range(8):
        e = tile_edge(x, y, r, a, 45 * k)
        on = (e > 0) & (e < BW)
        t = np.clip(e / BW, 0, 1)
        rgb = np.where(on[..., None], band_colour(t), rgb)
        alpha = np.where(on, 1.0, alpha)
    # hub ring + hub fill
    er = np.minimum(r - HUB_IN, HUB_OUT - r)
    ring = er > 0
    tr = np.clip(er / ((HUB_OUT - HUB_IN) / 2), 0, 1)       # 0 at both edges, 1 mid
    ring_col = np.where(tr[..., None] < 0.35, METAL_DARK, np.where(tr[..., None] < 0.75, METAL, METAL_LIGHT))
    rgb = np.where(ring[..., None], ring_col, rgb)
    alpha = np.where(ring, 1.0, alpha)
    hub = r <= HUB_IN
    rgb = np.where(hub[..., None], HUB_FILL, rgb)
    alpha = np.where(hub, 0.86, alpha)
    img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    im = down(img, px)
    return im.crop((px // 2, 0, px, px // 2))        # top-right quarter only

def wedge(center_deg, px=256, glow=False):
    x, y, r, a = grid(px)
    e = tile_edge(x, y, r, a, center_deg)
    if not glow:
        alpha = (e > BW * 0.5).astype(float)
    else:
        alpha = np.where(e > BW * 0.8, np.clip(1 - (e - BW) / 0.07, 0, 1) ** 1.6, 0)
    img = np.dstack([np.ones_like(alpha) * 255] * 3 + [alpha * 255]).astype(np.uint8)
    return down(img, px)

os.makedirs(OUT, exist_ok=True)
def save(im, name):
    im.save(os.path.join(OUT, name), compression="tga_rle")
save(frame(), "radial_frame.tga")
save(wedge(0), "radial_wedge0.tga")
save(wedge(45), "radial_wedge45.tga")
save(wedge(0, glow=True), "radial_glow0.tga")
save(wedge(45, glow=True), "radial_glow45.tga")
for f in sorted(os.listdir(OUT)):
    if f.startswith("radial_"):
        print(f, os.path.getsize(os.path.join(OUT, f)))
