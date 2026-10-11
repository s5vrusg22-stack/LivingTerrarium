extends Node3D

const SAVE_PATH := "user://terrarium_save_v6.json"
const BACKUP_PATH := "user://terrarium_save_v6_backup.json"
const V5_SAVE_PATH := "user://terrarium_save_v5.json"
const V4_SAVE_PATH := "user://terrarium_save_v4.json"
const MAX_DECORATIONS := 32
const PREVIOUS_SAVE_PATH := "user://terrarium_save_v3.json"
const LEGACY_SAVE_PATH := "user://terrarium_save_v2.json"
const MAX_FOOD := 12
var hunger := 32.0
var energy := 86.0
var stress := 12.0
var humidity := 70.0
var temperature := 25.0
var food_count := 0
var simulation_paused := false
var behavior := "휴식"
var animal: Node3D
var camera: Camera3D
var status: Label
var notice: Label
var orbit_yaw := 0.0
var orbit_pitch := 0.25
var orbit_distance := 4.6
var pointer_last := Vector2.ZERO
var touching := false
var touch_points: Dictionary = {}
var pinch_previous := 0.0
var roam_target := Vector3.ZERO
var roam_time := 0.0
var elapsed := 0.0
var legs: Array[Node3D] = []
var antennae: Array[Node3D] = []
var root_ui: Control
var prey_nodes: Array[Node3D] = []
var feeding_timer := 0.0
var autosave_timer := 0.0
var follow_animal := false
var strike_time := 0.0
var life_age := 0.0
var molt_count := 0
var growth := 0.35
var molt_progress := 0.0
var prey_motion_clock := 0.0
var walking_phase := 0.0
var head_pivot: Node3D
var forelegs: Array[Node3D] = []
var leg_pivots: Array[Node3D] = []
var gait_segments: Array = []
var gait_feet: Array[Vector3] = []
var abdomen: Node3D
var prey_velocities: Dictionary = {}
var molting := false
var decorations: Array[Node3D] = []
var decoration_data: Array = []
var editing := false
var decor_kind := "rock"
var edit_hint: Label
var terrain_root: Node3D
var step_targets: Array[Vector3] = []
var edit_touch_start := Vector2.ZERO
var edit_touch_moved := false
var edit_mouse_start := Vector2.ZERO
var edit_mouse_moved := false
var target_prey: Node3D = null
var prey_alert_radius := 0.43
var step_height := 0.085
var stats_visible := true
var ui_panel: PanelContainer
var foot_contact_smoothing := 10.0
var planted_foot_heights: Array[float] = []
var foot_contacts_enabled := true
# Physics foot contacts use the actual collision geometry rather than a
# height estimate. Layer 2 is reserved for walkable enclosure surfaces.
const WALKABLE_LAYER := 2
var foot_contact_hits := 0
var movement_blend := 0.0
# Six selectable procedural animation clips: IDLE, WALK, ALERT, GROOM, HUNT, STRIKE.
# MOLT is an additional lifecycle override. These are runtime poses, not GLB keyframes.
const ANIMATIONS := ["IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND"]
var animation_preview := "AUTO"
var animation_clock := 0.0
var animation_weight := 0.0
var animation_state := "IDLE"
var preview_strike_clock := 0.0
var animation_label: Label
var model_details: Array[Node3D] = []
var body_texture: Texture2D
var eye_texture: Texture2D
var bark_texture: Texture2D
var substrate_texture: Texture2D
var pbr_normal: Dictionary = {}
var pbr_roughness: Dictionary = {}
var stone_texture: Texture2D
var thorax_pivot: Node3D
var foreleg_elbows: Array[Node3D] = []
var foreleg_claws: Array[Node3D] = []
var tarsal_tips: Array[Node3D] = []
# Stance feet retain a world-space contact point while the body travels.
# Swing feet move to the next foothold, then plant on the collision surface.
var foot_anchors: Array[Vector3] = []
var foot_in_swing: Array[bool] = []
var foot_swing_origins: Array[Vector3] = []
var foot_swing_progress: Array[float] = []
var foot_toes: Array[MeshInstance3D] = []
const FOOT_REPLANT_DISTANCE := 0.24
const FOOT_SWING_DURATION := 0.23

# v2.4: imported skinned GLB is the visible model; the existing procedural
# hierarchy remains an invisible motion/IK fallback and physics reference.
const RIGGED_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_rigged.glb")
var rigged_visual: Node3D
var rigged_player: AnimationPlayer
var rigged_clip := ""
var use_rigged_visual := true
var rigged_available := false
var rigged_clips: Dictionary = {}
var procedural_meshes: Array[MeshInstance3D] = []
var rigged_import_warnings: Array[String] = []
var visual_model_scale := 1.0
# v2.5: runtime rig pose adaptation, applied after the GLB animation player.
var rigged_pose_driver: RiggedPoseDriver
var rigged_skeleton: Skeleton3D
var rigged_ik_enabled := true
var rigged_pose_status := "not initialized"
# v2.6: scripted traversal of a real, collidable inclined branch.
var climb_active := false
var climb_progress := 0.0
var climb_cooldown := 18.0
var climb_branch_start := Vector3(-0.18, -0.43, 0.60)
var climb_branch_end := Vector3(-0.02, 0.38, 0.52)
const CLIMB_SPEED := 0.18
const CLIMB_BODY_CLEARANCE := 0.12







# Lightweight procedural ecosystem animation (mobile-friendly).
var wind_strength := 0.45
var wind_enabled := true
var ecosystem_clock := 0.0
var plant_pivots: Array[Node3D] = []
var plant_phases: Array[float] = []
var plant_stiffness: Array[float] = []
var prey_appendages: Dictionary = {}
var habitat_motion_root: Node3D
var drifting_particles: Array[Node3D] = []
var particle_origins: Array[Vector3] = []

# v1.8: shared, bounded habitat interaction controller.
var habitat_interactions: HabitatInteractions
var habitat_event_count := 0


func _ready() -> void:
    _load_textures()
    _create_world()
    terrain_root = Node3D.new()
    terrain_root.name = "UserDecorations"
    add_child(terrain_root)
    _create_floor_collider()
    _create_climbable_branch()
    _create_mantis()
    _initialize_rigged_visual()
    planted_foot_heights.resize(6)
    planted_foot_heights.fill(-0.48)
    _initialize_foot_anchors()
    _create_ui()
    _create_habitat_details()
    _create_animated_ecosystem()
    habitat_interactions = HabitatInteractions.new()
    habitat_interactions.name = "HabitatInteractions"
    add_child(habitat_interactions)
    habitat_interactions.setup(self)
    _load_state(false)
    _sync_prey()
    _update_camera()
    _refresh()

func _initialize_rigged_visual() -> void:
    # Keep procedural geometry available if GLB import or clip discovery fails.
    procedural_meshes.clear()
    _collect_procedural_meshes(animal)
    var imported := RIGGED_MANTIS_SCENE.instantiate()
    if not imported is Node3D:
        rigged_import_warnings.append("GLB root is not Node3D")
        return
    rigged_visual = imported as Node3D
    rigged_visual.name = "RiggedMantisVisual"
    animal.add_child(rigged_visual)
    # Both models share the animal-local origin and move with the same AI root.
    rigged_visual.position = Vector3.ZERO
    rigged_visual.rotation = Vector3.ZERO
    rigged_visual.scale = Vector3.ONE * visual_model_scale
    rigged_player = _find_rigged_player(rigged_visual)
    if rigged_player == null:
        rigged_import_warnings.append("No AnimationPlayer found in imported GLB")
        rigged_visual.visible = false
        return
    for library_name in rigged_player.get_animation_library_list():
        var library := rigged_player.get_animation_library(library_name)
        if library == null:
            continue
        for clip_name in library.get_animation_list():
            var full_name := String(clip_name)
            if not String(library_name).is_empty():
                full_name = String(library_name) + "/" + full_name
            rigged_clips[String(clip_name).to_upper()] = full_name
    rigged_available = not rigged_clips.is_empty()
    if not rigged_available:
        rigged_import_warnings.append("Imported model has no animation clips")
    _apply_visual_mode()
    if rigged_available:
        rigged_skeleton = _find_rigged_skeleton(rigged_visual)
        if rigged_skeleton != null:
            rigged_pose_driver = RiggedPoseDriver.new()
            rigged_pose_driver.name = "RiggedPoseDriver"
            rigged_visual.add_child(rigged_pose_driver)
            rigged_pose_driver.setup(rigged_skeleton, rigged_player)
            rigged_pose_status = rigged_pose_driver.validation_message
            if not rigged_pose_driver.hierarchical_chains:
                rigged_import_warnings.append("Hierarchical leg IK unavailable; using fallback")
            rigged_ik_enabled = rigged_pose_driver.valid
        else:
            rigged_pose_status = "Skeleton3D missing; clip playback only"
            rigged_import_warnings.append(rigged_pose_status)
        _play_rigged_clip("IDLE")

