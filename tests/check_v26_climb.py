from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'scripts/main.gd').read_text()
r=(p/'scripts/rigged_pose_driver.gd').read_text()
for x in ['func _advance_climb','func _create_climbable_branch','_walkable_wood(self, climb_branch_start','climb_progress','foot_world = on_axis + contact_normal * 0.145','Basis.looking_at(travel_direction, radial)','foot_anchors[i].distance_to(desired_world)','return "CLIMB"']:
 assert x in s,x
for x in ['lateral_bias','atan2(target_local.z','Flat glTF bones']:
 assert x in r,x
print('v2.6 branch and pose static checks passed')
