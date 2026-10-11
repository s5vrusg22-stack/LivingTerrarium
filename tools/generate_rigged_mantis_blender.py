"""Blender 4.x: blender -b --python tools/generate_rigged_mantis_blender.py
Generate editable mantis rig .blend + animated GLB; Blender is required.
Adult Hierodula-style mint mantis; the Chiang Mai trade name is not a formal
species diagnosis. Anatomically inspired, hand-procedural, not a scan.
Coordinates: Blender Z up, head toward -Y; 1 Blender unit ~= 1 m in game.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=0.48, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    return m

shell = mat('Chitin - mint green', (.46,.77,.62), .37)
light = mat('Chitin - pale mint', (.67,.88,.74), .46)
olive = mat('Joint membranes', (.22,.43,.34), .67)
edge = mat('Segment edge', (.29,.52,.41), .55)
eye = mat('Compound eye - deep jade', (.015,.06,.045), .18)
vein = mat('Wing veins', (.34,.61,.49), .48)
wing = mat('Tegmina - mint', (.60,.83,.69), .65)
hindwing = mat('Hindwing - pale membrane', (.73,.91,.80), .54)

# Each mesh is rigidly weighted to one deform bone. This gives a valid armature
# and avoids brittle automatic skinning on thin insect limbs.
parts = []

def smooth_mesh(obj):
    if obj.type == 'MESH':
        for poly in obj.data.polygons: poly.use_smooth = True
    return obj

def ellipsoid(name, center, scale, material, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=center)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material); smooth_mesh(o)
    parts.append((o,bone)); return o

def rod(name, a, b, r0, r1, material, bone, vertices=12):
    a,b=Vector(a),Vector(b); d=b-a
    if d.length < 1e-5: return None
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r0, radius2=r1,
                                    depth=d.length, location=(a+b)*.5)
    o=bpy.context.object; o.name=name
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    o.data.materials.append(material); smooth_mesh(o)
    parts.append((o,bone)); return o

# Bone endpoints are in the same world coordinates as geometry, so the
# armature modifier can be bound without visual offsets.
bones = {}
def bone(name, a, b, parent=None):
    bones[name]=(tuple(a),tuple(b),parent)

bone('root',(0,0,.2),(0,-.08,.2))
bone('abdomen',(0,.02,.2),(0,.32,.2),'root')
bone('thorax',(0,-.1,.28),(0,-.52,.31),'root')
bone('head',(0,-.52,.31),(0,-.70,.32),'thorax')
ellipsoid('Abdomen body',(0,.20,.24),(.108,.30,.105),shell,'abdomen')
ellipsoid('Abdomen dorsal plate',(0,.18,.305),(.095,.26,.048),light,'abdomen')
for i in range(7):
    y=-.01+i*.065
    k=1-.38*abs((i-3)/4)
    ellipsoid('Abdominal tergite %02d'%i,(0,y,.265),(.104*k,.010,.084*k),edge,'abdomen')
ellipsoid('Pronotum',(0,-.29,.30),(.056,.30,.065),shell,'thorax')
ellipsoid('Pronotum ridge',(0,-.30,.357),(.019,.25,.014),light,'thorax')
ellipsoid('Head triangular capsule',(0,-.67,.32),(.155,.102,.087),light,'head')
ellipsoid('Clypeus',(0,-.759,.274),(.07,.023,.028),shell,'head')
for side,letter in [(-1,'L'),(1,'R')]:
    ellipsoid('Compound eye '+letter,(side*.124,-.694,.357),(.053,.058,.056),eye,'head')
    for facet in range(12):
        row=facet//4; col=facet%4
        facet_y=-.708+row*.021; facet_z=.323+col*.021
        dy=facet_y+.694; dz=facet_z-.357
        surface=.124+.053*math.sqrt(max(.05,1-(dy/.058)**2-(dz/.056)**2))+.003
        ellipsoid('Eye facet '+letter+str(facet),(side*surface,facet_y,facet_z),(.0055,.006,.006),vein,'head')
    # Two walking legs on each side, with explicit coxa/femur/tibia/tarsus.
    for index,y in enumerate((.12,-.13)):
        prefix=f'{letter}_walk{index+1}'
        hip=(side*.055,y,.255)
        coxa=(side*.16,y+.015,.24)
        knee=(side*.29,y+.085,.16)
        ankle=(side*.38,y+.13,.025)
        toe=(side*.41,y+.18,.014)
        bone(prefix+'_coxa',hip,coxa,'thorax')
        bone(prefix+'_femur',coxa,knee,prefix+'_coxa')
        bone(prefix+'_tibia',knee,ankle,prefix+'_femur')
        bone(prefix+'_tarsus',ankle,toe,prefix+'_tibia')
        rod(prefix+' coxa',hip,coxa,.021,.016,shell,prefix+'_coxa')
        rod(prefix+' femur',coxa,knee,.023,.012,light,prefix+'_femur')
        rod(prefix+' tibia',knee,ankle,.011,.005,shell,prefix+'_tibia')
        for tarsomere in range(5):
            t0=tarsomere/5; t1=(tarsomere+1)/5
            start=Vector(ankle).lerp(Vector(toe),t0)
            end=Vector(ankle).lerp(Vector(toe),t1)
            rod(prefix+' tarsomere %02d'%tarsomere,start,end,.005-tarsomere*.00045,.003,olive,prefix+'_tarsus')
        for claw_side in (-1,1):
            claw_end=(toe[0]+side*.018+claw_side*.006,toe[1]+.012,toe[2]+.006)
            rod(prefix+' paired claw',toe,claw_end,.0028,.0007,light,prefix+'_tarsus')
        ellipsoid(prefix+' knee',(knee),(.019,.019,.019),olive,prefix+'_femur')
    # Raptorial foreleg with movable coxa, spined femur, folding tibia.
    prefix=letter+'_raptor'
    a=(side*.052,-.46,.31); b=(side*.16,-.53,.37)
    c=(side*.24,-.68,.42); d=(side*.16,-.83,.28); e=(side*.13,-.89,.24)
    bone(prefix+'_coxa',a,b,'thorax')
    bone(prefix+'_femur',b,c,prefix+'_coxa')
    bone(prefix+'_tibia',c,d,prefix+'_femur')
    bone(prefix+'_tarsus',d,e,prefix+'_tibia')
    rod(prefix+' coxa',a,b,.022,.018,shell,prefix+'_coxa')
    rod(prefix+' femur',b,c,.044,.023,light,prefix+'_femur')
    rod(prefix+' tibia',c,d,.024,.006,shell,prefix+'_tibia')
    rod(prefix+' tarsus',d,e,.007,.001,olive,prefix+'_tarsus')
    for j in range(9):
        t=(j+1)/10
        base=Vector(b).lerp(Vector(c),t)
        tip=base+Vector((side*.013,-.017,-(.015+.018*math.sin(math.pi*t))))
        rod(prefix+' femoral spine %02d'%j,base,tip,.004,.0005,olive,prefix+'_femur',8)
    for j in range(7):
        t=(j+1)/8
        base=Vector(c).lerp(Vector(d),t)
        tip=base+Vector((-side*.008,.018,-.012))
        rod(prefix+' tibial spine %02d'%j,base,tip,.003,.0005,olive,prefix+'_tibia',8)
    # Long, visibly curved antennae made from short articulated sections.
    ant=letter+'_antenna'
    p0=Vector((side*.047,-.74,.38))
    previous=p0
    for j in range(10):
        t=(j+1)/10.0
        current=Vector((side*(.047+.11*t+.035*math.sin(math.pi*t)),-.74-.56*t,.38+.16*math.sin(math.pi*t)))
        u=tuple(previous); v=tuple(current)
        bn=ant+str(j)
        bone(bn,u,v,'head' if j==0 else ant+str(j-1))
        rod(bn,u,v,.0035-j*.00025,.0025-j*.00018,olive,bn,8)
        previous=current
    # Wing covers and veins follow abdomen.
    ellipsoid('Tegmen '+letter,(side*.065,.15,.345),(.055,.245,.013),wing,'abdomen')
    ellipsoid('Membranous hindwing '+letter,(side*.105,.14,.343),(.072,.225,.008),hindwing,'abdomen')
    for j in range(6):
        x=side*(.025+j*.018)
        rod('Wing vein '+letter+str(j),(x,-.09,.358),(x+side*.012,.39,.356),.0022,.0009,vein,'abdomen',8)

for name, center in [('Ocellus_Median',(0,-.754,.395)),('Ocellus_Left',(-.026,-.748,.390)),('Ocellus_Right',(.026,-.748,.390))]:
    ellipsoid(name,center,(.008,.007,.008),olive,'head')

# Build armature and bind rigid weights.
bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
arm=bpy.context.object; arm.name='MantisRig'
arm.data.edit_bones.remove(arm.data.edit_bones[0])
for name,(a,b,parent) in bones.items():
    eb=arm.data.edit_bones.new(name); eb.head=a; eb.tail=b
for name,(_,_,parent) in bones.items():
    if parent: arm.data.edit_bones[name].parent=arm.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for obj, bn in parts:
    group=obj.vertex_groups.new(name=bn)
    group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    mod=obj.modifiers.new('Armature deform','ARMATURE'); mod.object=arm
    obj.parent=arm

# Reusable, baked keyframe actions. Export NLA tracks as glTF animations.
from math import radians

def action(name, fps, duration, pattern):
    act=bpy.data.actions.new(name)
    # Blender 4.4+ uses action slots; keyframe_insert below allocates them.
    arm.animation_data_create(); arm.animation_data.action=act
    for frame in range(0,duration+1,2):
        t=frame/max(1,duration)
        for bn, fn in pattern.items():
            p=arm.pose.bones[bn]
            p.rotation_mode='XYZ'; p.rotation_euler=fn(t)
            p.keyframe_insert(data_path='rotation_euler',frame=frame,group=bn)
    track=arm.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,0,act); strip.action_frame_start=0; strip.action_frame_end=duration
    arm.animation_data.action=None
    return act

zero=lambda t:(0,0,0)
for name,period,amp in [('Idle',72,.025),('Walk',32,.21),('Alert',54,.12),('Strike',24,.75),('Groom',52,.42),('Feed',46,.27)]:
    pat={'head':lambda t,a=amp:(a*.20*math.sin(t*2*math.pi),0,a*.32*math.sin(t*2*math.pi))}
    for side,letter in [(-1,'L'),(1,'R')]:
        for i in range(1,4):
            phase=(i%2)*math.pi+(0 if side<0 else math.pi)
            pat[f'{letter}_walk{i}_coxa']=lambda t,a=amp,p=phase:(0,0,a*math.sin(2*math.pi*t+p))
            pat[f'{letter}_walk{i}_femur']=lambda t,a=amp,p=phase:(a*.55*max(0,math.sin(2*math.pi*t+p)),0,0)
        pat[f'{letter}_raptor_femur']=lambda t,a=amp,n=name:(a*(1 if n in ('Alert','Strike') else .25)*math.sin(math.pi*t),0,0)
        pat[f'{letter}_raptor_tibia']=lambda t,a=amp,n=name:(-a*(1 if n in ('Strike','Groom','Feed') else .25)*math.sin(math.pi*t),0,0)
        pat[f'{letter}_antenna0']=lambda t,a=amp,s=side:(0,a*.24*math.sin(2*math.pi*t+s),a*.15*math.sin(4*math.pi*t))
    pat['abdomen']=lambda t,a=amp:(a*.1*math.sin(2*math.pi*t),0,0)
    action(name,30,period,pat)

bpy.context.scene.frame_set(0)
for obj in bpy.context.selected_objects: obj.select_set(False)
arm.select_set(True); bpy.context.view_layer.objects.active=arm
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'mantis_rigged.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'mantis_rigged.glb'),export_format='GLB',
                          export_animations=True,export_animation_mode='NLA_TRACKS',
                          export_skins=True,export_materials='EXPORT')
print('Created mantis_rigged.blend and mantis_rigged.glb in',OUT)
