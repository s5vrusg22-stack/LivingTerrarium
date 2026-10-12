"""Blender 4.x: blender -b --python tools/generate_mantis_blender.py
Creates an editable anatomically-inspired low-poly base GLB, NOT a photogrammetry asset.
"""
import bpy, math
from mathutils import Vector
from pathlib import Path
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
root=Path(__file__).resolve().parents[1]/'assets'/'models'; root.mkdir(parents=True,exist_ok=True)
def material(name,rgba,rough=.53):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgba,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgba,1);bs.inputs['Roughness'].default_value=rough
 return m
green=material('Chitin green',(.19,.43,.10));dark=material('Joint olive',(.08,.19,.05));eye=material('Compound eyes',(.015,.045,.025),.17)
def ellipsoid(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);return o
def rod(name,a,b,r,mat):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r,radius2=r*.72,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
ellipsoid('Abdomen',(0,.18,.15),(.10,.09,.33),green)
ellipsoid('Thorax',(0,.25,-.31),(.055,.065,.32),green)
ellipsoid('Triangular head',(0,.30,-.67),(.17,.10,.09),green)
for side in (-1,1):
 ellipsoid('Eye', (side*.125,.34,-.72),(.052,.06,.045),eye)
 for i,z in enumerate((.12,-.08,-.28)):
  a=(side*.07,.20,z);b=(side*.20,.15,z+.03);c=(side*.34,-.28,z+.09)
  rod('Walking femur',a,b,.015,green);rod('Walking tibia',b,c,.009,dark)
 a=(side*.05,.27,-.48);b=(side*.20,.41,-.58);c=(side*.17,.20,-.79)
 rod('Raptorial femur',a,b,.026,green);rod('Raptorial tibia',b,c,.020,dark)
 rod('Antenna',(side*.05,.35,-.74),(side*.16,.56,-1.05),.004,dark)
bpy.ops.export_scene.gltf(filepath=str(root/'mantis_base.glb'),export_format='GLB')
print('Created',root/'mantis_base.glb')
