#!/usr/bin/env python3
"""Refine the mantis model actually selected by the successful v8.3 APK.

The source is pinned to the v8.3 scene's mantis_v7_animated.glb. The output
keeps its authored body, materials, node layout, and six clips; it adds only
fine raised forewing cross-veins beneath the original wing pivots.
"""
from __future__ import annotations

import hashlib
import json
import math
import subprocess
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets/models/mantis_latest.glb"
SOURCE_COMMIT = "bb32cf56b468a1a9b441bbade3d447e6b36e2416"
SOURCE_PATH = "assets/models/mantis_v7_animated.glb"
SOURCE_BLOB_SHA1 = "11f382981fb1afd2b0506a8ddee16b52a55c8259"

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
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


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
        self.document["bufferViews"].append({
            "buffer": 0, "byteOffset": offset, "byteLength": len(payload), "target": target
        })
        accessor = {
            "bufferView": view_index, "componentType": component_type,
            "count": count, "type": kind,
        }
        if minimum is not None:
            accessor["min"] = list(minimum)
        if maximum is not None:
            accessor["max"] = list(maximum)
        accessor_index = len(self.document["accessors"])
        self.document["accessors"].append(accessor)
        return accessor_index

    def append_mesh(self, name: str, positions: list[Vec], normals: list[Vec],
                    parent_index: int, material_index: int,
                    triangles: list[tuple[int, int, int]]) -> None:
        if not positions or len(positions) != len(normals):
            raise ValueError(f"Invalid geometry for {name}")
        flat_pos = [v for p in positions for v in p]
        flat_nrm = [v for p in normals for v in p]
        pos_data = struct.pack("<" + "f" * len(flat_pos), *flat_pos)
        nrm_data = struct.pack("<" + "f" * len(flat_nrm), *flat_nrm)
        index_values = [v for tri in triangles for v in tri]
        if max(index_values) > 65535:
            raise ValueError(f"Too many vertices for {name}")
        index_data = struct.pack("<" + "H" * len(index_values), *index_values)
        pmin = tuple(min(p[i] for p in positions) for i in range(3))
        pmax = tuple(max(p[i] for p in positions) for i in range(3))
        p_acc = self.append_accessor(pos_data, 5126, "VEC3", len(positions), 34962,
                                     minimum=pmin, maximum=pmax)
        n_acc = self.append_accessor(nrm_data, 5126, "VEC3", len(normals), 34962)
        i_acc = self.append_accessor(index_data, 5123, "SCALAR", len(index_values), 34963,
                                     minimum=(min(index_values),), maximum=(max(index_values),))
        mesh_index = len(self.document["meshes"])
        self.document["meshes"].append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": p_acc, "NORMAL": n_acc},
                "indices": i_acc, "material": material_index, "mode": 4,
            }],
        })
        node_index = len(self.document["nodes"])
        self.document["nodes"].append({"name": name, "mesh": mesh_index})
        self.document["nodes"][parent_index].setdefault("children", []).append(node_index)

    def finish(self, output: Path) -> None:
        self.document["buffers"][0]["byteLength"] = len(self.binary)
        encoded = json.dumps(self.document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        encoded += b" " * ((4 - len(encoded) % 4) % 4)
        binary = bytes(self.binary)
        chunks = (struct.pack("<II", len(encoded), 0x4E4F534A) + encoded +
                  struct.pack("<II", len(binary), 0x004E4942) + binary)
        output.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks)


