#!/usr/bin/env python3
"""Add photo-guided eye and wing anatomy to the v8.3 canonical mantis GLB.

This is a non-destructive GLB extension: it refuses any source other than the
approved v8.3 canonical asset, appends two skinned detail meshes, and leaves the
original mesh, skin, hierarchy, and animation data intact.
"""
from __future__ import annotations

import hashlib
import json
import math
import subprocess
import struct
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets/models/mantis_latest.glb"
SOURCE_COMMIT = "1bdf2ee81eb73e6c390442a5a87c7477d5d336f1"
SOURCE_PATH = "assets/models/mantis_latest.glb"
SOURCE_BLOB_SHA1 = "4536831ef5925acd706a9f607f30d31043e4173c"

Vec = tuple[float, float, float]


def add(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a: Vec, s: float) -> Vec:
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a: Vec, b: Vec) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a: Vec, b: Vec) -> Vec:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(v: Vec) -> Vec:
    length = math.sqrt(dot(v, v))
    return mul(v, 1.0 / length) if length > 1e-12 else (0.0, 1.0, 0.0)


def glb_blob_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def parse_glb(data: bytes) -> tuple[dict, bytes]:
    if data[:4] != b"glTF" or struct.unpack_from("<I", data, 8)[0] != len(data):
        raise ValueError("Invalid GLB header")
    offset = 12
    document = None
    binary = None
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + length]
        offset += length
        if kind == 0x4E4F534A:
            document = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            binary = chunk
    if document is None or binary is None:
        raise ValueError("GLB must contain JSON and BIN chunks")
    return document, binary


def accessor_values(document: dict, binary: bytes, index: int) -> list[tuple]:
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    formats = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
    fmt = formats[accessor["componentType"]]
    element_size = struct.calcsize("<" + fmt * components)
    stride = view.get("byteStride", element_size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * components, binary, start + i * stride)
            for i in range(accessor["count"])]


class GLBAppender:
    def __init__(self, document: dict, binary: bytes):
        self.document = document
        self.binary = bytearray(binary)

    def append_accessor(self, payload: bytes, component_type: int, kind: str,
                        count: int, target: int, *, minimum=None, maximum=None) -> int:
        while len(self.binary) % 4:
            self.binary.append(0)
        offset = len(self.binary)
        self.binary.extend(payload)
        view_index = len(self.document["bufferViews"])
        self.document["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                             "byteLength": len(payload), "target": target})
        accessor = {"bufferView": view_index, "componentType": component_type,
                    "count": count, "type": kind}
        if minimum is not None:
            accessor["min"] = list(minimum)
        if maximum is not None:
            accessor["max"] = list(maximum)
        accessor_index = len(self.document["accessors"])
        self.document["accessors"].append(accessor)
        return accessor_index

    def append_mesh(self, name: str, positions: list[Vec], normals: list[Vec],
                    joint_index: int, material_index: int,
                    triangles: list[tuple[int, int, int]]) -> None:
        if not positions or len(positions) != len(normals):
            raise ValueError(f"Invalid geometry for {name}")
        flat_pos = [v for p in positions for v in p]
        flat_nrm = [v for p in normals for v in p]
        pos_data = struct.pack("<" + "f" * len(flat_pos), *flat_pos)
        nrm_data = struct.pack("<" + "f" * len(flat_nrm), *flat_nrm)
        joint_data = bytes(value for _ in positions for value in (joint_index, 0, 0, 0))
        weight_data = struct.pack("<" + "f" * (4 * len(positions)),
                                  *(value for _ in positions for value in (1.0, 0.0, 0.0, 0.0)))
        index_values = [v for tri in triangles for v in tri]
        index_data = struct.pack("<" + "H" * len(index_values), *index_values)
        pmin = tuple(min(p[i] for p in positions) for i in range(3))
        pmax = tuple(max(p[i] for p in positions) for i in range(3))
        p_acc = self.append_accessor(pos_data, 5126, "VEC3", len(positions), 34962,
                                     minimum=pmin, maximum=pmax)
        n_acc = self.append_accessor(nrm_data, 5126, "VEC3", len(normals), 34962)
        j_acc = self.append_accessor(joint_data, 5121, "VEC4", len(positions), 34962)
        w_acc = self.append_accessor(weight_data, 5126, "VEC4", len(positions), 34962)
        i_acc = self.append_accessor(index_data, 5123, "SCALAR", len(index_values), 34963,
                                     minimum=(min(index_values),), maximum=(max(index_values),))
        mesh_index = len(self.document["meshes"])
        self.document["meshes"].append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": p_acc, "NORMAL": n_acc,
                                             "JOINTS_0": j_acc, "WEIGHTS_0": w_acc},
                            "indices": i_acc, "material": material_index, "mode": 4}],
        })
        node_index = len(self.document["nodes"])
        self.document["nodes"].append({"name": name, "mesh": mesh_index, "skin": 0})
        self.document["nodes"][self.root_node].setdefault("children", []).append(node_index)

    @property
    def root_node(self) -> int:
        return next(i for i, node in enumerate(self.document["nodes"])
                    if node.get("name") == "MantisRig")

    def finish(self, output: Path) -> None:
        self.document["buffers"][0]["byteLength"] = len(self.binary)
        encoded = json.dumps(self.document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        encoded += b" " * ((4 - len(encoded) % 4) % 4)
        binary = bytes(self.binary)
        chunks = (struct.pack("<II", len(encoded), 0x4E4F534A) + encoded +
                  struct.pack("<II", len(binary), 0x004E4942) + binary)
        output.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks)