func _collect_procedural_meshes(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            procedural_meshes.append(child as MeshInstance3D)
        _collect_procedural_meshes(child)

func _find_rigged_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_rigged_player(child)
        if found != null:
            return found
    return null

func _find_rigged_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var result := _find_rigged_skeleton(child)
        if result != null:
            return result
    return null

func _apply_visual_mode() -> void:
    var show_rigged := use_rigged_visual and rigged_available
    for part in procedural_meshes:
        if is_instance_valid(part):
            part.visible = not show_rigged
    if rigged_visual != null:
        rigged_visual.visible = show_rigged
    if rigged_player != null:
        if show_rigged:
            rigged_player.speed_scale = 1.0
        else:
            rigged_player.stop()
    rigged_clip = ""
    if rigged_pose_driver != null:
        rigged_pose_driver.enabled = show_rigged and rigged_ik_enabled
        if not show_rigged:
            rigged_pose_driver.reset_offsets()

func _toggle_visual_model() -> void:
    use_rigged_visual = not use_rigged_visual
    _apply_visual_mode()
    if notice != null:
        notice.text = "3D 모델: " + ("리깅 GLB" if use_rigged_visual and rigged_available else "절차적 모델")

func _play_rigged_clip(clip: String) -> void:
    if rigged_player == null or not rigged_available:
        return
    var resolved := clip
    if not rigged_clips.has(resolved):
        resolved = "IDLE"
    if not rigged_clips.has(resolved):
        return
    if rigged_clip == resolved:
        return
    var name: String = rigged_clips[resolved]
    if not rigged_player.has_animation(name):
        rigged_import_warnings.append("Missing imported clip: " + name)
        return
    # Crossfade on the same AnimationPlayer, avoiding per-frame restarts.
    rigged_player.play(name, 0.18)
    rigged_clip = resolved

func _update_rigged_visual(_dt: float) -> void:
    if not use_rigged_visual or not rigged_available or rigged_visual == null:
        return
    var state := animation_state
    # Molting has no matching clip in the GLB; use a non-moving pose.
    if state == "MOLT":
        state = "IDLE"
    _play_rigged_clip(state)
    if rigged_pose_driver != null and rigged_ik_enabled:
        rigged_pose_driver.set_motion_targets(state, movement_blend, foot_anchors, foot_in_swing, animal, leg_pivots, head_pivot, strike_time, _dt)
    # Growth is already applied to the shared animal root, so never apply
    # a second growth scale here.

func _load_textures() -> void:
    body_texture = load("res://assets/textures/mantis_cuticle_albedo.png")
    eye_texture = load("res://assets/textures/mantis_eye_albedo.png")
    bark_texture = load("res://assets/textures/bark_albedo.png")
    substrate_texture = load("res://assets/textures/substrate_albedo.png")
    stone_texture = load("res://assets/textures/stone_albedo.png")
    for kind in ["mantis_cuticle", "mantis_eye", "bark", "substrate", "stone"]:
        pbr_normal[kind] = load("res://assets/textures/%s_normal.png" % kind)
        pbr_roughness[kind] = load("res://assets/textures/%s_roughness.png" % kind)

func _create_world() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 55.0
    add_child(camera)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.065, 0.085, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.8, 0.72)
    env.ambient_light_energy = 0.6
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)
    _box(Vector3(3.2, 0.2, 2.3), Vector3(0, -0.65, 0), Color(0.23, 0.15, 0.09))
    _box(Vector3(3.2, 1.8, 0.06), Vector3(0, 0.14, -1.17), Color(0.19, 0.25, 0.21, 0.45), true)
    _box(Vector3(0.05, 1.8, 2.3), Vector3(-1.62, 0.14, 0), Color(0.5, 0.7, 0.7, 0.16), true)
    _box(Vector3(0.05, 1.8, 2.3), Vector3(1.62, 0.14, 0), Color(0.5, 0.7, 0.7, 0.16), true)
    for i in range(9):
        var x := -1.3 + float(i % 5) * 0.56
        var z := -0.85 + float(i / 5) * 1.45
        _branch(Vector3(x, -0.43, z), Vector3(x + 0.16, 0.12 + float(i % 3) * 0.13, z - 0.08), 0.025)
    for i in range(12):
        var p := Vector3(-1.25 + float(i % 6) * 0.48, -0.49, -0.7 + float(i / 6) * 1.3)
        _ellipsoid(p, Vector3(0.11, 0.04, 0.16), Color(0.17 + 0.02 * (i % 3), 0.31, 0.12))

func _create_climbable_branch() -> void:
    # A deliberately wide, reachable branch with matching visual and collision.
    # The original decorative twigs are too narrow for reliable foot placement.
    _segment(self, climb_branch_start, climb_branch_end, 0.095, Color(0.29, 0.19, 0.11))
    _walkable_wood(self, climb_branch_start, climb_branch_end, 0.095)

func _advance_climb(dt: float) -> void:
    if not climb_active:
        if climb_cooldown > 0.0 or molting or stress > 65.0 or hunger > 45.0:
            return
        # Walk towards the foot of the branch before starting the ascent.
        var approach := Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        var planar := Vector2(animal.position.x - approach.x, animal.position.z - approach.z)
        if planar.length() > 0.13:
            animal.position.x = move_toward(animal.position.x, approach.x, dt * 0.20)
            animal.position.z = move_toward(animal.position.z, approach.z, dt * 0.20)
            behavior = "나뭇가지 접근"
            return
        climb_active = true
        climb_progress = 0.0
        for i in range(foot_in_swing.size()):
            foot_in_swing[i] = false
        behavior = "나뭇가지 등반"
    climb_progress = minf(1.0, climb_progress + dt * CLIMB_SPEED / climb_branch_start.distance_to(climb_branch_end))
    var center := climb_branch_start.lerp(climb_branch_end, climb_progress)
    var tangent := (climb_branch_end - climb_branch_start).normalized()
    var target := center + Vector3.UP * CLIMB_BODY_CLEARANCE
    animal.position = animal.position.lerp(target, clampf(dt * 3.5, 0.0, 1.0))
    animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-tangent.x, -tangent.z), clampf(dt * 3.0, 0.0, 1.0))
    behavior = "나뭇가지 등반"
    if climb_progress >= 1.0 and animal.position.distance_to(target) < 0.035:
        climb_active = false
        climb_cooldown = 38.0
        # Return to the floor gradually on the next exploration phase.
        roam_target = Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        roam_time = 0.0

func _create_floor_collider() -> void:
    var floor_body := StaticBody3D.new()
    floor_body.name = "WalkableSubstrate"
    floor_body.collision_layer = WALKABLE_LAYER
    floor_body.collision_mask = 0
    floor_body.position = Vector3(0, -0.55, 0)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(3.2, 0.2, 2.3)
    shape.shape = box_shape
    floor_body.add_child(shape)
    add_child(floor_body)

