#!/usr/bin/env python3
"""Refine the rigged mantis GLB using only the Python standard library.

Run from the project root:
    python3 tools/upgrade_mantis_glb.py

Keeps the existing skeleton and animations, adds smooth vertex normals, nudges
the model toward the broad-winged green mantis reference, and tones down the
over-bright vertex colors. The v2 pass grades the vertex colors into the
reference's pale olive-green palette and broadens the wing silhouette.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
MODEL = PROJECT / "assets" / "models" / "mantis_latest.glb"

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
COMPONENT_FORMATS = {
    5121: ("B", 1),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
TYPE_WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def align4(data: bytearray) -> None:
    while len(data) % 4:
        data.append(0)


def accessor_layout(doc: dict, accessor_index: int) -> tuple[dict, int, int, int, str]:
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    fmt, size = COMPONENT_FORMATS[accessor["componentType"]]
    width = TYPE_WIDTHS[accessor["type"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", size * width)
    return accessor, offset, stride, width, fmt


def read_vectors(doc: dict, binary: bytearray, accessor_index: int) -> list[tuple[float, ...]]:
    accessor, offset, stride, width, fmt = accessor_layout(doc, accessor_index)
    unpacker = struct.Struct("<" + fmt * width)
    return [
        tuple(float(x) for x in unpacker.unpack_from(binary, offset + i * stride))
        for i in range(accessor["count"])
    ]


def write_vectors(
    doc: dict,
    binary: bytearray,
    accessor_index: int,
    vectors: list[tuple[float, ...]],
) -> None:
    accessor, offset, stride, width, fmt = accessor_layout(doc, accessor_index)
    packer = struct.Struct("<" + fmt * width)
    for i, vector in enumerate(vectors):
        packer.pack_into(binary, offset + i * stride, *vector)
    if width == 3 and vectors:
        accessor["min"] = [min(row[axis] for row in vectors) for axis in range(3)]
        accessor["max"] = [max(row[axis] for row in vectors) for axis in range(3)]


def read_indices(doc: dict, binary: bytearray, accessor_index: int) -> list[int]:
    accessor, offset, stride, _, fmt = accessor_layout(doc, accessor_index)
    unpacker = struct.Struct("<" + fmt)
    return [unpacker.unpack_from(binary, offset + i * stride)[0] for i in range(accessor["count"])]


def vertex_normals(positions: list[tuple[float, ...]], indices: list[int]) -> list[tuple[float, float, float]]:
    accum = [[0.0, 0.0, 0.0] for _ in positions]
    for tri in range(0, len(indices) - 2, 3):
        ia, ib, ic = indices[tri : tri + 3]
        a, b, c = positions[ia], positions[ib], positions[ic]
        ab = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        ac = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
        n = (
            ab[1] * ac[2] - ab[2] * ac[1],
            ab[2] * ac[0] - ab[0] * ac[2],
            ab[0] * ac[1] - ab[1] * ac[0],
        )
        for index in (ia, ib, ic):
            for axis in range(3):
                accum[index][axis] += n[axis]
    result = []
    for normal in accum:
        length = math.sqrt(sum(value * value for value in normal))
        if length < 1e-12:
            result.append((0.0, 1.0, 0.0))
        else:
            result.append(tuple(value / length for value in normal))
    return result


def append_normal_accessor(doc: dict, binary: bytearray, values: list[tuple[float, float, float]]) -> int:
    align4(binary)
    start = len(binary)
    for value in values:
        binary.extend(struct.pack("<3f", *value))
    view_index = len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer": 0, "byteOffset": start, "byteLength": len(values) * 12, "target": 34962})
    accessor_index = len(doc["accessors"])
    doc["accessors"].append({
        "bufferView": view_index,
        "componentType": 5126,
        "count": len(values),
        "type": "VEC3",
        "min": [min(row[axis] for row in values) for axis in range(3)],
        "max": [max(row[axis] for row in values) for axis in range(3)],
    })
    return accessor_index


def scale_for_mesh(name: str) -> tuple[float, float, float]:
    if name == "Head":
        # Smaller, more oval head: the abdomen and folded tegmina dominate the silhouette.
        return (0.76, 0.88, 0.84)
    if name.startswith("Eye_"):
        return (0.90, 0.92, 0.90)
    if name.startswith("Wing_"):
        # Broaden each flattened forewing and extend it along the abdomen.
        return (1.28, 0.82, 1.10)
    if name == "Abdomen":
        return (1.06, 1.04, 1.12)
    if name.startswith("AbdominalPlate_"):
        return (1.05, 1.0, 1.08)
    if name == "Thorax":
        return (1.0, 1.0, 1.10)
    return (1.0, 1.0, 1.0)


def color_factor(name: str) -> tuple[float, float, float]:
    if name.startswith("Wing_"):
        return (0.88, 0.91, 0.82)
    if name.startswith("AbdominalPlate_") or name.startswith("Spine_"):
        return (0.84, 0.88, 0.80)
    if name == "Thorax":
        return (1.05, 1.10, 0.98)
    if name.startswith("Eye_") or name.startswith("Ocellus_"):
        return (1.0, 1.0, 1.0)
    return (0.80, 0.88, 0.78)


def reference_scale(name: str) -> tuple[float, float, float]:
    """Small follow-up proportions pass; GLB long axis is local Z."""
    if name.startswith("Wing_"):
        # Broad, flattened leaf-shaped tegmina should cover the abdomen.
        return (1.18, 0.90, 1.05)
    if name == "Abdomen":
        return (1.04, 0.96, 1.06)
    if name.startswith("AbdominalPlate_"):
        return (1.03, 1.0, 1.04)
    if name == "Thorax":
        return (0.94, 0.97, 1.10)
    if name == "Head":
        return (0.90, 0.92, 0.94)
    if name.startswith("Eye_"):
        return (0.94, 0.95, 0.94)
    return (1.0, 1.0, 1.0)


def reference_palette(name: str) -> tuple[float, float, float]:
    """Photo-guided pale olive colors, in linear glTF vertex-color space."""
    if name.startswith("Wing_"):
        return (0.53, 0.65, 0.30)
    if name.startswith("AbdominalPlate_"):
        return (0.39, 0.50, 0.23)
    if name == "Abdomen":
        return (0.46, 0.57, 0.27)
    if name == "Thorax":
        return (0.45, 0.57, 0.27)
    if name == "Head":
        return (0.49, 0.60, 0.30)
    if name.startswith("Eye_"):
        return (0.09, 0.17, 0.10)
    if name.startswith("Ocellus_"):
        return (0.24, 0.34, 0.18)
    if name.startswith("Spine_"):
        return (0.43, 0.49, 0.22)
    if name.startswith("ForeFemur_"):
        return (0.48, 0.59, 0.28)
    if name.startswith("ForeTibia_"):
        return (0.43, 0.54, 0.25)
    if name.startswith("Antenna_"):
        return (0.43, 0.52, 0.27)
    if name.startswith("Coxa_"):
        return (0.42, 0.52, 0.24)
    if name.startswith("Tibia_"):
        return (0.46, 0.56, 0.27)
    if name.startswith("Joint_"):
        return (0.37, 0.46, 0.21)
    return (0.44, 0.54, 0.25)


def modify_reference_colors(
    doc: dict,
    binary: bytearray,
    mesh_name: str,
    accessor_index: int,
    positions: list[tuple[float, ...]],
) -> None:
    """Retain mild shape shading while removing the previous cyan/brown cast."""
    accessor, offset, stride, width, fmt = accessor_layout(doc, accessor_index)
    normalized = accessor.get("normalized", False)
    integer = accessor["componentType"] == 5121
    max_value = 255.0 if integer and normalized else 1.0
    packer = struct.Struct("<" + fmt * width)
    base = reference_palette(mesh_name)
    rows = []
    z_extent = max(max(abs(p[2]) for p in positions), 1e-6) if positions else 1.0
    x_extent = max(max(abs(p[0]) for p in positions), 1e-6) if positions else 1.0
    y_extent = max(max(abs(p[1]) for p in positions), 1e-6) if positions else 1.0
    for i in range(accessor["count"]):
        rgba = list(packer.unpack_from(binary, offset + i * stride))
        source = [float(v) / max_value for v in rgba]
        luminance = 0.2126 * source[0] + 0.7152 * source[1] + 0.0722 * source[2]
        shade = 0.88 + 0.28 * max(0.0, min(1.0, luminance))
        if mesh_name.startswith("Wing_"):
            p = positions[i]
            t = (p[2] / z_extent + 1.0) * 0.5
            lateral = abs(p[0]) / x_extent
            dorsal = max(0.0, min(1.0, (p[1] / y_extent + 1.0) * 0.5))
            midrib = math.exp(-((lateral / 0.055) ** 2))
            branch_a = math.exp(-(((lateral - (0.15 + 0.34 * t)) / 0.055) ** 2))
            branch_b = math.exp(-(((lateral - (0.50 + 0.25 * t)) / 0.060) ** 2))
            shade *= 1.0 - dorsal * (0.075 * midrib + 0.042 * (branch_a + branch_b))
        converted = []
        for channel in range(3):
            value = max(0.0, min(1.0, base[channel] * shade))
            converted.append(round(value * max_value) if integer else value)
        if width > 3:
            converted.extend(rgba[3:])
        rows.append(tuple(converted))
    for i, row in enumerate(rows):
        packer.pack_into(binary, offset + i * stride, *row)


def transform_positions(name: str, positions: list[tuple[float, ...]]) -> list[tuple[float, ...]]:
    sx, sy, sz = scale_for_mesh(name)
    return [(row[0] * sx, row[1] * sy, row[2] * sz) for row in positions]


def modify_colors(
    doc: dict,
    binary: bytearray,
    mesh_name: str,
    accessor_index: int,
    positions: list[tuple[float, ...]],
) -> None:
    accessor, offset, stride, width, fmt = accessor_layout(doc, accessor_index)
    factor = color_factor(mesh_name)
    normalized = accessor.get("normalized", False)
    integer = accessor["componentType"] == 5121
    max_value = 255.0 if integer and normalized else 1.0
    packer = struct.Struct("<" + fmt * width)
    rows = []
    for i in range(accessor["count"]):
        rgba = list(packer.unpack_from(binary, offset + i * stride))
        color = [float(v) / max_value for v in rgba]
        for channel in range(3):
            color[channel] *= factor[channel]
        if mesh_name.startswith("Wing_"):
            p = positions[i]
            half_len = max(max(abs(v[2]) for v in positions), 1e-6)
            half_width = max(max(abs(v[0]) for v in positions), 1e-6)
            t = (p[2] / half_len + 1.0) * 0.5
            lateral = abs(p[0]) / half_width
            midrib = math.exp(-((lateral / 0.045) ** 2))
            branch_a = math.exp(-(((lateral - (0.13 + 0.32 * t)) / 0.035) ** 2))
            branch_b = math.exp(-(((lateral - (0.48 + 0.30 * t)) / 0.04) ** 2))
            dorsal = max(0.0, min(1.0, (p[1] / max(max(abs(v[1]) for v in positions), 1e-6) + 1.0) * 0.5))
            vein = min(1.0, (0.13 * midrib + 0.075 * (branch_a + branch_b)) * dorsal)
            color[0] *= 1.0 - vein * 0.55
            color[1] *= 1.0 - vein * 0.12
            color[2] *= 1.0 - vein * 0.36
        converted = []
        for channel, value in enumerate(color):
            if channel < 3:
                value = max(0.0, min(1.0, value))
                converted.append(round(value * max_value) if integer else value)
            else:
                converted.append(rgba[channel])
        rows.append(tuple(converted))
    for i, row in enumerate(rows):
        packer.pack_into(binary, offset + i * stride, *row)


def read_glb(path: Path) -> tuple[dict, bytearray]:
    data = path.read_bytes()
    magic, version, total_length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2 or total_length != len(data):
        raise ValueError("Unsupported or malformed GLB header")
    offset = 12
    document = None
    binary = bytearray()
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + length]
        offset += length
        if kind == JSON_CHUNK:
            document = json.loads(chunk.rstrip(b" \t\r\n\x00"))
        elif kind == BIN_CHUNK:
            binary = bytearray(chunk)
    if document is None or not binary:
        raise ValueError("GLB must contain JSON and binary chunks")
    return document, binary


def write_glb(path: Path, document: dict, binary: bytearray) -> None:
    align4(binary)
    document["buffers"][0]["byteLength"] = len(binary)
    json_chunk = bytearray(json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
    while len(json_chunk) % 4:
        json_chunk.append(0x20)
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    output = bytearray(struct.pack("<III", GLB_MAGIC, 2, total))
    output.extend(struct.pack("<II", len(json_chunk), JSON_CHUNK))
    output.extend(json_chunk)
    output.extend(struct.pack("<II", len(binary), BIN_CHUNK))
    output.extend(binary)
    path.write_bytes(output)


def main() -> None:
    document, binary = read_glb(MODEL)
    asset_extras = document.setdefault("asset", {}).setdefault("extras", {})
    if asset_extras.get("reference_mantis_refinement") in {"v2", "photo_proportions_v3", "photo_proportions_v4", "photo_proportions_v5", "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum"}:
        print("The reference-mantis refinement is already applied; leaving the GLB unchanged.")
        return
    normal_count = 0
    changed_positions = set()
    changed_colors = set()
    changed_normals = set()
    for mesh in document.get("meshes", []):
        name = mesh.get("name", "")
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            position_index = attributes.get("POSITION")
            if position_index is None:
                continue
            positions = read_vectors(document, binary, position_index)
            if position_index not in changed_positions:
                positions = transform_positions(name, positions)
                sx, sy, sz = reference_scale(name)
                positions = [(p[0] * sx, p[1] * sy, p[2] * sz) for p in positions]
                write_vectors(document, binary, position_index, positions)
                changed_positions.add(position_index)
            indices_index = primitive.get("indices")
            indices = read_indices(document, binary, indices_index) if indices_index is not None else list(range(len(positions)))
            if "NORMAL" not in attributes:
                normals = vertex_normals(positions, indices)
                attributes["NORMAL"] = append_normal_accessor(document, binary, normals)
                normal_count += 1
            elif attributes["NORMAL"] not in changed_normals:
                normals = vertex_normals(positions, indices)
                write_vectors(document, binary, attributes["NORMAL"], normals)
                changed_normals.add(attributes["NORMAL"])
            color_index = attributes.get("COLOR_0")
            if color_index is not None and color_index not in changed_colors:
                modify_reference_colors(document, binary, name, color_index, positions)
                changed_colors.add(color_index)
    asset_extras["reference_mantis_refinement"] = "v2"
    write_glb(MODEL, document, binary)
    print(f"Updated {MODEL.name}: {normal_count} smooth normal streams, "
          f"{len(changed_positions)} mesh shapes, {len(changed_colors)} color streams")


if __name__ == "__main__":
    main()
