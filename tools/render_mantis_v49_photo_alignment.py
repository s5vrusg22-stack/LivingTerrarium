#!/usr/bin/env python3
"""Render v4.9 after the photo-guided foreleg and anatomy corrections."""
from pathlib import Path
import sys

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import render_mantis_previews as renderer


def main() -> None:
    renderer.OUT.mkdir(parents=True, exist_ok=True)
    points, normals, colors, uvs, texture_kind, faces = renderer.read_scene()
    renderer.capture(
        points, normals, colors, uvs, texture_kind, faces,
        "mantis_v49_photo_alignment_overview.png",
        "Photo-aligned mantis anatomy in the active 3D model",
        "Forward-reaching raptorial femur · rearward folding toothed tibia",
        (3.8, 2.3, -4.4), (0.0, 0.18, -0.12), (0.0, 1.0, 0.0),
        version="v4.9", footer="Refined head and eyes  ·  slim antennae  ·  segmented abdomen  ·  paired two-hinge forelegs",
    )
    renderer.capture(
        points, normals, colors, uvs, texture_kind, faces,
        "mantis_v49_forelegs_reversed.png",
        "Both forelegs now face the requested direction",
        "Side view · coxa socket, forward femur, knee, inward folding tibia",
        (5.0, 0.70, -1.90), (0.0, -0.06, -0.66), (0.0, 1.0, 0.0),
        crop=((-0.56, 0.56), (-0.66, 0.70)), version="v4.9",
        footer="All three visible segments meet  ·  both articulated hinges remain connected",
    )
    renderer.capture(
        points, normals, colors, uvs, texture_kind, faces,
        "mantis_v49_head_antennae.png",
        "Triangular face, bright eye line and curved antennae",
        "Front three-quarter close-up · paired eyes, tapered face and curved antennae",
        (0.65, 0.68, -4.6), (0.0, 0.45, -0.88), (0.0, 1.0, 0.0),
        crop=((-0.52, 0.52), (-0.30, 0.52)), version="v4.9",
        footer="Paired eye pupils and catchlights  ·  high-resolution curved antenna tubes",
    )
    print("Rendered the v4.9 overall, foreleg, and head review images to", renderer.OUT)


if __name__ == "__main__":
    main()
