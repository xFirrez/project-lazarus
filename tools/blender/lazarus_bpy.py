"""Shared helpers for the Project Lazarus Blender generator scripts (bpy, Blender 4.2+ / 5.x).

Conventions (docs/ART_PIPELINE.md):
- Blender units are metres, Z up; the glTF exporter converts to Godot's Y up (Blender -Y = Godot +Z).
- Materials are named ``M_<id>``; the Godot post-import script swaps each for the shared
  ``res://content/materials/<id>.tres`` (automatic material remap).
- Collision objects get Godot import-hint suffixes: ``-convcolonly`` (convex, invisible) or
  ``-colonly`` (trimesh, invisible). A ``surface`` custom property travels as a glTF extra and
  becomes the collider's ``surface`` meta (impacts, footsteps).
- Sockets are empties named ``Socket_<what>[_n]`` (barricade planks, doors, attachments).
- Vertex color attribute ``Col``: R = grime/edge-dirt amount, G = wind-sway weight.
Every generator is deterministic: no randomness without a fixed seed.
"""

from __future__ import annotations

import math
import os
import random
import sys
import zlib

import bpy  # noqa: I001 (bpy must load before bmesh/mathutils in module mode)
import bmesh
from mathutils import Matrix, Vector

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME_ROOT = os.path.join(REPO_ROOT, "game")

# Viewport preview colors only; the real look comes from the remapped Godot materials.
PREVIEW_COLORS = {
    "plaster_rose": (0.62, 0.46, 0.44),
    "wood_dark": (0.22, 0.13, 0.08),
    "stone_grey": (0.42, 0.42, 0.44),
    "marble_floor": (0.75, 0.73, 0.7),
    "cobble_snow": (0.7, 0.72, 0.76),
    "metal_olive": (0.29, 0.31, 0.19),
    "metal_dark": (0.12, 0.12, 0.13),
    "brass": (0.7, 0.52, 0.24),
    "canvas_olive": (0.35, 0.36, 0.24),
    "sandbag": (0.52, 0.47, 0.35),
    "rubber": (0.05, 0.05, 0.05),
    "glass_lit": (1.0, 0.7, 0.35),
    "glass_frosted": (0.7, 0.8, 0.85),
    "ice": (0.6, 0.8, 0.9),
    "vesperite": (0.3, 1.0, 0.4),
    "zombie_skin": (0.55, 0.55, 0.45),
    "cloth_orderly": (0.78, 0.78, 0.72),
    "cloth_trousers": (0.18, 0.2, 0.24),
    "leather_boot": (0.12, 0.09, 0.07),
    "gun_steel": (0.1, 0.1, 0.11),
    "gun_grip_wood": (0.3, 0.15, 0.07),
    "sleeve_olive": (0.27, 0.29, 0.2),
    "skin_hand": (0.72, 0.56, 0.46),
    "emissive_red": (1.0, 0.1, 0.05),
    "emissive_warm": (1.0, 0.75, 0.4),
}


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(1234)


def argv_after_dashes() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def material(mat_id: str) -> bpy.types.Material:
    name = "M_" + mat_id
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        c = PREVIEW_COLORS.get(mat_id, (0.5, 0.5, 0.5))
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def link(obj: bpy.types.Object, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def empty(name: str, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.location = loc
    e.rotation_euler = rot
    e.empty_display_size = 0.2
    return link(e, parent)


def _finish_mesh(name: str, bm: bmesh.types.BMesh, mat_id: str | None, parent, grime: str) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    if mat_id is not None:
        me.materials.append(material(mat_id))
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me), parent)
    # Always write the attribute (zero grime for "none"): joining meshes where some parts lack
    # it leaves those corners undefined and the export non-deterministic.
    paint_grime(obj, grime)
    return obj


def box(name, size, loc=(0, 0, 0), mat_id="stone_grey", parent=None, rot=(0, 0, 0), bevel=0.0, grime="height"):
    """Axis-aligned box centred at ``loc`` (rotation applied to vertices, object at origin)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(
            bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True
        )
    mat = Matrix.Translation(Vector(loc)) @ _euler(rot)
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    return _finish_mesh(name, bm, mat_id, parent, grime)


def cylinder(name, radius, depth, loc=(0, 0, 0), mat_id="metal_dark", parent=None, rot=(0, 0, 0), segments=16,
             radius2=None, grime="height", cap=True):
    """Cylinder (or cone frustum with ``radius2``) along local Z, centred at ``loc``."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=cap, cap_tris=False, segments=segments, radius1=radius,
        radius2=radius if radius2 is None else radius2, depth=depth,
    )
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(loc)) @ _euler(rot), verts=bm.verts)
    return _finish_mesh(name, bm, mat_id, parent, grime)


