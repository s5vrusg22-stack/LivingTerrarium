from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text()
for token in ['_create_animated_ecosystem()', 'func _leaf_mesh()', 'func _animate_ecosystem(dt: float)', 'func _create_prey_appendages(prey: Node3D)', 'func _animate_prey_appendages(prey: Node3D, velocity: Vector3)', 'wind_enabled', 'plant_pivots', 'drifting_particles', '_animate_ecosystem(dt)', '_animate_prey_appendages(prey, velocity)']:
    assert token in s, token
assert s.count('func _create_animated_ecosystem()') == 1
print('v1.7 static checks passed')
