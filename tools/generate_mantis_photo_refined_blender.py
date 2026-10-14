"""Generate the photo-guided adult mantis source and canonical GLB.

Run with Blender 4.x:
    blender --background --python tools/generate_mantis_photo_refined_blender.py

The model is an authored anatomical interpretation of the supplied front, side,
and dorsal photographs. It is not a scan or a species-level identification.
Coordinates use Blender Z-up; the insect faces -Y. The 62-joint skeleton and
11 clip names are kept compatible with the Godot simulation.
"""
from __future__ import annotations

import json
import math
import struct
import sys
import glob
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MODEL_OUT = ROOT / "assets" / "models" / "mantis_latest.glb"
BLEND_OUT = ROOT / "tools" / "blender_source" / "mantis_photo_refined.blend"
MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
BLEND_OUT.parent.mkdir(parents=True, exist_ok=True)

# Keep the same native proportions and orientation as the current Godot model.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.armatures, bpy.data.actions):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)


# ------------------------------ materials ----------------------------------
def mat(name: str, color: tuple[float, float, float], roughness: float = .45,
        metallic: float = 0.0, subsurface: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = subsurface
    elif "Subsurface" in bsdf.inputs:
        bsdf.inputs["Subsurface"].default_value = subsurface
    return material

shell = mat("Cuticle | translucent spring green", (.37, .63, .20), .34, .0, .05)
shell_light = mat("Cuticle | sunlit lime", (.61, .78, .31), .39, .0, .04)
shell_mid = mat("Cuticle | leaf green", (.29, .51, .15), .43)
shell_shadow = mat("Cuticle | shaded olive", (.16, .29, .085), .54)
membrane = mat("Wing | pale folded tegmen", (.62, .79, .39), .47, .0, .03)
membrane_light = mat("Wing | translucent hindwing", (.73, .86, .54), .56, .0, .02)
vein = mat("Wing | raised vein green", (.32, .52, .20), .49)
vein_light = mat("Wing | fine vein highlight", (.78, .87, .54), .55)
joint_mat = mat("Joint | soft olive membrane", (.24, .38, .13), .60)
spine_mat = mat("Raptorial spines | dark olive", (.18, .27, .075), .51)
underside = mat("Underside | pale yellow green", (.66, .75, .37), .55)
spiracle_mat = mat("Spiracles | recessed olive", (.10, .18, .055), .66)
eye_dark = mat("Compound eye | deep jade pseudopupil", (.035, .10, .045), .17, .0, .02)
eye_green = mat("Compound eye | emerald facets", (.34, .59, .24), .22, .0, .03)
eye_green_2 = mat("Compound eye | light facet", (.54, .72, .35), .25, .0, .03)
eye_green_3 = mat("Compound eye | shaded facet", (.22, .43, .17), .24, .0, .02)
ocellus_mat = mat("Ocelli | amber green", (.72, .72, .32), .23)

parts: list[tuple[bpy.types.Object, str]] = []
bones: dict[str, tuple[tuple[float, ...], tuple[float, ...], str | None]] = {}


def smooth(obj: bpy.types.Object, enabled: bool = True) -> bpy.types.Object:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = enabled
    return obj


def add_mesh(name: str, vertices: list[tuple[float, float, float]],
             faces: list[tuple[int, ...]], material: bpy.types.Material,
             bone_name: str, *, smooth_faces: bool = True,
             face_materials: list[int] | None = None,
             extra_materials: tuple[bpy.types.Material, ...] = ()) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + " geometry")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    for extra in extra_materials:
        mesh.materials.append(extra)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth_faces
        if face_materials and polygon.index < len(face_materials):
            polygon.material_index = face_materials[polygon.index]
    parts.append((obj, bone_name))
    return obj


def ellipsoid(name: str, center: tuple[float, float, float],
              scale: tuple[float, float, float], material: bpy.types.Material,
              bone_name: str, *, segments: int = 32, rings: int = 20,
              rotation: tuple[float, float, float] = (0, 0, 0),
              flat: bool = False) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = rotation
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    smooth(obj, not flat)
    parts.append((obj, bone_name))
    return obj


def rod(name: str, a: tuple[float, float, float] | Vector,
        b: tuple[float, float, float] | Vector, r0: float, r1: float,
        material: bpy.types.Material, bone_name: str, vertices: int = 10) -> bpy.types.Object | None:
    start, end = Vector(a), Vector(b)
    direction = end - start
    if direction.length < 1e-5:
        return None
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r0, radius2=r1,
                                    depth=direction.length, location=(start + end) * .5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    smooth(obj)
    parts.append((obj, bone_name))
    return obj


def curved_rod(name: str, points: list[Vector], radius: float,
               material: bpy.types.Material, bone_name: str,
               *, tapered: bool = True) -> None:
    """Create one continuous low-poly vein/keel mesh along a smooth path."""
    if len(points) < 2:
        return
    radial = 6
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for i, point in enumerate(points):
        before = points[max(0, i - 1)]
        after = points[min(len(points) - 1, i + 1)]
        tangent = (after - before).normalized()
        reference = Vector((0, 0, 1))
        if abs(tangent.dot(reference)) > .92:
            reference = Vector((0, 1, 0))
        axis_u = tangent.cross(reference).normalized()
        axis_v = tangent.cross(axis_u).normalized()
        taper = (.58 + .42 * math.sin(math.pi * i / max(1, len(points) - 1)) ** .35) if tapered else 1.0
        for j in range(radial):
            angle = math.tau * j / radial
            vertex = point + radius * taper * (math.cos(angle) * axis_u + math.sin(angle) * axis_v)
            vertices.append(tuple(vertex))
    for i in range(len(points) - 1):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            faces.append((a, b, c, d))
    add_mesh(name, vertices, faces, material, bone_name)


