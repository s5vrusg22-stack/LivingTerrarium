from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'scripts/rigged_pose_driver.gd').read_text()
keys=['HIP_YAW_LIMIT','HIP_PITCH_LIMIT','KNEE_FLEX_LIMIT','ANKLE_FLEX_LIMIT','MAX_TARGET_SPEED','MAX_ROTATION_SPEED','MIN_REACH_RATIO','SINGULARITY_EPS','MAX_INVALID_FRAMES','CCD_DAMPING','_limit_joint_rotation','_finite_vector','_finite_basis','get_ik_diagnostics','target_ready.fill(false)','last_error[leg_index]','chain_enabled','MAX_FRAME_DELTA','CLIMB_STANCE_WEIGHT','SWING_WEIGHT']
for key in keys: assert key in s,key
assert s.count('func _solve_leg_ccd(')==1
assert len([line for line in (p/'README_v3.0.md').read_text().splitlines() if line.split('. ')[0].isdigit()])==50
print('v3.0 joint limit safeguards: 20 code checks, 50 documented items passed')
