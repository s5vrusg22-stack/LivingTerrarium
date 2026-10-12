"""Build a tileable pale-green mantis cuticle texture and matching PBR maps.

Requires NumPy and Pillow. Run from any directory with:
    python tools/generate_mantis_cuticle_texture.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


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


def build_wing_maps() -> None:
    """Generate a dedicated, non-tiling leaf-wing texture and PBR maps.

    UV x follows the forewing chord and UV y follows its length. The broad
    primary veins fan toward the trailing edge; finer cross-veins break the
    surface into small, softly pigmented cells.
    """
    size = SIZE
    scale = 2
    hi = size * scale
    ROOT.mkdir(parents=True, exist_ok=True)
    major_layer = Image.new("L", (hi, hi), 0)
    minor_layer = Image.new("L", (hi, hi), 0)
    major_draw = ImageDraw.Draw(major_layer)
    minor_draw = ImageDraw.Draw(minor_layer)

    # A central midrib and bowed primary veins give the tegmen a leaf-like fan.
    major_draw.line(
        [(int((0.055 + 0.040 * t) * hi), int(t * hi)) for t in np.linspace(0.0, 1.0, 97)],
        fill=255,
        width=5 * scale,
    )
    for vein_index in range(1, 19):
        lane = float(vein_index) / 19.0
        points = []
        for t in np.linspace(0.015, 0.985, 97):
            spread = 0.17 + 0.83 * (t ** 0.74)
            u = 0.075 + lane * 0.91 * spread + 0.007 * np.sin(t * 11.0 + lane * 8.0)
            points.append((int(np.clip(u, 0.0, 0.995) * hi), int(t * hi)))
        major_draw.line(points, fill=205 if vein_index % 3 else 235, width=(2 if vein_index % 4 else 3) * scale)

    # Short, curved cross-veins create fine areoles between the longitudinal ribs.
    for cross_index in range(1, 35):
        t0 = float(cross_index) / 35.0
        points = []
        for step in range(49):
            s = float(step) / 48.0
            u = 0.10 + 0.82 * s * (0.72 + 0.28 * np.sin(t0 * np.pi * 0.5))
            t = t0 + 0.012 * np.sin(np.pi * s) + 0.003 * np.sin(s * 5.0 * np.pi + t0 * 41.0)
            points.append((int(u * hi), int(np.clip(t, 0.0, 1.0) * hi)))
        minor_draw.line(points, fill=175, width=1 * scale)

    major = np.asarray(major_layer.filter(ImageFilter.GaussianBlur(0.55 * scale)), dtype=np.float32) / 255.0
    minor = np.asarray(minor_layer.filter(ImageFilter.GaussianBlur(0.45 * scale)), dtype=np.float32) / 255.0
    major = major.reshape(size, scale, size, scale).mean(axis=(1, 3))
    minor = minor.reshape(size, scale, size, scale).mean(axis=(1, 3))

    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u = x / float(size - 1)
    t = y / float(size - 1)
    rng = np.random.default_rng(718)
    grain = rng.normal(0.0, 1.0, (size, size)).astype(np.float32)
    broad = periodic_band_noise(size, 1.0, 7.0, 718)
    mid = periodic_band_noise(size, 6.0, 36.0, 719)

    # Pale mint base with restrained green variation and shaded wing margins.
    variation = broad * 2.6 + mid * 1.4 + grain * 0.55 - u * 7.0 + 2.0 * np.sin(t * np.pi)
    base = np.stack(
        (
            220.0 + variation,
            236.0 + variation,
            203.0 + variation * 0.72,
        ),
        axis=-1,
    )
    vein_strength = np.clip(major * 0.30 + minor * 0.17, 0.0, 0.48)[..., None]
    vein_color = np.array([129.0, 164.0, 103.0], dtype=np.float32)
    albedo = np.clip(base * (1.0 - vein_strength) + vein_color * vein_strength, 0.0, 255.0)
    Image.fromarray(np.uint8(albedo), "RGB").save(ROOT / "mantis_wing_albedo.png", optimize=True)

    # A shallow relief field makes the micro-veins catch light without looking embossed.
    height = np.clip(0.48 + major * 0.080 + minor * 0.035 + broad * 0.0025 + mid * 0.0015, 0.0, 1.0)
    gy, gx = np.gradient(height)
    strength = 10.0
    normals = np.stack((-gx * strength, -gy * strength, np.ones_like(height)), axis=-1)
    normals /= np.maximum(np.linalg.norm(normals, axis=2, keepdims=True), 1e-8)
    normal_rgb = np.uint8(np.clip(normals * 0.5 + 0.5, 0.0, 1.0) * 255.0)
    Image.fromarray(normal_rgb, "RGB").save(ROOT / "mantis_wing_normal.png", optimize=True)

    roughness = np.clip(0.70 - major * 0.10 - minor * 0.035 + mid * 0.014, 0.54, 0.78)
    Image.fromarray(np.uint8(roughness * 255.0), "L").save(ROOT / "mantis_wing_roughness.png", optimize=True)


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
    build_wing_maps()

    print("Generated tileable cuticle maps and dedicated mint wing albedo, normal, and roughness maps in", ROOT)


if __name__ == "__main__":
    main()
