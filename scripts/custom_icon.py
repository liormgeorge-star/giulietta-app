import sys
from PIL import Image, ImageDraw
src, res = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
for name, s, f in [("mdpi",48,108),("hdpi",72,162),("xhdpi",96,216),("xxhdpi",144,324),("xxxhdpi",192,432)]:
    d = f"{res}/mipmap-{name}"
    im.resize((s, s), Image.LANCZOS).save(f"{d}/ic_launcher.png")
    m = Image.new("L", (s*4, s*4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, s*4-1, s*4-1), fill=255)
    r = im.resize((s, s), Image.LANCZOS)
    r.putalpha(Image.composite(r.getchannel("A"), Image.new("L", (s, s), 0), m.resize((s, s), Image.LANCZOS)))
    r.save(f"{d}/ic_launcher_round.png")
    p = int(f * 0.61)
    fg = Image.new("RGBA", (f, f), (0, 0, 0, 0))
    fg.paste(im.resize((p, p), Image.LANCZOS), ((f-p)//2, (f-p)//2))
    fg.save(f"{d}/ic_launcher_foreground.png")
print("Applied", src)
