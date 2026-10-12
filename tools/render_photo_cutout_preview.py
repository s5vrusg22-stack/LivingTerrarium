#!/usr/bin/env python3
"""Render a review sheet for the photo cutouts used by the Godot scene."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "previews/mantis_v8_photo_cutouts.png"


def font(size: int, bold: bool = False):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def leaf(draw, points, fill):
    draw.polygon(points, fill=fill)
    draw.line(points[:2], fill=(91, 127, 66), width=3)


def main():
    width, height = 1440, 860
    sheet = Image.new("RGB", (width, height), (18, 31, 23))
    draw = ImageDraw.Draw(sheet, "RGBA")
    # Soft, low-contrast leaf shapes echo the terrarium without hiding the cutouts.
    for points, color in [
        ([(0, 230), (145, 45), (225, 80), (120, 275)], (50, 83, 45, 90)),
        ([(1250, 0), (1425, 210), (1340, 280), (1205, 85)], (56, 86, 45, 72)),
        ([(1120, 860), (1285, 680), (1375, 710), (1270, 860)], (48, 80, 43, 84)),
        ([(12, 810), (200, 630), (275, 700), (105, 860)], (45, 76, 42, 76)),
    ]:
        leaf(draw, points, color)

    draw.text((52, 30), "MANTIS PHOTO MODE", font=font(31, True), fill=(228, 240, 218))
    draw.text((54, 74), "Original uploaded pixels • optional photo overlay • articulated V7 model is the default", font=font(17), fill=(165, 190, 157))

    cards = [(48, 126, 520, 812), (544, 126, 1392, 812)]
    for box in cards:
        draw.rounded_rectangle(box, radius=20, fill=(27, 47, 34, 205), outline=(98, 128, 81, 180), width=2)

    draw.text((76, 148), "DORSAL CAMERA", font=font(19, True), fill=(208, 229, 191))
    draw.text((572, 148), "SIDE CAMERA", font=font(19, True), fill=(208, 229, 191))

    dorsal = Image.open(ROOT / "assets/photo_cutouts/mantis_dorsal_photo.png").convert("RGBA")
    side = Image.open(ROOT / "assets/photo_cutouts/mantis_side_photo.png").convert("RGBA")
    dorsal.thumbnail((390, 600), Image.Resampling.LANCZOS)
    side.thumbnail((790, 545), Image.Resampling.LANCZOS)
    sheet.paste(dorsal, (85 + (390 - dorsal.width) // 2, 190 + (600 - dorsal.height) // 2), dorsal)
    sheet.paste(side, (574 + (790 - side.width) // 2, 195 + (545 - side.height) // 2), side)

    draw.text((75, 775), "Top image switches on overhead view", font=font(14), fill=(169, 191, 162))
    draw.text((572, 775), "Side image switches on lower view • whole-photo pose motion", font=font(14), fill=(169, 191, 162))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, optimize=True)
    print(f"Wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
