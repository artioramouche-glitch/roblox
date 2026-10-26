"""
COMPOSE REVIEW, BLENDER EDITION
Same compare sheet and numbers as compose_review.py, but it runs in Blender's bundled Python
(bpy + numpy), so no system Python or Pillow is needed. Added for Roblox Ultimate MCP; not part
of the original skill.

blender --background --python scripts/compose_review_bpy.py -- --ref ref/front.png \
  --render review/02_blockout/clay_ref.png --out review/02_blockout/compare_ref.png \
  --overlay 0.5 --gameplay-px 128 --measure

Panels left to right: REF, RENDER, OVERLAY, GAMEPLAY strip. They have no text labels (no font
rasteriser here). The reference can be any image Blender reads (png, jpg, webp...); --measure
writes the same JSON as compose_review.py next to the sheet.
"""
import bpy, sys, os, json, argparse
import numpy as np

GREY = np.array([110, 110, 110, 255], np.float32) / 255
BACK = np.array([40, 40, 40, 255], np.float32) / 255


# IMAGES (H, W, 4) float RGBA 0..1, row 0 = top

def load(path):
    img = bpy.data.images.load(os.path.abspath(path), check_existing=False)
    w, h, c = img.size[0], img.size[1], img.channels
    px = np.empty(w * h * c, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    px = px.reshape(h, w, c)[::-1]
    if c == 4:
        return px.copy()
    rgb = np.repeat(px[..., :1], 3, -1) if c < 3 else px[..., :3]
    return np.concatenate([rgb, np.ones((h, w, 1), np.float32)], -1)


def save(path, arr):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("_review_sheet", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1], np.float32).ravel())
    img.filepath_raw = os.path.abspath(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def resize(arr, w, h):
    """Blender's own image scaler (area filter when shrinking)."""
    if arr.shape[0] == h and arr.shape[1] == w:
        return arr
    img = bpy.data.images.new("_review_tmp", arr.shape[1], arr.shape[0], alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1], np.float32).ravel())
    img.scale(w, h)
    out = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(out)
    bpy.data.images.remove(img)
    return out.reshape(h, w, 4)[::-1].copy()


def fit_height(img, height):
    return resize(img, max(1, int(img.shape[1] * height / img.shape[0])), height)


def over_grey(img):
    out = img.copy()
    a = img[..., 3:4]
    out[..., :3] = img[..., :3] * a + GREY[:3] * (1 - a)
    out[..., 3] = 1
    return out


def grey(img):
    out = img.copy()
    out[..., :3] = (img[..., 0] * 0.299 + img[..., 1] * 0.587 + img[..., 2] * 0.114)[..., None]
    return out


def paste(canvas, img, x, y):
    """Alpha-blends img onto canvas in place, top-left corner at (x, y)."""
    h, w = img.shape[:2]
    region = canvas[y:y + h, x:x + w]
    a = img[..., 3:4]
    region[..., :3] = img[..., :3] * a + region[..., :3] * (1 - a)


def panel(color, h, w):
    return np.tile(color, (h, w, 1))


# MASKS

def render_mask(img):
    return img[..., 3] > 16 / 255


def ref_mask(img, tol=40):
    a = img[..., 3]
    if a.min() < 250 / 255:
        return a > 16 / 255
    rgb = img[..., :3]
    corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
                              rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
    d = np.abs(rgb - corners.mean(0)) * 255
    return d[..., 0] * 0.299 + d[..., 1] * 0.587 + d[..., 2] * 0.114 > tol


def bbox_of(mask):
    ys, xs = np.nonzero(mask)
    if not len(ys):
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def crop_pad(img, mask, pad_frac=0.03):
    b = bbox_of(mask)
    if not b:
        return img, mask
    p = int(max(b[2] - b[0], b[3] - b[1]) * pad_frac)
    H, W = mask.shape
    x0, y0, x1, y1 = max(0, b[0] - p), max(0, b[1] - p), min(W, b[2] + p), min(H, b[3] + p)
    return img[y0:y1, x0:x1], mask[y0:y1, x0:x1]


def nearest(mask, w, h):
    ys = np.minimum(((np.arange(h) + 0.5) * mask.shape[0] / h).astype(int), mask.shape[0] - 1)
    xs = np.minimum(((np.arange(w) + 0.5) * mask.shape[1] / w).astype(int), mask.shape[1] - 1)
    return mask[ys][:, xs]


