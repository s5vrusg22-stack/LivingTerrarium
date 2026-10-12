#!/usr/bin/env python3
"""Rebuild the thorax shield and paired tegmina as high-density skinned meshes.

Run after refine_mantis_v5.py from the project root:
    python3 tools/refine_mantis_v6.py

The rig, animation clips, material pipeline, and scene nodes are retained.
"""
from __future__ import annotations

import math
import struct

import upgrade_mantis_glb as glb


MODEL = glb.PROJECT / "assets" / "models" / "mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v5"
MARKER = "photo_proportions_v6"


def append_accessor(document: dict, binary: bytearray, rows: list[tuple],
                    *, gl_type: str, component_type: int, fmt: str,
                    target: int, normalized: bool = False) -> int:
    glb.align4(binary)
    offset = len(binary)
    packer = struct.Struct("<" + fmt * len(rows[0]))
    for row in rows:
        binary.extend(packer.pack(*row))
    view_index = len(document["bufferViews"])
    document["bufferViews"].append({
        "buffer": 0, "byteOffset": offset, "byteLength": len(rows) * packer.size,
        "target": target,
    })
    accessor = {
        "bufferView": view_index, "componentType": component_type,
        "count": len(rows), "type": gl_type,
    }
    if normalized:
        accessor["normalized"] = True
    if gl_type != "SCALAR":
        width = len(rows[0])
        accessor["min"] = [min(float(row[i]) for row in rows) for i in range(width)]
        accessor["max"] = [max(float(row[i]) for row in rows) for i in range(width)]
    elif rows:
        accessor["min"] = [min(int(row[0]) for row in rows)]
        accessor["max"] = [max(int(row[0]) for row in rows)]
    accessor_index = len(document["accessors"])
    document["accessors"].append(accessor)
    return accessor_index


def unit(value: tuple[float, ...]) -> tuple[float, ...]:
    length = math.sqrt(sum(component * component for component in value))
    if length < 1e-12:
        return (0.0, 1.0, 0.0)
    return tuple(component / length for component in value)


def normalized_color(document: dict, binary: bytearray, accessor_index: int) -> tuple[float, ...]:
    accessor = document["accessors"][accessor_index]
    value = glb.read_vectors(document, binary, accessor_index)[0]
    if accessor.get("normalized") and accessor["componentType"] == 5121:
        return tuple(channel / 255.0 for channel in value)
    return tuple(value)


def finish_primitive(document: dict, binary: bytearray, primitive: dict,
                     positions: list[tuple[float, float, float]],
                     indices: list[int], uv: list[tuple[float, float]],
                     colors: list[tuple[float, float, float, float]],
                     joints: list[tuple[int, int, int, int]],
                     weights: list[tuple[float, float, float, float]]) -> None:
    normals = glb.vertex_normals(positions, indices)
    primitive["attributes"] = {
        "POSITION": append_accessor(document, binary, positions, gl_type="VEC3", component_type=5126, fmt="f", target=34962),
        "NORMAL": append_accessor(document, binary, normals, gl_type="VEC3", component_type=5126, fmt="f", target=34962),
        "TEXCOORD_0": append_accessor(document, binary, uv, gl_type="VEC2", component_type=5126, fmt="f", target=34962),
        "COLOR_0": append_accessor(document, binary, colors, gl_type="VEC4", component_type=5126, fmt="f", target=34962),
        "JOINTS_0": append_accessor(document, binary, joints, gl_type="VEC4", component_type=5123, fmt="H", target=34962),
        "WEIGHTS_0": append_accessor(document, binary, weights, gl_type="VEC4", component_type=5126, fmt="f", target=34962),
    }
    primitive["indices"] = append_accessor(
        document, binary, [(index,) for index in indices],
        gl_type="SCALAR", component_type=5123, fmt="H", target=34963,
    )
    primitive["mode"] = 4


