#!/usr/bin/env python3
"""Add photo-guided body, eye, and antenna detail to the latest v4.9 model.

This pass intentionally leaves the v14 foreleg reflection, animation clips,
procedural pose bank, and v5.0 butterfly project untouched.
"""
from __future__ import annotations

import math
from pathlib import Path

import upgrade_mantis_glb as glb
import refine_mantis_v11_two_hinge_forelegs as v11


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v14_forelegs_front_back_flipped"
DETAIL_MARKER = "photo_details_v15"


def make_antenna_geometry(joint_index, color, side, base, control, tip):
    positions, indices, uv, colors, joints, weights = [], [], [], [], [], []
    axial, radial = 56, 10

    def center(t):
        u = 1.0 - t
        return tuple(u * u * base[i] + 2.0 * u * t * control[i] + t * t * tip[i]
                     for i in range(3))

    def tangent(t):
        return v11.unit(tuple(2.0 * (1.0 - t) * (control[i] - base[i]) +
                              2.0 * t * (tip[i] - control[i]) for i in range(3)))

    for i in range(axial + 1):
        t = i / axial
        c = center(t)
        axis = tangent(t)
        side_axis = v11.unit(v11.cross(axis, (0.0, 1.0, 0.0)))
        if sum(value * value for value in side_axis) < 1e-8:
            side_axis = (1.0, 0.0, 0.0)
        up_axis = v11.unit(v11.cross(side_axis, axis))
        radius = 0.0042 * (1.0 - t) ** 0.82 + 0.00045
        for j in range(radial):
            theta = 2.0 * math.pi * j / radial
            offset = v11.add(v11.mul(side_axis, radius * math.cos(theta)),
                             v11.mul(up_axis, radius * math.sin(theta)))
            p = tuple(c[k] - base[k] + offset[k] for k in range(3))
            gain = 0.86 + 0.14 * math.sin(math.pi * t)
            v11.append_vertex(positions, indices, uv, colors, joints, weights,
                              p, (t, j / radial),
                              tuple(min(1.0, channel * gain) for channel in color[:3]) + (color[3],),
                              joint_index)
    for i in range(axial):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            indices.extend((a, b, c, a, c, d))
    return positions, indices, uv, colors, joints, weights


def make_eye_patch(joint_index, color, side, *, glint=False):
    positions, indices, uv, colors, joints, weights = [], [], [], [], [], []
    normal = v11.unit((side * 0.82, 0.05, -0.56))
    horizontal = v11.unit(v11.cross((0.0, 1.0, 0.0), normal))
    vertical = v11.unit(v11.cross(normal, horizontal))
    if glint:
        center = v11.add(v11.mul(normal, 0.027),
                         v11.add(v11.mul(horizontal, -0.0017), v11.mul(vertical, 0.0025)))
        radii = (0.0016, 0.0020, 0.0008)
    else:
        center = v11.mul(normal, 0.0245)
        radii = (0.0070, 0.0090, 0.0024)
    rings, radial = 10, 20
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(radial):
            theta = 2.0 * math.pi * j / radial
            local = v11.add(center, v11.add(
                v11.mul(horizontal, radii[0] * math.sin(phi) * math.cos(theta)),
                v11.add(v11.mul(vertical, radii[1] * math.cos(phi)),
                        v11.mul(normal, radii[2] * math.sin(phi) * math.sin(theta)))))
            light_gain = 0.82 + 0.18 * max(0.0, math.cos(phi))
            shaded = tuple(min(1.0, value * light_gain) for value in color[:3]) + (color[3],)
            v11.append_vertex(positions, indices, uv, colors, joints, weights,
                              local, (j / radial, i / rings), shaded, joint_index)
    for i in range(rings):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            indices.extend((a, d, b, b, d, c))
    return positions, indices, uv, colors, joints, weights


