#!/usr/bin/env python3
"""Make the long thorax-to-femur foreleg segment read clearly in the model."""
from __future__ import annotations

import math

import upgrade_mantis_glb as glb
import refine_mantis_v11_two_hinge_forelegs as v11


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v12_long_neck_attached_two_hinge_forelegs"
MARKER = "photo_proportions_v13_prominent_long_coxa"
THICKNESS_SCALE = 1.70
ROOT_SOCKET_RADIUS = 0.021


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("reference_mantis_refinement") == MARKER:
        print("The visible long-coxa correction is already applied.")
        return
    if extras.get("reference_mantis_refinement") != SOURCE_MARKER:
        raise ValueError("Expected the v4.8 two-hinge foreleg model.")

    nodes = {node.get("name"): node for node in document["nodes"] if node.get("name")}
    meshes = {mesh.get("name"): mesh for mesh in document["meshes"]}
    skin = document["skins"][0]
    if len(skin["joints"]) != 61 or len(document.get("animations", [])) != 10:
        raise ValueError("The existing 61-joint rig and ten imported clips must be preserved.")

    anatomy = extras["mantis_v12_anatomy"]
    joint_slot = {document["nodes"][node_id]["name"]: slot
                  for slot, node_id in enumerate(skin["joints"])}
    thorax_origin = v11.translation(nodes["Rig_Thorax"])
    thorax_joint = joint_slot["Rig_Thorax"]
    material = meshes["ForeFemur_L"]["primitives"][0].get("material")
    visible = {}

    for suffix in "LR":
        mesh_name = "ForeCoxa_" + suffix
        if mesh_name not in meshes or mesh_name not in nodes:
            raise ValueError(f"Missing thorax-to-femur segment {mesh_name}.")
        pose = anatomy["leg_rest_pose"][suffix]
        attach = tuple(pose["coxa_attach_world"])
        shoulder = tuple(pose["first_hinge_world"])
        geometry = v11.make_coxa_geometry(
            thorax_joint,
            v11.normalized_color(document, binary,
                                 meshes["ForeFemur_" + suffix]["primitives"][0]["attributes"]["COLOR_0"]),
            attach, shoulder, thorax_origin,
            thickness_scale=THICKNESS_SCALE,
            socket_radius=ROOT_SOCKET_RADIUS,
        )
        primitive = v11.finish_primitive(document, binary, *geometry, material)
        meshes[mesh_name]["primitives"][0] = primitive
        visible[suffix] = {
            "segment": mesh_name,
            "start_world": list(attach),
            "end_world": list(shoulder),
            "length": round(math.dist(attach, shoulder), 4),
            "shaft_thickness_scale": THICKNESS_SCALE,
            "thorax_socket_radius": ROOT_SOCKET_RADIUS,
            "surface": "rounded long coxa with a clear thorax socket, linked to the femur shoulder",
        }

    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v13_coxa_visibility"] = {
        "purpose": "make the additional long foreleg segment clearly visible between thorax and femur",
        "paired_segments": visible,
        "rig_and_animation_preserved": True,
    }
    glb.write_glb(MODEL, document, binary)
    print("Broadened both long coxae and added visible thorax sockets; all existing hinges remain intact.")


if __name__ == "__main__":
    main()
