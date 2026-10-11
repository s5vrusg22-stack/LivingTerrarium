from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'scripts/main.gd').read_text()
for token in ('func _create_floor_collider()', 'func _raycast_foot_height(', 'PhysicsRayQueryParameters3D.create', 'func _walkable_wood(', 'func _walkable_sphere(', 'movement_blend', '_raycast_foot_height(desired_world)'):
    assert token in s, token
assert (p/'project.godot').exists()
assert (p/'scenes/main.tscn').exists()
print('v1.0 structural checks OK (not an engine/runtime test)')
