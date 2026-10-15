"""Base2 procedural cuticle enhancement and animation setup.
Run AFTER generate_base2.py, in Blender 4.x:
  blender -b assets/models/base2.blend --python tools/blender/enhance_base2.py
Saves base2_detailed.blend and base2_detailed.glb without replacing Base1.
"""
import bpy, math, os, random
from mathutils import Vector
random.seed(20261015)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.frame_start=1; scene.frame_end=180

def mat(name, base, rough=.55):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    n=m.node_tree.nodes
    n.clear()
    out=n.new('ShaderNodeOutputMaterial')
    p=n.new('ShaderNodeBsdfPrincipled')
    p.inputs['Base Color'].default_value=(*base,1)
    p.inputs['Roughness'].default_value=rough
    m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=72
    noise.inputs['Detail'].default_value=4
    ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.20
    ramp.color_ramp.elements[0].color=(base[0]*.58,base[1]*.65,base[2]*.50,1)
    ramp.color_ramp.elements[1].position=.80
    ramp.color_ramp.elements[1].color=(min(1,base[0]*1.28),min(1,base[1]*1.25),min(1,base[2]*1.2),1)
    m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs['Fac'])
    m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12
    bump.inputs['Distance'].default_value=.003
    m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
    m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
    return m

cuticle=mat('Base2_cuticle_microtexture',(.23,.40,.105),.57)
underside=mat('Base2_ventral_microtexture',(.42,.52,.19),.7)
wingmat=mat('Base2_wing_membrane_microtexture',(.25,.40,.13),.67)
eye=mat('Base2_eye_microtexture',(.16,.11,.075),.23)
for obj in list(bpy.data.objects):
    if obj.type!='MESH':continue
    name=obj.name.lower()
    if 'eye_' in name: target=eye
    elif 'sternite' in name:target=underside
    elif 'tegmen' in name:target=wingmat
    elif 'spine' in name or 'vein' in name or 'antenna' in name:continue
    else:target=cuticle
    if obj.data.materials:obj.data.materials[0]=target
    else:obj.data.materials.append(target)

# A separate neck/head controller for inspectable motion. Object parenting
# keeps meshes editable; future deformation rig can replace these controllers.
def controller(name, position):
    o=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(o)
    o.location=position
    o.empty_display_type='SPHERE'
    o.empty_display_size=.09
    return o

head=controller('CTRL_head',(0,-1.04,1.12))
for obj in list(bpy.data.objects):
    if obj.type!='MESH':continue
    if obj.name.startswith(('head_','compound_eye_','mandible_','antenna_')):
        world=obj.matrix_world.copy()
        obj.parent=head
        obj.matrix_world=world
for frame,angle in ((1,0),(40,.20),(85,-.16),(130,.13),(180,0)):
    head.rotation_euler[2]=angle
    head.keyframe_insert(data_path='rotation_euler',frame=frame)

# Create two independent foreleg controllers with subtle threat posture.
for side in (-1,1):
    ctrl=controller('CTRL_raptorial_L' if side<0 else 'CTRL_raptorial_R',(side*.16,-.69,1.06))
    for obj in list(bpy.data.objects):
        if obj.type!='MESH':continue
        if obj.name.startswith((f'raptorial_{side}_',f'femoral_spine_{side}_',f'tibial_spine_{side}_')):
            world=obj.matrix_world.copy()
            obj.parent=ctrl
            obj.matrix_world=world
    for frame,angle in ((1,0),(55,side*.18),(95,side*.45),(145,side*.15),(180,0)):
        ctrl.rotation_euler[1]=angle
        ctrl.keyframe_insert(data_path='rotation_euler',frame=frame)

# Gentle abdominal breathing; apply only to abdomen pieces.
abdomen=controller('CTRL_abdomen',(0,.60,1.0))
for obj in list(bpy.data.objects):
    if obj.type=='MESH' and obj.name.startswith(('abdomen_tergite_','abdomen_sternite_')):
        world=obj.matrix_world.copy()
        obj.parent=abdomen;obj.matrix_world=world
for frame,scale in ((1,1),(45,1.025),(90,1),(135,1.025),(180,1)):
    abdomen.scale=(scale,scale,1)
    abdomen.keyframe_insert(data_path='scale',frame=frame)

# Blender glTF exports empty-node transforms as animation channels.
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
out=os.path.join(root,'assets','models')
os.makedirs(out,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,'base2_detailed.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(out,'base2_detailed.glb'),
                          export_format='GLB',export_animations=True)
print('Base2 detailed exports created')
