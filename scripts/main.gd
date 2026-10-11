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
var camera_target := Vector3(0, 0.20, 0)
var camera_pan_offset := Vector3.ZERO
var camera_pan_mode := false
var mouse_pan_active := false
var pan_center_previous := Vector2.ZERO
var habitat_root: Node3D
var leaf_detail_texture: Texture2D
var leaf_normal_texture: Texture2D
var status: Label
var notice: Label
var orbit_yaw := 0.0
var orbit_pitch := 0.30
var orbit_distance := 8.6
const CAMERA_MIN_DISTANCE := 0.42
const CAMERA_MAX_DISTANCE := 22.0
const WALK_BOUND_X := 3.25
const WALK_BOUND_Z := 2.18
const PREY_BOUND_X := 3.48
const PREY_BOUND_Z := 2.46
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
var mandibles: Array[Node3D] = []
var forelegs: Array[Node3D] = []
var wing_pivots: Array[Node3D] = []
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
var menu_scroll: ScrollContainer
var menu_touch_index := -1
var menu_touch_start := Vector2.ZERO
var menu_touch_last := Vector2.ZERO
var menu_touch_dragging := false
var suppress_menu_click := false
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
const ANIMATIONS := ["IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "FLY", "DEFEND"]
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
var foot_tarsi: Array = []
var foot_claws: Array = []
const FOOT_REPLANT_DISTANCE := 0.24
const FOOT_SWING_DURATION := 0.23

# v2.4: imported skinned GLB is the visible model; the existing procedural
# hierarchy remains an invisible motion/IK fallback and physics reference.
const RIGGED_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_rigged.glb")
var rigged_visual: Node3D
var rigged_player: AnimationPlayer
var rigged_clip := ""
var use_rigged_visual := false
var rigged_available := false
var rigged_clips: Dictionary = {}
var procedural_meshes: Array[MeshInstance3D] = []
var rigged_import_warnings: Array[String] = []
var visual_model_scale := 0.26
# v2.5: runtime rig pose adaptation, applied after the GLB animation player.
var rigged_pose_driver: RiggedPoseDriver
var rigged_skeleton: Skeleton3D
var rigged_ik_enabled := true
var rigged_pose_status := "not initialized"
# v2.6: scripted traversal of a real, collidable inclined branch.
var climb_active := false
var climb_progress := 0.0
var climb_cooldown := 18.0
var climb_branch_start := Vector3(-0.48, -0.48, 0.62)
var climb_branch_end := Vector3(-0.18, 0.92, 0.38)
const CLIMB_SPEED := 0.18
const CLIMB_BODY_CLEARANCE := 0.065
var climb_direction := 1.0
var climb_pause := 0.0
var flight_demo_clock := 0.0
var flight_start_position := Vector3.ZERO
var flight_start_yaw := 0.0
const FLIGHT_TAKEOFF_DURATION := 0.95
var feed_demo_prey: Node3D







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
    _build_leaf_detail_textures()
    _create_world()
    terrain_root = Node3D.new()
    terrain_root.name = "UserDecorations"
    add_child(terrain_root)
    _create_floor_collider()
    _create_climbable_branch()
    _create_mantis()
    _initialize_rigged_visual()
    planted_foot_heights.resize(4)
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
    # The runtime's corrected mint Hierodula model is procedural. Keep the
    # older imported GLB out of the shipped view until it is regenerated.
    if not use_rigged_visual:
        return
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
    camera.fov = 48.0
    add_child(camera)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.065, 0.085, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.8, 0.72)
    env.ambient_light_energy = 0.74
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.12
    sun.shadow_enabled = true
    add_child(sun)
    # Scale the habitat around the walkable floor so the animal and its movement
    # stay unchanged while the enclosure gains 50% more room in every direction.
    habitat_root = Node3D.new()
    habitat_root.name = "HabitatScaleRoot"
    habitat_root.scale = Vector3.ONE * 1.5
    habitat_root.position = Vector3(0, 0.275, 0)
    add_child(habitat_root)
    # The enclosure grows around the existing animal scale. Keep the mantis
    # model's transform unchanged while giving it a roomy, layered habitat.
    _box(Vector3(5.2, 0.2, 3.8), Vector3(0, -0.65, 0), Color(0.23, 0.15, 0.09))
    _box(Vector3(5.2, 2.7, 0.06), Vector3(0, 0.80, -1.92), Color(0.13, 0.19, 0.16, 0.42), true)
    _box(Vector3(5.08, 2.64, 0.035), Vector3(0, 0.80, -1.875), Color(0.66, 0.72, 0.48))
    _box(Vector3(0.05, 2.7, 3.8), Vector3(-2.62, 0.80, 0), Color(0.5, 0.7, 0.7, 0.12), true)
    _box(Vector3(0.05, 2.7, 3.8), Vector3(2.62, 0.80, 0), Color(0.5, 0.7, 0.7, 0.12), true)
    var branch_rng := RandomNumberGenerator.new()
    branch_rng.seed = 9182026
    var branch_clusters: Array[Vector2] = [Vector2(-2.22, -1.42), Vector2(-2.30, -0.60), Vector2(-2.16, 0.42), Vector2(-1.82, 1.48), Vector2(-0.92, 1.48), Vector2(0.88, 1.48), Vector2(1.88, 1.40), Vector2(2.24, 0.63), Vector2(2.28, -0.42), Vector2(1.92, -1.42), Vector2(0.74, -1.48), Vector2(-0.84, -1.45)]
    # A crooked, buttressed tree line builds a deep forest edge and canopy;
    # the center stays open enough to watch the mantis move and feed.
    var trunk_sites: Array[Vector2] = [Vector2(-2.28, -1.47), Vector2(-1.70, -1.57), Vector2(-0.95, -1.60), Vector2(0.10, -1.62), Vector2(1.22, -1.58), Vector2(2.18, -1.43), Vector2(-2.30, -0.44), Vector2(-2.25, 0.72), Vector2(-1.88, 1.48), Vector2(1.84, 1.48), Vector2(2.28, 0.69), Vector2(2.25, -0.65)]
    for i in range(trunk_sites.size()):
        var site: Vector2 = trunk_sites[i]
        var start := Vector3(site.x + branch_rng.randf_range(-0.13, 0.13), -0.53, site.y + branch_rng.randf_range(-0.12, 0.12))
        var bend := Vector3(branch_rng.randf_range(-0.28, 0.28), branch_rng.randf_range(0.50, 0.85), branch_rng.randf_range(-0.20, 0.20))
        var mid := start + bend
        var top := Vector3(clampf(mid.x + branch_rng.randf_range(-0.34, 0.34), -2.38, 2.38), branch_rng.randf_range(1.25, 1.94), clampf(mid.z + branch_rng.randf_range(-0.30, 0.30), -1.75, 1.72))
        var trunk_radius := branch_rng.randf_range(0.115, 0.17)
        _tapered_branch(start, mid, trunk_radius, trunk_radius * 0.70)
        _tapered_branch(mid, top, trunk_radius * 0.72, branch_rng.randf_range(0.035, 0.060))
        # Roots flare out at different angles and lengths rather than repeating
        # a regular row of thin upright poles.
        for root_index in range(branch_rng.randi_range(3, 5)):
            var angle := float(root_index) * TAU / 3.0 + branch_rng.randf_range(-0.3, 0.3)
            var root_end := Vector3(clampf(start.x + cos(angle) * branch_rng.randf_range(0.22, 0.38), -2.46, 2.46), -0.485, clampf(start.z + sin(angle) * branch_rng.randf_range(0.20, 0.37), -1.72, 1.72))
            _tapered_branch(root_end, start + Vector3(0.0, 0.08, 0.0), 0.025, trunk_radius * 0.48)
        var fork_count := branch_rng.randi_range(3, 5)
        for fork_index in range(fork_count):
            var fork_start := start.lerp(top, branch_rng.randf_range(0.48, 0.90))
            var fork_end := Vector3(clampf(fork_start.x + branch_rng.randf_range(-0.56, 0.56), -2.43, 2.43), minf(2.04, fork_start.y + branch_rng.randf_range(0.22, 0.55)), clampf(fork_start.z + branch_rng.randf_range(-0.48, 0.48), -1.78, 1.78))
            _tapered_branch(fork_start, fork_end, branch_rng.randf_range(0.040, 0.070), branch_rng.randf_range(0.012, 0.022))
    # Fallen wood is scattered among the planted edges and leaf litter.
    for i in range(18):
        var cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var start := Vector3(cluster.x + branch_rng.randf_range(-0.24, 0.24), -0.49, cluster.y + branch_rng.randf_range(-0.22, 0.22))
        var end := Vector3(clampf(start.x + branch_rng.randf_range(-0.56, 0.56), -2.46, 2.46), start.y + branch_rng.randf_range(0.04, 0.26), clampf(start.z + branch_rng.randf_range(-0.48, 0.48), -1.72, 1.72))
        _tapered_branch(start, end, branch_rng.randf_range(0.050, 0.085), branch_rng.randf_range(0.016, 0.030))
    for i in range(88):
        var rock_cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var p := Vector3(clampf(rock_cluster.x + branch_rng.randf_range(-0.38, 0.38), -2.46, 2.46), -0.49, clampf(rock_cluster.y + branch_rng.randf_range(-0.34, 0.34), -1.72, 1.72))
        var pebble_size: Vector3 = Vector3(branch_rng.randf_range(0.040, 0.105), branch_rng.randf_range(0.014, 0.039), branch_rng.randf_range(0.035, 0.095))
        var pebble_color: Color = Color(0.19, 0.23, 0.18).lerp(Color(0.39, 0.34, 0.25), branch_rng.randf())
        _ellipsoid(p, pebble_size, pebble_color)
    for i in range(24):
        var cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var rock_pos := Vector3(clampf(cluster.x + branch_rng.randf_range(-0.30, 0.30), -2.46, 2.46), -0.49, clampf(cluster.y + branch_rng.randf_range(-0.28, 0.28), -1.72, 1.72))
        var rock_size := Vector3(branch_rng.randf_range(0.12, 0.24), branch_rng.randf_range(0.045, 0.12), branch_rng.randf_range(0.10, 0.22))
        _ellipsoid(rock_pos, rock_size, Color(0.19, 0.25, 0.19).lerp(Color(0.42, 0.36, 0.27), branch_rng.randf()))

func _create_climbable_branch() -> void:
    # A substantial inclined trunk branch gives the feet a real surface to grip.
    # Its matching collider keeps the climb pose attached to the wood.
    _tapered_branch(climb_branch_start, climb_branch_end, 0.074, 0.048, self)
    var fork_start := climb_branch_start.lerp(climb_branch_end, 0.61)
    _tapered_branch(fork_start, fork_start + Vector3(0.34, 0.38, -0.16), 0.034, 0.012, self)
    _walkable_wood(self, climb_branch_start, climb_branch_end, 0.068)

func _advance_climb(dt: float, force_demo: bool = false) -> void:
    if not climb_active:
        if (climb_cooldown > 0.0 and not force_demo) or molting or (stress > 65.0 and not force_demo) or (hunger > 45.0 and not force_demo):
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
        climb_direction = 1.0
        climb_pause = 0.0
        for i in range(foot_in_swing.size()):
            foot_in_swing[i] = false
        behavior = "나뭇가지 등반"
    if climb_pause > 0.0:
        climb_pause = maxf(0.0, climb_pause - dt)
    elif climb_direction > 0.0:
        climb_progress = minf(1.0, climb_progress + dt * CLIMB_SPEED / climb_branch_start.distance_to(climb_branch_end))
    else:
        climb_progress = maxf(0.0, climb_progress - dt * CLIMB_SPEED / climb_branch_start.distance_to(climb_branch_end))
    var center := climb_branch_start.lerp(climb_branch_end, climb_progress)
    var tangent := (climb_branch_end - climb_branch_start).normalized()
    var radial := Vector3(0.0, 0.0, 1.0)
    radial = (radial - tangent * radial.dot(tangent)).normalized()
    var travel_direction := tangent * climb_direction
    var target := center + radial * CLIMB_BODY_CLEARANCE
    var target_basis := Basis.looking_at(travel_direction, radial)
    animal.position = animal.position.lerp(target, clampf(dt * 8.0, 0.0, 1.0))
    animal.quaternion = animal.quaternion.slerp(target_basis.get_rotation_quaternion(), clampf(dt * 7.0, 0.0, 1.0))
    behavior = "가지에 매달림" if climb_pause > 0.0 else "나뭇가지 등반"
    if climb_direction > 0.0 and climb_progress >= 1.0 and animal.position.distance_to(target) < 0.035:
        climb_direction = -1.0
        climb_pause = 0.8
    elif climb_direction < 0.0 and climb_progress <= 0.0 and animal.position.distance_to(target) < 0.045:
        climb_active = false
        climb_cooldown = 38.0
        animal.position = Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        animal.quaternion = Quaternion.IDENTITY
        roam_target = Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        roam_time = 0.0
        if animation_preview == "CLIMB":
            animation_preview = "AUTO"
            if animation_label != null:
                animation_label.text = "애니메이션: AUTO"