def bone(name: str, a: tuple[float, float, float], b: tuple[float, float, float],
         parent: str | None = None) -> None:
    bones[name] = (tuple(a), tuple(b), parent)


def swept_segment(name: str, start: tuple[float, float, float], end: tuple[float, float, float],
                  radius_x: float, radius_y: float, material: bpy.types.Material,
                  bone_name: str, *, bulge: float = .20, curve: float = 0.0,
                  rings: int = 24, sides: int = 24) -> bpy.types.Object:
    """Smooth, flattened organic leg segment rather than a straight cone."""
    a, b = Vector(start), Vector(end)
    tangent = (b - a).normalized()
    reference = Vector((0, 0, 1))
    if abs(tangent.dot(reference)) > .90:
        reference = Vector((1, 0, 0))
    axis_u = tangent.cross(reference).normalized()
    axis_v = tangent.cross(axis_u).normalized()
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for i in range(rings + 1):
        t = i / rings
        width = max(.035, math.sin(math.pi * t) ** .42)
        width *= 1.0 + bulge * math.sin(math.pi * t)
        center = a.lerp(b, t) + axis_v * (curve * math.sin(math.pi * t))
        for j in range(sides):
            angle = math.tau * j / sides
            p = center + axis_u * (math.cos(angle) * radius_x * width)
            p += axis_v * (math.sin(angle) * radius_y * width)
            vertices.append(tuple(p))
    for i in range(rings):
        for j in range(sides):
            a0 = i * sides + j
            b0 = i * sides + (j + 1) % sides
            c0 = (i + 1) * sides + (j + 1) % sides
            d0 = (i + 1) * sides + j
            faces.append((a0, b0, c0, d0))
    return add_mesh(name, vertices, faces, material, bone_name)


def body_radius(t: float) -> tuple[float, float]:
    taper = max(.025, math.sin(math.pi * max(.002, min(.998, t)))) ** .54
    width = .151 * taper * (.80 + .35 * t)
    height = .105 * taper * (.90 + .22 * t)
    return width, height


def abdomen_surface(t: float, angle: float, offset: float = 0.0) -> Vector:
    y = -.115 + .685 * t
    rx, rz = body_radius(t)
    return Vector(((rx + offset) * math.cos(angle), y,
                   .215 + (rz + offset) * math.sin(angle)))


def abdomen_shell() -> None:
    # One continuous, subtly arched shell under the separate abdominal plates.
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    axial, radial = 64, 48
    for i in range(axial + 1):
        t = i / axial
        for j in range(radial):
            vertices.append(tuple(abdomen_surface(t, math.tau * j / radial)))
    for i in range(axial):
        for j in range(radial):
            a = i * radial + j
            b = i * radial + (j + 1) % radial
            c = (i + 1) * radial + (j + 1) % radial
            d = (i + 1) * radial + j
            faces.append((a, b, c, d))
    add_mesh("Continuous segmented abdomen core", vertices, faces,
             shell_mid, "Rig_Abdomen")

    # Seven overlapping, individually modeled tergites and ventral sternites.
    segment_materials = (shell_light, shell, shell_mid)
    for index in range(7):
        t0 = .075 + index * .125
        t1 = t0 + .116
        vertices = []
        faces = []
        material_ids = []
        steps_y, steps_a = 6, 48
        for iy in range(steps_y + 1):
            t = t0 + (t1 - t0) * iy / steps_y
            for ia in range(steps_a + 1):
                angle = math.tau * ia / steps_a
                vertices.append(tuple(abdomen_surface(t, angle, .0055)))
        for iy in range(steps_y):
            for ia in range(steps_a):
                a = iy * (steps_a + 1) + ia
                b = a + 1
                c = b + steps_a + 1
                d = a + steps_a + 1
                faces.append((a, b, c, d))
                angle = math.tau * (ia + .5) / steps_a
                material_ids.append(0 if math.sin(angle) > .38 else (1 if math.sin(angle) >= -.20 else 2))
        plate = add_mesh(f"Abdominal tergite {index + 1:02d}", vertices, faces,
                         segment_materials[0], "Rig_Abdomen", face_materials=material_ids,
                         extra_materials=(segment_materials[1], segment_materials[2]))
        # A fine contrasting posterior seam makes each ring legible in close views.
        seam_points = [abdomen_surface(t1, math.tau * j / 24, .008) for j in range(25)]
        curved_rod(f"Tergite seam {index + 1:02d}", seam_points, .0014,
                   shell_shadow, "Rig_Abdomen")
        for side, letter in [(-1, "L"), (1, "R")]:
            tm = (t0 + t1) * .5
            rx, rz = body_radius(tm)
            y = -.115 + .685 * tm
            # The spiracle sits in the pleural plate just under the wing margin.
            ellipsoid(f"Spiracle rim {letter} {index + 1:02d}",
                      (side * (rx + .004), y, .212), (.0045, .012, .008),
                      shell_shadow, "Rig_Abdomen", segments=16, rings=10)
            ellipsoid(f"Spiracle opening {letter} {index + 1:02d}",
                      (side * (rx + .007), y, .212), (.0024, .006, .0043),
                      spiracle_mat, "Rig_Abdomen", segments=12, rings=8)
    # The underside is a slightly lighter flexible membrane with visible folds.
    for i in range(8):
        t = .10 + i * .105
        rx, rz = body_radius(t)
        y = -.115 + .685 * t
        ellipsoid(f"Ventral sternite {i + 1:02d}", (0, y, .215 - rz * .82),
                  (rx * .63, .045, .010), underside, "Rig_Abdomen", segments=20, rings=10)


