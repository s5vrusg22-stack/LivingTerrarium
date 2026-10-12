#!/usr/bin/env python3
"""Give the photo-guided mantis a slim prothorax and a real two-hinge foreleg chain.

Run from the project root after the v4.6 photo-foreleg pass:
    python3 tools/refine_mantis_v11_two_hinge_forelegs.py

Each foreleg now reads as a thorax-attached coxa, a broad spined femur, and a
folding toothed tibia. The femur and tibia pivots form two visible, animated
hinges. Existing animation clips, skeleton size, wing meshes, and habitats stay.
"""
from __future__ import annotations

import math
import struct
from pathlib import Path

import upgrade_mantis_glb as glb
import refine_mantis_v10_photo_forelegs as v10


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v10_photo_forelegs_100"
MARKER = "photo_proportions_v11_two_hinge_forelegs_slim_pronotum"
FEMUR_AXIAL, FEMUR_RADIAL = 72, 24
TIBIA_AXIAL, TIBIA_RADIAL = 64, 20
RIDGES_PER_SEGMENT = 9
FEMUR_SPINES, TIBIA_TEETH = 18, 14


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def unit(v):
    length = math.sqrt(dot(v, v))
    if length < 1e-10:
        return (0.0, 1.0, 0.0)
    return mul(v, 1.0 / length)


def lerp(a, b, t):
    return add(mul(a, 1.0 - t), mul(b, t))


def translation_matrix(position):
    x, y, z = position
    return [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            float(x), float(y), float(z), 1.0]


def translation(node):
    matrix = node.get("matrix")
    if matrix:
        return (float(matrix[12]), float(matrix[13]), float(matrix[14]))
    return tuple(float(v) for v in node.get("translation", (0.0, 0.0, 0.0)))


def set_translation(node, position):
    node["matrix"] = translation_matrix(position)
    node.pop("translation", None)
    node.pop("rotation", None)
    node.pop("scale", None)


def normalized_color(document, binary, accessor_index):
    accessor = document["accessors"][accessor_index]
    value = glb.read_vectors(document, binary, accessor_index)[0]
    if accessor.get("normalized") and accessor["componentType"] == 5121:
        value = tuple(channel / 255.0 for channel in value)
    return tuple(value)


def append_accessor(document, binary, rows, *, gl_type, fmt, target):
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
        accessor["min"] = [min(float(row[i]) for row in rows) for i in range(len(rows[0]))]
        accessor["max"] = [max(float(row[i]) for row in rows) for i in range(len(rows[0]))]
    else:
        accessor["min"] = [min(int(row[0]) for row in rows)]
        accessor["max"] = [max(int(row[0]) for row in rows)]
    index = len(document["accessors"])
    document["accessors"].append(accessor)
    return index


def finish_primitive(document, binary, positions, indices, uv, colors, joints, weights, material):
    primitive = {
        "attributes": {
            "POSITION": append_accessor(document, binary, positions, gl_type="VEC3", fmt="f", target=34962),
            "NORMAL": append_accessor(document, binary, glb.vertex_normals(positions, indices), gl_type="VEC3", fmt="f", target=34962),
            "TEXCOORD_0": append_accessor(document, binary, uv, gl_type="VEC2", fmt="f", target=34962),
            "COLOR_0": append_accessor(document, binary, colors, gl_type="VEC4", fmt="f", target=34962),
            "JOINTS_0": append_accessor(document, binary, joints, gl_type="VEC4", fmt="H", target=34962),
            "WEIGHTS_0": append_accessor(document, binary, weights, gl_type="VEC4", fmt="f", target=34962),
        },
        "indices": append_accessor(document, binary, [(i,) for i in indices], gl_type="SCALAR", fmt="H", target=34963),
        "mode": 4,
    }
    if material is not None:
        primitive["material"] = material
    return primitive


def append_vertex(positions, indices, uv, colors, joints, weights,
                  position, texcoord, color, joint_index):
    positions.append(tuple(position))
    uv.append(tuple(texcoord))
    colors.append(tuple(color))
    joints.append((joint_index, 0, 0, 0))
    weights.append((1.0, 0.0, 0.0, 0.0))