func _advance_flight(dt: float) -> void:
    flight_demo_clock += dt
    var launch_t := clampf(flight_demo_clock / FLIGHT_TAKEOFF_DURATION, 0.0, 1.0)
    var launch_ease := launch_t * launch_t * (3.0 - 2.0 * launch_t)
    var glide_time := maxf(0.0, flight_demo_clock - FLIGHT_TAKEOFF_DURATION)
    # A short forward-and-up launch avoids the old straight vertical lift.
    var target := flight_start_position + Vector3(0.0, 0.62 * launch_ease, -0.16 * launch_ease)
    var x_extent: float = minf(0.42, maxf(0.0, 2.08 - absf(flight_start_position.x)))
    var z_extent: float = minf(0.58, maxf(0.0, 1.32 - absf(flight_start_position.z)))
    var dx := 0.0
    var dz := -0.18 - z_extent * 0.56
    if glide_time > 0.0:
        var glide_x := x_extent * (1.0 - cos(glide_time * 0.78))
        var glide_z := -z_extent * sin(glide_time * 0.56)
        target.x = flight_start_position.x + glide_x
        target.z = flight_start_position.z - 0.16 + glide_z
        target.y = flight_start_position.y + 0.62 + sin(glide_time * 2.9) * 0.045
        dx = x_extent * 0.78 * sin(glide_time * 0.78)
        dz = -z_extent * 0.56 * cos(glide_time * 0.56)
    animal.position = target
    var desired_yaw := atan2(-dx, -dz)
    animal.rotation.y = lerp_angle(animal.rotation.y, desired_yaw, clampf(dt * 2.4, 0.0, 1.0))

func _ensure_feed_demo_prey() -> void:
    if feed_demo_prey != null and is_instance_valid(feed_demo_prey):
        feed_demo_prey.visible = true
        return
    feed_demo_prey = Node3D.new()
    feed_demo_prey.name = "FeedDemonstrationPrey"
    animal.add_child(feed_demo_prey)
    _create_feeder_insect(feed_demo_prey, 1.08, Color(0.48, 0.31, 0.16))
    # Hold the cricket between the capture tibiae directly below the mouth.
    feed_demo_prey.position = Vector3(0.0, 0.20, -0.70)

func _create_floor_collider() -> void:
    var floor_body := StaticBody3D.new()
    floor_body.name = "WalkableSubstrate"
    floor_body.collision_layer = WALKABLE_LAYER
    floor_body.collision_mask = 0
    floor_body.position = Vector3(0, -0.55, 0)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(5.2, 0.2, 3.8)
    shape.shape = box_shape
    floor_body.add_child(shape)
    habitat_root.add_child(floor_body)

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
    # Adult Hierodula-style mantis. This corrected procedural mesh is the
    # Android default so the shipped app displays the same model as the source.
    animal = Node3D.new()
    animal.name = "Mantis_01"
    animal.position = Vector3(0, -0.38, 0)
    animal.scale = Vector3.ONE * (0.32 * (0.80 + growth * 0.30))
    add_child(animal)
    # The reference is a saturated leaf green; reduce the cyan cast and keep
    # highlights within the cuticle instead of washing the model toward white.
    # Saturated yellow-green cuticle closer to the bright leaf-green reference.
    var mint := Color(0.23, 0.49, 0.10)
    var mint_light := Color(0.34, 0.62, 0.16)
    var mint_shadow := Color(0.11, 0.25, 0.045)
    var eye_color := Color(0.035, 0.095, 0.035)

    abdomen = Node3D.new()
    abdomen.name = "AbdomenPivot"
    animal.add_child(abdomen)
    # A slim, elongated abdomen sits under the leaf-shaped forewings. The
    # overlapping plates stay visible along its underside and narrow at both ends.
    _part(abdomen, Vector3(0, 0.178, 0.14), Vector3(0.084, 0.054, 0.35), mint)
    for band in range(8):
        var t: float = float(band) / 7.0
        var z: float = -0.12 + t * 0.56
        var taper: float = 0.66 + 0.34 * sin((t * 0.90 + 0.05) * PI)
        var segment_color: Color = mint if band % 2 == 0 else mint.darkened(0.045)
        _part(abdomen, Vector3(0, 0.185, z), Vector3(0.091 * taper, 0.057 * taper, 0.047), segment_color)
        _segment(abdomen, Vector3(-0.074 * taper, 0.174, z + 0.029), Vector3(0.074 * taper, 0.174, z + 0.029), 0.0018, mint_shadow)
        for side_index in range(2):
            var side: float = -1.0 if side_index == 0 else 1.0
            _part(abdomen, Vector3(side * 0.094 * taper, 0.178, z), Vector3(0.008, 0.005, 0.012), mint_shadow)
    # Underlapping sternites give the abdomen a segmented underside instead of a single smooth tube.
    for sternite in range(7):
        var sternite_t: float = float(sternite) / 6.0
        var sternite_z: float = -0.075 + sternite_t * 0.49
        var sternite_taper: float = 0.70 + 0.30 * sin((sternite_t * 0.90 + 0.05) * PI)
        var sternite_color: Color = mint if sternite % 2 == 0 else mint.darkened(0.08)
        _part(abdomen, Vector3(0, 0.132, sternite_z), Vector3(0.056 * sternite_taper, 0.020, 0.035), sternite_color)
        _segment(abdomen, Vector3(-0.047 * sternite_taper, 0.124, sternite_z + 0.022), Vector3(0.047 * sternite_taper, 0.124, sternite_z + 0.022), 0.0015, mint_shadow)
    _part(abdomen, Vector3(0, 0.16, 0.48), Vector3(0.052, 0.038, 0.066), mint_shadow)
    for side_index in range(2):
        var side: float = -1.0 if side_index == 0 else 1.0
        _segment(abdomen, Vector3(side * 0.024, 0.16, 0.515), Vector3(side * 0.050, 0.145, 0.60), 0.006, mint_shadow)
        _create_mantis_wing(abdomen, side, false)
        _create_mantis_wing(abdomen, side, true)

    thorax_pivot = Node3D.new()
    thorax_pivot.name = "ThoraxArticulation"
    thorax_pivot.position = Vector3(0, 0.24, -0.34)
    animal.add_child(thorax_pivot)
    # A long, slender pronotum joins the head to the wing roots. Keep the
    # raised margins restrained so the thorax reads as one continuous shield.
    _part(thorax_pivot, Vector3(0, 0.010, 0.005), Vector3(0.044, 0.036, 0.39), mint)
    _part(thorax_pivot, Vector3(0, -0.001, 0.115), Vector3(0.057, 0.038, 0.115), mint_light)
    _part(thorax_pivot, Vector3(0, 0.027, -0.115), Vector3(0.036, 0.014, 0.095), mint_light)
    for thorax_rib in range(3):
        var rib_z := -0.035 + float(thorax_rib) * 0.092
        _segment(thorax_pivot, Vector3(-0.036, -0.009, rib_z), Vector3(0.036, -0.009, rib_z), 0.0017, mint_shadow)
    _segment(thorax_pivot, Vector3(0, 0.050, 0.16), Vector3(0, 0.050, -0.245), 0.0042, mint_light)
    for pronotum_side in [-1.0, 1.0]:
        _segment(thorax_pivot, Vector3(pronotum_side * 0.038, 0.019, 0.13), Vector3(pronotum_side * 0.034, 0.016, -0.23), 0.0018, mint_shadow)
    # Narrow cervical bridge overlaps the head and front edge of the shield.
    _part(thorax_pivot, Vector3(0, 0.010, -0.205), Vector3(0.034, 0.027, 0.10), mint)

    head_pivot = Node3D.new()
    head_pivot.name = "HeadPivot"
    head_pivot.position = Vector3(0, 0.29, -0.64)
    animal.add_child(head_pivot)
    _part(head_pivot, Vector3(0, 0.012, -0.012), Vector3(0.15, 0.11, 0.12), mint_light)
    _part(head_pivot, Vector3(0, -0.045, -0.087), Vector3(0.084, 0.054, 0.036), mint)
    _part(head_pivot, Vector3(0, -0.078, -0.097), Vector3(0.036, 0.019, 0.025), mint_shadow)
    # Soft cheek plates give the broad, triangular mantis face a defined lower edge.
    for cheek_side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(cheek_side * 0.076, -0.027, -0.074), Vector3(0.043, 0.047, 0.031), mint)
    for mandible_side in [-1.0, 1.0]:
        var mandible := Node3D.new()
        mandible.name = "Mandible_%d" % int(mandible_side)
        mandible.position = Vector3(mandible_side * 0.014, -0.062, -0.105)
        head_pivot.add_child(mandible)
        _ellipsoid_limb(mandible, Vector3.ZERO, Vector3(mandible_side * 0.012, -0.020, -0.025), 0.006, mint_shadow)
        _segment(mandible, Vector3(mandible_side * 0.012, -0.020, -0.025), Vector3(mandible_side * 0.004, -0.027, -0.035), 0.003, mint_light)
        mandibles.append(mandible)
    # Three small ocelli sit between the compound eyes, above the clypeus.
    _part(head_pivot, Vector3(0, 0.092, -0.077), Vector3(0.009, 0.008, 0.008), mint_shadow)
    for ocellus_side in [-1.0, 1.0]:
        _part(head_pivot, Vector3(ocellus_side * 0.027, 0.085, -0.073), Vector3(0.008, 0.007, 0.008), mint_shadow)
    # Short paired palps frame the chewing mouthparts.
    for palp_side in [-1.0, 1.0]:
        _segment(head_pivot, Vector3(palp_side * 0.035, -0.060, -0.105), Vector3(palp_side * 0.050, -0.104, -0.132), 0.0035, mint_shadow)

    # Prominent lateral compound eyes, small visible facets, and fine antennae.
    for side_index in range(2):
        var side: float = -1.0 if side_index == 0 else 1.0
        # A muted green socket surrounds the darker compound-eye facets.
        _part(head_pivot, Vector3(side * 0.118, 0.02, -0.024), Vector3(0.078, 0.084, 0.078), mint_shadow)
        _part(head_pivot, Vector3(side * 0.118, 0.02, -0.024), Vector3(0.068, 0.074, 0.067), eye_color)
        # Staggered facets wrap around the eye instead of forming a square grid.
        for facet in range(30):
            var row: int = int(facet / 6)
            var column: int = facet % 6
            var facet_y: float = -0.048 + float(row) * 0.024
            var facet_z: float = -0.049 + float(column) * 0.0196
            var surface_factor: float = sqrt(maxf(0.04, 1.0 - pow(facet_y / 0.074, 2.0) - pow(facet_z / 0.067, 2.0)))
            var facet_x: float = 0.118 + 0.068 * surface_factor + 0.002
            var facet_shade: float = 0.91 + 0.08 * float((row + column) % 3) / 2.0
            _part(head_pivot, Vector3(side * facet_x, 0.02 + facet_y, -0.024 + facet_z), Vector3(0.0048, 0.0052, 0.0052), Color(0.19, 0.40, 0.18) * facet_shade)
        # Small specular points sit on the outer eye surface.
        _part(head_pivot, Vector3(side * 0.176, 0.049, -0.075), Vector3(0.007, 0.010, 0.005), Color(0.67, 0.82, 0.53))
        var feeler := Node3D.new()
        feeler.name = "Antenna_%d" % int(side)
        feeler.position = Vector3(side * 0.045, 0.075, -0.085)
        head_pivot.add_child(feeler)
        var antenna_start := Vector3.ZERO
        for segment_index in range(18):
            var t: float = float(segment_index + 1) / 18.0
            var antenna_wave: float = 0.016 * sin(t * PI * 2.6 + side * 0.7)
            var antenna_end := Vector3(side * (0.018 + 0.12 * t + 0.028 * sin(t * PI)) + antenna_wave, 0.018 * sin(t * PI * 1.3 + side * 0.35), -0.88 * t)
            _segment(feeler, antenna_start, antenna_end, 0.0025 * (1.0 - 0.48 * t), mint_shadow)
            antenna_start = antenna_end
        antennae.append(feeler)

        # Two walking pairs (four legs), plus one specialized capture pair below.
        for i in range(2):
            var leg_z: float = -0.08 if i == 0 else 0.20
            var joint := Node3D.new()
            joint.name = "WalkingLeg_%d_%d" % [int(side), i]
            joint.position = Vector3(side * 0.052, 0.19, leg_z)
            animal.add_child(joint)
            _segment(joint, Vector3.ZERO, Vector3(side * 0.075, -0.005, 0.025), 0.014, mint_shadow)
            var upper := _make_gait_bone(joint, 0.018, mint_light)
            var lower := _make_gait_bone(joint, 0.010, mint_shadow)
            leg_pivots.append(joint)
            gait_segments.append([upper, lower])
            var leg_foot := Vector3(side * 0.32, -0.47, leg_z + (0.19 if i == 0 else 0.22))
            gait_feet.append(leg_foot)
            step_targets.append(leg_foot)
            var tarsomeres: Array[MeshInstance3D] = []
            for tarsomere_index in range(5):
                var tarsomere := _make_gait_bone(joint, 0.0052 - float(tarsomere_index) * 0.00045, mint_shadow)
                tarsomere.name = "Tarsomere_%d_%d_%d" % [int(side), i, tarsomere_index]
                tarsomeres.append(tarsomere)
            foot_tarsi.append(tarsomeres)
            var claws: Array[MeshInstance3D] = []
            for claw_index in range(2):
                var tarsal_claw := _make_gait_bone(joint, 0.0028, mint_light)
                tarsal_claw.name = "TarsalClaw_%d_%d_%d" % [int(side), i, claw_index]
                claws.append(tarsal_claw)
            foot_claws.append(claws)

        # Enlarged femur folds against a spined tibia to form a clear V-shaped
        # raptorial foreleg. It is visibly separate from the four walking legs.
        var foreleg := Node3D.new()
        foreleg.name = "RaptorialForeleg_%d" % int(side)
        foreleg.position = Vector3(side * 0.055, 0.255, -0.39)
        animal.add_child(foreleg)
        var coxa_end := Vector3(side * 0.075, 0.015, -0.055)
        var femur_end := Vector3(side * 0.19, 0.008, -0.19)
        _ellipsoid_limb(foreleg, Vector3.ZERO, coxa_end, 0.020, mint_shadow)
        _part(foreleg, coxa_end, Vector3(0.023, 0.021, 0.023), mint_light)
        _part(foreleg, coxa_end.lerp(femur_end, 0.08), Vector3(0.019, 0.014, 0.021), mint_shadow)
        var elbow := Node3D.new()
        elbow.name = "ForelegElbow_%d" % int(side)
        elbow.position = femur_end
        foreleg.add_child(elbow)
        # A broad, flattened femoral blade makes the mantis's capture arm
        # unmistakable; alternating inner spines oppose the tibial teeth.
        _ellipsoid_limb(foreleg, coxa_end, femur_end, 0.055, mint_light)
        _ellipsoid_limb(foreleg, coxa_end.lerp(femur_end, 0.08), coxa_end.lerp(femur_end, 0.92), 0.026, mint)
        _ellipsoid_limb(foreleg, coxa_end.lerp(femur_end, 0.10) + Vector3(0.0, 0.030, 0.0), coxa_end.lerp(femur_end, 0.90) + Vector3(0.0, 0.030, 0.0), 0.010, mint_light)
        _part(foreleg, femur_end, Vector3(0.023, 0.023, 0.025), mint_shadow)
        for spine_index in range(11):
            var t: float = 0.08 + float(spine_index) * 0.083
            var base: Vector3 = coxa_end.lerp(femur_end, t)
            var spine_tip: Vector3 = base + Vector3(-side * (0.043 if spine_index % 2 == 0 else 0.052), 0.003, -0.016)
            _segment(foreleg, base, spine_tip, 0.0065 if spine_index % 2 == 0 else 0.0055, mint_shadow)
        # Two longer discoidal spines make the prey-facing femur edge distinct
        # from the shorter comb of marginal teeth.
        for spine_index in range(2):
            var t: float = 0.43 + float(spine_index) * 0.19
            var base: Vector3 = coxa_end.lerp(femur_end, t)
            var spine_tip: Vector3 = base + Vector3(-side * 0.069, 0.004, -0.022)
            _segment(foreleg, base, spine_tip, 0.009, mint_shadow)
        var claw := Node3D.new()
        claw.name = "ForelegTibia_%d" % int(side)
        elbow.add_child(claw)
        var tibia_end := Vector3(-side * 0.15, -0.13, -0.115)
        _ellipsoid_limb(claw, Vector3.ZERO, tibia_end, 0.024, mint)
        _part(claw, Vector3.ZERO, Vector3(0.020, 0.020, 0.020), mint_shadow)
        for spine_index in range(11):
            var t: float = 0.08 + float(spine_index) * 0.083
            var base: Vector3 = tibia_end * t
            var tooth_length: float = 0.041 if spine_index % 3 == 1 else 0.030
            _segment(claw, base, base + Vector3(side * tooth_length, 0.006, -0.014), 0.0055 if spine_index % 3 else 0.0065, mint_shadow)
        var tarsal_palm := tibia_end + Vector3(-side * 0.018, -0.006, -0.035)
        _ellipsoid_limb(claw, tibia_end, tarsal_palm, 0.009, mint_shadow)
        _ellipsoid_limb(claw, tarsal_palm, tarsal_palm + Vector3(-side * 0.028, -0.004, -0.038), 0.0055, mint_light)
        _ellipsoid_limb(claw, tarsal_palm, tarsal_palm + Vector3(side * 0.012, -0.004, -0.032), 0.0045, mint_shadow)
        forelegs.append(foreleg)
        foreleg_elbows.append(elbow)
        foreleg_claws.append(claw)