# ------------------------------ thorax -------------------------------------
# Long prothorax / pronotum: tapered cylinder with an anatomical neck shield.
vertices: list[tuple[float, float, float]] = []
faces: list[tuple[int, int, int, int]] = []
axial, radial = 64, 32
for i in range(axial + 1):
    t = i / axial
    y = -.555 + .485 * t
    width = .047 + .011 * math.sin(math.pi * t) + .009 * math.exp(-((t - .68) / .12) ** 2)
    height = .040 + .010 * math.sin(math.pi * t)
    zc = .298 + .025 * math.sin(math.pi * t)
    for j in range(radial):
        a = math.tau * j / radial
        vertices.append((width * math.cos(a), y, zc + height * math.sin(a)))
for i in range(axial):
    for j in range(radial):
        a = i * radial + j
        b = i * radial + (j + 1) % radial
        c = (i + 1) * radial + (j + 1) % radial
        d = (i + 1) * radial + j
        faces.append((a, b, c, d))
add_mesh("LongPronotumShell", vertices, faces, shell, "Rig_Thorax")

# Broad but low neck shield, paired lateral ridges, and repeated cuticle striae.
ellipsoid("Pronotal shield", (0, -.32, .343), (.061, .173, .044), shell_light,
          "Rig_Thorax", segments=40, rings=24)
curved_rod("Pronotum dorsal keel", [Vector((0, -.51 + .42 * i / 24,
            .365 + .018 * math.sin(math.pi * i / 24))) for i in range(25)],
           .0045, shell_light, "Rig_Thorax")
for side, letter in [(-1, "L"), (1, "R")]:
    curved_rod(f"Pronotum raised margin {letter}",
               [Vector((side * (.048 + .005 * math.sin(math.pi * i / 24)),
                        -.52 + .42 * i / 24, .316 + .018 * math.sin(math.pi * i / 24)))
                for i in range(25)], .0032, shell_mid, "Rig_Thorax")
    for groove in range(7):
        y = -.48 + groove * .055
        width = .052 + .007 * math.sin((groove + 1) * math.pi / 8)
        rod(f"Pronotal transverse stria {letter} {groove:02d}",
            (side * width, y, .329), (side * (width - .012), y + .011, .345),
            .0015, .0007, shell_shadow, "Rig_Thorax", 8)

# Mesothorax / metathorax collar, wing roots, and paired side plates.
ellipsoid("Mesothorax collar", (0, -.025, .286), (.102, .112, .073), shell_mid,
          "Rig_Thorax", segments=36, rings=20)
ellipsoid("Dorsal thoracic plate", (0, -.065, .344), (.076, .095, .024), shell_light,
          "Rig_Thorax", segments=32, rings=18)
for side, letter in [(-1, "L"), (1, "R")]:
    ellipsoid(f"Thoracic pleuron {letter}", (side * .068, -.005, .278),
              (.038, .070, .042), shell, "Rig_Thorax", segments=28, rings=16)
    rod(f"Thoracic suture {letter}", (side * .083, -.065, .27),
        (side * .088, .045, .28), .0025, .0014, shell_shadow, "Rig_Thorax", 8)

# ------------------------------- abdomen -----------------------------------
bone("Rig_Root", (0, 0, .2), (0, -.08, .2))
bone("Rig_Abdomen", (0, .02, .2), (0, .32, .2), "Rig_Root")
bone("Rig_Thorax", (0, -.1, .28), (0, -.52, .31), "Rig_Root")
bone("Rig_Head", (0, -.52, .31), (0, -.70, .32), "Rig_Thorax")
bone("Rig_Wing_L", (-.01, .02, .34), (-.14, .23, .34), "Rig_Abdomen")
bone("Rig_Wing_R", (.01, .02, .34), (.14, .23, .34), "Rig_Abdomen")
bone("Rig_Mandible_L", (-.03, -.73, .28), (-.05, -.79, .25), "Rig_Head")
bone("Rig_Mandible_R", (.03, -.73, .28), (.05, -.79, .25), "Rig_Head")
bone("Rig_Cercus_L", (-.02, .42, .216), (-.035, .49, .20), "Rig_Abdomen")
bone("Rig_Cercus_R", (.02, .42, .216), (.035, .49, .20), "Rig_Abdomen")
abdomen_shell()
for side, letter in [(-1, "L"), (1, "R")]:
    swept_segment(f"Abdominal cercus {letter}",
                  (side * .018, .448, .216), (side * .036, .522, .19),
                  .008, .007, shell_mid, f"Rig_Cercus_{letter}", rings=18, sides=16)

