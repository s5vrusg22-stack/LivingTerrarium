#!/usr/bin/env python3
"""Build tileable cuticle maps and a veined tegmen map with Pillow and NumPy."""
from __future__ import annotations

from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures"
SIZE = 1024
RNG = np.random.default_rng(7134)


def periodic_noise(grid: int) -> np.ndarray:
    small = RNG.normal(0.0, 1.0, (grid, grid)).astype(np.float32)
    tiled = np.tile(small, (3, 3))
    image = Image.fromarray(tiled, mode="F")
    factor = SIZE // grid
    enlarged = image.resize((grid * factor * 3, grid * factor * 3), Image.Resampling.BICUBIC)
    result = np.asarray(enlarged.crop((SIZE, SIZE, SIZE * 2, SIZE * 2)), dtype=np.float32).copy()
    result -= result.mean()
    result /= max(float(result.std()), 1e-5)
    return result


def make_normal(height: np.ndarray, strength: float) -> Image.Image:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx, ny = -dx * strength, -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return Image.fromarray(np.uint8(np.clip(normal * 0.5 + 0.5, 0, 1) * 255), "RGB")


def save_cuticle_maps() -> None:
    low = periodic_noise(32)
    middle = periodic_noise(128)
    grain = periodic_noise(512)
    pore = np.zeros((SIZE, SIZE), dtype=np.float32)
    for _ in range(1900):
        cx = int(RNG.integers(5, SIZE - 5))
        cy = int(RNG.integers(5, SIZE - 5))
        radius = int(RNG.integers(1, 3))
        depth = float(RNG.uniform(4.0, 12.0))
        for oy in range(-radius - 1, radius + 2):
            for ox in range(-radius - 1, radius + 2):
                distance = math.sqrt(ox * ox + oy * oy)
                if distance <= radius + 1:
                    rim = math.exp(-((distance - radius * 0.52) / 0.48) ** 2)
                    pit = math.exp(-(distance / max(radius * 0.57, 0.7)) ** 2)
                    pore[(cy + oy) % SIZE, (cx + ox) % SIZE] += depth * (0.24 * rim - pit)

    # Low, mid and pore-scale variation all remain subtle, but are strong
    # enough to read on a small in-game model under ordinary lighting.
    height = 0.25 * low + 0.26 * middle + 0.15 * grain + pore * 0.10
    surface = 226.0 + 6.2 * low + 4.8 * middle + 2.7 * grain + pore * 0.70
    surface = np.clip(surface, 190, 247)
    rgb = np.stack((surface - 4.0, surface + 4.0, surface - 22.0), axis=-1)
    Image.fromarray(np.uint8(np.clip(rgb, 0, 255)), "RGB").save(ROOT / "mantis_cuticle_detail_albedo.png")
    make_normal(height, 58.0).save(ROOT / "mantis_cuticle_detail_normal.png")
    roughness = np.clip(0.86 + 0.040 * low + 0.030 * middle - pore * 0.0015, 0.70, 0.97)
    Image.fromarray(np.uint8(roughness * 255), "L").save(ROOT / "mantis_cuticle_detail_roughness.png")


def save_wing_maps() -> None:
    width, height = 512, 1024
    noise = periodic_noise(512)[:height, :width]
    wing = np.uint8(np.clip(244.0 + noise * 2.0, 230, 252))
    image = Image.fromarray(wing, "L")
    draw = ImageDraw.Draw(image)
    center = width * 0.5

    def half_width(t: float) -> float:
        return width * 0.485 * max(0.0, math.sin(math.pi * t)) ** 0.78

    def center_x(t: float) -> float:
        return center + 3.0 * math.sin(t * math.pi * 2.0)

    # Contrasting midrib and secondary veins stay visible at normal gameplay
    # distance while retaining a soft, natural sage-green appearance.
    midrib = [(center_x(i / 256.0), i * 4) for i in range(257)]
    draw.line(midrib, fill=148, width=12, joint="curve")
    draw.line([(x + 5.0, y) for x, y in midrib], fill=251, width=2)

    # Longitudinal secondary veins taper toward the wing tip.
    for side in (-1.0, 1.0):
        for band, tint in zip((0.23, 0.40, 0.58, 0.76, 0.91), (169, 182, 194, 207, 218)):
            points = []
            for step in range(257):
                t = step / 256.0
                bend = band * (0.91 + 0.08 * math.sin(t * math.pi))
                points.append((center_x(t) + side * half_width(t) * bend, t * (height - 1)))
            draw.line(points, fill=tint, width=6 if band < 0.5 else 4, joint="curve")

        # Fine cross-links connect the veins into a restrained reticulate mesh.
        for row, y in enumerate(range(32, height - 32, 28)):
            t = y / (height - 1)
            edge = center_x(t) + side * half_width(t) * 0.94
            for band in (0.25, 0.43, 0.61, 0.79):
                x0 = center_x(t) + side * half_width(t) * band
                sway = 4.0 + (row % 3) * 1.3
                points = [
                    (x0, y),
                    (x0 + side * sway, y + 5),
                    (x0 + (edge - x0) * 0.56, y + 10),
                    (x0 + (edge - x0) * 0.82, y + 15),
                    (edge, y + 18),
                ]
                draw.line(points, fill=204 if row % 2 else 211, width=3, joint="curve")

    # Very sparse pale cuticle flecks; low contrast keeps the wing botanical.
    for _ in range(520):
        x = int(RNG.integers(8, width - 8))
        y = int(RNG.integers(8, height - 8))
        if RNG.random() < 0.5:
            draw.point((x, y), fill=252)

    intensity = np.asarray(image, dtype=np.float32) / 255.0
    rgb = np.repeat(intensity[:, :, None], 3, axis=2)
    Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255), "RGB").save(ROOT / "mantis_wing_detail.png")
    relief = (intensity - 0.94) * 1.0
    make_normal(relief.astype(np.float32), 68.0).save(ROOT / "mantis_wing_normal.png")
    rough = np.clip(0.88 + (1.0 - intensity) * 0.20 + noise * 0.018, 0.76, 0.98)
    Image.fromarray(np.uint8(rough * 255), "L").save(ROOT / "mantis_wing_roughness.png")


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    save_cuticle_maps()
    save_wing_maps()
    print("Wrote tileable cuticle maps and a veined wing texture.")