func _create_mantis_wing(parent: Node3D, side: float, hindwing: bool) -> void:
    # Smooth leaf-like forewings cover most of the abdomen; pale hindwings stay tucked below.
    var segments := 32
    var lane_count := 8
    var start_z: float = -0.02 if hindwing else -0.15
    var end_z: float = 0.58 if hindwing else 0.68
    var y: float = 0.238 if hindwing else 0.251
    var max_width: float = 0.34 if hindwing else 0.205
    var total_length: float = end_z - start_z
    var wing_color: Color = Color(0.54, 0.68, 0.31, 0.58) if hindwing else Color(0.22, 0.47, 0.09, 1.0)
    var hinge := Vector3(side * (0.024 if hindwing else 0.008), y, start_z)
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    for i in range(segments):
        var t0: float = float(i) / float(segments)
        var t1: float = float(i + 1) / float(segments)
        var arch0: float = 0.016 * sin(PI * t0)
        var arch1: float = 0.016 * sin(PI * t1)
        var profile0 := _mantis_wing_profile(t0, hindwing)
        var profile1 := _mantis_wing_profile(t1, hindwing)
        var w0: float = 0.004 + profile0 * max_width
        var w1: float = 0.004 + profile1 * max_width
        var edge0: float = 0.0015 * sin(t0 * PI * 4.0) * sin(t0 * PI)
        var edge1: float = 0.0015 * sin(t1 * PI * 4.0) * sin(t1 * PI)
        for lane in range(lane_count):
            var u0: float = float(lane) / float(lane_count)
            var u1: float = float(lane + 1) / float(lane_count)
            var p00 := _mantis_wing_surface_point(u0, t0, w0, edge0, arch0, total_length, side)
            var p10 := _mantis_wing_surface_point(u1, t0, w0, edge0, arch0, total_length, side)
            var p11 := _mantis_wing_surface_point(u1, t1, w1, edge1, arch1, total_length, side)
            var p01 := _mantis_wing_surface_point(u0, t1, w1, edge1, arch1, total_length, side)
            var n00 := _mantis_wing_surface_normal(u0, t0, w0, total_length, side)
            var n10 := _mantis_wing_surface_normal(u1, t0, w0, total_length, side)
            var n11 := _mantis_wing_surface_normal(u1, t1, w1, total_length, side)
            var n01 := _mantis_wing_surface_normal(u0, t1, w1, total_length, side)
            var c00 := _mantis_wing_tint(wing_color, u0, t0)
            var c10 := _mantis_wing_tint(wing_color, u1, t0)
            var c11 := _mantis_wing_tint(wing_color, u1, t1)
            var c01 := _mantis_wing_tint(wing_color, u0, t1)
            vertices.append(p00)
            vertices.append(p10)
            vertices.append(p11)
            vertices.append(p00)
            vertices.append(p11)
            vertices.append(p01)
            normals.append(n00)
            normals.append(n10)
            normals.append(n11)
            normals.append(n00)
            normals.append(n11)
            normals.append(n01)
            uvs.append(Vector2(u0, t0))
            uvs.append(Vector2(u1, t0))
            uvs.append(Vector2(u1, t1))
            uvs.append(Vector2(u0, t0))
            uvs.append(Vector2(u1, t1))
            uvs.append(Vector2(u0, t1))
            colors.append(c00)
            colors.append(c10)
            colors.append(c11)
            colors.append(c00)
            colors.append(c11)
            colors.append(c01)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    var wing_mesh := ArrayMesh.new()
    wing_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var wing_pivot := Node3D.new()
    wing_pivot.name = ("HindwingPivot" if hindwing else "ForewingPivot") + ("_L" if side < 0.0 else "_R")
    wing_pivot.position = hinge
    wing_pivot.set_meta("wing_side", side)
    wing_pivot.set_meta("hindwing", hindwing)
    if hindwing:
        wing_pivot.scale.x = 0.30
    parent.add_child(wing_pivot)
    var wing_instance := MeshInstance3D.new()
    wing_instance.name = "WingMembrane"
    wing_instance.mesh = wing_mesh
    var wing_material := _material(Color.WHITE)
    wing_material.vertex_color_use_as_albedo = true
    wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if pbr_normal.has("mantis_cuticle"):
        wing_material.normal_enabled = true
        wing_material.normal_texture = pbr_normal["mantis_cuticle"]
        wing_material.normal_scale = 0.14 if hindwing else 0.18
    if pbr_roughness.has("mantis_cuticle"):
        wing_material.roughness_texture = pbr_roughness["mantis_cuticle"]
        wing_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if hindwing:
        wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        wing_material.roughness = 0.42
    else:
        wing_material.roughness = 0.72
    wing_instance.material_override = wing_material
    wing_pivot.add_child(wing_instance)
    var vein_color: Color = Color(0.30, 0.42, 0.19) if hindwing else Color(0.15, 0.31, 0.055)
    _segment(wing_pivot, Vector3(0, 0.015, 0.012), Vector3(side * 0.020, 0.016, total_length - 0.012), 0.0018, vein_color)
    for vein_index in range(9):
        var t: float = 0.10 + float(vein_index) * 0.093
        var z: float = total_length * t
        var width: float = _mantis_wing_profile(t, hindwing) * max_width
        var origin := Vector3(side * width * 0.035, 0.014 + 0.010 * sin(PI * t), z * 0.20)
        var tip := Vector3(side * width * 0.91, 0.012 + 0.010 * sin(PI * t), z)
        _segment(wing_pivot, origin, tip, 0.0009 if hindwing else 0.0010, vein_color)
    # Sparse cross-veins leave the forewing surface predominantly smooth.
    for cross_index in range(7 if hindwing else 5):
        var t: float = 0.13 + float(cross_index) * (0.12 if hindwing else 0.15)
        var z: float = total_length * t
        var width: float = _mantis_wing_profile(t, hindwing) * max_width
        _segment(wing_pivot, Vector3(side * width * 0.22, 0.014, z - 0.010), Vector3(side * width * 0.82, 0.014, z + 0.016), 0.00065, vein_color)
    wing_pivots.append(wing_pivot)

func _mantis_wing_surface_point(u: float, t: float, width: float, edge: float, arch: float, length: float, side: float) -> Vector3:
    var x: float = width * u + edge * pow(u, 8.0)
    var y: float = arch + 0.007 * sin(PI * u)
    return Vector3(side * x, y, length * t)

func _mantis_wing_surface_normal(u: float, t: float, width: float, length: float, side: float) -> Vector3:
    var dx_du: float = width
    var dy_du: float = 0.007 * PI * cos(PI * u)
    var dy_dt: float = 0.012 * PI * cos(PI * t)
    return Vector3(-side * dy_du * length, maxf(0.001, dx_du) * length, -side * dx_du * dy_dt).normalized()

func _mantis_wing_tint(base: Color, u: float, t: float) -> Color:
    # A restrained darker margin and low-amplitude pigment variation retain a leathery cuticle.
    var edge_amount: float = clampf((u - 0.72) / 0.28, 0.0, 1.0)
    var tint: Color = base.lerp(base.darkened(0.10), edge_amount * 0.65)
    var vein_shade: float = 0.985 + 0.015 * sin(t * PI * 4.0 + u * 2.0)
    tint.r *= vein_shade
    tint.g *= vein_shade
    tint.b *= vein_shade
    return tint

func _mantis_wing_profile(t: float, hindwing: bool) -> float:
    var safe_t: float = clampf(t, 0.0, 1.0)
    if hindwing:
        # Folded hindwing: narrower and still fanned beneath the forewing.
        var flare: float = 0.12 + 0.88 * sin(safe_t * PI * 0.5)
        var taper: float = pow(maxf(0.0, 1.0 - safe_t), 0.30)
        return flare * taper
    # Forewing has a tapered hinge, broad blade, and rounded distal tip.
    var root: float = clampf(safe_t / 0.13, 0.0, 1.0)
    root = root * root * (3.0 - 2.0 * root)
    var tip: float = clampf((1.0 - safe_t) / 0.24, 0.0, 1.0)
    tip = tip * tip * (3.0 - 2.0 * tip)
    return root * tip

func _ellipsoid_limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
    var delta := b - a
    var length: float = delta.length()
    if length < 0.0001:
        return
    var item := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radial_segments = 24
    mesh.rings = 12
    item.mesh = mesh
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.BACK, delta.normalized())
    item.scale = Vector3(radius, radius, length * 0.64)
    item.material_override = _material(tint)
    parent.add_child(item)

# Surface maps add cuticle detail without overriding the selected mint color.