# ------------------------------- head --------------------------------------
def triangular_head() -> None:
    center = Vector((0, -.653, .365))
    sx, sy, sz = .151, .112, .102
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    rings, sides = 28, 48
    for i in range(rings + 1):
        phi = -math.pi / 2 + math.pi * i / rings
        ring = math.cos(phi)
        z = math.sin(phi)
        for j in range(sides):
            theta = math.tau * j / sides
            ux = ring * math.cos(theta)
            uy = ring * math.sin(theta)
            # Narrow clypeus at the front; broad temples behind the eyes.
            width = .58 + .42 * ((uy + 1.0) * .5)
            vertices.append((center.x + ux * sx * width,
                             center.y + uy * sy,
                             center.z + z * sz))
    for i in range(rings):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = (i + 1) * sides + (j + 1) % sides
            d = (i + 1) * sides + j
            faces.append((a, b, c, d))
    add_mesh("Triangular compound-eye head capsule", vertices, faces,
             shell_light, "Rig_Head")

triangular_head()
ellipsoid("Frons face shield", (0, -.754, .344), (.070, .030, .045), shell,
          "Rig_Head", segments=32, rings=18)
ellipsoid("Clypeus", (0, -.773, .300), (.056, .026, .025), shell_light,
          "Rig_Head", segments=28, rings=16)
ellipsoid("Labrum", (0, -.790, .280), (.030, .014, .013), shell_mid,
          "Rig_Head", segments=20, rings=12)
for side, letter in [(-1, "L"), (1, "R")]:
    # Large lateral globes with explicit flat facet color variation.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=22,
                                         location=(side * .132, -.664, .381))
    eye_obj = bpy.context.object
    eye_obj.name = f"CompoundEye_{letter}"
    eye_obj.scale = (.071, .079, .071)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for material in (eye_green, eye_green_2, eye_green_3):
        eye_obj.data.materials.append(material)
    for poly in eye_obj.data.polygons:
        normal = poly.center.normalized()
        shade = (int(abs(normal.x * 7 + normal.y * 11 + normal.z * 13)) % 9)
        poly.material_index = 1 if shade in (0, 4) else (2 if shade in (2, 6) else 0)
        poly.use_smooth = False
    parts.append((eye_obj, "Rig_Head"))
    # The small dark pseudo-pupil on the forward-lateral face gives the same
    # prominent close-up expression as the reference photographs.
    ellipsoid(f"Eye pseudopupil {letter}", (side * .158, -.735, .379),
              (.011, .006, .025), eye_dark, "Rig_Head", segments=24, rings=16)
    ellipsoid(f"Eye catchlight {letter}", (side * .157, -.740, .395),
              (.0038, .003, .007), eye_green_2, "Rig_Head", segments=16, rings=10)
    # Mandible and segmented maxillary palp, each visibly distinct in profile.
    rod(f"Mandible {letter}", (side * .025, -.775, .287),
        (side * .043, -.818, .256), .008, .001, shell_shadow,
        f"Rig_Mandible_{letter}", 10)
    palp_points = [Vector((side * .036, -.766, .295)),
                   Vector((side * .052, -.792, .276)),
                   Vector((side * .061, -.813, .267))]
    for i in range(2):
        rod(f"Maxillary palp {letter} {i}", palp_points[i], palp_points[i + 1],
            .0042 - i * .001, .0020 - i * .0005, underside,
            "Rig_Head", 8)

# Exactly three pale ocelli sit across the centerline of the forehead.
for idx, dx in enumerate((-.026, 0.0, .026)):
    ellipsoid(f"Ocellus {idx + 1}", (dx, -.727, .452 - abs(dx) * .20),
              (.009, .006, .008), ocellus_mat, "Rig_Head", segments=16, rings=10)

# ------------------------------ antennae -----------------------------------
for side, letter in [(-1, "L"), (1, "R")]:
    previous = Vector((side * .045, -.742, .432))
    antenna_points = [previous]
    for i in range(1, 11):
        t = i / 10.0
        point = Vector((side * (.045 + .245 * t + .045 * math.sin(math.pi * t)),
                        -.742 - .37 * t,
                        .432 + .37 * math.sin(math.pi * t) - .055 * t))
        antenna_points.append(point)
    for i in range(10):
        start, end = antenna_points[i], antenna_points[i + 1]
        bn = f"Rig_Antenna_{letter}" if i == 0 else f"Rig_Antenna_{letter}{i}"
        parent = "Rig_Head" if i == 0 else (f"Rig_Antenna_{letter}" if i == 1 else f"Rig_Antenna_{letter}{i - 1}")
        bone(bn, tuple(start), tuple(end), parent)
        # One uninterrupted tube per bone makes the antenna read as a fine
        # flexible filament; the original 10-link rig remains intact.
        mid = start.lerp(end, .5) + Vector((side * .002, -.001, .002))
        curved_rod(f"Antenna {letter} filament {i:02d}",
                   [start, mid, end], .0036 - i * .00019,
                   shell_mid, bn, tapered=False)