def wing_geometry(side: int, joint_index: int, color: tuple[float, ...]):
    """Build one leaf-like forewing with 80 longitudinal and 24 lateral cuts."""
    length_steps, width_steps = 80, 24
    columns = width_steps + 1
    surface_count = (length_steps + 1) * columns
    positions: list[tuple[float, float, float]] = []
    uv: list[tuple[float, float]] = []
    colors: list[tuple[float, float, float, float]] = []
    joints: list[tuple[int, int, int, int]] = []
    weights: list[tuple[float, float, float, float]] = []

    def index(i: int, j: int, underside: bool = False) -> int:
        return i * columns + j + (surface_count if underside else 0)

    def point(u: float, across: float, underside: bool) -> tuple[float, float, float]:
        sin_u = max(0.0, math.sin(math.pi * u))
        # The rear end narrows more sharply than the rounded leading shoulder.
        outline = sin_u ** 0.74 * (0.88 + 0.12 * math.cos(math.pi * (u - 0.10)))
        outward = 0.145 * outline * across
        x = side * outward - side * 0.075  # cancel the wing node's bind-pose offset
        centerline = 0.004 * math.sin(2.0 * math.pi * u) * sin_u
        camber = 0.012 * math.sin(math.pi * across) * sin_u ** 0.70
        midrib = 0.0048 * math.exp(-((across - 0.50) / 0.035) ** 2) * sin_u ** 0.60
        secondary = 0.0
        for band, height in ((0.24, 0.0018), (0.39, 0.00145), (0.62, 0.00145), (0.78, 0.0012), (0.92, 0.0009)):
            curve = band * (0.92 + 0.08 * math.sin(math.pi * u))
            secondary += height * math.exp(-((across - curve) / 0.022) ** 2) * sin_u ** 0.62
        cross_phase = u * 22.0 - across * 0.42
        distance = abs((cross_phase + 0.5) % 1.0 - 0.5)
        crossvein = 0.00075 * math.exp(-((distance / 0.075) ** 2)) * math.sin(math.pi * across) * sin_u ** 0.45
        relief = camber + midrib + secondary + crossvein
        thickness = 0.0017
        return (x, 0.006 + centerline + relief + (-thickness if underside else thickness), (u - 0.5) * 1.02)

    for underside in (False, True):
        for i in range(length_steps + 1):
            u = i / length_steps
            for j in range(columns):
                across = j / width_steps
                positions.append(point(u, across, underside))
                uv.append((across, u))
                weave = 1.0 + 0.018 * math.sin((u * 22.0 - across * 0.42) * 2.0 * math.pi)
                dorsal = (0.985 + 0.025 * math.sin(math.pi * across)) if not underside else 0.86
                vein_tint = 0.955 if not underside and (abs(across - 0.50) < 0.032 or abs(across - 0.24) < 0.020 or abs(across - 0.78) < 0.018) else 1.0
                colors.append((
                    min(1.0, max(0.0, color[0] * dorsal * weave * vein_tint)),
                    min(1.0, max(0.0, color[1] * dorsal * weave * vein_tint)),
                    min(1.0, max(0.0, color[2] * dorsal * weave * vein_tint)),
                    color[3],
                ))
                joints.append((joint_index, 0, 0, 0))
                weights.append((1.0, 0.0, 0.0, 0.0))

    indices: list[int] = []
    for i in range(length_steps):
        for j in range(width_steps):
            a, b = index(i, j), index(i, j + 1)
            c, d = index(i + 1, j + 1), index(i + 1, j)
            if side > 0:
                top = (a, d, c, a, c, b)
            else:
                top = (a, b, c, a, c, d)
            indices.extend(top)
            a, b = index(i, j, True), index(i, j + 1, True)
            c, d = index(i + 1, j + 1, True), index(i + 1, j, True)
            indices.extend((a, c, d, a, b, c) if side > 0 else (a, d, c, a, c, b))

    # Close the thin cuticle along both leaf margins and both tips.
    for i in range(length_steps):
        for j in (0, width_steps):
            a, b = index(i, j), index(i + 1, j)
            c, d = index(i + 1, j, True), index(i, j, True)
            indices.extend((a, b, c, a, c, d))
    for j in range(width_steps):
        for i in (0, length_steps):
            a, b = index(i, j), index(i, j + 1)
            c, d = index(i, j + 1, True), index(i, j, True)
            indices.extend((a, b, c, a, c, d))
    return positions, indices, uv, colors, joints, weights


