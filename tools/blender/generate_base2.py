"""Base2 procedural mantis prototype for Blender 4.x.
Run: blender -b -t 4 --python tools/blender/generate_base2.py
Produces assets/models/base2.glb and assets/models/base2.blend.
Coordinates: +Z up in Blender; exported glTF uses its standard axis conversion.
This is a first-pass anatomical blockout, NOT a photoreal finished asset.
"""
import bpy
import math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, rgba, roughness=0.65, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgba, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgba, 1)
    bs.inputs["Roughness"].default_value = roughness
    bs.inputs["Metallic"].default_value = metallic
    return m

green = material("chitin_olive_green", (.21,.39,.095), .51)
pale = material("chitin_ventral", (.41,.55,.18), .64)
dark = material("joint_membrane", (.085,.115,.045), .8)
eye = material("compound_eye_brown", (.20,.125,.075), .27)
wing = material("wing_leaf", (.26,.43,.14), .68)
vein = material("wing_veins", (.15,.29,.07), .73)
spine = material("spines", (.26,.34,.09), .55)

def uvball(name, xyz, scale, mat, seg=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=xyz)
    o=bpy.context.object; o.name=name
    o.scale=scale; o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    return o

def tube(name, a, b, r1, r2, mat, vertices=12):
    a,b=Vector(a),Vector(b); direction=b-a
    mid=(a+b)*.5
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2,
                                   depth=direction.length, location=mid)
    o=bpy.context.object; o.name=name
    o.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth=True
    return o

def chain(name, pts, radii, mat):
    for i in range(len(pts)-1):
        tube(f"{name}_{i}",pts[i],pts[i+1],radii[i],radii[i+1],mat)
        uvball(f"{name}_joint_{i}",pts[i],(radii[i]*1.1,)*3,dark,12,8)

# Anatomical axes: head forward (-Y), abdomen backward (+Y).
uvball("head_triangular_base",(0,-1.13,1.18),(.35,.21,.19),green,32,16)
for side in (-1,1):
    uvball(f"compound_eye_{side}",(side*.305,-1.18,1.245),(.115,.145,.14),eye,32,16)
    uvball(f"mandible_{side}",(side*.085,-1.32,1.04),(.065,.10,.055),pale)
    chain(f"antenna_{side}",[(side*.14,-1.29,1.32),
          (side*.24,-1.65,1.48),(side*.33,-2.05,1.63),(side*.4,-2.40,1.62)],
          [.014,.011,.007,.003],dark)

# Pronotum/prothorax: long, narrow, gently tapered.
chain("pronotum",[(0,-.99,1.09),(0,-.66,1.07),(0,-.20,1.03),(0,.21,1.02)],
      [.11,.155,.19,.17],green)
uvball("thorax",(0,.30,1.01),(.27,.33,.25),green)
for i in range(7):
    y=.63+i*.22
    factor=math.sin(math.pi*(i+1)/9)
    uvball(f"abdomen_tergite_{i+1}",(0,y,1.0-i*.018),
           (.24+.17*factor,.17,.18+.07*factor),green,24,12)
    uvball(f"abdomen_sternite_{i+1}",(0,y,.83-i*.018),
           (.19+.13*factor,.145,.065),pale,20,10)

# Articulated legs with independent named segments for later rigging.
for side in (-1,1):
    for idx, y in enumerate((.26,.55,.78)):
        hip=(side*.19,y,1.0)
        knee=(side*(.43+idx*.07),y+(.06 if idx else -.12),.69)
        ankle=(side*(.70+idx*.13),y+(.18+idx*.13),.18)
        foot=(side*(.79+idx*.16),y+(.33+idx*.14),.065)
        chain(f"walking_leg_{side}_{idx}",[hip,knee,ankle,foot],
              [.065,.052,.024,.009],green)

# Raptorial forelegs: coxa, broad femur, folding tibia and tarsus.
for side in (-1,1):
    coxa=(side*.16,-.69,1.06)
    elbow=(side*.41,-.91,.92)
    femur_end=(side*.62,-1.34,1.01)
    tibia_end=(side*.44,-1.68,1.17)
    tip=(side*.39,-1.78,1.18)
    chain(f"raptorial_{side}",[coxa,elbow,femur_end,tibia_end,tip],
          [.075,.095,.115,.042,.009],green)
    # Separate tapered spines along the inner femur.
    for k in range(11):
        t=(k+1)/12
        base=Vector(elbow).lerp(Vector(femur_end),t)
        length=.05+.075*math.sin(t*math.pi)
        tube(f"femoral_spine_{side}_{k}",base,
             base+Vector((-side*length,-.02,.018)),.017,.001,spine,8)
    for k in range(8):
        t=(k+1)/9
        base=Vector(femur_end).lerp(Vector(tibia_end),t)
        tube(f"tibial_spine_{side}_{k}",base,
             base+Vector((-side*.055,.016,-.008)),.012,.001,spine,8)

# Thin curved leaf-like tegmina; true membrane sculpting is a future pass.
for side in (-1,1):
    vertices=[]; faces=[]
    rows=22
    for i in range(rows+1):
        t=i/rows
        y=.40+1.63*t
        width=.06+.28*math.sin(math.pi*t)**.75
        for j in range(5):
            u=j/4
            x=side*(.055+width*u)
            z=1.24-.15*t+.055*math.sin(math.pi*u)
            vertices.append((x,y,z))
    for i in range(rows):
        for j in range(4):
            a=i*5+j; faces.append((a,a+1,a+6,a+5))
    mesh=bpy.data.meshes.new(f"wing_mesh_{side}")
    mesh.from_pydata(vertices,[],faces); mesh.update()
    ob=bpy.data.objects.new(f"tegmen_{side}",mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(wing)
    solid=ob.modifiers.new("thin_cuticle","SOLIDIFY");solid.thickness=.006
    for j in (1,2,3):
        points=[vertices[i*5+j] for i in range(rows+1)]
        for i in range(rows):
            tube(f"wing_vein_{side}_{j}_{i}",points[i],points[i+1],
                 .004,.003,vein,6)

# Simple non-destructive organization, suitable for editing in Blender.
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':
        obj["asset_version"]="Base2_prototype_01"
        obj["requires_manual_anatomy_review"]=True

import os
root=os.path.abspath(os.path.join(os.path.dirname(__file__),"../.."))
out=os.path.join(root,"assets","models")
os.makedirs(out,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,"base2.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(out,"base2.glb"),export_format='GLB')
print("Created Base2 prototype:",out)