# -------------------------- legs and feet ----------------------------------
for side, letter in [(-1, "L"), (1, "R")]:
    # Three pairs are kept in the rig; Godot hides the redundant third pair.
    for index, y in enumerate((-.13, .12, .32)):
        hip = (side * .052, y, .255)
        coxa = (side * .15, y + (index - 1) * .018, .238)
        knee = (side * .275, y + (index - 1) * .055 + .035, .155)
        ankle = (side * .37, y + (index - 1) * .085 + .075, .024)
        toe = (side * .405, y + (index - 1) * .085 + .13, .012)
        coxa_bone = f"Rig_Coxa_{letter}{index}"
        joint_bone = f"Rig_Joint_{letter}{index}"
        tibia_bone = f"Rig_Tibia_{letter}{index}"
        foot_bone = f"Rig_Foot_{letter}{index}"
        bone(coxa_bone, hip, coxa, "Rig_Thorax")
        bone(joint_bone, coxa, knee, coxa_bone)
        bone(tibia_bone, knee, ankle, joint_bone)
        bone(foot_bone, ankle, toe, tibia_bone)
        swept_segment(f"Coxa_{letter}{index}", hip, coxa, .019, .018,
                      shell_mid, coxa_bone, rings=18, sides=16, bulge=.12)
        ellipsoid(f"Joint membrane {letter}{index}", coxa, (.022, .022, .020),
                  joint_mat, coxa_bone, segments=18, rings=12)
        swept_segment(f"Joint_{letter}{index}", coxa, knee, .018, .016,
                      shell, joint_bone, rings=22, sides=18, curve=.008, bulge=.16)
        ellipsoid(f"Knee_{letter}{index}", knee, (.018, .018, .018),
                  shell_light, joint_bone, segments=18, rings=12)
        swept_segment(f"Tibia_{letter}{index}", knee, ankle, .0095, .0085,
                      shell_mid, tibia_bone, rings=24, sides=14, curve=.004, bulge=.08)
        # Fine tibial spines are small but visible in the side and rear views.
        for spine in range(7):
            t = .18 + spine * .105
            base = Vector(knee).lerp(Vector(ankle), t)
            direction = Vector((side * .009, -.012, .010 if spine % 2 else -.011))
            rod(f"Walking tibial spine {letter}{index} {spine:02d}", base,
                base + direction, .0024, .0003, spine_mat, tibia_bone, 7)
        # Five tarsomeres and a forked pair of terminal claws.
        for toe_seg in range(5):
            t0, t1 = toe_seg / 5, (toe_seg + 1) / 5
            start = Vector(ankle).lerp(Vector(toe), t0)
            end = Vector(ankle).lerp(Vector(toe), t1)
            radius = .0046 - toe_seg * .00055
            rod(f"Tarsomere_{letter}{index}_{toe_seg + 1:02d}", start, end,
                radius, radius * .74, underside, foot_bone, 8)
        ellipsoid(f"Arolium {letter}{index}",
                  (toe[0], toe[1] + .008, toe[2] + .002),
                  (.0065, .010, .0035), shell_light, foot_bone, segments=16, rings=8)
        for claw, spread in enumerate((-1, 1)):
            claw_tip = (toe[0] + side * .012 + spread * .005,
                        toe[1] + .018, toe[2] + .004)
            rod(f"Tarsal claw {letter}{index} {claw}", toe, claw_tip,
                .0022, .0002, shell_shadow, foot_bone, 7)

    # Specialized raptorial forelegs: flattened femoral blade, dual hinge,
    # dense inner femoral teeth, and a comb of opposing tibial spines.
    a = (side * .052, -.46, .31)
    b = (side * .16, -.53, .37)
    c = (side * .24, -.68, .42)
    d = (side * .16, -.83, .28)
    e = (side * .13, -.89, .24)
    coxa_bone = f"Rig_Fore_{letter}Coxa"
    femur_bone = f"Rig_ForeFemur_{letter}"
    tibia_bone = f"Rig_ForeTibia_{letter}"
    foot_bone = f"Rig_Fore_{letter}Foot"
    bone(coxa_bone, a, b, "Rig_Thorax")
    bone(femur_bone, b, c, coxa_bone)
    bone(tibia_bone, c, d, femur_bone)
    bone(foot_bone, d, e, tibia_bone)
    swept_segment(f"ForeCoxa_{letter}", a, b, .020, .019, shell_mid,
                  coxa_bone, rings=20, sides=18, curve=.005, bulge=.16)
    ellipsoid(f"Foreleg coxal socket {letter}", a, (.026, .023, .023),
              joint_mat, coxa_bone, segments=20, rings=14)
    swept_segment(f"ForeFemur_{letter}", b, c, .043, .026, shell_light,
                  femur_bone, rings=36, sides=28, curve=.018, bulge=.55)
    # A raised inner edge gives the broad femur its distinct leaf-shaped keel.
    side_axis = Vector((side * .012, -.016, -.004))
    curved_rod(f"Femoral inner keel {letter}",
               [Vector(b).lerp(Vector(c), i / 20) + side_axis * math.sin(math.pi * i / 20)
                for i in range(21)], .0033, shell, femur_bone)
    # Fourteen long teeth alternate with short secondary serrations.
    for tooth in range(14):
        t = .10 + tooth * .056
        base = Vector(b).lerp(Vector(c), t)
        base += Vector((side * .016, -.005, .010 * math.sin(math.pi * t)))
        length = .019 + .010 * math.sin(math.pi * t)
        tip = base + Vector((-side * .006, -.013, -length))
        rod(f"Femoral tooth {letter} {tooth + 1:02d}", base, tip,
            .0044 if tooth % 3 else .0051, .00025, spine_mat, femur_bone, 8)
        if tooth < 13:
            short_t = t + .027
            short_base = Vector(b).lerp(Vector(c), short_t)
            short_base += Vector((side * .014, -.004, .009 * math.sin(math.pi * short_t)))
            rod(f"Femoral secondary tooth {letter} {tooth + 1:02d}", short_base,
                short_base + Vector((-side * .004, -.009, -.011)),
                .0024, .0002, shell_shadow, femur_bone, 7)
    swept_segment(f"ForeTibia_{letter}", c, d, .020, .014, shell,
                  tibia_bone, rings=32, sides=22, curve=-.010, bulge=.18)
    # Opposing tibial comb points inward toward the femoral groove.
    for tooth in range(18):
        t = .08 + tooth * .048
        base = Vector(c).lerp(Vector(d), t)
        base += Vector((-side * .006, .006, -.004))
        length = .014 + .006 * (tooth % 4 == 0)
        tip = base + Vector((side * .005, .014, length))
        rod(f"Tibial comb tooth {letter} {tooth + 1:02d}", base, tip,
            .0031, .0002, spine_mat, tibia_bone, 7)
    swept_segment(f"ForeFoot_{letter}", d, e, .006, .005,
                  underside, foot_bone, rings=14, sides=12, bulge=.05)

