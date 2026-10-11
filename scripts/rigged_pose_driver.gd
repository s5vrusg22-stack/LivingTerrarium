class_name RiggedPoseDriver
extends Node

# Procedural pose corrections are layered on top of imported glTF clips.
# Hierarchical CCD is applied to the four walking legs when compatible bones exist.
const SIDES := ["L", "R"]
const LEGS_PER_SIDE := 2
const MAX_ANGLE := 0.28
const FOOT_SMOOTHING := 9.0
const CCD_ITERATIONS := 9
const MAX_CCD_STEP := 0.20
const MAX_TARGET_DISTANCE := 1.20
const IK_EPSILON := 0.008
const MIN_IK_SEGMENT := 0.008
const IK_BLEND_SPEED := 6.0
# Conservative anatomical constraints (radians). Tunable per leg, not measured anatomy.
const HIP_YAW_LIMIT := 0.55
const HIP_PITCH_LIMIT := 0.80
const KNEE_FLEX_LIMIT := 1.35
const ANKLE_FLEX_LIMIT := 0.90
const MAX_FRAME_DELTA := 0.05
const MAX_TARGET_SPEED := 2.4
const MAX_ROTATION_SPEED := 3.2
const TARGET_DEAD_ZONE := 0.002
const MIN_REACH_RATIO := 0.12
const SINGULARITY_EPS := 0.0001
const MAX_SOLVE_ERROR := 0.12
const MAX_INVALID_FRAMES := 8
const CCD_DAMPING := 0.70
const STANCE_WEIGHT := 0.95
const SWING_WEIGHT := 0.28
const CLIMB_STANCE_WEIGHT := 1.0
const MAX_BONE_SCALE_DEVIATION := 0.12
const EPSILON := 0.000001


var enabled := true
var valid := false
var validation_message := "uninitialized"
var skeleton: Skeleton3D
var player: AnimationPlayer
var bone_map: Dictionary = {}
var leg_offsets: Array[float] = []
var head_offset := 0.0
var foreleg_offset := 0.0
var active_state := "IDLE"
var hierarchical_chains := false
var chain_bones: Array = []
var chain_reach: Array[float] = []
var ik_blend: Array[float] = []
var filtered_targets: Array[Vector3] = []
var target_ready: Array[bool] = []
var invalid_frames: Array[int] = []
var last_error: Array[float] = []
var solve_iterations: Array[int] = []
var joint_rest_bases: Dictionary = {}
var chain_enabled: Array[bool] = []
var last_state := "IDLE"
var diagnostic_events := 0
var max_observed_error := 0.0
var limit_hits := 0
var target_rejections := 0
var reached_targets := 0