func _walkable_sphere(parent: Node3D, center: Vector3, radius: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "RockCollision"
    body.collision_layer = WALKABLE_LAYER
    body.collision_mask = 0
    body.position = center
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.0
    collision.shape = shape
    collision.scale = radius
    body.add_child(collision)
    parent.add_child(body)

func _walkable_wood(parent: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
    var body := StaticBody3D.new()
    body.name = "WoodCollision"
    body.collision_layer = WALKABLE_LAYER
    body.collision_mask = 0
    body.position = (a + b) * 0.5
    body.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = radius
    shape.height = a.distance_to(b)
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)

func _raycast_foot_height(point: Vector3) -> float:
    var space := get_world_3d().direct_space_state
    var ray := PhysicsRayQueryParameters3D.create(
        point + Vector3.UP * 0.42,
        point + Vector3.DOWN * 0.95,
        WALKABLE_LAYER
    )
    ray.collide_with_areas = false
    var hit := space.intersect_ray(ray)
    if not hit.is_empty():
        foot_contact_hits += 1
        return (hit["position"] as Vector3).y
    return -0.45

func _create_mantis() -> void:
    # Procedural, anatomically inspired placeholder. Not a scanned/photorealistic asset.
    animal = Node3D.new()
    animal.name = "Mantis_01"
    animal.position = Vector3(0, -0.38, 0)
    add_child(animal)
    var green := Color(0.28, 0.52, 0.18)
    var dark_green := Color(0.19, 0.39, 0.12)
    abdomen = Node3D.new()
    abdomen.name = "AbdomenPivot"
    animal.add_child(abdomen)
    _part(abdomen, Vector3(0, 0.18, 0.13), Vector3(0.105, 0.10, 0.35), green)
    _part(abdomen, Vector3(0, 0.20, 0.13), Vector3(0.095, 0.05, 0.29), Color(0.38, 0.61, 0.20))
    thorax_pivot = Node3D.new()
    thorax_pivot.name = "ThoraxArticulation"
    thorax_pivot.position = Vector3(0, 0.25, -0.35)
    animal.add_child(thorax_pivot)
    _part(thorax_pivot, Vector3.ZERO, Vector3(0.060, 0.065, 0.31), dark_green)
    head_pivot = Node3D.new()
    head_pivot.name = "HeadPivot"
    head_pivot.position = Vector3(0, 0.29, -0.67)
    animal.add_child(head_pivot)
    _part(head_pivot, Vector3.ZERO, Vector3(0.16, 0.10, 0.105), green)
    # Anatomical silhouette details: triangular clypeus and articulated thorax plates.
    _part(head_pivot, Vector3(0, -0.055, -0.06), Vector3(0.068, 0.030, 0.060), dark_green)
    for plate in range(4):
        _part(thorax_pivot, Vector3(0, 0.03, -0.16 + float(plate) * 0.10), Vector3(0.066, 0.014, 0.030), green.darkened(float(plate) * 0.055))
    # Stylized procedural microdetails; a high-resolution scanned asset is
    # still needed to achieve genuinely photorealistic insect anatomy.
    for band in range(6):
        var z_band := -0.01 + float(band) * 0.052
        _part(abdomen, Vector3(0, 0.183, z_band), Vector3(0.107, 0.012, 0.007), Color(0.16, 0.33, 0.10))
    for side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(side * 0.115, 0.03, -0.055), Vector3(0.052, 0.060, 0.051), Color(0.035, 0.075, 0.045))
        # Faceted glints suggest compound-eye texture at close camera range.
        for facet in range(8):
            var phi := float(facet) * TAU / 8.0
            _part(head_pivot, Vector3(side * (0.140 + 0.006 * cos(phi)), 0.03 + 0.035 * sin(phi), -0.055 + 0.033 * cos(phi)), Vector3(0.004, 0.004, 0.004), Color(0.12, 0.20, 0.11))
        for i in range(3):
            var z := 0.12 - float(i) * 0.21
            var joint := Node3D.new()
            joint.name = "WalkingLeg_%d_%d" % [int(side), i]
            joint.position = Vector3(side * 0.08, 0.16, z)
            animal.add_child(joint)
            var upper := _make_gait_bone(joint, 0.014, green)
            var lower := _make_gait_bone(joint, 0.010, dark_green)
            leg_pivots.append(joint)
            gait_segments.append([upper, lower])
            gait_feet.append(Vector3(side * 0.33, -0.48, 0.09))
            step_targets.append(Vector3(side * 0.33, -0.48, 0.09))
            var toe := _make_gait_bone(joint, 0.006, dark_green)
            toe.name = "Tarsus_%d_%d" % [int(side), i]
            foot_toes.append(toe)
        var foreleg := Node3D.new()
        foreleg.name = "RaptorialForeleg_%d" % int(side)
        foreleg.position = Vector3(side * 0.055, 0.27, -0.51)
        animal.add_child(foreleg)
        # Shoulder, elbow and tibial claw are independent joints, not one rigid limb.
        var elbow := Node3D.new()
        elbow.name = "ForelegElbow_%d" % int(side)
        elbow.position = Vector3(side * 0.19, 0.15, -0.11)
        foreleg.add_child(elbow)
        _segment(foreleg, Vector3.ZERO, elbow.position, 0.025, green)
        var claw := Node3D.new()
        claw.name = "ForelegTibia_%d" % int(side)
        claw.position = Vector3(0, -0.21, -0.16)
        elbow.add_child(claw)
        _segment(elbow, Vector3.ZERO, claw.position, 0.030, dark_green)
        _segment(claw, Vector3.ZERO, Vector3(0, -0.12, -0.08), 0.012, green)
        for j in range(5):
            var t := float(j) / 5.0
            _segment(elbow, Vector3(0, -0.19 + t * 0.17, -0.16 + t * 0.13), Vector3(side * 0.025, -0.22 + t * 0.17, -0.18 + t * 0.13), 0.006, Color(0.47, 0.55, 0.20))
        forelegs.append(foreleg)
        foreleg_elbows.append(elbow)
        foreleg_claws.append(claw)
        var feeler := Node3D.new()
        feeler.name = "Antenna_%d" % int(side)
        feeler.position = Vector3(side * 0.06, 0.055, -0.08)
        head_pivot.add_child(feeler)
        _segment(feeler, Vector3.ZERO, Vector3(side * 0.11, 0.19, -0.32), 0.004, Color(0.38, 0.37, 0.17))
        antennae.append(feeler)


    # Independent abdominal sternite ridges, narrow tapered terminal segment,
    # and a small pronotal collar help the placeholder read as an insect.
    for ring in range(5):
        var z_ring := 0.045 + float(ring) * 0.056
        var taper := 1.0 - float(ring) * 0.085
        _part(abdomen, Vector3(0, 0.127, z_ring), Vector3(0.086 * taper, 0.009, 0.012), dark_green)
    _part(abdomen, Vector3(0, 0.17, 0.325), Vector3(0.05, 0.047, 0.065), dark_green)
    _part(thorax_pivot, Vector3(0, 0.035, -0.13), Vector3(0.079, 0.022, 0.065), green)
    _enhance_mantis_model()

# Maps are generated from the source color textures; they are an affordable
# material-detail approximation, not measured photogrammetric PBR data.

# Twenty lightweight, named anatomical modeling passes. These meshes are
# stylized procedural geometry, not a scanned specimen or skinned GLB rig.
func _enhance_mantis_model() -> void:
    var olive := Color(0.24, 0.43, 0.15)
    var pale := Color(0.53, 0.66, 0.29)
    var dark := Color(0.13, 0.25, 0.10)
    var wing := Color(0.34, 0.55, 0.22, 0.93)
    # 01 Pronotum dorsal keel
    _segment(thorax_pivot, Vector3(0, 0.067, 0.13), Vector3(0, 0.069, -0.25), 0.008, pale)
    # 02 Pronotum left and right lateral ridges
    for side in [-1.0, 1.0]:
        _segment(thorax_pivot, Vector3(side * 0.051, 0.022, 0.10), Vector3(side * 0.047, 0.023, -0.25), 0.007, olive)
    # 03 Pronotum anterior collar
    _part(thorax_pivot, Vector3(0, 0.018, -0.285), Vector3(0.073, 0.038, 0.024), pale)
    # 04 Cervical neck connector, parented to head
    _part(head_pivot, Vector3(0, -0.015, 0.091), Vector3(0.049, 0.038, 0.055), dark)
    # 05 Triangular frontal shield
    _part(head_pivot, Vector3(0, 0.015, -0.098), Vector3(0.075, 0.052, 0.024), olive)
    # 06 Median simple eye (ocellus)
    _part(head_pivot, Vector3(0, 0.075, -0.082), Vector3(0.013, 0.011, 0.011), dark)
    # 07 Paired lateral ocelli
    for side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(side * 0.032, 0.072, -0.080), Vector3(0.010, 0.009, 0.010), dark)
    # 08 Clypeal transverse suture
    _segment(head_pivot, Vector3(-0.051, -0.043, -0.105), Vector3(0.051, -0.043, -0.105), 0.004, pale)
    # 09 Labrum upper mouth flap
    _part(head_pivot, Vector3(0, -0.086, -0.092), Vector3(0.035, 0.016, 0.025), olive)
    # 10 Paired mandible lobes
    for side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(side * 0.027, -0.090, -0.081), Vector3(0.016, 0.025, 0.021), dark)
    # 11 Paired maxillary palps
    for side in [-1.0, 1.0]:
        _segment(head_pivot, Vector3(side * 0.043, -0.078, -0.08), Vector3(side * 0.060, -0.11, -0.12), 0.004, pale)
    # 12 Antennal basal sockets
    for side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(side * 0.06, 0.055, -0.08), Vector3(0.017, 0.014, 0.016), dark)
    # 13 Antennal terminal tips; attached to existing animated feelers
    for i in range(antennae.size()):
        var side := -1.0 if i == 0 else 1.0
        _part(antennae[i], Vector3(side * 0.11, 0.19, -0.32), Vector3(0.006, 0.008, 0.012), pale)
    # 14 Dorsal tegmina: stylized wing cases, attached to abdomen
    for side in [-1.0, 1.0]:
        _part(abdomen, Vector3(side * 0.052, 0.248, 0.145), Vector3(0.044, 0.012, 0.207), wing)
    # 15 Longitudinal wing veins
    for side in [-1.0, 1.0]:
        _segment(abdomen, Vector3(side * 0.051, 0.261, -0.052), Vector3(side * 0.051, 0.261, 0.335), 0.0035, pale)
    # 16 Oblique wing cross-veins
    for side in [-1.0, 1.0]:
        for j in range(4):
            var z := -0.015 + float(j) * 0.085
            _segment(abdomen, Vector3(side * 0.025, 0.261, z), Vector3(side * 0.081, 0.258, z + 0.043), 0.0025, olive)
    # 17 Abdominal lateral spiracles
    for side in [-1.0, 1.0]:
        for j in range(5):
            _part(abdomen, Vector3(side * 0.100, 0.160, 0.005 + float(j) * 0.061), Vector3(0.006, 0.008, 0.012), dark)
    # 18 Lateral abdominal pleural plates
    for side in [-1.0, 1.0]:
        for j in range(4):
            _part(abdomen, Vector3(side * 0.087, 0.164, 0.037 + float(j) * 0.075), Vector3(0.009, 0.027, 0.026), olive)
    # 19 Paired terminal cerci
    for side in [-1.0, 1.0]:
        _segment(abdomen, Vector3(side * 0.024, 0.160, 0.340), Vector3(side * 0.053, 0.147, 0.425), 0.006, dark)
    # 20 Raptorial femur gripping spines; these follow elbow animation
    for i in range(foreleg_elbows.size()):
        var side := -1.0 if i == 0 else 1.0
        for j in range(7):
            var t := float(j) / 7.0
            var origin := Vector3(0, -0.025 - t * 0.16, -0.026 - t * 0.12)
            _segment(foreleg_elbows[i], origin, origin + Vector3(side * 0.028, -0.013, -0.012), 0.0035, pale)

func _apply_pbr(mat: StandardMaterial3D, kind: String) -> void:
    if pbr_normal.has(kind):
        mat.normal_enabled = true
        mat.normal_texture = pbr_normal[kind]
        mat.normal_scale = 0.55 if kind == "mantis_eye" else 0.9
    if pbr_roughness.has(kind):
        mat.roughness_texture = pbr_roughness[kind]
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if kind == "mantis_eye":
        mat.metallic = 0.02
        mat.roughness = 0.25
    elif kind == "mantis_cuticle":
        mat.metallic = 0.04
        mat.roughness = 0.47

