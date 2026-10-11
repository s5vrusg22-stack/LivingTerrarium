from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'scripts/main.gd').read_text()
b=(root/'scripts/habitat_interactions.gd').read_text()
assert 'HabitatInteractions.new()' in a
assert 'habitat_interactions.simulate(dt)' in a
assert 'habitat_interactions.leaf_displacement(joint)' in a
assert 'habitat_interactions.register_prey(prey)' in a
assert 'habitat_interactions.unregister_prey(target_prey)' in a
assert 'habitat_interactions.on_decoration_added(root, kind)' in a
for name in ['setup','simulate','_plant_interactions','_prey_interactions','_habitat_interactions','summary','_nearest_cover']:
    assert f'func {name}(' in b
assert b.count('func ') >= 10
assert (root/'scenes/main.tscn').exists()
print('v1.8 static integration checks: PASS')