def add_sphere(positions, indices, uv, colors, joints, weights,
               center, radius, joint_index, color, rings=8, sides=14):
    start = len(positions)
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(sides):
            theta = 2.0 * math.pi * j / sides
            normal = (math.sin(phi) * math.cos(theta),
                      math.cos(phi),
                      math.sin(phi) * math.sin(theta))
            shade = 0.86 + 0.14 * max(0.0, normal[1])
            point = add(center, mul(normal, radius))
            append_vertex(positions, indices, uv, colors, joints, weights, point,
                          (j / sides, i / rings),
                          tuple(min(1.0, c * shade) for c in color[:3]) + (color[3],),
                          joint_index)
    for i in range(rings):
        for j in range(sides):
            a = start + i * sides + j
            b = start + i * sides + (j + 1) % sides
            c = start + (i + 1) * sides + (j + 1) % sides
            d = start + (i + 1) * sides + j
            indices.extend((a, d, b, b, d, c))


def nearest_on_curve(point, curve, steps=56):
    best = None
    best_distance = float("inf")
    for i in range(steps + 1):
        candidate = curve(i / steps)
        distance = dot(sub(candidate, point), sub(candidate, point))
        if distance < best_distance:
            best, best_distance = candidate, distance
    return best


def make_limb_geometry(name, side, joint_index, color, start_world, end_world,
                       other_curve, inner_joint_radius, mirror_front_back=False):
    is_femur = name.startswith("ForeFemur")
    axial, radial = (FEMUR_AXIAL, FEMUR_RADIAL) if is_femur else (TIBIA_AXIAL, TIBIA_RADIAL)
    axis = unit(sub(end_world, start_world))
    lateral_seed = (float(side), 0.0, 0.0)
    lateral = unit(sub(lateral_seed, mul(axis, dot(lateral_seed, axis))))
    broad = unit(cross(axis, lateral))
    if dot(broad, (0.0, 1.0, 0.0)) < 0.0:
        broad = mul(broad, -1.0)

    bow = (0.0, 0.0, 0.0)
    if not is_femur:
        middle = lerp(start_world, end_world, 0.5)
        toward_femur = sub(nearest_on_curve(middle, other_curve), middle)
        toward_femur = sub(toward_femur, mul(axis, dot(toward_femur, axis)))
        if dot(toward_femur, toward_femur) > 1e-8:
            bow = mul(unit(toward_femur), 0.009)

    def center_global(u):
        return add(lerp(start_world, end_world, u), mul(bow, math.sin(math.pi * u)))

    def profile(u):
        wave = max(0.0, math.sin(math.pi * u))
        if is_femur:
            fullness = wave ** 0.58
            width = 0.009 + 0.030 * fullness
            thickness = 0.0045 + 0.009 * fullness
            hinge_pad = 1.0 + 0.13 * math.exp(-(((u - 0.87) / 0.10) ** 2))
            return width * hinge_pad, thickness * hinge_pad
        fullness = wave ** 0.68
        width = 0.0035 + 0.0055 * fullness
        thickness = 0.0025 + 0.0035 * fullness
        return width, thickness

    positions, indices, uv, colors, joints, weights = [], [], [], [], [], []
    ridge_angles = [0.22 + i * (math.pi - 0.44) / (RIDGES_PER_SEGMENT - 1)
                    for i in range(RIDGES_PER_SEGMENT)]
    for i in range(axial + 1):
        u = i / axial
        width, thickness = profile(u)
        center = sub(center_global(u), start_world)
        wave = max(0.0, math.sin(math.pi * u))
        for j in range(radial):
            theta = 2.0 * math.pi * j / radial
            cs, sn = math.cos(theta), math.sin(theta)
            exponent = 3.0 if is_femur else 2.15
            shaped_broad = math.copysign(abs(cs) ** (2.0 / exponent), cs)
            shaped_lateral = math.copysign(abs(sn) ** (2.0 / exponent), sn)
            relief = 0.0
            for ridge_index, angle in enumerate(ridge_angles):
                delta = (theta - angle + math.pi) % (2.0 * math.pi) - math.pi
                strength = 0.13 if is_femur else 0.09
                if ridge_index == RIDGES_PER_SEGMENT // 2:
                    strength *= 1.25
                relief += strength * math.exp(-((delta / (0.060 if is_femur else 0.045)) ** 2))
            p = add(center, add(mul(broad, width * shaped_broad * (1.0 + min(relief, 0.34))),
                                mul(lateral, thickness * shaped_lateral * (1.0 + min(relief, 0.34)))))
            color_gain = 0.86 + 0.14 * wave + min(0.08, relief * 0.16)
            append_vertex(positions, indices, uv, colors, joints, weights, p, (u, j / radial),
                          tuple(min(1.0, channel * color_gain) for channel in color[:3]) + (color[3],),
                          joint_index)
    for i in range(axial):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            indices.extend((a, b, c, a, c, d))

    # A rounded cap is the first unmistakable hinge; the second is the tibia's knee.
    if inner_joint_radius > 0.0:
        joint_color = tuple(min(1.0, channel * 1.12) for channel in color[:3]) + (color[3],)
        add_sphere(positions, indices, uv, colors, joints, weights, (0.0, 0.0, 0.0),
                   inner_joint_radius, joint_index, joint_color)

    spine_count = FEMUR_SPINES if is_femur else TIBIA_TEETH
    for tooth in range(spine_count):
        u = 0.14 + 0.72 * (tooth + 0.5) / spine_count
        center_global_point = center_global(u)
        toward_other = sub(nearest_on_curve(center_global_point, other_curve), center_global_point)
        toward_other = sub(toward_other, mul(axis, dot(toward_other, axis)))
        if dot(toward_other, toward_other) < 1e-8:
            toward_other = broad
        outward = unit(toward_other)
        width, _ = profile(u)
        sign = 1.0 if dot(outward, broad) >= 0.0 else -1.0
        base_global = add(center_global_point, mul(broad, sign * width * 0.93))
        base = sub(base_global, start_world)
        if is_femur:
            length = 0.030 + 0.009 * (0.5 + 0.5 * math.sin(tooth * 1.37))
            tooth_width = 0.0048 + 0.0008 * (tooth % 3)
        else:
            length = 0.024 + 0.008 * (0.5 + 0.5 * math.cos(tooth * 1.61))
            tooth_width = 0.0038 + 0.0007 * (tooth % 2)
        v10.add_spike(positions, indices, uv, colors, joints, weights, base,
                      outward, broad, length, tooth_width, joint_index, color, tooth * 0.69)

    if not is_femur:
        # A short downward tarsal hook continues past the second hinge without adding
        # a third animated joint.
        tip = sub(end_world, start_world)
        hook_direction = unit((0.0, -0.84, 0.54 if mirror_front_back else -0.54))
        v10.add_spike(positions, indices, uv, colors, joints, weights, tip,
                      hook_direction, broad, 0.060, 0.0032, joint_index, color, 0.6)

    return positions, indices, uv, colors, joints, weights


