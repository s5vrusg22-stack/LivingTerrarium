#!/usr/bin/env python3
"""Sculpt high-resolution raptorial forelegs and 100 discrete surface details.

Run from the project root after the v3.9 mantis detail pass:
    python3 tools/refine_mantis_v8_forelegs.py

The existing four skinned foreleg meshes are rebuilt in place. Skin joints,
materials, animation clips, and scene nodes remain untouched.
"""
from __future__ import annotations

import math
import struct
from pathlib import Path

import upgrade_mantis_glb as glb


MODEL = glb.PROJECT / "assets" / "models" / "mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v7_80_detail"
MARKER = "photo_proportions_v8_forelegs_100"
FEMUR_AXIAL, FEMUR_RADIAL = 72, 24
TIBIA_AXIAL, TIBIA_RADIAL = 64, 20
MICRO_STRIAE = 15
FEMUR_SPINES, TIBIA_TEETH = 12, 8


def normalized_color(document: dict, binary: bytearray, accessor_index: int) -> tuple[float, ...]:
    accessor = document["accessors"][accessor_index]
    value = glb.read_vectors(document, binary, accessor_index)[0]
    if accessor.get("normalized") and accessor["componentType"] == 5121:
        return tuple(channel / 255.0 for channel in value)
    return tuple(value)


def append_accessor(document: dict, binary: bytearray, rows: list[tuple], *,
                    gl_type: str, fmt: str, target: int) -> int:
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
    component_type = {"f": 5126, "H": 5123}[fmt]
    accessor = {
        "bufferView": view_index, "componentType": component_type,
        "count": len(rows), "type": gl_type,
    }
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


def dot(a: tuple[float, ...], b: tuple[float, ...]) -> float:
    return sum(x * y for x, y in zip(a, b))


def add(a: tuple[float, ...], b: tuple[float, ...]) -> tuple[float, float, float]:
    return tuple(x + y for x, y in zip(a, b))


def scale(a: tuple[float, ...], amount: float) -> tuple[float, float, float]:
    return tuple(x * amount for x in a)


def subtract(a: tuple[float, ...], b: tuple[float, ...]) -> tuple[float, float, float]:
    return tuple(x - y for x, y in zip(a, b))


def cross(a: tuple[float, ...], b: tuple[float, ...]) -> tuple[float, float, float]:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(value: tuple[float, ...]) -> tuple[float, float, float]:
    length = math.sqrt(dot(value, value))
    if length < 1e-12:
        return (0.0, 1.0, 0.0)
    return tuple(component / length for component in value)


def principal_axis(points: list[tuple[float, ...]]) -> tuple[float, float, float]:
    center = tuple(sum(point[i] for point in points) / len(points) for i in range(3))
    centered = [subtract(point, center) for point in points]
    covariance = [[sum(point[i] * point[j] for point in centered) for j in range(3)] for i in range(3)]
    axis = (1.0, 0.73, -0.41)
    for _ in range(40):
        axis = unit(tuple(sum(covariance[i][j] * axis[j] for j in range(3)) for i in range(3)))
    return axis