func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 20
    mesh.rings = 12
    var item := MeshInstance3D.new()
    item.mesh = mesh
    item.position = pos
    item.scale = size
    var mat := _material(color)
    if eye_texture != null and color.r < 0.1 and color.g < 0.15:
        mat.albedo_texture = eye_texture
        mat.albedo_color = Color.WHITE
        _apply_pbr(mat, "mantis_eye")
    elif body_texture != null and color.g > color.r * 1.15:
        mat.albedo_texture = body_texture
        mat.albedo_color = Color(0.85, 1.0, 0.83)
        _apply_pbr(mat, "mantis_cuticle")
    item.material_override = mat
    parent.add_child(item)

func _animal_ellipsoid(pos: Vector3, scale_value: Vector3, color: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 16
    mesh.rings = 8
    var item := MeshInstance3D.new()
    item.mesh = mesh
    item.position = pos
    item.scale = scale_value
    item.material_override = _material(color)
    animal.add_child(item)

func _ellipsoid(pos: Vector3, scale_value: Vector3, color: Color) -> void:
    var item := MeshInstance3D.new()
    item.mesh = SphereMesh.new()
    item.position = pos
    item.scale = scale_value
    item.material_override = _material(color)
    add_child(item)

func _segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
    var item := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.15
    mesh.height = a.distance_to(b)
    item.mesh = mesh
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    var mat := _material(color)
    if bark_texture != null and color.r > color.g and color.g > color.b:
        mat.albedo_texture = bark_texture
        _apply_pbr(mat, "bark")
    item.material_override = mat
    parent.add_child(item)

func _branch(a: Vector3, b: Vector3, radius: float) -> void:
    _segment(self, a, b, radius, Color(0.32, 0.21, 0.12))

func _box(size: Vector3, pos: Vector3, color: Color, transparent := false) -> void:
    var item := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    item.mesh = mesh
    item.position = pos
    var mat := _material(color)
    if not transparent and pos.y < -0.6 and substrate_texture != null:
        mat.albedo_texture = substrate_texture
        _apply_pbr(mat, "substrate")
    if transparent:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.roughness = 0.08
    item.material_override = mat
    add_child(item)

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.68
    return mat

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    root_ui = Control.new()
    root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root_ui)
    var toggle := Button.new()
    toggle.text = "☰ 관리 메뉴"
    toggle.position = Vector2(16, 16)
    toggle.custom_minimum_size = Vector2(160, 52)
    toggle.pressed.connect(func(): stats_visible = not stats_visible; ui_panel.visible = stats_visible)
    root_ui.add_child(toggle)
    ui_panel = PanelContainer.new()
    ui_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    ui_panel.position = Vector2(16, 74)
    ui_panel.custom_minimum_size = Vector2(280, 0)
    root_ui.add_child(ui_panel)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(300, 0)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ui_panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(column)
    get_viewport().size_changed.connect(_resize_ui)
    call_deferred("_resize_ui")
    var title := Label.new()
    title.text = "LIVING TERRARIUM 3D"
    column.add_child(title)
    status = Label.new()
    column.add_child(status)
    _button(column, "먹이 추가", func(): _add_food())
    _button(column, "바람 켜기/끄기", func(): wind_enabled = not wind_enabled; notice.text = "바람: " + ("켜짐" if wind_enabled else "꺼짐"))
    _button(column, "생태계 상호작용 켜기/끄기", func(): habitat_interactions.active = not habitat_interactions.active; notice.text = "생태계 상호작용: " + ("켜짐" if habitat_interactions.active else "꺼짐"))
    _button(column, "생태계 활동 기록", func(): notice.text = habitat_interactions.summary())
    _button(column, "바람 세기 변경", func(): wind_strength = fmod(wind_strength + 0.25, 1.26); notice.text = "바람 세기: %.2f" % wind_strength)
    animation_label = Label.new()
    animation_label.text = "애니메이션: AUTO"
    column.add_child(animation_label)
    _button(column, "3D 모델 전환 (GLB / 기본)", func(): _toggle_visual_model())
    _button(column, "자동 행동 애니메이션", func(): _set_animation_preview("AUTO"))
    for clip in ANIMATIONS:
        var selected_clip: String = clip
        _button(column, "동작 시연: " + selected_clip, func(): _set_animation_preview(selected_clip))
    _button(column, "관찰 기록", func(): notice.text = "성장 %.0f%% / 탈피 %d회 / 경과 %.0f초" % [growth * 100.0, molt_count, life_age])
    _button(column, "온도 +1°C", func(): temperature = minf(38.0, temperature + 1.0); _refresh())
    _button(column, "온도 -1°C", func(): temperature = maxf(15.0, temperature - 1.0); _refresh())
    _button(column, "분무 +10%", func(): humidity = minf(100.0, humidity + 10.0); _refresh())
    _button(column, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(column, "발 접지 켜기/끄기", func(): foot_contacts_enabled = not foot_contacts_enabled; notice.text = "발 접지: " + ("켜짐" if foot_contacts_enabled else "꺼짐"))
    _button(column, "개체 추적 켜기/끄기", func(): follow_animal = not follow_animal; _update_camera())
    _button(column, "돌 배치 모드", func(): _set_edit_mode("rock"))
    _button(column, "유목 배치 모드", func(): _set_edit_mode("wood"))
    _button(column, "장식 지우기 모드", func(): _set_edit_mode("erase"))
    _button(column, "편집 종료", func(): editing = false; edit_hint.text = "관찰 모드")
    _button(column, "UI 숨김/표시", func(): stats_visible = not stats_visible; ui_panel.visible = stats_visible)
    _button(column, "저장", func(): _save_state())
    _button(column, "불러오기", func(): _load_state(true))
    edit_hint = Label.new()
    edit_hint.text = "관찰 모드"
    column.add_child(edit_hint)
    notice = Label.new()
    notice.text = "드래그: 회전 | 휠·두 손가락: 확대"
    column.add_child(notice)

func _resize_ui() -> void:
    if ui_panel == null:
        return
    var screen := get_viewport().get_visible_rect().size
    ui_panel.position = Vector2(16, 74)
    ui_panel.size = Vector2(minf(320.0, screen.x * 0.68), maxf(100.0, screen.y - 94.0))


# Reusable simple leaf mesh: six triangles with a raised midrib and pointed tip.
func _leaf_mesh() -> ArrayMesh:
    # Curved double-sided blade, with per-vertex pigment gradient and a raised midrib.
    # Vertex colors are used by the foliage material; no extra texture fetch is needed.
    var vertices := PackedVector3Array()
    var colors := PackedColorArray()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var outline := [
        Vector3(0.0, 0.0, 0.0),
        Vector3(-0.105, 0.014, 0.105),
        Vector3(-0.115, 0.009, 0.19),
        Vector3(-0.068, 0.004, 0.285),
        Vector3(0.0, 0.0, 0.39),
        Vector3(0.068, 0.004, 0.285),
        Vector3(0.115, 0.009, 0.19),
        Vector3(0.105, 0.014, 0.105)
    ]
    var middle := Vector3(0, 0.034, 0.19)
    for i in range(outline.size()):
        var a: Vector3 = outline[i]
        var b: Vector3 = outline[(i + 1) % outline.size()]
        for vertex in [middle, a, b]:
            vertices.append(vertex)
            var vein := 1.0 if vertex == middle else 0.0
            colors.append(Color(0.74 + vein * 0.24, 0.86 + vein * 0.14, 0.65 + vein * 0.18))
            uv.append(Vector2(vertex.x * 3.0 + 0.5, vertex.z * 2.5))
            normals.append(Vector3.UP)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uv
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _create_animated_ecosystem() -> void:
    habitat_motion_root = Node3D.new()
    habitat_motion_root.name = "AnimatedEcosystem"
    add_child(habitat_motion_root)
    var rng := RandomNumberGenerator.new()
    rng.seed = 17012026
    var leaf_mesh := _leaf_mesh()
    var leaf_materials: Array[StandardMaterial3D] = []
    for tint in [Color(0.20, 0.42, 0.14), Color(0.34, 0.50, 0.18), Color(0.45, 0.32, 0.13)]:
        var mat := _material(tint)
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 0.86
        leaf_materials.append(mat)
    var stem_material := _material(Color(0.21, 0.31, 0.12))
    # 24 small plants, each with a flexible stem and 2-4 animated leaves.
    for i in range(24):
        var plant := Node3D.new()
        plant.name = "Plant_%02d" % i
        plant.position = Vector3(rng.randf_range(-1.40, 1.40), -0.53, rng.randf_range(-0.97, 0.97))
        habitat_motion_root.add_child(plant)
        var height := rng.randf_range(0.14, 0.37)
        var stem := MeshInstance3D.new()
        var stem_mesh := CylinderMesh.new()
        stem_mesh.top_radius = 0.005
        stem_mesh.bottom_radius = 0.013
        stem_mesh.height = height
        stem_mesh.radial_segments = 5
        stem.mesh = stem_mesh
        stem.material_override = stem_material
        stem.position.y = height * 0.5
        plant.add_child(stem)
        var leaf_count := rng.randi_range(2, 4)
        for j in range(leaf_count):
            var leaf_joint := Node3D.new()
            leaf_joint.position.y = height * (0.5 + 0.45 * float(j) / float(leaf_count))
            leaf_joint.rotation.y = float(j) * TAU / float(leaf_count) + rng.randf_range(-0.3, 0.3)
            plant.add_child(leaf_joint)
            var leaf := MeshInstance3D.new()
            leaf.mesh = leaf_mesh
            leaf.material_override = leaf_materials[(i + j) % leaf_materials.size()]
            leaf.scale = Vector3.ONE * rng.randf_range(0.45, 0.85)
            leaf.rotation.x = -0.22 - 0.07 * float(j % 2)
            leaf.rotation.z = rng.randf_range(-0.16, 0.16)
            leaf_joint.add_child(leaf)
            plant_pivots.append(leaf_joint)
            plant_phases.append(rng.randf_range(0.0, TAU))
            plant_stiffness.append(rng.randf_range(0.6, 1.35))
        plant_pivots.append(plant)
        plant_phases.append(rng.randf_range(0.0, TAU))
        plant_stiffness.append(rng.randf_range(0.35, 0.8))
    # 14 ambient floating motes; no transparency sorting or expensive particles.
    var mote_mesh := SphereMesh.new()
    mote_mesh.radial_segments = 5
    mote_mesh.rings = 3
    var mote_mat := _material(Color(0.68, 0.67, 0.44))
    mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for i in range(14):
        var mote := Node3D.new()
        var visual := MeshInstance3D.new()
        visual.mesh = mote_mesh
        visual.scale = Vector3.ONE * rng.randf_range(0.003, 0.008)
        visual.material_override = mote_mat
        mote.add_child(visual)
        mote.position = Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.3, 0.65), rng.randf_range(-1.0, 1.0))
        habitat_motion_root.add_child(mote)
        drifting_particles.append(mote)
        particle_origins.append(mote.position)

