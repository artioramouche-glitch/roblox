
# DETAIL KIT
# Ready-made, low-poly detail parts for hard-surface props (chests, doors, crates, carts, weapons).
# Added for Roblox Ultimate MCP, not part of the original skill: blender_image_to_3d { action: "build" }
# appends it to the build template, so it uses the template's helpers (box, cylinder, profile_spin,
# bevel, new_mesh_object, join_meshes, assign). Metres. `face` is where a part looks:
# "-Y" front, "+Y" back, "+X" / "-X" sides, "+Z" top. On a face, u runs to the right and v up.

FRAMES = {   # u (right), v (up), n (out) of each face
    "-Y": ((1, 0, 0), (0, 0, 1), (0, -1, 0)),
    "+Y": ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    "+X": ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    "-X": ((0, -1, 0), (0, 0, 1), (-1, 0, 0)),
    "+Z": ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    "-Z": ((1, 0, 0), (0, -1, 0), (0, 0, -1)),
}


def face_matrix(location, face):
    """World matrix of a face frame at location: local x = u, y = v, z = n."""
    u, v, n = FRAMES[face]
    return Matrix.Translation(Vector(location)) @ Matrix((u, v, n)).transposed().to_4x4()


def face_point(location, face, du=0.0, dv=0.0, dn=0.0):
    """A point du to the right, dv up and dn out of location, on a face."""
    u, v, n = (Vector(a) for a in FRAMES[face])
    return tuple(Vector(location) + u * du + v * dv + n * dn)


def _chamfer(ob, width):
    if width:
        bevel(ob, width=width, segments=1, angle_limit=30, harden=False)
    return ob


def hex_bolt(location, face="-Y", size=(0.02, 0.016), collection="LOW", name="bolt"):
    """Hex bolt head (size = radius, height) sitting on a face (location = on the surface), chamfered top, open underneath: 30 triangles."""
    radius, height = size
    ob = profile_spin(name, [(radius, 0), (radius, height * 0.55), (radius * 0.68, height), (0, height)],
                      collection=collection, steps=6)
    ob.matrix_world = face_matrix(location, face)
    return ob


def bolt_grid(location, face, cols, rows, spacing_u, spacing_v, size=(0.02, 0.016), collection="LOW"):
    """cols x rows bolts centred on location."""
    return [hex_bolt(face_point(location, face, (i - (cols - 1) / 2) * spacing_u, (j - (rows - 1) / 2) * spacing_v), face, size, collection)
            for i in range(cols) for j in range(rows)]


def bolt_row(a, b, count, face, size=(0.02, 0.016), collection="LOW"):
    """count bolts evenly from point a to point b."""
    a, b = Vector(a), Vector(b)
    return [hex_bolt(tuple(a + (b - a) * (k / max(1, count - 1))), face, size, collection) for k in range(count)]


