from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts'/'main.gd'
s=p.read_text()
for token in ('func _solve_leg_knee(', 'func _pose_gait_bone(', 'gait_segments.append(', 'tripod :=', 'func _animate_mantis('):
    assert token in s, token
assert s.count('func _solve_leg_knee(')==1
print('Static IK source checks passed (not a Godot runtime test)')