def scale_mesh(document, binary, mesh, scale):
    for primitive in mesh.get("primitives", []):
        attrs = primitive["attributes"]
        points = glb.read_vectors(document, binary, attrs["POSITION"])
        shaped = [tuple(point[i] * scale[i] for i in range(3)) for point in points]
        glb.write_vectors(document, binary, attrs["POSITION"], shaped)
        if "NORMAL" in attrs:
            glb.write_vectors(
                document, binary, attrs["NORMAL"],
                glb.vertex_normals(shaped, glb.read_indices(document, binary, primitive["indices"])),
            )


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("mantis_v15_photo_details", {}).get("pass") == DETAIL_MARKER:
        print("The v4.9 photo-detail pass is already applied.")
        return
    if extras.get("reference_mantis_refinement") != SOURCE_MARKER:
        raise ValueError("Expected the latest v14 foreleg-flipped mantis model.")

    skin = document["skins"][0]
    if len(skin.get("joints", [])) != 61 or len(document.get("animations", [])) != 10:
        raise ValueError("The 61-bone rig and all ten imported clips must remain intact.")

    nodes = {node.get("name"): node for node in document["nodes"] if node.get("name")}
    node_ids = {node.get("name"): i for i, node in enumerate(document["nodes"]) if node.get("name")}
    meshes = {mesh.get("name"): mesh for mesh in document["meshes"]}
    root_node = nodes["MantisRigRoot"]
    joint_slot = {document["nodes"][node_id]["name"]: slot
                  for slot, node_id in enumerate(skin["joints"])}

    # Slim and lengthen the abdomen while keeping each visible plate legible.
    body_scale = (0.88, 0.92, 1.06)
    plate_scale = (0.86, 0.92, 1.0)
    for name in ("Abdomen", "AbdomenSurfaceDetail"):
        if name in meshes:
            scale_mesh(document, binary, meshes[name], body_scale)
    for name in sorted(name for name in meshes if name.startswith("AbdominalPlate_")):
        scale_mesh(document, binary, meshes[name], plate_scale)

    # Narrow the anterior face into the shield-like triangular profile seen in
    # the photo without moving the eyes or mouthpart attachments.
    head = meshes["Head"]
    for primitive in head.get("primitives", []):
        attrs = primitive["attributes"]
        points = glb.read_vectors(document, binary, attrs["POSITION"])
        shaped = []
        for x, y, z in points:
            front = max(0.0, min(1.0, (-z - 0.005) / 0.080))
            smooth = front * front * (3.0 - 2.0 * front)
            lower_face = max(0.0, min(1.0, (0.065 - y) / 0.130))
            lower_smooth = lower_face * lower_face * (3.0 - 2.0 * lower_face)
            width = (1.0 - 0.13 * smooth) * (1.0 - 0.50 * lower_smooth)
            shaped.append((x * width, y, z - 0.012 * lower_smooth))
        glb.write_vectors(document, binary, attrs["POSITION"], shaped)
        if "NORMAL" in attrs:
            glb.write_vectors(
                document, binary, attrs["NORMAL"],
                glb.vertex_normals(shaped, glb.read_indices(document, binary, primitive["indices"])),
            )

    # Keep the three tiny simple eyes subordinate to the two compound eyes.
    for name in ("Ocellus_0", "Ocellus_1", "Ocellus_2"):
        if name in meshes:
            scale_mesh(document, binary, meshes[name], (0.62, 0.62, 0.62))

    # Replace the original short rods with long, curved, finely tapered paired
    # antennae. Existing bones stay in use for the idle/alert sway animation.
    antenna_layout = {}
    changed_bones = {}
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        base = (side * 0.058, 0.435, -0.895)
        control = (side * 0.20, 0.665, -0.965)
        tip = (side * 0.19, 0.890, -1.215)
        mesh = meshes["Antenna_" + suffix]
        primitive = mesh["primitives"][0]
        color = v11.normalized_color(document, binary, primitive["attributes"]["COLOR_0"])
        geometry = make_antenna_geometry(
            joint_slot["Rig_Antenna_" + suffix], color, side, base, control, tip
        )
        mesh["primitives"][0] = v11.finish_primitive(
            document, binary, *geometry, primitive.get("material")
        )
        v11.set_translation(nodes["Antenna_" + suffix], base)
        v11.set_translation(nodes["Rig_Antenna_" + suffix], base)
        changed_bones[node_ids["Rig_Antenna_" + suffix]] = base
        antenna_layout[suffix] = {
            "base_world": list(base),
            "control_world": list(control),
            "tip_world": list(tip),
            "tube_samples": 56,
            "tapered": True,
        }

    # Small pupils and catchlights clarify each compound eye while remaining
    # weighted to the existing eye bones.
    added_eye_nodes = []
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        eye_center = v11.translation(nodes["Eye_" + suffix])
        slot = joint_slot["Rig_Eye_" + suffix]
        for name, color, glint in (
            ("EyePupil_" + suffix, (0.10, 0.16, 0.045, 1.0), False),
            ("EyeGlint_" + suffix, (0.90, 1.0, 0.68, 1.0), True),
        ):
            if name in nodes:
                raise ValueError(f"Unexpected pre-existing detail node: {name}")
            geometry = make_eye_patch(slot, color, side, glint=glint)
            node_id = v11.add_mesh_and_node(
                document, binary, root_node, name, geometry, None, 0,
                v11.translation_matrix(eye_center),
            )
            added_eye_nodes.append({"name": name, "node": node_id, "joint": "Rig_Eye_" + suffix})

    v11.update_inverse_bind_matrices(document, binary, skin, changed_bones.keys(), changed_bones)
    extras["mantis_v15_photo_details"] = {
        "pass": DETAIL_MARKER,
        "reference_photo": "assets/reference/1000157363(3).jpg",
        "foreleg_flip_preserved": extras["mantis_v14_front_back_flip"],
        "abdomen_body_scale_xyz": list(body_scale),
        "abdomen_plate_scale_xyz": list(plate_scale),
        "head_front_taper": 0.13,
        "head_lower_face_taper": 0.50,
        "head_point_shift": -0.012,
        "ocelli_scale": 0.62,
        "antennae": antenna_layout,
        "eye_facets_and_glints": added_eye_nodes,
        "bone_count": len(skin["joints"]),
        "imported_clip_count": len(document["animations"]),
        "surface_detail_count": extras.get("mantis_v12_anatomy", {}).get("detail_count_preserved", 100),
    }
    glb.write_glb(MODEL, document, binary)
    print("Added photo-guided abdomen, head, eye, and antenna refinements; retained v14 foreleg pose.")


if __name__ == "__main__":
    main()