def add_spike(positions: list[tuple[float, float, float]], indices: list[int],
              uv: list[tuple[float, float]], colors: list[tuple[float, float, float, float]],
              joints: list[tuple[int, int, int, int]], weights: list[tuple[float, float, float, float]],
              base: tuple[float, float, float], outward: tuple[float, float, float],
              across: tuple[float, float, float], length: float, width: float,
              joint_index: int, color: tuple[float, ...], phase: float) -> None:
    """Append one curved, ridged, pointed cuticle spine to the skinned limb."""
    forward = unit(add(outward, scale(across, 0.10 * math.sin(phase))))
    side_axis = unit(cross(forward, across))
    ring_sides = 7
    start = len(positions)
    for ring, (distance, radius) in enumerate(((0.0, width), (0.34, width * 0.66), (0.72, width * 0.30))):
        center = add(base, scale(forward, length * distance))
        center = add(center, scale(across, length * 0.08 * distance * distance))
        for j in range(ring_sides):
            angle = 2.0 * math.pi * j / ring_sides
            ridge = 1.0 + 0.08 * math.cos(3.0 * angle + phase)
            p = add(center, add(scale(side_axis, radius * math.cos(angle) * ridge), scale(across, radius * math.sin(angle) * ridge)))
            positions.append(p)
            uv.append((distance, j / ring_sides))
            shade = 0.74 + 0.08 * math.cos(angle * 2.0 + phase)
            colors.append(tuple(min(1.0, max(0.0, color[i] * shade)) for i in range(3)) + (color[3],))
            joints.append((joint_index, 0, 0, 0))
            weights.append((1.0, 0.0, 0.0, 0.0))
    tip_index = len(positions)
    tip = add(base, scale(forward, length))
    tip = add(tip, scale(across, length * 0.10))
    positions.append(tip)
    uv.append((1.0, 0.5))
    colors.append(tuple(min(1.0, max(0.0, c * 0.58)) for c in color[:3]) + (color[3],))
    joints.append((joint_index, 0, 0, 0))
    weights.append((1.0, 0.0, 0.0, 0.0))
    for ring in range(2):
        here = start + ring * ring_sides
        nxt = here + ring_sides
        for j in range(ring_sides):
            a, b = here + j, here + (j + 1) % ring_sides
            c, d = nxt + (j + 1) % ring_sides, nxt + j
            indices.extend((a, b, d, b, c, d))
    for j in range(ring_sides):
        indices.extend((start + 2 * ring_sides + j,
                        start + 2 * ring_sides + (j + 1) % ring_sides,
                        tip_index))