def make_coxa_geometry(joint_index, color, start_world, end_world, body_origin,
                       thickness_scale=1.0, socket_radius=0.0):
    axis_vector = sub(end_world, start_world)
    axis = unit(axis_vector)
    lateral = unit(sub((1.0, 0.0, 0.0), mul(axis, axis[0])))
    broad = unit(cross(axis, lateral))
    axial, radial = 44, 20
    positions, indices, uv, colors, joints, weights = [], [], [], [], [], []
    for i in range(axial + 1):
        u = i / axial
        center = sub(lerp(start_world, end_world, u), body_origin)
        fullness = 0.72 + 0.28 * math.sin(math.pi * u)
        if u < 0.08:
            fullness *= 0.93 + 0.07 * u / 0.08
        if u > 0.90:
            fullness *= 0.92 + 0.08 * (1.0 - u) / 0.10
        width = 0.0105 * fullness * thickness_scale
        depth = 0.0070 * fullness * thickness_scale
        for j in range(radial):
            theta = 2.0 * math.pi * j / radial
            p = add(center, add(mul(broad, width * math.cos(theta)),
                                mul(lateral, depth * math.sin(theta))))
            gain = 0.90 + 0.10 * max(0.0, math.cos(theta))
            append_vertex(positions, indices, uv, colors, joints, weights, p,
                          (u, j / radial),
                          tuple(min(1.0, c * gain) for c in color[:3]) + (color[3],),
                          joint_index)
    for i in range(axial):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            indices.extend((a, b, c, a, c, d))
    if socket_radius > 0.0:
        socket_center = sub(start_world, body_origin)
        socket_color = tuple(min(1.0, channel * 1.04) for channel in color[:3]) + (color[3],)
        add_sphere(positions, indices, uv, colors, joints, weights,
                   socket_center, socket_radius, joint_index, socket_color)
    return positions, indices, uv, colors, joints, weights


