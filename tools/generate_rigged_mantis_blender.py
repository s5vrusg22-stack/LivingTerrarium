"""Blender 4.x: blender -b --python tools/generate_rigged_mantis_blender.py
Generate an editable Blender source file and animated GLB; Blender is required.
Adult Hierodula-style mint mantis; the Chiang Mai trade name is not a formal
species diagnosis. Anatomically inspired, hand-procedural, not a scan.
Coordinates: Blender Z up, head toward -Y; 1 Blender unit ~= 1 m in game.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'models'
BLEND_OUT = Path(__file__).resolve().parent / 'blender_source'
OUT.mkdir(parents=True, exist_ok=True)
BLEND_OUT.mkdir(parents=True, exist_ok=True)
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

def triangular_head(name, center, scale, material, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=center)
    o=bpy.context.object; o.name=name
    for vertex in o.data.vertices:
        unit=vertex.co.copy()
        frontness=(unit.y+1.0)*0.5
        # Broad behind the eyes, tapering toward the clypeus to form the
        # unmistakable triangular mantis head instead of a round capsule.
        width_factor=0.54+0.46*frontness
        vertex.co.x*=scale[0]*width_factor
        vertex.co.y*=scale[1]
        vertex.co.z*=scale[2]
    o.data.materials.append(material); smooth_mesh(o)
    parts.append((o,bone)); return o

def wing_blade(name, side, y_start, y_end, max_span, z_base, material, bone, stations=40, chord_rows=12):
    vertices=[]; faces=[]
    for i in range(stations+1):
        t=i/stations
        profile=max(0.012, math.sin(math.pi*t))**0.72
        width=max_span*profile*(0.88+0.12*t)
        center_y=y_start+(y_end-y_start)*t
        for j in range(chord_rows+1):
            chord=j/chord_rows
            x=side*(0.012+width*chord)
            y=center_y + (chord-0.5)*0.014*math.sin(math.pi*t)
            camber=0.013*math.sin(math.pi*t)*math.sin(math.pi*chord)
            z=z_base+camber+0.002*math.sin(2.0*math.pi*t+chord*math.pi)
            vertices.append((x,y,z))
    row=chord_rows+1
    for i in range(stations):
        for j in range(chord_rows):
            a=i*row+j; b=(i+1)*row+j; c=b+1; d=a+1
            if side > 0:
                faces.extend([(a,d,b),(d,c,b)])
            else:
                faces.extend([(a,b,d),(d,b,c)])
    mesh=bpy.data.meshes.new(name+' shaped membrane')
    mesh.from_pydata(vertices,[],faces); mesh.update()
    for poly in mesh.polygons: poly.use_smooth=True
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material); parts.append((obj,bone)); return obj

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

bone('Rig_Root',(0,0,.2),(0,-.08,.2))
bone('Rig_Abdomen',(0,.02,.2),(0,.32,.2),'Rig_Root')
bone('Rig_Thorax',(0,-.1,.28),(0,-.52,.31),'Rig_Root')
bone('Rig_Head',(0,-.52,.31),(0,-.70,.32),'Rig_Thorax')
bone('Rig_Wing_L',(-.01,.02,.34),(-.14,.23,.34),'Rig_Abdomen')
bone('Rig_Wing_R',(.01,.02,.34),(.14,.23,.34),'Rig_Abdomen')
bone('Rig_Mandible_L',(-.03,-.73,.28),(-.05,-.79,.25),'Rig_Head')
bone('Rig_Mandible_R',(.03,-.73,.28),(.05,-.79,.25),'Rig_Head')
bone('Rig_Cercus_L',(-.02,.42,.22),(-.035,.49,.20),'Rig_Abdomen')
bone('Rig_Cercus_R',(.02,.42,.22),(.035,.49,.20),'Rig_Abdomen')
ellipsoid('Abdomen body',(0,.20,.24),(.118,.31,.108),shell,'Rig_Abdomen')
ellipsoid('Abdomen dorsal plate',(0,.18,.305),(.104,.27,.050),light,'Rig_Abdomen')
for i in range(7):
    y=-.01+i*.065
    k=1-.38*abs((i-3)/4)
    ellipsoid('Abdominal tergite %02d'%i,(0,y,.265),(.112*k,.010,.087*k),edge,'Rig_Abdomen')
    ellipsoid('Abdominal sternite %02d'%i,(0,y,.169),(.082*k,.011,.022*k),olive,'Rig_Abdomen')
    for side,letter in [(-1,'L'),(1,'R')]:
        ellipsoid('Abdominal pleurite %s %02d'%(letter,i),(side*.087*k,y,.226),(.022*k,.022,.037*k),shell,'Rig_Abdomen')
        ellipsoid('Abdominal spiracle %s %02d'%(letter,i),(side*.108*k,y,.235),(.004,.008,.005),olive,'Rig_Abdomen')
ellipsoid('Pronotum',(0,-.29,.30),(.056,.30,.065),shell,'Rig_Thorax')
ellipsoid('Pronotum ridge',(0,-.30,.357),(.019,.25,.014),light,'Rig_Thorax')
for side,letter in [(-1,'L'),(1,'R')]:
    rod('Pronotal raised margin '+letter,(side*.047,-.51,.303),(side*.047,-.08,.303),.004,.003,edge,'Rig_Thorax',10)
triangular_head('Head triangular capsule',(0,-.67,.32),(.155,.102,.087),light,'Rig_Head')
ellipsoid('Clypeus',(0,-.759,.274),(.07,.023,.028),shell,'Rig_Head')
for side,letter in [(-1,'L'),(1,'R')]:
    ellipsoid('Eye_Compound_'+letter,(side*.124,-.694,.357),(.053,.058,.056),eye,'Rig_Head')
    ellipsoid('EyePupil_'+letter,(side*.174,-.704,.357),(.010,.019,.020),eye,'Rig_Head')
    ellipsoid('EyeGlint_'+letter,(side*.181,-.717,.373),(.004,.006,.007),light,'Rig_Head')
    for facet in range(12):
        row=facet//4; col=facet%4
        facet_y=-.708+row*.021; facet_z=.323+col*.021
        dy=facet_y+.694; dz=facet_z-.357
        surface=.124+.053*math.sqrt(max(.05,1-(dy/.058)**2-(dz/.056)**2))+.003
        ellipsoid('Eye_Facet_'+letter+'_%02d'%facet,(side*surface,facet_y,facet_z),(.0055,.006,.006),vein,'Rig_Head')
    # Three complete walking-leg pairs, each with individually named joints.
    for index,y in enumerate((-.13,.12,.32)):
        prefix=f'Rig_Walk_{letter}{index}'
        hip=(side*.052,y,.255)
        coxa=(side*.15,y+(index-1)*.018,.238)
        knee=(side*.275,y+(index-1)*.055+.035,.155)
        ankle=(side*.37,y+(index-1)*.085+.075,.024)
        toe=(side*.405,y+(index-1)*.085+.13,.012)
        coxa_bone=f'Rig_Coxa_{letter}{index}'
        joint_bone=f'Rig_Joint_{letter}{index}'
        tibia_bone=f'Rig_Tibia_{letter}{index}'
        foot_bone=f'Rig_Foot_{letter}{index}'
        bone(coxa_bone,hip,coxa,'Rig_Thorax')
        bone(joint_bone,coxa,knee,coxa_bone)
        bone(tibia_bone,knee,ankle,joint_bone)
        bone(foot_bone,ankle,toe,tibia_bone)
        # Name the canonical leg segments explicitly so Godot's visual check
        # can confirm both retained pairs and the hidden redundant third pair.
        rod(f'Coxa_{letter}{index}',hip,coxa,.021,.016,shell,coxa_bone)
        rod(f'Joint_{letter}{index}',coxa,knee,.023,.012,light,joint_bone)
        rod(f'Tibia_{letter}{index}',knee,ankle,.011,.005,shell,tibia_bone)
        for tarsomere in range(5):
            t0=tarsomere/5; t1=(tarsomere+1)/5
            start=Vector(ankle).lerp(Vector(toe),t0)
            end=Vector(ankle).lerp(Vector(toe),t1)
            name = f'Foot_{letter}{index}' if tarsomere == 0 else f'Tarsomere_{letter}{index}_{tarsomere:02d}'
            rod(name,start,end,.005-tarsomere*.00045,.003,olive,foot_bone)
        for claw_index, claw_side in enumerate((-1,1)):
            claw_end=(toe[0]+side*.018+claw_side*.006,toe[1]+.012,toe[2]+.006)
            rod(f'TarsalClaw_{letter}{index}_{claw_index}',toe,claw_end,.0028,.0007,light,foot_bone)
        ellipsoid(f'Knee_{letter}{index}',(knee),(.019,.019,.019),olive,joint_bone)
    # Raptorial foreleg with movable coxa, spined femur, folding tibia.
    prefix='Rig_Fore_'+letter
    a=(side*.052,-.46,.31); b=(side*.16,-.53,.37)
    c=(side*.24,-.68,.42); d=(side*.16,-.83,.28); e=(side*.13,-.89,.24)
    coxa_bone=prefix+'Coxa'; femur_bone='Rig_ForeFemur_'+letter
    tibia_bone='Rig_ForeTibia_'+letter; foot_bone=prefix+'Foot'
    bone(coxa_bone,a,b,'Rig_Thorax')
    bone(femur_bone,b,c,coxa_bone)
    bone(tibia_bone,c,d,femur_bone)
    bone(foot_bone,d,e,tibia_bone)
    rod('ForeCoxa_'+letter,a,b,.022,.018,shell,coxa_bone)
    rod('ForeFemur_'+letter,b,c,.044,.023,light,femur_bone)
    rod('ForeTibia_'+letter,c,d,.024,.006,shell,tibia_bone)
    rod('ForeFoot_'+letter,d,e,.007,.001,olive,foot_bone)
    for j in range(9):
        t=(j+1)/10
        base=Vector(b).lerp(Vector(c),t)
        tip=base+Vector((side*.013,-.017,-(.015+.018*math.sin(math.pi*t))))
        rod(prefix+' femoral spine %02d'%j,base,tip,.004,.0005,olive,femur_bone,8)
    for j in range(7):
        t=(j+1)/8
        base=Vector(c).lerp(Vector(d),t)
        tip=base+Vector((-side*.008,.018,-.012))
        rod(prefix+' tibial spine %02d'%j,base,tip,.003,.0005,olive,tibia_bone,8)
    # Long, visibly curved antennae made from short articulated sections.
    ant='Rig_Antenna_'+letter
    p0=Vector((side*.047,-.74,.38))
    previous=p0
    for j in range(10):
        t=(j+1)/10.0
        current=Vector((side*(.047+.11*t+.035*math.sin(math.pi*t)),-.74-.56*t,.38+.16*math.sin(math.pi*t)))
        u=tuple(previous); v=tuple(current)
        bn=ant if j==0 else ant+str(j)
        parent_bone='Rig_Head' if j==0 else ant if j==1 else ant+str(j-1)
        bone(bn,u,v,parent_bone)
        rod(bn,u,v,.0035-j*.00025,.0025-j*.00018,olive,bn,8)
        previous=current
    # Layered, cambered tegmina and hindwings with a branching vein network.
    wing_bone='Rig_Wing_'+letter
    wing_blade('Hindwing_Membrane_'+letter,side,-.105,.43,.128,.337,hindwing,wing_bone,44,14)
    wing_blade('Wing_Tegmen_'+letter,side,-.085,.42,.096,.358,wing,wing_bone,48,12)
    for j in range(7):
        t=(j+1)/8.0
        y=-.075+.49*t
        width=.128*max(0.012,math.sin(math.pi*t))**.72
        center_x=side*.018
        edge_x=side*(.012+width*.96)
        rod('WingVeinDetail_%s_long_%02d'%(letter,j),(center_x,y,.362),(edge_x,y+.012,.354),.0018,.00075,vein,wing_bone,8)
    for j in range(8):
        t=(j+1)/9.0
        y=-.09+.50*t
        width=.091*max(0.012,math.sin(math.pi*t))**.72
        x0=side*.019; x1=side*(.012+width*.94)
        rod('WingVeinDetail_%s_cross_%02d'%(letter,j),(x0,y,.371),(x1,y+.018,.369),.0012,.00055,vein,wing_bone,8)
    rod('Mandible_'+letter,(side*.034,-.741,.276),(side*.048,-.798,.247),.009,.0015,olive,'Rig_Mandible_'+letter,10)
    rod('Cercus_'+letter,(side*.019,.424,.216),(side*.034,.49,.20),.006,.001,shell,'Rig_Cercus_'+letter,8)

for name, center in [('Ocellus_Median',(0,-.754,.395)),('Ocellus_Left',(-.026,-.748,.390)),('Ocellus_Right',(.026,-.748,.390))]:
    ellipsoid(name,center,(.008,.007,.008),olive,'Rig_Head')

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

def animation_pattern(name, amplitude):
    pat={
        'Rig_Head':lambda t,a=amplitude:(a*.18*math.sin(2*math.pi*t),0,a*.28*math.sin(2*math.pi*t)),
        'Rig_Thorax':lambda t,a=amplitude:(a*.06*math.sin(2*math.pi*t),0,0),
        'Rig_Abdomen':lambda t,a=amplitude:(a*.08*math.sin(2*math.pi*t),0,0),
    }
    for side,letter in [(-1,'L'),(1,'R')]:
        for i in range(3):
            phase=(i%2)*math.pi+(0 if side<0 else math.pi)
            pat[f'Rig_Coxa_{letter}{i}']=lambda t,a=amplitude,p=phase:(0,0,a*.48*math.sin(2*math.pi*t+p))
            pat[f'Rig_Joint_{letter}{i}']=lambda t,a=amplitude,p=phase:(a*.42*max(0,math.sin(2*math.pi*t+p)),0,0)
            pat[f'Rig_Tibia_{letter}{i}']=lambda t,a=amplitude,p=phase:(-a*.30*max(0,math.sin(2*math.pi*t+p)),0,0)
        for j in range(10):
            antenna_name='Rig_Antenna_'+letter if j==0 else 'Rig_Antenna_'+letter+str(j)
            pat[antenna_name]=lambda t,a=amplitude,s=side,n=j:(0,a*.10*math.sin(2*math.pi*t+s+n*.24),a*.08*math.sin(4*math.pi*t+n*.18))
        femur='Rig_ForeFemur_'+letter; tibia='Rig_ForeTibia_'+letter
        pat[femur]=lambda t,a=amplitude:(a*.16*math.sin(math.pi*t),0,0)
        pat[tibia]=lambda t,a=amplitude:(-a*.16*math.sin(math.pi*t),0,0)
        pat['Rig_Mandible_'+letter]=lambda t,a=amplitude:(a*.05*math.sin(6*math.pi*t),0,0)
        pat['Rig_Wing_'+letter]=lambda t,a=amplitude,s=side:(0,s*a*.04*math.sin(2*math.pi*t),0)
    if name in ('ALERT','STRIKE','DEFEND'):
        lift=1.0 if name=='STRIKE' else .62
        pat['Rig_ForeFemur_L']=lambda t,a=amplitude,k=lift:(a*k*math.sin(math.pi*t),0,.10*math.sin(math.pi*t))
        pat['Rig_ForeFemur_R']=lambda t,a=amplitude,k=lift:(a*k*math.sin(math.pi*t),0,-.10*math.sin(math.pi*t))
        pat['Rig_ForeTibia_L']=lambda t,a=amplitude,k=lift:(-a*k*.9*math.sin(math.pi*t),0,0)
        pat['Rig_ForeTibia_R']=lambda t,a=amplitude,k=lift:(-a*k*.9*math.sin(math.pi*t),0,0)
    if name=='SCAN':
        pat['Rig_Head']=lambda t:(.035*math.sin(2*math.pi*t),0,.34*math.sin(2*math.pi*t))
    if name=='GROOM':
        pat['Rig_ForeFemur_L']=lambda t:(.34*math.sin(math.pi*t),0,.08)
        pat['Rig_ForeTibia_L']=lambda t:(-.48*math.sin(math.pi*t),0,0)
    if name=='FEED':
        pat['Rig_Mandible_L']=lambda t:(.13*math.sin(8*math.pi*t),0,0)
        pat['Rig_Mandible_R']=lambda t:(-.13*math.sin(8*math.pi*t),0,0)
    if name=='CLIMB':
        pat['Rig_Thorax']=lambda t:(.14*math.sin(2*math.pi*t),0,0)
    if name=='FLY':
        for side,letter in [(-1,'L'),(1,'R')]:
            pat['Rig_Wing_'+letter]=lambda t,a=amplitude,s=side:(s*.18*math.sin(12*math.pi*t),s*.72*math.sin(12*math.pi*t),s*.08*math.sin(12*math.pi*t))
        pat['Rig_ForeFemur_L']=lambda t:(.26,0,.08)
        pat['Rig_ForeFemur_R']=lambda t:(.26,0,-.08)
    return pat

for name,period,amp in [
    ('IDLE',72,.025),('WALK',32,.21),('ALERT',54,.52),('GROOM',52,.42),
    ('HUNT',40,.34),('STRIKE',24,.78),('SCAN',64,.18),('FEED',48,.20),
    ('CLIMB',36,.24),('DEFEND',42,.56),('FLY',30,.64),
]:
    action(name,30,period,animation_pattern(name,amp))

bpy.context.scene.frame_set(0)
for obj in bpy.context.selected_objects: obj.select_set(False)
arm.select_set(True); bpy.context.view_layer.objects.active=arm
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT/'mantis_rigged.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'mantis_rigged.glb'),export_format='GLB',
                          export_animations=True,export_animation_mode='NLA_TRACKS',
                          export_skins=True,export_materials='EXPORT')
stale_blend = OUT/'mantis_rigged.blend'
if stale_blend.exists():
    stale_blend.unlink()
print('Created editable Blender source in',BLEND_OUT,'and mantis_rigged.glb in',OUT)