# ------------------------------- wings -------------------------------------
def wing_surface(t: float, chord: float, side: int, *, width: float,
                 y_start: float, y_end: float, z_base: float) -> Vector:
    profile = max(.008, math.sin(math.pi * t)) ** .62 * (.82 + .28 * t)
    span = width * profile
    x = side * (.008 + span * chord)
    y = y_start + (y_end - y_start) * t + (chord - .42) * .035 * math.sin(math.pi * t)
    z = z_base + .018 * math.sin(math.pi * t) * math.sin(math.pi * chord)
    z += .003 * math.sin(2 * math.pi * t + chord * 1.7)
    return Vector((x, y, z))


def wing_blade(name: str, side: int, material: bpy.types.Material,
               bone_name: str, *, width: float, y_start: float,
               y_end: float, z_base: float, longitudinal: int = 56,
               crosswise: int = 20) -> None:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int]] = []
    for i in range(longitudinal + 1):
        for j in range(crosswise + 1):
            vertices.append(tuple(wing_surface(i / longitudinal, j / crosswise, side,
                width=width, y_start=y_start, y_end=y_end, z_base=z_base)))
    row = crosswise + 1
    for i in range(longitudinal):
        for j in range(crosswise):
            a = i * row + j
            b = (i + 1) * row + j
            c = b + 1
            d = a + 1
            faces.extend(((a, d, b), (d, c, b)) if side > 0 else ((a, b, d), (d, b, c)))
    add_mesh(name, vertices, faces, material, bone_name)
    # Main longitudinal veins run from the wing root to the tapered tip.
    for vein_index, chord in enumerate((.08, .22, .39, .57, .74, .91)):
        points = [wing_surface(.035 + .93 * k / 32, chord * (.84 + .16 * math.sin(math.pi * k / 32)),
                   side, width=width, y_start=y_start, y_end=y_end, z_base=z_base + .0022)
                  for k in range(33)]
        curved_rod(f"Wing radial vein {side} {vein_index:02d}", points,
                   .0017 if vein_index < 3 else .00115,
                   vein if vein_index % 2 == 0 else vein_light, bone_name)
    # Delicate cross-veins follow the curvature of the broad leaf-like wing.
    for cross_index in range(1, 19):
        t = cross_index / 20
        points = [wing_surface(t, .04 + .91 * k / 12, side,
                   width=width, y_start=y_start, y_end=y_end, z_base=z_base + .0028)
                  for k in range(13)]
        curved_rod(f"Wing crossvein {side} {cross_index:02d}", points,
                   .00085, vein_light if cross_index % 3 == 0 else vein, bone_name)
    # Raised outer margin catches light in side and dorsal views.
    margin = [wing_surface(.02 + .96 * k / 40, 1.0, side,
               width=width, y_start=y_start, y_end=y_end, z_base=z_base + .002)
              for k in range(41)]
    curved_rod(f"Wing raised margin {side}", margin, .0021, shell_light, bone_name)

for side, letter in [(-1, "L"), (1, "R")]:
    bone(f"Rig_Wing_{letter}", (side * .01, .02, .34), (side * .14, .23, .34), "Rig_Abdomen")
    # Layered folded forewing and visible sliver of the hindwing below it.
    wing_blade(f"Wing_Tegmen_{letter}", side, membrane, f"Rig_Wing_{letter}",
               width=.158, y_start=-.155, y_end=.565, z_base=.348)
    wing_blade(f"Hindwing_Membrane_{letter}", side, membrane_light, f"Rig_Wing_{letter}",
               width=.126, y_start=-.075, y_end=.51, z_base=.340,
               longitudinal=44, crosswise=14)
    # A few reinforced costal ribs define the folded margin and overlap seam.
    for rib in range(4):
        chord = .11 + rib * .22
        points = [wing_surface(.06 + .88 * k / 28, chord, side,
                   width=.158, y_start=-.155, y_end=.565, z_base=.353)
                  for k in range(29)]
        curved_rod(f"Tegmen costa {letter} {rib:02d}", points,
                   .00135, shell_mid, f"Rig_Wing_{letter}")