def add_mesh_and_node(document, binary, world_node, name, geometry, material, skin_index,
                      node_matrix):
    positions, indices, uv, colors, joints, weights = geometry
    primitive = finish_primitive(document, binary, positions, indices, uv, colors, joints, weights, material)
    mesh_index = len(document["meshes"])
    document["meshes"].append({"name": name, "primitives": [primitive]})
    node = {"name": name, "mesh": mesh_index, "skin": skin_index, "matrix": list(node_matrix)}
    node_index = len(document["nodes"])
    document["nodes"].append(node)
    world_node.setdefault("children", []).append(node_index)
    return node_index


def update_thorax_profile(document, binary, meshes):
    z_front, z_back = -0.372, 0.372
    changed = {}
    for name in ("Thorax", "ThoraxSurfaceDetail"):
        mesh = meshes[name]
        for primitive in mesh.get("primitives", []):
            attrs = primitive["attributes"]
            accessor = attrs["POSITION"]
            points = glb.read_vectors(document, binary, accessor)
            reshaped = []
            for x, y, z in points:
                u = max(0.0, min(1.0, (z - z_front) / (z_back - z_front)))
                smooth = u * u * (3.0 - 2.0 * u)
                # The head-side third becomes a slim pronotum; the rear collar retains
                # enough width to blend into the wings and abdomen.
                x_factor = 0.70 + 0.15 * smooth
                y_factor = 0.30 + 0.25 * smooth
                reshaped.append((x * x_factor, y * y_factor, z))
            glb.write_vectors(document, binary, accessor, reshaped)
            if "NORMAL" in attrs:
                normals = glb.vertex_normals(reshaped, glb.read_indices(document, binary, primitive["indices"]))
                glb.write_vectors(document, binary, attrs["NORMAL"], normals)
            changed[name] = {
                "cross_section_x_front_rear": [0.70, 0.85],
                "cross_section_y_front_rear": [0.30, 0.55],
            }
    return changed


def catmull_rom(a, b, c, d, t):
    t2, t3 = t * t, t * t * t
    return tuple(0.5 * ((2.0 * b[i]) + (-a[i] + c[i]) * t +
                        (2.0 * a[i] - 5.0 * b[i] + 4.0 * c[i] - d[i]) * t2 +
                        (-a[i] + 3.0 * b[i] - 3.0 * c[i] + d[i]) * t3)
                 for i in range(3))


