#!/usr/bin/env python3
"""Render an offline side close-up for the corrected foreleg direction."""
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
        "mantis_v410_foreleg_front_back.png",
        "The complete forelegs now face the corrected direction",
        "Side close-up · coxa, femur, tibia and tarsal hook mirrored together",
        (4.8, 0.65, -1.75), (0.0, 0.10, -0.55), (0.0, 1.0, 0.0),
        crop=((-0.78, 0.78), (-0.40, 0.38)), version="v4.9.1",
        footer="Z direction corrected  ·  thorax roots fixed  ·  61 joints and all motion paths retained",
    )
    print("Rendered front-to-back foreleg preview to", renderer.OUT)


if __name__ == "__main__":
    main()