def metal_plate(location, size_u, size_v, thickness=0.012, face="-Y", chamfer=0.006, bolts=(0, 0), bolt_inset=0.03,
                collection="LOW", name="plate", bolt_size=(0.02, 0.016)):
    """Plate on a face (location = its centre on the surface) with an optional cols x rows bolt grid. Returns [plate, bolts...]."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(size_u, size_v, thickness), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, thickness / 2), verts=bm.verts)
    ob = new_mesh_object(name, bm, collection)
    ob.matrix_world = face_matrix(location, face)
    out = [_chamfer(ob, chamfer)]
    if bolts[0] and bolts[1]:
        su = (size_u - 2 * bolt_inset) / max(1, bolts[0] - 1)
        sv = (size_v - 2 * bolt_inset) / max(1, bolts[1] - 1)
        out += bolt_grid(face_point(location, face, dn=thickness), face, bolts[0], bolts[1], su, sv, bolt_size, collection)
    return out


def corner_cap(x, y, z0, size=0.14, height=0.14, chamfer=0.008, bolts=(2, 2), side_bolts=(1, 2), collection="LOW",
               name="corner", bolt_size=(0.02, 0.016)):
    """Metal cap wrapping a vertical corner whose outer edge is at (x, y), from z0 up: feet, corner plates.
    bolts go on the front or back face, side_bolts on the side face. Returns [cap, bolts...]."""
    sx, sy = (1 if x > 0 else -1), (1 if y > 0 else -1)
    out = [_chamfer(box(name, (size, size, height), collection=collection, location=(x - sx * size / 2, y - sy * size / 2, z0),
                        base_at_origin=True), chamfer)]
    inset = size * 0.28
    if bolts[0] and bolts[1]:
        out += bolt_grid((x - sx * size / 2, y, z0 + height / 2), "+Y" if sy > 0 else "-Y", bolts[0], bolts[1],
                         size - 2 * inset, height - 2 * inset, bolt_size, collection)
    if side_bolts[0] and side_bolts[1]:
        out += bolt_grid((x, y - sy * size / 2, z0 + height / 2), "+X" if sx > 0 else "-X", side_bolts[0], side_bolts[1],
                         size - 2 * inset, height - 2 * inset, bolt_size, collection)
    return out


def plank_stack(name, size, count, location=(0, 0, 0), gap=0.008, chamfer=0.008, collection="LOW"):
    """count boards stacked along Z filling size (x, y, z) from location up, with real gaps over a recessed core."""
    w, d, h = size
    ph = (h - gap * (count - 1)) / count
    out = [_chamfer(box(name, (w, d, ph), collection=collection, location=(location[0], location[1], location[2] + i * (ph + gap)),
                        base_at_origin=True), chamfer) for i in range(count)]
    out.append(box(name + "_core", (w - 0.02, d - 0.02, h), collection=collection, location=location, base_at_origin=True))
    return out


def arch_points(half_depth, height, base_z=0.0, n=3.0, segments=10):
    """Superellipse arch in (y, z) from the back (y = +half_depth) over the top to the front. n = 2 is round, 3+ squarer."""
    pts = []
    for k in range(segments + 1):
        t = math.pi * k / segments
        c, s = math.cos(t), math.sin(t)
        pts.append((half_depth * math.copysign(abs(c) ** (2 / n), c), base_z + height * abs(s) ** (2 / n)))
    return pts


def prism(name, profile_yz, x0, x1, collection="LOW"):
    """Closed (y, z) outline extruded along X from x0 to x1: lids, beams, rails, mouldings."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile_yz]
    b = [bm.verts.new((x1, y, z)) for y, z in profile_yz]
    for i in range(len(a)):
        j = (i + 1) % len(a)
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_mesh_object(name, bm, collection)


