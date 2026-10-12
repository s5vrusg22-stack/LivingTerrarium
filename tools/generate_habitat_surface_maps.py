#!/usr/bin/env python3
"""Generate small, repeatable foliage PBR maps for the terrarium leaves."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures"
SIZE = 1024
RNG = np.random.default_rng(3505)


def smooth_noise(grid: int) -> np.ndarray:
    small = RNG.normal(0.0, 1.0, (grid, grid)).astype(np.float32)
    image = Image.fromarray(small, mode="F").resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    result = np.asarray(image, dtype=np.float32).copy()
    result -= result.mean()
    result /= max(float(result.std()), 1e-5)
    return result


def normal_map(height: np.ndarray, strength: float) -> Image.Image:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx, ny, nz = -dx * strength, -dy * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return Image.fromarray(np.uint8(np.clip(rgb * 0.5 + 0.5, 0, 1) * 255), "RGB")


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    broad = smooth_noise(24)
    mottling = smooth_noise(112)
    fine = RNG.normal(0.0, 1.0, (SIZE, SIZE)).astype(np.float32)

    vein_image = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(vein_image)
    centerline = []
    for y in range(SIZE):
        x = SIZE * 0.5 + np.sin(y / SIZE * np.pi * 2.0) * 5.0
        centerline.append((x, y))
    draw.line(centerline, fill=255, width=14, joint="curve")
    for side in (-1.0, 1.0):
        for index, y in enumerate(range(54, SIZE - 36, 94)):
            t = y / SIZE
            reach = (SIZE * 0.44) * max(0.0, np.sin(np.pi * t)) ** 0.76
            x0 = SIZE * 0.5 + np.sin(t * np.pi * 2.0) * 5.0
            x1 = x0 + side * reach
            bend = side * (14 + index % 3 * 4)
            draw.line([(x0, y), (x0 + bend, y + 20), (x1 * 0.68 + x0 * 0.32, y + 43), (x1, y + 60)],
                      fill=190, width=6, joint="curve")
    veins = np.asarray(vein_image.filter(ImageFilter.GaussianBlur(1.4)), dtype=np.float32) / 255.0
    fine_veins = np.asarray(vein_image, dtype=np.float32) / 255.0

    pigment = 224.0 + broad * 5.0 + mottling * 3.5 + fine * 1.2
    edge = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)[None, :]
    edge_darkening = np.clip(np.abs(edge - 0.5) * 1.8, 0.0, 1.0)
    pigment -= edge_darkening * 3.0
    pigment += veins * 14.0 + fine_veins * 4.0
    rgb = np.repeat(pigment[:, :, None], 3, axis=2)
    Image.fromarray(np.uint8(np.clip(rgb, 0, 255)), "RGB").save(ROOT / "foliage_albedo.png")

    relief = broad * 0.025 + mottling * 0.012 + (veins - 0.35) * 0.09 + fine * 0.0015
    normal_map(relief, 32.0).save(ROOT / "foliage_normal.png")
    rough = np.clip(0.78 + broad * 0.035 + mottling * 0.025 - veins * 0.045, 0.62, 0.94)
    Image.fromarray(np.uint8(rough * 255), "L").save(ROOT / "foliage_roughness.png")
    print("Wrote foliage albedo, vein relief, and roughness maps.")


if __name__ == "__main__":
    main()
