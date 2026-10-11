from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / 'scripts/main.gd').read_text()
interaction = (root / 'scripts/habitat_interactions.gd').read_text()
assert 'prey_leaf_touch_count' in interaction
assert 'prey_impulse' in interaction
assert 'last_leaf_contact[id] = clock' in interaction
assert 'humidity_droop * plant_stiffness[i]' in main
assert 'func _plant_interactions(dt: float)' in interaction
assert 'habitat_interactions.simulate(dt)' in main
print('v1.9 interaction static checks: PASS')