func _apply_pbr(mat: StandardMaterial3D, kind: String) -> void:
    if pbr_normal.has(kind):
        mat.normal_enabled = true
        mat.normal_texture = pbr_normal[kind]
        mat.normal_scale = 0.42 if kind == "mantis_eye" else 0.48
    if pbr_roughness.has(kind):
        mat.roughness_texture = pbr_roughness[kind]
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if kind == "mantis_eye":
        mat.metallic = 0.0
        mat.roughness = 0.22
    elif kind == "mantis_cuticle":
        mat.metallic = 0.01
        mat.roughness = 0.52

func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 28
    mesh.rings = 16
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
        # Keep the requested mint pigment; use the existing maps only for
        # surface response so the old olive albedo cannot recolor the model.
        mat.albedo_color = color
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
    (habitat_root if habitat_root != null else self).add_child(item)

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

func _tapered_branch(a: Vector3, b: Vector3, base_radius: float, tip_radius: float, target_parent: Node3D = null) -> void:
    var item := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = maxf(0.004, tip_radius)
    mesh.bottom_radius = maxf(0.006, base_radius)
    mesh.height = a.distance_to(b)
    mesh.radial_segments = 9
    item.mesh = mesh
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    var mat := _material(Color(0.34, 0.22, 0.13))
    if bark_texture != null:
        mat.albedo_texture = bark_texture
        _apply_pbr(mat, "bark")
    item.material_override = mat
    var destination: Node3D = target_parent if target_parent != null else (habitat_root if habitat_root != null else self)
    destination.add_child(item)

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
    elif not transparent and pos.z < -1.7 and bark_texture != null:
        mat.albedo_texture = bark_texture
        _apply_pbr(mat, "bark")
    if transparent:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.roughness = 0.08
    item.material_override = mat
    (habitat_root if habitat_root != null else self).add_child(item)

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
    menu_scroll = ScrollContainer.new()
    menu_scroll.custom_minimum_size = Vector2(300, 0)
    menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    menu_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    menu_scroll.scroll_deadzone = 8
    ui_panel.add_child(menu_scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.mouse_filter = Control.MOUSE_FILTER_PASS
    menu_scroll.add_child(column)
    get_viewport().size_changed.connect(_resize_ui)
    call_deferred("_resize_ui")
    var title := Label.new()
    title.text = "LIVING TERRARIUM 3D"
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(title)
    status = Label.new()
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(status)
    _button(column, "먹이 추가", func(): _add_food())
    _button(column, "바람 켜기/끄기", func(): wind_enabled = not wind_enabled; notice.text = "바람: " + ("켜짐" if wind_enabled else "꺼짐"))
    _button(column, "생태계 상호작용 켜기/끄기", func(): habitat_interactions.active = not habitat_interactions.active; notice.text = "생태계 상호작용: " + ("켜짐" if habitat_interactions.active else "꺼짐"))
    _button(column, "생태계 활동 기록", func(): notice.text = habitat_interactions.summary())
    _button(column, "바람 세기 변경", func(): wind_strength = fmod(wind_strength + 0.25, 1.26); notice.text = "바람 세기: %.2f" % wind_strength)
    animation_label = Label.new()
    animation_label.text = "애니메이션: AUTO"
    animation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(animation_label)
    _button(column, "자동 행동 애니메이션", func(): _set_animation_preview("AUTO"))
    for clip in ANIMATIONS:
        var selected_clip: String = clip
        var clip_label := "동작 시연: " + selected_clip
        if selected_clip == "FEED":
            clip_label = "동작 시연: 먹이 먹기"
        elif selected_clip == "FLY":
            clip_label = "동작 시연: 비행"
        elif selected_clip == "CLIMB":
            clip_label = "동작 시연: 가지 오르기"
        _button(column, clip_label, func(): _set_animation_preview(selected_clip))
    _button(column, "관찰 기록", func(): notice.text = "성장 %.0f%% / 탈피 %d회 / 경과 %.0f초" % [growth * 100.0, molt_count, life_age])
    _button(column, "온도 +1°C", func(): temperature = minf(38.0, temperature + 1.0); _refresh())
    _button(column, "온도 -1°C", func(): temperature = maxf(15.0, temperature - 1.0); _refresh())
    _button(column, "분무 +10%", func(): humidity = minf(100.0, humidity + 10.0); _refresh())
    _button(column, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(column, "발 접지 켜기/끄기", func(): foot_contacts_enabled = not foot_contacts_enabled; notice.text = "발 접지: " + ("켜짐" if foot_contacts_enabled else "꺼짐"))
    _button(column, "개체 추적 켜기/끄기", func(): _toggle_follow_camera())
    _button(column, "돌 배치 모드", func(): _set_edit_mode("rock"))
    _button(column, "유목 배치 모드", func(): _set_edit_mode("wood"))
    _button(column, "장식 지우기 모드", func(): _set_edit_mode("erase"))
    _button(column, "편집 종료", func(): editing = false; edit_hint.text = "관찰 모드")
    _button(column, "UI 숨김/표시", func(): stats_visible = not stats_visible; ui_panel.visible = stats_visible)
    _button(column, "저장", func(): _save_state())
    _button(column, "불러오기", func(): _load_state(true))
    edit_hint = Label.new()
    edit_hint.text = "관찰 모드"
    edit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(edit_hint)
    notice = Label.new()
    notice.text = "드래그: 회전 | 이동 버튼을 누른 뒤 드래그: 시야 이동 | 두 손가락: 이동·확대"
    notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(notice)

    var zoom_controls := VBoxContainer.new()
    zoom_controls.anchor_left = 1.0
    zoom_controls.anchor_top = 0.5
    zoom_controls.anchor_right = 1.0
    zoom_controls.anchor_bottom = 0.5
    zoom_controls.offset_left = -84.0
    zoom_controls.offset_top = -150.0
    zoom_controls.offset_right = -14.0
    zoom_controls.offset_bottom = 150.0
    zoom_controls.add_theme_constant_override("separation", 8)
    root_ui.add_child(zoom_controls)
    var zoom_in := Button.new()
    zoom_in.text = "+"
    zoom_in.custom_minimum_size = Vector2(68, 58)
    zoom_in.add_theme_font_size_override("font_size", 30)
    zoom_in.pressed.connect(func(): _set_camera_zoom(-0.42))
    zoom_controls.add_child(zoom_in)
    var zoom_out := Button.new()
    zoom_out.text = "−"
    zoom_out.custom_minimum_size = Vector2(68, 58)
    zoom_out.add_theme_font_size_override("font_size", 30)
    zoom_out.pressed.connect(func(): _set_camera_zoom(0.42))
    zoom_controls.add_child(zoom_out)
    var zoom_reset := Button.new()
    zoom_reset.text = "맞춤"
    zoom_reset.custom_minimum_size = Vector2(68, 42)
    zoom_reset.pressed.connect(func(): _reset_camera())
    zoom_controls.add_child(zoom_reset)

    var pan_mode_button := Button.new()
    pan_mode_button.text = "회전"
    pan_mode_button.custom_minimum_size = Vector2(68, 42)
    pan_mode_button.pressed.connect(func():
        camera_pan_mode = not camera_pan_mode
        pan_mode_button.text = "이동" if camera_pan_mode else "회전"
        notice.text = "한 손가락 드래그로 시야 이동" if camera_pan_mode else "한 손가락 드래그로 회전"
    )
    zoom_controls.add_child(pan_mode_button)
    var focus_button := Button.new()
    focus_button.text = "개체"
    focus_button.custom_minimum_size = Vector2(68, 42)
    focus_button.pressed.connect(func(): _focus_mantis_camera())
    zoom_controls.add_child(focus_button)

    var pan_pad := GridContainer.new()
    pan_pad.columns = 3
    pan_pad.anchor_left = 1.0
    pan_pad.anchor_top = 1.0
    pan_pad.anchor_right = 1.0
    pan_pad.anchor_bottom = 1.0
    pan_pad.offset_left = -158.0
    pan_pad.offset_top = -158.0
    pan_pad.offset_right = -10.0
    pan_pad.offset_bottom = -10.0
    pan_pad.add_theme_constant_override("h_separation", 4)
    pan_pad.add_theme_constant_override("v_separation", 4)
    root_ui.add_child(pan_pad)
    var pad_up_space := Control.new()
    pad_up_space.custom_minimum_size = Vector2(44, 44)
    pan_pad.add_child(pad_up_space)
    var pad_up := Button.new()
    pad_up.text = "▲"
    pad_up.custom_minimum_size = Vector2(44, 44)
    pad_up.pressed.connect(func(): _move_camera_direction(Vector2(0, 1)))
    pan_pad.add_child(pad_up)
    var pad_top_space := Control.new()
    pad_top_space.custom_minimum_size = Vector2(44, 44)
    pan_pad.add_child(pad_top_space)
    var pad_left := Button.new()
    pad_left.text = "◀"
    pad_left.custom_minimum_size = Vector2(44, 44)
    pad_left.pressed.connect(func(): _move_camera_direction(Vector2(-1, 0)))
    pan_pad.add_child(pad_left)
    var pad_center := Button.new()
    pad_center.text = "◎"
    pad_center.custom_minimum_size = Vector2(44, 44)
    pad_center.pressed.connect(func(): _focus_mantis_camera())
    pan_pad.add_child(pad_center)
    var pad_right := Button.new()
    pad_right.text = "▶"
    pad_right.custom_minimum_size = Vector2(44, 44)
    pad_right.pressed.connect(func(): _move_camera_direction(Vector2(1, 0)))
    pan_pad.add_child(pad_right)
    var pad_bottom_left_space := Control.new()
    pad_bottom_left_space.custom_minimum_size = Vector2(44, 44)
    pan_pad.add_child(pad_bottom_left_space)
    var pad_down := Button.new()
    pad_down.text = "▼"
    pad_down.custom_minimum_size = Vector2(44, 44)
    pad_down.pressed.connect(func(): _move_camera_direction(Vector2(0, -1)))
    pan_pad.add_child(pad_down)
    var pad_bottom_right_space := Control.new()
    pad_bottom_right_space.custom_minimum_size = Vector2(44, 44)
    pan_pad.add_child(pad_bottom_right_space)

func _resize_ui() -> void:
    if ui_panel == null:
        return
    var screen := get_viewport().get_visible_rect().size
    ui_panel.position = Vector2(16, 74)
    ui_panel.size = Vector2(minf(320.0, screen.x * 0.68), maxf(100.0, screen.y - 94.0))


# Reusable simple leaf mesh: six triangles with a raised midrib and pointed tip.
func _build_leaf_detail_textures() -> void:
    var tex_width := 128
    var tex_height := 256
    var height_values := PackedFloat32Array()
    height_values.resize(tex_width * tex_height)
    var albedo_image := Image.create(tex_width, tex_height, false, Image.FORMAT_RGBA8)
    for y in range(tex_height):
        var t: float = float(y) / float(tex_height - 1)
        for x in range(tex_width):
            var u: float = float(x) / float(tex_width - 1) * 2.0 - 1.0
            var central_vein: float = exp(-pow(absf(u) / 0.024, 2.0))
            var side_vein := 0.0
            var side_sign: float = -1.0 if u < 0.0 else 1.0
            for vein_index in range(8):
                var root_t: float = 0.12 + float(vein_index) * 0.105
                var vein_t: float = root_t + absf(u) * 0.075 + side_sign * absf(u) * 0.012
                var distance_to_vein: float = absf(t - vein_t)
                side_vein = maxf(side_vein, exp(-pow(distance_to_vein / 0.006, 2.0)) * clampf(1.0 - absf(u) * 1.6, 0.0, 1.0))
            var noise_value: float = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
            noise_value = (fposmod(noise_value, 1.0) * 2.0 - 1.0) * 0.018
            var edge_darkening: float = pow(absf(u), 3.0) * 0.07
            var pigment: float = clampf(0.94 + noise_value + central_vein * 0.055 - side_vein * 0.13 - edge_darkening, 0.72, 1.0)
            albedo_image.set_pixel(x, y, Color(clampf(pigment * 1.05, 0.0, 1.0), pigment, clampf(pigment * 0.91, 0.0, 1.0), 1.0))
            var grain: float = sin(float(x) * 0.41 + float(y) * 0.23) * 0.0012
            height_values[y * tex_width + x] = central_vein * 0.012 + side_vein * 0.004 + grain
    var normal_image := Image.create(tex_width, tex_height, false, Image.FORMAT_RGBA8)
    for y in range(tex_height):
        for x in range(tex_width):
            var left_value: float = height_values[y * tex_width + maxi(0, x - 1)]
            var right_value: float = height_values[y * tex_width + mini(tex_width - 1, x + 1)]
            var upper_value: float = height_values[maxi(0, y - 1) * tex_width + x]
            var lower_value: float = height_values[mini(tex_height - 1, y + 1) * tex_width + x]
            var normal := Vector3((left_value - right_value) * 5.0, (upper_value - lower_value) * 5.0, 1.0).normalized()
            normal_image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0))
    leaf_detail_texture = ImageTexture.create_from_image(albedo_image)
    leaf_normal_texture = ImageTexture.create_from_image(normal_image)

