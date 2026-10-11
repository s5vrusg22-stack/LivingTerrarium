from pathlib import Path
import struct,json,numpy as np
p=Path(__file__).resolve().parents[1];raw=(p/'assets/models/mantis_rigged.glb').read_bytes();assert struct.unpack_from('<I',raw)[0]==0x46546c67
assert struct.unpack_from('<I',raw,8)[0]==len(raw)
jl=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+jl]);offset=20+jl;bl=struct.unpack_from('<I',raw,offset)[0];buf=raw[offset+8:offset+8+bl];names={n.get('name'):i for i,n in enumerate(j['nodes'])};skin=j['skins'][0];joint_set=set(skin['joints']);parents={c:i for i,n in enumerate(j['nodes']) for c in n.get('children',[])}
def ac(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];dt={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']];cols={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',cols*np.dtype(dt).itemsize)
 return np.array([np.frombuffer(buf,dtype=dt,count=cols,offset=start+k*stride) for k in range(a['count'])])
assert len(skin['joints'])==61
assert ac(skin['inverseBindMatrices']).shape==(61,16)
for side in 'LR':
 for k in range(3):
  hip=names[f'Rig_Coxa_{side}{k}'];knee=names[f'Rig_Joint_{side}{k}'];ankle=names[f'Rig_Tibia_{side}{k}'];foot=names[f'Rig_Foot_{side}{k}']
  assert parents[knee]==hip and parents[ankle]==knee and parents[foot]==ankle
  assert foot in joint_set
count=0;soft=0
for n in j['nodes']:
 if n.get('name','').startswith(('Coxa_','Tibia_','Joint_')) and 'mesh' in n:
  for prim in j['meshes'][n['mesh']]['primitives']:
   attrs=prim['attributes'];ji=ac(attrs['JOINTS_0']);w=ac(attrs['WEIGHTS_0']);assert ji.shape==w.shape
   assert np.all(np.isfinite(w)) and np.all(w>=0) and np.allclose(w.sum(axis=1),1,atol=1e-5)
   assert np.all(ji < len(skin['joints']))
   soft+=int(np.count_nonzero((w>1e-3).sum(axis=1)>1));count+=len(w)
assert count>200 and soft>0,(count,soft)
assert len(j['animations'])==10
for a in j['accessors']:
 v=j['bufferViews'][a['bufferView']];assert v.get('byteOffset',0)+v['byteLength']<=len(buf)
s=(p/'scripts/rigged_pose_driver.gd').read_text()
for key in ['Rig_Foot_','for joint_id in [ankle, knee, hip]','chain_bones.append([hip, knee, ankle, tip])','CCD_ITERATIONS := 9','skeleton.to_local(anchors[i])']:
 assert key in s,key
readme=(p/'README_v2.9.md').read_text();assert len([line for line in readme.splitlines() if line[:1].isdigit() and '. ' in line])==40
print('v2.9 skin and foot-IK checks passed:',count,'vertices,',soft,'blended')
