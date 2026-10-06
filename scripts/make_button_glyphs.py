# make_button_glyphs.py - face-button icons for both button styles
# (Textures/btn_xb_a.tga ... btn_ps_triangle.tga), used on the controller bar
# and inline in hint text. Same look for both: a dark disc with a thin rim and
# the button's letter / symbol in its colour.
from PIL import Image, ImageDraw, ImageFont
import os

N, SS = 64, 4                      # output size, supersampling
OUT = os.path.join(os.path.dirname(__file__), "..", "addon", "WowPad", "Textures")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

XBOX = {"a": (90, 210, 90), "b": (255, 85, 85), "x": (85, 153, 255), "y": (255, 221, 51)}
PS = {"cross": (125, 166, 255), "circle": (255, 107, 107), "square": (255, 138, 216), "triangle": (79, 214, 160)}

def base():
    S = N * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = 2 * SS
    d.ellipse((m, m, S - m, S - m), fill=(20, 20, 22, 235), outline=(150, 150, 155, 255), width=3 * SS)
    return im, d, S

def save(im, name):
    im.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, name + ".tga"))

for k, col in XBOX.items():
    im, d, S = base()
    f = ImageFont.truetype(FONT, int(S * 0.58))
    t = k.upper()
    l, t0, r, b = d.textbbox((0, 0), t, font=f)
    d.text(((S - (r - l)) / 2 - l, (S - (b - t0)) / 2 - t0), t, font=f, fill=col + (255,))
    save(im, "btn_xb_" + k)

W = int(6 * SS)                    # symbol stroke width
for k, col in PS.items():
    im, d, S = base()
    c, r = S / 2, S * 0.24
    fill = col + (255,)
    if k == "cross":
        d.line((c - r, c - r, c + r, c + r), fill=fill, width=W)
        d.line((c - r, c + r, c + r, c - r), fill=fill, width=W)
    elif k == "circle":
        d.ellipse((c - r, c - r, c + r, c + r), outline=fill, width=W)
    elif k == "square":
        d.rectangle((c - r * 0.9, c - r * 0.9, c + r * 0.9, c + r * 0.9), outline=fill, width=W)
    else:
        h = r * 1.15
        pts = [(c, c - h), (c + h * 0.95, c + h * 0.62), (c - h * 0.95, c + h * 0.62)]
        d.line(pts + [pts[0]], fill=fill, width=W, joint="curve")
    save(im, "btn_ps_" + k)
print("written")
