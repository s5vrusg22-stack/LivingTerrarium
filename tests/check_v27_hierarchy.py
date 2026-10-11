from pathlib import Path
import struct,json
p=Path(__file__).resolve().parents[1]
d=(p/'assets/models/mantis_rigged.glb').read_bytes()
assert struct.unpack_from('<I',d)[0]==0x46546c67
length=struct.unpack_from('<I',d,12)[0]
j=json.loads(d[20:20+length]); nodes=j['nodes']; ids={x['name']:i for i,x in enumerate(nodes)}
parent={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
for side in 'LR':
 for k in range(3):
  assert parent[ids[f'Rig_Joint_{side}{k}']]==ids[f'Rig_Coxa_{side}{k}']
  assert parent[ids[f'Rig_Tibia_{side}{k}']]==ids[f'Rig_Joint_{side}{k}']
 assert parent[ids[f'Rig_ForeTibia_{side}']]==ids[f'Rig_ForeFemur_{side}']
assert parent[ids['Rig_Head']]==ids['Rig_Thorax']
assert len(j['animations'])==10
s=(p/'scripts/rigged_pose_driver.gd').read_text()
for term in ['_solve_leg_ccd','skeleton.to_local(anchors[i])','CCD_ITERATIONS','get_bone_parent','MAX_TARGET_DISTANCE']:
 assert term in s
print('v2.7 hierarchy/IK checks passed')
