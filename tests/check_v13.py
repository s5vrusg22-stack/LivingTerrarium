from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
script = (root/'scripts/main.gd').read_text()
for name in ['mantis_cuticle','mantis_eye','bark','substrate','stone']:
    for suffix in ['albedo','normal','roughness']:
        path = root/'assets/textures'/f'{name}_{suffix}.png'
        assert path.is_file(), path
        expected_size = (1024, 1024) if name == 'mantis_cuticle' else (512, 512)
        with Image.open(path) as img:
            assert img.size == expected_size, path
for suffix in ['albedo','normal','roughness']:
    path = root/'assets/textures'/f'mantis_wing_{suffix}.png'
    with Image.open(path) as img:
        assert img.size == (1024, 1024), path
assert 'func _apply_pbr(' in script
assert 'mat.normal_texture = pbr_normal[kind]' in script
assert 'mat.roughness_texture = pbr_roughness[kind]' in script
assert 'func _animate_mantis(' in script
assert 'func _raycast_foot_height(' in script
print('v1.3 static texture + integration checks passed')
