"""Build a tileable pale-green mantis cuticle texture and matching PBR maps.

Requires NumPy and Pillow. Run from any directory with:
    python tools/generate_mantis_cuticle_texture.py
"""
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures"
SIZE = 512


def periodic_band_noise(size: int, low: float, high: float, seed: int) -> np.ndarray:
    """Make seamless Fourier noise in a frequency band, normalized to unit range."""
    rng = np.random.default_rng(seed)
    source = rng.normal(size=(size, size))
    fy = np.fft.fftfreq(size) * size
    fx = np.fft.rfftfreq(size) * size
    radius = np.sqrt(fy[:, None] ** 2 + fx[None, :] ** 2)
    low_pass = np.exp(-0.5 * (radius / high) ** 2)
    high_pass = 1.0 - np.exp(-0.5 * (radius / max(low, 0.1)) ** 2)
    field = np.fft.irfft2(np.fft.rfft2(source) * low_pass * high_pass, s=(size, size))
    field -= field.mean()
    field /= max(float(field.std()), 1e-8)
    return field


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    low = periodic_band_noise(SIZE, 1.5, 9.0, 41)
    middle = periodic_band_noise(SIZE, 9.0, 48.0, 42)
    fine = periodic_band_noise(SIZE, 48.0, 190.0, 43)

    # Fine, softly broken longitudinal striae suggest cuticle without reading as fur.
    warp = 0.24 * low + 0.11 * middle
    striae = np.sin(2.0 * np.pi * (x * 0.19 + warp))
    height = 0.925 + low * 0.018 + middle * 0.010 + fine * 0.006 + striae * 0.0025
    height = np.clip(height, 0.82, 0.995)

    # A nearly neutral warm green lets each body part retain its own mint/olive tint.
    rgb = np.stack((height * 0.99, height, height * 0.94), axis=-1)
    albedo = np.uint8(np.clip(rgb * 255.0, 0, 255))
    Image.fromarray(albedo, "RGB").save(ROOT / "mantis_cuticle_albedo.png", optimize=True)

    gray = np.asarray(Image.fromarray(albedo, "RGB").convert("L"), dtype=np.float32) / 255.0
    gy, gx = np.gradient(gray)
    strength = 4.2
    normals = np.stack((-gx * strength, -gy * strength, np.ones_like(gray)), axis=-1)
    normals /= np.maximum(np.linalg.norm(normals, axis=2, keepdims=True), 1e-8)
    normal_rgb = np.uint8(np.clip(normals * 0.5 + 0.5, 0, 1) * 255)
    Image.fromarray(normal_rgb, "RGB").save(ROOT / "mantis_cuticle_normal.png", optimize=True)

    roughness = np.clip(0.54 + (gray - gray.mean()) * 0.38 + middle * 0.012, 0.43, 0.66)
    Image.fromarray(np.uint8(roughness * 255), "L").save(ROOT / "mantis_cuticle_roughness.png", optimize=True)

    print("Generated tileable 512px mantis albedo, normal, and roughness maps in", ROOT)


if __name__ == "__main__":
    main()