func _animate_ecosystem(dt: float) -> void:
    ecosystem_clock += dt
    var wind := wind_strength if wind_enabled else 0.0
    for i in range(plant_pivots.size()):
        var joint := plant_pivots[i]
        var wave := sin(ecosystem_clock * 1.7 + plant_phases[i])
        var gust := sin(ecosystem_clock * 0.43 + plant_phases[i] * 0.3)
        var contact_offset := habitat_interactions.leaf_displacement(joint) if habitat_interactions != null else 0.0
        joint.rotation.z = (wave * 0.12 + gust * 0.09) * wind * plant_stiffness[i] + contact_offset
        var humidity_droop := clampf((55.0 - humidity) / 90.0, 0.0, 0.22)
        joint.rotation.x = sin(ecosystem_clock * 1.2 + plant_phases[i]) * wind * 0.07 + humidity_droop * plant_stiffness[i]
    for i in range(drifting_particles.size()):
        var mote := drifting_particles[i]
        var origin := particle_origins[i]
        var phase := ecosystem_clock * 0.45 + float(i) * 1.37
        mote.position = origin + Vector3(sin(phase) * 0.14 * wind, sin(phase * 0.63) * 0.07, cos(phase * 0.7) * 0.09 * wind)

func _create_prey_appendages(prey: Node3D) -> void:
    var appendages: Array[Node3D] = []
    for side in [-1.0, 1.0]:
        for i in range(3):
            var joint := Node3D.new()
            joint.position = Vector3(side * 0.035, -0.005, (float(i) - 1.0) * 0.045)
            prey.add_child(joint)
            _segment(joint, Vector3.ZERO, Vector3(side * 0.075, -0.03, 0.035), 0.005, Color(0.22, 0.13, 0.07))
            appendages.append(joint)
    for side in [-1.0, 1.0]:
        var antenna := Node3D.new()
        antenna.position = Vector3(side * 0.025, 0.025, -0.07)
        prey.add_child(antenna)
        _segment(antenna, Vector3.ZERO, Vector3(side * 0.025, 0.05, -0.10), 0.003, Color(0.23, 0.14, 0.08))
        appendages.append(antenna)
    # Segmented dorsal plates and paired wing covers follow the prey's transform.
    var shell := _material(Color(0.31, 0.19, 0.09))
    shell.roughness = 0.48
    for segment_index in range(3):
        var plate := MeshInstance3D.new()
        var plate_mesh := SphereMesh.new()
        plate_mesh.radial_segments = 8
        plate_mesh.rings = 5
        plate.mesh = plate_mesh
        plate.material_override = shell
        plate.scale = Vector3(0.042, 0.012, 0.025)
        plate.position = Vector3(0, 0.028, -0.012 + float(segment_index) * 0.034)
        prey.add_child(plate)
    for side in [-1.0, 1.0]:
        var wing := MeshInstance3D.new()
        var wing_mesh := SphereMesh.new()
        wing_mesh.radial_segments = 8
        wing_mesh.rings = 5
        wing.mesh = wing_mesh
        wing.scale = Vector3(0.025, 0.006, 0.075)
        wing.position = Vector3(side * 0.023, 0.032, 0.015)
        wing.material_override = _material(Color(0.38, 0.25, 0.11))
        prey.add_child(wing)
    prey_appendages[prey.get_instance_id()] = appendages

func _animate_prey_appendages(prey: Node3D, velocity: Vector3) -> void:
    var appendages: Array = prey_appendages.get(prey.get_instance_id(), [])
    var speed := clampf(velocity.length() * 5.0, 0.0, 1.0)
    for i in range(appendages.size()):
        var joint: Node3D = appendages[i]
        if i < 6:
            joint.rotation.z = sin(prey_motion_clock * 20.0 + float(i % 3) * 1.8 + (PI if i >= 3 else 0.0)) * speed * 0.42
        else:
            joint.rotation.y = sin(prey_motion_clock * 3.0 + float(i)) * 0.20

func _create_habitat_details() -> void:
    # Frame edges give the enclosure readable depth without layered transparency.
    var frame_color := Color(0.14, 0.18, 0.16)
    for x in [-1.57, 1.57]:
        for z in [-1.09, 1.09]:
            _segment(self, Vector3(x, -0.53, z), Vector3(x, 0.72, z), 0.011, frame_color)
    for y in [-0.53, 0.72]:
        for z in [-1.09, 1.09]:
            _segment(self, Vector3(-1.57, y, z), Vector3(1.57, y, z), 0.011, frame_color)
        for x in [-1.57, 1.57]:
            _segment(self, Vector3(x, y, -1.09), Vector3(x, y, 1.09), 0.011, frame_color)
    # Low-cost substrate details; avoids expensive transparent foliage layers.
    var root := Node3D.new()
    root.name = "SubstrateDetails"
    add_child(root)
    var rng := RandomNumberGenerator.new()
    rng.seed = 240619
    var stone_mat := _material(Color(0.25, 0.23, 0.18))
    stone_mat.albedo_texture = stone_texture
    _apply_pbr(stone_mat, "stone")
    var leaf_mat := _material(Color(0.28, 0.22, 0.10))
    leaf_mat.albedo_texture = substrate_texture
    _apply_pbr(leaf_mat, "substrate")
    var stone_mesh := SphereMesh.new()
    stone_mesh.radial_segments = 8
    stone_mesh.rings = 4
    var leaf_mesh := SphereMesh.new()
    leaf_mesh.radial_segments = 6
    leaf_mesh.rings = 3
    for i in range(85):
        var item := MeshInstance3D.new()
        item.mesh = stone_mesh if i % 4 == 0 else leaf_mesh
        item.material_override = stone_mat if i % 4 == 0 else leaf_mat
        item.position = Vector3(rng.randf_range(-1.48, 1.48), -0.535, rng.randf_range(-1.02, 1.02))
        item.scale = Vector3(0.025, 0.009, 0.033) if i % 4 == 0 else Vector3(0.052, 0.006, 0.023)
        item.rotation.y = rng.randf_range(-PI, PI)
        root.add_child(item)

func _button(parent: VBoxContainer, label_text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(260, 48)
    button.pressed.connect(callback)
    parent.add_child(button)

func _process(delta: float) -> void:
    if rigged_player != null and use_rigged_visual and rigged_available:
        rigged_player.speed_scale = 0.0 if simulation_paused else 1.0
    if simulation_paused:
        return
    var dt := minf(delta, 0.1)
    elapsed += dt
    _animate_ecosystem(dt)
    if habitat_interactions != null:
        habitat_interactions.simulate(dt)
    animation_clock += dt
    preview_strike_clock = maxf(0.0, preview_strike_clock - dt)
    autosave_timer += dt
    if autosave_timer >= 60.0:
        autosave_timer = 0.0
        _save_state(false)
    if strike_time > 0.0:
        strike_time = maxf(0.0, strike_time - dt)
    life_age += dt
    prey_motion_clock += dt
    _move_prey(dt)
    climb_cooldown = maxf(0.0, climb_cooldown - dt)
    target_prey = _nearest_prey()
    if molting:
        molt_progress += dt
        behavior = "탈피 중"
        if molt_progress >= 12.0:
            molting = false
            molt_progress = 0.0
            molt_count += 1
            growth = minf(1.0, growth + 0.13)
            animal.scale = Vector3.ONE * (0.80 + growth * 0.30)
            hunger = minf(100.0, hunger + 12.0)
            energy = maxf(15.0, energy - 22.0)
    elif life_age > 150.0 * float(molt_count + 1) and molt_count < 5 and hunger < 65.0 and stress < 40.0:
        molting = true
        molt_progress = 0.0
    hunger = minf(100.0, hunger + dt * 0.22)
    humidity = maxf(0.0, humidity - dt * 0.018)
    stress = clampf(stress + (dt * 0.75 if temperature < 21.0 or temperature > 31.0 or humidity < 40.0 else -dt * 0.15), 0.0, 100.0)
    if molting:
        pass
    elif climb_active:
        _advance_climb(dt)
    elif stress > 65.0:
        behavior = "은신 / 경계"
        energy = minf(100.0, energy + dt * 0.5)
    elif hunger > 45.0 and food_count > 0:
        behavior = "먹이 추적"
        if target_prey != null:
            var target := target_prey.position
            var direction := target - animal.position
            if direction.length() > 0.01:
                animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), dt * 3.0)
            animal.position = animal.position.move_toward(target, dt * 0.18)
            animal.position.x = clampf(animal.position.x, -1.10, 1.10)
            animal.position.z = clampf(animal.position.z, -0.70, 0.70)
            if animal.position.distance_to(target) < 0.18:
                strike_time = 0.45
                if habitat_interactions != null:
                    habitat_interactions.unregister_prey(target_prey)
                prey_appendages.erase(target_prey.get_instance_id())
                prey_velocities.erase(target_prey.get_instance_id())
                prey_nodes.erase(target_prey)
                target_prey.queue_free()
                target_prey = null
                food_count = prey_nodes.size()
                hunger = maxf(0.0, hunger - 35.0)
                energy = maxf(0.0, energy - 2.0)
    elif energy < 35.0:
        behavior = "휴식"
        energy = minf(100.0, energy + dt * 2.0)
    elif hunger > 55.0:
        behavior = "먹이 탐색"
        _roam(dt)
    else:
        behavior = "환경 탐색"
        if climb_cooldown <= 0.0:
            _advance_climb(dt)
        else:
            _roam(dt)
    _animate_mantis(dt)
    _update_rigged_visual(dt)
    if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
        _refresh()
    if follow_animal:
        _update_camera()

