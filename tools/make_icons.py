# 512x512 store icons for game passes / developer products, built from the 3D
# renders in marketing/renders (cut out by tools/key.py) or a big emoji.
#   python tools/make_icons.py
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os

ROOT = os.path.join(os.path.dirname(__file__), '..')
REN = os.path.join(ROOT, 'marketing', 'renders')
OUT = os.path.join(ROOT, 'marketing', 'icons')
os.makedirs(OUT, exist_ok=True)
EMOJI = ImageFont.truetype(r'C:\Windows\Fonts\seguiemj.ttf', 109)  # emoji font renders at 109px bitmaps
BOLD = r'C:\Windows\Fonts\impact.ttf'
S = 512


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def G(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def base(c1, c2):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    yy, xx = [v.astype('float32') for v in __import__('numpy').mgrid[0:S, 0:S]]
    import numpy as np
    d = np.clip(np.hypot(xx - S * 0.5, yy - S * 0.36) / (S * 0.78), 0, 1)[..., None]
    a, b = np.array(c1, 'float32'), np.array(c2, 'float32')
    rgb = (a + (b - a) * d).astype('uint8')
    bg = Image.fromarray(np.dstack([rgb, np.full((S, S), 255, 'uint8')]))
    # soft light rays
    rays = Image.new('L', (S, S), 0)
    dr = ImageDraw.Draw(rays)
    for k in range(12):
        a0 = k * 30
        dr.pieslice([-S, -S * 1.1, S * 2, S * 1.9], a0, a0 + 12, fill=26)
    rays = rays.filter(ImageFilter.GaussianBlur(6))
    white = Image.new('RGBA', (S, S), (255, 255, 255, 255))
    bg = Image.composite(white, bg, rays)
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([8, 8, S - 8, S - 8], radius=96, fill=255)
    img.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([8, 8, S - 8, S - 8], radius=96, outline=lerp(c2, (0, 0, 0), 0.5) + (255,), width=14)
    for (sx, sy, r) in [(410, 100, 22), (96, 410, 15), (430, 390, 11), (100, 108, 10)]:
        d.polygon([(sx, sy - r), (sx + r * 0.3, sy - r * 0.3), (sx + r, sy), (sx + r * 0.3, sy + r * 0.3), (sx, sy + r), (sx - r * 0.3, sy + r * 0.3), (sx - r, sy), (sx - r * 0.3, sy - r * 0.3)], fill=(255, 255, 255, 220))
    return img


def paste_shadowed(img, layer, pos):
    shadow = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel('A').point(lambda a: int(a * 0.5)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(9))
    img.alpha_composite(shadow, (pos[0] + 8, pos[1] + 14))
    img.alpha_composite(layer, pos)


def render(name, box):
    im = Image.open(os.path.join(REN, name + '.png')).convert('RGBA')
    im.thumbnail((box, box), Image.LANCZOS)
    return im


def emoji(ch, size):
    layer = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((80, 84), ch, font=EMOJI, anchor='mm', embedded_color=True)
    bb = layer.getbbox()
    layer = layer.crop(bb) if bb else layer
    k = size / max(layer.size)
    return layer.resize((max(1, int(layer.width * k)), max(1, int(layer.height * k))), Image.LANCZOS)


def label(img, text, c2, y=0.86, size=82):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(BOLD, size)
    d.text((S / 2, S * y), text, font=f, anchor='mm', fill=(255, 255, 255), stroke_width=9, stroke_fill=lerp(c2, (0, 0, 0), 0.65))


def icon(name, c1, c2, main=None, emo=None, badge=None, text=None, main_box=380, main_y=None):
    img = base(c1, c2)
    if main:
        r = render(main, main_box)
        y = main_y if main_y is not None else (S - r.height) // 2 - (24 if text else 0)
        paste_shadowed(img, r, ((S - r.width) // 2, y))
    elif emo:
        e = emoji(emo, 300)
        paste_shadowed(img, e, ((S - e.width) // 2, (S - e.height) // 2 - (28 if text else 0)))
    if badge:
        b = emoji(badge, 150)
        paste_shadowed(img, b, (S - b.width - 34, 30))
    if text:
        label(img, text, c2)
    img.save(os.path.join(OUT, name + '.png'))


specs = [
    # passes
    dict(name='pass_DoubleCash', c1=G('#b6ff9a'), c2=G('#1f8a34'), main='rm_gold_phoenix', badge='💰', text='2X CASH'),
    dict(name='pass_VIP', c1=G('#ffe27a'), c2=G('#b8600b'), main='rm_gold_blaze', badge='👑', text='VIP'),
    dict(name='pass_AutoCollect', c1=G('#c9f1ff'), c2=G('#2b5fc9'), emo='🧲', badge='💵', text='AUTO'),
    dict(name='pass_Lucky', c1=G('#9dffa0'), c2=G('#127a3a'), main='rm_galaxy_storm', badge='🍀', text='LUCKY'),
    dict(name='pass_FastHatch', c1=G('#ffd0f0'), c2=G('#a1218a'), main='re_Epic', badge='⏩', text='2X FAST', main_box=330),
    dict(name='pass_MegaBase', c1=G('#ffcf9a'), c2=G('#b04a12'), emo='🏰', badge='➕', text='+4 PADS'),
    dict(name='pass_SuperLock', c1=G('#ffb0b0'), c2=G('#9b1525'), emo='🔒', text='SUPER LOCK'),
    dict(name='pass_SpeedBoost', c1=G('#a8dcff'), c2=G('#1d47b8'), emo='👟', badge='⚡', text='+25%'),
    # cash
    dict(name='dev_Cash1', c1=G('#d6ffb0'), c2=G('#2f8f1a'), emo='💵'),
    dict(name='dev_Cash2', c1=G('#c8ffb0'), c2=G('#22801a'), emo='💰'),
    dict(name='dev_Cash3', c1=G('#c9f1ff'), c2=G('#1f6fb8'), emo='💎'),
    dict(name='dev_Cash4', c1=G('#ffe9a0'), c2=G('#8f3fd1'), main='rm_gold_blaze', badge='💰'),
    # boosts / utility
    dict(name='dev_HatchNow', c1=G('#fff0b0'), c2=G('#c27a00'), main='re_Legendary', badge='🐣', main_box=340),
    dict(name='dev_LockBase', c1=G('#ffc0c0'), c2=G('#9b1525'), emo='🔒', text='5 MIN'),
    dict(name='dev_CashBoost', c1=G('#c8ffb0'), c2=G('#1f7a2a'), emo='💸', text='2X 15M'),
    dict(name='dev_LuckBoost', c1=G('#f2c2ff'), c2=G('#6a1fa8'), emo='🔮', text='2X 15M'),
    dict(name='dev_AdLuck', c1=G('#c8ffcf'), c2=G('#127a3a'), emo='🍀', text='10 MIN'),
    dict(name='dev_ServerLuck', c1=G('#fff6b0'), c2=G('#c2367a'), emo='🌈', text='SERVER'),
    dict(name='dev_Speed10', c1=G('#bfe4ff'), c2=G('#1d47b8'), emo='⚡', text='+10'),
    # events
    dict(name='dev_Event_golden', c1=G('#fff0a0'), c2=G('#b8600b'), main='rm_gold_phoenix', badge='🌟'),
    dict(name='dev_Event_meteor', c1=G('#ffcf9a'), c2=G('#5a1a70'), emo='🌠'),
    dict(name='dev_Event_bloodmoon', c1=G('#ff9a9a'), c2=G('#3a0612'), emo='🌑', badge='🩸'),
    dict(name='dev_Event_secret', c1=G('#e8e8ff'), c2=G('#151530'), main='re_Secret', badge='❓', main_box=340),
    # eggs bought safely
    dict(name='dev_Egg_Common', c1=G('#eef0f4'), c2=G('#6a7280'), main='re_Common', main_box=320),
    dict(name='dev_Egg_Uncommon', c1=G('#d0ffc8'), c2=G('#2c8a30'), main='re_Uncommon', main_box=320),
    dict(name='dev_Egg_Rare', c1=G('#c8e4ff'), c2=G('#1f5fbf'), main='re_Rare', main_box=320),
    dict(name='dev_Egg_Epic', c1=G('#ecd0ff'), c2=G('#6b22b5'), main='re_Epic', main_box=320),
    dict(name='dev_Egg_Legendary', c1=G('#fff3b8'), c2=G('#c27a00'), main='re_Legendary', main_box=320),
    dict(name='dev_Egg_Mythic', c1=G('#ffcadc'), c2=G('#b5124f'), main='re_Mythic', main_box=320),
    dict(name='dev_Egg_Secret', c1=G('#f0f0ff'), c2=G('#0c0c1c'), main='re_Secret', main_box=320),
]
for s in specs:
    icon(**s)
print('made', len(specs))
