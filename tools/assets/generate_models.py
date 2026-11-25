"""Memoria Phase 00 - reproducible procedural 3D asset generator.

Run headless with Blender 4.2+ (verified with Blender 4.3.2):

    blender -b --factory-startup -P tools/assets/generate_models.py -- assets/models

Every asset is generated from code with fixed seeds, so running the script twice
produces the same geometry. No third-party meshes or textures are used; the only
image inputs are the procedural PNGs written by generate_textures.py.

Exported files (glTF 2.0 binary, PBR metallic-roughness, vertex colours as COLOR_0):
  planet_bloom.glb          hero memory planet (tree, waterfall, vegetation, rocks,
                            clouds, glass atmosphere, orbital ring, particles)
  planet_bloom_evolved.glb  evolved variation of the hero planet
  planet_tide.glb           ocean archipelago world + moon
  planet_dune.glb           warm dune world + dust ring + stone arches
  planet_frost.glb          pale crystal world + mint ring
  planet_grove.glb          dense forest world + lake + fireflies
  planet_ember.glb          twilight world with lantern glows
  capsule_sealed.glb        sealed memory capsule (core, glass shell, lattice, seal)
  galaxy_2024.glb / galaxy_2025.glb / galaxy_2026.glb   particle galaxies
  starfield.glb             distant star shell
  nebula_veils.glb          layered translucent nebula sprites (hybrid background)
  orbit_ring.glb            unit orbital path ring (instanced per planet orbit)

Named child nodes (Clouds, Ring, Particles, Shell, Lattice, Stars, ...) are animated
independently at runtime by the Flutter scene controller.
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix, noise

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "assets/models")
ONLY = set(argv[1:])
HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "textures")
os.makedirs(OUT, exist_ok=True)


# ----------------------------------------------------------------------------
# Utilities
# ----------------------------------------------------------------------------

def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return (srgb_to_lin(int(h[0:2], 16) / 255), srgb_to_lin(int(h[2:4], 16) / 255),
            srgb_to_lin(int(h[4:6], 16) / 255), a)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(4))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=5, lac=2.0, gain=0.5):
    s, a, f, n = 0.0, 0.5, 1.0, 0.0
    for i in range(octaves):
        s += a * noise.noise(p * f + Vector((i * 7.13, i * 3.71, i * 1.37)), noise_basis="PERLIN_ORIGINAL")
        n += a
        a *= gain
        f *= lac
    return s / n


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color=(1, 1, 1, 1), rough=0.85, metal=0.0, vcol=True, emission=None,
             strength=0.0, alpha=None, unlit=False, cull=True, image=None, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = cull
    nt = m.node_tree
    out = nt.nodes["Material Output"]
    if unlit:
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        bg = nt.nodes.new("ShaderNodeBackground")
        bg.inputs["Color"].default_value = color
        if vcol:
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Col"
            nt.links.new(vc.outputs["Color"], bg.inputs["Color"])
        nt.links.new(bg.outputs[0], out.inputs["Surface"])
        return m
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = spec
    if vcol:
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
        nt.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Strength"].default_value = strength
    elif emission is not None:
        b.inputs["Emission Color"].default_value = emission
        b.inputs["Emission Strength"].default_value = strength
    if alpha is not None and image is None:
        b.inputs["Alpha"].default_value = alpha
    return m


def obj_from_bm(name, bm, mat, parent=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if mat is not None:
        if isinstance(mat, (list, tuple)):
            for mm in mat:
                me.materials.append(mm)
        else:
            me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if parent is not None:
        o.parent = parent
    return o


def empty(name, parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    if parent is not None:
        o.parent = parent
    return o


def paint(bm, fn):
    """Write per-corner linear colours. fn(vert) -> rgba."""
    layer = bm.loops.layers.float_color.new("Col")
    bm.verts.index_update()
    cache = {}
    for f in bm.faces:
        for l in f.loops:
            v = l.vert
            c = cache.get(v.index)
            if c is None:
                c = fn(v)
                cache[v.index] = c
            l[layer] = c
    return layer


def paint_faces(bm, fn):
    layer = bm.loops.layers.float_color.new("Col")
    for f in bm.faces:
        c = fn(f)
        for l in f.loops:
            l[layer] = c


def add_ico(bm, center, radius, subdiv=1, scale=(1, 1, 1), color=None, jitter=0.0, rnd=None, rot=None):
    """Append an icosphere into an existing bmesh; returns new verts."""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
    if jitter and rnd is not None:
        for v in tmp.verts:
            v.co *= 1.0 + rnd.uniform(-jitter, jitter)
    for v in tmp.verts:
        co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
        if rot is not None:
            co = rot @ co
        v.co = co + center
    return merge(bm, tmp, color)


def merge(bm, tmp, color=None):
    """Merge bmesh tmp into bm, carrying an optional flat colour in a temp map."""
    vmap = {}
    for v in tmp.verts:
        nv = bm.verts.new(v.co)
        vmap[v] = nv
        if color is not None:
            COLOR_HINT[nv] = color
    for f in tmp.faces:
        try:
            bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            pass
    tmp.free()
    return list(vmap.values())


COLOR_HINT = {}


def paint_hints(bm, default=(1, 1, 1, 1)):
    layer = bm.loops.layers.float_color.new("Col")
    for f in bm.faces:
        for l in f.loops:
            l[layer] = COLOR_HINT.get(l.vert, default)
    COLOR_HINT.clear()


def add_tube(bm, a, b, ra, rb, segs=7, color=None, caps=True):
    """Tapered cylinder from point a to b."""
    d = b - a
    length = d.length
    if length < 1e-6:
        return
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=segs,
                          radius1=ra, radius2=rb, depth=length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    m = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
    merge(bm, tmp, color)


def tangent_frame(n):
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    t = n.cross(up).normalized()
    b = n.cross(t).normalized()
    return t, b


def rand_dir(rnd):
    z = rnd.uniform(-1, 1)
    a = rnd.uniform(0, 2 * math.pi)
    r = math.sqrt(1 - z * z)
    return Vector((r * math.cos(a), r * math.sin(a), z))


def load_image(name):
    path = os.path.join(TEX, name)
    img = bpy.data.images.load(path)
    img.pack()
    return img


def export(name):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_materials="EXPORT",
        export_vertex_color="MATERIAL",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_image_format="AUTO",
    )
    tris = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
    print(f"ASSET {name}.glb tris={tris} bytes={os.path.getsize(path)}")
    STATS[name] = tris


STATS = {}


# ----------------------------------------------------------------------------
# Planet framework
# ----------------------------------------------------------------------------

class Planet:
    """Terrain height field on a sphere plus helpers to place props on it."""

    def __init__(self, seed, height_fn):
        self.seed = seed
        self.rnd = random.Random(seed)
        r = random.Random(seed * 31 + 7)
        self.off = Vector((r.uniform(-50, 50), r.uniform(-50, 50), r.uniform(-50, 50)))
        self.height_fn = height_fn

    def h(self, d):
        return self.height_fn(self, d)

    def surface(self, d):
        d = d.normalized()
        return d * (1.0 + self.h(d))

    def terrain(self, name, subdiv, color_fn, parent, rough=0.9):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        bm.verts.index_update()
        heights = {}
        for v in bm.verts:
            d = v.co.normalized()
            hh = self.h(d)
            heights[v.index] = hh
            v.co = d * (1.0 + hh)
        bm.normal_update()

        def fn(v):
            d = v.co.normalized()
            slope = 1.0 - max(0.0, v.normal.dot(d))
            return color_fn(self, d, heights[v.index], slope)

        paint(bm, fn)
        return obj_from_bm(name, bm, material(name + "Mat", rough=rough), parent)


def ocean(name, parent, color, radius=1.0, alpha=0.82, subdiv=4):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    m = material(name + "Mat", color=color, rough=0.12, vcol=False, alpha=alpha,
                 emission=(color[0] * 0.6, color[1] * 0.6, color[2] * 0.6, 1), strength=0.15, spec=0.8)
    return obj_from_bm(name, bm, m, parent)


def glass_shell(name, parent, radius, tint, alpha, strength=0.08, subdiv=4):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    m = material(name + "Mat", color=tint, rough=0.04, vcol=False, alpha=alpha,
                 emission=tint, strength=strength, spec=1.0)
    return obj_from_bm(name, bm, m, parent)


def ring(name, parent, major, minor, tilt_x, tilt_y, color, strength, sparkles=0, rnd=None,
         segs=160, spark_color=None):
    bm = bmesh.new()
    tmp = bmesh.new()
    bmesh.ops.create_circle(tmp, cap_ends=False, segments=segs, radius=major)
    # sweep a small circle along the ring -> torus
    tmp.free()
    for i in range(segs):
        a0 = 2 * math.pi * i / segs
        a1 = 2 * math.pi * (i + 1) / segs
        p0 = Vector((math.cos(a0) * major, math.sin(a0) * major, 0))
        p1 = Vector((math.cos(a1) * major, math.sin(a1) * major, 0))
        add_tube(bm, p0, p1, minor, minor, segs=5, caps=False)
    if sparkles and rnd is not None:
        for i in range(sparkles):
            a = rnd.uniform(0, 2 * math.pi)
            rr = major + rnd.gauss(0, major * 0.03)
            p = Vector((math.cos(a) * rr, math.sin(a) * rr, rnd.gauss(0, 0.01)))
            add_ico(bm, p, rnd.uniform(0.006, 0.016), subdiv=0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    rot = Matrix.Rotation(math.radians(tilt_x), 4, "X") @ Matrix.Rotation(math.radians(tilt_y), 4, "Y")
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    m = material(name + "Mat", color=color, vcol=False, emission=color, strength=strength, rough=0.4)
    return obj_from_bm(name, bm, m, parent)


def particles(name, parent, count, rmin, rmax, colors, size, rnd, strength=2.0, flatten=1.0):
    bm = bmesh.new()
    for i in range(count):
        d = rand_dir(rnd)
        d.z *= flatten
        p = d.normalized() * rnd.uniform(rmin, rmax)
        add_ico(bm, p, rnd.uniform(size[0], size[1]), subdiv=0, color=rnd.choice(colors))
    paint_hints(bm)
    m = material(name + "Mat", vcol=True, unlit=True)
    return obj_from_bm(name, bm, m, parent, smooth=False)


def cloud_puffs(name, parent, planet_r, count, rnd, color, band=(-0.6, 0.35), size=(0.06, 0.12),
                height=(0.14, 0.24), alpha=None, strength=0.3, lobes=(7, 13)):
    bm = bmesh.new()
    for i in range(count):
        z = rnd.uniform(*band)
        a = rnd.uniform(0, 2 * math.pi)
        rr = math.sqrt(1 - z * z)
        d = Vector((rr * math.cos(a), rr * math.sin(a), z))
        center = d * (planet_r + rnd.uniform(*height))
        t, b = tangent_frame(d)
        for k in range(rnd.randint(*lobes)):
            off = t * rnd.gauss(0, 0.09) + b * rnd.gauss(0, 0.05) + d * rnd.gauss(0, 0.015)
            s = rnd.uniform(*size)
            rot = Matrix((t, b, d)).transposed()
            add_ico(bm, center + off, s, subdiv=2, scale=(1.0, 0.85, 0.62), jitter=0.06, rnd=rnd, rot=rot)
    bm.normal_update()

    def shade(v):
        # bottom of puffs slightly cooler/darker, tops warm ivory: fake scattering
        up = v.normal.dot(v.co.normalized())
        return mix(hexc("#B9C9C6"), color, 0.55 + 0.45 * up)

    paint(bm, shade)
    m = material(name + "Mat", rough=1.0, vcol=True, emission=hexc("#F2E2D2"), strength=strength,
                 alpha=alpha, spec=0.1)
    return obj_from_bm(name, bm, m, parent)


def scatter_on(planet, count, rnd, accept, place):
    placed = 0
    tries = 0
    while placed < count and tries < count * 60:
        tries += 1
        d = rand_dir(rnd)
        hh = planet.h(d)
        if accept(d, hh):
            place(d, hh)
            placed += 1


# ----------------------------------------------------------------------------
# Tree (recursive branching + blossom canopy)
# ----------------------------------------------------------------------------

def build_tree(bm_wood, bm_leaf, base, up, height, rnd, depth=4, blossom_colors=None,
               canopy=1.0, leaf_size=(0.022, 0.05)):
    trunk_col = hexc("#4A3A30")
    tips = []

    def branch(p, direction, length, radius, level):
        segs = 3
        cur = p
        dirn = direction.normalized()
        for s in range(segs):
            bend = Vector((rnd.gauss(0, 0.18), rnd.gauss(0, 0.18), rnd.gauss(0, 0.18)))
            dirn = (dirn + bend * 0.5 + up * (0.12 if level == 0 else 0.02)).normalized()
            nxt = cur + dirn * (length / segs)
            r0 = radius * (1 - 0.22 * s / segs)
            r1 = radius * (1 - 0.22 * (s + 1) / segs)
            add_tube(bm_wood, cur, nxt, r0, r1, segs=7 if level < 2 else 5,
                     color=mix(trunk_col, hexc("#6B5444"), level / depth))
            cur = nxt
        if level >= depth:
            tips.append(cur)
            return
        n_child = 2 if level == 0 else rnd.choice((2, 3, 3))
        t, b = tangent_frame(dirn)
        for c in range(n_child):
            ang = rnd.uniform(0, 2 * math.pi) + c * 2 * math.pi / n_child
            spread = rnd.uniform(0.75, 1.15) if level < 2 else rnd.uniform(0.45, 0.85)
            nd = (dirn * math.cos(spread) + (t * math.cos(ang) + b * math.sin(ang)) * math.sin(spread))
            nd = (nd + up * 0.12).normalized()
            branch(cur, nd, length * rnd.uniform(0.7, 0.85), radius * 0.6, level + 1)
            if level >= 2:
                tips.append(cur)

    lean = (up + Vector((rnd.gauss(0, 0.15), rnd.gauss(0, 0.15), 0))).normalized()
    branch(base - up * 0.02, lean, height * 0.36, height * 0.085, 0)
    # blossom canopy: soft clusters around tips
    for tip in tips:
        n = int(rnd.randint(8, 12) * canopy)
        for i in range(n):
            off = Vector((rnd.gauss(0, 0.07), rnd.gauss(0, 0.07), rnd.gauss(0, 0.045))) * (height / 0.45)
            col = rnd.choice(blossom_colors)
            col = mix(col, hexc("#FBE3E6"), rnd.uniform(0, 0.15))
            add_ico(bm_leaf, tip + off + up * 0.015, rnd.uniform(*leaf_size) * (height / 0.45), subdiv=1,
                    color=col, jitter=0.12, rnd=rnd, scale=(1, 1, 0.7))
    return tips


def bushes(planet, bm, count, rnd, accept, palette, size=(0.018, 0.035), conifer=0.35):
    def place(d, hh):
        p = planet.surface(d)
        s = rnd.uniform(*size)
        col = rnd.choice(palette)
        if rnd.random() < conifer:
            tmp = bmesh.new()
            bmesh.ops.create_cone(tmp, cap_ends=True, segments=6, radius1=s * 0.8, radius2=0.0, depth=s * 3.0)
            q = Vector((0, 0, 1)).rotation_difference(d)
            bmesh.ops.transform(tmp, matrix=Matrix.Translation(p + d * s * 1.3) @ q.to_matrix().to_4x4(), verts=tmp.verts)
            merge(bm, tmp, col)
        else:
            add_ico(bm, p + d * s * 0.6, s, subdiv=1, scale=(1, 1, 0.85), color=col, jitter=0.12, rnd=rnd,
                    rot=Vector((0, 0, 1)).rotation_difference(d).to_matrix())
    scatter_on(planet, count, rnd, accept, place)


def rocks(planet, bm, count, rnd, accept, palette, size=(0.012, 0.04)):
    def place(d, hh):
        p = planet.surface(d)
        s = rnd.uniform(*size)
        add_ico(bm, p, s, subdiv=1, scale=(1.0, 0.8, 0.6), color=rnd.choice(palette), jitter=0.3, rnd=rnd,
                rot=Vector((0, 0, 1)).rotation_difference(d).to_matrix())
    scatter_on(planet, count, rnd, accept, place)


# ----------------------------------------------------------------------------
# Hero planet: "bloom"
# ----------------------------------------------------------------------------

TOP = Vector((0.12, -0.32, 1.0)).normalized()  # plateau axis (Blender Z-up)


def bloom_height(pl, d):
    base = fbm(d * 2.1 + pl.off, 5) * 0.11 + fbm(d * 7.0 + pl.off * 1.3, 3) * 0.025
    base = max(base, -0.035)
    c = d.dot(TOP)
    plateau = 0.13 * smoothstep(0.78, 0.83, c) + 0.02 * smoothstep(0.83, 1.0, c) * fbm(d * 9 + pl.off, 2)
    if c > 0.72:
        base = max(base, 0.012) * (1 - smoothstep(0.72, 0.8, c)) + 0.012 * smoothstep(0.72, 0.8, c)
    return base + plateau


def bloom_colors(pl, d, hh, slope, evolved=False):
    n = fbm(d * 11 + pl.off, 3)
    c = d.dot(TOP)
    if hh < -0.004:
        return mix(hexc("#2F5F5B"), hexc("#5E8F86"), smoothstep(-0.035, -0.004, hh))
    if hh < 0.008 and c < 0.78:
        return mix(hexc("#D8C9A4"), hexc("#B9B38A"), n * 0.5 + 0.5)
    grass = mix(hexc("#7FA352"), hexc("#A8BE6A"), n * 0.5 + 0.5)
    grass = mix(grass, hexc("#55804A"), smoothstep(0.1, 0.5, fbm(d * 23 + pl.off, 2)))
    if slope > 0.18 or (0.775 < c < 0.835):
        strata = 0.5 + 0.5 * math.sin(hh * 140 + n * 3)
        rock = mix(hexc("#7C6F62"), hexc("#A69684"), strata)
        moss = mix(rock, hexc("#5D7F48"), smoothstep(0.3, 0.7, fbm(d * 17 + pl.off, 2)) * 0.6)
        return moss
    if c > 0.83:
        top = mix(grass, hexc("#93B45C"), 0.4)
        petals = smoothstep(0.92, 0.97, c) * (0.55 if evolved else 0.25)
        top = mix(top, hexc("#EDB9C4"), petals * (0.5 + 0.5 * n))
        return top
    return grass


def build_bloom(evolved=False):
    reset()
    root = empty("PlanetBloomEvolved" if evolved else "PlanetBloom")
    pl = Planet(1, bloom_height)
    rnd = random.Random(101)
    body = empty("Body", root)
    pl.terrain("Terrain", 5, lambda p, d, h, s: bloom_colors(p, d, h, s, evolved), body)
    ocean("Water", body, hexc("#5FA39E"), radius=1.0, alpha=0.78)

    # waterfall: river across the plateau to its rim, then a cascading ribbon down the cliff
    t, b = tangent_frame(TOP)
    toward_cam = Vector((0.25, -1.0, 0.0))  # Blender -Y == glTF +Z (default camera side)
    fall_dir = (toward_cam - TOP * toward_cam.dot(TOP)).normalized()
    bm = bmesh.new()

    def ribbon(start_ang, width0, width1, steps=26):
        pts = []
        for i in range(steps + 1):
            u = i / steps
            ang = start_ang + u * 0.62  # radians away from TOP
            d = (TOP * math.cos(ang) + fall_dir * math.sin(ang)).normalized()
            r = 1.0 + pl.h(d) + 0.006
            if u > 0.18:
                # free-falling sheet: keep slightly off the cliff
                r = max(r, 1.0 + 0.004) + 0.012 * smoothstep(0.18, 0.4, u)
            pts.append((d * r, d))
        verts = []
        for i, (p, d) in enumerate(pts):
            u = i / steps
            side = d.cross(fall_dir).normalized()
            w = width0 + (width1 - width0) * u
            verts.append((p - side * w, p + side * w, u))
        layer_rows = []
        for (a, c, u) in verts:
            layer_rows.append((bm.verts.new(a), bm.verts.new(c), u))
        for i in range(len(layer_rows) - 1):
            a0, c0, u0 = layer_rows[i]
            a1, c1, u1 = layer_rows[i + 1]
            f = bm.faces.new((a0, c0, c1, a1))
            for v, u in ((a0, u0), (c0, u0), (c1, u1), (a1, u1)):
                COLOR_HINT[v] = mix(hexc("#A8D4D0"), hexc("#F4FBF8"), smoothstep(0.1, 0.35, u))

    ribbon(0.45, 0.018, 0.05)
    ribbon(0.47, 0.008, 0.028)
    paint_hints(bm)
    wf = material("WaterfallMat", vcol=True, rough=0.2, emission=hexc("#E6F4F1"), strength=0.5, alpha=0.86,
                  cull=False)
    obj_from_bm("Waterfall", bm, wf, body)

    # mist at the waterfall base
    ang = 0.45 + 0.62
    base_d = (TOP * math.cos(ang) + fall_dir * math.sin(ang)).normalized()
    bm = bmesh.new()
    for i in range(14):
        p = base_d * 1.02 + Vector((rnd.gauss(0, 0.05), rnd.gauss(0, 0.05), rnd.gauss(0, 0.03)))
        add_ico(bm, p, rnd.uniform(0.025, 0.05), subdiv=2, jitter=0.1, rnd=rnd, color=hexc("#F1F5F2"))
    paint_hints(bm)
    obj_from_bm("Mist", bm, material("MistMat", rough=1.0, emission=hexc("#F4EFE8"), strength=0.4, alpha=0.7),
                body)

    # hero tree on the plateau
    wood, leaf = bmesh.new(), bmesh.new()
    tree_base = pl.surface(TOP)
    blossoms = [hexc("#D98CA3"), hexc("#C9758F"), hexc("#E6A3B6"), hexc("#B9667F"), hexc("#EDB5C4")]
    build_tree(wood, leaf, tree_base, TOP, 0.74 if evolved else 0.66, random.Random(7), depth=4,
               blossom_colors=blossoms, canopy=1.5 if evolved else 1.0)
    if evolved:
        # a young second blossom tree appears after revisiting
        d2 = (TOP + t * 0.22 + b * 0.12).normalized()
        build_tree(wood, leaf, pl.surface(d2), d2, 0.24, random.Random(19), depth=3,
                   blossom_colors=blossoms, canopy=1.2, leaf_size=(0.016, 0.03))
    paint_hints(wood)
    obj_from_bm("TreeWood", wood, material("BarkMat", rough=0.9), body)
    paint_hints(leaf)
    obj_from_bm("Blossom", leaf, material("BlossomMat", rough=0.75, emission=hexc("#F5C6D1"),
                                          strength=0.35 if evolved else 0.18), body)

    # vegetation, rocks, flowers
    veg = bmesh.new()
    greens = [hexc("#4E7A44"), hexc("#5F8D4B"), hexc("#3F6A42"), hexc("#7A9F55")]
    bushes(pl, veg, 170, rnd, lambda d, hh: 0.012 < hh < 0.09 and d.dot(TOP) < 0.76, greens)
    bushes(pl, veg, 40, rnd, lambda d, hh: d.dot(TOP) > 0.85 and d.dot(TOP) < 0.97, greens,
           size=(0.012, 0.022), conifer=0.1)
    rocks(pl, veg, 34, rnd, lambda d, hh: (0.0 < hh < 0.02) or (0.77 < d.dot(TOP) < 0.84),
          [hexc("#8B8177"), hexc("#A59A8C"), hexc("#6E675F")])
    flower_cols = [hexc("#F8F1E4"), hexc("#F2D58A"), hexc("#EFB3C2")]
    nflowers = 360 if evolved else 140

    def flower(d, hh):
        add_ico(veg, pl.surface(d) + d * 0.004, rnd.uniform(0.004, 0.008), subdiv=0, color=rnd.choice(flower_cols))
    scatter_on(pl, nflowers, rnd, lambda d, hh: 0.012 < hh < 0.2, flower)
    paint_hints(veg)
    obj_from_bm("Vegetation", veg, material("VegMat", rough=0.85), body)

    # glass atmosphere (echoes the glass-sphere look of the concept art)
    glass_shell("Atmosphere", root, 1.13, hexc("#CFE5E1"), 0.10, strength=0.05)

    clouds = empty("Clouds", root)
    cloud_puffs("CloudPuffs", clouds, 1.0, 11, rnd, hexc("#FBF3EC"), band=(-0.75, 0.25))

    ring_e = empty("Ring", root)
    ring("RingBand", ring_e, 1.58, 0.0045, 14, -20, hexc("#F1D3AC"), 6.0, sparkles=80, rnd=rnd)
    if evolved:
        ring("RingBandInner", ring_e, 1.42, 0.0025, 20, -12, hexc("#F3C6CF"), 5.0, sparkles=40, rnd=rnd)
    part = empty("Particles", root)
    cols = [hexc("#F5C3CF"), hexc("#F6E2C8"), hexc("#FFFFFF")]
    if evolved:
        cols.append(hexc("#F2D089"))
    particles("Petals", part, 260 if evolved else 150, 1.18, 1.95, cols, (0.006, 0.013), rnd)
    export("planet_bloom_evolved" if evolved else "planet_bloom")


# ----------------------------------------------------------------------------
# Supporting planets
# ----------------------------------------------------------------------------

def build_tide():
    reset()
    root = empty("PlanetTide")
    rnd = random.Random(202)

    def hfn(pl, d):
        v = fbm(d * 2.6 + pl.off, 5) * 0.12
        return max(v - 0.02, -0.03)

    def cfn(pl, d, hh, s):
        if hh < -0.005:
            return mix(hexc("#1F4E57"), hexc("#3F8C8A"), smoothstep(-0.03, -0.005, hh))
        if hh < 0.006:
            return hexc("#E6D8B5")
        return mix(hexc("#6E9B5A"), hexc("#9DBB72"), fbm(d * 13 + pl.off, 2) * 0.5 + 0.5)

    pl = Planet(2, hfn)
    body = empty("Body", root)
    pl.terrain("Terrain", 4, cfn, body)
    ocean("Water", body, hexc("#4A9FA6"), radius=1.0, alpha=0.8)
    bm = bmesh.new()
    bushes(pl, bm, 80, rnd, lambda d, hh: hh > 0.008, [hexc("#4F7F4C"), hexc("#6F9A55")], conifer=0.0)
    coral = [hexc("#E7A4A0"), hexc("#F0C0A8"), hexc("#D98F95")]

    def reef(d, hh):
        add_ico(bm, pl.surface(d), rnd.uniform(0.006, 0.014), subdiv=1, color=rnd.choice(coral), jitter=0.3, rnd=rnd)
    scatter_on(pl, 120, rnd, lambda d, hh: -0.012 < hh < -0.002, reef)
    paint_hints(bm)
    obj_from_bm("Islands", bm, material("IslandMat", rough=0.85), body)
    clouds = empty("Clouds", root)
    cloud_puffs("CloudPuffs", clouds, 1.0, 9, rnd, hexc("#F7F5F0"), band=(-0.35, 0.35), height=(0.1, 0.16),
                size=(0.04, 0.08))
    moon = empty("Moon", root)
    bm = bmesh.new()
    add_ico(bm, Vector((1.75, 0, 0.35)), 0.16, subdiv=3, jitter=0.04, rnd=rnd, color=hexc("#C9C3B6"))
    paint_hints(bm)
    obj_from_bm("MoonBody", bm, material("MoonMat", rough=0.95), moon)
    glass_shell("Atmosphere", root, 1.09, hexc("#BFE3E6"), 0.08)
    export("planet_tide")


def build_dune():
    reset()
    root = empty("PlanetDune")
    rnd = random.Random(303)

    def hfn(pl, d):
        ridge = 1 - abs(noise.noise(d * 3.2 + pl.off, noise_basis="PERLIN_ORIGINAL"))
        return ridge ** 3 * 0.07 + fbm(d * 8 + pl.off, 3) * 0.012

    def cfn(pl, d, hh, s):
        base = mix(hexc("#C98F7E"), hexc("#E8BC9C"), smoothstep(0.0, 0.06, hh))
        base = mix(base, hexc("#F1DCC4"), smoothstep(0.045, 0.075, hh))
        if s > 0.12:
            base = mix(base, hexc("#B07A72"), 0.5)
        return base

    pl = Planet(3, hfn)
    body = empty("Body", root)
    pl.terrain("Terrain", 4, cfn, body, rough=0.95)
    bm = bmesh.new()
    for k in range(3):
        d = rand_dir(rnd)
        t, b = tangent_frame(d)
        c = pl.surface(d)
        prev = None
        for i in range(13):
            a = math.pi * i / 12
            p = c + t * (math.cos(a) * 0.09) + d * (math.sin(a) * 0.08)
            if prev is not None:
                add_tube(bm, prev, p, 0.016, 0.016, segs=6, color=hexc("#A9746A"))
            prev = p
    rocks(pl, bm, 50, rnd, lambda d, hh: True, [hexc("#9C6E66"), hexc("#B98A7B")])
    paint_hints(bm)
    obj_from_bm("Arches", bm, material("ArchMat", rough=0.9), body)
    ring_e = empty("Ring", root)
    bm = bmesh.new()
    for i in range(1400):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(1.35, 1.95)
        p = Vector((math.cos(a) * rr, math.sin(a) * rr, rnd.gauss(0, 0.012)))
        star_octa(bm, p, rnd.uniform(0.006, 0.014), rnd.choice([hexc("#E5C5AE"), hexc("#D6A39F"), hexc("#F3E3CF")]))
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(70), 4, "X") @ Matrix.Rotation(math.radians(12), 4, "Y"),
                        verts=bm.verts)
    paint_hints(bm)
    obj_from_bm("DustRing", bm, material("DustMat", unlit=True), ring_e, smooth=True)
    glass_shell("Atmosphere", root, 1.1, hexc("#F0D2BF"), 0.07)
    export("planet_dune")


def build_frost():
    reset()
    root = empty("PlanetFrost")
    rnd = random.Random(404)

    def hfn(pl, d):
        return fbm(d * 3.0 + pl.off, 5) * 0.06

    def cfn(pl, d, hh, s):
        c = mix(hexc("#AFC6C6"), hexc("#E9EFEA"), smoothstep(-0.03, 0.03, hh))
        if s > 0.1:
            c = mix(c, hexc("#8FA8A6"), 0.6)
        return c

    pl = Planet(4, hfn)
    body = empty("Body", root)
    pl.terrain("Terrain", 4, cfn, body, rough=0.6)
    bm = bmesh.new()

    def crystal(d, hh):
        base = pl.surface(d)
        for k in range(rnd.randint(2, 4)):
            tilt = (d + Vector((rnd.gauss(0, 0.3), rnd.gauss(0, 0.3), rnd.gauss(0, 0.3)))).normalized()
            L = rnd.uniform(0.08, 0.22)
            tmp = bmesh.new()
            bmesh.ops.create_cone(tmp, cap_ends=True, segments=6, radius1=L * 0.18, radius2=0.0, depth=L)
            q = Vector((0, 0, 1)).rotation_difference(tilt)
            bmesh.ops.transform(tmp, matrix=Matrix.Translation(base + tilt * L * 0.45) @ q.to_matrix().to_4x4(),
                                verts=tmp.verts)
            merge(bm, tmp, rnd.choice([hexc("#A9D8D6"), hexc("#C4E3DC"), hexc("#E3F1EC")]))
    scatter_on(pl, 46, rnd, lambda d, hh: True, crystal)
    paint_hints(bm)
    obj_from_bm("Crystals", bm, material("CrystalMat", rough=0.08, emission=hexc("#BFE6E0"), strength=0.6,
                                         alpha=0.82, spec=1.0), body, smooth=False)
    ring_e = empty("Ring", root)
    ring("RingBand", ring_e, 1.5, 0.006, 60, 25, hexc("#BFE6DA"), 4.0, sparkles=60, rnd=rnd)
    glass_shell("Atmosphere", root, 1.1, hexc("#DDEFEA"), 0.1)
    export("planet_frost")


def build_grove():
    reset()
    root = empty("PlanetGrove")
    rnd = random.Random(505)

    def hfn(pl, d):
        return max(fbm(d * 2.4 + pl.off, 5) * 0.1, -0.02)

    def cfn(pl, d, hh, s):
        if hh < -0.004:
            return hexc("#2D5A55")
        c = mix(hexc("#2F5B3A"), hexc("#557F45"), fbm(d * 9 + pl.off, 3) * 0.5 + 0.5)
        if s > 0.15:
            c = mix(c, hexc("#6B6155"), 0.5)
        return c

    pl = Planet(5, hfn)
    body = empty("Body", root)
    pl.terrain("Terrain", 4, cfn, body)
    ocean("Lake", body, hexc("#3E7F7B"), radius=1.0, alpha=0.85)
    bm = bmesh.new()
    bushes(pl, bm, 520, rnd, lambda d, hh: hh > 0.002,
           [hexc("#2E5A3A"), hexc("#3F6E45"), hexc("#4F7F4C"), hexc("#264B33")], size=(0.02, 0.04), conifer=0.7)
    paint_hints(bm)
    obj_from_bm("Forest", bm, material("ForestMat", rough=0.9), body)
    clouds = empty("Clouds", root)
    cloud_puffs("MistPuffs", clouds, 1.0, 8, rnd, hexc("#E7EEEA"), band=(-0.5, 0.5), height=(0.07, 0.11),
                size=(0.04, 0.07), alpha=0.75, strength=0.2)
    part = empty("Particles", root)
    particles("Fireflies", part, 120, 1.05, 1.5, [hexc("#F2D089"), hexc("#F6E2C8")], (0.005, 0.01), rnd)
    glass_shell("Atmosphere", root, 1.1, hexc("#CFE3D6"), 0.08)
    export("planet_grove")


def build_ember():
    reset()
    root = empty("PlanetEmber")
    rnd = random.Random(606)

    def hfn(pl, d):
        return fbm(d * 2.8 + pl.off, 5) * 0.085

    def cfn(pl, d, hh, s):
        c = mix(hexc("#5E4A5A"), hexc("#A07C86"), smoothstep(-0.04, 0.05, hh))
        if s > 0.14:
            c = mix(c, hexc("#4A3B48"), 0.5)
        return c

    pl = Planet(6, hfn)
    body = empty("Body", root)
    pl.terrain("Terrain", 4, cfn, body)
    bm = bmesh.new()

    def pool(d, hh):
        t, b = tangent_frame(d)
        add_ico(bm, pl.surface(d) + d * 0.002, rnd.uniform(0.03, 0.06), subdiv=2, scale=(1, 1, 0.12),
                color=rnd.choice([hexc("#E9A87A"), hexc("#E5C5AE")]), rot=Matrix((t, b, d)).transposed())
    scatter_on(pl, 18, rnd, lambda d, hh: hh < 0.0, pool)
    paint_hints(bm)
    obj_from_bm("GlowPools", bm, material("PoolMat", rough=0.3, emission=hexc("#EBB38A"), strength=2.2), body)
    bm = bmesh.new()

    def lantern(d, hh):
        add_ico(bm, pl.surface(d) + d * rnd.uniform(0.03, 0.12), rnd.uniform(0.008, 0.016), subdiv=1)
    scatter_on(pl, 40, rnd, lambda d, hh: True, lantern)
    obj_from_bm("Lanterns", bm, material("LanternMat", vcol=False, color=hexc("#F2D3A8"),
                                         emission=hexc("#F2D3A8"), strength=5.0), body)
    rocks(pl, bm := bmesh.new(), 60, rnd, lambda d, hh: True, [hexc("#4F4150"), hexc("#6A5563")])
    paint_hints(bm)
    obj_from_bm("Rocks", bm, material("RockMat", rough=0.9), body)
    glass_shell("Atmosphere", root, 1.1, hexc("#E7C3C3"), 0.09)
    export("planet_ember")


# ----------------------------------------------------------------------------
# Sealed capsule
# ----------------------------------------------------------------------------

def build_capsule():
    reset()
    root = empty("Capsule")
    rnd = random.Random(707)
    core = empty("Core", root)
    pl = Planet(1, bloom_height)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = d * (1.0 + pl.h(d)) * 0.62
    bm.normal_update()
    paint(bm, lambda v: mix(bloom_colors(pl, v.co.normalized(), pl.h(v.co.normalized()), 0.0),
                            hexc("#8FA8A6"), 0.55))
    obj_from_bm("CoreBody", bm, material("CoreMat", rough=0.9, emission=hexc("#9DB7B2"), strength=0.12), core)
    glass_shell("Shell", root, 1.0, hexc("#BFD6D2"), 0.30, strength=0.18, subdiv=4)
    lat = empty("Lattice", root)
    bm = bmesh.new()
    ico = bmesh.new()
    bmesh.ops.create_icosphere(ico, subdivisions=2, radius=1.015)
    for e in ico.edges:
        a, b = e.verts[0].co.copy(), e.verts[1].co.copy()
        mid = ((a + b) * 0.5).normalized() * 1.015
        add_tube(bm, a, mid, 0.0035, 0.0035, segs=5, caps=False)
        add_tube(bm, mid, b, 0.0035, 0.0035, segs=5, caps=False)
    for v in ico.verts:
        add_ico(bm, v.co, 0.011, subdiv=1)
    ico.free()
    obj_from_bm("LatticeMesh", bm, material("LatticeMat", vcol=False, color=hexc("#E5C5AE"),
                                            emission=hexc("#E5C5AE"), strength=1.3, rough=0.35, metal=0.6), lat)
    seal = empty("Seal", root)
    ring("SealBand", seal, 1.12, 0.010, 12, 0, hexc("#EED6B8"), 3.0, segs=128)
    ring("SealBandThin", seal, 1.2, 0.003, 18, -6, hexc("#E5C5AE"), 4.0, sparkles=50, rnd=rnd, segs=128)
    part = empty("Particles", root)
    particles("Motes", part, 140, 0.68, 0.95, [hexc("#F6E2C8"), hexc("#E5C5AE"), hexc("#D6A39F")], (0.006, 0.012), rnd)
    particles("OuterMotes", part, 90, 1.15, 1.7, [hexc("#E5C5AE"), hexc("#C4D0C9")], (0.005, 0.01), rnd)
    export("capsule_sealed")


# ----------------------------------------------------------------------------
# Galaxies, starfield, nebula veils
# ----------------------------------------------------------------------------

TETRA = [Vector((1, 1, 1)), Vector((-1, -1, 1)), Vector((-1, 1, -1)), Vector((1, -1, -1))]


def star_octa(bm, p, s, col):
    """Tiny tetrahedron star (4 tris, 4 shared verts) - cheap point sprite substitute."""
    vs = []
    for c in TETRA:
        v = bm.verts.new(p + c * (s * 0.577))
        COLOR_HINT[v] = col
        vs.append(v)
    for f in ((0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)):
        bm.faces.new([vs[i] for i in f])


def build_galaxy(year, seed, arms, palette, core_col, veil_img, shape="spiral", count=5200, twist=2.6):
    reset()
    root = empty(f"Galaxy{year}")
    rnd = random.Random(seed)
    stars = empty("Stars", root)
    bm = bmesh.new()
    for i in range(count):
        if shape == "ring":
            a = rnd.uniform(0, 2 * math.pi)
            r = rnd.gauss(2.6, 0.45) if rnd.random() < 0.75 else abs(rnd.gauss(0, 1.0))
            x, y = math.cos(a) * r, math.sin(a) * r * 0.86
        else:
            arm = rnd.randrange(arms)
            r = rnd.random() ** 1.6 * 4.0 + 0.15
            a = arm * 2 * math.pi / arms + r * twist / 4.0 * math.pi + rnd.gauss(0, 0.22 + 0.08 * r)
            x, y = math.cos(a) * r, math.sin(a) * r
        z = rnd.gauss(0, 0.06 + 0.12 * math.exp(-((x * x + y * y) ** 0.5)))
        rr = (x * x + y * y) ** 0.5
        t = min(1.0, rr / 4.0)
        col = mix(core_col, rnd.choice(palette), smoothstep(0.0, 0.55, t))
        bright = rnd.uniform(0.55, 1.0)
        col = (col[0] * bright, col[1] * bright, col[2] * bright, 1)
        s = rnd.uniform(0.016, 0.042) * (1.7 if rnd.random() < 0.04 else 1.0)
        star_octa(bm, Vector((x, y, z)), s, col)
    paint_hints(bm)
    obj_from_bm("StarPoints", bm, material("StarMat", unlit=True), stars, smooth=True)
    core = empty("Core", root)
    bm = bmesh.new()
    add_ico(bm, Vector((0, 0, 0)), 0.32, subdiv=3, scale=(1, 1, 0.55))
    obj_from_bm("CoreGlow", bm, material("CoreMat", vcol=False, color=core_col, emission=core_col, strength=4.0), core)
    # layered translucent veils give a volumetric-looking nebula around the disc
    dust = empty("Dust", root)
    img = load_image(veil_img)
    glow = load_image("glow.png")
    for k in range(5):
        bm = bmesh.new()
        size = rnd.uniform(3.6, 5.2) if k else 2.0
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x / size + 1) * 0.5, (l.vert.co.y / size + 1) * 0.5)
        rot = Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 4, "Z") @ Matrix.Rotation(rnd.uniform(-0.15, 0.15), 4, "X")
        bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, rnd.uniform(-0.05, 0.05))) @ rot, verts=bm.verts)
        m = material(f"Veil{k}Mat", vcol=False, image=glow if k == 0 else img, strength=1.6 if k == 0 else 0.9,
                     cull=False)
        obj_from_bm(f"Veil{k}", bm, m, dust)
    export(f"galaxy_{year}")


def build_starfield():
    reset()
    root = empty("Starfield")
    rnd = random.Random(808)
    bm = bmesh.new()
    cols = [hexc("#EEEDE5"), hexc("#E5C5AE"), hexc("#C4D0C9"), hexc("#FFFFFF")]
    for i in range(2600):
        d = rand_dir(rnd)
        b = rnd.random() ** 2.5
        col = rnd.choice(cols)
        col = (col[0] * (0.35 + 0.65 * b), col[1] * (0.35 + 0.65 * b), col[2] * (0.35 + 0.65 * b), 1)
        star_octa(bm, d * rnd.uniform(70, 95), 0.07 + 0.22 * b, col)
    paint_hints(bm)
    obj_from_bm("Stars", bm, material("StarfieldMat", unlit=True), root, smooth=True)
    export("starfield")


def build_veils():
    reset()
    root = empty("NebulaVeils")
    rnd = random.Random(909)
    imgs = [load_image("veil_teal.png"), load_image("veil_amber.png"), load_image("veil_rose.png")]
    placements = [
        (Vector((-14, -30, 4)), 22, 0, 0.7), (Vector((16, -36, -6)), 26, 1, 0.55),
        (Vector((2, -44, 10)), 30, 2, 0.45), (Vector((-24, -20, -10)), 18, 1, 0.4),
        (Vector((26, -18, 8)), 20, 0, 0.5), (Vector((0, 34, 0)), 34, 0, 0.45),
        (Vector((-30, 10, 12)), 26, 2, 0.35), (Vector((30, 16, -10)), 28, 1, 0.35),
    ]
    for i, (pos, size, im, strength) in enumerate(placements):
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x / size + 1) * 0.5, (l.vert.co.y / size + 1) * 0.5)
        # face the origin (where the camera orbits)
        n = (-pos).normalized()
        q = Vector((0, 0, 1)).rotation_difference(n)
        spin = Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 4, "Z")
        bmesh.ops.transform(bm, matrix=Matrix.Translation(pos) @ q.to_matrix().to_4x4() @ spin, verts=bm.verts)
        m = material(f"VeilMat{i}", vcol=False, image=imgs[im], strength=strength, cull=False)
        obj_from_bm(f"Veil{i}", bm, m, root)
    export("nebula_veils")


def build_orbit_ring():
    """Unit-radius orbital path; scaled per planet orbit at runtime."""
    reset()
    root = empty("OrbitRing")
    bm = bmesh.new()
    segs = 192
    for i in range(segs):
        a0 = 2 * math.pi * i / segs
        a1 = 2 * math.pi * (i + 1) / segs
        add_tube(bm, Vector((math.cos(a0), math.sin(a0), 0)), Vector((math.cos(a1), math.sin(a1), 0)),
                 0.0022, 0.0022, segs=4, caps=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    m = material("OrbitMat", vcol=False, color=hexc("#EEEDE5"), emission=hexc("#E5C5AE"), strength=1.2,
                 alpha=0.45, rough=0.5)
    obj_from_bm("Path", bm, m, root)
    export("orbit_ring")


BUILDERS = {
    "planet_bloom": lambda: build_bloom(False),
    "planet_bloom_evolved": lambda: build_bloom(True),
    "planet_tide": build_tide,
    "planet_dune": build_dune,
    "planet_frost": build_frost,
    "planet_grove": build_grove,
    "planet_ember": build_ember,
    "capsule_sealed": build_capsule,
    "galaxy_2024": lambda: build_galaxy(2024, 2024, 2, [hexc("#8FD0C4"), hexc("#C4D0C9"), hexc("#6FB3B0")],
                                        hexc("#F4F1E6"), "veil_teal.png", twist=2.8),
    "galaxy_2025": lambda: build_galaxy(2025, 2025, 3, [hexc("#E5C5AE"), hexc("#F2B98F"), hexc("#EED9B6")],
                                        hexc("#FFE7C4"), "veil_amber.png", twist=2.0),
    "galaxy_2026": lambda: build_galaxy(2026, 2026, 1, [hexc("#D6A39F"), hexc("#C9A7C7"), hexc("#EFC6C8")],
                                        hexc("#F8E1E1"), "veil_rose.png", shape="ring"),
    "starfield": build_starfield,
    "nebula_veils": build_veils,
    "orbit_ring": build_orbit_ring,
}

if __name__ == "__main__":
    for key, fn in BUILDERS.items():
        if ONLY and key not in ONLY:
            continue
        fn()
    print("STATS", STATS)
