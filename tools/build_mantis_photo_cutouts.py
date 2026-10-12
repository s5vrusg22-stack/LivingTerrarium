#!/usr/bin/env python3
"""Make alpha cutouts from the user's exact mantis photos (preserve RGB pixels)."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PHOTO_DIR = ROOT / "assets/photo_cutouts"


def isolate(source: Path, destination: Path, style: str):
    original = Image.open(source).convert("RGB")
    hsv = np.asarray(original.convert("HSV"), dtype=np.uint8)
    hue, saturation, value = hsv[..., 0], hsv[..., 1], hsv[..., 2]

    # The dorsal photo is isolated from its near-white paper using saturation;
    # the side photo's warm hand/background is excluded by its green hue range.
    if style == "dorsal":
        keep = (saturation >= 18) & (hue >= 19) & (hue <= 145) & (value >= 35)
        mask = Image.fromarray((keep * 255).astype(np.uint8), "L")
        # Close only tiny gaps in the soft-focus green silhouette.
        mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
        # The original dorsal photo has two nearly colorless antennae, plus
        # brown tarsal tips. The hue key drops these hair-thin features, so
        # restore their exact photographed pixels with antialiased strokes.
        scale = 3
        details = Image.new("L", (original.width * scale, original.height * scale), 0)
        detail_draw = ImageDraw.Draw(details)

        def detail_line(points, width):
            scaled = [(int(x * scale), int(y * scale)) for x, y in points]
            radius = width * scale // 2
            detail_draw.line(scaled, fill=255, width=width * scale, joint="curve")
            for x, y in scaled:
                detail_draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)

        detail_line([(496, 438), (458, 410), (410, 374), (358, 335), (310, 300), (286, 280)], 3)
        # Restore the antenna's low-saturation, hair-thin photographed pixels.
        details = details.resize(original.size, Image.Resampling.LANCZOS)
        mask = Image.fromarray(np.maximum(np.asarray(mask), np.asarray(details)), "L")
    else:
        # The side reference has a human hand behind the insect. Trace the
        # visible body and appendages at high resolution so the hand is removed
        # without keying away the pale blue-green pronotum.
        scale = 3
        mask = Image.new("L", (original.width * scale, original.height * scale), 0)
        draw = ImageDraw.Draw(mask)

        def polygon(points):
            draw.polygon([(int(x * scale), int(y * scale)) for x, y in points], fill=255)

        def limb(points, width):
            scaled = [(int(x * scale), int(y * scale)) for x, y in points]
            stroke = Image.new("L", mask.size, 0)
            stroke_draw = ImageDraw.Draw(stroke)
            stroke_draw.line(scaled, fill=255, width=width * scale, joint="curve")
            radius = width * scale // 2
            for x, y in scaled:
                stroke_draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
            stroke = stroke.resize(original.size, Image.Resampling.LANCZOS)
            stroke = stroke.resize(mask.size, Image.Resampling.LANCZOS)
            draw.bitmap((0, 0), stroke, fill=255)

        # Folded wing and abdomen, long pronotum, and triangular head.
        polygon([(0, 511), (50, 492), (155, 480), (270, 482), (390, 490),
                 (510, 495), (620, 498), (720, 502), (790, 509), (830, 523),
                 (844, 545), (830, 570), (800, 597), (755, 625), (700, 650),
                 (620, 674), (540, 698), (455, 718), (365, 738), (265, 749),
                 (160, 746), (78, 738), (0, 730)])
        polygon([(760, 515), (802, 508), (850, 515), (895, 528), (950, 540),
                 (1015, 551), (1080, 563), (1150, 580), (1220, 600), (1280, 619),
                 (1324, 639), (1344, 658), (1332, 679), (1305, 687), (1273, 678),
                 (1225, 661), (1168, 644), (1100, 629), (1030, 616), (950, 606),
                 (875, 598), (820, 586), (790, 572)])
        polygon([(1266, 652), (1273, 637), (1288, 624), (1305, 620),
                 (1323, 623), (1342, 631), (1359, 644), (1368, 659),
                 (1367, 675), (1356, 690), (1342, 701), (1325, 705),
                 (1308, 700), (1293, 690), (1280, 677), (1270, 665)])

        # Raised support leg crossing the upper-left edge of the source.
        limb([(0, 248), (100, 248), (200, 248), (268, 248), (300, 255),
              (316, 281), (325, 340), (337, 408), (349, 480), (358, 507)], 11)
        # The second raised support leg was absent from the old mask. Its upper
        # brown-green segment and knee continue up from the visible green part.
        limb([(650, 504), (680, 440), (714, 380), (746, 324), (764, 298)], 12)
        limb([(764, 298), (744, 246), (724, 190), (704, 120)], 8)

        # Foreground walking leg: keep the full angular knee and the long
        # distal section all the way to the source's bottom edge. The old mask
        # stopped above its foot and used a brush wide enough to include hand.
        limb([(455, 704), (483, 738), (520, 782), (558, 836),
              (591, 887), (604, 929)], 16)
        limb([(604, 929), (595, 949), (550, 980), (495, 1018),
              (430, 1060), (360, 1101), (300, 1145),
              (267, 1188), (253, 1220), (238, 1243)], 7)
        limb([(300, 1145), (267, 1188), (253, 1220), (238, 1243)], 5)

        # Folded raptorial leg below the head. The blade reaches its original
        # tip; its joint and terminal end are explicitly included so no part
        # disappears at the cutout boundary.
        limb([(1050, 733), (1064, 754), (1090, 781), (1130, 811),
              (1171, 843), (1212, 878), (1250, 913), (1280, 946),
              (1301, 966)], 28)
        limb([(1060, 740), (1041, 722), (1020, 708)], 13)

        # Preserve the antennae and the short green projection visible beyond
        # the head, including the portions that were outside the prior crop.
        limb([(1360, 666), (1392, 710), (1425, 758), (1458, 808)], 3)
        limb([(1346, 679), (1376, 728), (1403, 785), (1426, 843)], 3)
        mask = mask.resize(original.size, Image.Resampling.LANCZOS)

    mask = mask.filter(ImageFilter.GaussianBlur(0.35))
    alpha = np.asarray(mask, dtype=np.uint8)
    bbox = mask.getbbox()
    if not bbox:
        raise RuntimeError(f"No insect pixels found in {source}")
    # Crop only to the completed silhouette plus a comfortable border. All
    # tagged paths are included before this box is computed, so antennae,
    # head, both raised legs, the folded foreleg, and feet remain uncut.
    pad = 18
    left, top, right, bottom = bbox
    crop_box = (max(0, left - pad), max(0, top - pad),
                min(original.width, right + pad), min(original.height, bottom + pad))
    rgba = original.convert("RGBA")
    rgba.putalpha(mask)
    rgba = rgba.crop(crop_box)
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(destination, optimize=True)
    return {"source": source.name, "cutout": destination.name,
            "source_size": list(original.size), "crop": list(crop_box),
            "cutout_size": list(rgba.size), "opaque_pixels": int((alpha > 245).sum())}


def main():
    source_dir = PHOTO_DIR / "source"
    files = [
        isolate(source_dir / "1000157366.jpg", PHOTO_DIR / "mantis_dorsal_photo.png", "dorsal"),
        isolate(source_dir / "1000157339.jpg", PHOTO_DIR / "mantis_side_photo.png", "side"),
    ]
    (PHOTO_DIR / "cutout_manifest.json").write_text(json.dumps(files, indent=2) + "\n")
    for entry in files:
        print(f"Wrote {entry['cutout']} {entry['cutout_size']} from {entry['source']}")


if __name__ == "__main__":
    main()
