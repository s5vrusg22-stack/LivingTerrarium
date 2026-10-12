#!/usr/bin/env python3
"""Correct the photo-guided mantis head, neck, and raptorial forelegs.

Run from the project root after refine_mantis_v11_two_hinge_forelegs.py.
The head and its details move forward on a slender cervical connector, and the
forelegs are reset as attached coxa -> long femur -> opposing toothed tibia.
"""
from __future__ import annotations

import math
from pathlib import Path

import upgrade_mantis_glb as glb
import refine_mantis_v11_two_hinge_forelegs as v11


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v11_two_hinge_forelegs_slim_pronotum"
MARKER = "photo_proportions_v12_long_neck_attached_two_hinge_forelegs"


def move_node(node, position):
    node["matrix"] = v11.translation_matrix(position)
    node.pop("translation", None)
    node.pop("rotation", None)
    node.pop("scale", None)


def move_mesh_vertices(document, binary, mesh, scale):
    for primitive in mesh["primitives"]:
        attrs = primitive["attributes"]
        position_accessor = attrs["POSITION"]
        positions = glb.read_vectors(document, binary, position_accessor)
        positions = [tuple(p[i] * scale[i] for i in range(3)) for p in positions]
        indices = glb.read_indices(document, binary, primitive["indices"])
        glb.write_vectors(document, binary, position_accessor, positions)
        if "NORMAL" in attrs:
            glb.write_vectors(document, binary, attrs["NORMAL"], glb.vertex_normals(positions, indices))


def taper_pronotum(document, binary, meshes):
    z_front, z_back = -0.372, 0.372
    for name in ("Thorax", "ThoraxSurfaceDetail"):
        mesh = meshes[name]
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            points = glb.read_vectors(document, binary, attrs["POSITION"])
            shaped = []
            for x, y, z in points:
                u = max(0.0, min(1.0, (z - z_front) / (z_back - z_front)))
                s = u * u * (3.0 - 2.0 * u)
                # Add a clear head-side taper while preserving the thorax collar.
                extra_x = 0.62 + 0.38 * s
                extra_y = 0.58 + 0.42 * s
                shaped.append((x * extra_x, y * extra_y, z))
            glb.write_vectors(document, binary, attrs["POSITION"], shaped)
            if "NORMAL" in attrs:
                glb.write_vectors(document, binary, attrs["NORMAL"],
                                  glb.vertex_normals(shaped, glb.read_indices(document, binary, primitive["indices"])))


