from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
s=(root/'scripts/main.gd').read_text()
assert s.count('func _leaf_mesh()') == 1
for marker in [
    'vertex_color_use_as_albedo = true', 'PackedColorArray()', 'var rock_material :=',
    '_apply_pbr(rock_material, "stone")', 'foot_anchors[i]', 'var frame_color :=',
    'func _create_feeder_insect(', 'three distinct leg pairs', '"hips": leg_hips',
    'func _mantis_wing_profile(', 'var max_width: float = 0.34 if hindwing else 0.15',
    'FLIGHT_TAKEOFF_DURATION := 0.95', 'var launch_ease := launch_t * launch_t * (3.0 - 2.0 * launch_t)',
    'var flight_pose_blend: float', 'Keep all four walking feet on their resting contacts',
    'Cricket tympanum on the fore tibia', 'for tarsomere_index in range(3)',
    'Two longer discoidal spines', 'Mandible_%d'
]:
    assert marker in s, marker
for kind in ['mantis_cuticle','mantis_eye','bark','substrate','stone']:
    for suffix in ['albedo','normal','roughness']:
        file=root/'assets'/'textures'/f'{kind}_{suffix}.png'
        assert file.exists(), file
        with Image.open(file) as im:
            im.verify()
print('v2.0 geometry/material and texture regression checks OK')