func setup(target_skeleton: Skeleton3D, target_player: AnimationPlayer) -> void:
    skeleton = target_skeleton
    player = target_player
    bone_map.clear()
    var missing: Array[String] = []
    for side in SIDES:
        for index in range(LEGS_PER_SIDE):
            for prefix in ["Coxa", "Tibia", "Joint", "Foot"]:
                var name := "Rig_%s_%s%d" % [prefix, side, index]
                var bone := skeleton.find_bone(name)
                if bone < 0:
                    missing.append(name)
                else:
                    bone_map[name] = bone
        for prefix in ["ForeFemur", "ForeTibia", "Antenna"]:
            var name := "Rig_%s_%s" % [prefix, side]
            var bone := skeleton.find_bone(name)
            if bone < 0:
                missing.append(name)
            else:
                bone_map[name] = bone
    for name in ["Rig_Head", "Rig_Thorax"]:
        var bone := skeleton.find_bone(name)
        if bone < 0:
            missing.append(name)
        else:
            bone_map[name] = bone
    leg_offsets.resize(4)
    leg_offsets.fill(0.0)
    valid = missing.is_empty()
    validation_message = "all required rig bones found" if valid else "Missing: " + ", ".join(missing)
    enabled = valid
    chain_bones.clear()
    chain_reach.clear()
    ik_blend.resize(4)
    ik_blend.fill(0.0)
    hierarchical_chains = valid
    filtered_targets.resize(4)
    target_ready.resize(4)
    target_ready.fill(false)
    invalid_frames.resize(4)
    invalid_frames.fill(0)
    last_error.resize(4)
    last_error.fill(0.0)
    solve_iterations.resize(4)
    solve_iterations.fill(0)
    chain_enabled.resize(4)
    chain_enabled.fill(false)
    joint_rest_bases.clear()
    if valid:
        for side in SIDES:
            for index in range(LEGS_PER_SIDE):
                var hip: int = bone_map["Rig_Coxa_%s%d" % [side, index]]
                var knee: int = bone_map["Rig_Joint_%s%d" % [side, index]]
                var ankle: int = bone_map["Rig_Tibia_%s%d" % [side, index]]
                var tip: int = bone_map["Rig_Foot_%s%d" % [side, index]]
                chain_bones.append([hip, knee, ankle, tip])
                var hip_rest := skeleton.get_bone_global_rest(hip).origin
                var knee_rest := skeleton.get_bone_global_rest(knee).origin
                var tip_rest := skeleton.get_bone_global_rest(tip).origin
                var upper := hip_rest.distance_to(knee_rest)
                var ankle_rest := skeleton.get_bone_global_rest(ankle).origin
                var lower := knee_rest.distance_to(ankle_rest)
                var tarsus := ankle_rest.distance_to(tip_rest)
                chain_reach.append(upper + lower + tarsus)
                var chain_ok := skeleton.get_bone_parent(knee) == hip and skeleton.get_bone_parent(ankle) == knee and skeleton.get_bone_parent(tip) == ankle and upper >= MIN_IK_SEGMENT and lower >= MIN_IK_SEGMENT and tarsus >= MIN_IK_SEGMENT
                chain_enabled[index if side == "L" else index + 2] = chain_ok
                if not chain_ok:
                    hierarchical_chains = false
                for bone_id in [hip, knee, ankle]:
                    joint_rest_bases[bone_id] = skeleton.get_bone_global_rest(bone_id).basis.orthonormalized()
    if not hierarchical_chains:
        validation_message += "; hierarchical IK unavailable, orientation fallback"

func reset_offsets() -> void:
    leg_offsets.fill(0.0)
    head_offset = 0.0
    foreleg_offset = 0.0
    ik_blend.fill(0.0)
    target_ready.fill(false)
    invalid_frames.fill(0)
    last_error.fill(0.0)
    solve_iterations.fill(0)
    if skeleton != null:
        skeleton.clear_bones_global_pose_override()

func set_motion_targets(state: String, movement: float, anchors: Array[Vector3], swings: Array[bool], animal_root: Node3D, joints: Array[Node3D], head: Node3D, strike_timer: float, dt: float) -> void:
    if not enabled or not valid or skeleton == null:
        return
    if dt <= 0.0 or not is_finite(dt):
        return
    dt = minf(dt, MAX_FRAME_DELTA)
    if state != last_state:
        # Prevent a stale ground contact from being carried onto a branch.
        if state == "CLIMB" or last_state == "CLIMB":
            target_ready.fill(false)
        last_state = state
    active_state = state
    # Start each update from the imported clip, rather than accumulating previous
    # frame's IK rotations. This also releases overrides when the model is paused.
    skeleton.clear_bones_global_pose_override()
    # A target is supplied in WORLD coordinates by the grounded gait controller.
    # Convert it into the Skeleton3D local frame; never treat it as joint-local.
    for i in range(4):
        if i >= anchors.size() or i >= swings.size():
            continue
        if not _finite_vector(anchors[i]):
            target_rejections += 1
            continue
        if hierarchical_chains and chain_enabled[i]:
            _solve_leg_ccd(i, skeleton.to_local(anchors[i]), swings[i], movement, dt)
        elif i < joints.size():
            # Flat glTF bones: backward compatibility with older flat skeletons.
            var side := "L" if i < 2 else "R"
            var index := i % 2
            var target_local := joints[i].to_local(anchors[i])
            var reach_bias := clampf(atan2(target_local.z, maxf(0.1, absf(target_local.y))) * 0.22, -MAX_ANGLE, MAX_ANGLE)
            var lateral_bias := clampf(atan2(target_local.x, maxf(0.1, absf(target_local.y))) * 0.12, -MAX_ANGLE, MAX_ANGLE)
            var goal := (reach_bias + lateral_bias * 0.3) * movement
            leg_offsets[i] = move_toward(leg_offsets[i], goal, dt * FOOT_SMOOTHING)
            _apply_local_rotation("Rig_Coxa_%s%d" % [side, index], Vector3.RIGHT, leg_offsets[i], 0.72)
            _apply_local_rotation("Rig_Tibia_%s%d" % [side, index], Vector3.RIGHT, -leg_offsets[i] * 0.62, 0.62)
    var head_goal := clampf(head.rotation.y if head != null else 0.0, -0.35, 0.35)
    head_offset = move_toward(head_offset, head_goal, dt * 6.0)
    _apply_local_rotation("Rig_Head", Vector3.UP, head_offset, 0.65)
    var strike_goal := -0.45 if state == "STRIKE" and strike_timer > 0.0 else -0.18 if state in ["HUNT", "ALERT"] else 0.0
    foreleg_offset = move_toward(foreleg_offset, strike_goal, dt * 10.0)
    for side in SIDES:
        _apply_local_rotation("Rig_ForeFemur_" + side, Vector3.RIGHT, foreleg_offset, 0.75)
        _apply_local_rotation("Rig_ForeTibia_" + side, Vector3.RIGHT, -foreleg_offset * 0.48, 0.65)