func _roam(dt: float) -> void:
    roam_time -= dt
    if roam_time <= 0.0 or animal.position.distance_to(roam_target) < 0.12:
        roam_time = randf_range(2.0, 5.0)
        roam_target = Vector3(randf_range(-1.05, 1.05), -0.38, randf_range(-0.7, 0.7))
    var direction := roam_target - animal.position
    if direction.length() > 0.03:
        animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), dt * 3.0)
        animal.position = animal.position.move_toward(roam_target, dt * 0.085)
        animal.position.x = clampf(animal.position.x, -1.10, 1.10)
        animal.position.z = clampf(animal.position.z, -0.70, 0.70)
        energy = maxf(0.0, energy - dt * 0.3)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            orbit_distance = maxf(2.2, orbit_distance - 0.3)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            orbit_distance = minf(8.0, orbit_distance + 0.3)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if editing:
                if event.pressed:
                    edit_mouse_start = event.position
                    edit_mouse_moved = false
                elif not edit_mouse_moved and edit_mouse_start.distance_to(event.position) < 16.0:
                    _place_at_screen(event.position)
            touching = event.pressed and not editing
            pointer_last = event.position
    elif event is InputEventMouseMotion:
        if editing and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            if edit_mouse_start.distance_to(event.position) > 16.0:
                edit_mouse_moved = true
        elif touching:
            _orbit(event.relative)
    elif event is InputEventScreenTouch:
        if editing and not event.pressed and touch_points.size() <= 1 and not edit_touch_moved and edit_touch_start.distance_to(event.position) < 20.0:
            _place_at_screen(event.position)
        if event.pressed:
            if touch_points.is_empty():
                edit_touch_start = event.position
                edit_touch_moved = false
            touch_points[event.index] = event.position
        else:
            touch_points.erase(event.index)
        pinch_previous = 0.0
    elif event is InputEventScreenDrag:
        touch_points[event.index] = event.position
        if editing and (touch_points.size() > 1 or edit_touch_start.distance_to(event.position) > 20.0):
            edit_touch_moved = true
        if touch_points.size() == 1:
            _orbit(event.relative)
        elif touch_points.size() == 2:
            var points := touch_points.values()
            var distance: float = points[0].distance_to(points[1])
            if pinch_previous > 0.0:
                orbit_distance = clampf(orbit_distance - (distance - pinch_previous) * 0.008, 2.2, 8.0)
            pinch_previous = distance
    _update_camera()

func _orbit(motion: Vector2) -> void:
    orbit_yaw -= motion.x * 0.008
    orbit_pitch = clampf(orbit_pitch + motion.y * 0.006, -0.15, 1.05)

func _update_camera() -> void:
    if camera == null:
        return
    var center := animal.position + Vector3(0, 0.35, 0) if follow_animal and animal != null else Vector3(0, 0.0, 0)
    camera.position = center + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
    camera.look_at(center, Vector3.UP)

func _refresh() -> void:
    if status == null:
        return
    status.text = "온도: %.1f°C | 습도: %.1f%%\n배고픔: %.0f | 체력: %.0f\n스트레스: %.0f | 먹이: %d\n탈피: %d회 | 성장: %.0f%%\n행동: %s%s" % [temperature, humidity, hunger, energy, stress, food_count, molt_count, growth * 100.0, behavior, " (정지)" if simulation_paused else ""]

func _save_state(show_message: bool = true) -> void:
    var data := {"version": 6, "decorations": decoration_data, "life_age": life_age, "molt_count": molt_count, "growth": growth, "hunger": hunger, "energy": energy, "stress": stress, "humidity": humidity, "temperature": temperature, "food_count": food_count, "prey_positions": _prey_positions(), "animal_position": [animal.position.x, animal.position.y, animal.position.z]}
    # Keep a last-known-good copy before replacing the main save.
    if FileAccess.file_exists(SAVE_PATH):
        var previous := FileAccess.get_file_as_string(SAVE_PATH)
        var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
        if backup != null:
            backup.store_string(previous)
            backup.close()
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        if show_message:
            notice.text = "저장 실패: 파일을 열 수 없습니다."
        return
    file.store_string(JSON.stringify(data))
    file.close()
    if show_message:
        notice.text = "저장 완료"

func _load_state(show_message: bool) -> void:
    var candidates := [SAVE_PATH, BACKUP_PATH, V5_SAVE_PATH, V4_SAVE_PATH, PREVIOUS_SAVE_PATH, LEGACY_SAVE_PATH]
    var path := ""
    for candidate in candidates:
        if FileAccess.file_exists(candidate):
            var candidate_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
            if candidate_data is Dictionary and int(candidate_data.get("version", 0)) in [2, 3, 4, 5, 6]:
                path = candidate
                break
    if path.is_empty():
        if show_message:
            notice.text = "저장된 데이터가 없습니다."
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        if show_message:
            notice.text = "불러오기 실패"
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary) or int(parsed.get("version", 0)) not in [2, 3, 4, 5, 6]:
        if show_message:
            notice.text = "저장 파일 형식이 맞지 않습니다."
        return
    _clear_decorations()
    var saved_decor: Variant = parsed.get("decorations", [])
    if saved_decor is Array:
        for entry in saved_decor:
            if entry is Dictionary and decorations.size() < MAX_DECORATIONS:
                var kind: String = str(entry.get("kind", "rock"))
                var x: float = clampf(float(entry.get("x", 0.0)), -1.4, 1.4)
                var z: float = clampf(float(entry.get("z", 0.0)), -0.95, 0.95)
                if kind in ["rock", "wood"]:
                    _add_decoration(kind, Vector3(x, -0.50, z))
    life_age = maxf(0.0, float(parsed.get("life_age", 0.0)))
    molt_count = clampi(int(parsed.get("molt_count", 0)), 0, 5)
    growth = clampf(float(parsed.get("growth", 0.35)), 0.35, 1.0)
    animal.scale = Vector3.ONE * (0.80 + growth * 0.30)
    hunger = clampf(float(parsed.get("hunger", 32.0)), 0.0, 100.0)
    energy = clampf(float(parsed.get("energy", 86.0)), 0.0, 100.0)
    stress = clampf(float(parsed.get("stress", 12.0)), 0.0, 100.0)
    humidity = clampf(float(parsed.get("humidity", 70.0)), 0.0, 100.0)
    temperature = clampf(float(parsed.get("temperature", 25.0)), 15.0, 38.0)
    food_count = clampi(int(parsed.get("food_count", 0)), 0, MAX_FOOD)
    for prey in prey_nodes:
        prey.queue_free()
    prey_nodes.clear()
    var positions: Variant = parsed.get("prey_positions", [])
    if positions is Array and positions.size() > 0:
        for coords in positions:
            if coords is Array and coords.size() == 3 and prey_nodes.size() < MAX_FOOD:
                _spawn_prey(Vector3(clampf(float(coords[0]), -1.2, 1.2), -0.38, clampf(float(coords[2]), -0.8, 0.8)))
        food_count = prey_nodes.size()
    else:
        _sync_prey()
    var pos: Variant = parsed.get("animal_position", [])
    if pos is Array and pos.size() == 3:
        animal.position = Vector3(clampf(float(pos[0]), -1.3, 1.3), -0.38, clampf(float(pos[2]), -0.9, 0.9))
    if show_message:
        notice.text = "불러오기 완료" + (" (백업 복구)" if path == BACKUP_PATH else "")
    _refresh()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and animal != null:
        _save_state()

func _add_food() -> void:
    if prey_nodes.size() >= MAX_FOOD:
        notice.text = "먹이는 최대 12개까지 넣을 수 있습니다."
        return
    _spawn_prey(Vector3(randf_range(-1.1, 1.1), -0.38, randf_range(-0.75, 0.75)))
    food_count = prey_nodes.size()
    _refresh()