def closest_on_triangle(p: Vec, a: Vec, b: Vec, c: Vec) -> Vec:
    ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
    d1, d2 = dot(ab, ap), dot(ac, ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return a
    bp = sub(p, b)
    d3, d4 = dot(ab, bp), dot(ac, bp)
    if d3 >= 0.0 and d4 <= d3:
        return b
    vc = d1 * d4 - d3 * d2
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
        return add(a, mul(ab, d1 / (d1 - d3)))
    cp = sub(p, c)
    d5, d6 = dot(ab, cp), dot(ac, cp)
    if d6 >= 0.0 and d5 <= d6:
        return c
    vb = d5 * d2 - d1 * d6
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
        return add(a, mul(ac, d2 / (d2 - d6)))
    va = d3 * d6 - d5 * d4
    if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
        return add(b, mul(sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6))))
    denominator = 1.0 / (va + vb + vc)
    v, w = vb * denominator, vc * denominator
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
    wing_node_index = next(i for i, node in enumerate(document["nodes"])
                           if node.get("name") == f"Wing_{side_name}")
    wing_node = document["nodes"][wing_node_index]
    primitive = document["meshes"][wing_node["mesh"]]["primitives"][0]
    positions = [tuple(float(x) for x in p)
                 for p in accessor_values(document, binary, primitive["attributes"]["POSITION"])]
    indices = [int(row[0]) for row in accessor_values(document, binary, primitive["indices"])]
    triangles = [(positions[indices[i]], positions[indices[i + 1]], positions[indices[i + 2]])
                 for i in range(0, len(indices), 3)]
    zmin, zmax = min(p[2] for p in positions), max(p[2] for p in positions)
    ymin, ymax = min(p[1] for p in positions), max(p[1] for p in positions)
    wing_y = (ymin + ymax) * 0.5
    all_vertices: list[Vec] = []
    all_normals: list[Vec] = []
    all_faces: list[tuple[int, int, int]] = []
    added_rows = 0
    for row_index in range(14):
        z = zmin + (zmax - zmin) * (row_index + 0.5) / 14.0
        near = [p for p in positions if abs(p[2] - z) < 0.075]
        if not near:
            continue
        inner = max(p[0] for p in near) if side_sign < 0 else min(p[0] for p in near)
        outer = min(p[0] for p in near) if side_sign < 0 else max(p[0] for p in near)
        if abs(outer - inner) < 0.025:
            continue
        path: list[Vec] = []
        path_normals: list[Vec] = []
        for sample_index in range(13):
            u = 0.06 + 0.88 * sample_index / 12.0
            x = inner + (outer - inner) * u
            curve_z = z + (u - 0.5) ** 2 * 0.016 * (1.0 if row_index % 2 else -1.0)
            sample = (x, wing_y, curve_z)
            best = None
            best_d2 = float("inf")
            best_normal = (0.0, 1.0, 0.0)
            for a, b, c in triangles:
                q = closest_on_triangle(sample, a, b, c)
                delta = sub(sample, q)
                d2 = dot(delta, delta)
                if d2 < best_d2:
                    best_d2 = d2
                    best = q
                    best_normal = norm(cross(sub(b, a), sub(c, a)))
            if best is None:
                continue
            if best_normal[1] < 0.0:
                best_normal = mul(best_normal, -1.0)
            path.append(add(best, mul(best_normal, 0.0008)))
            path_normals.append(best_normal)
        if len(path) < 3:
            continue
        vertices, normals, faces = make_tube(path, path_normals, 0.0018)
        offset = len(all_vertices)
        all_vertices.extend(vertices)
        all_normals.extend(normals)
        all_faces.extend(tuple(offset + index for index in face) for face in faces)
        added_rows += 1
    if all_vertices:
        appender.append_mesh(
            f"WingVeinDetail_Fine_{side_name}", all_vertices, all_normals,
            wing_node_index, material_index, all_faces
        )
    return added_rows


def main() -> None:
    source_path = f"{SOURCE_COMMIT}:{SOURCE_PATH}"
    try:
        source_data = subprocess.check_output(["git", "show", source_path], cwd=ROOT)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"Missing the v8.3 APK model source {source_path}") from exc
    actual_sha = glb_blob_sha1(source_data)
    if actual_sha != SOURCE_BLOB_SHA1:
        raise SystemExit(f"Refusing wrong source model: {actual_sha} != {SOURCE_BLOB_SHA1}")
    document, binary = parse_glb(source_data)
    if (len(document.get("meshes", [])) != 31 or
            len(document.get("nodes", [])) != 38 or
            len(document.get("animations", [])) != 6):
        raise SystemExit("Pinned source does not match the model selected by the successful v8.3 APK")
    materials = document["materials"]
    material_index = next(i for i, material in enumerate(materials)
                          if material.get("name") == "vein")
    appender = GLBAppender(document, binary)
    vein_rows = {
        "L": wing_crossvein_mesh(appender, document, binary, "L", -1.0, material_index),
        "R": wing_crossvein_mesh(appender, document, binary, "R", 1.0, material_index),
    }
    if vein_rows != {"L": 14, "R": 14}:
        raise SystemExit(f"Expected 14 cross-vein rows on each wing, got {vein_rows}")
    document.setdefault("asset", {}).setdefault("extras", {})["mantisPhotoRefinement"] = {
        "revision": "v8.3-apk-model-photo-refinement-1",
        "sourceModelGitBlob": SOURCE_BLOB_SHA1,
        "sourceModelPath": f"{SOURCE_PATH} at bb32cf5",
        "changes": ["fine raised forewing cross-veins"],
        "materialsAndEyeFacets": "retained from the model used by the successful v8.3 APK",
        "animationData": "all six v8.3 animation clips retained byte-for-byte",
        "fineCrossVeinRowsByWing": vein_rows,
    }
    output = MODEL.with_suffix(".refined.glb")
    appender.finish(output)
    output.replace(MODEL)
    print(f"Updated {MODEL} from the exact mantis model in the successful v8.3 APK.")
    print(f"Added fine forewing cross-veins: {vein_rows}; preserved all six original clips.")
    print(f"Source Git blob: {SOURCE_BLOB_SHA1}")


if __name__ == "__main__":
    main()