func _apply_local_rotation(name: String, axis: Vector3, angle: float, strength: float) -> void:
    if not bone_map.has(name):
        return
    var index: int = bone_map[name]
    # Use imported clip's pose as the baseline, rather than replacing it with
    # the bind pose. Global pose overrides are intentionally nonpersistent.
    var base := skeleton.get_bone_global_pose_no_override(index)
    var rotated := base.rotated_local(axis, angle)
    skeleton.set_bone_global_pose_override(index, rotated, strength, false)

func _solve_leg_ccd(leg_index: int, target: Vector3, swinging: bool, movement: float, dt: float) -> void:
    # The imported clip supplies the base pose. We solve in skeleton coordinates.
    # A true distal Foot bone replaces the approximate tibia-origin endpoint.
    # A grounded foot gets stronger IK than a swinging foot, while blending avoids
    # discontinuities when entering or leaving a climb/step.
    var chain: Array = chain_bones[leg_index]
    var hip: int = chain[0]
    var knee: int = chain[1]
    var ankle: int = chain[2]
    var tip: int = chain[3]
    var hip_pos := skeleton.get_bone_global_pose(hip).origin
    var relative := target - hip_pos
    var reachable := minf(MAX_TARGET_DISTANCE, maxf(MIN_IK_SEGMENT, chain_reach[leg_index] * 0.97))
    if relative.length() > reachable:
        target = hip_pos + relative.normalized() * reachable
    if not _finite_vector(target):
        target_rejections += 1
        return
    # Keep target motion bounded without slowing deliberate swing trajectories.
    if not target_ready[leg_index]:
        filtered_targets[leg_index] = target
        target_ready[leg_index] = true
    else:
        var previous: Vector3 = filtered_targets[leg_index]
        var step := target - previous
        var max_step := MAX_TARGET_SPEED * dt * (2.0 if swinging else 1.0)
        filtered_targets[leg_index] = previous + step.limit_length(max_step)
    target = filtered_targets[leg_index]
    var min_reach := chain_reach[leg_index] * MIN_REACH_RATIO
    relative = target - hip_pos
    if relative.length() < min_reach and relative.length() > EPSILON:
        target = hip_pos + relative.normalized() * min_reach
    var desired_weight := SWING_WEIGHT if swinging else CLIMB_STANCE_WEIGHT if active_state == "CLIMB" else STANCE_WEIGHT
    ik_blend[leg_index] = move_toward(ik_blend[leg_index], desired_weight, dt * IK_BLEND_SPEED)
    var weight := ik_blend[leg_index]
    # CCD: rotate distal ankle, knee, then hip; the Foot joint is the end effector.
    for iteration in range(CCD_ITERATIONS):
        solve_iterations[leg_index] = iteration + 1
        for joint_id in [ankle, knee, hip]:
            var joint_pose := skeleton.get_bone_global_pose(joint_id)
            var pivot := joint_pose.origin
            var tip_pos := skeleton.get_bone_global_pose(tip).origin
            var error := tip_pos.distance_to(target)
            last_error[leg_index] = error
            max_observed_error = maxf(max_observed_error, error)
            if error <= IK_EPSILON:
                reached_targets += 1
                invalid_frames[leg_index] = 0
                return
            var from_vec := tip_pos - pivot
            var to_vec := target - pivot
            if from_vec.length_squared() < 0.000001 or to_vec.length_squared() < 0.000001:
                continue
            var axis := from_vec.cross(to_vec)
            if axis.length_squared() < SINGULARITY_EPS * SINGULARITY_EPS:
                # Anti-parallel vectors need a deterministic orthogonal axis.
                if from_vec.dot(to_vec) < 0.0:
                    axis = from_vec.cross(Vector3.UP)
                    if axis.length_squared() < EPSILON:
                        axis = from_vec.cross(Vector3.RIGHT)
                if axis.length_squared() < EPSILON:
                    continue
            axis = axis.normalized()
            var angle := minf(from_vec.angle_to(to_vec) * CCD_DAMPING, minf(MAX_CCD_STEP, MAX_ROTATION_SPEED * dt))
            if not is_finite(angle) or angle < EPSILON:
                continue
            var corrected := joint_pose
            corrected.basis = (Basis(Quaternion(axis, angle)) * joint_pose.basis).orthonormalized()
            corrected.basis = _limit_joint_rotation(joint_id, corrected.basis, hip, knee, ankle)
            if not _finite_basis(corrected.basis):
                target_rejections += 1
                continue
            skeleton.set_bone_global_pose_override(joint_id, corrected, weight, true)
        if skeleton.get_bone_global_pose(tip).origin.distance_to(target) <= IK_EPSILON:
            reached_targets += 1
            invalid_frames[leg_index] = 0
            return
    last_error[leg_index] = skeleton.get_bone_global_pose(tip).origin.distance_to(target)
    if last_error[leg_index] > MAX_SOLVE_ERROR:
        invalid_frames[leg_index] += 1
        if invalid_frames[leg_index] >= MAX_INVALID_FRAMES:
            target_ready[leg_index] = false
            invalid_frames[leg_index] = 0
            diagnostic_events += 1
    else:
        invalid_frames[leg_index] = 0

