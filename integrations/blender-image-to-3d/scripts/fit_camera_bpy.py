"""
FIT CAMERA
Finds the --ref-cam AZ EL LENS of a perspective reference (concept art, photo, screenshot): renders
the model's silhouette from a grid of cameras, then around the best one, and keeps the camera with
the best IoU against the reference matte (make_matte_bpy.py first). It fits the camera to the model,
so run it once the blockout is roughly right; a low best IoU means the model is off, not the camera.
Added for Roblox Ultimate MCP; not part of the original skill.

blender --background --python scripts/fit_camera_bpy.py -- --blend X_master.blend \
  --matte ref/concept_matte.png --out review/camera [--az -90 90] [--el 0 45] [--lens 24,35,50,85]

A symmetric model looks the same from az and -az: check which side the reference shows. Writes
<out>/fit_camera.json (best and top 5) and <out>/fit_best.png.
"""
import bpy, sys, os, json, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import review_render as rr          # scope, visibility, camera fitting and Workbench setup of the gates
import compose_review_bpy as cr     # masks, profile and IoU of compose_review


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("--blend", required=True)
    p.add_argument("--matte", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--collections", default="LOW")
    p.add_argument("--az", type=float, nargs=2, default=[-90, 90])
    p.add_argument("--el", type=float, nargs=2, default=[0, 45])
    p.add_argument("--lens", default="24,35,50,85")
    p.add_argument("--px", type=int, default=200, help="render height of each try")
    a = p.parse_args(argv)

    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(a.blend))
    scene = bpy.context.scene
    os.makedirs(a.out, exist_ok=True)
    opts = argparse.Namespace(collections=a.collections, only="", show_ref=False, mode="silhouette", samples=8)
    scope = rr.scope_objects(opts)
    rr.apply_visibility(scene, scope)
    corners, lo, hi = rr.world_corners(scope)
    center, extent = (lo + hi) / 2, max(hi - lo)
    rr.setup_engine(scene, opts, "workbench", scope, center, extent)
    cam = bpy.data.objects.new("_fit_cam", bpy.data.cameras.new("_fit_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    matte = cr.load(a.matte)
    ref = cr.profile(cr.ref_mask(matte))
    if not ref:
        raise RuntimeError("empty matte: " + a.matte)
    H = a.px
    W = max(1, round(H * matte.shape[1] / matte.shape[0]))
    scene.render.resolution_x, scene.render.resolution_y = W, H
    tmp = os.path.join(a.out, "_fit_try.png")
    tried = {}

    def score(az, el, lens):
        key = (round(az, 2), round(el, 2), lens)
        if key not in tried:
            rr.fit_camera(cam, corners, center, rr.view_direction(az, el), W, H, lens, 1.1)
            rr.render_to(scene, tmp)
            m = cr.profile(cr.render_mask(cr.load(tmp)))
            tried[key] = cr.iou(ref["_img"], m["_img"]) if m else 0.0
        return tried[key]

    def span(lo_, hi_, step):
        n = max(1, int(round((hi_ - lo_) / step)))
        return [lo_ + i * (hi_ - lo_) / n for i in range(n + 1)]

    lenses = [float(x) for x in a.lens.split(",") if x]
    for lens in lenses:                                  # coarse: 15 degree steps
        for az in span(a.az[0], a.az[1], 15):
            for el in span(a.el[0], a.el[1], 15):
                score(az, el, lens)
    def refine(az0, el0, lens0):
        for step in (5, 2):
            for daz in (-2 * step, -step, 0, step, 2 * step):
                for de in (-2 * step, -step, 0, step, 2 * step):
                    score(az0 + daz, min(89, max(-89, el0 + de)), lens0)
            near = {k: v for k, v in tried.items() if k[2] == lens0 and abs(k[0] - az0) <= 2 * step and abs(k[1] - el0) <= 2 * step}
            az0, el0, _ = max(near, key=near.get)

    # then finer around the 3 best coarse cameras: the best coarse one can sit in the wrong valley
    for cand in sorted(tried, key=tried.get, reverse=True)[:3]:
        refine(*cand)
    ranked = sorted(tried.items(), key=lambda kv: -kv[1])
    (az, el, lens), best = ranked[0]
    rr.fit_camera(cam, corners, center, rr.view_direction(az, el), W, H, lens, 1.1)
    rr.render_to(scene, os.path.join(a.out, "fit_best.png"))
    os.remove(tmp)
    res = {"best": {"az": az, "el": el, "lens": lens, "iou": best},
           "ref_cam": [round(az, 1), round(el, 1), lens],
           "top": [{"az": k[0], "el": k[1], "lens": k[2], "iou": v} for k, v in ranked[:5]],
           "tries": len(tried)}
    with open(os.path.join(a.out, "fit_camera.json"), "w") as f:
        json.dump(res, f, indent=2)
    print("best --ref-cam %.1f %.1f %g  IoU %.3f  (%d tries)" % (az, el, lens, best, len(tried)))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