def foreleg_geometry(name: str, side: int, joint_index: int,
                     color: tuple[float, ...], reference_points: list[tuple[float, ...]]):
    is_femur = name.startswith("ForeFemur")
    length_steps = FEMUR_AXIAL if is_femur else TIBIA_AXIAL
    radial_steps = FEMUR_RADIAL if is_femur else TIBIA_RADIAL
    axis = principal_axis(reference_points)
    # Keep the distal femur end aligned toward its tibial joint.
    if is_femur:
        direction = (float(side), -0.38, -0.62)
        if dot(axis, direction) < 0.0:
            axis = scale(axis, -1.0)
    elif axis[0] < 0.0:
        axis = scale(axis, -1.0)
    inward_candidate = (float(-side), 0.0, 0.0)
    inward = unit(subtract(inward_candidate, scale(axis, dot(inward_candidate, axis))))
    dorsal = unit(subtract((0.0, 1.0, 0.0), scale(axis, axis[1])))
    if math.sqrt(dot(dorsal, dorsal)) < 0.5:
        dorsal = unit(cross(axis, inward))
    across = unit(cross(axis, inward))
    if dot(across, dorsal) < 0.0:
        across = scale(across, -1.0)
    # Extend slightly past the previous generic spindle so the grasping plate
    # reads as a long raptorial limb in the hand-held reference proportions.
    length = max(abs(dot(point, axis)) for point in reference_points) * 1.08
    inner_radius = 0.052 if is_femur else 0.029
    dorsal_radius = 0.030 if is_femur else 0.021
    ring_count = radial_steps
    positions: list[tuple[float, float, float]] = []
    indices: list[int] = []
    uv: list[tuple[float, float]] = []
    colors: list[tuple[float, float, float, float]] = []
    joints: list[tuple[int, int, int, int]] = []
    weights: list[tuple[float, float, float, float]] = []

    # Fifteen narrow raised cuticle striae are carried in the swept surface.
    stria_angles = [(-1.18 + i * 2.36 / (MICRO_STRIAE - 1)) for i in range(MICRO_STRIAE)]
    for i in range(length_steps + 1):
        u = i / length_steps
        end_taper = max(0.0, math.sin(math.pi * u)) ** (0.58 if is_femur else 0.72)
        bulb = 0.78 + 0.22 * math.sin(math.pi * u) if is_femur else 0.82 + 0.18 * math.sin(math.pi * u)
        longitudinal = (0.045 + 0.955 * end_taper) * bulb
        center = scale(axis, (2.0 * u - 1.0) * length)
        if not is_femur:
            # A barely perceptible inward bow follows the sickle-like tibial profile.
            center = add(center, scale(inward, 0.012 * math.sin(math.pi * u)))
        for j in range(ring_count):
            theta = 2.0 * math.pi * j / ring_count
            cos_t, sin_t = math.cos(theta), math.sin(theta)
            radius_inner = inner_radius * longitudinal
            radius_dorsal = dorsal_radius * longitudinal
            base_radius = math.sqrt((radius_inner * cos_t) ** 2 + (radius_dorsal * sin_t) ** 2)
            relief = 0.0
            for ridge_i, ridge_angle in enumerate(stria_angles):
                angular_delta = (theta - ridge_angle + math.pi) % (2.0 * math.pi) - math.pi
                ridge_width = 0.036 if is_femur else 0.030
                relief += (0.065 if is_femur else 0.050) * math.exp(-((angular_delta / ridge_width) ** 2))
            keel = (0.11 if is_femur else 0.07) * max(0.0, sin_t) ** 10
            radius = base_radius * (1.0 + min(relief, 0.24) + keel)
            p = add(center, add(scale(inward, radius * cos_t), scale(dorsal, radius * sin_t)))
            positions.append(p)
            uv.append((u, j / ring_count))
            vein_shade = 1.0 + min(0.045, relief * 0.16) + keel * 0.12
            end_shade = 0.88 + 0.12 * end_taper
            colors.append(tuple(min(1.0, max(0.0, color[k] * vein_shade * end_shade)) for k in range(3)) + (color[3],))
            joints.append((joint_index, 0, 0, 0))
            weights.append((1.0, 0.0, 0.0, 0.0))
    for i in range(length_steps):
        for j in range(ring_count):
            a = i * ring_count + j
            b = i * ring_count + (j + 1) % ring_count
            c = (i + 1) * ring_count + (j + 1) % ring_count
            d = (i + 1) * ring_count + j
            indices.extend((a, b, c, a, c, d))

    # Seal the tapered tips with weighted center vertices.
    cap_start = len(positions)
    for u in (0.0, 1.0):
        p = scale(axis, (2.0 * u - 1.0) * length)
        if not is_femur:
            p = add(p, scale(inward, 0.012 * math.sin(math.pi * u)))
        positions.append(p)
        uv.append((u, 0.5))
        colors.append(color)
        joints.append((joint_index, 0, 0, 0))
        weights.append((1.0, 0.0, 0.0, 0.0))
    for j in range(ring_count):
        indices.extend((cap_start, (j + 1) % ring_count, j))
        last_ring = length_steps * ring_count
        indices.extend((cap_start + 1, last_ring + j, last_ring + (j + 1) % ring_count))

    spine_count = FEMUR_SPINES if is_femur else TIBIA_TEETH
    # One inner-edge tooth row on the femur and the opposing tibia.
    for tooth in range(spine_count):
        u = (0.15 + 0.70 * (tooth + 0.5) / spine_count)
        longitudinal = max(0.0, math.sin(math.pi * u)) ** (0.58 if is_femur else 0.72)
        body_radius = inner_radius * longitudinal
        body_radius += dorsal_radius * 0.04
        center = scale(axis, (2.0 * u - 1.0) * length)
        if not is_femur:
            center = add(center, scale(inward, 0.012 * math.sin(math.pi * u)))
        base = add(center, scale(inward, body_radius * 0.93))
        if is_femur:
            direction = unit(add(scale(inward, 0.79), scale(axis, 0.61)))
            tooth_length = 0.030 + 0.009 * (0.5 + 0.5 * math.sin(tooth * 1.37))
            tooth_width = 0.0062 + 0.0011 * (tooth % 3)
        else:
            direction = unit(add(scale(inward, 0.86), scale(axis, -0.51)))
            tooth_length = 0.026 + 0.008 * (0.5 + 0.5 * math.cos(tooth * 1.61))
            tooth_width = 0.0045 + 0.0008 * (tooth % 2)
        add_spike(positions, indices, uv, colors, joints, weights, base, direction,
                  across, tooth_length, tooth_width, joint_index, color, tooth * 0.71)

    normals = glb.vertex_normals(positions, indices)
    return positions, indices, normals, uv, colors, joints, weights