def add_ommatidia(appender: GLBAppender, document: dict, binary: bytes,
                  material_index: int) -> int:
    added = 0
    for side_name, sign in (("L", -1.0), ("R", 1.0)):
        eye_node = next(n for n in document["nodes"] if n.get("name") == f"Eye_Compound_{side_name}")
        primitive = document["meshes"][eye_node["mesh"]]["primitives"][0]
        positions = accessor_values(document, binary, primitive["attributes"]["POSITION"])
        lo = [min(p[i] for p in positions) for i in range(3)]
        hi = [max(p[i] for p in positions) for i in range(3)]
        center = tuple((lo[i] + hi[i]) * 0.5 for i in range(3))
        radii = tuple((hi[i] - lo[i]) * 0.5 for i in range(3))
        old_centers = []
        for node in document["nodes"]:
            if node.get("name", "").startswith(f"Eye_Facet_{side_name}_"):
                prim = document["meshes"][node["mesh"]]["primitives"][0]
                verts = accessor_values(document, binary, prim["attributes"]["POSITION"])
                old_centers.append(tuple(sum(v[i] for v in verts) / len(verts) for i in range(3)))
        vertices: list[Vec] = []
        normals: list[Vec] = []
        triangles: list[tuple[int, int, int]] = []
        # Existing macro facets stay intact; this fine hexagonal grid fills the
        # gaps on the outward eye surface seen in the user's close-up references.
        y_steps, z_steps = 11, 15
        for row in range(y_steps):
            y = center[1] - radii[1] * 0.84 + row * (radii[1] * 1.68 / (y_steps - 1))
            for col in range(z_steps):
                z_fraction = (col + (0.5 if row % 2 else 0)) / (z_steps - 1)
                z = center[2] - radii[2] * 0.84 + z_fraction * (radii[2] * 1.68)
                dy = (y - center[1]) / radii[1]
                dz = (z - center[2]) / radii[2]
                remaining = 1.0 - dy * dy - dz * dz
                if remaining < 0.18:
                    continue
                x = center[0] + sign * (radii[0] * math.sqrt(remaining) + 0.00055)
                if any(math.hypot(y - old[1], z - old[2]) < 0.009 for old in old_centers):
                    continue
                surface = (x, y, z)
                normal = norm(((x - center[0]) / (radii[0] ** 2),
                               (y - center[1]) / (radii[1] ** 2),
                               (z - center[2]) / (radii[2] ** 2)))
                tangent_u = norm(sub((0.0, 0.0, 1.0), mul(normal, normal[2])))
                tangent_v = norm(cross(normal, tangent_u))
                base = len(vertices)
                # Each added lens fills the spaces between the existing coarse
                # facets and has enough relief to remain readable at game scale.
                radius = 0.0055
                vertices.append(add(surface, mul(normal, 0.0028)))
                normals.append(normal)
                for k in range(6):
                    angle = math.tau * k / 6.0
                    offset = add(mul(tangent_u, radius * math.cos(angle)),
                                 mul(tangent_v, radius * math.sin(angle)))
                    vertices.append(add(add(surface, offset), mul(normal, 0.00075)))
                    normals.append(normal)
                for k in range(6):
                    triangles.append((base, base + 1 + k, base + 1 + ((k + 1) % 6)))
                added += 1
        if vertices:
            head_joint = document["skins"][0]["joints"].index(
                next(i for i, n in enumerate(document["nodes"]) if n.get("name") == "Rig_Head"))
            appender.append_mesh(f"PhotoEyeFacet_{side_name}", vertices, normals,
                                 head_joint, material_index, triangles)
    return added