def make_head_wedge_geometry(joint_index, color):
    """Build a distinct mantis head with a wide eye line and tapered face."""
    knots = [(-0.085, 0.012, 0.012),
             (-0.025, 0.070, 0.051),
             (0.015, 0.115, 0.069),
             (0.078, 0.044, 0.031)]
    rows = []
    subdivisions = 16
    for interval in range(len(knots) - 1):
        a = knots[max(0, interval - 1)]
        b = knots[interval]
        c = knots[interval + 1]
        d = knots[min(len(knots) - 1, interval + 2)]
        for step in range(subdivisions):
            rows.append(catmull_rom(a, b, c, d, step / subdivisions))
    rows.append(knots[-1])
    radial = 32
    positions, indices, uv, colors, joints, weights = [], [], [], [], [], []
    for ring_index, (z, radius_x, radius_y) in enumerate(rows):
        t = ring_index / max(1, len(rows) - 1)
        for j in range(radial):
            theta = 2.0 * math.pi * j / radial
            cs, sn = math.cos(theta), math.sin(theta)
            # Slightly flattened superellipse planes create a triangular face plate.
            sx = math.copysign(abs(cs) ** (2.0 / 2.65), cs)
            sy = math.copysign(abs(sn) ** (2.0 / 2.65), sn)
            point = (max(-0.118, min(0.118, radius_x * sx)),
                     max(-0.073, min(0.073, radius_y * sy)), z)
            gain = 0.88 + 0.12 * max(0.0, sy) + 0.04 * (1.0 - t)
            append_vertex(positions, indices, uv, colors, joints, weights, point,
                          (j / radial, t),
                          tuple(min(1.0, channel * gain) for channel in color[:3]) + (color[3],),
                          joint_index)
    for i in range(len(rows) - 1):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            indices.extend((a, b, c, a, c, d))
    for end_ring, reverse in ((0, True), (len(rows) - 1, False)):
        center_index = len(positions)
        z = rows[end_ring][0]
        append_vertex(positions, indices, uv, colors, joints, weights, (0.0, 0.0, z),
                      (0.5, end_ring / (len(rows) - 1)), color, joint_index)
        base = end_ring * radial
        for j in range(radial):
            a, b = base + j, base + (j + 1) % radial
            indices.extend((center_index, b, a) if reverse else (center_index, a, b))
    return positions, indices, uv, colors, joints, weights


