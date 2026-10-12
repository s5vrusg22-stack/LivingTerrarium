#!/usr/bin/env python3
"""Apply the photo-proportion pass to the v4.4 mantis without touching its rig.

The paired tegmina move rearward, the abdomen slims under the covers, the
pronotum lengthens, the head narrows toward the mouth, and old detached spine
markers are removed in favor of the 100 integrated foreleg details from v4.0.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys

import numpy as np

import upgrade_mantis_glb as glb
import refine_mantis_detail_v7 as detail

MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v8_forelegs_100"
PASS_MARKER = "photo_reference_profile_v9"
WING_X_SCALE = 1.14
WING_Z_SCALE = 1.06
WING_POSTERIOR_OFFSET = 0.18


def update_normals(doc: dict, binary: bytearray, primitive: dict,
                   points: list[tuple[float, ...]]) -> None:
    indices = glb.read_indices(doc, binary, primitive["indices"])
    normals = glb.vertex_normals(points, indices)
    normal_index = primitive["attributes"].get("NORMAL")
    if normal_index is None:
        primitive["attributes"]["NORMAL"] = glb.append_normal_accessor(doc, binary, normals)
    else:
        glb.write_vectors(doc, binary, normal_index, normals)


def scale_surface(doc: dict, binary: bytearray, mesh_name: str,
                   *, side: int) -> None:
    mesh = next(item for item in doc["meshes"] if item.get("name") == mesh_name)
    seam_x = -side * 0.075
    for primitive in mesh.get("primitives", []):
        attrs = primitive["attributes"]
        position_index = attrs["POSITION"]
        points = glb.read_vectors(doc, binary, position_index)
        scaled = [(seam_x + (x - seam_x) * WING_X_SCALE,
                   y,
                   z * WING_Z_SCALE + WING_POSTERIOR_OFFSET)
                  for x, y, z in points]
        glb.write_vectors(doc, binary, position_index, scaled)
        update_normals(doc, binary, primitive, scaled)


def reshape_mesh(doc: dict, binary: bytearray, mesh_name: str,
                 factors: tuple[float, float, float]) -> None:
    mesh = next(item for item in doc["meshes"] if item.get("name") == mesh_name)
    for primitive in mesh.get("primitives", []):
        attrs = primitive["attributes"]
        position_index = attrs["POSITION"]
        points = glb.read_vectors(doc, binary, position_index)
        shaped = [tuple(point[i] * factors[i] for i in range(3)) for point in points]
        glb.write_vectors(doc, binary, position_index, shaped)
        update_normals(doc, binary, primitive, shaped)


def sculpt_head(doc: dict, binary: bytearray,
                processed_positions: set[int]) -> None:
    meshes = {mesh.get("name"): mesh for mesh in doc["meshes"]}
    for mesh_name in ("Head", "Eye_L", "Eye_R"):
        mesh = meshes[mesh_name]
        for primitive in mesh.get("primitives", []):
            attrs = primitive["attributes"]
            position_index = attrs["POSITION"]
            if position_index in processed_positions:
                continue
            processed_positions.add(position_index)
            points = glb.read_vectors(doc, binary, position_index)
            if mesh_name == "Head":
                zmin = min(point[2] for point in points)
                zmax = max(point[2] for point in points)
                shaped = []
                for x, y, z in points:
                    u = (z - zmin) / max(zmax - zmin, 1e-9)
                    smooth = u * u * (3.0 - 2.0 * u)
                    taper = 0.62 + 0.38 * smooth
                    shaped.append((x * 1.08 * taper,
                                   y * (0.86 + 0.14 * smooth),
                                   z * 1.04))
            else:
                shaped = [(x * 0.70, y * 0.73, z * 0.74) for x, y, z in points]
            glb.write_vectors(doc, binary, position_index, shaped)
            update_normals(doc, binary, primitive, shaped)


def make_mouthparts() -> detail.MeshBuilder:
    builder = detail.MeshBuilder()
    plate = (0.42, 0.56, 0.25, 1.0)
    palp = (0.31, 0.44, 0.19, 1.0)
    builder.ellipsoid((0.0, -0.050, -0.063), (0.028, 0.012, 0.013), plate,
                      latitudes=12, longitudes=20)
    for side in (-1.0, 1.0):
        mandible = [(side * 0.014, -0.057, -0.071),
                    (side * 0.022, -0.066, -0.081),
                    (side * 0.016, -0.076, -0.090),
                    (side * 0.007, -0.080, -0.087)]
        builder.tube(mandible, 0.0031, palp, sides=6)
        maxillary_palp = [(side * 0.027, -0.047, -0.060),
                          (side * 0.039, -0.054, -0.073),
                          (side * 0.034, -0.061, -0.081)]
        builder.tube(maxillary_palp, 0.0022, plate, sides=5)
    return builder


def main() -> None:
    doc, binary = glb.read_glb(MODEL)
    extras = doc.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to alter an unknown rig.")
    if PASS_MARKER in extras:
        print("The v4.5 reference-profile pass is already applied.")
        return
    meshes = {mesh.get("name"): mesh for mesh in doc.get("meshes", [])}
    nodes = {node.get("name"): node for node in doc.get("nodes", []) if "name" in node}
    required_meshes = {"Abdomen", "Thorax", "ThoraxSurfaceDetail", "Head",
                       "Eye_L", "Eye_R", "Wing_L", "Wing_R",
                       "WingVeinDetail_L", "WingVeinDetail_R", "Hindwing_L", "Hindwing_R"}
    if not required_meshes.issubset(meshes):
        raise ValueError(f"Missing v4.2 mantis meshes: {sorted(required_meshes - meshes.keys())}")
    if len(doc.get("skins", [{}])[0].get("joints", [])) != 61 or len(doc.get("animations", [])) != 10:
        raise ValueError("The 61-joint rig and 10 imported clips must be preserved.")
    if extras.get("mantis_v8_frontleg_geometry", {}).get("total_foreleg_render_details") != 100:
        raise ValueError("Expected the v4.0 integrated 100-detail foreleg meshes.")

    for side, suffix in ((-1, "L"), (1, "R")):
        for prefix in ("Wing_", "WingVeinDetail_", "Hindwing_"):
            scale_surface(doc, binary, prefix + suffix, side=side)

    reshape_mesh(doc, binary, "Abdomen", (0.90, 0.80, 0.96))
    for index in range(6):
        reshape_mesh(doc, binary, f"AbdominalPlate_{index:02d}", (0.92, 0.88, 0.96))
    reshape_mesh(doc, binary, "Thorax", (1.04, 1.08, 1.10))
    reshape_mesh(doc, binary, "ThoraxSurfaceDetail", (1.04, 1.08, 1.10))
    sculpt_head(doc, binary, set())

    detached = 0
    for node in doc["nodes"]:
        name = node.get("name", "")
        if name.startswith(("Spine_L", "Spine_R")) and name[-1:] in "0123456":
            node.pop("mesh", None)
            node.pop("skin", None)
            detached += 1

    head_node = nodes["Head"]
    joint, weight = detail.node_joint_binding(doc, binary, head_node)
    mouth_index = detail.append_mesh(doc, binary, "MouthpartDetail", make_mouthparts(), joint, weight)
    detail.add_bound_node(doc, "MouthpartDetail", mouth_index, head_node)

    extras[PASS_MARKER] = {
        "wing_cover_width_scale": WING_X_SCALE,
        "wing_cover_length_scale": WING_Z_SCALE,
        "wing_cover_posterior_offset": WING_POSTERIOR_OFFSET,
        "abdomen_factors": [0.90, 0.80, 0.96],
        "thorax_factors": [1.04, 1.08, 1.10],
        "head_shape": "broad eye line, tapered anterior wedge",
        "eye_factors": [0.70, 0.73, 0.74],
        "mouthparts": "paired mandibles and maxillary palps",
        "legacy_spine_nodes_detached": detached,
        "foreleg_details_preserved": 100,
    }
    glb.write_glb(MODEL, doc, binary)
    print("Improved v4.4 mantis wing placement, chest/abdomen proportions, tapered face, and mouthparts; preserved the 100-detail forelegs and animation bank.")


if __name__ == "__main__":
    main()