def closest_on_triangle(p: Vec, a: Vec, b: Vec, c: Vec) -> Vec:
    ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
    d1, d2 = dot(ab, ap), dot(ac, ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return a
    bp = sub(p, b); d3, d4 = dot(ab, bp), dot(ac, bp)
    if d3 >= 0.0 and d4 <= d3:
        return b
    vc = d1 * d4 - d3 * d2
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
        return add(a, mul(ab, d1 / (d1 - d3)))
    cp = sub(p, c); d5, d6 = dot(ab, cp), dot(ac, cp)
    if d6 >= 0.0 and d5 <= d6:
        return c
    vb = d5 * d2 - d1 * d6
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
        return add(a, mul(ac, d2 / (d2 - d6)))
    va = d3 * d6 - d5 * d4
    if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
        return add(b, mul(sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6))))
    denom = 1.0 / (va + vb + vc)
    v, w = vb * denom, vc * denom
    return add(a, add(mul(ab, v), mul(ac, w)))


def make_tube(points: list[Vec], surface_normals: list[Vec], radius: float,
              sides: int = 5) -> tuple[list[Vec], list[Vec], list[tuple[int, int, int]]]:
    vertices: list[Vec] = []
    normals: list[Vec] = []
    faces: list[tuple[int, int, int]] = []
    for i, point in enumerate(points):
        tangent = norm(sub(points[min(i + 1, len(points) - 1)], points[max(i - 1, 0)]))
        normal = surface_normals[i]
        u = norm(cross(tangent, normal))
        v = norm(cross(tangent, u))
        taper = 0.45 + 0.55 * min(1.0, (i + 1) / 3.0, (len(points) - i) / 3.0)
        for k in range(sides):
            angle = math.tau * k / sides
            radial = norm(add(mul(u, math.cos(angle)), mul(v, math.sin(angle))))
            vertices.append(add(point, mul(radial, radius * taper)))
            normals.append(radial)
    for i in range(len(points) - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + (k + 1) % sides
            d = (i + 1) * sides + k
            faces.extend(((a, b, c), (a, c, d)))
    return vertices, normals, faces


def wing_crossvein_mesh(appender: GLBAppender, document: dict, binary: bytes,
                        side_name: str, side_sign: float, material_index: int) -> int:
    wing_node = next(n for n in document["nodes"] if n.get("name") == f"Wing_Tegmen_{side_name}")
    primitive = document["meshes"][wing_node["mesh"]]["primitives"][0]
    p_index = primitive["attributes"]["POSITION"]
    positions = [tuple(float(x) for x in p) for p in accessor_values(document, binary, p_index)]
    indices = accessor_values(document, binary, primitive["indices"])
    flat_indices = [int(i[0]) for i in indices]
    triangles = [(positions[flat_indices[i]], positions[flat_indices[i + 1]], positions[flat_indices[i + 2]])
                 for i in range(0, len(flat_indices), 3)]
    existing_z = []
    for node in document["nodes"]:
        name = node.get("name", "")
        if name.startswith(f"WingVeinDetail_{side_name}_cross_"):
            prim = document["meshes"][node["mesh"]]["primitives"][0]
            vals = accessor_values(document, binary, prim["attributes"]["POSITION"])
            existing_z.append(sum(p[2] for p in vals) / len(vals))
    zmin, zmax = min(p[2] for p in positions), max(p[2] for p in positions)
    # Add fine cross veins only in the spaces between the original primary ribs.
    z_candidates = [zmin + (zmax - zmin) * (i + 0.5) / 22 for i in range(21)]
    z_candidates = [z for z in z_candidates if min(abs(z - old) for old in existing_z) > 0.011]
    all_vertices: list[Vec] = []
    all_normals: list[Vec] = []
    all_faces: list[tuple[int, int, int]] = []
    added_rows = 0
    for row_index, z in enumerate(z_candidates):
        near = [p for p in positions if abs(p[2] - z) < 0.014]
        if not near:
            continue
        inner = max(p[0] for p in near) if side_sign < 0 else min(p[0] for p in near)
        outer = min(p[0] for p in near) if side_sign < 0 else max(p[0] for p in near)
        if abs(outer - inner) < 0.012:
            continue
        path, path_normals = [], []
        for k in range(13):
            u = 0.06 + 0.88 * k / 12.0
            x = inner + (outer - inner) * u
            curve_z = z + (u - 0.5) ** 2 * 0.012 * (1.0 if row_index % 2 else -1.0)
            sample = (x, 0.52, curve_z)
            best = None; best_d2 = float("inf"); best_n = (0.0, 1.0, 0.0)
            for a, b, c in triangles:
                q = closest_on_triangle(sample, a, b, c)
                delta = sub(sample, q); d2 = dot(delta, delta)
                if d2 < best_d2:
                    best_d2 = d2; best = q; best_n = norm(cross(sub(b, a), sub(c, a)))
            if best is None:
                continue
            if best_n[1] < 0.0:
                best_n = mul(best_n, -1.0)
            path.append(add(best, mul(best_n, 0.00065)))
            path_normals.append(best_n)
        if len(path) < 3:
            continue
        verts, norms, faces = make_tube(path, path_normals, 0.00145)
        offset = len(all_vertices)
        all_vertices.extend(verts); all_normals.extend(norms)
        all_faces.extend(tuple(offset + idx for idx in face) for face in faces)
        added_rows += 1
    if all_vertices:
        wing_joint = document["skins"][0]["joints"].index(
            next(i for i, n in enumerate(document["nodes"]) if n.get("name") == f"Rig_Wing_{side_name}"))
        appender.append_mesh(f"WingVeinDetail_Fine_{side_name}", all_vertices, all_normals,
                             wing_joint, material_index, all_faces)
    return added_rows


def main() -> None:
    if len(sys.argv) > 2:
        raise SystemExit("Usage: refine_v83_mantis_glb.py [exact-v8.3-source.glb]")
    if len(sys.argv) == 2:
        data = Path(sys.argv[1]).read_bytes()
    else:
        try:
            data = subprocess.check_output(
                ["git", "show", f"{SOURCE_COMMIT}:{SOURCE_PATH}"], cwd=ROOT
            )
        except subprocess.CalledProcessError as exc:
            raise SystemExit(
                "The approved v8.3 model is not in this checkout's Git history. "
                "Pass its exact mantis_latest.glb as the optional argument."
            ) from exc
    actual_sha = glb_blob_sha1(data)
    if actual_sha != SOURCE_BLOB_SHA1:
        raise SystemExit(f"Refusing non-v8.3 source model: blob={actual_sha}, expected={SOURCE_BLOB_SHA1}")
    document, binary = parse_glb(data)
    original_animations = json.dumps(document.get("animations", []), sort_keys=True, separators=(",", ":"))
    if len(document.get("meshes", [])) != 225 or len(document.get("animations", [])) != 11:
        raise SystemExit("The selected source is not the approved v8.3 model")
    materials = document.setdefault("materials", [])
    eye_material_index = len(materials)
    materials.append({"name": "Photo eye facets | jade", "pbrMetallicRoughness": {
        "baseColorFactor": [0.18, 0.43, 0.24, 1.0], "metallicFactor": 0.03,
        "roughnessFactor": 0.25}})
    vein_material_index = 5  # Existing 8.3 wing-vein material.
    appender = GLBAppender(document, binary)
    facet_count = add_ommatidia(appender, document, binary, eye_material_index)
    vein_rows = {
        side: wing_crossvein_mesh(appender, document, binary, side, sign,
                                  vein_material_index)
        for side, sign in (("L", -1.0), ("R", 1.0))
    }
    document.setdefault("asset", {}).setdefault("extras", {})["mantisPhotoRefinement"] = {
        "revision": "v8.3-base-photo-refinement-1",
        "sourceModelGitBlob": SOURCE_BLOB_SHA1,
        "sourceModelPath": "assets/models/mantis_latest.glb at 1bdf2ee",
        "changes": ["dense sculpted compound-eye ommatidia", "fine raised forewing cross-veins"],
        "animationData": "retained byte-for-byte from the v8.3 source GLB",
        "newEyeFacetCount": facet_count,
        "fineCrossVeinRowsByWing": vein_rows,
    }
    output = MODEL.with_suffix(".refined.glb")
    appender.finish(output)
    output.replace(MODEL)
    print(f"Updated canonical 8.3 model in place: {MODEL}")
    print(f"Added {facet_count} eye facets and wing vein rows {vein_rows}; original 225 meshes and 11 clips retained.")
    print(f"Source Git blob: {SOURCE_BLOB_SHA1}; animation JSON sha256: {hashlib.sha256(original_animations.encode()).hexdigest()}")


if __name__ == "__main__":
    main()
