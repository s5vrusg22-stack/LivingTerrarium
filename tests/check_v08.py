from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text()
for token in ['func _nearest_prey()', 'target_prey = _nearest_prey()', 'head_pivot.rotation.y = lerp_angle', 'away.normalized() * 0.28', 'prey_nodes.erase(target_prey)', 'animal.position.x = clampf']:
 assert token in s, token
print('v0.8 static checks passed (not an engine runtime test)')
