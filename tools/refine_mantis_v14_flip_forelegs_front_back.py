#!/usr/bin/env python3
"""Mirror each complete raptorial foreleg front-to-back, anchored at the thorax."""
from __future__ import annotations

import json
import math

import upgrade_mantis_glb as glb
import refine_mantis_v11_two_hinge_forelegs as v11


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
ANIMATION_BANK = glb.PROJECT / "assets/animations/front_leg_100.json"
SOURCE_MARKER = "photo_proportions_v13_prominent_long_coxa"
MARKER = "photo_proportions_v14_forelegs_front_back_flipped"
THICKNESS_SCALE = 1.70
ROOT_SOCKET_RADIUS = 0.021


def move_node(node, position):
    node["matrix"] = v11.translation_matrix(position)
    node.pop("translation", None)
    node.pop("rotation", None)
    node.pop("scale", None)


def reflect_z(point, root_z):
    return (float(point[0]), float(point[1]), 2.0 * root_z - float(point[2]))


def retarget_imported_animations(document, binary, changed_names):
    node_names = {index: node.get("name") for index, node in enumerate(document["nodes"])}
    channel_uses = {}
    for animation in document.get("animations", []):
        for channel in animation.get("channels", []):
            sampler = animation["samplers"][channel["sampler"]]
            accessor_id = sampler["output"]
            channel_uses.setdefault(accessor_id, []).append(
                (animation.get("name", ""), node_names.get(channel["target"]["node"]),
                 channel["target"].get("path")))

    report = []
    changed_accessors = set()
    for animation in document.get("animations", []):
        for channel in animation.get("channels", []):
            node_id = channel["target"]["node"]
            name = node_names.get(node_id)
            if name not in changed_names or channel["target"].get("path") != "rotation":
                continue
            sampler = animation["samplers"][channel["sampler"]]
            accessor_id = sampler["output"]
            accessor = document["accessors"][accessor_id]
            if accessor_id not in changed_accessors:
                if accessor.get("type") != "VEC4" or accessor.get("componentType") != 5126:
                    raise ValueError(f"Unexpected imported rotation output for {name}.")
                other_uses = [use for use in channel_uses[accessor_id]
                              if use[1] not in changed_names or use[2] != "rotation"]
                if other_uses:
                    raise ValueError("A foreleg rotation output is shared with a non-foreleg channel.")
                before = glb.read_vectors(document, binary, accessor_id)
                after = [(-row[0], -row[1], row[2], row[3]) for row in before]
                glb.write_vectors(document, binary, accessor_id, after)
                changed_accessors.add(accessor_id)
                sample_before, sample_after = before[0], after[0]
            else:
                after = glb.read_vectors(document, binary, accessor_id)
                sample_before = (-after[0][0], -after[0][1], after[0][2], after[0][3])
                sample_after = after[0]
            report.append({
                "animation": animation.get("name", ""),
                "joint": name,
                "path": "rotation",
                "output_accessor": accessor_id,
                "sample_before": list(sample_before),
                "sample_after": list(sample_after),
            })
    if len(report) < 8:
        raise ValueError("Expected front-leg rotations in the existing imported clips.")
    return report


