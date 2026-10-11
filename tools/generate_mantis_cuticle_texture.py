"""Build a tileable pale-green mantis cuticle texture and matching PBR maps.

Requires NumPy and Pillow. Run from any directory with:
    python tools/generate_mantis_cuticle_texture.py
"""
import base64
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


def mantis_wing_albedo(size: int = 512) -> np.ndarray:
    """Return a tileable, pale cuticle map with branching veins and cross-veins."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u = x / float(size)
    t = y / float(size)
    low = periodic_band_noise(size, 1.5, 10.0, 51)
    middle = periodic_band_noise(size, 10.0, 64.0, 52)
    fine = periodic_band_noise(size, 64.0, 240.0, 53)

    # The tegmina fan from a narrow hinge and converge again at their rounded tip.
    root = np.clip(t / 0.17, 0.0, 1.0)
    root = root * root * (3.0 - 2.0 * root)
    tip = np.clip((1.0 - t) / 0.24, 0.0, 1.0)
    tip = tip * tip * (3.0 - 2.0 * tip)
    profile = root * tip
    longitudinal = np.zeros_like(u)
    highlight = np.zeros_like(u)
    for vein_index, center in enumerate(np.linspace(0.11, 0.91, 9)):
        phase = float(vein_index) * 0.41
        curve = center * profile + 0.004 * np.sin(2.0 * np.pi * t + phase) * profile
        distance = np.abs(u - curve)
        longitudinal += np.exp(-0.5 * (distance / 0.0028) ** 2) * 0.060
        highlight += np.exp(-0.5 * ((distance - 0.0050) / 0.0020) ** 2) * 0.014

    # Fine diagonal cross-veins form low-contrast cells between the main veins.
    cross_phase = 2.0 * np.pi * (t * 28.0 + u * 3.5 + 0.018 * np.sin(u * 2.0 * np.pi * 7.0))
    cross_veins = np.exp(-0.5 * (np.sin(cross_phase) / 0.13) ** 2)
    cross_veins *= 1.0 - np.clip(longitudinal * 4.0, 0.0, 0.45)

    striae = np.sin(2.0 * np.pi * (u * 124.0 + low * 0.08 + middle * 0.025))
    edge = np.clip((np.abs(u - 0.5) - 0.43) / 0.07, 0.0, 1.0)
    height = 0.982 + low * 0.008 + middle * 0.004 + fine * 0.0025
    height += striae * 0.0015 + highlight + cross_veins * 0.014
    height -= longitudinal + edge * 0.024
    height = np.clip(height, 0.82, 1.0)
    rgb = np.stack((height * 1.015, height, height * 0.92), axis=-1)
    return np.uint8(np.clip(rgb * 255.0, 0, 255))


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

    wing_path = ROOT / "mantis_wing_albedo.png"
    Image.fromarray(mantis_wing_albedo(), "RGB").save(wing_path, optimize=True)
    encoded = base64.b64encode(wing_path.read_bytes()).decode("ascii")
    (ROOT / "mantis_wing_albedo.b64").write_text(encoded, encoding="ascii")

    print("Generated cuticle PBR maps and a 512px veined mantis wing map in", ROOT)


if __name__ == "__main__":
    main()
