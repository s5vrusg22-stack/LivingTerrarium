#!/usr/bin/env python3
"""Add 80 fine wing and thorax features on top of the v3.6 mantis meshes.

This is a deterministic GLB edit, so it can run without Blender and preserves
the existing skeleton and animation clips. Coordinates are local to the
existing Wing_L/R and Thorax mesh nodes.
"""
from __future__ import annotations

import copy
import math
import struct
from pathlib import Path

import upgrade_mantis_glb as glb

MODEL = glb.PROJECT / "assets/models/mantis_rigged.glb"
SOURCE_MARKER = "photo_proportions_v6"
MARKER = "photo_proportions_v7_80_detail"


def append_accessor(doc: dict, binary: bytearray, values: list[tuple[float, ...]],
                    component_type: int, gltf_type: str, target: int,
                    fmt: str) -> int:
    glb.align4(binary)
    start = len(binary)
    packer = struct.Struct("<" + fmt * len(values[0]))
    for value in values:
        binary.extend(packer.pack(*value))
    view_index = len(doc["bufferViews"])
    doc["bufferViews"].append({
        "buffer": 0, "byteOffset": start, "byteLength": len(binary) - start,
        "target": target,
    })
    accessor_index = len(doc["accessors"])
    accessor = {
        "bufferView": view_index, "componentType": component_type,
        "count": len(values), "type": gltf_type,
    }
    if gltf_type != "SCALAR":
        width = len(values[0])
        accessor["min"] = [min(row[i] for row in values) for i in range(width)]
        accessor["max"] = [max(row[i] for row in values) for i in range(width)]
    doc["accessors"].append(accessor)
    return accessor_index


