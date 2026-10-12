#!/usr/bin/env python3
"""Build a brighter lime compound-eye map while retaining the existing cell grain."""
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/textures/mantis_eye_albedo.png"
OUTPUT = ROOT / "assets/textures/mantis_eye_albedo_v49.png"


def main() -> None:
    source = np.asarray(Image.open(SOURCE).convert("RGB"), dtype=np.float32)
    cellular = (source[:, :, 1] - float(source[:, :, 1].mean())) / 22.0
    result = np.stack((82.0 + cellular * 15.0,
                       164.0 + cellular * 32.0,
                       43.0 + cellular * 10.0), axis=-1)
    Image.fromarray(np.clip(result, 0, 255).astype(np.uint8), "RGB").save(OUTPUT)
    print("Generated brighter, grained mantis compound-eye map at", OUTPUT)


if __name__ == "__main__":
    main()