func _leaf_surface(u: float, t: float) -> Vector3:
    var safe_t: float = clampf(t, 0.0, 1.0)
    var taper: float = pow(maxf(0.0, sin(PI * safe_t)), 0.78)
    var edge_wave: float = 0.003 * sin(safe_t * PI * 24.0) * taper * pow(absf(u), 6.0)
    var width: float = 0.004 + taper * 0.122 + edge_wave
    var midrib: float = 0.018 * taper
    var cup: float = 0.010 * taper * (1.0 - absf(u))
    var natural_bend: float = 0.008 * sin(safe_t * TAU + 0.35) * taper
    var serration_lift: float = 0.002 * sin(safe_t * PI * 24.0) * taper * pow(absf(u), 6.0)
    return Vector3(u * width, midrib + cup + natural_bend + serration_lift, safe_t * 0.56)

func _leaf_surface_normal(u: float, t: float) -> Vector3:
    var u0: float = maxf(-1.0, u - 0.012)
    var u1: float = minf(1.0, u + 0.012)
    var t0: float = maxf(0.0, t - 0.003)
    var t1: float = minf(1.0, t + 0.003)
    var tangent_u := _leaf_surface(u1, t) - _leaf_surface(u0, t)
    var tangent_t := _leaf_surface(u, t1) - _leaf_surface(u, t0)
    var normal := tangent_t.cross(tangent_u).normalized()
    return normal if normal.y >= 0.0 else -normal

func _leaf_mesh() -> ArrayMesh:
    # Higher-density leaf surfaces have rolled edges, a lifted midrib, gentle
    # serrations, and normals that catch light across the blade.
    var vertices := PackedVector3Array()
    var colors := PackedColorArray()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var station_count := 25
    var lane_count := 10
    var rows: Array = []
    for station in range(station_count):
        var t: float = float(station) / float(station_count - 1)
        var row: Array[Vector3] = []
        for lane in range(lane_count + 1):
            var u: float = float(lane) / float(lane_count) * 2.0 - 1.0
            row.append(_leaf_surface(u, t))
        rows.append(row)
    for station in range(station_count - 1):
        var t0: float = float(station) / float(station_count - 1)
        var t1: float = float(station + 1) / float(station_count - 1)
        for lane in range(lane_count):
            var u0: float = float(lane) / float(lane_count) * 2.0 - 1.0
            var u1: float = float(lane + 1) / float(lane_count) * 2.0 - 1.0
            var p00: Vector3 = rows[station][lane]
            var p10: Vector3 = rows[station][lane + 1]
            var p11: Vector3 = rows[station + 1][lane + 1]
            var p01: Vector3 = rows[station + 1][lane]
            var uv00 := Vector2((u0 + 1.0) * 0.5, t0)
            var uv10 := Vector2((u1 + 1.0) * 0.5, t0)
            var uv11 := Vector2((u1 + 1.0) * 0.5, t1)
            var uv01 := Vector2((u0 + 1.0) * 0.5, t1)
            for entry in [[p00, uv00, u0, t0], [p10, uv10, u1, t0], [p11, uv11, u1, t1], [p00, uv00, u0, t0], [p11, uv11, u1, t1], [p01, uv01, u0, t1]]:
                var point: Vector3 = entry[0]
                var point_uv: Vector2 = entry[1]
                var point_u: float = entry[2]
                var point_t: float = entry[3]
                vertices.append(point)
                uv.append(point_uv)
                normals.append(_leaf_surface_normal(point_u, point_t))
                var edge_factor: float = pow(absf(point_u), 2.0)
                var central_vein: float = exp(-pow(absf(point_u) / 0.040, 2.0))
                var tone: float = 0.96 + 0.04 * sin(PI * point_t) - edge_factor * 0.06 + central_vein * 0.025
                colors.append(Color(tone, clampf(tone + 0.015, 0.0, 1.0), clampf(tone - 0.025, 0.0, 1.0), 1.0))
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
    habitat_root.add_child(habitat_motion_root)
    var rng := RandomNumberGenerator.new()
    rng.seed = 17012026
    var leaf_mesh := _leaf_mesh()
    var leaf_materials: Array[StandardMaterial3D] = []
    for tint in [Color(0.055, 0.18, 0.045), Color(0.09, 0.26, 0.065), Color(0.14, 0.34, 0.09), Color(0.20, 0.42, 0.12), Color(0.28, 0.34, 0.10), Color(0.32, 0.24, 0.07)]:
        var mat := _material(tint)
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.vertex_color_use_as_albedo = true
        mat.albedo_texture = leaf_detail_texture
        mat.normal_enabled = true
        mat.normal_texture = leaf_normal_texture
        mat.normal_scale = 0.12
        mat.roughness = 0.88
        leaf_materials.append(mat)
    var stem_material := _material(Color(0.24, 0.31, 0.15))
    var stem_mesh := CylinderMesh.new()
    stem_mesh.top_radius = 0.007
    stem_mesh.bottom_radius = 0.015
    stem_mesh.height = 1.0
    stem_mesh.radial_segments = 7
    var plant_clusters: Array[Vector2] = [Vector2(-2.22, -1.46), Vector2(-2.30, -0.55), Vector2(-2.15, 0.55), Vector2(-1.76, 1.48), Vector2(-0.88, 1.53), Vector2(0.20, 1.55), Vector2(1.28, 1.49), Vector2(2.20, 1.20), Vector2(2.25, 0.25), Vector2(2.22, -0.72), Vector2(1.82, -1.48), Vector2(0.70, -1.54), Vector2(-0.65, -1.50)]
    # Dense but irregular plant groups rise from the substrate into the canopy.
    # The center stays more open so the mantis remains readable at the larger scale.
    for i in range(45):
        var plant := Node3D.new()
        plant.name = "Plant_%02d" % i
        var plant_cluster: Vector2 = plant_clusters[rng.randi_range(0, plant_clusters.size() - 1)]
        var plant_angle: float = rng.randf_range(0.0, TAU)
        var plant_radius: float = rng.randf_range(0.04, 0.53)
        plant.position = Vector3(plant_cluster.x + cos(plant_angle) * plant_radius, -0.53, plant_cluster.y + sin(plant_angle) * plant_radius)
        plant.position.x = clampf(plant.position.x, -2.45, 2.45)
        plant.position.z = clampf(plant.position.z, -1.74, 1.74)
        plant.rotation.y = rng.randf_range(-PI, PI)
        habitat_motion_root.add_child(plant)
        var plant_type := i % 3
        var height: float = rng.randf_range(0.72, 1.52) if plant_type != 1 else rng.randf_range(0.38, 0.78)
        if plant_type != 1:
            var stem := MeshInstance3D.new()
            stem.mesh = stem_mesh
            stem.material_override = stem_material
            stem.position.y = height * 0.5
            stem.scale = Vector3(1.0, height, 1.0)
            plant.add_child(stem)
        if plant_type == 0:
            # Feathered fern fronds: several arched rachises with paired pinnae.
            var frond_count := rng.randi_range(3, 5)
            for frond_index in range(frond_count):
                var frond := Node3D.new()
                frond.name = "FernFrond_%d" % frond_index
                frond.position = Vector3(rng.randf_range(-0.04, 0.04), 0.10, rng.randf_range(-0.04, 0.04))
                frond.rotation.y = TAU * float(frond_index) / float(frond_count) + rng.randf_range(-0.35, 0.35)
                frond.rotation.x = rng.randf_range(-0.72, -0.30)
                plant.add_child(frond)
                var frond_length := rng.randf_range(0.62, 0.93)
                _segment(frond, Vector3.ZERO, Vector3(0.0, 0.05, frond_length), 0.0045, Color(0.29, 0.39, 0.18))
                for leaflet_index in range(5):
                    var t: float = 0.19 + float(leaflet_index) * 0.135
                    var rachis_z := frond_length * t
                    var rachis_y := 0.05 * t
                    for side_index in range(2):
                        var leaflet_side: float = -1.0 if side_index == 0 else 1.0
                        var pinna := Node3D.new()
                        pinna.position = Vector3(0.0, rachis_y, rachis_z)
                        pinna.rotation.y = leaflet_side * rng.randf_range(0.88, 1.20)
                        pinna.rotation.z = leaflet_side * rng.randf_range(-0.16, 0.16)
                        frond.add_child(pinna)
                        var leaflet := MeshInstance3D.new()
                        leaflet.mesh = leaf_mesh
                        leaflet.material_override = leaf_materials[rng.randi_range(0, 4)]
                        leaflet.scale = Vector3(rng.randf_range(0.48, 0.68), 0.78, rng.randf_range(0.72, 0.94))
                        leaflet.rotation.x = -0.18
                        leaflet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                        pinna.add_child(leaflet)
                plant_pivots.append(frond)
                plant_phases.append(rng.randf_range(0.0, TAU))
                plant_stiffness.append(rng.randf_range(0.65, 1.15))
        elif plant_type == 1:
            # Low rosettes add broad leaves, mossy groundcover and young shoots.
            var leaf_count := rng.randi_range(7, 10)
            for j in range(leaf_count):
                var leaf_joint := Node3D.new()
                leaf_joint.position = Vector3(0.0, rng.randf_range(0.04, 0.12), 0.0)
                leaf_joint.rotation.y = TAU * float(j) / float(leaf_count) + rng.randf_range(-0.34, 0.34)
                leaf_joint.rotation.x = rng.randf_range(-0.58, -0.20)
                leaf_joint.rotation.z = rng.randf_range(-0.18, 0.18)
                plant.add_child(leaf_joint)
                var leaf := MeshInstance3D.new()
                leaf.mesh = leaf_mesh
                leaf.material_override = leaf_materials[rng.randi_range(0, leaf_materials.size() - 1)]
                leaf.scale = Vector3(rng.randf_range(1.02, 1.62), 0.9, rng.randf_range(1.45, 2.20))
                leaf.rotation.x = rng.randf_range(-0.24, -0.06)
                leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                leaf_joint.add_child(leaf)
                plant_pivots.append(leaf_joint)
                plant_phases.append(rng.randf_range(0.0, TAU))
                plant_stiffness.append(rng.randf_range(0.40, 0.85))
        else:
            # Narrow stems and alternating leaves break up the repeated bush shape.
            var leaf_count := rng.randi_range(6, 9)
            for j in range(leaf_count):
                var leaf_joint := Node3D.new()
                leaf_joint.position = Vector3(rng.randf_range(-0.055, 0.055), height * (0.24 + 0.66 * float(j) / float(leaf_count)), 0.0)
                leaf_joint.rotation.y = rng.randf_range(-PI, PI)
                leaf_joint.rotation.z = rng.randf_range(-0.30, 0.30)
                plant.add_child(leaf_joint)
                var leaf := MeshInstance3D.new()
                leaf.mesh = leaf_mesh
                leaf.material_override = leaf_materials[rng.randi_range(0, leaf_materials.size() - 1)]
                leaf.scale = Vector3(rng.randf_range(0.76, 1.20), 0.84, rng.randf_range(1.06, 1.62))
                leaf.rotation.x = rng.randf_range(-0.32, -0.05)
                leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                leaf_joint.add_child(leaf)
                plant_pivots.append(leaf_joint)
                plant_phases.append(rng.randf_range(0.0, TAU))
                plant_stiffness.append(rng.randf_range(0.5, 1.0))
        plant_pivots.append(plant)
        plant_phases.append(rng.randf_range(0.0, TAU))
        plant_stiffness.append(rng.randf_range(0.35, 0.8))
    # A few climbing vines hang from the rear branches and connect the layers.
    for vine_index in range(8):
        var vine := Node3D.new()
        vine.name = "HangingVine_%02d" % vine_index
        vine.position = Vector3(rng.randf_range(-2.1, 2.1), rng.randf_range(1.10, 1.72), rng.randf_range(-1.62, -1.25))
        vine.rotation.y = rng.randf_range(-PI, PI)
        habitat_motion_root.add_child(vine)
        var vine_length := rng.randf_range(0.65, 1.35)
        _segment(vine, Vector3.ZERO, Vector3(rng.randf_range(-0.18, 0.18), -vine_length, 0.0), 0.004, Color(0.21, 0.32, 0.16))
        for leaf_index in range(5):
            var leaf := MeshInstance3D.new()
            leaf.mesh = leaf_mesh
            leaf.material_override = leaf_materials[rng.randi_range(0, leaf_materials.size() - 1)]
            leaf.position = Vector3(rng.randf_range(-0.13, 0.13), -vine_length * float(leaf_index + 1) / 6.0, 0.0)
            leaf.rotation = Vector3(-0.35, rng.randf_range(-PI, PI), rng.randf_range(-0.2, 0.2))
            leaf.scale = Vector3(0.86, 0.82, rng.randf_range(0.75, 1.2))
            leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            vine.add_child(leaf)
    # Ambient motes use shared meshes and stay sparse enough for mobile GPUs.
    var mote_mesh := SphereMesh.new()
    mote_mesh.radial_segments = 5
    mote_mesh.rings = 3
    var mote_mat := _material(Color(0.68, 0.67, 0.44))
    mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for i in range(20):
        var mote := Node3D.new()
        var visual := MeshInstance3D.new()
        visual.mesh = mote_mesh
        visual.scale = Vector3.ONE * rng.randf_range(0.003, 0.008)
        visual.material_override = mote_mat
        mote.add_child(visual)
        mote.position = Vector3(rng.randf_range(-2.35, 2.35), rng.randf_range(-0.3, 1.85), rng.randf_range(-1.68, 1.68))
        habitat_motion_root.add_child(mote)
        drifting_particles.append(mote)
        particle_origins.append(mote.position)

