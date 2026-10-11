from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
s=(root/'scripts/main.gd').read_text()
assert s.count('func _leaf_mesh()') == 1
for marker in ['vertex_color_use_as_albedo = true', 'PackedColorArray()', 'var rock_material :=', '_apply_pbr(rock_material, "stone")', 'foot_anchors[i]', 'var frame_color :=', 'func _create_feeder_insect(', 'Six overlapping abdominal tergites', '"hips": leg_hips']:
    assert marker in s, marker
for kind in ['mantis_cuticle','mantis_eye','bark','substrate','stone']:
    for suffix in ['albedo','normal','roughness']:
        file=root/'assets'/'textures'/f'{kind}_{suffix}.png'
        assert file.exists(), file
        with Image.open(file) as im:
            im.verify()
print('v2.0 geometry/material and texture regression checks OK')
