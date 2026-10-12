#!/usr/bin/env python3
"""Build a photo-informed, articulated mantis GLB without Blender.

Axes: X is left/right, Y is up, and the head points toward -Z.
The model is procedural and anatomically inspired, not a photogrammetry scan.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "assets/models/mantis_v7_animated.glb"
PREVIEW_PATH = ROOT / "previews/mantis_v7_model.png"
DETAIL_PATH = ROOT / "previews/mantis_v7_foreleg_detail.png"

MATERIALS = {
    "cuticle": ([0.39, 0.66, 0.22, 1.0], 0.39),
    "cuticle_light": ([0.60, 0.78, 0.34, 1.0], 0.43),
    "cuticle_dark": ([0.21, 0.40, 0.10, 1.0], 0.52),
    "joint": ([0.23, 0.39, 0.10, 1.0], 0.58),
    "wing": ([0.52, 0.73, 0.31, 1.0], 0.56),
    "wing_shadow": ([0.26, 0.47, 0.13, 1.0], 0.60),
    "vein": ([0.22, 0.43, 0.12, 1.0], 0.58),
    "hindwing": ([0.66, 0.77, 0.39, 1.0], 0.62),
    "eye": ([0.27, 0.46, 0.12, 1.0], 0.24),
    "eye_facet": ([0.48, 0.67, 0.23, 1.0], 0.26),
    "face_mark": ([0.24, 0.40, 0.11, 1.0], 0.62),
    "face_light": ([0.72, 0.82, 0.43, 1.0], 0.48),
    "mouth": ([0.25, 0.30, 0.08, 1.0], 0.48),
}


def vec(v):
    return np.asarray(v, dtype=float)


def unit(v):
    n = float(np.linalg.norm(v))
    return vec(v) / n if n > 1e-10 else np.array([0.0, 1.0, 0.0])


class Geometry:
    def __init__(self):
        self.vertices: list[list[float]] = []
        self.faces: list[tuple[int, int, int]] = []

    def add(self, vertices, faces):
        offset = len(self.vertices)
        self.vertices.extend([list(map(float, p)) for p in vertices])
        self.faces.extend(tuple(offset + int(i) for i in f) for f in faces)


def ellipsoid(g: Geometry, center, scale, rings=18, sides=32):
    c, s = vec(center), vec(scale)
    vertices, faces = [], []
    for i in range(rings + 1):
        lat = -math.pi / 2 + math.pi * i / rings
        for j in range(sides):
            lon = 2 * math.pi * j / sides
            vertices.append(c + s * np.array([math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)]))
    for i in range(rings):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c0, d = (i + 1) * sides + j, (i + 1) * sides + (j + 1) % sides
            faces.extend([(a, c0, d), (a, d, b)])
    g.add(vertices, faces)


def tube(g: Geometry, points, radii, sides=10):
    pts = [vec(p) for p in points]
    if len(pts) < 2:
        return
    if isinstance(radii, (int, float)):
        rs = [float(radii)] * len(pts)
    else:
        rs = list(map(float, radii))
    vertices, faces = [], []
    prev_u = None
    for i, p in enumerate(pts):
        tangent = unit(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        ref = np.array([0.0, 0.0, 1.0]) if abs(tangent[2]) < 0.86 else np.array([1.0, 0.0, 0.0])
        u = unit(np.cross(tangent, ref))
        if prev_u is not None and np.dot(u, prev_u) < 0:
            u = -u
        v = unit(np.cross(tangent, u))
        prev_u = u
        for j in range(sides):
            a = 2 * math.pi * j / sides
            vertices.append(p + rs[i] * (math.cos(a) * u + math.sin(a) * v))
    for i in range(len(pts) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.extend([(a, b, b + sides), (a, b + sides, a + sides)])
    g.add(vertices, faces)


def tapered_segment(g: Geometry, length, width, depth, shape="limb", rings=30, sides=24):
    vertices, faces = [], []
    for i in range(rings + 1):
        u = i / rings
        bloom = max(0.04, math.sin(math.pi * u) ** (0.58 if shape == "blade" else 0.72))
        if shape == "blade":
            rx = width * (0.20 + 0.80 * bloom)
            rz = depth * (0.28 + 0.72 * bloom)
        else:
            rx = width * (0.18 + 0.82 * bloom)
            rz = depth * (0.20 + 0.80 * bloom)
        cx = 0.018 * math.sin(math.pi * u)
        cz = 0.008 * math.sin(2 * math.pi * u)
        for j in range(sides):
            a = 2 * math.pi * j / sides
            vertices.append([cx + rx * math.cos(a), length * u, cz + rz * math.sin(a)])
    for i in range(rings):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.extend([(a, b, b + sides), (a, b + sides, a + sides)])
    g.add(vertices, faces)


def tetra_spine(g: Geometry, base, tip, width=0.012):
    b, t = vec(base), vec(tip)
    axis = unit(t - b)
    side = unit(np.cross(axis, np.array([0.0, 0.0, 1.0])))
    if np.linalg.norm(side) < 0.1:
        side = unit(np.cross(axis, np.array([0.0, 1.0, 0.0])))
    depth = unit(np.cross(axis, side)) * width * 0.55
    side *= width
    vertices = [b + side, b - side, b + depth, t]
    g.add(vertices, [(0, 1, 2), (0, 3, 1), (1, 3, 2), (2, 3, 0)])


def rotation_frame(head, tail, x_hint):
    y = unit(vec(tail) - vec(head))
    x = vec(x_hint) - y * float(np.dot(vec(x_hint), y))
    if np.linalg.norm(x) < 1e-7:
        x = np.cross(y, np.array([0.0, 0.0, 1.0]))
    x = unit(x)
    z = unit(np.cross(x, y))
    x = unit(np.cross(y, z))
    return np.column_stack((x, y, z))


def matrix_quaternion(m):
    # Returns glTF's x,y,z,w order.
    tr = float(np.trace(m))
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s,
             (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    return (vec(q) / np.linalg.norm(q)).tolist()


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz]


def axis_angle(axis, angle):
    a = unit(axis)
    s = math.sin(angle / 2)
    return [float(a[0] * s), float(a[1] * s), float(a[2] * s), math.cos(angle / 2)]


class Builder:
    def __init__(self):
        self.nodes = [{"name": "MantisRoot", "children": []}]
        self.parents = [None]
        self.world = [np.eye(4)]
        self.local_matrices = [np.eye(4)]
        self.node_groups: list[dict[str, Geometry]] = [{}]
        self.node_names = {"MantisRoot": 0}
        self.static_groups: dict[str, Geometry] = {}
        self.segments: dict[str, tuple[np.ndarray, np.ndarray, float]] = {}
        self.anim_targets: dict[str, list[tuple[int, str]]] = {}
        self.animation_curves: dict[str, dict[str, dict[str, tuple[np.ndarray, np.ndarray]]]] = {}
        self.spine_rows: dict[int, list[tuple[int, int]]] = {}

    def group(self, mapping, material):
        if material not in mapping:
            mapping[material] = Geometry()
        return mapping[material]

    def static_ellipsoid(self, name, center, scale, material, rings=18, sides=32):
        ellipsoid(self.group(self.static_groups, material), center, scale, rings, sides)

    def static_tube(self, name, points, radii, material, sides=10):
        tube(self.group(self.static_groups, material), points, radii, sides)

    def node_ellipsoid(self, node, center, scale, material, rings=18, sides=32):
        ellipsoid(self.group(self.node_groups[node], material), center, scale, rings, sides)

    def node_tube(self, node, points, radii, material, sides=10):
        tube(self.group(self.node_groups[node], material), points, radii, sides)

    def node(self, name, local_matrix, parent=0):
        idx = len(self.nodes)
        m = np.asarray(local_matrix, dtype=float)
        self.nodes.append({"name": name, "children": [],
                           "translation": m[:3, 3].tolist(),
                           "rotation": matrix_quaternion(m[:3, :3])})
        self.parents.append(parent)
        self.world.append(self.world[parent] @ m)
        self.local_matrices.append(m.copy())
        self.node_groups.append({})
        self.nodes[parent]["children"].append(idx)
        self.node_names[name] = idx
        return idx

    def mesh_node(self, name, parent=0):
        return self.node(name, np.eye(4), parent)

    def segment_node(self, name, head, tail, parent, x_hint, shape, width, depth, material="cuticle"):
        rw = rotation_frame(head, tail, x_hint)
        tw = np.eye(4)
        tw[:3, :3] = rw
        tw[:3, 3] = vec(head)
        local = np.linalg.inv(self.world[parent]) @ tw
        node = self.node(name, local, parent)
        length = float(np.linalg.norm(vec(tail) - vec(head)))
        self.segments[name] = (vec(head), vec(tail), length)
        tapered_segment(self.group(self.node_groups[node], material), length, width, depth, shape)
        self.node_groups[node].setdefault("joint", Geometry())
        ellipsoid(self.node_groups[node]["joint"], [0, 0, 0], [width * 0.52, width * 0.52, depth * 0.58], 12, 20)
        return node, length

    def add_spine_row(self, node, length, width, count, side=1.0, material="cuticle_dark", start=0.12, end=0.90, length_scale=1.0):
        g = self.group(self.node_groups[node], material)
        self.spine_rows.setdefault(node, []).append((int(side), int(count)))
        for i in range(count):
            u = start + (end - start) * (i + 0.5) / count
            bloom = max(0.1, math.sin(math.pi * u) ** 0.55)
            x = side * width * (0.18 + 0.82 * bloom)
            z = 0.0
            tooth = length_scale * (0.018 + 0.025 * math.sin(math.pi * u))
            tilt = 0.012 if i % 2 == 0 else -0.008
            base = [x, length * u, z]
            tip = [x + side * tooth, length * u + tilt, z + (0.008 if i % 2 == 0 else -0.008)]
            tetra_spine(g, base, tip, width=0.007 if count > 10 else 0.009)

    def mesh_for_groups(self, groups, mesh_list, accessors, views, binary):
        primitives = []
        for material, geom in groups.items():
            if not geom.faces:
                continue
            verts = np.asarray(geom.vertices, dtype=np.float32)
            inds = np.asarray(geom.faces, dtype=np.uint32).reshape(-1)
            normals = np.zeros_like(verts)
            for tri in np.asarray(geom.faces, dtype=np.int64):
                a, b, c = verts[tri]
                n = np.cross(b - a, c - a)
                for ix in tri:
                    normals[ix] += n
            norms = np.linalg.norm(normals, axis=1)
            normals = normals / np.maximum(norms[:, None], 1e-9)

            def add_view(data, target):
                while len(binary) % 4:
                    binary.append(0)
                offset = len(binary)
                binary.extend(data)
                view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
                if target:
                    view["target"] = target
                views.append(view)
                return len(views) - 1

            def add_accessor(view, comp, count, typ, minimum=None, maximum=None):
                acc = {"bufferView": view, "componentType": comp, "count": count, "type": typ}
                if minimum is not None:
                    acc["min"] = list(map(float, minimum))
                    acc["max"] = list(map(float, maximum))
                accessors.append(acc)
                return len(accessors) - 1

            pv = add_view(verts.astype("<f4").tobytes(), 34962)
            pa = add_accessor(pv, 5126, len(verts), "VEC3", verts.min(axis=0), verts.max(axis=0))
            nv = add_view(normals.astype("<f4").tobytes(), 34962)
            na = add_accessor(nv, 5126, len(normals), "VEC3")
            phase = verts @ np.array([31.7, 57.1, 83.3], dtype=np.float32)
            fleck = 0.955 + 0.045 * (0.5 + 0.5 * np.sin(phase) * np.sin(phase * 0.37 + 0.9))
            colors = np.column_stack((fleck, fleck * 0.985, fleck * 0.94, np.ones(len(verts), dtype=np.float32))).astype("<f4")
            cv = add_view(colors.tobytes(), 34962)
            ca = add_accessor(cv, 5126, len(colors), "VEC4")
            iv = add_view(inds.astype("<u4").tobytes(), 34963)
            ia = add_accessor(iv, 5125, len(inds), "SCALAR", [int(inds.min())], [int(inds.max())])
            primitives.append({"attributes": {"POSITION": pa, "NORMAL": na, "COLOR_0": ca}, "indices": ia,
                               "material": list(MATERIALS).index(material), "mode": 4})
        if not primitives:
            return None
        mesh_list.append({"name": "MantisMesh", "primitives": primitives})
        return len(mesh_list) - 1

    def finalize(self):
        mesh_list, views, accessors, binary = [], [], [], bytearray()
        for material, geom in self.static_groups.items():
            groups = {material: geom}
            ni = self.mesh_node("Static_" + material)
            mi = self.mesh_for_groups(groups, mesh_list, accessors, views, binary)
            if mi is not None:
                self.nodes[ni]["mesh"] = mi
        for ni, groups in enumerate(self.node_groups):
            if ni == 0 or not groups:
                continue
            mi = self.mesh_for_groups(groups, mesh_list, accessors, views, binary)
            if mi is not None:
                self.nodes[ni]["mesh"] = mi
        animations = self.build_animations(accessors, views, binary)
        while len(binary) % 4:
            binary.append(0)
        materials = []
        for name, (color, rough) in MATERIALS.items():
            materials.append({"name": name, "pbrMetallicRoughness": {"baseColorFactor": color,
                              "metallicFactor": 0.0, "roughnessFactor": rough},
                              "doubleSided": name in ("wing", "hindwing")})
        doc = {"asset": {"version": "2.0", "generator": "LivingTerrarium Mantis Anatomy v7"},
               "scene": 0, "scenes": [{"nodes": [0]}], "nodes": self.nodes, "meshes": mesh_list,
               "materials": materials, "accessors": accessors, "bufferViews": views,
               "buffers": [{"byteLength": len(binary)}], "animations": animations}
        j = json.dumps(doc, separators=(",", ":")).encode("utf8")
        j += b" " * ((4 - len(j) % 4) % 4)
        b = bytes(binary) + b"\x00" * ((4 - len(binary) % 4) % 4)
        total = 12 + 8 + len(j) + 8 + len(b)
        out = struct.pack("<4sII", b"glTF", 2, total)
        out += struct.pack("<I4s", len(j), b"JSON") + j
        out += struct.pack("<I4s", len(b), b"BIN\x00") + b
        MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
        MODEL_PATH.write_bytes(out)
        return doc

    def build_animations(self, accessors, views, binary):
        animations = []
        times = np.linspace(0.0, 1.0, 9, dtype="<f4")
        profiles = {
            "cycle": np.sin(2.0 * math.pi * times),
            "double": np.sin(4.0 * math.pi * times),
            "pulse": np.asarray([0.0, 0.06, 0.20, 0.60, 1.0, 0.78, 0.42, 0.12, 0.0], dtype=np.float32),
            "feed": np.sin(4.0 * math.pi * times),
        }
        clips = {name: {"rotation": {}, "translation": {}, "loop": True}
                 for name in ("IDLE", "WALK", "ALERT", "STRIKE", "GROOM", "FEED")}

        def rotation(clip, node, angle, axis="x", profile="cycle"):
            clips[clip]["rotation"][node] = (angle, axis, profile)

        def translation(clip, node, offset, profile="cycle"):
            clips[clip]["translation"][node] = (np.asarray(offset, dtype=np.float32), profile)

        # Quiet breathing and small balance corrections. Every loop returns to
        # its exact starting transform, so the cycle has no visible snap.
        translation("IDLE", "MantisRoot", (0.0, 0.007, 0.0), "double")
        rotation("IDLE", "Head", 0.012, "x")
        rotation("IDLE", "Abdomen", 0.010, "x")
        for side, sign in (("L", 1), ("R", -1)):
            rotation("IDLE", f"Raptor_{side}_Femur", 0.025 * sign, "z")
            rotation("IDLE", f"Raptor_{side}_Tibia", -0.022 * sign, "z")
            rotation("IDLE", f"Raptor_{side}_Tarsus", 0.012 * sign, "z")
            for label in ("Mid", "Hind"):
                rotation("IDLE", f"Leg_{side}_{label}_Tarsus", 0.008 * sign, "x")

        # Four support legs use an alternating diagonal gait; each coxa, femur,
        # tibia, and foot contributes a small coordinated step.
        translation("WALK", "MantisRoot", (0.0, 0.016, 0.0), "double")
        rotation("WALK", "Head", 0.025, "x")
        rotation("WALK", "Abdomen", 0.020, "x")
        for side, side_sign in (("L", 1), ("R", -1)):
            rotation("WALK", f"Raptor_{side}_Coxa", 0.035 * side_sign, "z")
            rotation("WALK", f"Raptor_{side}_Femur", 0.085 * side_sign, "z")
            rotation("WALK", f"Raptor_{side}_Tibia", -0.065 * side_sign, "z")
            rotation("WALK", f"Raptor_{side}_Tarsus", 0.040 * side_sign, "z")
            for label, phase in (("Mid", side_sign), ("Hind", -side_sign)):
                rotation("WALK", f"Leg_{side}_{label}_Coxa", 0.060 * phase, "x")
                rotation("WALK", f"Leg_{side}_{label}_Femur", 0.220 * phase, "x")
                rotation("WALK", f"Leg_{side}_{label}_Tibia", -0.190 * phase, "x")
                rotation("WALK", f"Leg_{side}_{label}_Tarsus", 0.105 * phase, "x")

        translation("ALERT", "MantisRoot", (0.0, 0.012, 0.0), "double")
        rotation("ALERT", "Head", 0.075, "x")
        rotation("ALERT", "Abdomen", 0.008, "x")
        for side, sign in (("L", 1), ("R", -1)):
            rotation("ALERT", f"Raptor_{side}_Femur", 0.11 * sign, "z")
            rotation("ALERT", f"Raptor_{side}_Tibia", -0.13 * sign, "z")
            for label in ("Mid", "Hind"):
                rotation("ALERT", f"Leg_{side}_{label}_Femur", -0.025 * sign, "x")

        clips["STRIKE"]["loop"] = False
        translation("STRIKE", "MantisRoot", (0.0, 0.0, -0.065), "pulse")
        translation("STRIKE", "Head", (0.0, 0.0, -0.028), "pulse")
        rotation("STRIKE", "Abdomen", 0.018, "x", "pulse")
        for side, sign in (("L", 1), ("R", -1)):
            rotation("STRIKE", f"Raptor_{side}_Coxa", 0.045 * sign, "x", "pulse")
            rotation("STRIKE", f"Raptor_{side}_Femur", -0.12 * sign, "z", "pulse")
            rotation("STRIKE", f"Raptor_{side}_Tibia", 0.34 * sign, "z", "pulse")
            rotation("STRIKE", f"Raptor_{side}_Tarsus", -0.09 * sign, "z", "pulse")
            for label in ("Mid", "Hind"):
                rotation("STRIKE", f"Leg_{side}_{label}_Femur", 0.055 * sign, "x", "pulse")
                rotation("STRIKE", f"Leg_{side}_{label}_Tibia", -0.065 * sign, "x", "pulse")

        translation("GROOM", "MantisRoot", (0.0, 0.004, 0.0), "double")
        rotation("GROOM", "Head", -0.045, "x")
        rotation("GROOM", "Abdomen", 0.008, "x")
        rotation("GROOM", "Raptor_L_Coxa", 0.035, "x")
        rotation("GROOM", "Raptor_L_Femur", -0.21, "x")
        rotation("GROOM", "Raptor_L_Tibia", -0.17, "z")
        rotation("GROOM", "Raptor_L_Tarsus", 0.09, "z")

        rotation("FEED", "Head", 0.035, "x", "feed")
        rotation("FEED", "Abdomen", 0.012, "x", "feed")
        for side, sign in (("L", 1), ("R", -1)):
            rotation("FEED", f"Raptor_{side}_Femur", 0.035 * sign, "z", "feed")
            rotation("FEED", f"Raptor_{side}_Tibia", -0.075 * sign, "z", "feed")
            rotation("FEED", f"Raptor_{side}_Tarsus", 0.032 * sign, "z", "feed")

        self.animation_curves = {}
        for clip_name, spec in clips.items():
            samplers, channels = [], []
            curves = {}
            for node_name, (amplitude, axis_name, profile) in spec["rotation"].items():
                if node_name not in self.node_names:
                    continue
                ni = self.node_names[node_name]
                base = self.nodes[ni]["rotation"]
                axis = {"x": [1, 0, 0], "z": [0, 0, 1]}[axis_name]
                values = np.asarray([qmul(base, axis_angle(axis, amplitude * float(f)))
                                     for f in profiles[profile]], dtype="<f4")
                ti = self.add_animation_accessor(times, "SCALAR", accessors, views, binary, 1)
                oi = self.add_animation_accessor(values, "VEC4", accessors, views, binary, 1)
                samplers.append({"input": ti, "output": oi, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": ni, "path": "rotation"}})
                curves.setdefault(node_name, {})["rotation"] = (times.copy(), values.copy())
            for node_name, (offset, profile) in spec["translation"].items():
                if node_name not in self.node_names:
                    continue
                ni = self.node_names[node_name]
                base = np.asarray(self.nodes[ni].get("translation", [0.0, 0.0, 0.0]), dtype=np.float32)
                values = np.asarray([base + offset * float(f) for f in profiles[profile]], dtype="<f4")
                ti = self.add_animation_accessor(times, "SCALAR", accessors, views, binary, 1)
                oi = self.add_animation_accessor(values, "VEC3", accessors, views, binary, 1)
                samplers.append({"input": ti, "output": oi, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": ni, "path": "translation"}})
                curves.setdefault(node_name, {})["translation"] = (times.copy(), values.copy())
            self.animation_curves[clip_name] = curves
            animations.append({"name": clip_name, "samplers": samplers, "channels": channels,
                               "extras": {"loop": spec["loop"]}})
        return animations

    @staticmethod
    def add_animation_accessor(array, typ, accessors, views, binary, target):
        while len(binary) % 4:
            binary.append(0)
        data = np.asarray(array, dtype="<f4").tobytes()
        views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)})
        binary.extend(data)
        accessor = {"bufferView": len(views) - 1, "componentType": 5126,
                    "count": len(array), "type": typ}
        if typ == "SCALAR":
            accessor["min"] = [float(np.min(array))]
            accessor["max"] = [float(np.max(array))]
        accessors.append(accessor)
        return len(accessors) - 1


def leaf_mesh(g, side, y, z0, length, width):
    vertices, faces = [], []
    stations, across = 38, 12
    for i in range(stations + 1):
        u = i / stations
        z = z0 + length * u
        w = width * (0.035 + 0.965 * math.sin(math.pi * u) ** 0.78)
        cx = side * (0.012 + 0.07 * u)
        for j in range(across + 1):
            v = -1 + 2 * j / across
            x = cx + side * w * v
            dome = 0.025 * (1 - v * v) * math.sin(math.pi * u) ** 0.65
            vertices.append([x, y + dome, z])
    for i in range(stations):
        for j in range(across):
            a = i * (across + 1) + j
            b = a + 1
            c = a + across + 1
            d = c + 1
            if side > 0:
                faces.extend([(a, c, d), (a, d, b)])
            else:
                faces.extend([(a, d, c), (a, b, d)])
    g.add(vertices, faces)


def thorax_loft(g, stations, sides=40):
    """Continuous cross-section shell, broader at the wing and leg bases."""
    vertices, faces = [], []
    for z, cy, rx, ry in stations:
        for j in range(sides):
            a = 2 * math.pi * j / sides
            vertices.append([rx * math.cos(a), cy + ry * math.sin(a), z])
    for i in range(len(stations) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = (i + 1) * sides + j
            d = (i + 1) * sides + (j + 1) % sides
            faces.extend([(a, b, d), (a, d, c)])
    faces.append(tuple(range(sides - 1, -1, -1)))
    faces.append(tuple((len(stations) - 1) * sides + j for j in range(sides)))
    # Fan-triangulate the two end caps for glTF triangle lists.
    caps = faces[-2:]
    faces = faces[:-2]
    for cap in caps:
        for i in range(1, len(cap) - 1):
            faces.append((cap[0], cap[i], cap[i + 1]))
    g.add(vertices, faces)


def build_model():
    b = Builder()

    # Large, separate abdomen behind the thorax. It is deliberately longer
    # and fuller than the thorax; curved seams define nine broad segments.
    abdomen_node = b.mesh_node("Abdomen")
    abdomen_stations = [(-0.02, 0.91, 0.18, 0.12), (0.14, 0.89, 0.29, 0.20),
                        (0.34, 0.87, 0.38, 0.27), (0.58, 0.85, 0.43, 0.30),
                        (0.84, 0.83, 0.44, 0.30), (1.10, 0.81, 0.42, 0.28),
                        (1.36, 0.80, 0.38, 0.25), (1.61, 0.80, 0.32, 0.21),
                        (1.82, 0.80, 0.23, 0.15), (1.98, 0.80, 0.045, 0.045)]
    abdomen_shell = b.group(b.node_groups[abdomen_node], "cuticle")
    thorax_loft(abdomen_shell, abdomen_stations, sides=48)
    seam_group = b.group(b.node_groups[abdomen_node], "cuticle_dark")
    for i in range(1, 9):
        z = -0.02 + i * 0.20
        cy = float(np.interp(z, [s[0] for s in abdomen_stations], [s[1] for s in abdomen_stations]))
        rx = float(np.interp(z, [s[0] for s in abdomen_stations], [s[2] for s in abdomen_stations]))
        ry = float(np.interp(z, [s[0] for s in abdomen_stations], [s[3] for s in abdomen_stations]))
        seam = [(rx * math.cos(2 * math.pi * j / 28), cy + ry * math.sin(2 * math.pi * j / 28), z)
                for j in range(29)]
        tube(seam_group, seam, [0.0035] * len(seam), 7)
    b.node_tube(abdomen_node, [(-0.06, 0.80, 1.91), (-0.10, 0.78, 2.10), (-0.14, 0.76, 2.22)], [0.007, 0.004, 0.0008], "cuticle_dark", 7)
    b.node_tube(abdomen_node, [(0.06, 0.80, 1.91), (0.10, 0.78, 2.10), (0.14, 0.76, 2.22)], [0.007, 0.004, 0.0008], "cuticle_dark", 7)

    # The prothorax is a long, flattened pronotum. Behind it sits the shorter,
    # leg-bearing thorax, with shallow side plates rather than round bulges.
    pronotum_node = b.mesh_node("Pronotum")
    pronotum = b.group(b.node_groups[pronotum_node], "cuticle_light")
    thorax_loft(pronotum, [(-0.90, 1.205, 0.105, 0.080), (-0.72, 1.19, 0.135, 0.100),
                           (-0.43, 1.15, 0.165, 0.120), (-0.20, 1.10, 0.19, 0.135),
                           (0.01, 1.045, 0.23, 0.155)], sides=48)
    b.node_tube(pronotum_node, [(0, 1.285, -0.82), (0, 1.282, -0.52),
                                (0, 1.235, -0.20), (0, 1.205, 0.0)],
                [0.012, 0.015, 0.012, 0.008], "cuticle", 10)
    for side in (-1, 1):
        b.node_tube(pronotum_node, [(side * 0.065, 1.272, -0.79), (side * 0.09, 1.245, -0.49),
                                    (side * 0.12, 1.205, -0.16)],
                    [0.005, 0.007, 0.004], "cuticle_dark", 7)

    thorax_node = b.mesh_node("Thorax")
    thorax = b.group(b.node_groups[thorax_node], "cuticle_light")
    thorax_loft(thorax, [(-0.10, 1.035, 0.23, 0.15), (0.04, 0.995, 0.27, 0.18),
                         (0.20, 0.955, 0.29, 0.19), (0.36, 0.925, 0.255, 0.17),
                         (0.47, 0.91, 0.18, 0.12)], sides=48)
    # Shallow side sclerites define the shoulder and wing bases without making
    # the thorax look like a stack of round beads.
    for side in (-1, 1):
        b.node_ellipsoid(thorax_node, (side * 0.205, 0.955, 0.10),
                         (0.075, 0.105, 0.15), "cuticle", 16, 28)
        b.node_ellipsoid(thorax_node, (side * 0.185, 0.925, 0.32),
                         (0.065, 0.085, 0.105), "cuticle_light", 14, 24)
        b.node_ellipsoid(thorax_node, (side * 0.205, 1.02, -0.04),
                         (0.052, 0.058, 0.060), "joint", 12, 20)
    b.node_tube(thorax_node, [(0, 1.13, -0.06), (0, 1.145, 0.12),
                              (0, 1.11, 0.32)], [0.009, 0.012, 0.006], "cuticle", 8)

    # Broad triangular mantis head with laterally placed compound eyes.
    head_node = b.mesh_node("Head")
    head = b.group(b.node_groups[head_node], "cuticle_light")
    thorax_loft(head, [(-1.005, 1.205, 0.090, 0.065), (-0.925, 1.245, 0.155, 0.115),
                       (-0.785, 1.315, 0.255, 0.175), (-0.625, 1.325, 0.22, 0.155)], sides=48)
    # A shallow pentagonal clypeal shield and paired facial sutures give the
    # head the characteristic patterned face, rather than a blank green mask.
    shield = b.group(b.node_groups[head_node], "face_light")
    outline = [(-0.077, 1.294, -1.074), (0.077, 1.294, -1.074),
               (0.067, 1.254, -1.078), (0.0, 1.218, -1.082),
               (-0.067, 1.254, -1.078)]
    center = (0.0, 1.263, -1.084)
    shield.add([center] + outline, [(0, i + 1, (i + 1) % len(outline) + 1)
                                    for i in range(len(outline))])
    markings = b.group(b.node_groups[head_node], "face_mark")
    # Central facial seam, paired cheek grooves, and small paired ocellar marks.
    b.node_tube(head_node, [(0.0, 1.291, -1.087), (0.0, 1.270, -1.091),
                            (0.0, 1.235, -1.089)], [0.0055, 0.0040, 0.0018], "face_mark", 7)
    for side in (-1, 1):
        b.node_tube(head_node, [(side * 0.059, 1.284, -1.087),
                               (side * 0.051, 1.258, -1.090),
                               (side * 0.030, 1.235, -1.090)],
                    [0.0038, 0.0032, 0.0012], "face_mark", 7)
        b.node_ellipsoid(head_node, (side * 0.039, 1.278, -1.092),
                         (0.008, 0.006, 0.0035), "face_mark", 10, 16)
        b.node_tube(head_node, [(side * 0.071, 1.288, -1.078),
                               (side * 0.065, 1.263, -1.083)],
                    [0.0035, 0.0012], "face_light", 7)
    b.node_ellipsoid(head_node, (0, 1.195, -0.987), (0.095, 0.052, 0.035), "cuticle", 14, 24)
    for side in (-1, 1):
        b.node_tube(head_node, [(side * 0.045, 1.18, -0.985),
                                (side * 0.028, 1.145, -1.028), (0, 1.16, -1.02)],
                    [0.010, 0.005, 0.0015], "mouth", 8)
        b.node_ellipsoid(head_node, (side * 0.229, 1.365, -0.755),
                         (0.108, 0.112, 0.103), "eye", 20, 32)
        # Small, subtle ommatidia follow the curved outer surface instead of
        # forming a ring of isolated bumps around a black eye socket.
        for iy in range(-3, 4):
            for iz in range(-3, 4):
                dy, dz = iy * 0.026, iz * 0.024
                rr = (dy / 0.108) ** 2 + (dz / 0.098) ** 2
                if rr > 0.86:
                    continue
                x = side * (0.229 + 0.108 * math.sqrt(max(0.02, 1.0 - rr)) + 0.002)
                b.node_ellipsoid(head_node, (x, 1.365 + dy, -0.755 + dz),
                                 (0.0045, 0.0055, 0.0055), "eye_facet", 6, 8)
        # Fine antennae rise from the inner corners of the eyes.
        pts = []
        for j in range(26):
            t = j / 25
            pts.append((side * (0.055 + 0.12 * t + 0.055 * math.sin(math.pi * t)),
                        1.43 + 0.72 * t + 0.06 * math.sin(math.pi * t),
                        -0.91 - 0.10 * t))
        b.node_tube(head_node, pts, np.linspace(0.0055, 0.001, len(pts)), "cuticle_dark", 7)

    # Full-length overlapping wing covers; their broad leaf blades span the
    # enlarged abdomen instead of stopping halfway along it.
    for side in (-1, 1):
        letter = "L" if side < 0 else "R"
        wing_node = b.mesh_node("Wing_" + letter)
        g = b.group(b.node_groups[wing_node], "wing")
        leaf_mesh(g, side, 1.18, -0.08, 2.20, 0.445)
        centerline = []
        for j in range(24):
            t = j / 23
            centerline.append((side * (0.018 + 0.11 * t), 1.205 + 0.030 * math.sin(math.pi * t), -0.08 + 2.20 * t))
        b.node_tube(wing_node, centerline, np.linspace(0.010, 0.0035, len(centerline)), "vein", 8)
        for k in range(1, 17):
            u = k / 18
            z = -0.08 + 2.20 * u
            cx = side * (0.018 + 0.11 * u)
            w = 0.445 * (0.035 + 0.965 * math.sin(math.pi * u) ** 0.78)
            splay = 1 if k % 2 == 0 else -1
            pts = [(cx, 1.225, z),
                   (cx + side * w * 0.52, 1.210 + 0.016 * splay, z + 0.050 * splay),
                   (cx + side * w * 0.96, 1.185, z + 0.10 * splay)]
            b.node_tube(wing_node, pts, [0.0038, 0.0030, 0.0017], "vein", 6)
        # Folded pale hindwing fan peeks out along the outer margin.
        hg = b.group(b.node_groups[wing_node], "hindwing")
        leaf_mesh(hg, side, 1.135, 0.04, 1.98, 0.335)
        for k in range(10):
            t = (k + 1) / 12
            z = 0.04 + 1.98 * t
            cx = side * (0.04 + 0.08 * t)
            w = 0.335 * math.sin(math.pi * t) ** 0.78
            b.node_tube(wing_node, [(cx, 1.16, z), (cx + side * w * 0.6, 1.145, z + 0.04), (cx + side * w, 1.13, z + 0.08)], [0.0032, 0.0025, 0.0011], "wing_shadow", 6)

    # Paired raptorial forelegs. Both sides use the same head-forward V pose.
    raptor_nodes = {}
    for side, letter in [(-1, "L"), (1, "R")]:
        # Stagger the far and near clamps slightly in depth so both long
        # femur-tibia pairs stay legible from the app's common side camera.
        depth_shift = 0.0 if side > 0 else 0.16
        # Lengthen both proximal foreleg segments while keeping the feet above
        # the floor and preserving the characteristic folded knee silhouette.
        shoulder = vec((side * 0.16, 1.16, -0.16 + depth_shift))
        # Three unmistakable directions: coxa drops from the chest, the broad
        # femur rises forward to the knee, and the spined tibia folds down/back.
        coxa_tip = vec((side * 0.331, 0.684, -0.319 + depth_shift))
        old_tip = vec((side * 0.281, 0.709, -0.314 + depth_shift))
        old_knee = vec((side * 0.451, 1.389 if side > 0 else 1.439, -1.044 + depth_shift))
        knee = coxa_tip + (old_knee - old_tip) * 1.020
        # This long lower blade is the longest raptorial segment and reaches
        # nearly to the ground after the femur folds up to the knee.
        tibia_tip = vec((side * 0.361 + knee[0] - old_knee[0], 0.039 if side > 0 else 0.089,
                         -0.694 + depth_shift + knee[2] - old_knee[2]))
        tarsus_tip = vec((side * 0.351 + knee[0] - old_knee[0], -0.006 if side > 0 else 0.044,
                          -0.564 + depth_shift + knee[2] - old_knee[2]))
        shoulder_node = b.mesh_node("Raptor_" + letter + "_Shoulder")
        b.static_ellipsoid("CoxaSocket", shoulder, (0.055, 0.058, 0.064), "joint", 14, 24)
        coxa, coxa_len = b.segment_node("Raptor_" + letter + "_Coxa", shoulder, coxa_tip, shoulder_node,
                                        (side, 0.3, 0.3), "limb", 0.040, 0.037, "cuticle")
        b.static_ellipsoid("CoxaArticulation", coxa_tip, (0.032, 0.031, 0.033), "joint", 12, 20)
        femur, femur_len = b.segment_node("Raptor_" + letter + "_Femur", coxa_tip, knee, coxa,
                                          (side, 0, 0), "blade", 0.14, 0.082, "cuticle_light")
        b.add_spine_row(femur, femur_len, 0.14, 18, side=-1, material="cuticle_dark", start=0.16, end=0.94, length_scale=1.35)
        # Femoral inner groove and two raised outer ridges.
        for zoff, mat_name in [(0.014, "cuticle_dark"), (-0.014, "cuticle")]:
            pts = []
            for j in range(16):
                u = 0.12 + 0.78 * j / 15
                bloom = max(0.1, math.sin(math.pi * u) ** 0.58)
                pts.append((-0.13 * (0.20 + 0.80 * bloom) * 0.72, femur_len * u, zoff * bloom))
            tube(b.group(b.node_groups[femur], mat_name), pts, np.linspace(0.0035, 0.002, len(pts)), 6)
        tibia, tibia_len = b.segment_node("Raptor_" + letter + "_Tibia", knee, tibia_tip, femur,
                                         (side, 0, 0), "limb", 0.064, 0.048, "cuticle")
        b.add_spine_row(tibia, tibia_len, 0.060, 26, side=-1, material="cuticle_dark", start=0.05, end=0.97, length_scale=1.65)
        tarsus, tarsus_len = b.segment_node("Raptor_" + letter + "_Tarsus", tibia_tip, tarsus_tip, tibia,
                                            (side, 0, 0), "limb", 0.010, 0.009, "joint")
        tg = b.group(b.node_groups[tarsus], "cuticle_dark")
        for j in range(2):
            y = tarsus_len * (0.55 + j * 0.18)
            tube(tg, [(0, y, 0), (side * 0.008, y + 0.035, -0.007), (side * 0.015, y + 0.065, -0.020)], [0.006, 0.003, 0.0007], 7)
        raptor_nodes[letter] = {"coxa": coxa, "femur": femur, "tibia": tibia, "tarsus": tarsus}

    # Four long support legs emerge from the rear half of the thorax. Their
    # outward coxae, bent femora, long shanks, and fine feet stay readable
    # beside the enlarged abdomen.
    for side, letter in [(-1, "L"), (1, "R")]:
        for label, hip_z, knee_z, ankle_z, toe_z in [
            ("Mid", -0.05, -0.22, -0.58, -0.88),
            ("Hind", 0.42, 0.68, 1.07, 1.36),
        ]:
            hip = vec((side * 0.23, 0.88, hip_z))
            coxa_end = vec((side * 0.46, 0.81, hip_z + 0.10))
            knee_w = vec((side * 0.72, 0.53, knee_z))
            ankle = vec((side * 0.90, 0.04, ankle_z))
            toe = vec((side * 1.02, 0.02, toe_z))
            root = b.mesh_node("Leg_" + letter + "_" + label + "_Root")
            coxa_n, _ = b.segment_node("Leg_" + letter + "_" + label + "_Coxa", hip, coxa_end, root,
                                        (side, 0, 0), "limb", 0.045, 0.038, "cuticle")
            fem_n, fem_len = b.segment_node("Leg_" + letter + "_" + label + "_Femur", coxa_end, knee_w, coxa_n,
                                             (side, 0.2, 0.2), "limb", 0.047, 0.036, "cuticle_light")
            tib_n, tib_len = b.segment_node("Leg_" + letter + "_" + label + "_Tibia", knee_w, ankle, fem_n,
                                             (side, 0, 0), "limb", 0.025, 0.022, "cuticle")
            b.add_spine_row(tib_n, tib_len, 0.022, 8, side=1, material="cuticle_dark", start=0.22, end=0.86, length_scale=0.48)
            tar_n, tar_len = b.segment_node("Leg_" + letter + "_" + label + "_Tarsus", ankle, toe, tib_n,
                                             (side, 0, 0), "limb", 0.012, 0.009, "joint")
            for j in range(4):
                y = tar_len * (j + 1) / 5
                tg = b.group(b.node_groups[tar_n], "cuticle_light")
                tube(tg, [(0, y, 0), (0, y + tar_len * 0.18, -0.004)], [0.0035, 0.002], 6)
            tg = b.group(b.node_groups[tar_n], "cuticle_dark")
            for claw_side in (-1, 1):
                tube(tg, [(0, tar_len * 0.9, 0), (claw_side * 0.010, tar_len * 1.08, -0.006),
                          (claw_side * 0.015, tar_len * 1.14, -0.018)], [0.004, 0.002, 0.0005], 7)

    return b



if __name__ == "__main__":
    model = build_model()
    doc = model.finalize()
    from render_mantis_previews import render_previews
    render_previews(model)
    print(f"Wrote {MODEL_PATH} ({MODEL_PATH.stat().st_size:,} bytes)")
    print(f"Wrote {PREVIEW_PATH} ({PREVIEW_PATH.stat().st_size:,} bytes)")
    print(f"Wrote {DETAIL_PATH} ({DETAIL_PATH.stat().st_size:,} bytes)")
    print(f"Parts: {len(doc['nodes'])} nodes, {len(doc['meshes'])} meshes, {len(doc['animations'])} animations")