func _create_habitat_details() -> void:
    # Slim dark frame bars mark the much larger enclosure without blocking it.
    var frame_color := Color(0.14, 0.18, 0.16)
    for x in [-2.57, 2.57]:
        for z in [-1.87, 1.87]:
            _segment(habitat_root, Vector3(x, -0.53, z), Vector3(x, 2.14, z), 0.014, frame_color)
    for y in [-0.53, 2.14]:
        for z in [-1.87, 1.87]:
            _segment(habitat_root, Vector3(-2.57, y, z), Vector3(2.57, y, z), 0.014, frame_color)
        for x in [-2.57, 2.57]:
            _segment(habitat_root, Vector3(x, y, -1.87), Vector3(x, y, 1.87), 0.014, frame_color)
    var root := Node3D.new()
    root.name = "SubstrateDetails"
    habitat_root.add_child(root)
    var rng := RandomNumberGenerator.new()
    rng.seed = 240619
    var stone_mat := _material(Color(0.25, 0.25, 0.21))
    stone_mat.albedo_texture = stone_texture
    _apply_pbr(stone_mat, "stone")
    var litter_materials: Array[StandardMaterial3D] = []
    for tint in [Color(0.25, 0.22, 0.13), Color(0.34, 0.29, 0.16), Color(0.18, 0.25, 0.16), Color(0.40, 0.31, 0.18), Color(0.13, 0.23, 0.17)]:
        var litter_material := _material(tint)
        litter_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        litter_material.vertex_color_use_as_albedo = true
        litter_materials.append(litter_material)
    var stone_mesh := SphereMesh.new()
    stone_mesh.radial_segments = 8
    stone_mesh.rings = 4
    var leaf_mesh := _leaf_mesh()
    var litter_clusters: Array[Vector2] = [Vector2(-2.17, -1.42), Vector2(-2.27, -0.50), Vector2(-2.12, 0.54), Vector2(-1.67, 1.45), Vector2(-0.66, 1.47), Vector2(0.75, 1.45), Vector2(1.85, 1.38), Vector2(2.17, 0.42), Vector2(2.22, -0.58), Vector2(1.73, -1.43), Vector2(0.55, -1.46), Vector2(-0.72, -1.43)]
    for i in range(168):
        var item := MeshInstance3D.new()
        var litter_cluster: Vector2 = litter_clusters[rng.randi_range(0, litter_clusters.size() - 1)]
        var litter_angle: float = rng.randf_range(0.0, TAU)
        var litter_radius: float = rng.randf_range(0.03, 0.55)
        item.position = Vector3(clampf(litter_cluster.x + cos(litter_angle) * litter_radius, -2.45, 2.45), -0.535, clampf(litter_cluster.y + sin(litter_angle) * litter_radius, -1.74, 1.74))
        item.rotation.y = rng.randf_range(-PI, PI)
        if i % 6 == 0:
            item.mesh = stone_mesh
            item.material_override = stone_mat
            item.scale = Vector3(rng.randf_range(0.030, 0.075), rng.randf_range(0.010, 0.023), rng.randf_range(0.028, 0.073))
        else:
            item.mesh = leaf_mesh
            item.material_override = litter_materials[rng.randi_range(0, litter_materials.size() - 1)]
            item.scale = Vector3(rng.randf_range(0.36, 0.84), 0.22, rng.randf_range(0.48, 1.18))
        root.add_child(item)
    for i in range(20):
        var twig_cluster: Vector2 = litter_clusters[rng.randi_range(0, litter_clusters.size() - 1)]
        var twig_angle: float = rng.randf_range(0.0, TAU)
        var twig_start := Vector3(twig_cluster.x + rng.randf_range(-0.35, 0.35), -0.525, twig_cluster.y + rng.randf_range(-0.28, 0.28))
        var twig_end := twig_start + Vector3(cos(twig_angle), 0.0, sin(twig_angle)) * rng.randf_range(0.10, 0.30)
        _segment(root, twig_start, twig_end, rng.randf_range(0.003, 0.007), Color(0.30, 0.22, 0.13))

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

func _create_feeder_insect(prey: Node3D, size_factor: float, body_color: Color) -> void:
    # Cricket-like feeder anatomy: a shielded thorax, plated abdomen, paired
    # tegmina, long filiform antennae, cerci, and three distinct leg pairs.
    var model := Node3D.new()
    model.name = "CricketAnatomy"
    model.scale = Vector3.ONE * size_factor
    prey.add_child(model)

    var shell := body_color
    var shell_light := body_color.lightened(0.20)
    var shell_dark := body_color.darkened(0.28)
    var underside := body_color.darkened(0.42)
    _part(model, Vector3(0.0, -0.002, 0.064), Vector3(0.042, 0.027, 0.094), shell)
    _part(model, Vector3(0.0, 0.003, -0.043), Vector3(0.034, 0.026, 0.052), shell_light)
    # Broad, shield-like pronotum with a raised rim and a clear head plate.
    _part(model, Vector3(0.0, 0.014, -0.048), Vector3(0.041, 0.009, 0.044), shell_light)
    _segment(model, Vector3(-0.034, 0.022, -0.068), Vector3(0.034, 0.022, -0.068), 0.0021, shell_dark)
    _part(model, Vector3(0.0, 0.009, -0.085), Vector3(0.038, 0.030, 0.040), shell_light)
    _part(model, Vector3(0.0, -0.025, 0.048), Vector3(0.034, 0.012, 0.086), underside)
    # Six layered tergites taper toward the rear; paired pleural marks read as
    # real abdominal side plates rather than a smooth oval under the wings.
    for band in range(7):
        var t: float = float(band) / 6.0
        var z: float = 0.002 + t * 0.137
        var taper: float = 0.96 - t * 0.38
        var plate_color: Color = shell_light if band % 2 == 0 else shell
        _part(model, Vector3(0.0, 0.006, z), Vector3(0.040 * taper, 0.025 * taper, 0.018), plate_color)
        _segment(model, Vector3(-0.034 * taper, -0.003, z + 0.011), Vector3(0.034 * taper, -0.003, z + 0.011), 0.0018, shell_dark)
        for side in [-1.0, 1.0]:
            _part(model, Vector3(side * 0.036 * taper, -0.004, z + 0.002), Vector3(0.0035, 0.004, 0.004), shell_dark)
            _part(model, Vector3(side * 0.034 * taper, 0.010, z), Vector3(0.003, 0.003, 0.005), shell_dark)
    # Paired leathery forewings overlap over the abdomen, with costa, veins,
    # short crossbars, and a visible center seam.
    var wing_pivots: Array[Node3D] = []
    for side in [-1.0, 1.0]:
        var wing_root := Node3D.new()
        wing_root.name = "FeederWing_%d" % int(side)
        wing_root.position = Vector3(side * 0.012, 0.026, 0.016)
        wing_root.set_meta("side", side)
        model.add_child(wing_root)
        _part(wing_root, Vector3(side * 0.018, 0.0, 0.046), Vector3(0.024, 0.005, 0.090), shell.lightened(0.10))
        _segment(wing_root, Vector3(side * 0.003, 0.005, 0.004), Vector3(side * 0.028, 0.005, 0.126), 0.0018, shell_light)
        for vein in range(7):
            var t: float = float(vein) / 6.0
            var x: float = side * (0.004 + t * 0.030)
            _segment(wing_root, Vector3(side * (0.003 + t * 0.009), 0.0055, 0.006), Vector3(x, 0.0055, 0.122 - t * 0.012), 0.0010, shell_dark)
        for cross_index in range(5):
            var z: float = 0.030 + float(cross_index) * 0.019
            _segment(wing_root, Vector3(side * 0.008, 0.0058, z), Vector3(side * 0.024, 0.0058, z + 0.009), 0.0009, shell_dark)
        if side > 0.0:
            _segment(wing_root, Vector3(0.0, 0.006, 0.012), Vector3(0.0, 0.006, 0.122), 0.0015, shell_dark)
        wing_pivots.append(wing_root)
    # Faceted eyes, mandibles, and paired palps define the small head.
    for side in [-1.0, 1.0]:
        _part(model, Vector3(side * 0.032, 0.020, -0.098), Vector3(0.013, 0.015, 0.014), Color(0.045, 0.055, 0.035))
        _part(model, Vector3(side * 0.036, 0.025, -0.102), Vector3(0.0035, 0.004, 0.004), shell_light)
        _part(model, Vector3(side * 0.014, -0.015, -0.112), Vector3(0.007, 0.005, 0.009), shell_dark)
        _segment(model, Vector3(side * 0.014, -0.018, -0.112), Vector3(side * 0.021, -0.031, -0.124), 0.0022, underside)
        _segment(model, Vector3(side * 0.022, -0.012, -0.111), Vector3(side * 0.031, -0.024, -0.120), 0.0020, shell_dark)
    var antenna_roots: Array[Node3D] = []
    for side in [-1.0, 1.0]:
        var antenna := Node3D.new()
        antenna.name = "Feeler_%d" % int(side)
        antenna.position = Vector3(side * 0.015, 0.027, -0.106)
        model.add_child(antenna)
        var previous := Vector3.ZERO
        for segment_index in range(14):
            var t: float = float(segment_index + 1) / 14.0
            var tip := Vector3(side * (0.020 + 0.052 * t + 0.018 * sin(t * PI)), 0.040 * t, -0.34 * t)
            _segment(antenna, previous, tip, 0.0024 * (1.0 - 0.62 * t), shell_dark)
            previous = tip
        antenna_roots.append(antenna)
    # A pair of fine rear cerci extends beyond the last abdominal plate.
    for side in [-1.0, 1.0]:
        var base := Vector3(side * 0.014, 0.0, 0.145)
        _segment(model, base, base + Vector3(side * 0.036, 0.012, 0.105), 0.0035, shell_dark)
        _segment(model, base + Vector3(side * 0.036, 0.012, 0.105), base + Vector3(side * 0.045, 0.016, 0.142), 0.0021, shell_dark)

    var leg_hips: Array[Node3D] = []
    var leg_knees: Array[Node3D] = []
    for side in [-1.0, 1.0]:
        for leg_index in range(3):
            var hip := Node3D.new()
            hip.name = "LegHip_%d_%d" % [int(side), leg_index]
            hip.position = Vector3(side * 0.025, -0.008, -0.058 + float(leg_index) * 0.060)
            model.add_child(hip)
            var hind := leg_index == 2
            var knee_offset := Vector3(side * (0.102 if hind else 0.061), -0.032, -0.018 if leg_index == 0 else (0.043 if hind else 0.014))
            var ankle_offset := Vector3(side * (0.154 if hind else 0.078), -0.095, 0.096 if hind else 0.036)
            var leg_tint := shell_light if hind else shell
            var coxa_tip := Vector3(side * 0.022, -0.004, 0.008)
            _ellipsoid_limb(hip, Vector3.ZERO, coxa_tip, 0.008, shell_dark)
            _part(hip, coxa_tip, Vector3(0.009, 0.008, 0.009), shell_light)
            _ellipsoid_limb(hip, coxa_tip, knee_offset, 0.024 if hind else 0.011, leg_tint)
            if hind:
                var femur_mid := coxa_tip.lerp(knee_offset, 0.55)
                _segment(hip, femur_mid + Vector3(0.0, 0.010, -0.004), femur_mid + Vector3(0.0, 0.010, 0.018), 0.0020, shell_dark)
                _part(hip, femur_mid, Vector3(0.014, 0.013, 0.025), shell_light)
            _part(hip, knee_offset, Vector3(0.009, 0.009, 0.009), shell_dark)
            var knee := Node3D.new()
            knee.name = "LegKnee_%d_%d" % [int(side), leg_index]
            knee.position = knee_offset
            hip.add_child(knee)
            var tibia_vector := ankle_offset - knee_offset
            _ellipsoid_limb(knee, Vector3.ZERO, tibia_vector, 0.0072 if hind else 0.0055, shell_dark)
            _part(knee, ankle_offset - knee_offset, Vector3(0.005, 0.005, 0.005), shell_light)
            if leg_index == 0:
                # Cricket tympanum on the fore tibia, framed by a raised rim.
                var ear_center := tibia_vector * 0.55 + Vector3(side * 0.005, 0.004, 0.0)
                _part(knee, ear_center, Vector3(0.0035, 0.0065, 0.013), shell_light)
                _part(knee, ear_center + Vector3(side * 0.002, 0.0, 0.0), Vector3(0.0016, 0.0042, 0.009), shell_dark)
            # Tibial spines occur in opposing rows, with larger apical spurs
            # on the jumping legs and fine paired claws on every foot.
            for spur_index in range(5 if hind else 3):
                var t: float = 0.17 + float(spur_index) * (0.14 if hind else 0.22)
                var point := tibia_vector * t
                var spur_length: float = 0.017 if hind else 0.009
                _segment(knee, point, point + Vector3(side * spur_length, 0.004, -0.007), 0.0022 if hind else 0.0015, shell_light)
                if hind:
                    _segment(knee, point, point + Vector3(-side * spur_length * 0.72, 0.004, 0.006), 0.0018, shell_dark)
            if hind:
                for spur_side in [-1.0, 1.0]:
                    _segment(knee, tibia_vector * 0.90, tibia_vector * 0.90 + Vector3(side * 0.020, 0.004, spur_side * 0.012), 0.0023, shell_light)
            var toe_end := ankle_offset + Vector3(side * (0.046 if hind else 0.038), -0.010, 0.048 if hind else 0.024)
            var ankle_local := ankle_offset - knee_offset
            var toe_local := toe_end - knee_offset
            for tarsomere_index in range(3):
                var t0: float = float(tarsomere_index) / 3.0
                var t1: float = float(tarsomere_index + 1) / 3.0
                _ellipsoid_limb(knee, ankle_local.lerp(toe_local, t0), ankle_local.lerp(toe_local, t1), 0.0033 - float(tarsomere_index) * 0.0004, shell_dark)
                _part(knee, ankle_local.lerp(toe_local, t1), Vector3(0.0028, 0.0028, 0.0028), shell_light)
            _segment(knee, toe_local, toe_local + Vector3(side * 0.012, -0.002, 0.014), 0.0018, shell_dark)
            _segment(knee, toe_local, toe_local + Vector3(-side * 0.007, -0.002, 0.015), 0.0016, shell_dark)
            leg_hips.append(hip)
            leg_knees.append(knee)
    prey_appendages[prey.get_instance_id()] = {
        "hips": leg_hips,
        "knees": leg_knees,
        "antennae": antenna_roots,
        "wings": wing_pivots
    }