def sphere(name, radius, loc=(0, 0, 0), mat_id="stone_grey", parent=None, scale=(1, 1, 1), segments=16, rings=8,
           grime="height"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return _finish_mesh(name, bm, mat_id, parent, grime)


def polygon_prism(name, points_xz, depth, y=0.0, mat_id="stone_grey", parent=None, grime="height"):
    """Extrude a closed XZ polygon (list of (x, z)) along +Y by ``depth`` starting at ``y``."""
    bm = bmesh.new()
    front = [bm.verts.new((p[0], y, p[1])) for p in points_xz]
    back = [bm.verts.new((p[0], y + depth, p[1])) for p in points_xz]
    n = len(points_xz)
    bm.faces.new(list(reversed(front)))
    bm.faces.new(back)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_mesh(name, bm, mat_id, parent, grime)


def collision_box(name, size, loc=(0, 0, 0), parent=None, surface="concrete", rot=(0, 0, 0)):
    """Invisible convex collider (Godot ``-convcolonly`` hint) with a surface tag."""
    obj = box(name + "-convcolonly", size, loc, None, parent, rot, grime="none")
    obj["surface"] = surface
    return obj


def collision_hull(name, obj_or_points, parent=None, surface="concrete"):
    """Invisible convex collider from a point list (ramps, wedges)."""
    bm = bmesh.new()
    for p in obj_or_points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=list(bm.verts))
    obj = _finish_mesh(name + "-convcolonly", bm, None, parent, "none")
    obj["surface"] = surface
    return obj


def paint_grime(obj: bpy.types.Object, mode: str = "height", sway_axis: str = "") -> None:
    """Vertex color ``Col``: R = grime (dirt collects low and in seams), G = wind weight.

    ``height``: R falls off over the first metre above the object's lowest point.
    ``uniform``: constant light grime. ``none``: zero grime (attribute still written). G stays 0 unless ``sway_axis`` names a local axis whose
    normalized extent becomes the sway weight (0 at the anchor, 1 at the free end).
    """
    me = obj.data
    if not me.vertices:
        return
    # Per-vertex (POINT) colours: per-corner values make the glTF exporter split vertices in a
    # run-dependent order, so the output would not be byte-reproducible.
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    zs = [v.co.z for v in me.vertices]
    zmin = min(zs)
    rnd = random.Random(zlib.crc32(obj.name.encode()))  # stable across runs (str hash is salted)
    axis_vals = None
    if sway_axis:
        idx = "xyz".index(sway_axis.lstrip("-"))
        vals = [v.co[idx] for v in me.vertices]
        lo, hi = min(vals), max(vals)
        flip = sway_axis.startswith("-")
        axis_vals = [((hi - x) if flip else (x - lo)) / max(hi - lo, 1e-5) for x in vals]
    for vi, v in enumerate(me.vertices):
        if mode == "none":
            g = 0.0
        else:
            g = max(0.0, 1.0 - (v.co.z - zmin) / 1.0) * 0.8 + 0.1 if mode == "height" else 0.25
            g = min(1.0, max(0.0, g + rnd.uniform(-0.05, 0.05)))
        w = axis_vals[vi] if axis_vals is not None else 0.0
        attr.data[vi].color = (g, w, 0.0, 1.0)


def join(objs: list[bpy.types.Object], name: str) -> bpy.types.Object:
    """Join meshes into the first one (keeps materials and color attributes)."""
    objs = [o for o in objs if o is not None]
    base = objs[0]
    with bpy.context.temp_override(
        active_object=base, selected_editable_objects=objs, selected_objects=objs, object=base
    ):
        bpy.ops.object.join()
    base.name = name
    base.data.name = name
    return base


def join_visuals(name: str, parent=None) -> bpy.types.Object | None:
    """Join every visible (non-collision) mesh directly under ``parent`` into one object: one
    mesh per piece keeps draw calls at one per material."""
    objs = [o for o in bpy.context.scene.objects
            if o.type == "MESH" and "colonly" not in o.name and o.parent == parent]
    if not objs:
        return None
    return join(objs, name)


def export_glb(path: str, animations: bool = False, selection: list | None = None) -> str:
    """Export the scene (or ``selection``) as GLB with modifiers applied and extras on."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Triangulate up front with fixed methods: the exporter's own n-gon triangulation is not
    # run-to-run stable, which would make the GLBs differ byte-wise between identical builds.
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="FIXED", ngon_method="EAR_CLIP")
            bm.to_mesh(o.data)
            bm.free()
    if selection is not None:
        for o in bpy.context.scene.objects:
            o.select_set(o in selection)
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        export_apply=True,
        export_extras=True,
        export_yup=True,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
        export_animations=animations,
        use_selection=selection is not None,
    )
    if animations:
        kwargs.update(export_animation_mode="ACTIONS", export_anim_slide_to_zero=True, export_bake_animation=False,
                      export_optimize_animation_size=False)
    bpy.ops.export_scene.gltf(**kwargs)
    print("[blender] wrote", os.path.relpath(path, REPO_ROOT))
    return path


def tri_count(objs=None) -> int:
    total = 0
    for o in objs or bpy.context.scene.objects:
        if o.type == "MESH" and "colonly" not in o.name:
            for p in o.data.polygons:
                total += len(p.vertices) - 2
    return total


def _euler(rot) -> Matrix:
    from mathutils import Euler

    return Euler(rot, "XYZ").to_matrix().to_4x4()


def rad(deg: float) -> float:
    return math.radians(deg)
