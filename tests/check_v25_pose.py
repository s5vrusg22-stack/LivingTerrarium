from pathlib import Path
import json, struct
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text()
driver=(root/'scripts/rigged_pose_driver.gd').read_text()
p=root/'assets/models/mantis_rigged.glb'
b=p.read_bytes(); n=struct.unpack_from('<I',b,12)[0]; gltf=json.loads(b[20:20+n]); names={node.get('name','') for node in gltf['nodes']}
checks={
 '01 GLB binary': b[:4]==b'glTF',
 '02 skin exists':bool(gltf.get('skins')),
 '03 skeleton discovery':'_find_rigged_skeleton' in main,
 '04 bone validation':'missing.is_empty()' in driver,
 '05 six coxa bones':all(f'Rig_Coxa_{s}{i}' in names for s in 'LR' for i in range(3)),
 '06 world anchors':'to_local(anchors[i])' in driver,
 '07 bounded pose':'MAX_ANGLE := 0.28' in driver,
 '08 tibia compensation':'Rig_Tibia_%s%d' in driver,
 '09 head aiming':'Rig_Head' in driver,
 '10 fallback reset':'rigged_pose_driver.reset_offsets()' in main,
}
for name,ok in checks.items():
 print(('PASS' if ok else 'FAIL'),name)
assert all(checks.values())