# ----------------------------- armature ------------------------------------
# The retained skeleton has 62 joints: thorax, head, abdomen, wings, 3 walking
# pairs (one hidden by the app), raptorial forelegs, mandibles, cerci, antennae.
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.object
arm.name = "MantisRig"
arm.data.name = "MantisRig_62Joints"
arm.data.edit_bones.remove(arm.data.edit_bones[0])
for name, (head, tail, _parent) in bones.items():
    edit_bone = arm.data.edit_bones.new(name)
    edit_bone.head = head
    edit_bone.tail = tail
for name, (_head, _tail, parent) in bones.items():
    if parent:
        arm.data.edit_bones[name].parent = arm.data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

# Collapse non-control surface pieces into one skinned mesh per joint. The
# named leg sections remain separate so Godot can hide the unused pair and run
# the existing leg-visibility checks without paying for hundreds of draw calls.
protected = set()
for side in ("L", "R"):
    for index in range(3):
        protected.update((f"Coxa_{side}{index}", f"Joint_{side}{index}",
                          f"Tibia_{side}{index}"))
    protected.update((f"ForeCoxa_{side}", f"ForeFemur_{side}",
                      f"ForeTibia_{side}", f"ForeFoot_{side}"))
by_bone: dict[str, list[bpy.types.Object]] = {}
for obj, bone_name in parts:
    if obj.name not in protected:
        by_bone.setdefault(bone_name, []).append(obj)
for bone_name, objects in by_bone.items():
    if len(objects) < 2:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = f"DetailPack_{bone_name}"

# Skin each part to its matching rigid segment; the model remains easy to pose.
for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
    bone_name = None
    for candidate, candidate_bone in parts:
        if obj is candidate or obj.name == f"DetailPack_{candidate_bone}":
            bone_name = candidate_bone
            break
    if bone_name is None:
        continue
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Mantis rigid joint", "ARMATURE")
    modifier.object = arm
    obj.parent = arm

# -------------------------- animation library ------------------------------
def action(name: str, duration: int, amplitude: float,
           patterns: dict[str, object] | None = None) -> None:
    action_data = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = action_data
    pattern = patterns or {}
    base = {
        "Rig_Head": lambda t, a=amplitude: (a * .16 * math.sin(math.tau * t), 0, a * .24 * math.sin(math.tau * t)),
        "Rig_Thorax": lambda t, a=amplitude: (a * .045 * math.sin(math.tau * t), 0, 0),
        "Rig_Abdomen": lambda t, a=amplitude: (a * .055 * math.sin(math.tau * t), 0, 0),
    }
    base.update(pattern)
    for frame in range(0, duration + 1, 2):
        t = frame / max(1, duration)
        for bone_name, fn in base.items():
            if bone_name not in arm.pose.bones:
                continue
            pose = arm.pose.bones[bone_name]
            pose.rotation_mode = "XYZ"
            pose.rotation_euler = fn(t)
            pose.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action_data)
    strip.action_frame_start = 0
    strip.action_frame_end = duration
    arm.animation_data.action = None


def gait_pattern(amplitude: float) -> dict[str, object]:
    out: dict[str, object] = {}
    for side, letter in [(-1, "L"), (1, "R")]:
        for index in range(3):
            phase = (index % 2) * math.pi + (math.pi if side > 0 else 0)
            out[f"Rig_Coxa_{letter}{index}"] = lambda t, a=amplitude, p=phase: (0, 0, a * .38 * math.sin(math.tau * t + p))
            out[f"Rig_Joint_{letter}{index}"] = lambda t, a=amplitude, p=phase: (a * .32 * max(0, math.sin(math.tau * t + p)), 0, 0)
            out[f"Rig_Tibia_{letter}{index}"] = lambda t, a=amplitude, p=phase: (-a * .24 * max(0, math.sin(math.tau * t + p)), 0, 0)
        for index in range(10):
            ant = f"Rig_Antenna_{letter}" if index == 0 else f"Rig_Antenna_{letter}{index}"
            out[ant] = lambda t, a=amplitude, s=side, n=index: (0, a * .07 * math.sin(math.tau * t + s + n * .2), a * .045 * math.sin(2 * math.tau * t + n * .18))
        out[f"Rig_Wing_{letter}"] = lambda t, a=amplitude, s=side: (0, s * a * .035 * math.sin(math.tau * t), 0)
    return out