def finish_primitive(document: dict, binary: bytearray, primitive: dict, geometry) -> None:
    positions, indices, normals, uv, colors, joints, weights = geometry
    primitive["attributes"] = {
        "POSITION": append_accessor(document, binary, positions, gl_type="VEC3", fmt="f", target=34962),
        "NORMAL": append_accessor(document, binary, normals, gl_type="VEC3", fmt="f", target=34962),
        "TEXCOORD_0": append_accessor(document, binary, uv, gl_type="VEC2", fmt="f", target=34962),
        "COLOR_0": append_accessor(document, binary, colors, gl_type="VEC4", fmt="f", target=34962),
        "JOINTS_0": append_accessor(document, binary, joints, gl_type="VEC4", fmt="H", target=34962),
        "WEIGHTS_0": append_accessor(document, binary, weights, gl_type="VEC4", fmt="f", target=34962),
    }
    primitive["indices"] = append_accessor(
        document, binary, [(index,) for index in indices], gl_type="SCALAR", fmt="H", target=34963,
    )
    primitive["mode"] = 4


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker == MARKER:
        print("The v7 foreleg rebuild is already applied; leaving the GLB unchanged.")
        return
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to rebuild an unknown base.")

    meshes = {mesh.get("name"): mesh for mesh in document.get("meshes", [])}
    expected = {"ForeFemur_L", "ForeFemur_R", "ForeTibia_L", "ForeTibia_R"}
    if not expected.issubset(meshes):
        raise ValueError("The four skinned raptorial foreleg segment meshes are required.")
    if len(document.get("skins", [{}])[0].get("joints", [])) != 61 or len(document.get("animations", [])) != 10:
        raise ValueError("The v3.6 skeleton and 10 existing clips must be preserved.")

    for name in sorted(expected):
        mesh = meshes[name]
        if len(mesh.get("primitives", [])) != 1:
            raise ValueError(f"Expected one primitive in {name}; refusing to discard material slots.")
        primitive = mesh["primitives"][0]
        attrs = primitive["attributes"]
        source_points = glb.read_vectors(document, binary, attrs["POSITION"])
        joint_rows = glb.read_vectors(document, binary, attrs["JOINTS_0"])
        joint_index = int(round(joint_rows[0][0]))
        color = normalized_color(document, binary, attrs["COLOR_0"])
        side = -1 if name.endswith("_L") else 1
        finish_primitive(document, binary, primitive,
                         foreleg_geometry(name, side, joint_index, color, source_points))

    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v8_frontleg_geometry"] = {
        "femur_axial_segments": FEMUR_AXIAL,
        "femur_radial_segments": FEMUR_RADIAL,
        "tibia_axial_segments": TIBIA_AXIAL,
        "tibia_radial_segments": TIBIA_RADIAL,
        "fine_cuticle_striae_per_segment": MICRO_STRIAE,
        "femoral_spines_per_side": FEMUR_SPINES,
        "tibial_teeth_per_side": TIBIA_TEETH,
        "discrete_grasping_spines": FEMUR_SPINES * 2,
        "discrete_tibial_teeth": TIBIA_TEETH * 2,
        "raised_cuticle_striae": MICRO_STRIAE * 4,
        "total_foreleg_render_details": FEMUR_SPINES * 2 + TIBIA_TEETH * 2 + MICRO_STRIAE * 4,
        "segments": ["ForeFemur_L", "ForeFemur_R", "ForeTibia_L", "ForeTibia_R"],
        "surface_relief": ["raised longitudinal carinae", "cuticle striae", "paired tooth rows", "tapered joint ends"],
    }
    glb.write_glb(MODEL, document, binary)
    print("Rebuilt the four skinned foreleg segments with 100 rendered details; retained v3.9 meshes, rig, and clips.")


if __name__ == "__main__":
    main()