def update_inverse_bind_matrices(document, binary, skin, node_indices, global_positions):
    accessor = document["accessors"][skin["inverseBindMatrices"]]
    view = document["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 64)
    joint_slot = {node_index: slot for slot, node_index in enumerate(skin["joints"])}
    for node_index in node_indices:
        slot = joint_slot[node_index]
        x, y, z = global_positions[node_index]
        inv = translation_matrix((-x, -y, -z))
        struct.pack_into("<16f", binary, offset + slot * stride, *inv)


def main():
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    marker = extras.get("reference_mantis_refinement")
    if marker == MARKER:
        print("The slim-neck and two-hinge foreleg pass is already applied.")
        return
    if marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {marker!r}; refusing to alter an unknown model.")
    if len(document.get("skins", [{}])[0].get("joints", [])) != 61:
        raise ValueError("Expected the v4.6 61-bone rig.")
    if len(document.get("animations", [])) != 10:
        raise ValueError("Expected all ten imported animation clips.")
    profile = extras.get("photo_reference_profile_v9", {})
    if profile.get("foreleg_details_preserved") != 100:
        raise ValueError("The v4.5 photo profile and its 100 foreleg details are required.")

    nodes = {node.get("name"): node for node in document["nodes"] if "name" in node}
    meshes = {mesh.get("name"): mesh for mesh in document["meshes"]}
    required = {"Thorax", "ThoraxSurfaceDetail", "ForeFemur_L", "ForeFemur_R",
                "ForeTibia_L", "ForeTibia_R", "Head"}
    if not required.issubset(meshes):
        raise ValueError(f"Missing required model meshes: {sorted(required - meshes.keys())}")
    if any(name in nodes for name in ("ForeCoxa_L", "ForeCoxa_R")):
        raise ValueError("Refusing to duplicate a partially applied coxa mesh.")

    # Thin the chest longitudinally at the head end so the separate head and
    # elongated pronotum no longer read as a single cylindrical log.
    thorax_profile = update_thorax_profile(document, binary, meshes)

    root_node = nodes["MantisRigRoot"]
    thorax_bone = nodes["Rig_Thorax"]
    root_mesh_node = nodes["world"]
    thorax_origin = translation(thorax_bone)
    changed_bone_worlds = {}
    foreleg_layout = {}
    skin = document["skins"][0]
    joint_indices = {document["nodes"][node_id]["name"]: i for i, node_id in enumerate(skin["joints"])}
    femur_material = meshes["ForeFemur_L"]["primitives"][0].get("material")
    tibia_material = meshes["ForeTibia_L"]["primitives"][0].get("material")
    thorax_material = meshes["Thorax"]["primitives"][0].get("material")
    thorax_joint = joint_indices["Rig_Thorax"]

    # Lift the distinct wedge-shaped head slightly off the thorax. Move the eyes
    # with it, then bridge the narrow gap with a small cervical membrane.
    head_shift = 0.030
    head_bone = nodes["Rig_Head"]
    head_local = translation(head_bone)
    head_local = (head_local[0], head_local[1] + head_shift, head_local[2])
    set_translation(head_bone, head_local)
    head_bone_id = document["nodes"].index(head_bone)
    changed_bone_worlds[head_bone_id] = add(thorax_origin, head_local)
    head_mesh_node = nodes["Head"]
    head_mesh_world = translation(head_mesh_node)
    set_translation(head_mesh_node, (head_mesh_world[0], head_mesh_world[1] + head_shift, head_mesh_world[2]))
    head_primitive = meshes["Head"]["primitives"][0]
    head_color = normalized_color(document, binary, head_primitive["attributes"]["COLOR_0"])
    head_geometry = make_head_wedge_geometry(joint_indices["Rig_Head"], head_color)
    meshes["Head"]["primitives"][0] = finish_primitive(
        document, binary, *head_geometry, head_primitive.get("material"))

    for suffix in "LR":
        eye_bone = nodes["Rig_Eye_" + suffix]
        eye_position = translation(eye_bone)
        eye_position = (eye_position[0], eye_position[1] + head_shift, eye_position[2] + 0.065)
        set_translation(eye_bone, eye_position)
        changed_bone_worlds[document["nodes"].index(eye_bone)] = eye_position
        eye_mesh_node = nodes["Eye_" + suffix]
        eye_mesh_world = translation(eye_mesh_node)
        set_translation(eye_mesh_node, (eye_mesh_world[0], eye_mesh_world[1] + head_shift, eye_mesh_world[2] + 0.065))

    for node in document["nodes"]:
        if node.get("name") == "MouthpartDetail":
            mouth_world = translation(node)
            set_translation(node, (mouth_world[0], mouth_world[1] + head_shift, mouth_world[2]))

    cervical_color = tuple(min(1.0, c * factor) for c, factor in
                           zip(normalized_color(document, binary, meshes["Thorax"]["primitives"][0]["attributes"]["COLOR_0"]),
                               (0.91, 0.97, 0.84, 1.0)))
    cervical_geometry = make_coxa_geometry(
        thorax_joint, cervical_color,
        (0.0, 0.255, -0.650), (0.0, 0.315, -0.600), thorax_origin,
    )
    add_mesh_and_node(document, binary, root_mesh_node, "CervicalLink", cervical_geometry,
                      thorax_material, 0, translation_matrix(thorax_origin))

    for side, suffix in ((-1, "L"), (1, "R")):
        attach = (side * 0.055, 0.220, -0.455)
        shoulder = (side * 0.130, 0.055, -0.545)
        knee = (side * 0.240, -0.095, -0.315)
        tip = (side * 0.250, -0.280, -0.535)
        femur_curve = lambda u, a=shoulder, b=knee: lerp(a, b, u)
        tibia_curve = lambda u, a=knee, b=tip: lerp(a, b, u)

        femur_node = nodes["Rig_ForeFemur_" + suffix]
        tibia_node = nodes["Rig_ForeTibia_" + suffix]
        femur_mesh_node = nodes["ForeFemur_" + suffix]
        tibia_mesh_node = nodes["ForeTibia_" + suffix]
        femur_bone_id = document["nodes"].index(femur_node)
        tibia_bone_id = document["nodes"].index(tibia_node)
        changed_bone_worlds[femur_bone_id] = shoulder
        changed_bone_worlds[tibia_bone_id] = knee

        # The shoulder is a child of the thorax articulation. The tibia is a
        # child of the femur hinge, so both physical joints follow the body.
        if femur_bone_id in root_node.get("children", []):
            root_node["children"].remove(femur_bone_id)
        thorax_bone.setdefault("children", []).append(femur_bone_id)
        set_translation(femur_node, sub(shoulder, thorax_origin))
        set_translation(tibia_node, sub(knee, shoulder))
        set_translation(femur_mesh_node, shoulder)
        set_translation(tibia_mesh_node, knee)

        # Rebuild the two moving segments from their pivot outward. Previously
        # they were centered on their pivots, so each limb floated past its joint.
        for part_name, start, end, other_curve, radius, material in (
            ("ForeFemur_" + suffix, shoulder, knee, tibia_curve, 0.022, femur_material),
            ("ForeTibia_" + suffix, knee, tip, femur_curve, 0.024, tibia_material),
        ):
            mesh = meshes[part_name]
            if len(mesh.get("primitives", [])) != 1:
                raise ValueError(f"Expected one primitive for {part_name}.")
            primitive = mesh["primitives"][0]
            geometry = make_limb_geometry(part_name, side, joint_indices["Rig_" + part_name],
                                          normalized_color(document, binary, primitive["attributes"]["COLOR_0"]),
                                          start, end, other_curve, radius)
            replacement = finish_primitive(document, binary, *geometry, primitive.get("material"))
            mesh["primitives"][0] = replacement

        # A slender, thorax-bound coxa reaches down from the chest to the first hinge.
        coxa_geometry = make_coxa_geometry(
            thorax_joint, normalized_color(document, binary, meshes["ForeFemur_" + suffix]["primitives"][0]["attributes"]["COLOR_0"]),
            attach, shoulder, thorax_origin,
        )
        coxa_index = add_mesh_and_node(
            document, binary, root_mesh_node, "ForeCoxa_" + suffix, coxa_geometry,
            femur_material if femur_material is not None else thorax_material,
            0, translation_matrix(thorax_origin),
        )
        foreleg_layout[suffix] = {
            "coxa_attach_world": list(attach),
            "first_hinge_world": list(shoulder),
            "second_hinge_world": list(knee),
            "tibial_tip_world": list(tip),
            "visible_segments": ["ForeCoxa_" + suffix, "ForeFemur_" + suffix, "ForeTibia_" + suffix],
            "hinge_bones": ["Rig_ForeFemur_" + suffix, "Rig_ForeTibia_" + suffix],
        }

    # Recompute affected bind matrices after moving the two animated pivots.
    update_inverse_bind_matrices(document, binary, skin, changed_bone_worlds.keys(), changed_bone_worlds)

    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v11_anatomy"] = {
        "prothorax_cross_section_scale_front_rear": {
            "lateral_x": [0.78, 0.89],
            "vertical_y": [0.49, 0.79],
        },
        "head_remains_separate_mesh_and_bone": True,
        "head_shape": "broad eye-line wedge with a tapered triangular face",
        "head_lift": head_shift,
        "eye_line_shift_forward_axis": 0.065,
        "cervical_link": "slim thorax-bound connector beneath the head",
        "foreleg_segments_per_side": ["coxa", "spined femur", "toothed tibia", "short tarsal hook"],
        "independent_hinge_count_per_side": 2,
        "two_hinge_bones": ["Rig_ForeFemur_L", "Rig_ForeTibia_L", "Rig_ForeFemur_R", "Rig_ForeTibia_R"],
        "segments_start_at_their_pivots": True,
        "coxa_attaches_to_thorax": True,
        "femur_knee_and_tibia_share_pivot": True,
        "detail_count_preserved": 100,
        "surface_details_per_side": {
            "femoral_spines": FEMUR_SPINES,
            "tibial_teeth": TIBIA_TEETH,
            "longitudinal_cuticle_ridges": RIDGES_PER_SEGMENT * 2,
        },
        "leg_rest_pose": foreleg_layout,
    }
    if extras.get("photo_reference_profile_v9", {}).get("foreleg_details_preserved") != 100:
        raise AssertionError("The photo profile's detail bank was lost.")
    glb.write_glb(MODEL, document, binary)
    print("Slimmed the head-side pronotum and rebuilt attached, two-hinge V-folding forelegs; retained 100 visible details and all imported clips.")


if __name__ == "__main__":
    main()
