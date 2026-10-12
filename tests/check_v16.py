from pathlib import Path
p = Path(__file__).resolve().parents[1]
s = (p / 'scripts/main.gd').read_text()
assert '    _enhance_mantis_model()' in s
assert s.count('func _enhance_mantis_model()') == 1
for i in range(1, 21):
    assert f'# {i:02d} ' in s, f'missing modeling pass {i}'
for symbol in ('head_pivot', 'thorax_pivot', 'abdomen', 'foreleg_elbows', 'antennae'):
    assert symbol in s
assert (p / 'project.godot').exists()
assert (p / 'scenes/main.tscn').exists()
assert len(list((p / 'assets/textures').glob('*.png'))) >= 15
print('v1.6 static checks passed: 20 passes, scene, textures')
