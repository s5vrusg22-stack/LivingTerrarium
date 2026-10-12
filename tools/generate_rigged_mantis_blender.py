"""Blender 4.x: blender -b --python tools/generate_rigged_mantis_blender.py
Generate editable mantis rig .blend + animated GLB; Blender is required.
Anatomically inspired, hand-procedural model, not a scan or photoreal asset.
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

shell = mat('Chitin - leaf green', (.30,.43,.13), .62)
light = mat('Chitin - dorsal green', (.39,.53,.19), .66)
olive = mat('Joint membranes', (.18,.26,.09), .72)
edge = mat('Segment edge', (.25,.34,.12), .70)
eye = mat('Compound eye - dark jade', (.018,.055,.028), .30)
vein = mat('Wing veins', (.40,.53,.22), .68)
wing = mat('Tegmina - semi matte', (.40,.54,.20), .78)

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

def leaf_wing(name, side, center_y, center_z, material, bone_name):
    """One half of a paired, cambered leaf wing with a fine vein relief grid."""
    length_steps, width_steps = 80, 24
    columns = width_steps + 1
    surface_count = (length_steps + 1) * columns
    vertices, uv_by_vertex = [], []

    def vertex_index(i, j, underside=False):
        return i * columns + j + (surface_count if underside else 0)

    for underside in (False, True):
        for i in range(length_steps + 1):
            u = i / length_steps
            profile = max(0.0, math.sin(math.pi * u)) ** .74 * (0.88 + .12 * math.cos(math.pi * (u - .10)))
            y = center_y + (u - .5) * .82
            for j in range(columns):
                across = j / width_steps
                x = side * .145 * across * profile
                camber = .012 * math.sin(math.pi * across) * max(0.0, math.sin(math.pi * u)) ** .70
                midrib = .0048 * math.exp(-((across - .5) / .035) ** 2)
                ribs = sum(height * math.exp(-((across - band) / .022) ** 2)
                           for band, height in ((.24, .0018), (.39, .00145), (.62, .00145), (.78, .0012), (.92, .0009)))
                cross_phase = u * 22.0 - across * .42
                cross_dist = abs((cross_phase + .5) % 1.0 - .5)
                crossvein = .00075 * math.exp(-((cross_dist / .075) ** 2)) * math.sin(math.pi * across)
                z = center_z + camber + (midrib + ribs + crossvein) * max(0.0, math.sin(math.pi * u)) ** .6 + (-.0017 if underside else .0017)
                vertices.append((x, y, z))
                uv_by_vertex.append((across, u))

    faces = []
    for i in range(length_steps):
        for j in range(width_steps):
            a = vertex_index(i, j)
            b = vertex_index(i, j + 1)
            c = vertex_index(i + 1, j + 1)
            d = vertex_index(i + 1, j)
            if side > 0:
                faces.append((a, b, c, d))
                faces.append((vertex_index(i, j, True), vertex_index(i + 1, j, True),
                              vertex_index(i + 1, j + 1, True), vertex_index(i, j + 1, True)))
            else:
                faces.append((a, d, c, b))
                faces.append((vertex_index(i, j, True), vertex_index(i, j + 1, True),
                              vertex_index(i + 1, j + 1, True), vertex_index(i + 1, j, True)))
    for i in range(length_steps):
        for j in (0, width_steps):
            faces.append((vertex_index(i, j), vertex_index(i + 1, j),
                          vertex_index(i + 1, j, True), vertex_index(i, j, True)))
    for j in range(width_steps):
        faces.append((vertex_index(0, j), vertex_index(0, j, True),
                      vertex_index(0, j + 1, True), vertex_index(0, j + 1)))
        faces.append((vertex_index(length_steps, j), vertex_index(length_steps, j + 1),
                      vertex_index(length_steps, j + 1, True), vertex_index(length_steps, j, True)))

    mesh = bpy.data.meshes.new(name + ' mesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop_index in polygon.loop_indices:
            vertex = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uv_by_vertex[vertex % surface_count]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    parts.append((obj, bone_name))
    return obj

def pronotum(name, material, bone_name):
    """Fine swept pronotal shield with a keel, side carinae, and collar grooves."""
    length_steps, ring_steps = 80, 24
    vertices, faces = [], []
    for i in range(length_steps + 1):
        u = i / length_steps
        y = -.65 + .72 * u
        profile = .88 + .12 * math.sin(math.pi * u) ** .65
        groove = .045 * (math.exp(-((u - .095) / .012) ** 2) + math.exp(-((u - .925) / .014) ** 2))
        lip = .030 * (math.exp(-((u - .072) / .018) ** 2) + math.exp(-((u - .895) / .020) ** 2))
        for j in range(ring_steps):
            phi = 2.0 * math.pi * j / ring_steps
            sn, cs = math.sin(phi), math.cos(phi)
            dorsal = max(0.0, cs)
            width = .052 * profile * (1.0 - groove + lip)
            height = .060 * profile * (1.0 - groove + lip)
            keel = .0085 * dorsal ** 8 * math.sin(math.pi * u) ** .45
            carina = .0032 * math.exp(-((abs(sn) - .66) / .055) ** 2) * dorsal
            vertices.append((width * sn, y, .30 + height * cs + keel + carina))
    for i in range(length_steps):
        for j in range(ring_steps):
            a = i * ring_steps + j
            b = i * ring_steps + (j + 1) % ring_steps
            c = (i + 1) * ring_steps + (j + 1) % ring_steps
            d = (i + 1) * ring_steps + j
            faces.extend(((a, b, c), (a, c, d)))
    start_center = len(vertices)
    vertices.append((0.0, -.65, .30))
    end_center = len(vertices)
    vertices.append((0.0, .07, .30))
    for j in range(ring_steps):
        nxt = (j + 1) % ring_steps
        faces.extend(((start_center, nxt, j), (end_center, length_steps * ring_steps + j,
                                                length_steps * ring_steps + nxt)))
    mesh = bpy.data.meshes.new(name + ' mesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    parts.append((obj, bone_name))
    return obj

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
ellipsoid('Abdomen body',(0,.20,.24),(.122,.355,.108),shell,'abdomen')
ellipsoid('Abdomen dorsal plate',(0,.18,.305),(.104,.305,.041),light,'abdomen')
for i in range(7):
    y=-.01+i*.065
    k=1-.38*abs((i-3)/4)
    ellipsoid('Abdominal tergite %02d'%i,(0,y,.265),(.108*k,.008,.086*k),edge,'abdomen')
pronotum('Pronotum shield',shell,'thorax')
ellipsoid('Head triangular capsule',(0,-.67,.32),(.105,.080,.073),light,'head')
ellipsoid('Clypeus',(0,-.751,.277),(.058,.020,.024),shell,'head')
for side,letter in [(-1,'L'),(1,'R')]:
    ellipsoid('Compound eye '+letter,(side*.103,-.694,.357),(.046,.050,.048),eye,'head')
    for i in range(3):
        ellipsoid('Ocellus '+letter+str(i),(side*(.013+.020*i),-.754,.395),(.008,.007,.008),olive,'head')
    # Three walking legs on each side, with explicit coxa/femur/tibia/tarsus.
    for index,y in enumerate((.13,-.07,-.28)):
        prefix=f'{letter}_walk{index+1}'
        hip=(side*.055,y,.255)
        coxa=(side*.16,y+.015,.24)
        knee=(side*.29,y+.085,.16)
        ankle=(side*.40,y+.15,.022)
        toe=(side*.45,y+.205,.012)
        bone(prefix+'_coxa',hip,coxa,'thorax' if index==2 else 'root')
        bone(prefix+'_femur',coxa,knee,prefix+'_coxa')
        bone(prefix+'_tibia',knee,ankle,prefix+'_femur')
        bone(prefix+'_tarsus',ankle,toe,prefix+'_tibia')
        rod(prefix+' coxa',hip,coxa,.018,.014,shell,prefix+'_coxa')
        rod(prefix+' femur',coxa,knee,.019,.010,light,prefix+'_femur')
        rod(prefix+' tibia',knee,ankle,.011,.005,shell,prefix+'_tibia')
        rod(prefix+' tarsus',ankle,toe,.005,.002,olive,prefix+'_tarsus')
        ellipsoid(prefix+' knee',(knee),(.019,.019,.019),olive,prefix+'_femur')
    # Raptorial foreleg with movable coxa, spined femur, folding tibia.
    prefix=letter+'_raptor'
    a=(side*.052,-.46,.31); b=(side*.16,-.53,.37)
    c=(side*.24,-.68,.42); d=(side*.16,-.83,.28); e=(side*.13,-.89,.24)
    bone(prefix+'_coxa',a,b,'thorax')
    bone(prefix+'_femur',b,c,prefix+'_coxa')
    bone(prefix+'_tibia',c,d,prefix+'_femur')
    bone(prefix+'_tarsus',d,e,prefix+'_tibia')
    rod(prefix+' coxa',a,b,.027,.022,shell,prefix+'_coxa')
    rod(prefix+' femur',b,c,.068,.038,light,prefix+'_femur')
    rod(prefix+' tibia',c,d,.040,.012,shell,prefix+'_tibia')
    rod(prefix+' tarsus',d,e,.009,.0015,olive,prefix+'_tarsus')
    for j in range(13):
        t=(j+1)/14
        base=Vector(b).lerp(Vector(c),t)
        tip=base+Vector((side*.020,-.025,-(.021+.021*math.sin(math.pi*t))))
        rod(prefix+' femoral spine %02d'%j,base,tip,.006,.0005,olive,prefix+'_femur',8)
    for j in range(10):
        t=(j+1)/11
        base=Vector(c).lerp(Vector(d),t)
        tip=base+Vector((-side*.010,.022,-.015))
        rod(prefix+' tibial spine %02d'%j,base,tip,.004,.0006,olive,prefix+'_tibia',8)
    # Antennae in three articulated sections.
    ant=letter+'_antenna'
    p0=(side*.047,-.74,.38); p1=(side*.078,-.89,.47)
    p2=(side*.12,-1.03,.53); p3=(side*.17,-1.17,.56)
    for j,(u,v) in enumerate(((p0,p1),(p1,p2),(p2,p3))):
        bn=ant+str(j)
        bone(bn,u,v,'head' if j==0 else ant+str(j-1))
        rod(bn,u,v,.004-j*.0008,.002-j*.0004,olive,bn,8)
    # Separate lanceolate tegmina meet at the dorsal seam and carry readable veins.
    leaf_wing('Wing_'+letter,side,.17,.355,wing,'abdomen')
    center_x=side*.073
    rod('Wing midrib '+letter,(center_x,-.185,.373),(center_x,.525,.373),.0036,.0018,vein,'abdomen',8)
    for row in range(1,19):
        u=row/19.0
        y=.17-.41+.82*u
        extent=.0725*max(0.0,math.sin(math.pi*u))**.74
        for flank in (-1.0,1.0):
            end_x=center_x+flank*extent
            rod('Wing crossvein %s %02d'%(letter,row),
                (center_x,y,.371),(end_x,y+.026,.368),.0018,.0008,vein,'abdomen',8)

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
