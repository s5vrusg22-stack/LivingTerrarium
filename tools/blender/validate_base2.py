#!/usr/bin/env python3
"""Validate generated Base2 GLB without third-party Python packages."""
import json, struct, sys
from pathlib import Path

def validate(path):
    data=Path(path).read_bytes()
    assert len(data)>=20, 'GLB too short'
    magic,version,total=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2, 'Expected GLB 2.0'
    assert total==len(data), 'GLB length mismatch'
    length,chunk=struct.unpack_from('<I4s',data,12)
    assert chunk==b'JSON', 'Missing JSON chunk'
    doc=json.loads(data[20:20+length])
    names=[x.get('name','') for x in doc.get('nodes',[])]
    required=['head_triangular_base','thorax','CTRL_head','CTRL_abdomen']
    for name in required:
        assert any(name in n for n in names),f'Missing {name}'
    assert len(doc.get('meshes',[]))>50,'Unexpectedly simple geometry'
    assert doc.get('animations'), 'No exported animation'
    print('PASS',path,'meshes',len(doc['meshes']),'animations',len(doc['animations']))

if __name__=='__main__':
    validate(sys.argv[1] if len(sys.argv)>1 else 'assets/models/base2_detailed.glb')