class MeshBuilder:
    def __init__(self) -> None:
        self.positions: list[tuple[float, float, float]] = []
        self.colors: list[tuple[float, float, float, float]] = []
        self.uvs: list[tuple[float, float]] = []
        self.indices: list[int] = []

    def vertex(self, p: tuple[float, float, float], color: tuple[float, float, float, float],
               uv: tuple[float, float] = (0.0, 0.0)) -> int:
        self.positions.append(p)
        self.colors.append(color)
        self.uvs.append(uv)
        return len(self.positions) - 1

    def tri(self, a: int, b: int, c: int) -> None:
        self.indices.extend((a, b, c))

    def grid(self, rows: int, cols: int, point, color, uv, upper: bool = True) -> tuple[list[list[int]], list[list[int]]]:
        top: list[list[int]] = []
        bottom: list[list[int]] = []
        for i in range(rows + 1):
            tr, br = [], []
            t = i / rows
            for j in range(cols + 1):
                across = 2.0 * j / cols - 1.0
                p = point(t, across)
                c = color(t, across)
                uv_value = uv(t, across)
                tr.append(self.vertex(p, c, uv_value))
                br.append(self.vertex((p[0], p[1] - 0.005, p[2]),
                                      (c[0] * 0.78, c[1] * 0.80, c[2] * 0.72, c[3]),
                                      uv_value))
            top.append(tr)
            bottom.append(br)

        for i in range(rows):
            for j in range(cols):
                a, b = top[i][j], top[i][j + 1]
                c, d = top[i + 1][j + 1], top[i + 1][j]
                if upper:
                    self.tri(a, d, c); self.tri(a, c, b)
                else:
                    self.tri(a, b, c); self.tri(a, c, d)
                a, b = bottom[i][j], bottom[i][j + 1]
                c, d = bottom[i + 1][j + 1], bottom[i + 1][j]
                if upper:
                    self.tri(a, b, c); self.tri(a, c, d)
                else:
                    self.tri(a, d, c); self.tri(a, c, b)

        # Close the blade edges with thin chitin walls.
        edges = [
            [(0, j) for j in range(cols + 1)],
            [(rows, j) for j in range(cols + 1)],
            [(i, 0) for i in range(rows + 1)],
            [(i, cols) for i in range(rows + 1)],
        ]
        for edge in edges:
            for k in range(len(edge) - 1):
                i0, j0 = edge[k]; i1, j1 = edge[k + 1]
                a, b = top[i0][j0], bottom[i0][j0]
                c, d = bottom[i1][j1], top[i1][j1]
                self.tri(a, b, c); self.tri(a, c, d)
        return top, bottom

    def tube(self, points: list[tuple[float, float, float]], radius: float,
             color: tuple[float, float, float, float], sides: int = 6) -> None:
        if len(points) < 2:
            return
        first = len(self.positions)
        for i, p in enumerate(points):
            previous = points[max(0, i - 1)]
            following = points[min(len(points) - 1, i + 1)]
            tangent = normalize(sub(following, previous))
            reference = (0.0, 1.0, 0.0)
            if abs(dot(tangent, reference)) > 0.94:
                reference = (1.0, 0.0, 0.0)
            axis_a = normalize(cross(tangent, reference))
            axis_b = normalize(cross(tangent, axis_a))
            taper = min(1.0, 0.35 + min(i, len(points) - i - 1) * 0.65)
            r = radius * taper
            for j in range(sides):
                angle = math.tau * j / sides
                radial = add(scale(axis_a, math.cos(angle)), scale(axis_b, math.sin(angle)))
                q = add(p, scale(radial, r))
                self.vertex(q, color, (j / sides, i / max(1, len(points) - 1)))
        for i in range(len(points) - 1):
            for j in range(sides):
                a = first + i * sides + j
                b = first + i * sides + (j + 1) % sides
                c = first + (i + 1) * sides + (j + 1) % sides
                d = first + (i + 1) * sides + j
                self.tri(a, b, c); self.tri(a, c, d)

    def ellipsoid(self, center: tuple[float, float, float], radii: tuple[float, float, float],
                  color: tuple[float, float, float, float], latitudes: int = 12,
                  longitudes: int = 20) -> None:
        base = len(self.positions)
        for i in range(latitudes + 1):
            phi = -math.pi * 0.5 + math.pi * i / latitudes
            for j in range(longitudes + 1):
                theta = math.tau * j / longitudes
                p = (
                    center[0] + radii[0] * math.cos(phi) * math.cos(theta),
                    center[1] + radii[1] * math.sin(phi),
                    center[2] + radii[2] * math.cos(phi) * math.sin(theta),
                )
                self.vertex(p, color, (j / longitudes, i / latitudes))
        stride = longitudes + 1
        for i in range(latitudes):
            for j in range(longitudes):
                a = base + i * stride + j
                b, c, d = a + 1, a + stride + 1, a + stride
                self.tri(a, b, c); self.tri(a, c, d)

    def torus(self, center: tuple[float, float, float], major: float, minor: float,
              color: tuple[float, float, float, float], segments: int = 24,
              rings: int = 6) -> None:
        base = len(self.positions)
        for i in range(segments):
            theta = math.tau * i / segments
            for j in range(rings):
                phi = math.tau * j / rings
                radial = major + minor * math.cos(phi)
                p = (center[0] + radial * math.cos(theta),
                     center[1] + minor * math.sin(phi),
                     center[2] + radial * math.sin(theta))
                self.vertex(p, color, (i / segments, j / rings))
        for i in range(segments):
            for j in range(rings):
                a = base + i * rings + j
                b = base + ((i + 1) % segments) * rings + j
                c = base + ((i + 1) % segments) * rings + (j + 1) % rings
                d = base + i * rings + (j + 1) % rings
                self.tri(a, b, c); self.tri(a, c, d)


def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def scale(a, factor): return (a[0] * factor, a[1] * factor, a[2] * factor)
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def normalize(a):
    length = math.sqrt(dot(a, a))
    return scale(a, 1.0 / length) if length > 1e-9 else (0.0, 1.0, 0.0)


def forewing_surface(u: float, across: float, side: int, lift: float = 0.0):
    """Match the v3.6 tegmen shell so added veins sit on its upper cuticle."""
    sin_u = max(0.0, math.sin(math.pi * u))
    outline = sin_u ** 0.74 * (0.88 + 0.12 * math.cos(math.pi * (u - 0.10)))
    x = side * (0.145 * outline * across) - side * 0.075
    centerline = 0.004 * math.sin(2.0 * math.pi * u) * sin_u
    camber = 0.012 * math.sin(math.pi * across) * sin_u ** 0.70
    midrib = 0.0048 * math.exp(-((across - 0.50) / 0.035) ** 2) * sin_u ** 0.60
    secondary = 0.0
    for band, height in ((0.24, 0.0018), (0.39, 0.00145), (0.62, 0.00145), (0.78, 0.0012), (0.92, 0.0009)):
        curve = band * (0.92 + 0.08 * math.sin(math.pi * u))
        secondary += height * math.exp(-((across - curve) / 0.022) ** 2) * sin_u ** 0.62
    cross_phase = u * 22.0 - across * 0.42
    distance = abs((cross_phase + 0.5) % 1.0 - 0.5)
    crossvein = 0.00075 * math.exp(-((distance / 0.075) ** 2)) * math.sin(math.pi * across) * sin_u ** 0.45
    y = 0.006 + centerline + camber + midrib + secondary + crossvein + 0.0017 + lift
    z = (u - 0.5) * 1.02
    return x, y, z


