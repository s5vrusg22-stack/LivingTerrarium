from pathlib import Path
s=Path(__file__).resolve().parents[1].joinpath('scripts/main.gd').read_text()
for marker in ('func _surface_height_at(', 'foot_anchors[i]', 'joint.to_global(', 'joint.to_local(', '발 접지 켜기/끄기'):
    assert marker in s, marker
assert s.count('func _animate_mantis(')==1
print('v0.9 static markers OK')
