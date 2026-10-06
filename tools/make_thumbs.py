# Store thumbnails (1920x1080) from in-game captures + renders, with bold titles.
#   python tools/make_thumbs.py
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import numpy as np
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')
CAP = os.path.join(ROOT, 'scratch', 'captures')
REN = os.path.join(ROOT, 'marketing', 'renders')
OUT = os.path.join(ROOT, 'marketing')
W, H = 1920, 1080
IMPACT = r'C:\Windows\Fonts\impact.ttf'


def crop169(img, cx=0.5, cy=0.5, zoom=1.0):
    iw, ih = img.size
    h = ih / zoom
    w = h * 16 / 9
    if w > iw:
        w = iw
        h = w * 9 / 16
    x0 = min(max(0, cx * iw - w / 2), iw - w)
    y0 = min(max(0, cy * ih - h / 2), ih - h)
    return img.crop((int(x0), int(y0), int(x0 + w), int(y0 + h))).resize((W, H), Image.LANCZOS)


def title(img, text, xy, size, fill, stroke=(25, 10, 30), sw=14, anchor='la', rot=0):
    f = ImageFont.truetype(IMPACT, size)
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # drop shadow
    d.text((xy[0] + 8, xy[1] + 10), text, font=f, fill=(0, 0, 0, 150), anchor=anchor, stroke_width=sw, stroke_fill=(0, 0, 0, 150))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)
    if rot:
        layer = layer.rotate(rot, center=xy, resample=Image.BICUBIC)
    img.alpha_composite(layer)


def render(name, h):
    im = Image.open(os.path.join(REN, name + '.png')).convert('RGBA')
    k = h / im.height
    return im.resize((int(im.width * k), int(h)), Image.LANCZOS)


def soft(layer, color, alpha, blur):
    """Blurred silhouette of `layer`, padded so the blur isn't clipped at its edges."""
    pad = blur * 3
    a = Image.new('L', (layer.width + pad * 2, layer.height + pad * 2), 0)
    a.paste(layer.getchannel('A').point(lambda v: int(v * alpha)), (pad, pad))
    out = Image.new('RGBA', a.size, color + (0,))
    out.putalpha(a.filter(ImageFilter.GaussianBlur(blur)))
    return out, pad


def paste(img, layer, xy, shadow=True):
    if shadow:
        sh, pad = soft(layer, (0, 0, 0), 0.45, 12)
        img.alpha_composite(sh, (xy[0] + 14 - pad, xy[1] + 20 - pad))
    img.alpha_composite(layer, xy)


def vignette(img, strength=0.45):
    yy, xx = np.mgrid[0:H, 0:W].astype('float32')
    v = np.clip((np.hypot((xx - W / 2) / W, (yy - H / 2) / H) - 0.32) * 1.6, 0, strength)
    m = Image.fromarray((v * 255).astype('uint8'))
    return Image.composite(Image.new('RGBA', (W, H), (10, 5, 20, 255)), img, m)


# 1: RUN!
t1 = crop169(Image.open(os.path.join(CAP, 'thumb_run7.jpg')).convert('RGBA'), cx=0.42, cy=0.5, zoom=1.0)
t1 = ImageEnhance.Color(t1).enhance(1.15)
t1 = vignette(t1, 0.35)
title(t1, 'STEAL THE EGG...', (60, 50), 128, (255, 225, 70))
title(t1, 'THEN RUN!', (1850, 1010), 230, (255, 70, 60), anchor='rd', rot=4)
t1.convert('RGB').save(os.path.join(OUT, 'thumb_1.png'))

# 2: GET RICH
t2 = crop169(Image.open(os.path.join(CAP, 'thumb_base2.jpg')).convert('RGBA'), cx=0.5, cy=0.45, zoom=1.0)
t2 = ImageEnhance.Color(t2).enhance(1.1)
t2 = vignette(t2, 0.4)
title(t2, 'HATCH DRAGONS', (960, 40), 170, (140, 255, 140), anchor='ma')
title(t2, 'GET RICH!', (960, 1030), 210, (255, 215, 60), anchor='md')
t2.convert('RGB').save(os.path.join(OUT, 'thumb_2.png'))

# 3: collection collage
yy, xx = np.mgrid[0:H, 0:W].astype('float32')
d = np.clip(np.hypot(xx - W / 2, yy - H * 0.55) / (W * 0.6), 0, 1)[..., None]
a, b = np.array((120, 70, 230), 'float32'), np.array((20, 15, 60), 'float32')
bg = Image.fromarray(np.dstack([(a + (b - a) * d).astype('uint8'), np.full((H, W), 255, 'uint8')]))
rays = Image.new('L', (W, H), 0)
dr = ImageDraw.Draw(rays)
for k in range(18):
    dr.pieslice([-W, -H * 1.5, W * 2, H * 2.6], k * 20, k * 20 + 8, fill=30)
t3 = Image.composite(Image.new('RGBA', (W, H), (255, 240, 255, 255)), bg, rays.filter(ImageFilter.GaussianBlur(12)))
ring = [
    ('rd_phoenix', 330, 120, 470), ('rd_unicorn', 300, 360, 600), ('rd_bumble', 260, 60, 760),
    ('rd_pharaoh', 300, 1500, 460), ('rd_disco', 300, 1300, 620), ('rd_aurora', 280, 1640, 760),
    ('rd_ghost', 230, 520, 820), ('rd_pizza', 240, 1180, 830), ('rd_nightmare', 250, 1460, 280), ('rd_storm', 250, 260, 250),
]
for name, h, x, y in ring:
    r = render(name, h)
    paste(t3, r, (x - r.width // 2, y - r.height // 2))
star = render('rd_galaxy_emperor', 640)
glow, gpad = soft(star, (255, 230, 140), 1.0, 40)
pos = (W // 2 - star.width // 2, 300)
t3.alpha_composite(glow, (pos[0] - gpad, pos[1] - gpad))
paste(t3, star, pos)
title(t3, '38 DRAGONS TO COLLECT', (960, 40), 130, (255, 230, 90), anchor='ma')
title(t3, 'SECRET + MUTATED!', (960, 1040), 150, (120, 240, 255), anchor='md')
t3.convert('RGB').save(os.path.join(OUT, 'thumb_3.png'))
print('saved')
