"""
Hollow Vigil — Blender asset builder.

Generates every character and prop of the game as low-poly models and exports them as
.glb files into ../game/assets/models/. The Godot game automatically uses these models
when present (otherwise it builds identical procedural stand-ins at runtime).

Run (Blender 3.6 – 4.x):
    blender --background --python blender/build_assets.py
or open Blender > Scripting tab > open this file > Run Script.

After running, open the Godot project once so it imports the new .glb files.

Conventions (must match game/scripts/body.gd):
  * All coordinates below are written in *Godot space* (Y up, characters face -Z) and are
    converted to Blender space (Z up, characters face +Y) by g2b().
  * Characters are made of separate objects whose ORIGIN is the joint pivot:
      Torso (hips), Head (neck), ArmL/ArmR (shoulders), LegL/LegR (hips),
      optional Tent1..Tent4 (beast tentacles), Eye (beast chest eye), Eyes (glowing eyes, child of Head).
  * The game animates those pivots procedurally, so no armature is needed.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else bpy.path.abspath("//")
OUT = os.path.normpath(os.path.join(HERE, "..", "game", "assets", "models"))

# Godot -> Blender basis change: (x, y, z)_godot -> (x, -z, y)_blender
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
CI = C.inverted()


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def rot_g(deg):
    """Godot Euler (degrees, YXZ order) -> Blender 3x3 rotation."""
    rx, ry, rz = (math.radians(a) for a in deg)
    r = Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(rz, 3, "Z")
    return C @ r @ CI


# ------------------------------------------------------------------ materials
_mats = {}


def material(color, glow=0.0, rough=0.8):
    key = (tuple(round(c, 3) for c in color), glow, rough)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("m%d" % len(_mats))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgba = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    if glow > 0:
        emit = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        emit.default_value = rgba
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = glow
    _mats[key] = m
    return m


# ------------------------------------------------------------------ geometry builder
class Part:
    """One Blender object whose origin sits at a Godot-space pivot."""

    def __init__(self, name, pivot=(0, 0, 0), parent=None):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.me = bpy.data.meshes.new(name)
        self.obj = bpy.data.objects.new(name, self.me)
        bpy.context.scene.collection.objects.link(self.obj)
        self.obj.location = g2b(pivot)
        if parent is not None:
            self.obj.parent = parent.obj if isinstance(parent, Part) else parent
        self.children = []

    def _slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _tag(self, before, mat):
        idx = self._slot(mat)
        for f in self.bm.faces:
            if f not in before:
                f.material_index = idx

    def box(self, size, pos, color, rot=(0, 0, 0), glow=0.0, rough=0.8):
        before = set(self.bm.faces)
        m = Matrix.Translation(g2b(pos)) @ rot_g(rot).to_4x4() @ Matrix.Diagonal((size[0], size[2], size[1], 1.0))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._tag(before, material(color, glow, rough))

    def cyl(self, rt, rb, h, pos, color, seg=8, rot=(0, 0, 0), glow=0.0, rough=0.8):
        before = set(self.bm.faces)
        m = Matrix.Translation(g2b(pos)) @ rot_g(rot).to_4x4()
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=rb, radius2=max(rt, 0.0001), depth=h, matrix=m)
        self._tag(before, material(color, glow, rough))

    def sphere(self, r, pos, color, seg=8, glow=0.0):
        before = set(self.bm.faces)
        m = Matrix.Translation(g2b(pos))
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=max(3, seg // 2), radius=r, matrix=m)
        self._tag(before, material(color, glow))

    def finish(self):
        self.bm.to_mesh(self.me)
        self.bm.free()
        for m in self.mats:
            self.me.materials.append(m)
        for p in self.me.polygons:
            p.use_smooth = False


def new_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def root(name):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    return e


def export(name, parts):
    for p in parts:
        p.finish()
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.select_set(True)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True)
    print("exported", path)


# ------------------------------------------------------------------ characters
SKIN = (0.62, 0.48, 0.38)
CLOTH = 0.95  # roughness > 0.9 => game uses the cloth texture


def darker(c, k):
    return tuple(x * (1 - k) for x in c)


def humanoid(r, shirt, pants, skin, head_scale=1.0):
    t = Part("Torso", (0, 0.95, 0), r)
    t.box((0.46, 0.56, 0.26), (0, 0.29, 0), shirt, rough=CLOTH)
    t.box((0.44, 0.12, 0.25), (0, 0.02, 0), darker(pants, 0.2), rough=CLOTH)
    h = Part("Head", (0, 1.52, 0), r)
    h.box((0.1, 0.1, 0.1), (0, 0.03, 0), skin)
    hs = head_scale
    h.box((0.25 * hs, 0.29 * hs, 0.27 * hs), (0, 0.19, 0), skin)
    parts = {"Torso": t, "Head": h}
    for side, nm in ((-1, "L"), (1, "R")):
        a = Part("Arm" + nm, (side * 0.31, 1.45, 0), r)
        a.box((0.13, 0.36, 0.14), (0, -0.16, 0), shirt, rough=CLOTH)
        a.box((0.11, 0.3, 0.12), (0, -0.47, 0), darker(shirt, 0.1), rough=CLOTH)
        a.box((0.1, 0.1, 0.1), (0, -0.66, 0), skin)
        leg = Part("Leg" + nm, (side * 0.12, 0.95, 0), r)
        leg.box((0.17, 0.86, 0.19), (0, -0.44, 0), pants, rough=CLOTH)
        leg.box((0.18, 0.1, 0.28), (0, -0.9, -0.04), (0.1, 0.08, 0.06))
        parts["Arm" + nm] = a
        parts["Leg" + nm] = leg
    return parts


def eyes(head, color, z=-0.14, y=0.22, spacing=0.06, glow=3.0):
    e = Part("Eyes", (0, 0, 0), head)
    e.obj.location = (0, 0, 0)
    for side in (-1, 1):
        e.box((0.045, 0.03, 0.02), (side * spacing, y, z), color, glow=glow)
    return e


def build_character(kind):
    new_scene()
    r = root(kind)
    extra = []
    if kind == "player":
        p = humanoid(r, (0.32, 0.2, 0.12), (0.16, 0.2, 0.3), SKIN)
        p["Head"].box((0.27, 0.1, 0.29), (0, 0.33, 0.01), (0.12, 0.09, 0.06))
        p["Head"].box((0.27, 0.16, 0.06), (0, 0.24, 0.13), (0.12, 0.09, 0.06))
        p["Torso"].box((0.12, 0.5, 0.05), (0.1, 0.3, -0.14), (0.2, 0.2, 0.2))
        p["Torso"].box((0.3, 0.35, 0.12), (0, 0.3, 0.18), (0.2, 0.22, 0.14), rough=CLOTH)
        # jacket collar + holster
        p["Torso"].box((0.5, 0.08, 0.3), (0, 0.55, 0.0), (0.26, 0.16, 0.1), rough=CLOTH)
        p["LegR"].box((0.08, 0.2, 0.2), (0.1, -0.15, 0), (0.1, 0.07, 0.05))
        extra.append(eyes(p["Head"], (0.05, 0.05, 0.05), -0.14, 0.2, 0.06, glow=0.0))
    elif kind == "villager":
        shirt = (0.4, 0.33, 0.22)
        skin = (0.5, 0.45, 0.38)
        p = humanoid(r, shirt, (0.24, 0.2, 0.15), skin)
        p["Head"].cyl(0.16, 0.16, 0.06, (0, 0.36, 0), (0.2, 0.18, 0.15), 8)
        p["Head"].box((0.28, 0.02, 0.12), (0, 0.34, -0.17), (0.2, 0.18, 0.15))
        p["Torso"].box((0.48, 0.3, 0.05), (0, 0.15, -0.14), (0.35, 0.3, 0.25), rough=CLOTH)  # apron
        extra.append(eyes(p["Head"], (1.0, 0.12, 0.05)))
    elif kind == "zealot":
        shirt = (0.18, 0.08, 0.1)
        p = humanoid(r, shirt, (0.2, 0.17, 0.13), (0.5, 0.45, 0.4))
        p["Head"].cyl(0.08, 0.2, 0.45, (0, 0.3, 0.02), shirt, 6, rough=CLOTH)
        p["Torso"].cyl(0.26, 0.38, 0.95, (0, -0.4, 0), shirt, 8, rough=CLOTH)
        p["Head"].box((0.2, 0.2, 0.04), (0, 0.18, -0.15), (0.8, 0.78, 0.7))
        extra.append(eyes(p["Head"], (1.0, 0.12, 0.05)))
    elif kind == "brute":
        p = humanoid(r, (0.3, 0.26, 0.2), (0.18, 0.15, 0.12), darker(SKIN, 0.2), 1.25)
        p["Head"].box((0.36, 0.42, 0.36), (0, 0.2, 0), (0.55, 0.47, 0.32), rough=CLOTH)
        p["Head"].box((0.1, 0.04, 0.02), (0, 0.1, -0.19), (0.2, 0.1, 0.05))  # stitched mouth
        p["Torso"].box((0.6, 0.7, 0.4), (0, 0.3, 0), (0.45, 0.4, 0.35), rough=CLOTH)
        p["Torso"].box((0.5, 0.8, 0.05), (0, 0.1, -0.22), (0.4, 0.15, 0.1), rough=CLOTH)
        for k in range(3):
            p["Torso"].box((0.05, 0.15, 0.05), (-0.25 + k * 0.08, -0.15, -0.26), (0.6, 0.6, 0.62))  # hooks
        extra.append(eyes(p["Head"], (1.0, 0.1, 0.05), -0.19, 0.25, 0.08))
    elif kind == "aldric":
        red = (0.35, 0.05, 0.08)
        p = humanoid(r, red, (0.2, 0.03, 0.05), (0.7, 0.66, 0.6))
        p["Torso"].cyl(0.26, 0.5, 1.05, (0, -0.45, 0), red, 8, rough=CLOTH)
        p["Torso"].box((0.14, 0.9, 0.03), (0, 0.1, -0.14), (0.7, 0.55, 0.15), glow=0.0)
        p["Head"].cyl(0.06, 0.16, 0.45, (0, 0.52, 0), (0.75, 0.7, 0.55), 4)
        p["Head"].box((0.2, 0.18, 0.08), (0, 0.02, -0.12), (0.85, 0.85, 0.85))
        extra.append(eyes(p["Head"], (1, 0.8, 0.2), -0.14, 0.2))
    elif kind == "beast":
        red = (0.3, 0.05, 0.08)
        p = humanoid(r, red, (0.2, 0.05, 0.05), (0.45, 0.35, 0.38))
        p["Torso"].cyl(0.3, 0.6, 1.1, (0, -0.45, 0), red, 7, rough=CLOTH)
        p["Torso"].box((0.7, 0.4, 0.5), (0, 0.55, 0.12), (0.4, 0.3, 0.33), rot=(20, 0, 0))
        for i in range(4):
            side = -1 if i % 2 == 0 else 1
            t = Part("Tent%d" % (i + 1), (side * 0.25, 1.35 + (i // 2) * 0.12, 0.2), r)
            for s in range(5):
                k = 1.0 - s * 0.12
                t.box((0.12 * k, 0.3 * k, 0.12 * k), (0, -0.15 - s * 0.28, 0), darker((0.5, 0.2, 0.25), s * 0.08))
            extra.append(t)
        eye = Part("Eye", (0, 1.25, -0.16), r)
        eye.sphere(0.2, (0, 0, 0), (1.0, 0.75, 0.1), 10, glow=3.0)
        eye.sphere(0.08, (0, 0, -0.17), (0.02, 0, 0), 6)
        extra.append(eye)
        p["Head"].cyl(0.02, 0.18, 0.6, (-0.12, 0.45, 0), (0.8, 0.75, 0.6), 4, rot=(0, 0, 25))
        p["Head"].cyl(0.02, 0.18, 0.6, (0.12, 0.45, 0), (0.8, 0.75, 0.6), 4, rot=(0, 0, -25))
    elif kind == "lena":
        coat = (0.8, 0.8, 0.76)
        p = humanoid(r, coat, (0.2, 0.2, 0.22), (0.68, 0.53, 0.43))
        p["Head"].box((0.28, 0.34, 0.2), (0, 0.23, 0.07), (0.1, 0.07, 0.05))
        p["Torso"].cyl(0.25, 0.32, 0.6, (0, -0.2, 0), coat, 8, rough=CLOTH)
        extra.append(eyes(p["Head"], (0.05, 0.05, 0.05), glow=0.0))
    elif kind == "merchant":
        coat = (0.12, 0.14, 0.2)
        p = humanoid(r, coat, (0.1, 0.1, 0.12), darker(SKIN, 0.4))
        p["Torso"].cyl(0.28, 0.45, 1.0, (0, -0.4, 0), coat, 8, rough=CLOTH)
        p["Head"].box((0.34, 0.38, 0.36), (0, 0.22, 0.04), (0.1, 0.12, 0.16), rough=CLOTH)
        p["Torso"].box((0.5, 0.7, 0.35), (0, 0.3, 0.3), (0.25, 0.18, 0.1), rough=CLOTH)
        p["Torso"].box((0.12, 0.3, 0.12), (0.2, 0.75, 0.35), (0.3, 0.3, 0.32))  # rifle stock poking out
        extra.append(eyes(p["Head"], (0.4, 0.6, 1.0), -0.16, 0.2))
    export(kind, list(p.values()) + extra)


# ------------------------------------------------------------------ props
def build_prop(name):
    new_scene()
    random.seed(name)
    r = root(name)
    m = Part(name + "_mesh", (0, 0, 0), r)
    parts = [m]
    wood = (0.35, 0.24, 0.13)
    if name == "house":
        wall = (0.42, 0.36, 0.28)
        m.box((8, 3.2, 6), (0, 1.6, 0), wall)
        for side in (-1, 1):
            m.box((8.6, 0.2, 3.9), (0, 4.2, side * 1.55), (0.25, 0.12, 0.08), rot=(side * 33, 0, 0))
        m.box((7.6, 1.8, 0.2), (0, 4.0, 2.9), darker(wall, 0.2))
        m.box((7.6, 1.8, 0.2), (0, 4.0, -2.9), darker(wall, 0.2))
        m.box((1.4, 2.3, 0.1), (0, 1.15, 3.02), (0.22, 0.14, 0.08))
        for x in (-2.6, 2.6):
            m.box((1.1, 0.9, 0.08), (x, 1.9, 3.02), (0.05, 0.05, 0.04))
            m.box((1.3, 0.12, 0.2), (x, 1.4, 3.05), (0.25, 0.16, 0.1))
            m.box((0.1, 0.9, 0.1), (x, 1.9, 3.06), (0.25, 0.16, 0.1))
        m.box((0.7, 1.6, 0.7), (2.5, 5.0, -1), (0.3, 0.28, 0.25))
        for x in (-3.9, 3.9):
            for z in (-2.9, 2.9):
                m.box((0.25, 3.2, 0.25), (x, 1.6, z), (0.25, 0.16, 0.1))
    elif name == "tree":
        h = 9.0
        m.cyl(0.15, 0.3, h * 0.4, (0, h * 0.2, 0), (0.2, 0.13, 0.08), 6)
        for k in range(3):
            rr = 2.3 - k * 0.6
            m.cyl(0.0, rr, h * 0.35, (0, h * (0.35 + k * 0.2), 0), (0.07, 0.13, 0.08), 7)
    elif name == "deadtree":
        m.cyl(0.1, 0.3, 6, (0, 3, 0), (0.15, 0.12, 0.1), 5)
        for k in range(4):
            m.cyl(0.02, 0.1, 2.2, (0, 3.5 + k * 0.6, 0), (0.15, 0.12, 0.1), 4, rot=(random.uniform(35, 70), k * 90 + random.uniform(0, 40), 0))
    elif name == "tombstone":
        g = (0.35, 0.35, 0.37)
        m.box((0.7, 1.0, 0.18), (0, 0.5, 0), g)
        m.cyl(0.35, 0.35, 0.18, (0, 1.0, 0), g, 8, rot=(90, 0, 0))
        m.box((0.9, 0.1, 1.8), (0, 0.05, 1.0), (0.18, 0.14, 0.1))
    elif name == "crate":
        m.box((0.9, 0.9, 0.9), (0, 0.45, 0), (0.45, 0.32, 0.18))
        m.box((0.95, 0.12, 0.95), (0, 0.45, 0), (0.3, 0.2, 0.1))
        m.box((0.95, 0.12, 0.12), (0, 0.45, 0), (0.3, 0.2, 0.1), rot=(0, 0, 45))
    elif name == "barrel":
        m.cyl(0.38, 0.38, 1.1, (0, 0.55, 0), (0.4, 0.26, 0.14), 8)
        for y in (0.2, 0.9):
            m.cyl(0.4, 0.4, 0.07, (0, y, 0), (0.2, 0.2, 0.2), 8)
    elif name == "fence":
        for x in (-1.5, 0, 1.5):
            m.box((0.14, 1.3, 0.14), (x, 0.65, 0), (0.3, 0.22, 0.13))
        for y in (0.5, 1.0):
            m.box((3.2, 0.1, 0.06), (0, y, 0), (0.33, 0.24, 0.14), rot=(0, 0, random.uniform(-4, 4)))
    elif name == "car":
        body = (0.12, 0.14, 0.12)
        m.box((1.9, 0.7, 4.3), (0, 0.6, 0), body)
        m.box((1.7, 0.6, 2.2), (0, 1.25, 0.2), (0.1, 0.12, 0.1))
        m.box((1.6, 0.45, 0.05), (0, 1.25, -0.92), (0.2, 0.25, 0.3), rot=(-20, 0, 0))
        for p in ((-0.9, 0.35, 1.4), (0.9, 0.35, 1.4), (-0.9, 0.35, -1.4), (0.9, 0.35, -1.4)):
            m.cyl(0.35, 0.35, 0.25, p, (0.05, 0.05, 0.05), 8, rot=(0, 0, 90))
        for x in (-0.6, 0.6):
            m.box((0.3, 0.15, 0.05), (x, 0.7, -2.16), (1, 0.9, 0.6), glow=3.0)
        m.box((1.8, 0.1, 0.4), (0, 0.4, 2.2), (0.3, 0.3, 0.3))
    elif name == "cart":
        m.box((1.6, 0.5, 2.6), (0, 0.9, 0), (0.35, 0.25, 0.14))
        for x in (-0.9, 0.9):
            m.cyl(0.6, 0.6, 0.12, (x, 0.6, 0.3), (0.25, 0.18, 0.1), 10, rot=(0, 0, 90))
        for x in (0.4, -0.4):
            m.box((0.12, 0.12, 2.2), (x, 0.8, -2.2), (0.3, 0.22, 0.12), rot=(-10, 0, 0))
        m.box((1.4, 0.6, 2.2), (0, 1.3, 0), (0.55, 0.48, 0.25))
    elif name == "well":
        m.cyl(1.1, 1.1, 0.9, (0, 0.45, 0), (0.35, 0.34, 0.33), 10)
        m.cyl(0.9, 0.9, 0.05, (0, 0.88, 0), (0.01, 0.01, 0.02), 10)
        for x in (-1.0, 1.0):
            m.box((0.15, 2.0, 0.15), (x, 1.5, 0), (0.3, 0.2, 0.12))
        m.box((2.6, 0.12, 1.4), (0, 2.6, 0), (0.25, 0.12, 0.08))
        m.cyl(0.1, 0.1, 2.0, (0, 2.2, 0), wood, 6, rot=(0, 0, 90))
    elif name == "bell":
        b = (0.45, 0.33, 0.14)
        m.cyl(0.35, 1.1, 1.6, (0, -0.8, 0), b, 12, rough=0.4)
        m.cyl(1.15, 1.15, 0.12, (0, -1.6, 0), darker(b, 0.1), 12, rough=0.4)
        m.sphere(0.36, (0, 0, 0), b, 10)
        m.sphere(0.18, (0, -1.5, 0), (0.2, 0.15, 0.1), 6)
        for k in range(3):
            m.box((1.9, 0.04, 0.04), (0, -0.6 - k * 0.3, 0), darker(b, 0.3), rot=(0, k * 60, 0))
    elif name == "cage":
        for i in range(10):
            a = math.tau * i / 10
            m.box((0.06, 2.4, 0.06), (math.cos(a), 1.2, math.sin(a)), (0.2, 0.18, 0.16))
        m.cyl(1.05, 1.05, 0.1, (0, 2.4, 0), (0.2, 0.18, 0.16), 10)
        m.cyl(1.05, 1.05, 0.1, (0, 0.05, 0), (0.2, 0.18, 0.16), 10)
        m.box((0.05, 3.0, 0.05), (0, 3.9, 0), (0.15, 0.15, 0.15))
    elif name == "helicopter":
        g = (0.18, 0.22, 0.18)
        m.box((2.2, 2.0, 5.0), (0, 1.4, 0), g)
        m.box((1.9, 1.0, 1.5), (0, 1.8, -2.7), (0.3, 0.4, 0.45), rot=(-15, 0, 0))
        m.box((0.5, 0.6, 5.5), (0, 1.9, 5.0), g)
        m.box((0.1, 1.6, 0.6), (0.3, 2.4, 7.5), g)
        m.box((0.4, 0.4, 0.6), (0, 2.55, 0), (0.1, 0.1, 0.1))
        for x in (-1.1, 1.1):
            m.box((0.12, 0.12, 4.2), (x, 0.1, 0), (0.1, 0.1, 0.1))
            m.box((0.08, 0.5, 0.08), (x, 0.35, -1.2), (0.1, 0.1, 0.1))
            m.box((0.08, 0.5, 0.08), (x, 0.35, 1.2), (0.1, 0.1, 0.1))
        rotor = Part("Rotor", (0, 2.7, 0), r)
        rotor.box((11, 0.05, 0.35), (0, 0, 0), (0.08, 0.08, 0.08))
        rotor.box((0.35, 0.05, 11), (0, 0, 0), (0.08, 0.08, 0.08))
        parts.append(rotor)
    elif name == "altar":
        m.box((3.2, 1.1, 1.3), (0, 0.55, 0), (0.4, 0.38, 0.36))
        m.box((3.4, 0.1, 1.5), (0, 1.12, 0), (0.45, 0.1, 0.1), rough=CLOTH)
        m.box((1.0, 0.9, 0.05), (0, 0.6, 0.78), (0.45, 0.1, 0.1), rough=CLOTH)
        for x in (-1.3, 1.3):
            m.cyl(0.05, 0.05, 0.4, (x, 1.35, 0), (0.9, 0.85, 0.7), 6)
            m.sphere(0.04, (x, 1.6, 0), (1, 0.6, 0.2), 4, glow=4.0)
    elif name == "pew":
        m.box((4.0, 0.12, 0.6), (0, 0.5, 0), (0.3, 0.18, 0.1))
        m.box((4.0, 0.7, 0.1), (0, 0.85, 0.3), (0.28, 0.17, 0.1))
        for x in (-1.9, 1.9):
            m.box((0.1, 0.5, 0.6), (x, 0.25, 0), (0.26, 0.16, 0.1))
    elif name == "lantern":
        m.box((0.25, 0.35, 0.25), (0, 0, 0), (0.1, 0.1, 0.1))
        m.sphere(0.1, (0, 0, 0), (1.0, 0.6, 0.2), 6, glow=4.0)
        m.box((0.05, 0.15, 0.05), (0, 0.25, 0), (0.1, 0.1, 0.1))
    elif name == "cross":
        m.box((0.3, 4.0, 0.3), (0, 2, 0), (0.25, 0.15, 0.08))
        m.box((2.0, 0.3, 0.3), (0, 3, 0), (0.25, 0.15, 0.08))
    export(name, parts)


CHARACTERS = ["player", "villager", "zealot", "brute", "aldric", "beast", "lena", "merchant"]
PROPS = ["house", "tree", "deadtree", "tombstone", "crate", "barrel", "fence", "car", "cart", "well",
         "bell", "cage", "helicopter", "altar", "pew", "lantern", "cross"]


def main():
    for k in CHARACTERS:
        build_character(k)
    for p in PROPS:
        build_prop(p)
    new_scene()
    print("Hollow Vigil: %d models written to %s" % (len(CHARACTERS) + len(PROPS), OUT))


if __name__ == "__main__":
    main()
