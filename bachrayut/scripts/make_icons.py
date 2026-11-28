"""Draws the באחריות launcher icon (green tile, shield with a check) into the Android res folder."""
import sys, os
from PIL import Image, ImageDraw

GREEN = (15, 107, 79, 255)
PAPER = (243, 239, 230, 255)
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

def shield(draw, cx, cy, s, fill, check):
    w, h = s * 0.62, s * 0.74
    top = cy - h / 2
    pts = [(cx, top), (cx + w / 2, top + h * 0.17), (cx + w / 2, top + h * 0.48),
           (cx + w * 0.36, top + h * 0.74), (cx, top + h), (cx - w * 0.36, top + h * 0.74),
           (cx - w / 2, top + h * 0.48), (cx - w / 2, top + h * 0.17)]
    draw.polygon(pts, fill=fill)
    lw = max(2, int(s * 0.075))
    draw.line([(cx - w * 0.22, cy + h * 0.02), (cx - w * 0.04, cy + h * 0.18), (cx + w * 0.26, cy - h * 0.14)],
              fill=check, width=lw, joint="curve")

def tile(px, round_=False):
    k = 4; n = px * k
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if round_: d.ellipse([0, 0, n - 1, n - 1], fill=GREEN)
    else: d.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=GREEN)
    shield(d, n / 2, n / 2, n * 0.78, PAPER, GREEN)
    return im.resize((px, px), Image.LANCZOS)

def foreground(px):
    k = 4; n = px * k
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shield(d, n / 2, n / 2, n * 0.46, PAPER, GREEN)
    return im.resize((px, px), Image.LANCZOS)

res = sys.argv[1]
for dens, px in SIZES.items():
    folder = os.path.join(res, f"mipmap-{dens}"); os.makedirs(folder, exist_ok=True)
    tile(px).save(os.path.join(folder, "ic_launcher.png"))
    tile(px, True).save(os.path.join(folder, "ic_launcher_round.png"))
    foreground(FG[dens]).save(os.path.join(folder, "ic_launcher_foreground.png"))
# status-bar notification icon: white shield with the check cut out
NOTIFY = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
for dens, px in NOTIFY.items():
    k = 4; n = px * k
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shield(d, n / 2, n / 2, n * 1.15, (255, 255, 255, 255), (0, 0, 0, 0))
    folder = os.path.join(res, f"drawable-{dens}"); os.makedirs(folder, exist_ok=True)
    im.resize((px, px), Image.LANCZOS).save(os.path.join(folder, "ic_stat_notify.png"))
vals = os.path.join(res, "values"); os.makedirs(vals, exist_ok=True)
with open(os.path.join(vals, "ic_launcher_background.xml"), "w") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#0F6B4F</color>\n</resources>\n')
print("icons written to", res)
