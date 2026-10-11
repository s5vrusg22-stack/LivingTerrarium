from pathlib import Path
import json, struct
p=Path(__file__).resolve().parents[1]
s=(p/'scripts/rigged_pose_driver.gd').read_text()
keys=['HIP_SWING_LIMIT','KNEE_SWING_LIMIT','ANKLE_SWING_LIMIT','CCD_DAMPING','CCD_STALL_LIMIT','_rotation_from_to','_safe_target','rotation_budget','get_ik_report','ik_error_history','MAX_FRAME_DELTA','MIN_FRAME_DELTA','ik_success','ik_iterations','last_max_error','CCD_PROGRESS_EPSILON','MAX_HIP_TO_FOOT_RATIO']
for key in keys: assert key in s,key
assert s.count('func _solve_leg_ccd(')==1
assert s.count('func get_ik_report(')==1
assert 'set_bone_global_pose_override' in s
assert 'skeleton.clear_bones_global_pose_override()' in s
raw=(p/'assets/models/mantis_rigged.glb').read_bytes()
assert struct.unpack_from('<I',raw)[0]==0x46546c67
assert struct.unpack_from('<I',raw,8)[0]==len(raw)
length=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+length]);names={n.get('name') for n in j['nodes']}
assert len(j['skins'][0]['joints'])==61 and len(j['animations'])==10
for side in 'LR':
 for i in range(3):
  for prefix in ('Coxa','Joint','Tibia','Foot'): assert f'Rig_{prefix}_{side}{i}' in names
readme=(p/'README_v3.0.md').read_text()
assert sum(line.split('. ',1)[0].isdigit() for line in readme.splitlines() if '. ' in line)==50
print('v3.0 joint limits, diagnostics and 50-item manifest: OK')