func _spawn_prey(pos: Vector3) -> void:
    var prey := Node3D.new()
    prey.name = "Prey_%d" % prey_nodes.size()
    prey.position = pos
    add_child(prey)
    var body := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radial_segments = 10
    mesh.rings = 6
    body.mesh = mesh
    body.scale = Vector3(0.065, 0.035, 0.10)
    body.material_override = _material(Color(0.30, 0.18, 0.09))
    prey.add_child(body)
    _create_prey_appendages(prey)
    prey_nodes.append(prey)
    if habitat_interactions != null:
        habitat_interactions.register_prey(prey)
    prey_velocities[prey.get_instance_id()] = Vector3(randf_range(-0.13, 0.13), 0, randf_range(-0.13, 0.13))

func _sync_prey() -> void:
    while prey_nodes.size() < food_count:
        _spawn_prey(Vector3(randf_range(-1.1, 1.1), -0.38, randf_range(-0.75, 0.75)))
    food_count = prey_nodes.size()

func _prey_positions() -> Array:
    var result := []
    for prey in prey_nodes:
        result.append([prey.position.x, prey.position.y, prey.position.z])
    return result

func _make_gait_bone(parent: Node3D, radius: float, tint: Color) -> MeshInstance3D:
    var bone := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 0.85
    mesh.height = 1.0
    bone.mesh = mesh
    bone.material_override = _material(tint)
    parent.add_child(bone)
    return bone

func _pose_gait_bone(bone: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    var direction := b - a
    var distance := direction.length()
    if distance < 0.0001:
        return
    bone.position = (a + b) * 0.5
    bone.quaternion = Quaternion(Vector3.UP, direction / distance)
    bone.scale = Vector3(1.0, distance, 1.0)

func _solve_leg_knee(hip: Vector3, foot: Vector3, upper: float, lower: float, side: float) -> Vector3:
    var delta := foot - hip
    var distance := clampf(delta.length(), 0.001, upper + lower - 0.0001)
    var axis := delta.normalized()
    var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
    var height := sqrt(maxf(0.0, upper * upper - along * along))
    var bend := Vector3(side, 0.0, 0.0)
    bend = (bend - axis * bend.dot(axis)).normalized()
    if bend.length_squared() < 0.001:
        bend = Vector3.FORWARD
    return hip + axis * along + bend * height

# Lightweight surface approximation for the prototype enclosure. This is NOT
# physics raycast IK or branch climbing: it samples known placed decorations.
# Local foot positions are converted into world space to account for rotation.
func _surface_height_at(world_point: Vector3) -> float:
    var height := -0.50
    for i in range(decoration_data.size()):
        var entry: Dictionary = decoration_data[i]
        var center := Vector2(float(entry.get("x", 0.0)), float(entry.get("z", 0.0)))
        var offset := Vector2(world_point.x, world_point.z) - center
        if str(entry.get("kind", "rock")) == "rock":
            var r := (offset.x / 0.16) * (offset.x / 0.16) + (offset.y / 0.12) * (offset.y / 0.12)
            if r < 1.0:
                height = maxf(height, -0.50 + 0.155 * sqrt(1.0 - r))
        else:
            # Wood is a diagonal low cylinder, approximated as a capsule in XZ.
            var t := clampf((offset.x + 0.22) / 0.44, 0.0, 1.0)
            var axis_z := -0.04 + t * 0.08
            var d := absf(offset.y - axis_z)
            if d < 0.055 and absf(offset.x) <= 0.25:
                height = maxf(height, -0.50 + 0.09 + 0.07 * t + sqrt(maxf(0.0, 0.055 * 0.055 - d * d)))
    return height

func _set_animation_preview(clip: String) -> void:
    if clip != "AUTO" and not ANIMATIONS.has(clip):
        return
    animation_preview = clip
    animation_clock = 0.0
    if clip == "STRIKE":
        preview_strike_clock = 0.65
        if rigged_player != null and rigged_clip == "STRIKE" and use_rigged_visual:
            rigged_player.seek(0.0, true)
    if animation_label != null:
        animation_label.text = "애니메이션: " + clip

func _resolve_animation() -> String:
    if molting:
        return "MOLT"
    if animation_preview != "AUTO":
        return animation_preview
    if strike_time > 0.0:
        return "STRIKE"
    if hunger < 25.0 and fmod(elapsed, 27.0) < 1.5:
        return "FEED"
    if climb_active or behavior.contains("등반"):
        return "CLIMB"
    if behavior.contains("추적"):
        return "HUNT"
    if behavior.contains("경계"):
        return "ALERT"
    if behavior.contains("탐색"):
        if fmod(elapsed, 19.0) < 2.2:
            return "SCAN"
        return "WALK"
    if energy > 65.0 and fmod(elapsed, 23.0) < 3.0:
        return "GROOM"
    return "IDLE"


func _initialize_foot_anchors() -> void:
    foot_anchors.clear()
    foot_in_swing.clear()
    foot_swing_origins.clear()
    foot_swing_progress.clear()
    for i in range(leg_pivots.size()):
        var side := -1.0 if i < 3 else 1.0
        var world := leg_pivots[i].to_global(Vector3(side * 0.33, -0.31, 0.28 - float(i % 3) * 0.24))
        world.y = _raycast_foot_height(world)
        foot_anchors.append(world)
        foot_swing_origins.append(world)
        foot_in_swing.append(false)
        foot_swing_progress.append(0.0)

func _animate_mantis(dt: float) -> void:
    var next_state := _resolve_animation()
    if next_state != animation_state:
        animation_state = next_state
        animation_weight = 0.0
    animation_weight = move_toward(animation_weight, 1.0, dt * 5.0)
    var walking := next_state in ["WALK", "HUNT", "CLIMB"]
    movement_blend = move_toward(movement_blend, 1.0 if walking else 0.0, dt * 3.0)
    walking_phase += dt * (3.2 if next_state == "CLIMB" else 5.5 if next_state == "HUNT" else 7.0)
    foot_contact_hits = 0
    # World-space stance locking prevents the feet from sliding with the body.
    # Tripod groups alternate their swing intervals; raycasts find the next
    # reachable surface height on rocks, wood, and substrate.
    for i in range(leg_pivots.size()):
        var joint := leg_pivots[i]
        var side := -1.0 if i < 3 else 1.0
        var index := i % 3
        var tripod := (index + (0 if i < 3 else 1)) % 2
        var phase := fposmod(walking_phase + float(tripod) * PI, TAU)
        var swing_window := phase < PI
        var rest_local := Vector3(side * 0.33, -0.31, 0.28 - float(index) * 0.24)
        var desired_world := joint.to_global(rest_local)
        if next_state != "CLIMB" or not climb_active:
            desired_world.y = _raycast_foot_height(desired_world) if foot_contacts_enabled else -0.45
        if next_state == "CLIMB" and climb_active:
            # Place feet against the inclined branch cylinder rather than the floor.
            var axis := climb_branch_end - climb_branch_start
            var t_axis := clampf((desired_world - climb_branch_start).dot(axis) / axis.length_squared(), 0.0, 1.0)
            var on_axis := climb_branch_start + axis * t_axis
            var outward := desired_world - on_axis
            if outward.length_squared() < 0.0001:
                outward = Vector3.UP
            desired_world = on_axis + outward.normalized() * 0.095
        # The branch is the supporting surface; do not project climb targets
        # back onto the floor before calculating contact.
        var drift := foot_anchors[i].distance_to(desired_world)
        if walking and swing_window and not foot_in_swing[i] and drift > 0.055:
            foot_in_swing[i] = true
            foot_swing_origins[i] = foot_anchors[i]
            foot_swing_progress[i] = 0.0
        var foot_world := foot_anchors[i]
        if foot_in_swing[i]:
            foot_swing_progress[i] = minf(1.0, foot_swing_progress[i] + dt / FOOT_SWING_DURATION)
            var t := foot_swing_progress[i]
            var eased := t * t * (3.0 - 2.0 * t)
            var destination := desired_world
            foot_world = foot_swing_origins[i].lerp(destination, eased)
            foot_world.y += sin(t * PI) * step_height
            if t >= 1.0:
                foot_in_swing[i] = false
                foot_anchors[i] = destination
        else:
            foot_world = foot_anchors[i]
            # Avoid overextending a leg when the body turns abruptly.
            if walking and drift > FOOT_REPLANT_DISTANCE:
                foot_anchors[i] = desired_world
                foot_world = desired_world
        var foot := joint.to_local(foot_world)
        # Clamp unreachable IK targets to the limb's maximum extension.
        var reach := foot.length()
        if reach > 0.795:
            foot = foot / reach * 0.795
        var knee := _solve_leg_knee(Vector3.ZERO, foot, 0.31, 0.49, side)
        _pose_gait_bone(gait_segments[i][0], Vector3.ZERO, knee)
        _pose_gait_bone(gait_segments[i][1], knee, foot)
        _pose_gait_bone(foot_toes[i], foot, foot + Vector3(side * 0.025, -0.012, -0.02))
    var attack_clock := strike_time if animation_preview == "AUTO" else preview_strike_clock
    for i in range(forelegs.size()):
        var target_pitch := 0.0
        var target_yaw := 0.0
        match next_state:
            "IDLE":
                target_pitch = sin(elapsed * 0.8 + float(i)) * 0.045
            "WALK":
                target_pitch = -0.12 + sin(walking_phase + float(i) * PI) * 0.10
            "ALERT":
                target_pitch = -0.48
                target_yaw = (-0.12 if i == 0 else 0.12)
            "GROOM":
                target_pitch = -0.70 + sin(animation_clock * 9.0 + float(i) * 2.1) * 0.25
                target_yaw = (0.16 if i == 0 else -0.16)
            "HUNT":
                target_pitch = -0.55 + sin(elapsed * 2.0) * 0.045
            "STRIKE":
                var progress := 1.0 - clampf(attack_clock / 0.65, 0.0, 1.0)
                target_pitch = -0.35 - sin(progress * PI) * 1.05
                target_yaw = (-0.10 if i == 0 else 0.10)
            "SCAN":
                target_pitch = -0.23 + sin(animation_clock * 1.8 + float(i)) * 0.08
                target_yaw = sin(animation_clock * 1.3) * 0.16
            "FEED":
                target_pitch = -0.62 + sin(animation_clock * 12.0 + float(i) * PI) * 0.16
                target_yaw = (0.18 if i == 0 else -0.18)
            "CLIMB":
                target_pitch = -0.20 + sin(walking_phase + float(i) * PI) * 0.17
            "DEFEND":
                target_pitch = -0.95 + sin(animation_clock * 3.0) * 0.12
                target_yaw = (-0.30 if i == 0 else 0.30)
            "MOLT":
                target_pitch = -0.18 + sin(elapsed * 3.5) * 0.07
        forelegs[i].rotation.x = lerpf(forelegs[i].rotation.x, target_pitch, clampf(dt * 9.0, 0.0, 1.0))
        forelegs[i].rotation.y = lerpf(forelegs[i].rotation.y, target_yaw, clampf(dt * 7.0, 0.0, 1.0))
        var elbow_target := -0.25
        var claw_target := 0.38
        match next_state:
            "GROOM", "FEED":
                elbow_target = -0.65 + sin(animation_clock * 9.0 + float(i) * PI) * 0.28
                claw_target = 0.8 + sin(animation_clock * 9.0 + float(i) * PI) * 0.35
            "HUNT", "ALERT":
                elbow_target = -0.75
                claw_target = 1.1
            "STRIKE":
                var strike_progress := 1.0 - clampf(attack_clock / 0.65, 0.0, 1.0)
                elbow_target = -0.85 + sin(strike_progress * PI) * 1.2
                claw_target = 1.2 - sin(strike_progress * PI) * 1.5
            "DEFEND":
                elbow_target = -1.0
                claw_target = 1.35
            "CLIMB":
                elbow_target = -0.3 + sin(walking_phase + float(i) * PI) * 0.35
        foreleg_elbows[i].rotation.x = lerpf(foreleg_elbows[i].rotation.x, elbow_target, clampf(dt * 11.0, 0.0, 1.0))
        foreleg_claws[i].rotation.x = lerpf(foreleg_claws[i].rotation.x, claw_target, clampf(dt * 13.0, 0.0, 1.0))
    for i in range(antennae.size()):
        var antenna_speed := 5.5 if next_state == "ALERT" else 2.3
        var amplitude := 0.29 if next_state == "ALERT" else 0.16
        antennae[i].rotation.y = sin(elapsed * antenna_speed + float(i) * 1.5) * amplitude
    if head_pivot != null:
        var desired_head_yaw := sin(elapsed * 0.7) * 0.11
        if next_state == "SCAN":
            desired_head_yaw = sin(animation_clock * 1.7) * 0.52
        elif next_state == "GROOM":
            desired_head_yaw = sin(animation_clock * 2.0) * 0.20
        elif next_state == "ALERT":
            desired_head_yaw = sin(animation_clock * 1.8) * 0.32
        elif target_prey != null and is_instance_valid(target_prey):
            var local_target := animal.to_local(target_prey.global_position)
            desired_head_yaw = clampf(atan2(-local_target.x, -local_target.z), -0.60, 0.60)
        head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, desired_head_yaw, clampf(dt * 5.0, 0.0, 1.0))
        head_pivot.rotation.x = lerpf(head_pivot.rotation.x, -0.14 if next_state == "HUNT" else 0.0, clampf(dt * 4.0, 0.0, 1.0))
    if thorax_pivot != null:
        var thorax_target := sin(elapsed * 1.6) * 0.012
        if next_state in ["ALERT", "DEFEND"]:
            thorax_target += 0.11
        elif next_state == "STRIKE":
            thorax_target -= 0.16
        thorax_pivot.rotation.x = lerpf(thorax_pivot.rotation.x, thorax_target, clampf(dt * 5.0, 0.0, 1.0))
    if abdomen != null:
        var abdomen_target := sin(elapsed * 1.3) * 0.018
        if next_state == "ALERT":
            abdomen_target += 0.12
        elif next_state == "MOLT":
            abdomen_target += sin(elapsed * 3.5) * 0.10
        elif next_state == "DEFEND":
            abdomen_target += 0.22
        elif next_state == "FEED":
            abdomen_target += sin(animation_clock * 5.0) * 0.035
        abdomen.rotation.x = lerpf(abdomen.rotation.x, abdomen_target, clampf(dt * 4.0, 0.0, 1.0))
    animal.rotation.z = lerpf(animal.rotation.z, sin(elapsed * 5.0) * 0.05 if molting else 0.0, clampf(dt * 4.0, 0.0, 1.0))
    if animation_preview == "STRIKE" and preview_strike_clock <= 0.0:
        preview_strike_clock = 0.65

