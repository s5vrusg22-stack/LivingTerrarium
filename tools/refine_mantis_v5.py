#!/usr/bin/env python3
"""Refine the v4 Hierodula wing silhouette and raptorial forelegs in-place."""
from __future__ import annotations

import sys
from pathlib import Path

import upgrade_mantis_glb as glb


MODEL = glb.PROJECT / "assets" / "models" / "mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v4"
MARKER = "photo_proportions_v5"


def center_scale(points: list[tuple[float, float, float]],
                 factors: tuple[float, float, float]) -> list[tuple[float, float, float]]:
    center = tuple((min(point[i] for point in points) + max(point[i] for point in points)) * 0.5 for i in range(3))
    return [tuple(center[i] + (point[i] - center[i]) * factors[i] for i in range(3)) for point in points]


def shape_wing(points: list[tuple[float, float, float]]) -> list[tuple[float, float, float]]:
    z_extent = max(abs(point[2]) for point in points)
    shaped = []
    for x, y, z in points:
        along = min(1.0, abs(z) / max(z_extent, 1e-6))
        # Retain the broad middle of the tegmen and narrow the tips so the
        # paired covers read as pointed leaves rather than oval plates.
        taper = 1.10 * (1.0 - 0.30 * along ** 2.4)
        shaped.append((x * taper, y * 1.12, z * 1.035))
    return shaped


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker in {MARKER, "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100"}:
        print("The v5 mantis shape pass or a later pass is already applied; leaving the GLB unchanged.")
        return
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to reshape an unknown base.")

    position_indices: set[int] = set()
    normal_indices: set[int] = set()
    uv_indices: set[int] = set()
    found: set[str] = set()
    for mesh in document.get("meshes", []):
        name = mesh.get("name", "")
        if not (name.startswith(("Wing_", "ForeFemur_", "ForeTibia_", "Spine_")) or name == "Thorax"):
            continue
        if name.startswith("Wing_"):
            found.add(name)
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            position_index = attributes.get("POSITION")
            if position_index is None or position_index in position_indices:
                continue
            points = glb.read_vectors(document, binary, position_index)
            if name.startswith("Wing_"):
                points = shape_wing(points)
            elif name.startswith("ForeFemur_"):
                points = center_scale(points, (1.07, 1.14, 1.12))
            elif name.startswith("ForeTibia_"):
                points = center_scale(points, (1.16, 1.07, 1.07))
            elif name.startswith("Spine_"):
                points = center_scale(points, (1.14, 1.14, 1.14))
            else:
                points = center_scale(points, (1.08, 1.02, 1.035))
            glb.write_vectors(document, binary, position_index, points)
            position_indices.add(position_index)

            index_accessor = primitive.get("indices")
            indices = glb.read_indices(document, binary, index_accessor) if index_accessor is not None else list(range(len(points)))
            normal_index = attributes.get("NORMAL")
            normals = glb.vertex_normals(points, indices)
            if normal_index is None:
                attributes["NORMAL"] = glb.append_normal_accessor(document, binary, normals)
            elif normal_index not in normal_indices:
                glb.write_vectors(document, binary, normal_index, normals)
                normal_indices.add(normal_index)

            if name.startswith("Wing_"):
                uv_index = attributes.get("TEXCOORD_0")
                if uv_index is not None and uv_index not in uv_indices:
                    uv = [(max(0.0, min(1.0, 0.5 + x / 0.24)),
                           max(0.0, min(1.0, 0.5 + z / 0.96))) for x, _y, z in points]
                    glb.write_vectors(document, binary, uv_index, uv)
                    document["accessors"][uv_index]["min"] = [min(row[axis] for row in uv) for axis in range(2)]
                    document["accessors"][uv_index]["max"] = [max(row[axis] for row in uv) for axis in range(2)]
                    uv_indices.add(uv_index)

    if found != {"Wing_L", "Wing_R"}:
        raise ValueError(f"Expected paired wing meshes; found {sorted(found)}")
    extras["reference_mantis_refinement"] = MARKER
    glb.write_glb(MODEL, document, binary)
    print("Sharpened both leaf-shaped tegmina and strengthened raptorial forelimbs; preserved skin and clips.")


if __name__ == "__main__":
    main()
