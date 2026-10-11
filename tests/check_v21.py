from pathlib import Path
import ast
root=Path(__file__).resolve().parents[1]
s=(root/'tools/generate_rigged_mantis_blender.py').read_text()
ast.parse(s)
for marker in ['MantisRig', 'vertex_groups.new', "modifiers.new('Armature deform'", 'bpy.ops.export_scene.gltf', 'bpy.ops.wm.save_as_mainfile', 'NLA_TRACKS', "'Idle'", "'Walk'", "'Strike'", "'Groom'", "'Feed'"]:
    assert marker in s,marker
assert (root/'scripts/main.gd').exists()
print('v2.1 generator structure: PASS (Blender runtime not tested)')
