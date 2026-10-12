#!/usr/bin/env python3
"""Render offline v4.8 review captures directly from the rigged mantis GLB.

Requires numpy, Pillow, and matplotlib. This is a static bind-pose preview,
not a screenshot from a running Godot window.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/mantis_mplconfig")

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import upgrade_mantis_glb as glb


PROJECT = Path(__file__).resolve().parents[1]
MODEL = PROJECT / "assets/models/mantis_rigged.glb"
OUT = PROJECT / "previews"
MODEL_SCALE = 1.18 + 0.35 * 0.45  # Current habitat scale at the default growth.


def _read_color(doc, binary, accessor_index):
    accessor = doc["accessors"][accessor_index]
    values = np.asarray(glb.read_vectors(doc, binary, accessor_index), dtype=np.float64)
    if accessor.get("normalized", False):
        denominator = {5121: 255.0, 5123: 65535.0, 5125: 4294967295.0}.get(accessor["componentType"], 1.0)
        values /= denominator
    return values[:, :3]


def _matrix(node):
    if "matrix" in node:
        return np.asarray(node["matrix"], dtype=np.float64).reshape((4, 4), order="F")
    # GLB meshes in this project use matrices; support TRS as a safe fallback.
    t = np.asarray(node.get("translation", (0, 0, 0)), dtype=np.float64)
    s = np.asarray(node.get("scale", (1, 1, 1)), dtype=np.float64)
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    rotation = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    result = np.eye(4)
    result[:3, :3] = rotation @ np.diag(s)
    result[:3, 3] = t
    return result


def _sample(texture, uv):
    # glTF UV origin is bottom-left; image arrays use a top-left origin.
    h, w = texture.shape[:2]
    u = np.mod(uv[:, 0], 1.0)
    v = np.mod(uv[:, 1], 1.0)
    x = np.minimum((u * (w - 1)).astype(int), w - 1)
    y = np.minimum(((1.0 - v) * (h - 1)).astype(int), h - 1)
    return texture[y, x]


def read_scene():
    doc, binary = glb.read_glb(MODEL)
    all_points, all_normals, all_colors, all_uvs, all_texture_kind, all_faces = [], [], [], [], [], []
    offset = 0
    for node in doc.get("nodes", []):
        if "mesh" not in node:
            continue
        mesh = doc["meshes"][node["mesh"]]
        transform = _matrix(node)
        normal_transform = np.linalg.inv(transform[:3, :3]).T
        for primitive in mesh.get("primitives", []):
            attrs = primitive.get("attributes", {})
            local = np.asarray(glb.read_vectors(doc, binary, attrs["POSITION"]), dtype=np.float64)
            homogeneous = np.column_stack((local, np.ones(len(local))))
            points = (homogeneous @ transform.T)[:, :3]
            if "NORMAL" in attrs:
                normals = np.asarray(glb.read_vectors(doc, binary, attrs["NORMAL"]), dtype=np.float64) @ normal_transform.T
                normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
            else:
                normals = np.tile((0.0, 1.0, 0.0), (len(local), 1))
            colors = _read_color(doc, binary, attrs["COLOR_0"]) if "COLOR_0" in attrs else np.tile((0.40, 0.55, 0.24), (len(local), 1))
            name = node.get("name", mesh.get("name", ""))
            if name.startswith(("Wing_", "WingVeinDetail_", "Hindwing_")) and "TEXCOORD_0" in attrs:
                uv = np.asarray(glb.read_vectors(doc, binary, attrs["TEXCOORD_0"]), dtype=np.float64)
                texture_kind = np.ones(len(local), dtype=np.uint8)
            elif name.startswith(("EyePupil_", "EyeGlint_")):
                uv = np.zeros((len(local), 2), dtype=np.float64)
                texture_kind = np.zeros(len(local), dtype=np.uint8)
            elif name.startswith("Eye_"):
                if "TEXCOORD_0" in attrs:
                    uv = np.asarray(glb.read_vectors(doc, binary, attrs["TEXCOORD_0"]), dtype=np.float64)
                else:
                    radius = np.maximum(np.linalg.norm(local, axis=1), 1e-9)
                    uv = np.column_stack((0.5 + np.arctan2(local[:, 2], local[:, 0]) / (2.0 * np.pi),
                                          0.5 + np.arcsin(np.clip(local[:, 1] / radius, -1.0, 1.0)) / np.pi))
                texture_kind = np.full(len(local), 3, dtype=np.uint8)
            elif not name.startswith("Eye_"):
                uv = np.column_stack((local[:, 2] * 18.0, local[:, 0] * 18.0))
                texture_kind = np.full(len(local), 2, dtype=np.uint8)
            else:
                uv = np.zeros((len(local), 2), dtype=np.float64)
                texture_kind = np.zeros(len(local), dtype=np.uint8)
            if "indices" in primitive:
                indices = np.asarray(glb.read_indices(doc, binary, primitive["indices"]), dtype=np.int64)
            else:
                indices = np.arange(len(points), dtype=np.int64)
            if primitive.get("mode", 4) != 4:
                continue
            faces = indices.reshape(-1, 3) + offset
            all_points.append(points)
            all_normals.append(normals)
            all_colors.append(colors)
            all_uvs.append(uv)
            all_texture_kind.append(texture_kind)
            all_faces.append(faces)
            offset += len(points)
    return (np.concatenate(all_points), np.concatenate(all_normals),
            np.concatenate(all_colors), np.concatenate(all_uvs),
            np.concatenate(all_texture_kind), np.concatenate(all_faces))


def unit(vector):
    vector = np.asarray(vector, dtype=np.float64)
    return vector / max(float(np.linalg.norm(vector)), 1e-9)


def rasterize(points, normals, colors, uvs, texture_kind, faces, eye, focus, world_up, xlim, ylim):
    direction = unit(np.asarray(eye, dtype=float) - np.asarray(focus, dtype=float))
    right = unit(np.cross(np.asarray(world_up, dtype=float), direction))
    up = unit(np.cross(direction, right))
    center = np.asarray(focus, dtype=np.float64) * MODEL_SCALE
    points = points * MODEL_SCALE
    relative = points - center
    sx, sy, depth = relative @ right, relative @ up, relative @ direction

    width = 1500
    height = max(650, min(1700, int(width * (ylim[1] - ylim[0]) / (xlim[1] - xlim[0]))))
    px = (sx - xlim[0]) / (xlim[1] - xlim[0]) * (width - 1)
    py = (ylim[1] - sy) / (ylim[1] - ylim[0]) * (height - 1)
    zbuffer = np.full((height, width), -np.inf, dtype=np.float32)
    rgba = np.zeros((height, width, 4), dtype=np.uint8)

    light = unit((0.65, 0.90, -0.35))
    half_vector = unit(light + direction)
    diffuse = np.maximum(0.0, normals @ light)
    light_gain = 0.78 + 0.62 * diffuse
    specular = np.maximum(0.0, normals @ half_vector) ** 18 * 0.10
    wing_tex = np.asarray(Image.open(PROJECT / "assets/textures/mantis_wing_detail.png").convert("RGB"), dtype=np.float64) / 255.0
    body_tex = np.asarray(Image.open(PROJECT / "assets/textures/mantis_cuticle_detail_albedo.png").convert("RGB"), dtype=np.float64) / 255.0
    eye_path = PROJECT / "assets/textures/mantis_eye_albedo_v49.png"
    if not eye_path.is_file():
        eye_path = PROJECT / "assets/textures/mantis_eye_albedo.png"
    eye_tex = np.asarray(Image.open(eye_path).convert("RGB"), dtype=np.float64) / 255.0

    for face in faces:
        fx, fy, fz = px[face], py[face], depth[face]
        min_x = max(0, int(np.floor(fx.min())))
        max_x = min(width - 1, int(np.ceil(fx.max())))
        min_y = max(0, int(np.floor(fy.min())))
        max_y = min(height - 1, int(np.ceil(fy.max())))
        if min_x > max_x or min_y > max_y:
            continue
        denom = (fy[1] - fy[2]) * (fx[0] - fx[2]) + (fx[2] - fx[1]) * (fy[0] - fy[2])
        if abs(denom) < 1e-7:
            continue
        grid_x, grid_y = np.meshgrid(np.arange(min_x, max_x + 1) + 0.5,
                                     np.arange(min_y, max_y + 1) + 0.5)
        w0 = ((fy[1] - fy[2]) * (grid_x - fx[2]) + (fx[2] - fx[1]) * (grid_y - fy[2])) / denom
        w1 = ((fy[2] - fy[0]) * (grid_x - fx[2]) + (fx[0] - fx[2]) * (grid_y - fy[2])) / denom
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-5) & (w1 >= -1e-5) & (w2 >= -1e-5)
        if not np.any(inside):
            continue
        z = w0 * fz[0] + w1 * fz[1] + w2 * fz[2]
        zview = zbuffer[min_y:max_y + 1, min_x:max_x + 1]
        mask = inside & (z > zview)
        if not np.any(mask):
            continue
        pixel_base = (w0[..., None] * colors[face[0]] + w1[..., None] * colors[face[1]] +
                      w2[..., None] * colors[face[2]])
        pixel_gain = w0 * light_gain[face[0]] + w1 * light_gain[face[1]] + w2 * light_gain[face[2]]
        pixel_specular = w0 * specular[face[0]] + w1 * specular[face[1]] + w2 * specular[face[2]]
        sample_kind = int(texture_kind[face[0]])
        if sample_kind:
            uv = (w0[..., None] * uvs[face[0]] + w1[..., None] * uvs[face[1]] +
                  w2[..., None] * uvs[face[2]])
            texture = wing_tex if sample_kind == 1 else eye_tex if sample_kind == 3 else body_tex
            th, tw = texture.shape[:2]
            u = np.mod(uv[..., 0], 1.0)
            v = np.mod(uv[..., 1], 1.0)
            tx = np.minimum((u * (tw - 1)).astype(int), tw - 1)
            ty = np.minimum(((1.0 - v) * (th - 1)).astype(int), th - 1)
            texel = texture[ty, tx] ** (1.8 if sample_kind == 1 else 1.35)
            if sample_kind == 3:
                pixel_base = np.broadcast_to(np.array((0.78, 0.90, 0.72)), pixel_base.shape).copy()
                texel = texture[ty, tx] ** 0.85
            elif sample_kind == 2:
                texel = 0.58 + 0.42 * texel
            pixel_base *= texel
        pixel_color = pixel_base * pixel_gain[..., None] + pixel_specular[..., None] * np.array((0.64, 0.78, 0.46))
        color_view = rgba[min_y:max_y + 1, min_x:max_x + 1]
        color_view[mask, :3] = np.clip(pixel_color[mask] * 255.0, 0, 255).astype(np.uint8)
        color_view[mask, 3] = 255
        zview[mask] = z[mask]
    return rgba


def capture(points, normals, colors, uvs, texture_kind, faces, filename, title, subtitle,
            eye, focus, world_up, crop=None, version="v4.8", footer=None):
    xlim, ylim = crop or ((-1.48, 1.48), (-1.02, 1.02))
    model = rasterize(points, normals, colors, uvs, texture_kind, faces, eye, focus, world_up, xlim, ylim)
    fig = plt.figure(figsize=(14.4, 9.6), dpi=150, facecolor="#111a16")
    ax = fig.add_axes((0.035, 0.09, 0.93, 0.73), facecolor="#17231c")
    yy, xx = np.mgrid[0:360, 0:600]
    glow = np.exp(-(((xx - 325) / 260) ** 2 + ((yy - 180) / 230) ** 2))
    backdrop = np.stack((0.075 + 0.105 * glow, 0.105 + 0.14 * glow, 0.085 + 0.10 * glow), axis=-1)
    ax.imshow(backdrop, extent=(-2.2, 2.2, -1.8, 1.8), origin="lower", zorder=0, aspect="auto")
    ax.add_patch(Ellipse((0.0, -0.79 if crop is None else -0.18),
                         1.05 if crop is None else 0.57, 0.25 if crop is None else 0.15,
                         facecolor="#07100d", edgecolor="none", alpha=0.42, zorder=1))
    ax.imshow(model, extent=(xlim[0], xlim[1], ylim[0], ylim[1]), origin="upper",
              interpolation="bilinear", zorder=3)
    ax.set_xlim(*xlim)
    ax.set_ylim(*ylim)
    ax.set_aspect("equal", adjustable="box")
    ax.axis("off")
    fig.text(0.065, 0.936, "LIVING TERRARIUM 3D  /  MANTIS MODEL", color="#c7d6c8",
             fontsize=11, fontweight="bold", family="DejaVu Sans", zorder=20)
    fig.text(0.065, 0.887, title, color="#f1f5ed", fontsize=23, fontweight="bold",
             family="DejaVu Sans", zorder=20)
    fig.text(0.065, 0.849, subtitle, color="#a8bcaa", fontsize=11, family="DejaVu Sans", zorder=20)
    fig.text(0.935, 0.936, f"{version}  ·  OFFLINE GEOMETRY PREVIEW", color="#91a995", fontsize=9,
             ha="right", family="DejaVu Sans", zorder=20)
    fig.text(0.065, 0.043, footer or "Separated head  ·  attached double-hinge forelegs  ·  100 surface details",
             color="#829687", fontsize=9, family="DejaVu Sans", zorder=20)
    fig.savefig(OUT / filename, dpi=150, facecolor=fig.get_facecolor(), bbox_inches=None)
    plt.close(fig)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    points, normals, colors, uvs, texture_kind, faces = read_scene()
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_overview.png", "Separate head, slim neck and two-hinge forelegs",
            "Three-quarter bind-pose view · tapered head-to-thorax line", (3.8, 2.3, -4.4),
            (0.0, 0.18, -0.12), (0.0, 1.0, 0.0))
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_profile.png", "Slim prothorax and full leaf-like wing covers",
            "Side view · head separated by a tapered pronotum", (4.6, 2.3, -0.18),
            (0.0, 0.24, -0.18), (0.0, 1.0, 0.0), crop=((-1.85, 1.85), (-1.05, 1.25)))
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_wings.png", "Raised veins over broader sculpted wings",
            "Dorsal view · expanded paired tegmina with separate translucent hindwings", (0.10, 5.0, 0.12),
            (0.0, 0.15, 0.34), (0.0, 0.0, -1.0), crop=((-0.38, 0.38), (-0.72, 1.24)))
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_forelegs.png", "Both raptorial legs with two clear hinges",
            "Front close-up · attached coxa, outward femur, inward folding tibia", (0.0, 0.30, -5.0),
            (0.0, -0.015, -0.59), (0.0, 1.0, 0.0), crop=((-0.50, 0.50), (-0.40, 0.45)))
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_forelegs_side.png", "Attached coxa and two folding foreleg joints",
            "Lateral close-up · long femur folds into the toothed tibia", (5.0, 0.70, -1.90),
            (0.0, -0.07, -0.54), (0.0, 1.0, 0.0), crop=((-0.48, 0.48), (-0.42, 0.42)))
    capture(points, normals, colors, uvs, texture_kind, faces,
            "mantis_v48_head_neck.png", "A separate triangular head on an elongated neck",
            "Side close-up · tapered prothorax meets the head through a slim link", (5.0, 0.58, -0.48),
            (0.0, 0.32, -0.79), (0.0, 1.0, 0.0), crop=((-0.42, 0.42), (-0.20, 0.34)))
    print("Rendered six offline bind-pose previews to", OUT)


if __name__ == "__main__":
    main()