# MEASURE

def profile(mask, bands=10, height=256):
    """Widths (as a fraction of silhouette height) at band centres from top to bottom, plus aspect."""
    b = bbox_of(mask)
    if not b:
        return None
    m = mask[b[1]:b[3], b[0]:b[2]]
    m = nearest(m, max(1, int(m.shape[1] * height / m.shape[0])), height)
    widths = []
    for i in range(bands):
        xs = np.nonzero(m[int((i + 0.5) * height / bands)])[0]
        widths.append(round(float(xs.max() - xs.min() + 1) / height, 4) if len(xs) else 0.0)
    return {"aspect_w_over_h": round(m.shape[1] / height, 4), "band_widths": widths, "_img": m}


def iou(m1, m2):
    h, w = max(m1.shape[0], m2.shape[0]), max(m1.shape[1], m2.shape[1])

    def centre(m):
        c = np.zeros((h, w), bool)
        y, x = (h - m.shape[0]) // 2, (w - m.shape[1]) // 2
        c[y:y + m.shape[0], x:x + m.shape[1]] = m
        return c
    a, b = centre(m1), centre(m2)
    union = np.logical_or(a, b).sum()
    return round(float(np.logical_and(a, b).sum()) / float(union), 4) if union else 0.0


# MAIN

def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("--ref", required=True)
    p.add_argument("--render", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--height", type=int, default=768)
    p.add_argument("--overlay", type=float, default=0.5, help="reference opacity in the overlay panel, 0 disables")
    p.add_argument("--gameplay-px", type=int, default=0)
    p.add_argument("--grey", action="store_true")
    p.add_argument("--measure", action="store_true")
    p.add_argument("--ref-tol", type=int, default=40)
    p.add_argument("--no-crop", action="store_true", help="keep full frames instead of cropping to the silhouettes")
    a = p.parse_args(argv)

    ref, ren = load(a.ref), load(a.render)
    rm, nm = ref_mask(ref, a.ref_tol), render_mask(ren)
    if not a.no_crop:
        ref, rm = crop_pad(ref, rm)
        ren, nm = crop_pad(ren, nm)
    if a.grey:
        ref, ren = grey(ref), grey(ren)

    H = a.height
    panels = [fit_height(ref, H), fit_height(over_grey(ren), H)]
    if a.overlay > 0:
        rr, rn = panels[0], panels[1]
        w = max(rr.shape[1], rn.shape[1])
        over = panel(GREY, H, w)
        paste(over, rn, (w - rn.shape[1]) // 2, 0)
        top = rr.copy()
        top[..., 3] *= a.overlay
        paste(over, top, (w - rr.shape[1]) // 2, 0)
        panels.append(over)
    if a.gameplay_px:
        gp = min(a.gameplay_px, H)
        gr, gn = fit_height(ref, gp), fit_height(over_grey(ren), gp)
        strip = panel(GREY, H, gr.shape[1] + gn.shape[1] + 12)
        paste(strip, gr, 0, 0)
        paste(strip, gn, gr.shape[1] + 12, 0)
        panels.append(strip)

    gap = 16
    sheet = panel(BACK, H + gap * 2, sum(im.shape[1] for im in panels) + gap * (len(panels) + 1))
    x = gap
    for im in panels:
        paste(sheet, im, x, gap)
        x += im.shape[1] + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    save(a.out, sheet)
    print("sheet", a.out)

    if a.measure:
        pr, pn = profile(rm), profile(nm)
        if not pr or not pn:
            print("MEASURE skipped: empty mask")
            return
        res = {
            "ref": {k: v for k, v in pr.items() if k != "_img"},
            "render": {k: v for k, v in pn.items() if k != "_img"},
            "iou": iou(pr["_img"], pn["_img"]),
            "band_width_diff": [round(n - r, 4) for r, n in zip(pr["band_widths"], pn["band_widths"])],
            "aspect_diff": round(pn["aspect_w_over_h"] - pr["aspect_w_over_h"], 4),
        }
        jpath = os.path.splitext(a.out)[0] + ".json"
        with open(jpath, "w") as f:
            json.dump(res, f, indent=2)
        print("IoU %.3f  aspect diff %+.3f" % (res["iou"], res["aspect_diff"]))
        print("band width diff (render minus ref, top to bottom):", res["band_width_diff"])
        print("measure", jpath)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