def thorax_geometry(joint_index: int, color: tuple[float, ...]):
    """An elongated pronotal shield with a keel, paired carinae, and collars."""
    length_steps, ring_steps = 80, 24
    columns = ring_steps
    positions: list[tuple[float, float, float]] = []
    uv: list[tuple[float, float]] = []
    colors: list[tuple[float, float, float, float]] = []
    joints: list[tuple[int, int, int, int]] = []
    weights: list[tuple[float, float, float, float]] = []

    for i in range(length_steps + 1):
        u = i / length_steps
        z = -0.338 + 0.676 * u
        center_y = 0.0746 * (1.0 - 2.0 * u)
        profile = 0.88 + 0.12 * math.sin(math.pi * u) ** 0.65
        collar_groove = 0.045 * (math.exp(-((u - 0.095) / 0.012) ** 2) + math.exp(-((u - 0.925) / 0.014) ** 2))
        collar_lip = 0.030 * (math.exp(-((u - 0.072) / 0.018) ** 2) + math.exp(-((u - 0.895) / 0.020) ** 2))
        for j in range(ring_steps):
            phi = 2.0 * math.pi * j / ring_steps
            sn, cs = math.sin(phi), math.cos(phi)
            dorsal = max(0.0, cs)
            width = 0.058 * profile * (1.0 - collar_groove + collar_lip)
            height = 0.068 * profile * (1.0 - collar_groove + collar_lip)
            keel = 0.0085 * dorsal ** 8 * math.sin(math.pi * u) ** 0.45
            lateral_carina = 0.0032 * math.exp(-((abs(sn) - 0.66) / 0.055) ** 2) * dorsal
            positions.append((width * sn, center_y + height * cs + keel + lateral_carina, z))
            uv.append((j / ring_steps, u))
            groove_shade = 1.0 - 0.075 * math.exp(-((u - 0.095) / 0.014) ** 2) - 0.075 * math.exp(-((u - 0.925) / 0.016) ** 2)
            dorsal_shade = 0.84 + 0.16 * dorsal + 0.04 * dorsal ** 10
            carina_shade = 1.035 if abs(abs(sn) - 0.66) < 0.055 and dorsal > 0.20 else 1.0
            colors.append(tuple(
                min(1.0, max(0.0, color[channel] * groove_shade * dorsal_shade * carina_shade))
                for channel in range(3)
            ) + (color[3],))
            joints.append((joint_index, 0, 0, 0))
            weights.append((1.0, 0.0, 0.0, 0.0))

    indices: list[int] = []
    for i in range(length_steps):
        for j in range(ring_steps):
            a = i * columns + j
            b = i * columns + (j + 1) % columns
            c = (i + 1) * columns + (j + 1) % columns
            d = (i + 1) * columns + j
            # Axial then radial winding points out from the pronotum surface.
            indices.extend((a, d, c, a, c, b))

    # Small end caps keep the raised shield watertight in profile views.
    start_center = len(positions)
    positions.append((0.0, 0.0746, -0.338))
    uv.append((0.5, 0.0)); colors.append(color)
    joints.append((joint_index, 0, 0, 0)); weights.append((1.0, 0.0, 0.0, 0.0))
    end_center = len(positions)
    positions.append((0.0, -0.0746, 0.338))
    uv.append((0.5, 1.0)); colors.append(color)
    joints.append((joint_index, 0, 0, 0)); weights.append((1.0, 0.0, 0.0, 0.0))
    for j in range(ring_steps):
        nxt = (j + 1) % ring_steps
        indices.extend((start_center, j, nxt))
        a, b = length_steps * columns + j, length_steps * columns + nxt
        indices.extend((end_center, b, a))
    return positions, indices, uv, colors, joints, weights


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker in {MARKER, "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100"}:
        print("The v6 thorax and wing rebuild or a later pass is already applied; leaving the GLB unchanged.")
        return
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to rebuild an unknown base.")

    meshes = {mesh.get("name"): mesh for mesh in document.get("meshes", [])}
    if not {"Thorax", "Wing_L", "Wing_R"}.issubset(meshes):
        raise ValueError("Expected the Thorax mesh and both skinned Wing_L/Wing_R meshes.")

    for name in ("Thorax", "Wing_L", "Wing_R"):
        mesh = meshes[name]
        if len(mesh.get("primitives", [])) != 1:
            raise ValueError(f"Expected one primitive in {name}; refusing to lose material slots.")
        primitive = mesh["primitives"][0]
        attributes = primitive["attributes"]
        joint_rows = glb.read_vectors(document, binary, attributes["JOINTS_0"])
        joint_index = int(round(joint_rows[0][0]))
        color = normalized_color(document, binary, attributes["COLOR_0"])
        geometry = thorax_geometry(joint_index, color) if name == "Thorax" else wing_geometry(
            -1 if name.endswith("L") else 1, joint_index, color,
        )
        finish_primitive(document, binary, primitive, *geometry)

    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v6_geometry"] = {
        "wing_length_segments": 80,
        "wing_width_segments": 24,
        "pronotum_length_segments": 80,
        "pronotum_ring_segments": 24,
        "raised_wing_vein_sets": 6,
        "thorax_features": ["dorsal_keel", "paired_carinae", "collar_grooves"],
    }
    glb.write_glb(MODEL, document, binary)
    print("Rebuilt 80x24 tegmina and an 80x24 ridged pronotum; retained rig and animations.")


if __name__ == "__main__":
    main()
