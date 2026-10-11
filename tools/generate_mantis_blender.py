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
green=material('Chitin mint',(.46,.74,.61));dark=material('Joint mint shadow',(.24,.45,.36));eye=material('Compound eyes',(.015,.045,.035),.17)
wing=material('Forewing mint',(.62,.86,.72),.58);hindwing=material('Hindwing pale mint',(.78,.94,.84),.48)
def ellipsoid(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);return o
def rod(name,a,b,r,mat):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r,radius2=r*.72,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
ellipsoid('Abdomen',(0,.18,.15),(.10,.09,.33),green)
for i in range(8):
 z=.15-.24+i*.065
 taper=.72+.28*math.sin((i/7*.82+.09)*math.pi)
 ellipsoid('Abdominal tergite %02d'%i,(0,.185,z),(.118*taper,.073*taper,.047),green)
for side in (-1,1):
 ellipsoid('Tegmen',(side*.065,.248,.15),(.052,.245,.013),wing)
 ellipsoid('Membranous hindwing',(side*.105,.24,.15),(.067,.225,.008),hindwing)
 for j in range(5):
  z0=-.07+j*.10
  rod('Wing vein',(side*.035,.264,z0),(side*.11,.264,z0+.04),.002,dark)
ellipsoid('Thorax',(0,.25,-.31),(.055,.065,.32),green)
ellipsoid('Triangular head',(0,.30,-.67),(.17,.10,.09),green)
for side in (-1,1):
 ellipsoid('Compound eye', (side*.125,.34,-.72),(.067,.074,.065),eye)
 for facet in range(12):
  row=facet//4; col=facet%4
  facet_y=.31+row*.018; facet_z=-.76+col*.022
  dy=facet_y-.34; dz=facet_z+.72
  surface=.125+.067*math.sqrt(max(.05,1-(dy/.074)**2-(dz/.065)**2))+.003
  ellipsoid('Eye facet',(side*surface,facet_y,facet_z),(.005,.006,.006),hindwing)
 for i,z in enumerate((.02,-.22)):
  a=(side*.07,.20,z);b=(side*.20,.15,z+.03);c=(side*.34,-.28,z+.09)
  rod('Walking femur',a,b,.015,green);rod('Walking tibia',b,c,.009,dark)
  for tarsomere in range(5):
   t0=tarsomere/5; t1=(tarsomere+1)/5
   start=Vector(c).lerp(Vector((side*.41,-.32,z+.12)),t0)
   end=Vector(c).lerp(Vector((side*.41,-.32,z+.12)),t1)
   rod('Walking tarsomere %02d'%tarsomere,start,end,.005-tarsomere*.0005,dark)
  tip=Vector((side*.41,-.32,z+.12))
  for claw_side in (-1,1):
   rod('Paired tarsal claw',tip,tip+Vector((side*.018+claw_side*.006,-.025,.008)),.0025,green)
 a=(side*.05,.27,-.48);b=(side*.20,.41,-.58);c=(side*.09,.24,-.69)
 rod('Raptorial coxa',a,b,.022,dark);rod('Enlarged raptorial femur',b,c,.040,green)
 for j in range(8):
  t=(j+1)/9
  base=Vector(b).lerp(Vector(c),t)
  rod('Femoral capture spine',base,base+Vector((-side*.045,0,-.012)),.004,dark)
 d=(side*.05,.18,-.79)
 rod('Folding spined tibia',c,d,.018,dark)
 for j in range(6):
  t=(j+1)/7
  base=Vector(c).lerp(Vector(d),t)
  rod('Tibial capture spine',base,base+Vector((side*.028,0,-.008)),.003,green)
 previous=Vector((side*.05,.35,-.74))
 for j in range(10):
  t=(j+1)/10
  current=Vector((side*(.05+.10*t+.03*math.sin(math.pi*t)),.35+.22*t,-.74-.48*t))
  rod('Curved antenna',previous,current,.0035-j*.0002,dark)
  previous=current
for x,y,z in [(0,.395,-.79),(-.027,.385,-.783),(.027,.385,-.783)]:
 ellipsoid('Ocellus',(x,y,z),(.008,.007,.008),dark)
bpy.ops.export_scene.gltf(filepath=str(root/'mantis_base.glb'),export_format='GLB')
print('Created',root/'mantis_base.glb')
