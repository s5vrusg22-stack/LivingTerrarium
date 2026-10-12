#!/usr/bin/env python3
"""Lengthen the cervical link and both first foreleg segments in the rigged GLB."""
from __future__ import annotations

from pathlib import Path

import upgrade_mantis_glb as glb


MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
PASS = "photo_proportions_v16_longer_neck_and_forecoxa"
SOURCE = "photo_details_v15"
NECK_SCALE = 1.65
COXA_SCALE = 1.24


def main() -> None:
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("mantis_v16_anatomy", {}).get("pass") == PASS:
        print("The V16 neck and forecoxa correction is already applied.")
        return
    if extras.get("mantis_v15_photo_details", {}).get("pass") != SOURCE:
        raise ValueError("Expected the V15 detailed mantis model before applying V16.")

    nodes = {node.get("name"): node for node in document["nodes"] if node.get("name")}
    for name in ("CervicalLink", "ForeCoxa_L", "ForeCoxa_R"):
        if name not in nodes or "matrix" not in nodes[name]:
            raise ValueError(f"Expected a matrix-transformed mesh node named {name}.")

    # Stretch the narrow neck away from its thorax attachment while keeping
    # the body-side endpoint fixed, so the bridge reaches the back of the head.
    neck = nodes["CervicalLink"]["matrix"]
    neck_attach_z = -0.359
    neck_translation_z = float(neck[14])
    neck[10] = NECK_SCALE
    neck[14] = neck_translation_z + (1.0 - NECK_SCALE) * neck_attach_z

    # Lengthen the coxa diagonally downward and outward from its thorax socket.
    # The attachment point is kept fixed on each mirrored side.
    coxa_anchors = {"ForeCoxa_L": (-0.005, -0.009), "ForeCoxa_R": (0.005, -0.009)}
    for name, (anchor_x, anchor_y) in coxa_anchors.items():
        matrix = nodes[name]["matrix"]
        matrix[0] = COXA_SCALE
        matrix[5] = COXA_SCALE
        matrix[12] += (1.0 - COXA_SCALE) * anchor_x
        matrix[13] += (1.0 - COXA_SCALE) * anchor_y

    if len(document.get("skins", [{}])[0].get("joints", [])) != 61:
        raise ValueError("The detailed mantis skeleton must keep all 61 joints.")
    if len(document.get("animations", [])) != 10:
        raise ValueError("The detailed mantis must keep all ten animation clips.")
    extras["mantis_v16_anatomy"] = {
        "pass": PASS,
        "neck_scale_z": NECK_SCALE,
        "neck_body_endpoint_preserved": True,
        "forecoxa_scale_xy": COXA_SCALE,
        "mirrored_foreleg_sockets_preserved": True,
        "bone_count": 61,
        "animation_clip_count": 10,
    }
    glb.write_glb(MODEL, document, binary)
    print("Lengthened the neck and mirrored foreleg coxae; preserved the rig and clips.")


if __name__ == "__main__":
    main()