func _create_prey_appendages(prey: Node3D) -> void:
    _create_feeder_insect(prey, 0.62, Color(0.35, 0.24, 0.13))

func _animate_prey_appendages(prey: Node3D, velocity: Vector3) -> void:
    var rig: Dictionary = prey_appendages.get(prey.get_instance_id(), {})
    var hips: Array = rig.get("hips", [])
    var knees: Array = rig.get("knees", [])
    var antenna_roots: Array = rig.get("antennae", [])
    var wing_pivots: Array = rig.get("wings", [])
    var speed := clampf(velocity.length() * 5.0, 0.0, 1.0)
    for i in range(hips.size()):
        var phase := prey_motion_clock * (15.0 + speed * 8.0) + float(i % 3) * 1.65 + (PI if i >= 3 else 0.0)
        var hip: Node3D = hips[i]
        var knee: Node3D = knees[i]
        hip.rotation.z = sin(phase) * (0.035 + speed * 0.26)
        knee.rotation.z = 0.06 + sin(phase + 0.8) * (0.035 + speed * 0.18)
    for i in range(antenna_roots.size()):
        var antenna: Node3D = antenna_roots[i]
        antenna.rotation.y = sin(prey_motion_clock * 2.8 + float(i) * PI) * (0.06 + speed * 0.22)
        antenna.rotation.x = sin(prey_motion_clock * 2.1 + float(i)) * 0.04
    for i in range(wing_pivots.size()):
        var wing: Node3D = wing_pivots[i]
        var side := float(wing.get_meta("side"))
        wing.rotation.z = side * sin(prey_motion_clock * 18.0) * speed * 0.12

func _button(parent: VBoxContainer, label_text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(260, 48)
    # Let a vertical drag begun over a button bubble to the parent
    # ScrollContainer; Button still emits `pressed` for a tap.
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(func():
        if suppress_menu_click:
            suppress_menu_click = false
            return
        callback.call()
    )
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
            animal.scale = Vector3.ONE * (0.32 * (0.80 + growth * 0.30))
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
    elif animation_preview == "FLY":
        _advance_flight(dt)
        behavior = "비행 시연"
    elif animation_preview == "FEED":
        behavior = "먹이 먹기 시연"
        if feed_demo_prey != null and is_instance_valid(feed_demo_prey):
            feed_demo_prey.position = Vector3(0.0, 0.16 + sin(animation_clock * 2.4) * 0.002, -0.66)
            _animate_prey_appendages(feed_demo_prey, Vector3.ZERO)
    elif animation_preview == "CLIMB":
        _advance_climb(dt, true)
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
            animal.position.x = clampf(animal.position.x, -WALK_BOUND_X, WALK_BOUND_X)
            animal.position.z = clampf(animal.position.z, -WALK_BOUND_Z, WALK_BOUND_Z)
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
        roam_target = Vector3(randf_range(-2.02, 2.02), -0.38, randf_range(-1.28, 1.28))
    var direction := roam_target - animal.position
    if direction.length() > 0.03:
        animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), dt * 3.0)
        animal.position = animal.position.move_toward(roam_target, dt * 0.085)
        animal.position.x = clampf(animal.position.x, -WALK_BOUND_X, WALK_BOUND_X)
        animal.position.z = clampf(animal.position.z, -WALK_BOUND_Z, WALK_BOUND_Z)
        energy = maxf(0.0, energy - dt * 0.3)

func _input(event: InputEvent) -> void:
    if menu_scroll == null or not ui_panel.visible:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if menu_scroll.get_global_rect().has_point(event.position):
                menu_touch_index = event.index
                menu_touch_start = event.position
                menu_touch_last = event.position
                menu_touch_dragging = false
        elif event.index == menu_touch_index:
            if menu_touch_dragging:
                suppress_menu_click = true
                call_deferred("_clear_menu_click_suppression")
            menu_touch_index = -1
            menu_touch_dragging = false
    elif event is InputEventScreenDrag and event.index == menu_touch_index:
        if not menu_touch_dragging and menu_touch_start.distance_to(event.position) > 10.0:
            menu_touch_dragging = true
        if menu_touch_dragging:
            var delta_y: float = event.position.y - menu_touch_last.y
            var bar := menu_scroll.get_v_scroll_bar()
            menu_scroll.scroll_vertical = clampi(menu_scroll.scroll_vertical - roundi(delta_y), 0, int(bar.max_value))
            menu_touch_last = event.position
            get_viewport().set_input_as_handled()

