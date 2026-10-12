#!/usr/bin/env python3
"""Separate and taper the v3.3 wing covers; add UVs for detailed vein maps."""
from __future__ import annotations

import json
import struct

import upgrade_mantis_glb as glb


MODEL = glb.PROJECT / "assets" / "models" / "mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v3"
MARKER = "photo_proportions_v4"


def append_vec2_accessor(document: dict, binary: bytearray,
                         values: list[tuple[float, float]]) -> int:
    glb.align4(binary)
    start = len(binary)
    for value in values:
        binary.extend(struct.pack("<2f", *value))
    view_index = len(document["bufferViews"])
    document["bufferViews"].append({
        "buffer": 0, "byteOffset": start, "byteLength": len(values) * 8,
        "target": 34962,
    })
    accessor_index = len(document["accessors"])
    document["accessors"].append({
        "bufferView": view_index, "componentType": 5126,
        "count": len(values), "type": "VEC2",
        "min": [min(row[axis] for row in values) for axis in range(2)],
        "max": [max(row[axis] for row in values) for axis in range(2)],
    })
    return accessor_index


def leaf_blade(positions: list[tuple[float, ...]]) -> list[tuple[float, float, float]]:
    x_extent = max(max(abs(p[0]) for p in positions), 1e-6)
    z_extent = max(max(abs(p[2]) for p in positions), 1e-6)
    result = []
    for x, y, z in positions:
        across = max(-1.0, min(1.0, x / x_extent))
        along = min(1.0, abs(z) / z_extent)
        tip_taper = 0.80 + 0.20 * (1.0 - along * along) ** 0.5
        # The imported Wing_L/R nodes sit at x=-/+0.075. A local half-width
        # of 0.105 makes the paired leaves meet at the center and extend just
        # beyond the abdomen, instead of overlapping as two full oval plates.
        shaped_x = across * 0.105 * tip_taper
        camber = 0.010 * (1.0 - across * across) * (1.0 - along * along)
        result.append((shaped_x, y * 0.88 + camber, z * 1.015))
    return result


def wing_uvs(positions: list[tuple[float, ...]]) -> list[tuple[float, float]]:
    x_extent = max(max(abs(p[0]) for p in positions), 1e-6)
    z_extent = max(max(abs(p[2]) for p in positions), 1e-6)
    return [
        (max(0.0, min(1.0, 0.5 + x / (2.0 * x_extent))),
         max(0.0, min(1.0, 0.5 + z / (2.0 * z_extent))))
        for x, _y, z in positions
    ]


def write_uvs(document: dict, binary: bytearray, accessor_index: int,
              values: list[tuple[float, float]]) -> None:
    glb.write_vectors(document, binary, accessor_index, values)
    accessor = document["accessors"][accessor_index]
    accessor["min"] = [min(row[axis] for row in values) for axis in range(2)]
    accessor["max"] = [max(row[axis] for row in values) for axis in range(2)]


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker in {MARKER, "photo_proportions_v5", "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100"}:
        print("The v4 wing refinement or a later pass is already applied; leaving the GLB unchanged.")
        return
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to reshape an unknown base.")

    position_indices: set[int] = set()
    normal_indices: set[int] = set()
    uv_indices: set[int] = set()
    found_wings: set[str] = set()
    for mesh in document.get("meshes", []):
        name = mesh.get("name", "")
        if not (name.startswith("Wing_") or name.startswith("ForeFemur_")
                or name.startswith("ForeTibia_") or name.startswith("Spine_")):
            continue
        if name.startswith("Wing_"):
            found_wings.add(name)
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            position_index = attributes.get("POSITION")
            if position_index is None:
                continue
            positions = glb.read_vectors(document, binary, position_index)
            if position_index not in position_indices:
                if name.startswith("Wing_"):
                    positions = leaf_blade(positions)
                elif name.startswith("ForeFemur_"):
                    positions = [(x * 1.20, y * 1.23, z * 1.06) for x, y, z in positions]
                elif name.startswith("ForeTibia_"):
                    positions = [(x * 1.16, y * 1.13, z * 1.08) for x, y, z in positions]
                else:
                    positions = [(x * 1.16, y * 1.18, z * 1.16) for x, y, z in positions]
                glb.write_vectors(document, binary, position_index, positions)
                position_indices.add(position_index)

            index_accessor = primitive.get("indices")
            indices = glb.read_indices(document, binary, index_accessor) if index_accessor is not None else list(range(len(positions)))
            normal_index = attributes.get("NORMAL")
            normals = glb.vertex_normals(positions, indices)
            if normal_index is None:
                attributes["NORMAL"] = glb.append_normal_accessor(document, binary, normals)
            elif normal_index not in normal_indices:
                glb.write_vectors(document, binary, normal_index, normals)
                normal_indices.add(normal_index)

            if name.startswith("Wing_"):
                uv_values = wing_uvs(positions)
                uv_index = attributes.get("TEXCOORD_0")
                if uv_index is None:
                    uv_index = append_vec2_accessor(document, binary, uv_values)
                    attributes["TEXCOORD_0"] = uv_index
                elif uv_index not in uv_indices:
                    write_uvs(document, binary, uv_index, uv_values)
                uv_indices.add(uv_index)

    if found_wings != {"Wing_L", "Wing_R"}:
        raise ValueError(f"Expected both paired wing meshes; found {sorted(found_wings)}")
    extras["reference_mantis_refinement"] = MARKER
    glb.write_glb(MODEL, document, binary)
    print("Refined both paired tegmina and added UVs; preserved skin, rig, and animation data.")


if __name__ == "__main__":
    main()
