# Game icon (512x512): a cute baby dragon hugging a golden egg while an angry
# guardian looms behind. Built from the cut-out renders in marketing/renders.
#   python tools/make_icon.py
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import numpy as np
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')
REN = os.path.join(ROOT, 'marketing', 'renders')
S = 1024  # draw at 2x, downsample at the end


def load(name, h):
    im = Image.open(os.path.join(REN, name + '.png')).convert('RGBA')
    k = h / im.height
    return im.resize((int(im.width * k), int(h)), Image.LANCZOS)


def radial(c_in, c_out, cx=0.5, cy=0.45):
    yy, xx = np.mgrid[0:S, 0:S].astype('float32')
    d = np.clip(np.hypot(xx - S * cx, yy - S * cy) / (S * 0.72), 0, 1)[..., None]
    a, b = np.array(c_in, 'float32'), np.array(c_out, 'float32')
    rgb = (a + (b - a) * d ** 1.2).astype('uint8')
    return Image.fromarray(np.dstack([rgb, np.full((S, S), 255, 'uint8')]))


def soft(layer, color, alpha, blur):
    # padded so the blur isn't clipped at the layer's edges
    pad = blur * 3
    a = Image.new('L', (layer.width + pad * 2, layer.height + pad * 2), 0)
    a.paste(layer.getchannel('A').point(lambda v: int(min(255, v * alpha))), (pad, pad))
    out = Image.new('RGBA', a.size, color + (0,))
    out.putalpha(a.filter(ImageFilter.GaussianBlur(blur)))
    return out, pad


def shadow(layer, blur=14, alpha=0.55, off=(10, 18)):
    sh, pad = soft(layer, (0, 0, 0), alpha, blur)
    return sh, (off[0] - pad, off[1] - pad)


def glow(layer, color, blur=28, strength=1.0):
    return soft(layer, color, strength, blur)


img = radial((255, 214, 120), (196, 60, 40))
# sun rays
rays = Image.new('L', (S, S), 0)
d = ImageDraw.Draw(rays)
for k in range(16):
    a0 = k * 22.5
    d.pieslice([-S, -S * 0.9, S * 2, S * 2.1], a0, a0 + 10, fill=40)
rays = rays.filter(ImageFilter.GaussianBlur(10))
img = Image.composite(Image.new('RGBA', (S, S), (255, 245, 200, 255)), img, rays)

# guardian looming behind (darkened, big, cropped by the frame)
g = load('rg_infernus', 980)
g = ImageEnhance.Brightness(g).enhance(0.62)
gx, gy = (S - g.width) // 2 + 40, -150
gl, gp = glow(g, (255, 120, 40), 40, 0.9)
img.alpha_composite(gl, (gx - gp, gy - gp))
img.alpha_composite(g, (gx, gy))

# baby dragon + egg in front
baby = load('rd_aurora', 620)
egg = load('re_goldcream', 400)
bx, by = 70, S - baby.height + 30
ex, ey = 560, S - egg.height - 30
for layer, pos in ((baby, (bx, by)), (egg, (ex, ey))):
    sh, off = shadow(layer)
    img.alpha_composite(sh, (pos[0] + off[0], pos[1] + off[1]))
gl, gp = glow(egg, (255, 230, 120), 30, 1.2)
img.alpha_composite(gl, (ex - gp, ey - gp))
img.alpha_composite(baby, (bx, by))
img.alpha_composite(egg, (ex, ey))

# sparkles
d = ImageDraw.Draw(img)
for (sx, sy, r) in [(860, 640, 34), (930, 520, 18), (470, 760, 20), (120, 160, 24)]:
    d.polygon([(sx, sy - r), (sx + r * 0.28, sy - r * 0.28), (sx + r, sy), (sx + r * 0.28, sy + r * 0.28), (sx, sy + r), (sx - r * 0.28, sy + r * 0.28), (sx - r, sy), (sx - r * 0.28, sy - r * 0.28)], fill=(255, 255, 240, 235))

# vignette
yy, xx = np.mgrid[0:S, 0:S].astype('float32')
v = np.clip((np.hypot(xx - S / 2, yy - S / 2) / (S * 0.7) - 0.55) * 1.4, 0, 0.55)
vig = Image.fromarray((v * 255).astype('uint8'))
img = Image.composite(Image.new('RGBA', (S, S), (40, 10, 10, 255)), img, vig)

out = img.resize((512, 512), Image.LANCZOS).convert('RGB')
out.save(os.path.join(ROOT, 'marketing', 'game_icon.png'))
print('saved')