def strap(name, path_yz, thickness, x, width, collection="LOW"):
    """Metal strap of constant thickness laid over an open (y, z) path (its inner surface, in the order of
    arch_points), width along X centred on x: chest bands, barrel hoops, door straps."""
    pts = [Vector(p) for p in path_yz]
    outer = []
    for k, p in enumerate(pts):
        t = pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]
        nrm = Vector((t.y, -t.x)).normalized()  # outward for a path from the back over the top to the front
        outer.append(p + nrm * thickness)
    bm = bmesh.new()
    x0, x1 = x - width / 2, x + width / 2
    O0, O1 = [bm.verts.new((x0, p.x, p.y)) for p in outer], [bm.verts.new((x1, p.x, p.y)) for p in outer]
    I0, I1 = [bm.verts.new((x0, p.x, p.y)) for p in pts], [bm.verts.new((x1, p.x, p.y)) for p in pts]
    for k in range(len(pts) - 1):
        bm.faces.new((O0[k], O0[k + 1], O1[k + 1], O1[k]))
        bm.faces.new((I0[k], I1[k], I1[k + 1], I0[k + 1]))
        bm.faces.new((O0[k], I0[k], I0[k + 1], O0[k + 1]))
        bm.faces.new((O1[k], O1[k + 1], I1[k + 1], I1[k]))
    for k in (0, len(pts) - 1):
        bm.faces.new((O0[k], O1[k], I1[k], I0[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_mesh_object(name, bm, collection)


def tube(name, points, radius, segments=6, closed=False, collection="LOW"):
    """Low-poly tube through 3D points: shackles, handles, rings, pipes. closed=True makes a loop."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    bm = bmesh.new()
    rings, ref = [], None
    for k, p in enumerate(pts):
        t = (pts[(k + 1) % n] - pts[k - 1]) if closed else (pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)])
        t.normalize()
        if ref is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        nrm = (ref - t * ref.dot(t)).normalized()  # carry the previous normal along: no twist
        ref, bnm = nrm, t.cross(nrm)
        rings.append([bm.verts.new(p + (nrm * math.cos(a) + bnm * math.sin(a)) * radius)
                      for a in (2 * math.pi * s / segments for s in range(segments))])
    for k in range(n if closed else n - 1):
        r0, r1 = rings[k], rings[(k + 1) % n]
        for s in range(segments):
            bm.faces.new((r0[s], r0[(s + 1) % segments], r1[(s + 1) % segments], r1[s]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_mesh_object(name, bm, collection)


def _in_frame(ob, M, offset=(0, 0, 0)):
    ob.data.transform(Matrix.Translation(offset))
    ob.location = (0, 0, 0)
    ob.matrix_world = M
    return ob


def padlock(location, face="-Y", width=0.2, height=0.22, depth=0.07, collection="LOW", name="lock"):
    """Padlock on a face (location = bottom centre of the body, on the surface): chamfered body, round shackle
    rising above it, keyhole. Returns {"body": [...], "keyhole": [...]}: give the keyhole a dark material."""
    M = face_matrix(location, face)
    body = _chamfer(_in_frame(box(name, (width, height, depth), collection=collection), M, (0, height / 2, depth / 2)),
                    min(width, height) * 0.16)
    sw, lift, z = width * 0.3, height * 0.28, depth / 2
    pts = [(-sw, height * 0.85, z), (-sw, height + lift, z)]
    pts += [(-sw * math.cos(a), height + lift + sw * math.sin(a), z) for a in (math.pi * k / 6 for k in range(1, 6))]
    pts += [(sw, height + lift, z), (sw, height * 0.85, z)]
    shackle = tube(name + "_shackle", pts, width * 0.07, collection=collection)
    shackle.matrix_world = M
    kr = width * 0.11
    hole = _in_frame(cylinder(name + "_key", kr, 0.008, collection=collection, segments=8), M, (0, height * 0.58, depth))
    slot = _in_frame(box(name + "_slot", (kr * 0.8, kr * 2.4, 0.008), collection=collection), M, (0, height * 0.58 - kr * 1.4, depth))
    return {"body": [body, shackle], "keyhole": [hole, slot]}


def ring_handle(location, face="+X", width=0.14, height=0.12, thickness=0.022, bolts=2, collection="LOW", name="handle",
                bolt_size=(0.02, 0.016)):
    """Side handle: a mount plate with `bolts` bolts and a ring hanging under it (location = mount centre on the surface)."""
    parts = metal_plate(location, width * 0.9, height * 0.45, 0.014, face, chamfer=0.004, bolts=(bolts, 1) if bolts else (0, 0),
                        bolt_inset=width * 0.15, collection=collection, name=name, bolt_size=bolt_size)
    r = thickness / 2
    w, h, c, z = width / 2 - r, height, height * 0.25, 0.014 + r * 1.5
    loop = [(-w, 0, z), (-w, -h + c, z), (-w + c, -h, z), (w - c, -h, z), (w, -h + c, z), (w, 0, z)]
    ring = tube(name + "_ring", loop, r, closed=True, collection=collection)
    ring.matrix_world = face_matrix(location, face)
    return parts + [ring]


def merge(name, objects, material=None, collection="LOW"):
    """Join parts into one mesh (one Roblox MeshPart), give it one material, delete the parts."""
    ob = join_meshes(name, objects, collection=collection)
    for o in objects:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)
    if material is not None:
        assign(ob, material)
    return ob


def tri_count(objects):
    """Triangles after modifiers, to check the budget in the build log."""
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in objects:
        if o.type == 'MESH':
            eo = o.evaluated_get(dg)
            total += sum(len(p.vertices) - 2 for p in eo.to_mesh().polygons)
            eo.to_mesh_clear()
    return total

