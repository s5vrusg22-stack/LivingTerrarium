from pathlib import Path
import json,struct,math
p=Path(__file__).resolve().parents[1]
data=(p/'assets/models/mantis_rigged.glb').read_bytes()
magic,version,total=struct.unpack_from('<III',data,0)
assert magic==0x46546c67 and version==2 and total==len(data)
length,typ=struct.unpack_from('<II',data,12)
assert typ==0x4e4f534a
j=json.loads(data[20:20+length]);nodes=j['nodes'];names={n.get('name'):i for i,n in enumerate(nodes)}
parents={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
assert len(j['animations'])==10 and len(j['skins'])>=1
for side in 'LR':
 for k in range(3):
  a,b,c=[names[f'Rig_{part}_{side}{k}'] for part in ['Coxa','Joint','Tibia']]
  assert parents[b]==a and parents[c]==b
  assert a in j['skins'][0]['joints'] and b in j['skins'][0]['joints'] and c in j['skins'][0]['joints']
s=(p/'scripts/rigged_pose_driver.gd').read_text()
for term in ['get_bone_global_rest','chain_reach','ik_blend','IK_EPSILON','clear_bones_global_pose_override','_solve_leg_ccd','get_bone_global_pose','set_bone_global_pose_override']:
 assert term in s,term
m=(p/'scripts/main.gd').read_text()
assert 'elif next_state == "CLIMB" and climb_active:' in m
assert 'foot_world = on_axis + contact_normal * 0.145' in m
assert 'Basis.looking_at(travel_direction, radial)' in m
print('v2.8 GLB skeleton and IK integration static checks passed')