func _clear_menu_click_suppression() -> void:
    suppress_menu_click = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var direction := Vector2.ZERO
        if event.keycode == KEY_W or event.keycode == KEY_UP:
            direction.y = 1.0
        elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
            direction.y = -1.0
        elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
            direction.x = -1.0
        elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
            direction.x = 1.0
        if direction != Vector2.ZERO:
            _move_camera_direction(direction)
            get_viewport().set_input_as_handled()
            return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _set_camera_zoom(-0.35)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _set_camera_zoom(0.35)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if editing:
                if event.pressed:
                    edit_mouse_start = event.position
                    edit_mouse_moved = false
                elif not edit_mouse_moved and edit_mouse_start.distance_to(event.position) < 16.0:
                    _place_at_screen(event.position)
            touching = event.pressed and not editing
            mouse_pan_active = false
            pointer_last = event.position
        elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
            touching = event.pressed and not editing
            mouse_pan_active = event.pressed and not editing
            pointer_last = event.position
    elif event is InputEventMouseMotion:
        if editing and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            if edit_mouse_start.distance_to(event.position) > 16.0:
                edit_mouse_moved = true
        elif touching:
            if mouse_pan_active or camera_pan_mode:
                _pan_camera(event.relative)
            else:
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
        pan_center_previous = Vector2.ZERO
    elif event is InputEventScreenDrag:
        touch_points[event.index] = event.position
        if editing and (touch_points.size() > 1 or edit_touch_start.distance_to(event.position) > 20.0):
            edit_touch_moved = true
        if touch_points.size() == 1:
            if camera_pan_mode:
                _pan_camera(event.relative)
            else:
                _orbit(event.relative)
        elif touch_points.size() == 2:
            var points := touch_points.values()
            var point_a: Vector2 = points[0]
            var point_b: Vector2 = points[1]
            var midpoint: Vector2 = (point_a + point_b) * 0.5
            var distance: float = point_a.distance_to(point_b)
            if pinch_previous > 0.0:
                orbit_distance = clampf(orbit_distance - (distance - pinch_previous) * 0.014, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
                _pan_camera(midpoint - pan_center_previous)
            pinch_previous = distance
            pan_center_previous = midpoint
    _update_camera()

func _orbit(motion: Vector2) -> void:
    orbit_yaw -= motion.x * 0.008
    orbit_pitch = clampf(orbit_pitch + motion.y * 0.006, -1.42, 1.42)

func _pan_camera(motion: Vector2) -> void:
    if camera == null:
        return
    var right := camera.global_transform.basis.x.normalized()
    var up := camera.global_transform.basis.y.normalized()
    var pan_scale: float = orbit_distance * 0.0014
    _apply_camera_translation(-right * motion.x * pan_scale + up * motion.y * pan_scale)

func _move_camera_direction(direction: Vector2) -> void:
    var right := Vector3(cos(orbit_yaw), 0.0, -sin(orbit_yaw))
    var forward := Vector3(-sin(orbit_yaw), 0.0, -cos(orbit_yaw))
    var step: float = maxf(0.16, orbit_distance * 0.045)
    _apply_camera_translation((right * direction.x + forward * direction.y) * step)

func _apply_camera_translation(delta: Vector3) -> void:
    var center := _camera_center() + delta
    center.x = clampf(center.x, -5.5, 5.5)
    center.y = clampf(center.y, -0.72, 4.0)
    center.z = clampf(center.z, -4.2, 4.2)
    if follow_animal and animal != null:
        camera_pan_offset = center - (animal.position + Vector3(0, 0.35, 0))
    else:
        camera_target = center
    _update_camera()

func _camera_center() -> Vector3:
    if follow_animal and animal != null:
        return animal.position + Vector3(0, 0.35, 0) + camera_pan_offset
    return camera_target

func _toggle_follow_camera() -> void:
    if animal == null:
        return
    if follow_animal:
        camera_target = _camera_center()
        camera_pan_offset = Vector3.ZERO
        follow_animal = false
    else:
        camera_pan_offset = camera_target - (animal.position + Vector3(0, 0.35, 0))
        follow_animal = true
    _update_camera()

func _focus_mantis_camera() -> void:
    if animal == null:
        return
    follow_animal = true
    camera_pan_offset = Vector3.ZERO
    orbit_distance = 1.8
    _update_camera()

func _fit_enclosure_distance() -> float:
    var vertical_fov: float = deg_to_rad(camera.fov)
    var screen := get_viewport().get_visible_rect().size
    var aspect: float = maxf(0.45, screen.x / maxf(1.0, screen.y))
    var horizontal_fov: float = 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
    var vertical_distance: float = 3.15 / tan(vertical_fov * 0.5)
    var horizontal_distance: float = 4.35 / tan(horizontal_fov * 0.5)
    return clampf(maxf(vertical_distance, horizontal_distance) * 1.12, 7.5, CAMERA_MAX_DISTANCE)

func _reset_camera() -> void:
    follow_animal = false
    camera_pan_offset = Vector3.ZERO
    camera_target = Vector3(0, 0.20, 0)
    orbit_yaw = 0.0
    orbit_pitch = 0.30
    orbit_distance = _fit_enclosure_distance()
    _update_camera()

func _set_camera_zoom(distance_delta: float) -> void:
    orbit_distance = clampf(orbit_distance + distance_delta, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
    _update_camera()

func _update_camera() -> void:
    if camera == null:
        return
    var center := _camera_center()
    camera.position = center + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
    camera.look_at(center, Vector3.UP)
func _orbit(motion: Vector2) -> void:
    orbit_yaw -= motion.x * 0.008
    orbit_pitch = clampf(orbit_pitch + motion.y * 0.006, -0.15, 1.05)

func _set_camera_zoom(distance_delta: float) -> void:
    orbit_distance = clampf(orbit_distance + distance_delta, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
    _update_camera()

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
                var x: float = clampf(float(entry.get("x", 0.0)), -2.45, 2.45)
                var z: float = clampf(float(entry.get("z", 0.0)), -1.75, 1.75)
                if kind in ["rock", "wood"]:
                    _add_decoration(kind, Vector3(x, -0.50, z))
    life_age = maxf(0.0, float(parsed.get("life_age", 0.0)))
    molt_count = clampi(int(parsed.get("molt_count", 0)), 0, 5)
    growth = clampf(float(parsed.get("growth", 0.35)), 0.35, 1.0)
    animal.scale = Vector3.ONE * (0.32 * (0.80 + growth * 0.30))
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
                _spawn_prey(Vector3(clampf(float(coords[0]), -PREY_BOUND_X, PREY_BOUND_X), -0.38, clampf(float(coords[2]), -PREY_BOUND_Z, PREY_BOUND_Z)))
        food_count = prey_nodes.size()
    else:
        _sync_prey()
    var pos: Variant = parsed.get("animal_position", [])
    if pos is Array and pos.size() == 3:
        animal.position = Vector3(clampf(float(pos[0]), -WALK_BOUND_X, WALK_BOUND_X), -0.38, clampf(float(pos[2]), -WALK_BOUND_Z, WALK_BOUND_Z))
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
    _spawn_prey(Vector3(randf_range(-1.95, 1.95), -0.38, randf_range(-1.22, 1.22)))
    food_count = prey_nodes.size()
    _refresh()

func _spawn_prey(pos: Vector3) -> void:
    var prey := Node3D.new()
    prey.name = "Prey_%d" % prey_nodes.size()
    prey.position = pos
    add_child(prey)
    var palettes: Array[Color] = [Color(0.35, 0.24, 0.13), Color(0.28, 0.22, 0.12), Color(0.40, 0.23, 0.13)]
    _create_feeder_insect(prey, 0.62, palettes[prey_nodes.size() % palettes.size()])
    prey_nodes.append(prey)
    if habitat_interactions != null:
        habitat_interactions.register_prey(prey)
    prey_velocities[prey.get_instance_id()] = Vector3(randf_range(-0.13, 0.13), 0, randf_range(-0.13, 0.13))

func _sync_prey() -> void:
    while prey_nodes.size() < food_count:
        _spawn_prey(Vector3(randf_range(-1.95, 1.95), -0.38, randf_range(-1.22, 1.22)))
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
    var previous_clip := animation_preview
    if clip != "FEED" and feed_demo_prey != null and is_instance_valid(feed_demo_prey):
        prey_appendages.erase(feed_demo_prey.get_instance_id())
        feed_demo_prey.queue_free()
        feed_demo_prey = null
    if previous_clip == "FLY" and clip != "FLY":
        animal.position = flight_start_position
        animal.rotation = Vector3(0.0, flight_start_yaw, 0.0)
        _initialize_foot_anchors()
    if clip in ["FLY", "FEED", "CLIMB"]:
        climb_active = false
        if clip != "FLY":
            animal.quaternion = Quaternion.IDENTITY
        if clip != "CLIMB":
            animal.position.y = -0.38
    if clip == "CLIMB":
        climb_cooldown = 0.0
        climb_progress = 0.0
        climb_direction = 1.0
        climb_pause = 0.0
    if clip == "FLY":
        flight_demo_clock = 0.0
        animal.position.y = -0.38
        animal.rotation.x = 0.0
        animal.rotation.z = 0.0
        flight_start_position = animal.position
        flight_start_yaw = animal.rotation.y
    animation_preview = clip
    animation_clock = 0.0
    if clip == "FEED":
        _ensure_feed_demo_prey()
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
        var side: float = -1.0 if i < 2 else 1.0
        var leg_index: int = i % 2
        var foot_z: float = -0.10 if leg_index == 0 else 0.16
        var world := leg_pivots[i].to_global(Vector3(side * 0.32, -0.27, foot_z))
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
    var flight_t: float = clampf(flight_demo_clock / FLIGHT_TAKEOFF_DURATION, 0.0, 1.0) if next_state == "FLY" else 0.0
    var flight_pose_blend: float = flight_t * flight_t * (3.0 - 2.0 * flight_t)
    movement_blend = move_toward(movement_blend, 1.0 if walking else 0.0, dt * 3.0)
    walking_phase += dt * (3.2 if next_state == "CLIMB" else 5.5 if next_state == "HUNT" else 7.0)
    foot_contact_hits = 0
    # Climbing feet are placed on the branch cylinder; flight legs tuck beneath
    # the thorax rather than reaching toward a stale floor contact.
    for i in range(leg_pivots.size()):
        var joint := leg_pivots[i]
        var side: float = -1.0 if i < 2 else 1.0
        var index: int = i % 2
        var foot := Vector3.ZERO
        var foot_world := Vector3.ZERO
        if next_state == "FLY":
            var grounded_foot := Vector3(side * 0.32, -0.27, -0.10 if index == 0 else 0.16)
            var tucked_foot := Vector3(side * 0.15, -0.12, 0.03 if index == 0 else 0.13)
            foot = grounded_foot.lerp(tucked_foot, flight_pose_blend)
            foot_anchors[i] = joint.to_global(foot)
            foot_in_swing[i] = false
        elif next_state == "CLIMB" and climb_active:
            var axis := climb_branch_end - climb_branch_start
            var step_phase := walking_phase + float(i % 2) * PI + (PI if i >= 2 else 0.0)
            var t_axis := clampf(climb_progress + (0.105 if index == 0 else -0.105) + sin(step_phase) * 0.025, 0.0, 1.0)
            var on_axis := climb_branch_start + axis * t_axis
            var outward := animal.global_basis.y.normalized()
            var lateral := animal.global_basis.x.normalized() * side
            var contact_normal := (outward * 0.62 + lateral * 0.78).normalized()
            foot_world = on_axis + contact_normal * 0.067
            foot_anchors[i] = foot_world
            foot_in_swing[i] = false
            foot = joint.to_local(foot_world)
        elif next_state == "FEED":
            # Keep all four walking feet on their resting contacts while the
            # capture pair folds around food; cancel any stride already queued.
            var rest_local := Vector3(side * 0.32, -0.27, -0.10 if index == 0 else 0.16)
            foot_world = joint.to_global(rest_local)
            foot_world.y = _raycast_foot_height(foot_world) if foot_contacts_enabled else -0.45
            foot_anchors[i] = foot_world
            foot_in_swing[i] = false
            foot = joint.to_local(foot_world)
        else:
            # World-space stance locking holds the four walking feet while the
            # body moves. Raycasts find their next foothold on the floor/rocks.
            var tripod: int = (index + (0 if i < 2 else 1)) % 2
            var phase := fposmod(walking_phase + float(tripod) * PI, TAU)
            var swing_window := phase < PI
            var rest_local := Vector3(side * 0.32, -0.27, -0.10 if index == 0 else 0.16)
            var desired_world := joint.to_global(rest_local)
            desired_world.y = _raycast_foot_height(desired_world) if foot_contacts_enabled else -0.45
            var drift := foot_anchors[i].distance_to(desired_world)
            if walking and swing_window and not foot_in_swing[i] and drift > 0.055:
                foot_in_swing[i] = true
                foot_swing_origins[i] = foot_anchors[i]
                foot_swing_progress[i] = 0.0
            foot_world = foot_anchors[i]
            if foot_in_swing[i]:
                foot_swing_progress[i] = minf(1.0, foot_swing_progress[i] + dt / FOOT_SWING_DURATION)
                var t := foot_swing_progress[i]
                var eased := t * t * (3.0 - 2.0 * t)
                foot_world = foot_swing_origins[i].lerp(desired_world, eased)
                foot_world.y += sin(t * PI) * step_height
                if t >= 1.0:
                    foot_in_swing[i] = false
                    foot_anchors[i] = desired_world
            else:
                foot_world = foot_anchors[i]
                if walking and drift > FOOT_REPLANT_DISTANCE:
                    foot_anchors[i] = desired_world
                    foot_world = desired_world
            foot = joint.to_local(foot_world)
        var reach := foot.length()
        if reach > 0.795:
            foot = foot / reach * 0.795
        var knee := _solve_leg_knee(Vector3.ZERO, foot, 0.31, 0.49, side)
        _pose_gait_bone(gait_segments[i][0], Vector3.ZERO, knee)
        _pose_gait_bone(gait_segments[i][1], knee, foot)
        var tarsus_offset := Vector3(side * lerpf(0.085, 0.045, flight_pose_blend), lerpf(-0.014, 0.032, flight_pose_blend), -0.025 if index == 0 else 0.025)
        var tarsus_end := foot + tarsus_offset
        var tarsomeres: Array = foot_tarsi[i]
        for segment_index in range(tarsomeres.size()):
            var t0: float = float(segment_index) / float(tarsomeres.size())
            var t1: float = float(segment_index + 1) / float(tarsomeres.size())
            _pose_gait_bone(tarsomeres[segment_index], foot.lerp(tarsus_end, t0), foot.lerp(tarsus_end, t1))
        var claws: Array = foot_claws[i]
        _pose_gait_bone(claws[0], tarsus_end, tarsus_end + Vector3(side * 0.020, -0.004, -0.018))
        _pose_gait_bone(claws[1], tarsus_end, tarsus_end + Vector3(-side * 0.020, -0.004, -0.018))
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
                # Both capture arms cradle one insect together; the paired
                # forelegs make a small synchronized adjustment while feeding.
                target_pitch = -0.42 + sin(animation_clock * 2.8) * 0.025
                target_yaw = (0.09 if i == 0 else -0.09)
            "CLIMB":
                target_pitch = -0.48 + sin(walking_phase + float(i) * PI) * 0.14
            "FLY":
                target_pitch = lerpf(-0.12, -0.64 + sin(animation_clock * 1.9) * 0.035, flight_pose_blend)
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
            "GROOM":
                elbow_target = -0.65 + sin(animation_clock * 9.0 + float(i) * PI) * 0.28
                claw_target = 0.8 + sin(animation_clock * 9.0 + float(i) * PI) * 0.35
            "FEED":
                elbow_target = -0.62 + sin(animation_clock * 2.7) * 0.035
                claw_target = 0.86 + sin(animation_clock * 3.1) * 0.045
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
                elbow_target = -0.78 + sin(walking_phase + float(i) * PI) * 0.28
                claw_target = 1.0 + sin(walking_phase + float(i) * PI) * 0.20
            "FLY":
                elbow_target = lerpf(-0.25, -0.82, flight_pose_blend)
                claw_target = lerpf(0.38, 1.16, flight_pose_blend)
        foreleg_elbows[i].rotation.x = lerpf(foreleg_elbows[i].rotation.x, elbow_target, clampf(dt * 11.0, 0.0, 1.0))
        foreleg_claws[i].rotation.x = lerpf(foreleg_claws[i].rotation.x, claw_target, clampf(dt * 13.0, 0.0, 1.0))
    for i in range(antennae.size()):
        var antenna_speed := 5.5 if next_state == "ALERT" else 2.3
        var amplitude := 0.29 if next_state == "ALERT" else 0.16
        antennae[i].rotation.y = sin(elapsed * antenna_speed + float(i) * 1.5) * amplitude
    for i in range(mandibles.size()):
        var chew_motion: float = sin(animation_clock * 6.2 + float(i) * PI) * 0.12 if next_state == "FEED" else 0.0
        mandibles[i].rotation.y = lerpf(mandibles[i].rotation.y, chew_motion, clampf(dt * 12.0, 0.0, 1.0))
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
        var head_pitch := -0.14 if next_state == "HUNT" else -0.22 if next_state == "FEED" else 0.0
        head_pivot.rotation.x = lerpf(head_pivot.rotation.x, head_pitch, clampf(dt * 4.0, 0.0, 1.0))
    if thorax_pivot != null:
        var thorax_target := sin(elapsed * 1.6) * 0.012
        if next_state in ["ALERT", "DEFEND"]:
            thorax_target += 0.11
        elif next_state == "STRIKE":
            thorax_target -= 0.16
        elif next_state == "FEED":
            thorax_target -= 0.045
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
            abdomen_target += sin(animation_clock * 2.6) * 0.012
        abdomen.rotation.x = lerpf(abdomen.rotation.x, abdomen_target, clampf(dt * 4.0, 0.0, 1.0))
    if next_state == "FEED" and feed_demo_prey != null and is_instance_valid(feed_demo_prey):
        feed_demo_prey.position = Vector3(0.0, 0.20 + sin(animation_clock * 2.4) * 0.0015, -0.70)
    for wing_pivot in wing_pivots:
        var wing_side := float(wing_pivot.get_meta("wing_side"))
        var is_hindwing := bool(wing_pivot.get_meta("hindwing"))
        var desired_spread: float = lerpf(0.36, 1.0, flight_pose_blend) if is_hindwing else 1.0
        wing_pivot.scale.x = lerpf(wing_pivot.scale.x, desired_spread, clampf(dt * 5.0, 0.0, 1.0))
        var flap_amplitude: float = (0.70 if is_hindwing else 0.56) * flight_pose_blend
        var target_flap := sin(animation_clock * 36.0 + (0.34 if is_hindwing else 0.0)) * flap_amplitude * wing_side if next_state == "FLY" else sin(elapsed * 1.4 + (PI if is_hindwing else 0.0)) * 0.025 * wing_side
        wing_pivot.rotation.z = lerpf(wing_pivot.rotation.z, target_flap, clampf(dt * 22.0, 0.0, 1.0))
    if not (next_state == "CLIMB" and climb_active):
        var body_roll_target := sin(elapsed * 5.0) * 0.05 if molting else sin(animation_clock * 0.85) * 0.065 * flight_pose_blend if next_state == "FLY" else 0.0
        var body_pitch_target := (-0.08 - sin(animation_clock * 1.6) * 0.028) * flight_pose_blend if next_state == "FLY" else -0.035 if next_state == "FEED" else 0.0
        animal.rotation.z = lerpf(animal.rotation.z, body_roll_target, clampf(dt * 4.0, 0.0, 1.0))
        animal.rotation.x = lerpf(animal.rotation.x, body_pitch_target, clampf(dt * 3.2, 0.0, 1.0))
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
        prey.position.x = clampf(prey.position.x + velocity.x * dt, -PREY_BOUND_X, PREY_BOUND_X)
        prey.position.z = clampf(prey.position.z + velocity.z * dt, -PREY_BOUND_Z, PREY_BOUND_Z)
        if velocity.length_squared() > 0.001:
            prey.rotation.y = lerp_angle(prey.rotation.y, atan2(-velocity.x, -velocity.z), dt * 3.2)
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
    if absf(point.x) > 2.45 or absf(point.z) > 1.75:
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
