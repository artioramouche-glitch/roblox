"""
MAKE MATTE
Cleans a reference picture into a matte (subject opaque, everything else transparent) for
compose_review (--ref), world_gate (--matte) and fit_camera (--matte). The skill asks for
"cleaned reference mattes" but ships no tool for it. Added for Roblox Ultimate MCP; not part of
the original skill. Runs in Blender's Python (bpy + numpy).

blender --background --python scripts/make_matte_bpy.py -- --ref ref/concept.png --out ref/concept_matte.png

Background = the colour of the image corners. A pixel belongs to the subject when it is far from
that colour in RGB (so a brown subject on a grey background counts even at the same brightness).
Then: --open drops lines and specks thinner than about 2 x open px (grid, axis lines, rulers),
--close bridges gaps narrower than about 2 x close px (outlines), holes are filled, and only the
blobs at least --min-blob of the largest one are kept (labels, logos). A picture that already has
transparency keeps its alpha as the start mask.
"""
import bpy, sys, os, argparse
from collections import deque
import numpy as np


def load(path):
    """(H, W, 4) float RGBA in 0..1, row 0 = top."""
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
    img = bpy.data.images.new("_matte", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1], np.float32).ravel())
    img.filepath_raw = os.path.abspath(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def morph(m, r, grow):
    """Square dilation (grow) or erosion of radius r, as two 1D passes."""
    if r <= 0:
        return m
    for axis in (0, 1):
        p = np.pad(m, [(r, r) if a == axis else (0, 0) for a in (0, 1)], constant_values=False)
        acc = np.zeros_like(m) if grow else np.ones_like(m)
        n = m.shape[axis]
        for k in range(2 * r + 1):
            s = p[k:k + n] if axis == 0 else p[:, k:k + n]
            acc = (acc | s) if grow else (acc & s)
        m = acc
    return m


def components(mask):
    """4-connected labels (0 = not in the mask) and the size of each label."""
    h, w = mask.shape
    flat = mask.ravel().tolist()
    lab = [0] * (h * w)
    sizes = [0]
    for start, on in enumerate(flat):
        if not on or lab[start]:
            continue
        n = len(sizes)
        lab[start] = n
        q, size = deque([start]), 0
        while q:
            p = q.popleft()
            size += 1
            y, x = divmod(p, w)
            for nb in ((p - w) if y else -1, (p + w) if y < h - 1 else -1, (p - 1) if x else -1, (p + 1) if x < w - 1 else -1):
                if nb >= 0 and flat[nb] and not lab[nb]:
                    lab[nb] = n
                    q.append(nb)
        sizes.append(size)
    return np.array(lab, np.int32).reshape(h, w), sizes


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("--ref", required=True)
    p.add_argument("--out", required=True, help="PNG with the subject opaque")
    p.add_argument("--tol", type=float, default=40, help="RGB distance (0-441) from the corner colour that counts as subject")
    p.add_argument("--open", type=int, default=3, help="px: removes lines and specks thinner than ~2x this")
    p.add_argument("--close", type=int, default=4, help="px: bridges gaps narrower than ~2x this")
    p.add_argument("--min-blob", type=float, default=0.05, help="keep blobs at least this fraction of the largest")
    a = p.parse_args(argv)

    img = load(a.ref)
    h, w = img.shape[:2]
    if img[..., 3].min() < 0.98:
        m = img[..., 3] > 0.5
    else:
        rgb = img[..., :3]
        corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
                                  rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
        m = np.sqrt(((rgb - np.median(corners, 0)) ** 2).sum(-1)) * 255 > a.tol
    m = morph(morph(m, a.open, False), a.open, True)     # opening: thin lines go
    m = morph(morph(m, a.close, True), a.close, False)   # closing: outline gaps close

    lab, sizes = components(~m)                          # background blobs not touching the border are holes
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
    m |= (lab > 0) & ~np.isin(lab, list(border))
    lab, sizes = components(m)
    if len(sizes) < 2:
        print("MATTE FAILED: nothing differs from the corner colour; lower --tol or crop the picture")
        sys.exit(1)
    biggest = max(sizes[1:])
    keep = [i for i, s in enumerate(sizes) if i and s >= a.min_blob * biggest]
    m = np.isin(lab, keep)

    out = img.copy()
    out[..., 3] = m.astype(np.float32)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    save(a.out, out)
    ys, xs = np.nonzero(m)
    print("matte", a.out)
    print("subject %.1f%% of the image, %d blob(s) kept of %d, bbox x %d-%d y %d-%d of %dx%d"
          % (100.0 * m.mean(), len(keep), len(sizes) - 1, xs.min(), xs.max(), ys.min(), ys.max(), w, h))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
