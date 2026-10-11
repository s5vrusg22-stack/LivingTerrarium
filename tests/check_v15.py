from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text()
for item in ['foot_anchors: Array[Vector3]','func _initialize_foot_anchors()', 'foot_in_swing[i]', 'foot_swing_origins[i].lerp(desired_world, eased)', 'joint.to_local(foot_world)', '_raycast_foot_height(desired_world)', '_pose_gait_bone(tarsomeres[segment_index]', 'FOOT_REPLANT_DISTANCE']:
    assert item in s, item
assert s.index('_initialize_foot_anchors()\n    _create_ui()') > 0
print('v1.5 world-space foot placement static checks passed')
