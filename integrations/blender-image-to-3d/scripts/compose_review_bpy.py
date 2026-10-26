"""
COMPOSE REVIEW, BLENDER EDITION
Same compare sheet and numbers as compose_review.py, but it runs in Blender's bundled Python
(bpy + numpy), so no system Python or Pillow is needed. Added for Roblox Ultimate MCP; not part
of the original skill.

blender --background --python scripts/compose_review_bpy.py -- --ref ref/front.png \
  --render review/02_blockout/clay_ref.png --out review/02_blockout/compare_ref.png \
  --overlay 0.5 --gameplay-px 128 --measure

Panels left to right: REF, RENDER, OVERLAY, GAMEPLAY strip, DETAIL map. They have no text labels
(no font rasteriser here). The reference can be any image Blender reads (png, jpg, webp...);
--measure writes the same JSON as compose_review.py next to the sheet.

--detail (with --measure) checks inside the silhouette, which IoU cannot see: both images are
stretched onto the reference's box and cut into a grid (--grid ROWS COLS). Per cell it compares
the detail (edge strength relative to each image's own average, so a reference drawn with outlines
and a shaded render compare by where the detail is) and the mean colour. The DETAIL panel paints
the reference: red = the reference has more detail there (missing bolts, grooves, plates), blue =
the colour differs, magenta = both. Cells are named r<row> c<col> from the top left.
"""
import bpy, sys, os, json, argparse
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_matte_bpy import morph

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


def detail_check(ref, rm, ren, nm, grid, ratio_tol, colour_tol):
    """Per grid cell: relative detail and mean colour of the reference vs the model. Returns (report, panel)."""
    def tight(img, mask):
        b = bbox_of(mask)
        return img[b[1]:b[3], b[0]:b[2]], mask[b[1]:b[3], b[0]:b[2]]
    r_img, r_m = tight(ref, rm)
    n_img, n_m = tight(ren, nm)
    H = 256
    W = max(1, int(r_img.shape[1] * H / r_img.shape[0]))
    r_img, n_img = resize(r_img, W, H), resize(n_img, W, H)  # the model stretched onto the reference box, like the IoU
    r_m, n_m = nearest(r_m, W, H), nearest(n_m, W, H)

    def edges(img, m):
        lum = img[..., 0] * 0.299 + img[..., 1] * 0.587 + img[..., 2] * 0.114
        gx, gy = np.zeros_like(lum), np.zeros_like(lum)
        gx[:, 1:-1] = lum[:, 2:] - lum[:, :-2]
        gy[1:-1] = lum[2:] - lum[:-2]
        inner = morph(m, 3, False)  # the outline of the silhouette is the IoU's job, not detail
        return np.sqrt(gx ** 2 + gy ** 2) * inner, inner

    er, ir = edges(r_img, r_m)
    en, inn = edges(n_img, n_m)
    gr, gn = er.sum() / max(1, ir.sum()), en.sum() / max(1, inn.sum())
    # exposure and white balance differ between a drawing and a render: match the model's overall colour to the reference's
    gain = np.median(r_img[r_m][:, :3], 0) / np.maximum(np.median(n_img[n_m][:, :3], 0), 1e-3)
    R, C = grid
    ratio, colour, flags, checked, ok = [], [], [], 0, 0
    overlay = np.zeros((H, W, 4), np.float32)
    for i in range(R):
        ratio.append([])
        colour.append([])
        for j in range(C):
            ys, xs = slice(i * H // R, (i + 1) * H // R), slice(j * W // C, (j + 1) * W // C)
            both = r_m[ys, xs] & n_m[ys, xs]
            if both.mean() < 0.3:  # mostly outside one silhouette: the IoU covers it
                ratio[i].append(None)
                colour[i].append(None)
                continue
            checked += 1
            dr = er[ys, xs].sum() / max(1, ir[ys, xs].sum()) / max(gr, 1e-6)
            dn = en[ys, xs].sum() / max(1, inn[ys, xs].sum()) / max(gn, 1e-6)
            # median, not mean: thin outlines in a drawing must not darken the cell
            cr_ = np.median(r_img[ys, xs][both][:, :3], 0) * 255
            cn_ = np.clip(np.median(n_img[ys, xs][both][:, :3], 0) * gain, 0, 1) * 255
            cd = float(np.sqrt(((cr_ - cn_) ** 2).sum()))
            ratio[i].append(round(float(dr / max(dn, 1e-6)), 2))
            colour[i].append(round(cd))
            missing = dr > 0.8 and dr > ratio_tol * dn
            extra = dn > 1.0 and dn > 1.5 * ratio_tol * dr  # stricter: mostly a few pixels of misalignment
            off = cd > colour_tol
            name = "r%d c%d" % (i + 1, j + 1)
            if missing:
                flags.append("%s: the reference has %.1fx more detail (bolts, grooves, plates, edges)" % (name, dr / max(dn, 1e-6)))
            if extra:
                flags.append("%s: the model has %.1fx more detail than the reference" % (name, dn / max(dr, 1e-6)))
            if off:
                flags.append("%s: colour differs, reference rgb(%d, %d, %d) vs model rgb(%d, %d, %d)" % ((name,) + tuple(int(v) for v in cr_) + tuple(int(v) for v in cn_)))
            if missing or extra or off:
                tint = (1.0, 0.1, 0.9) if (missing or extra) and off else (1.0, 0.15, 0.1) if (missing or extra) else (0.2, 0.4, 1.0)
                overlay[ys, xs] = tint + (0.45,)
            else:
                ok += 1
    overlay[[k * H // R for k in range(1, R)], :] = (1, 1, 1, 0.35)
    overlay[:, [k * W // C for k in range(1, C)]] = (1, 1, 1, 0.35)
    panel = over_grey(r_img)
    paste(panel, overlay, 0, 0)
    report = {"grid": [R, C], "score": round(ok / max(1, checked), 3), "cells_checked": checked,
              "flags": flags, "detail_ratio_ref_over_model": ratio, "colour_diff": colour}
    return report, panel


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
    p.add_argument("--detail", action="store_true", help="also compare detail and colour inside the silhouette, cell by cell")
    p.add_argument("--grid", type=int, nargs=2, default=[6, 8], metavar=("ROWS", "COLS"))
    p.add_argument("--detail-ratio", type=float, default=1.6, help="flag a cell when one image has this many times more detail")
    p.add_argument("--colour-tol", type=float, default=70, help="flag a cell when the mean colours are this far apart (RGB 0-441)")
    a = p.parse_args(argv)

    ref, ren = load(a.ref), load(a.render)
    rm, nm = ref_mask(ref, a.ref_tol), render_mask(ren)
    if not a.no_crop:
        ref, rm = crop_pad(ref, rm)
        ren, nm = crop_pad(ren, nm)
    detail = None
    if a.detail and rm.any() and nm.any():
        detail, detail_panel = detail_check(ref, rm, ren, nm, a.grid, a.detail_ratio, a.colour_tol)
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
    if detail:
        panels.append(fit_height(detail_panel, H))

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
        if detail:
            res["detail"] = detail
        jpath = os.path.splitext(a.out)[0] + ".json"
        with open(jpath, "w") as f:
            json.dump(res, f, indent=2)
        print("IoU %.3f  aspect diff %+.3f" % (res["iou"], res["aspect_diff"]))
        print("band width diff (render minus ref, top to bottom):", res["band_width_diff"])
        if detail:
            print("DETAIL score %.2f (%d cells checked), %d flag(s)" % (detail["score"], detail["cells_checked"], len(detail["flags"])))
            for f in detail["flags"]:
                print("  " + f)
        print("measure", jpath)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
