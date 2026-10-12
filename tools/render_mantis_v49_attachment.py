#!/usr/bin/env python3
"""Render a close-up of the visible thorax-to-femur foreleg segments."""
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
        "mantis_v49_frontleg_attachment.png",
        "The extra long foreleg segment is visible",
        "Close side view · each coxa bridges the thorax socket to the femur shoulder",
        (4.5, 0.45, -1.85), (0.0, 0.13, -0.58), (0.0, 1.0, 0.0),
        crop=((-0.36, 0.36), (-0.28, 0.30)), version="v4.9",
        footer="Long paired coxae  ·  thorax sockets  ·  two foreleg hinges preserved",
    )
    print("Rendered coxa attachment preview to", renderer.OUT)


if __name__ == "__main__":
    main()