clips = [
    ("IDLE", 72, .035), ("WALK", 32, .24), ("ALERT", 54, .54),
    ("GROOM", 52, .40), ("HUNT", 40, .35), ("STRIKE", 24, .78),
    ("SCAN", 64, .20), ("FEED", 48, .20), ("CLIMB", 36, .25),
    ("DEFEND", 42, .56), ("FLY", 30, .64),
]
for clip_name, duration, amplitude in clips:
    pattern = gait_pattern(amplitude)
    if clip_name == "SCAN":
        pattern["Rig_Head"] = lambda t: (.035 * math.sin(math.tau * t), 0, .34 * math.sin(math.tau * t))
    elif clip_name in ("ALERT", "STRIKE", "DEFEND"):
        lift = 1.0 if clip_name == "STRIKE" else .62
        for side, letter in [(-1, "L"), (1, "R")]:
            pattern[f"Rig_ForeFemur_{letter}"] = lambda t, a=amplitude, k=lift: (a * k * math.sin(math.pi * t), 0, 0)
            pattern[f"Rig_ForeTibia_{letter}"] = lambda t, a=amplitude, k=lift: (-a * k * .9 * math.sin(math.pi * t), 0, 0)
    elif clip_name == "GROOM":
        pattern["Rig_ForeFemur_L"] = lambda t: (.34 * math.sin(math.pi * t), 0, .08)
        pattern["Rig_ForeTibia_L"] = lambda t: (-.48 * math.sin(math.pi * t), 0, 0)
    elif clip_name == "FEED":
        pattern["Rig_Mandible_L"] = lambda t: (.13 * math.sin(8 * math.pi * t), 0, 0)
        pattern["Rig_Mandible_R"] = lambda t: (-.13 * math.sin(8 * math.pi * t), 0, 0)
    elif clip_name == "FLY":
        for side, letter in [(-1, "L"), (1, "R")]:
            pattern[f"Rig_Wing_{letter}"] = lambda t, s=side: (s * .18 * math.sin(12 * math.pi * t),
                                                                  s * .72 * math.sin(12 * math.pi * t),
                                                                  s * .08 * math.sin(12 * math.pi * t))
    action(clip_name, duration, amplitude, pattern)

# Blender 4.0 has a single active action at a time. NLA owns all named clips.
bpy.context.scene.frame_set(0)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1440
bpy.context.scene.render.resolution_y = 1080
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.world.color = (.08, .10, .06)
bpy.context.scene["model_name"] = "Photo-refined adult mantis"
bpy.context.scene["model_revision"] = "2026-10-14-photo-refined-v1"
bpy.context.scene["reference_views"] = "front, dorsal, rear, left, right"

# Preserve a clearly editable source, then export the exact runtime GLB.
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
# This managed workspace exposes its own Python first on Blender's sys.path;
# the Ubuntu Blender addon also needs the system CPython extension directory.
for candidate in glob.glob("/usr/lib/python*/lib-dynload"):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)
runtime_site = Path(sys.executable).resolve().parents[1] / "lib" / "python3.12" / "site-packages"
if runtime_site.is_dir() and str(runtime_site) not in sys.path:
    sys.path.insert(0, str(runtime_site))
bpy.ops.export_scene.gltf(filepath=str(MODEL_OUT), export_format="GLB",
                          export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_materials="EXPORT",
                          export_texcoords=True, export_normals=True)

# Store provenance in standard glTF extras without changing geometry or clips.
def add_glb_extras(path: Path) -> None:
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise RuntimeError("Blender did not write a GLB file")
    total_length = struct.unpack_from("<I", raw, 8)[0]
    if total_length != len(raw):
        raise RuntimeError(f"GLB length mismatch: header={total_length}, file={len(raw)}")
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    if json_type != 0x4E4F534A:
        raise RuntimeError("GLB JSON chunk is missing")
    document = json.loads(raw[20:20 + json_length].decode("utf-8"))
    document.setdefault("asset", {}).setdefault("extras", {}).update({
        "title": "Photo-refined adult mantis",
        "revision": "2026-10-14-photo-refined-v1",
        "referenceViews": ["front", "dorsal", "rear", "left", "right"],
        "visualBasis": "Hand-authored anatomical interpretation of user-supplied mantis photographs; not photogrammetry.",
        "rig": {"jointCount": 62, "animationClips": 11},
        "visibleStructures": ["compound eyes and pseudopupils", "three ocelli", "curved antennae",
                               "pronotum keel and lateral margins", "segmented tergites and sternites",
                               "paired spiracles", "folded forewings with branching venation",
                               "hindwing membranes", "spined raptorial femora and tibiae",
                               "segmented tarsi and terminal claws"],
    })
    encoded = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((4 - len(encoded) % 4) % 4)
    binary_offset = 20 + json_length
    binary_length, binary_type = struct.unpack_from("<II", raw, binary_offset)
    binary_chunk = raw[binary_offset + 8:binary_offset + 8 + binary_length]
    if binary_type != 0x004E4942:
        raise RuntimeError("GLB binary chunk is missing")
    chunk = struct.pack("<I", len(encoded)) + struct.pack("<I", 0x4E4F534A) + encoded
    chunk += struct.pack("<I", binary_length) + struct.pack("<I", binary_type) + binary_chunk
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(chunk)) + chunk)

add_glb_extras(MODEL_OUT)
print(f"Created editable Blender source: {BLEND_OUT}")
print(f"Created canonical photo-refined GLB: {MODEL_OUT} ({MODEL_OUT.stat().st_size:,} bytes)")
print(f"Rig: {len(bones)} joints; clips: {len(clips)}; mesh nodes: {sum(1 for o in bpy.context.scene.objects if o.type == 'MESH')}")