def main():
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("reference_mantis_refinement") == MARKER:
        print("The v4.8 photo-proportion correction is already applied.")
        return
    if extras.get("reference_mantis_refinement") != SOURCE_MARKER:
        raise ValueError("Expected the v4.7 mantis source; refusing an unknown model.")
    if len(document.get("skins", [{}])[0].get("joints", [])) != 61:
        raise ValueError("Expected the existing 61-bone mantis rig.")
    if len(document.get("animations", [])) != 10:
        raise ValueError("Expected all ten imported mantis clips.")

    nodes = {node.get("name"): node for node in document["nodes"] if node.get("name")}
    meshes = {mesh.get("name"): mesh for mesh in document["meshes"]}
    skin = document["skins"][0]
    joint_slot = {document["nodes"][node_id]["name"]: slot
                  for slot, node_id in enumerate(skin["joints"])}
    thorax_origin = v11.translation(nodes["Rig_Thorax"])
    changed_bone_worlds = {}

    # Narrow the thorax end that meets the head, then separate the head from it.
    taper_pronotum(document, binary, meshes)
    head_shift = (0.0, 0.0, -0.230)
    head_bone = nodes["Rig_Head"]
    head_local = (0.0, 0.115, -0.515)
    move_node(head_bone, head_local)
    head_id = document["nodes"].index(head_bone)
    head_world = (thorax_origin[0] + head_local[0], thorax_origin[1] + head_local[1],
                  thorax_origin[2] + head_local[2])
    changed_bone_worlds[head_id] = head_world
    move_node(nodes["Head"], head_world)
    # Refine the wedge slightly so its width reads as a head, not a second thorax.
    move_mesh_vertices(document, binary, meshes["Head"], (0.92, 0.94, 1.0))

    # Re-seat the compound eyes into the head's widened eye line.
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        eye_world = (side * 0.091, 0.403, -0.870)
        eye_bone = nodes["Rig_Eye_" + suffix]
        move_node(eye_bone, eye_world)
        changed_bone_worlds[document["nodes"].index(eye_bone)] = eye_world
        move_node(nodes["Eye_" + suffix], eye_world)
        move_mesh_vertices(document, binary, meshes["Eye_" + suffix], (0.83, 0.83, 0.83))

    # The antennae, ocelli, and mouthparts keep their positions relative to the
    # head after the head advances along the elongated prothorax.
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        for node_name in ("Antenna_" + suffix, "Rig_Antenna_" + suffix):
            node = nodes[node_name]
            # Set the antenna bases onto the upper lateral surface of the new
            # head, then keep their original long, tapered sweep.
            moved = (side * 0.1045, 0.562, -1.045)
            move_node(node, moved)
            if node_name.startswith("Rig_"):
                changed_bone_worlds[document["nodes"].index(node)] = moved
    for index in range(3):
        for node_name in (f"Ocellus_{index}", f"Rig_Ocellus_{index}"):
            node = nodes[node_name]
            moved = ((index - 1) * 0.022, 0.432, -0.880)
            move_node(node, moved)
            if node_name.startswith("Rig_"):
                changed_bone_worlds[document["nodes"].index(node)] = moved
    mouth = nodes["MouthpartDetail"]
    mouth_pos = v11.translation(mouth)
    move_node(mouth, (mouth_pos[0], mouth_pos[1], mouth_pos[2] + head_shift[2]))

    # Replace the nearly hidden neck connector with a long, thin bridge from the
    # narrowed thorax tip to the rear of the head capsule.
    cervical_color = tuple(min(1.0, c * factor) for c, factor in zip(
        v11.normalized_color(document, binary, meshes["Thorax"]["primitives"][0]["attributes"]["COLOR_0"]),
        (0.92, 0.98, 0.86, 1.0)))
    cervical_geo = v11.make_coxa_geometry(
        joint_slot["Rig_Thorax"], cervical_color,
        (0.0, 0.255, -0.719), (0.0, 0.337, -0.798), thorax_origin)
    cervical_node = nodes["CervicalLink"]
    primitive = v11.finish_primitive(document, binary, *cervical_geo,
                                     meshes["CervicalLink"]["primitives"][0].get("material"))
    meshes["CervicalLink"]["primitives"][0] = primitive
    move_node(cervical_node, v11.translation(cervical_node))

    root_node = nodes["MantisRigRoot"]
    thorax_bone = nodes["Rig_Thorax"]
    foreleg_layout = {}
    femur_material = meshes["ForeFemur_L"]["primitives"][0].get("material")
    tibia_material = meshes["ForeTibia_L"]["primitives"][0].get("material")
    thorax_material = meshes["Thorax"]["primitives"][0].get("material")

    # Each side has an attached coxa, a long outward/downward femur and a
    # second, inward folding tibia. The outer knee and inner tip form a clear V.
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        attach = (side * 0.026, 0.225, -0.520)
        shoulder = (side * 0.140, 0.015, -0.610)
        knee = (side * 0.330, -0.160, -0.370)
        tip = (side * 0.080, -0.300, -0.700)
        femur_curve = lambda u, a=shoulder, b=knee: v11.lerp(a, b, u)
        tibia_curve = lambda u, a=knee, b=tip: v11.lerp(a, b, u)

        femur_node = nodes["Rig_ForeFemur_" + suffix]
        tibia_node = nodes["Rig_ForeTibia_" + suffix]
        femur_id = document["nodes"].index(femur_node)
        tibia_id = document["nodes"].index(tibia_node)
        changed_bone_worlds[femur_id] = shoulder
        changed_bone_worlds[tibia_id] = knee
        if femur_id in root_node.get("children", []):
            root_node["children"].remove(femur_id)
        if femur_id not in thorax_bone.setdefault("children", []):
            thorax_bone["children"].append(femur_id)
        move_node(femur_node, v11.sub(shoulder, thorax_origin))
        move_node(tibia_node, v11.sub(knee, shoulder))
        move_node(nodes["ForeFemur_" + suffix], shoulder)
        move_node(nodes["ForeTibia_" + suffix], knee)

        for part_name, start, end, opposing, radius, material in (
            ("ForeFemur_" + suffix, shoulder, knee, tibia_curve, 0.022, femur_material),
            ("ForeTibia_" + suffix, knee, tip, femur_curve, 0.023, tibia_material),
        ):
            mesh = meshes[part_name]
            primitive = mesh["primitives"][0]
            color = v11.normalized_color(document, binary, primitive["attributes"]["COLOR_0"])
            geometry = v11.make_limb_geometry(part_name, int(side), joint_slot["Rig_" + part_name],
                                              color, start, end, opposing, radius)
            mesh["primitives"][0] = v11.finish_primitive(document, binary, *geometry, material)

        coxa_color = v11.normalized_color(document, binary,
                                          meshes["ForeFemur_" + suffix]["primitives"][0]["attributes"]["COLOR_0"])
        coxa_geo = v11.make_coxa_geometry(joint_slot["Rig_Thorax"], coxa_color,
                                          attach, shoulder, thorax_origin)
        primitive = v11.finish_primitive(document, binary, *coxa_geo, femur_material)
        meshes["ForeCoxa_" + suffix]["primitives"][0] = primitive

        foreleg_layout[suffix] = {
            "coxa_attach_world": list(attach),
            "first_hinge_world": list(shoulder),
            "second_hinge_world": list(knee),
            "tibial_tip_world": list(tip),
            "visible_segments": ["ForeCoxa_" + suffix, "ForeFemur_" + suffix, "ForeTibia_" + suffix],
            "hinge_bones": ["Rig_ForeFemur_" + suffix, "Rig_ForeTibia_" + suffix],
            "fold_shape": "outward femur then inward, forward folding tibia",
        }

    v11.update_inverse_bind_matrices(document, binary, skin,
                                     changed_bone_worlds.keys(), changed_bone_worlds)
    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v12_anatomy"] = {
        "head_center_world": list(head_world),
        "head_forward_shift": head_shift[2],
        "head_and_eye_meshes_repositioned": True,
        "eyes_recessed_and_scaled": 0.83,
        "pronotum_front_reduction": {"lateral_x": 0.62, "vertical_y": 0.58},
        "cervical_link_endpoints": [[0.0, 0.255, -0.719], [0.0, 0.337, -0.798]],
        "two_hinges_per_attached_foreleg": True,
        "leg_rest_pose": foreleg_layout,
        "detail_count_preserved": 100,
        "imported_clip_count": 10,
    }
    if extras.get("photo_reference_profile_v9", {}).get("foreleg_details_preserved") != 100:
        raise AssertionError("The 100-detail photo profile was lost.")
    glb.write_glb(MODEL, document, binary)
    print("Moved the head onto a longer slim neck and rebuilt both attached two-hinge grasping forelegs.")


if __name__ == "__main__":
    main()