def make_forewing_veins(side: int) -> tuple[MeshBuilder, int]:
    """Add 28 individually curved cross-vein paths to one existing wing."""
    mesh = MeshBuilder()
    vein = (0.35, 0.47, 0.20, 1.0)
    detail_count = 0
    for row in range(28):
        u0 = 0.065 + row * (0.87 / 27.0)
        path = []
        for step in range(17):
            q = step / 16.0
            across = 0.10 + 0.86 * q
            u = u0 + 0.012 * math.sin(math.pi * q) * (1.0 if row % 2 == 0 else -1.0)
            path.append(forewing_surface(u, across, side, lift=0.0018))
        mesh.tube(path, 0.00074, vein, sides=5)
        detail_count += 1
    return mesh, detail_count


def make_hindwing(side: int) -> MeshBuilder:
    """Folded, translucent fan membrane beneath each tegmen."""
    mesh = MeshBuilder()
    base = (0.60, 0.70, 0.42, 0.58)

    def point(t: float, signed_across: float):
        across = (signed_across + 1.0) * 0.5
        outline = max(0.0, math.sin(math.pi * t)) ** 0.74
        fan = 0.105 * outline
        fold = 0.0038 * math.sin(across * 14.0 * math.pi) * outline
        x = side * (fan * across) - side * 0.075
        y = -0.014 + fold
        z = (t - 0.5) * 0.78
        return x, y, z

    mesh.grid(44, 18, point, lambda t, a: base,
              lambda t, a: ((a + 1.0) * 0.5, t), upper=True)
    rib = (0.37, 0.49, 0.27, 0.62)
    for row in range(16):
        t = 0.07 + row * 0.057
        path = [point(t, -1.0 + 2.0 * i / 18.0) for i in range(19)]
        mesh.tube(path, 0.00068, rib, sides=4)
    return mesh


def thorax_surface(u: float, phi: float, lift: float = 0.0):
    """Point on the swept v3.6 pronotum, with a small radial surface offset."""
    z = -0.338 + 0.676 * u
    center_y = 0.0746 * (1.0 - 2.0 * u)
    profile = 0.88 + 0.12 * math.sin(math.pi * u) ** 0.65
    collar_groove = 0.045 * (math.exp(-((u - 0.095) / 0.012) ** 2) + math.exp(-((u - 0.925) / 0.014) ** 2))
    collar_lip = 0.030 * (math.exp(-((u - 0.072) / 0.018) ** 2) + math.exp(-((u - 0.895) / 0.020) ** 2))
    width = 0.058 * profile * (1.0 - collar_groove + collar_lip)
    height = 0.068 * profile * (1.0 - collar_groove + collar_lip)
    sn, cs = math.sin(phi), math.cos(phi)
    dorsal = max(0.0, cs)
    keel = 0.0085 * dorsal ** 8 * math.sin(math.pi * u) ** 0.45
    lateral_carina = 0.0032 * math.exp(-((abs(sn) - 0.66) / 0.055) ** 2) * dorsal
    nx, ny = sn / max(width, 1e-6), cs / max(height, 1e-6)
    normal_length = math.sqrt(nx * nx + ny * ny)
    nx, ny = nx / normal_length, ny / normal_length
    return (width * sn + lift * nx,
            center_y + height * cs + keel + lateral_carina + lift * ny,
            z)


