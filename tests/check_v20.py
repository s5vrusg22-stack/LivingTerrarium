from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
s=(root/'scripts/main.gd').read_text()
assert s.count('func _leaf_mesh(shape: int = 0)') == 1
assert (root/'tools/generate_leaf_materials.py').exists()
for marker in [
    'vertex_color_use_as_albedo = true', 'PackedColorArray()', 'var rock_material :=',
    '_apply_pbr(rock_material, "stone")', 'foot_anchors[i]', 'var frame_color :=',
    'func _create_feeder_insect(', 'three distinct leg pairs', '"hips": leg_hips',
    'func _mantis_wing_profile(', 'var max_width: float = 0.42 if hindwing else 0.215',
    'const BASE_MANTIS_SCALE := 0.60', 'gait_joints.append([hip_joint, knee_joint, ankle_joint])',
    'var longitudinal_stations := 28', 'var lateral_stations := 24',
    'var secondary_vein := 0.0', 'sun.shadow_blur = 1.15',
    'env.adjustment_contrast = 1.07', 'leaf_mesh_cache[variant] = mesh',
    'TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC',
    'leg_spurs.append(tibial_spurs)', 'counter_sway * 0.045',
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
for suffix in ['albedo','normal','roughness']:
    file=root/'assets'/'textures'/f'leaf_{suffix}.svg'
    assert file.exists(), file
    svg=ET.parse(file).getroot()
    assert svg.attrib.get('width') == '1024' and svg.attrib.get('height') == '1024', file
print('v2.0 geometry/material and texture regression checks OK')

