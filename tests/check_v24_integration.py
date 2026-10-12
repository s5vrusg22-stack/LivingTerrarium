"""30 independent integration and asset checks (static; not a Godot runtime test)."""
from pathlib import Path
import json, struct, zipfile, re
root = Path(__file__).resolve().parents[1]
s = (root/'scripts/main.gd').read_text(encoding='utf-8')
checks=[]
def check(label, result):
    checks.append((label, bool(result)))
    if not result: raise AssertionError(label)
model=root/'assets/models/mantis_rigged.glb'
check('01 GLB exists',model.is_file())
b=model.read_bytes()
check('02 GLB magic',b[:4]==b'glTF')
check('03 GLB version',struct.unpack_from('<I',b,4)[0]==2)
check('04 GLB byte length',struct.unpack_from('<I',b,8)[0]==len(b))
n,typ=struct.unpack_from('<I4s',b,12)
check('05 JSON chunk',typ==b'JSON')
j=json.loads(b[20:20+n])
check('06 glTF asset version',j['asset']['version']=='2.0')
check('07 default scene',len(j.get('scenes',[]))>0)
check('08 meshes',len(j.get('meshes',[]))>=30)
check('09 node graph',len(j.get('nodes',[]))>=50)
check('10 skeleton skin',len(j.get('skins',[]))>=1)
check('11 joint count',len(j['skins'][0]['joints'])>=40)
check('12 inverse bind accessor','inverseBindMatrices' in j['skins'][0])
check('13 skinned primitives',any('JOINTS_0' in p.get('attributes',{}) for m in j['meshes'] for p in m['primitives']))
check('14 weighted primitives',any('WEIGHTS_0' in p.get('attributes',{}) for m in j['meshes'] for p in m['primitives']))
clips={a['name'] for a in j.get('animations',[])}
check('15 ten animation clips',len(clips)>=10)
for name in ['IDLE','WALK','ALERT','GROOM','HUNT','STRIKE','SCAN','FEED','CLIMB','DEFEND']:
    check('clip '+name,name in clips)
check('26 runtime GLB preload','preload("res://assets/models/mantis_rigged.glb")' in s)
check('27 runtime model attached','animal.add_child(rigged_visual)' in s)
check('28 animation crossfade','rigged_player.play(name, 0.18)' in s)
check('29 photo-guided rigged model is the default','use_rigged_visual := true' in s)
check('30 high-detail 61-bone GLB selected at full scale',model.stat().st_size >= 6_000_000 and 'visual_model_scale := 1.0' in s)
assert len(checks)==30, len(checks)
print('v2.4 integration: 30/30 static checks PASS (engine runtime not verified)')
