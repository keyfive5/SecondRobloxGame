# Cut a photo-studio render (magenta backdrop) out to a transparent PNG.
#   python tools/key.py in.jpg out.png [pad_fraction]
# Soft alpha from the distance to pure magenta, magenta spill removed from edges,
# cropped to the subject with a little padding.
import sys
from PIL import Image
import numpy as np

KEY = np.array([255.0, 0.0, 255.0])


def key(src: str, dst: str, pad: float = 0.06):
    img = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
    d = np.linalg.norm(img - KEY, axis=2)
    # "magenta-ness": high red + high blue + low green is backdrop
    mag = np.minimum(img[..., 0], img[..., 2]) - img[..., 1]
    t0, t1 = 70.0, 150.0
    alpha = np.clip((d - t0) / (t1 - t0), 0, 1)
    alpha = np.where(mag > 200, 0, alpha)
    # despill: remove the backdrop's contribution from semi-transparent edges
    a3 = alpha[..., None]
    with np.errstate(divide='ignore', invalid='ignore'):
        col = np.where(a3 > 0.02, (img - (1 - a3) * KEY) / np.maximum(a3, 0.02), img)
    col = np.clip(col, 0, 255)
    # pull leftover pink out of edge pixels
    edge = (alpha < 0.98)[..., None]
    g = col[..., 1:2]
    col = np.where(edge, np.concatenate([np.minimum(col[..., 0:1], g + 60), g, np.minimum(col[..., 2:3], g + 60)], axis=2), col)
    rgba = np.dstack([col, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba)
    bbox = out.getchannel('A').point(lambda a: 255 if a > 20 else 0).getbbox()
    if bbox:
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        p = int(max(w, h) * pad)
        out = out.crop((max(0, bbox[0] - p), max(0, bbox[1] - p), min(out.width, bbox[2] + p), min(out.height, bbox[3] + p)))
    out.save(dst)
    return out.size


if __name__ == '__main__':
    print(key(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.06))