def make_thorax_surface_detail() -> tuple[MeshBuilder, int]:
    """Add 24 sutures, spiracles, pleural plates, striae, sockets, and collar accents."""
    mesh = MeshBuilder()
    count = 0
    shadow = (0.22, 0.33, 0.14, 1.0)
    accent = (0.56, 0.66, 0.34, 1.0)
    plate = (0.35, 0.47, 0.21, 1.0)
    pit = (0.075, 0.12, 0.055, 1.0)

    # Four transverse suture arcs follow the upper pronotum curvature.
    for u in (0.22, 0.40, 0.60, 0.78):
        path = [thorax_surface(u, -1.42 + 2.84 * i / 32.0, 0.0016)
                for i in range(33)]
        mesh.tube(path, 0.00110, shadow, sides=4)
        count += 1

    # Six lateral spiracles sit just outside the pleural shell.
    for side in (-1.0, 1.0):
        for u in (0.22, 0.50, 0.78):
            center = thorax_surface(u, side * 1.40, 0.0028)
            mesh.ellipsoid(center, (0.0024, 0.0038, 0.0090), pit,
                           latitudes=8, longitudes=14)
            count += 1

    # Three pairs of raised pleural plates mark the thoracic segment joins.
    for side in (-1.0, 1.0):
        for u in (0.18, 0.48, 0.76):
            center = thorax_surface(u, side * 1.26, 0.0018)
            mesh.ellipsoid(center, (0.0048, 0.0062, 0.021), plate,
                           latitudes=10, longitudes=16)
            count += 1

    # Four longitudinal cuticle striae run between the transverse sutures.
    for phi in (-1.08, -0.67, 0.67, 1.08):
        path = [thorax_surface(0.15 + 0.70 * i / 40.0, phi, 0.0015)
                for i in range(41)]
        mesh.tube(path, 0.00095, accent, sides=4)
        count += 1

    # Paired coxal socket rims lie on the lateral surface near the foreleg root.
    for side in (-1.0, 1.0):
        cx, cy, cz = thorax_surface(0.10, side * 1.28, 0.0040)
        path = [(cx + side * 0.0012,
                 cy + 0.0080 * math.cos(math.tau * i / 32.0),
                 cz + 0.0110 * math.sin(math.tau * i / 32.0))
                for i in range(33)]
        mesh.tube(path, 0.00125, accent, sides=5)
        count += 1

    # Two collar accents trace the grooves already sculpted into the base mesh.
    for u in (0.095, 0.925):
        path = [thorax_surface(u, -1.34 + 2.68 * i / 30.0, 0.0018)
                for i in range(31)]
        mesh.tube(path, 0.00105, accent, sides=4)
        count += 1
    return mesh, count


def vertex_normals(positions, indices):
    return glb.vertex_normals(positions, indices)


def append_mesh(doc: dict, binary: bytearray, mesh_name: str,
                builder: MeshBuilder, joint: tuple[float, ...],
                weight: tuple[float, ...]) -> int:
    normals = vertex_normals(builder.positions, builder.indices)
    count = len(builder.positions)
    joints = [tuple(int(v) for v in joint) for _ in range(count)]
    weights = [tuple(float(v) for v in weight) for _ in range(count)]
    attributes = {
        "POSITION": append_accessor(doc, binary, builder.positions, 5126, "VEC3", 34962, "f"),
        "NORMAL": append_accessor(doc, binary, normals, 5126, "VEC3", 34962, "f"),
        "COLOR_0": append_accessor(doc, binary, builder.colors, 5126, "VEC4", 34962, "f"),
        "JOINTS_0": append_accessor(doc, binary, joints, 5123, "VEC4", 34962, "H"),
        "WEIGHTS_0": append_accessor(doc, binary, weights, 5126, "VEC4", 34962, "f"),
        "TEXCOORD_0": append_accessor(doc, binary, builder.uvs, 5126, "VEC2", 34962, "f"),
    }
    index_accessor = append_accessor(doc, binary,
                                    [(int(i),) for i in builder.indices],
                                    5125, "SCALAR", 34963, "I")
    mesh_index = len(doc["meshes"])
    doc["meshes"].append({
        "name": mesh_name,
        "primitives": [{"attributes": attributes, "indices": index_accessor, "mode": 4}],
    })
    return mesh_index


def node_joint_binding(doc: dict, binary: bytearray, mesh_node: dict):
    primitive = doc["meshes"][mesh_node["mesh"]]["primitives"][0]
    attrs = primitive["attributes"]
    joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])[0]
    weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])[0]
    return joints, weights


def add_bound_node(doc: dict, name: str, mesh_index: int,
                   transform_node: dict) -> int:
    node = {
        "name": name, "mesh": mesh_index, "skin": transform_node.get("skin", 0),
        "matrix": copy.deepcopy(transform_node["matrix"]),
    }
    node_index = len(doc["nodes"])
    doc["nodes"].append(node)
    doc["nodes"][0].setdefault("children", []).append(node_index)
    return node_index