# Deterministic target choice: nearest valid prey, not insertion order.
func _nearest_prey() -> Node3D:
    var best: Node3D = null
    var best_dist := INF
    for prey in prey_nodes:
        if not is_instance_valid(prey):
            continue
        var dist := animal.position.distance_squared_to(prey.position)
        if dist < best_dist:
            best_dist = dist
            best = prey
    return best

func _move_prey(dt: float) -> void:
    for prey in prey_nodes:
        if not is_instance_valid(prey):
            continue
        var id := prey.get_instance_id()
        var velocity: Vector3 = prey_velocities.get(id, Vector3.ZERO)
        var away := prey.position - animal.position
        if away.length() < prey_alert_radius and away.length() > 0.001:
            velocity = away.normalized() * 0.28
        elif randf() < dt * 0.7:
            velocity = Vector3(randf_range(-0.17, 0.17), 0, randf_range(-0.17, 0.17))
        prey_velocities[id] = velocity
        prey.position.x = clampf(prey.position.x + velocity.x * dt, -1.18, 1.18)
        prey.position.z = clampf(prey.position.z + velocity.z * dt, -0.78, 0.78)
        prey.rotation.y += dt * 1.2
        _animate_prey_appendages(prey, velocity)


# Placement uses a ray-plane intersection, not an inferred 2D coordinate.
# All placements are clamped to the interior of the enclosure.
func _set_edit_mode(kind: String) -> void:
    editing = true
    decor_kind = kind
    edit_hint.text = "편집: " + ("돌" if kind == "rock" else ("유목" if kind == "wood" else "지우기")) + " · 바닥을 터치"

func _place_at_screen(screen_pos: Vector2) -> void:
    if camera == null:
        return
    var origin := camera.project_ray_origin(screen_pos)
    var direction := camera.project_ray_normal(screen_pos)
    if absf(direction.y) < 0.0001:
        return
    var distance := (-0.50 - origin.y) / direction.y
    if distance <= 0.0:
        return
    var point := origin + direction * distance
    if absf(point.x) > 1.42 or absf(point.z) > 0.98:
        return
    if decor_kind == "erase":
        _remove_nearest_decoration(point)
    elif decorations.size() < MAX_DECORATIONS:
        _add_decoration(decor_kind, point)
    else:
        notice.text = "장식은 최대 32개입니다."

func _add_decoration(kind: String, pos: Vector3) -> void:
    var root := Node3D.new()
    root.name = "Decoration_%d" % decorations.size()
    root.position = pos
    terrain_root.add_child(root)
    if kind == "rock":
        var stone := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radial_segments = 12
        mesh.rings = 8
        stone.mesh = mesh
        stone.scale = Vector3(0.16, 0.095, 0.12)
        stone.position.y = 0.06
        var rock_material := _material(Color(0.70, 0.72, 0.68))
        rock_material.albedo_texture = stone_texture
        _apply_pbr(rock_material, "stone")
        stone.material_override = rock_material
        root.add_child(stone)
        _walkable_sphere(root, Vector3(0, 0.06, 0), Vector3(0.16, 0.095, 0.12))
    else:
        var wood_a := Vector3(-0.22, 0.09, -0.04)
        var wood_b := Vector3(0.22, 0.16, 0.04)
        _segment(root, wood_a, wood_b, 0.055, Color(0.30, 0.19, 0.10))
        _walkable_wood(root, wood_a, wood_b, 0.055)
    decorations.append(root)
    if habitat_interactions != null:
        habitat_interactions.on_decoration_added(root, kind)
    decoration_data.append({"kind": kind, "x": pos.x, "z": pos.z})
    notice.text = "장식 %d/%d" % [decorations.size(), MAX_DECORATIONS]

func _remove_nearest_decoration(point: Vector3) -> void:
    var closest := -1
    var best := 0.30
    for i in range(decorations.size()):
        var distance := decorations[i].position.distance_to(point)
        if distance < best:
            best = distance
            closest = i
    if closest >= 0:
        decorations[closest].queue_free()
        decorations.remove_at(closest)
        decoration_data.remove_at(closest)
        notice.text = "장식을 제거했습니다."

func _clear_decorations() -> void:
    for item in decorations:
        item.queue_free()
    decorations.clear()
    decoration_data.clear()