func _limit_joint_rotation(bone_id: int, proposed_global: Basis, hip: int, knee: int, ankle: int) -> Basis:
    # Work relative to the animated pose, not the static rest pose.
    # Swing/twist limits are conservative safeguards, not anatomical calibration.
    var animated := skeleton.get_bone_global_pose_no_override(bone_id).basis.orthonormalized()
    var delta := (animated.inverse() * proposed_global).orthonormalized()
    var euler := delta.get_euler()
    var pitch_limit := HIP_PITCH_LIMIT if bone_id == hip else KNEE_FLEX_LIMIT if bone_id == knee else ANKLE_FLEX_LIMIT
    var yaw_limit := HIP_YAW_LIMIT if bone_id == hip else 0.22
    var bounded := Vector3(clampf(euler.x, -pitch_limit, pitch_limit), clampf(euler.y, -yaw_limit, yaw_limit), clampf(euler.z, -0.35, 0.35))
    if euler.distance_to(bounded) > 0.0001:
        limit_hits += 1
    return (animated * Basis.from_euler(bounded)).orthonormalized()

func _finite_vector(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _finite_basis(value: Basis) -> bool:
    return _finite_vector(value.x) and _finite_vector(value.y) and _finite_vector(value.z)

func get_ik_diagnostics() -> Dictionary:
    return {
        "hierarchical": hierarchical_chains,
        "chains": chain_enabled.duplicate(),
        "error": last_error.duplicate(),
        "iterations": solve_iterations.duplicate(),
        "limit_hits": limit_hits,
        "target_rejections": target_rejections,
        "reached_targets": reached_targets,
        "recoveries": diagnostic_events,
        "max_observed_error": max_observed_error
    }