def replace_wing_mesh(doc: dict, binary: bytearray, node: dict,
                      mesh_name: str, builder: MeshBuilder) -> None:
    old_mesh = doc["meshes"][node["mesh"]]
    original_primitive = old_mesh["primitives"][0]
    original_attrs = original_primitive["attributes"]
    joint = glb.read_vectors(doc, binary, original_attrs["JOINTS_0"])[0]
    weight = glb.read_vectors(doc, binary, original_attrs["WEIGHTS_0"])[0]
    normals = vertex_normals(builder.positions, builder.indices)
    count = len(builder.positions)
    attributes = {
        "POSITION": append_accessor(doc, binary, builder.positions, 5126, "VEC3", 34962, "f"),
        "NORMAL": append_accessor(doc, binary, normals, 5126, "VEC3", 34962, "f"),
        "COLOR_0": append_accessor(doc, binary, builder.colors, 5126, "VEC4", 34962, "f"),
        "JOINTS_0": append_accessor(doc, binary, [tuple(int(v) for v in joint)] * count, 5123, "VEC4", 34962, "H"),
        "WEIGHTS_0": append_accessor(doc, binary, [tuple(float(v) for v in weight)] * count, 5126, "VEC4", 34962, "f"),
        "TEXCOORD_0": append_accessor(doc, binary, builder.uvs, 5126, "VEC2", 34962, "f"),
    }
    index_accessor = append_accessor(doc, binary,
                                    [(int(i),) for i in builder.indices],
                                    5125, "SCALAR", 34963, "I")
    old_mesh["name"] = mesh_name
    old_mesh["primitives"] = [{"attributes": attributes, "indices": index_accessor, "mode": 4}]


def main() -> None:
    doc, binary = glb.read_glb(MODEL)
    extras = doc.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("reference_mantis_refinement") in {MARKER, "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100"}:
        print("The 80-detail v7 mantis pass is already applied.")
        return
    if extras.get("reference_mantis_refinement") != SOURCE_MARKER:
        raise ValueError("Expected the v3.6 80x24 mantis meshes; refusing an unknown source.")

    nodes = {node.get("name"): node for node in doc["nodes"]}
    wing_passes = 0
    for side, name in ((-1, "Wing_L"), (1, "Wing_R")):
        wing_node = nodes[name]
        joint, weight = node_joint_binding(doc, binary, wing_node)
        vein_mesh, passes = make_forewing_veins(side)
        vein_index = append_mesh(doc, binary, f"WingVeinDetail_{name[-1]}", vein_mesh,
                                 joint, weight)
        add_bound_node(doc, f"WingVeinDetail_{name[-1]}", vein_index, wing_node)
        wing_passes += passes

    thorax_node = nodes["Thorax"]
    thorax_joint, thorax_weight = node_joint_binding(doc, binary, thorax_node)
    thorax_mesh, thorax_passes = make_thorax_surface_detail()
    thorax_index = append_mesh(doc, binary, "ThoraxSurfaceDetail", thorax_mesh,
                               thorax_joint, thorax_weight)
    add_bound_node(doc, "ThoraxSurfaceDetail", thorax_index, thorax_node)

    for side, name in ((-1, "Wing_L"), (1, "Wing_R")):
        wing_node = nodes[name]
        joint, weight = node_joint_binding(doc, binary, wing_node)
        hindwing_mesh = make_hindwing(side)
        hindwing_index = append_mesh(doc, binary, f"Hindwing_{name[-1]}", hindwing_mesh,
                                     joint, weight)
        add_bound_node(doc, f"Hindwing_{name[-1]}", hindwing_index, wing_node)

    if wing_passes != 56 or thorax_passes != 24:
        raise AssertionError(f"Expected 56 wing + 24 thorax passes; got {wing_passes}+{thorax_passes}")
    extras["reference_mantis_refinement"] = MARKER
    extras["mantis_v7_detail_passes"] = {
        "total": wing_passes + thorax_passes,
        "wing_crossvein_paths": wing_passes,
        "thorax_surface_structures": thorax_passes,
        "base_geometry": "v3.6 80 x 24 wing and pronotum meshes retained",
        "hindwings": "paired folded translucent membranes with 16 ribs each",
    }
    glb.write_glb(MODEL, doc, binary)
    print(f"Added {wing_passes} wing cross-vein paths and {thorax_passes} thorax structures over the retained v3.6 meshes.")


if __name__ == "__main__":
    main()