def retarget_motion_bank(path):
    bank = json.loads(path.read_text(encoding="utf-8"))
    clips = bank.get("animations")
    if not isinstance(clips, list) or len(clips) != 100:
        raise ValueError("The 100-pattern front-leg motion bank is required.")
    transformed_samples = []
    for clip in clips:
        frames = clip.get("keyframes", [])
        if len(frames) != 9 or any(not isinstance(frame, list) or len(frame) != 12 for frame in frames):
            raise ValueError("An unexpected front-leg motion frame was found.")
        for frame_index, frame in enumerate(frames):
            for offset in (0, 6):
                # Reflection through a plane parallel to XY maps axial rotation
                # vectors as (pitch, yaw, roll) -> (-pitch, -yaw, roll).
                frame[offset] = -float(frame[offset])
                frame[offset + 1] = -float(frame[offset + 1])
                frame[offset + 3] = -float(frame[offset + 3])
                frame[offset + 4] = -float(frame[offset + 4])
            if clip["name"] == "Foreleg_001" and frame_index == 0:
                transformed_samples.append(list(frame))
    bank["foreleg_rotation_reflection"] = {
        "axis": "front-back Z",
        "rotation_mapping": {"pitch_x": -1, "yaw_y": -1, "roll_z": 1},
        "applied_to_clips": len(clips),
        "keyframes_per_clip": 9,
        "sample_foreleg_001_frame_0": transformed_samples[0],
    }
    path.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return bank["foreleg_rotation_reflection"]


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    current_marker = extras.get("reference_mantis_refinement")
    if current_marker == MARKER:
        print("The front-to-back foreleg correction is already applied.")
        return
    if current_marker != SOURCE_MARKER:
        raise ValueError(f"Expected {SOURCE_MARKER!r}, found {current_marker!r}; refusing an unknown model.")

    nodes = {node.get("name"): node for node in document["nodes"] if node.get("name")}
    node_ids = {node.get("name"): index for index, node in enumerate(document["nodes"])
                if node.get("name")}
    meshes = {mesh.get("name"): mesh for mesh in document["meshes"]}
    skin = document["skins"][0]
    if len(skin["joints"]) != 61 or len(document.get("animations", [])) != 10:
        raise ValueError("The 61-joint rig and all ten imported clips must remain intact.")
    anatomy = extras["mantis_v12_anatomy"]
    source_pose = anatomy["leg_rest_pose"]
    joint_slot = {document["nodes"][node_id]["name"]: slot
                  for slot, node_id in enumerate(skin["joints"])}
    thorax_origin = v11.translation(nodes["Rig_Thorax"])
    thorax_joint = joint_slot["Rig_Thorax"]
    root_node = nodes["MantisRigRoot"]
    thorax_bone = nodes["Rig_Thorax"]
    changed_bone_worlds = {}
    final_pose = {}
    visible_segments = {}
    femur_material = meshes["ForeFemur_L"]["primitives"][0].get("material")
    tibia_material = meshes["ForeTibia_L"]["primitives"][0].get("material")
    retargeted_joints = {"Rig_ForeFemur_L", "Rig_ForeFemur_R",
                         "Rig_ForeTibia_L", "Rig_ForeTibia_R"}

    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        old = source_pose[suffix]
        attach = tuple(old["coxa_attach_world"])
        shoulder = reflect_z(old["first_hinge_world"], attach[2])
        knee = reflect_z(old["second_hinge_world"], attach[2])
        tip = reflect_z(old["tibial_tip_world"], attach[2])
        femur_curve = lambda u, a=shoulder, b=knee: v11.lerp(a, b, u)
        tibia_curve = lambda u, a=knee, b=tip: v11.lerp(a, b, u)

        femur_bone = nodes["Rig_ForeFemur_" + suffix]
        tibia_bone = nodes["Rig_ForeTibia_" + suffix]
        femur_id = node_ids["Rig_ForeFemur_" + suffix]
        tibia_id = node_ids["Rig_ForeTibia_" + suffix]
        changed_bone_worlds[femur_id] = shoulder
        changed_bone_worlds[tibia_id] = knee
        if femur_id in root_node.get("children", []):
            root_node["children"].remove(femur_id)
        if femur_id not in thorax_bone.setdefault("children", []):
            thorax_bone["children"].append(femur_id)
        if tibia_id not in femur_bone.setdefault("children", []):
            femur_bone["children"].append(tibia_id)
        move_node(femur_bone, v11.sub(shoulder, thorax_origin))
        move_node(tibia_bone, v11.sub(knee, shoulder))
        move_node(nodes["ForeFemur_" + suffix], shoulder)
        move_node(nodes["ForeTibia_" + suffix], knee)

        for part_name, start, end, opposing, radius, material in (
            ("ForeFemur_" + suffix, shoulder, knee, tibia_curve, 0.022, femur_material),
            ("ForeTibia_" + suffix, knee, tip, femur_curve, 0.023, tibia_material),
        ):
            primitive = meshes[part_name]["primitives"][0]
            color = v11.normalized_color(document, binary,
                                         primitive["attributes"]["COLOR_0"])
            geometry = v11.make_limb_geometry(
                part_name, int(side), joint_slot["Rig_" + part_name], color,
                start, end, opposing, radius, mirror_front_back=True)
            meshes[part_name]["primitives"][0] = v11.finish_primitive(
                document, binary, *geometry, material)

        coxa_color = v11.normalized_color(
            document, binary,
            meshes["ForeFemur_" + suffix]["primitives"][0]["attributes"]["COLOR_0"])
        coxa_geometry = v11.make_coxa_geometry(
            thorax_joint, coxa_color, attach, shoulder, thorax_origin,
            thickness_scale=THICKNESS_SCALE, socket_radius=ROOT_SOCKET_RADIUS)
        meshes["ForeCoxa_" + suffix]["primitives"][0] = v11.finish_primitive(
            document, binary, *coxa_geometry, femur_material)

        final_pose[suffix] = {
            "coxa_attach_world": list(attach),
            "first_hinge_world": list(shoulder),
            "second_hinge_world": list(knee),
            "tibial_tip_world": list(tip),
            "visible_segments": ["ForeCoxa_" + suffix, "ForeFemur_" + suffix,
                                 "ForeTibia_" + suffix],
            "hinge_bones": ["Rig_ForeFemur_" + suffix, "Rig_ForeTibia_" + suffix],
        }
        visible_segments[suffix] = {
            "mirror_plane_z": attach[2],
            "source_pose": old,
            "rest_pose": final_pose[suffix],
            "segment_lengths_preserved": {
                "coxa": round(math.dist(attach, shoulder), 6),
                "femur": round(math.dist(shoulder, knee), 6),
                "tibia": round(math.dist(knee, tip), 6),
            },
        }

    v11.update_inverse_bind_matrices(
        document, binary, skin, changed_bone_worlds.keys(), changed_bone_worlds)
    clip_retargeting = retarget_imported_animations(
        document, binary, retargeted_joints)
    bank_retargeting = retarget_motion_bank(ANIMATION_BANK)

    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v14_front_back_flip"] = {
        "purpose": "flip the entire paired raptorial foreleg front-to-back while keeping thorax roots fixed",
        "coordinate_rule": "x'=x, y'=y, z'=2*z_root-z",
        "reflected_axis": "Z front-back only",
        "root_anchors_preserved": True,
        "left_right_and_vertical_coordinates_preserved": True,
        "shaft_thickness_scale": THICKNESS_SCALE,
        "thorax_socket_radius": ROOT_SOCKET_RADIUS,
        "segments": visible_segments,
        "rest_pose": final_pose,
        "imported_clip_rotation_reflection": {"quaternion": "(-x, -y, z, w)",
                                               "channel_count": len(clip_retargeting),
                                               "channels": clip_retargeting},
        "procedural_rotation_reflection": {"pitch": -1, "yaw": -1, "roll": 1},
        "custom_motion_bank_reflection": bank_retargeting,
        "rig_joint_count": len(skin["joints"]),
        "imported_clip_count": len(document["animations"]),
    }
    anatomy["leg_rest_pose"] = final_pose
    glb.write_glb(MODEL, document, binary)
    print("Mirrored both complete front-leg assemblies across Z; roots, left/right offsets, skin weights, and all animation systems were retargeted.")


if __name__ == "__main__":
    main()
