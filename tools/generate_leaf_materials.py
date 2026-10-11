"""Create scalable, UV-aligned leaf albedo, normal and roughness maps.

Run from the project root with Python's standard library only:
    python tools/generate_leaf_materials.py
SVG maps retain fine venation while Godot rasterizes them at import time.
"""
from pathlib import Path
import math
import random


SIZE = 1024
ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures"
ROOT.mkdir(parents=True, exist_ok=True)
random.seed(20261011)

def svg_document(definitions: str, content: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}"><defs>{definitions}</defs>{content}</svg>\n'
    )

secondary_albedo = []
secondary_normal = []
secondary_roughness = []
for index in range(13):
    y0 = int(SIZE * (0.045 + index * 0.074))
    y1 = min(SIZE - 8, y0 + int(SIZE * 0.18))
    for side in (-1, 1):
        x1 = SIZE // 2 + side * int(SIZE * 0.44)
        curve = (
            f'M 512 {y0} C {512 + side * 120} {y0 + 22}, '
            f'{512 + side * 320} {y0 + 115}, {x1} {y1}'
        )
        secondary_albedo.append(f'<path d="{curve}" fill="none" stroke="#a8be84" stroke-width="4" opacity="0.58"/>')
        secondary_normal.append(f'<path d="{curve}" fill="none" stroke="#7886ec" stroke-width="5" opacity="0.58"/>')
        secondary_roughness.append(f'<path d="{curve}" fill="none" stroke="#ababab" stroke-width="5" opacity="0.72"/>')

cross_albedo = []
cross_normal = []
cross_roughness = []
for index in range(27):
    y = int(SIZE * (0.06 + index * 0.034))
    reach = int(SIZE * (0.06 + 0.34 * math.sin(math.pi * y / SIZE)))
    path = f'M {512 - reach} {y - 8} Q 512 {y + 10} {512 + reach} {y - 5}'
    cross_albedo.append(f'<path d="{path}" fill="none" stroke="#cad9b0" stroke-width="2" opacity="0.46"/>')
    cross_normal.append(f'<path d="{path}" fill="none" stroke="#7d8aee" stroke-width="2" opacity="0.42"/>')
    cross_roughness.append(f'<path d="{path}" fill="none" stroke="#bdbdbd" stroke-width="2" opacity="0.55"/>')

flecks = []
for _ in range(420):
    x = random.randint(10, SIZE - 10)
    y = random.randint(10, SIZE - 10)
    radius = random.choice((1, 1, 2, 3))
    color = random.choice(("#edf0d6", "#bdc99f", "#dce7c3"))
    flecks.append(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{color}" opacity="0.48"/>')

albedo_defs = '''
<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#c4d5ab"/><stop offset="0.22" stop-color="#d5e2bb"/>
  <stop offset="0.5" stop-color="#e6edcf"/><stop offset="0.78" stop-color="#d5e2bb"/>
  <stop offset="1" stop-color="#c4d5ab"/>
</linearGradient>
<linearGradient id="length" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#f3f0d4" stop-opacity="0.25"/>
  <stop offset="0.5" stop-color="#aec38c" stop-opacity="0.02"/>
  <stop offset="1" stop-color="#7f9a61" stop-opacity="0.25"/>
</linearGradient>
<pattern id="grain" width="48" height="48" patternUnits="userSpaceOnUse">
  <circle cx="5" cy="12" r="1.2" fill="#8fa36f" opacity="0.22"/>
  <circle cx="31" cy="37" r="1" fill="#f7f4dc" opacity="0.45"/>
  <path d="M10 28l12-3M34 9l7 2" stroke="#9eb382" stroke-width="0.8" opacity="0.17"/>
</pattern>'''
albedo_content = (
    '<rect width="1024" height="1024" fill="url(#blade)"/>'
    '<rect width="1024" height="1024" fill="url(#length)"/>'
    '<rect width="1024" height="1024" fill="url(#grain)"/>'
    '<path d="M512 0 C509 280 516 690 512 1024" fill="none" stroke="#829a60" stroke-width="12" opacity="0.30"/>'
    '<path d="M512 0 C510 280 514 690 512 1024" fill="none" stroke="#eff2d6" stroke-width="7" opacity="0.90"/>'
    + ''.join(secondary_albedo) + ''.join(cross_albedo) + ''.join(flecks)
)
(ROOT / "leaf_albedo.svg").write_text(svg_document(albedo_defs, albedo_content), encoding="utf-8")

normal_defs = '''
<linearGradient id="normal" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#7c80f4"/><stop offset="0.5" stop-color="#8080ff"/>
  <stop offset="1" stop-color="#8480f4"/>
</linearGradient>'''
normal_content = (
    '<rect width="1024" height="1024" fill="url(#normal)"/>'
    '<path d="M512 0 C509 280 516 690 512 1024" fill="none" stroke="#8991f2" stroke-width="14" opacity="0.90"/>'
    + ''.join(secondary_normal) + ''.join(cross_normal)
)
(ROOT / "leaf_normal.svg").write_text(svg_document(normal_defs, normal_content), encoding="utf-8")

roughness_defs = '''
<linearGradient id="rough" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#dedede"/><stop offset="0.5" stop-color="#c4c4c4"/>
  <stop offset="1" stop-color="#dedede"/>
</linearGradient>'''
roughness_content = (
    '<rect width="1024" height="1024" fill="url(#rough)"/>'
    '<path d="M512 0 C509 280 516 690 512 1024" fill="none" stroke="#a4a4a4" stroke-width="14" opacity="0.70"/>'
    + ''.join(secondary_roughness) + ''.join(cross_roughness)
)
(ROOT / "leaf_roughness.svg").write_text(svg_document(roughness_defs, roughness_content), encoding="utf-8")

print("Generated three 1024 x 1024 SVG leaf material maps.")
