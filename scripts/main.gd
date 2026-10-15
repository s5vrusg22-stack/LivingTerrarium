Warning: truncated output (original token count: 38030)
Total output lines: 3143

extends Node3D

const SAVE_PATH := "user://terrarium_save_v8.json"
const BACKUP_PATH := "user://terrarium_save_v8_backup.json"
const V6_SAVE_PATH := "user://terrarium_save_v6.json"
const V6_BACKUP_PATH := "user://terrarium_save_v6_backup.json"
const V5_SAVE_PATH := "user://terrarium_save_v5.json"
const V4_SAVE_PATH := "user://terrarium_save_v4.json"
const MANTIS_COLLECTION_PATH := "user://mantis_collection_v1.json"
const MANTIS_COLLECTION_BACKUP_PATH := "user://mantis_collection_v1_backup.json"
const MAX_SAVED_MANTISES := 24
const MAX_DECORATIONS := 32
const PREVIOUS_SAVE_PATH := "user://terrarium_save_v3.json"
const LEGACY_SAVE_PATH := "user://terrarium_save_v2.json"
const MAX_FOOD := 12
const HABITAT_LINEAR_SCALE := 5.31 # About 30x the current enclosure volume; height rises with footprint.
const HERMIT_TANK_LINEAR_SCALE := 2.714 # cbrt(20).
const SALAMANDER_TANK_LINEAR_SCALE := 3.107 # cbrt(30).
const HABITAT_WIDTH := 9.6 * HABITAT_LINEAR_SCALE
const HABITAT_DEPTH := 6.8 * HABITAT_LINEAR_SCALE
const HABITAT_HALF_X := 4.70 * HABITAT_LINEAR_SCALE
const HABITAT_HALF_Z := 3.30 * HABITAT_LINEAR_SCALE
const HABITAT_CEILING_Y := 3.45 * HABITAT_LINEAR_SCALE
const HABITAT_WALL_HEIGHT := HABITAT_CEILING_Y + 0.55
const HABITAT_WALL_CENTER_Y := (HABITAT_CEILING_Y - 0.55) * 0.5
const ROAM_HALF_X := HABITAT_HALF_X - 1.10
const ROAM_HALF_Z := HABITAT_HALF_Z - 0.85
const CAMERA_MIN_DISTANCE := 1.35
const CAMERA_MAX_DISTANCE := 110.0
const CAMERA_MOVE_SPEED := 4.5
const CAMERA_BOOST_MULTIPLIER := 3.0
const LIFE_STAGES: Array[String] = ["1령 약충", "2령 약충", "3령 약충", "4령 약충", "5령 약충", "6령 약충", "성체"]
const NYMPH_SIZE_FACTORS: Array[float] = [0.23, 0.30, 0.40, 0.52, 0.67, 0.84]
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
var orbit_yaw := 1.43
var orbit_pitch := 0.26
var orbit_distance := 3.15
var camera_pan := Vector3.ZERO
var camera_touch_directions: Dictionary = {}
var pointer_last := Vector2.ZERO
var touching := false
var touch_points: Dictionary = {}
var pinch_previous := 0.0
var camera_mouse_dragging := false
var camera_touch_points: Dictionary = {}
var camera_pinch_previous := 0.0
var roam_target := Vector3.ZERO
var roam_time := 0.0
var elapsed := 0.0
var legs: Array[Node3D] = []
var antennae: Array[Node3D] = []
var root_ui: Control
var prey_nodes: Array[Node3D] = []
var feeding_timer := 0.0
var autosave_timer := 0.0
var follow_animal := true
var habitat_framing := false
var strike_time := 0.0
var life_age := 0.0
var molt_count := 0
var life_stage := "성체"
var stage_picker: OptionButton
var mantis_save_picker: OptionButton
var mantis_name_input: LineEdit
var saved_mantises: Array[Dictionary] = []
var juvenile_wing_buds: Node3D
var rigged_wing_buds: Node3D
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
# Procedural fallback poses are retained for motion references; the canonical GLB
# supplies its own animated FLY clip and remains the visible mantis model.
const ANIMATIONS := ["IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND", "FLY"]
const FRONT_LEG_VARIANT_COUNT := 100
var animation_preview := "AUTO"
var animation_clock := 0.0
var animation_weight := 0.0
var animation_state := "IDLE"
var preview_strike_clock := 0.0
var animation_label: Label
var frontleg_animation_label: Label
var selected_frontleg_animation := -1
var model_details: Array[Node3D] = []
var body_texture: Texture2D
var cuticle_detail_texture: Texture2D
var cuticle_detail_normal_texture: Texture2D
var cuticle_detail_roughness_texture: Texture2D
var wing_detail_texture: Texture2D
var eye_texture: Texture2D
var foliage_texture: Texture2D
var foliage_normal_texture: Texture2D
var foliage_roughness_texture: Texture2D
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
const BASE1_RIGGED_SCENE: PackedScene = preload("res://assets/models/base1.glb")
const BASE1_MANTIS_SCENE: PackedScene = preload("res://assets/models/base1.glb")
const PHOTO_SIDE_CUTOUT: Texture2D = preload("res://assets/photo_cutouts/mantis_side_photo.png")
const PHOTO_DORSAL_CUTOUT: Texture2D = preload("res://assets/photo_cutouts/mantis_dorsal_photo.png")
const BASE1_MANTIS_MODEL_SCALE := 1.0
const AQUARIUM_SYSTEM_SCRIPT = preload("res://scripts/aquarium_system.gd")
const BLUE_CRAYFISH_HABITAT_SCRIPT = preload("res://scripts/blue_crayfish_habitat.gd")
const BUTTERFLY_SYSTEM_SCRIPT = preload("res://scripts/butterfly_system.gd")
const HERMIT_CRAB_SYSTEM_SCRIPT = preload("res://scripts/hermit_crab_system.gd")
const STREAM_SALAMANDER_SYSTEM_SCRIPT = preload("res://scripts/stream_valley_system.gd")
var rigged_visual: Node3D
var rigged_player: AnimationPlayer
var rigged_clip := ""
var use_rigged_visual := false
var rigged_available := false
var rigged_clips: Dictionary = {}
var procedural_meshes: Array[MeshInstance3D] = []
var rigged_import_warnings: Array[String] = []
var visual_model_scale := 1.0
var photo_visual: Sprite3D
var photo_visual_dorsal: Sprite3D
var photo_motion_clock := 0.0
var photo_pose_last := ""
var use_photo_visual := false
# v2.5: runtime rig pose adaptation, applied after the GLB animation player.
var rigged_pose_driver: RiggedPoseDriver
var rigged_skeleton: Skeleton3D
var rigged_ik_enabled := true
var rigged_pose_status := "not initialized"
var base1_mantis_visual: Node3D
var base1_mantis_player: AnimationPlayer
var base1_mantis_clips: Dictionary = {}
var base1_mantis_clip := ""
var use_base1_mantis_visual := true
var social_partner: Node3D
var social_partner_player: AnimationPlayer
var social_partner_clip := ""
var manual_command := ""
var command_timer := 0.0
var command_elapsed := 0.0
var command_origin_rotation := Quaternion.IDENTITY
var flight_demo_active := false
var flight_demo_clock := 0.0
var flight_start_position := Vector3.ZERO
var flight_start_rotation := Quaternion.IDENTITY
# v2.6: scripted traversal of a real, collidable inclined branch.
var climb_active := false
var climb_progress := 0.0
var climb_cooldown := 18.0
var climb_branch_start := Vector3(-0.18, -0.43, 0.60)
var climb_branch_end := Vector3(-0.02, HABITAT_CEILING_Y * 0.82, 0.52)
const CLIMB_SPEED := 0.18
const CLIMB_BODY_CLEARANCE := 0.48







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
var aquarium_system: Node3D
var butterfly_system: Node3D
var hermit_crab_system: Node3D
var stream_salamander_system: Node3D
var blue_crayfish_habitat: Node3D
var mantis_environment_roots: Array[Node3D] = []
var current_species := "mantis"
var species_selector: OptionButton
var mantis_controls: VBoxContainer
var aquarium_controls: VBoxContainer
var crayfish_controls: VBoxContainer
var butterfly_controls: VBoxContainer
var hermit_crab_controls: VBoxContainer
var stream_salamander_controls: VBoxContainer
var reference_overlay: Control
var reference_panel: PanelContainer
var reference_photo_view: TextureRect
var camera_hint: Label


func _ready() -> void:
    _load_textures()
    _create_world()
    aquarium_system = AQUARIUM_SYSTEM_SCRIPT.new()
    aquarium_system.name = "AquariumSystem"
    aquarium_system.visible = false
    add_child(aquarium_system)
    blue_crayfish_habitat = BLUE_CRAYFISH_HABITAT_SCRIPT.new()
    blue_crayfish_habitat.name = "BlueCrayfishHabitat"
    blue_crayfish_habitat.visible = false
    blue_crayfish_habitat.set("paused", simulation_paused)
    blue_crayfish_habitat.set_process(false)
    add_child(blue_crayfish_habitat)
    butterfly_system = BUTTERFLY_SYSTEM_SCRIPT.new()
    butterfly_system.name = "ButterflyGardenSystem"
    butterfly_system.visible = false
    add_child(butterfly_system)
    hermit_crab_system = HERMIT_CRAB_SYSTEM_SCRIPT.new()
    hermit_crab_system.name = "LandHermitCrabTankSystem"
    hermit_crab_system.scale = Vector3.ONE * HERMIT_TANK_LINEAR_SCALE
    hermit_crab_system.visible = false
    add_child(hermit_crab_system)
    stream_salamander_system = STREAM_SALAMANDER_SYSTEM_SCRIPT.new()
    stream_salamander_system.name = "StreamValleySalamanderSystem"
    stream_salamander_system.scale = Vector3.ONE * SALAMANDER_TANK_LINEAR_SCALE
    stream_salamander_system.visible = false
    add_child(stream_salamander_system)
    terrain_root = Node3D.new()
    terrain_root.name = "UserDecorations"
    add_child(terrain_root)
    _create_floor_collider()
    _create_climbable_branch()
    _create_mantis()
    _initialize_photo_visual()
    _initialize_rigged_visual()
    _initialize_base1_mantis_visual()
    _create_juvenile_wing_buds()
    _apply_life_stage()
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
    _cache_mantis_environment_roots()
    _set_species_mode(0, false)
    # Start on the approved Base 1 model so its model details are visible.
    # The habitat overview remains available from the management menu.
    _set_camera_preset(true)
    _refresh()

func _initialize_rigged_visual() -> void:
    # Keep procedural geometry available if GLB import or clip discovery fails.
    procedural_meshes.clear()
    _collect_procedural_meshes(animal)
    var imported := BASE1_RIGGED_SCENE.instantiate()
    if not imported is Node3D:
        rigged_import_warnings.append("GLB root is not Node3D")
        return
    rigged_visual = imported as Node3D
    rigged_visual.name = "Base1RiggedVisual"
    animal.add_child(rigged_visual)
    _style_rigged_materials(rigged_visual)
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
        if not use_photo_visual:
            _play_rigged_clip("IDLE")

func _initialize_base1_mantis_visual() -> void:
    var imported := BASE1_MANTIS_SCENE.instantiate()
    if not imported is Node3D:
        rigged_import_warnings.append("Base 1 GLB root is not Node3D")
        return
    base1_mantis_visual = imported as Node3D
    base1_mantis_visual.name = "Base1"
    base1_mantis_visual.position = Vector3.ZERO
    base1_mantis_visual.rotation = Vector3.ZERO
    base1_mantis_visual.scale = Vector3.ONE * BASE1_MANTIS_MODEL_SCALE
    animal.add_child(base1_mantis_visual)
    _style_rigged_materials(base1_mantis_visual)
    base1_mantis_player = _find_rigged_player(base1_mantis_visual)
    if base1_mantis_player == null:
        rigged_import_warnings.append("Base 1 GLB has no AnimationPlayer")
        base1_mantis_visual.visible = false
        return
    for library_name in base1_mantis_player.get_animation_library_list():
        var library := base1_mantis_player.get_animation_library(library_name)
        if library == null:
            continue
        for clip_name in library.get_animation_list():
            var full_name := String(clip_name)
            if not String(library_name).is_empty():
                full_name = String(library_name) + "/" + full_name
            var normalized := String(clip_name).to_upper()
            base1_mantis_clips[normalized] = full_name
            var animation := library.get_animation(clip_name)
            if animation != null:
                animation.loop_mode = Animation.LOOP_LINEAR if normalized in ["IDLE", "WALK", "ALERT", "GROOM", "FEED", "FLY"] else Animation.LOOP_NONE
    if base1_mantis_clips.is_empty():
        rigged_import_warnings.append("Base 1 GLB has no animation clips")
        base1_mantis_visual.visible = false
        return
    _apply_visual_mode()
    _play_base1_mantis_clip("IDLE")

func _initialize_photo_visual() -> void:
    # Use the user's cropped, pixel-preserving side and dorsal photos in-world.
    photo_visual = Sprite3D.new()
    photo_visual.name = "Base1MantisSidePhotoCutout"
    photo_visual.texture = PHOTO_SIDE_CUTOUT
    photo_visual.position = Vector3(0.0, 1.05, 0.53) * BASE1_MANTIS_MODEL_SCALE
    photo_visual.pixel_size = 3.33 * BASE1_MANTIS_MODEL_SCALE / float(PHOTO_SIDE_CUTOUT.get_width())
    photo_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    photo_visual.shaded = false
    photo_visual.visible = false
    animal.add_child(photo_visual)

    photo_visual_dorsal = Sprite3D.new()
    photo_visual_dorsal.name = "Base1MantisDorsalPhoto"
    photo_visual_dorsal.texture = PHOTO_DORSAL_CUTOUT
    photo_visual_dorsal.position = Vector3(0.0, 1.30, 0.47) * BASE1_MANTIS_MODEL_SCALE
    photo_visual_dorsal.pixel_size = 3.33 * BASE1_MANTIS_MODEL_SCALE / float(PHOTO_DORSAL_CUTOUT.get_height())
    photo_visual_dorsal.rotation_degrees.x = -90.0
    photo_visual_dorsal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    photo_visual_dorsal.shaded = false
    photo_visual_dorsal.visible = false
    animal.add_child(photo_visual_dorsal)

func _update_photo_visual(delta: float) -> void:
    if photo_visual == null or photo_visual_dorsal == null or animal == null:
        return
    var use_dorsal := false
    if camera != null:
        var view_direction := (camera.global_position - animal.global_position).normalized()
        use_dorsal = view_direction.y > 0.70
        photo_visual.flip_h = camera.global_transform.basis.x.dot(-animal.global_transform.basis.z) < 0.0
    photo_visual.visible = use_photo_visual and not use_dorsal
    photo_visual_dorsal.visible = use_photo_visual and use_dorsal
    if delta <= 0.0:
        return
    var pose := animation_state
    if animation_preview != "AUTO":
        pose = animation_preview
    if pose != photo_pose_last:
        photo_pose_last = pose
        photo_motion_clock = 0.0
    photo_motion_clock += delta
    var phase := photo_motion_clock * (5.5 if pose in ["WALK", "CLIMB"] else 2.2)
    var offset := Vector3.ZERO
    var size_factor := 1.0
    match pose:
        "IDLE":
            offset.y = sin(phase) * 0.009
            size_factor = 1.0 + sin(phase) * 0.003
        "WALK", "CLIMB":
            offset.x = sin(phase) * 0.030
            offset.y = absf(sin(phase)) * 0.018
            offset.z = cos(phase) * 0.035
            size_factor = 1.0 + absf(sin(phase)) * 0.008
        "ALERT", "SCAN", "DEFEND":
            offset.y = 0.018 + sin(phase) * 0.005
            size_factor = 1.006
        "STRIKE", "HUNT":
            var strike := sin(minf(photo_motion_clock / 0.72, 1.0) * PI)
            offset.x = strike * 0.09
            offset.y = strike * 0.035
            size_factor = 1.0 + strike * 0.018
        "GROOM", "FEED":
            offset.y = sin(phase) * 0.010
            offset.x = sin(phase * 0.5) * 0.012
    photo_visual.position = (Vector3(0.0, 1.05, 0.53) + offset) * BASE1_MANTIS_MODEL_SCALE
    photo_visual_dorsal.position = (Vector3(0.0, 1.30, 0.47) + offset) * BASE1_MANTIS_MODEL_SCALE
    photo_visual.scale = Vector3.ONE * size_factor
    photo_visual_dorsal.scale = Vector3.ONE * size_factor

func _collect_procedural_meshes(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            procedural_meshes.append(child as MeshInstance3D)
        _collect_procedural_meshes(child)

func _style_rigged_materials(root: Node) -> void:
    # Preserve Base 1's per-surface palette. A shared material_override erased
    # those cuticle, face, eye, and wing differences and crushed color in shade.
    for child in root.get_children():
        if child is MeshInstance3D:
            var part := child as MeshInstance3D
            part.material_override = null
            if part.mesh != null:
                for surface_index in range(part.mesh.get_surface_count()):
                    var source := part.get_active_material(surface_index) as StandardMaterial3D
                    if source == null:
                        continue
                    var mat := source.duplicate() as StandardMaterial3D
                    if mat == null:
                        continue
                    var material_name := String(source.resource_name).to_lower()
                    # Keep the imported hue and let the GLB's chitin and wing
                    # roughness produce distinct, restrained specular highlights.
                    if material_name.contains("eye"):
                        mat.roughness = minf(mat.roughness, 0.30)
                    elif material_name.contains("wing"):
                        mat.roughness = minf(mat.roughness, 0.46)
                    elif material_name.contains("cuticle"):
                        mat.roughness = minf(mat.roughness, 0.48)
                    part.set_surface_override_material(surface_index, mat)
        _style_rigged_materials(child)

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
    # Lock the displayed animal to the recovered canonical GLB.
    use_photo_visual = false
    var show_photo := false
    var show_base1 := use_base1_mantis_visual and base1_mantis_visual != null and not base1_mantis_clips.is_empty()
    var show_rigged := not show_base1 and use_rigged_visual and rigged_available
    for part in procedural_meshes:
        if is_instance_valid(part):
            part.visible = false
    if rigged_visual != null:
        rigged_visual.visible = show_rigged
    if base1_mantis_visual != null:
        base1_mantis_visual.visible = show_base1
    if photo_visual != null:
        photo_visual.visible = show_photo and (camera == null or (camera.global_position - animal.global_position).normalized().y <= 0.70)
    if photo_visual_dorsal != null:
        photo_visual_dorsal.visible = show_photo and camera != null and (camera.global_position - animal.global_position).normalized().y > 0.70
    if rigged_player != null:
        if show_rigged:
            rigged_player.speed_scale = 1.0
        else:
            rigged_player.stop()
    if base1_mantis_player != null:
        if show_base1:
            base1_mantis_player.speed_scale = 1.0
        else:
            base1_mantis_player.stop()
    rigged_clip = ""
    base1_mantis_clip = ""
    if rigged_pose_driver != null:
        rigged_pose_driver.enabled = show_rigged and rigged_ik_enabled
        if not show_rigged:
            rigged_pose_driver.reset_offsets()

func _toggle_visual_model() -> void:
    use_photo_visual = false
    use_base1_mantis_visual = true
    use_rigged_visual = false
    _apply_visual_mode()
    if notice != null:
        notice.text = "Base 1 사마귀 모델을 사용합니다."

func _play_base1_mantis_clip(clip: String) -> void:
    if base1_mantis_player == null or base1_mantis_clips.is_empty():
        return
    var resolved := clip
    var aliases := {"MOLT": "IDLE", "HUNT": "STRIKE", "CLIMB": "WALK", "DEFEND": "ALERT", "SCAN": "ALERT"}
    if aliases.has(resolved):
        resolved = aliases[resolved]
    if not base1_mantis_clips.has(resolved):
        resolved = "IDLE"
    if not base1_mantis_clips.has(resolved) or base1_mantis_clip == resolved:
        return
    var animation_name: String = base1_mantis_clips[resolved]
    if not base1_mantis_player.has_animation(animation_name):
        rigged_import_warnings.append("Missing Base 1 clip: " + animation_name)
        return
    base1_mantis_player.play(animation_name, 0.18)
    base1_mantis_clip = resolved

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
    if use_base1_mantis_visual:
        if base1_mantis_visual == null or base1_mantis_clips.is_empty():
            return
        _play_base1_mantis_clip(animation_state)
        return
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
    cuticle_detail_texture = load("res://assets/textures/mantis_cuticle_detail_albedo.png")
    cuticle_detail_normal_texture = load("res://assets/textures/mantis_cuticle_detail_normal.png")
    cuticle_detail_roughness_texture = load("res://assets/textures/mantis_cuticle_detail_roughness.png")
    wing_detail_texture = load("res://assets/textures/mantis_wing_detail.png")
    eye_texture = load("res://assets/textures/mantis_eye_albedo_v49.png")
    foliage_texture = load("res://assets/textures/foliage_albedo.png")
    foliage_normal_texture = load("res://assets/textures/foliage_normal.png")
    foliage_roughness_texture = load("res://assets/textures/foliage_roughness.png")
    bark_texture = load("res://assets/textures/bark_albedo.png")
    substrate_texture = load("res://assets/textures/substrate_albedo.png")
    stone_texture = load("res://assets/textures/stone_albedo.png")
    for kind in ["mantis_cuticle", "mantis_eye", "bark", "substrate", "stone"]:
        pbr_normal[kind] = load("res://assets/textures/%s_normal.png" % kind)
        pbr_roughness[kind] = load("res://assets/textures/%s_roughness.png" % kind)

func _create_world() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 44.0
    add_child(camera)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.065, 0.085, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.50, 0.52, 0.46)
    env.ambient_light_energy = 0.38
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -31, 0)
    sun.light_color = Color(0.98, 0.97, 0.91)
    sun.light_energy = 0.68
    sun.shadow_opacity = 0.48
    sun.shadow_blur = 1.2
    sun.shadow_enabled = true
    add_child(sun)
    _box(Vector3(HABITAT_WIDTH, 0.2, HABITAT_DEPTH), Vector3(0, -0.65, 0), Color(0.39, 0.31, 0.21))
    _box(Vector3(HABITAT_WIDTH, HABITAT_WALL_HEIGHT, 0.06), Vector3(0, HABITAT_WALL_CENTER_Y, -HABITAT_HALF_Z), Color(0.14, 0.21, 0.17, 0.48), true)
    _box(Vector3(0.05, HABITAT_WALL_HEIGHT, HABITAT_DEPTH), Vector3(-HABITAT_HALF_X, HABITAT_WALL_CENTER_Y, 0), Color(0.36, 0.51, 0.45, 0.14), true)
    _box(Vector3(0.05, HABITAT_WALL_HEIGHT, HABITAT_DEPTH), Vector3(HABITAT_HALF_X, HABITAT_WALL_CENTER_Y, 0), Color(0.36, 0.51, 0.45, 0.14), true)
    for i in range(24):
        var column := i % 6
        var row := i / 6
        var x := (-3.78 + float(column) * 1.51) * HABITAT_LINEAR_SCALE
        var z := (-2.43 + float(row) * 1.62) * HABITAT_LINEAR_SCALE
        var height := (0.34 + float(i % 4) * 0.33) * HABITAT_LINEAR_SCALE
        _branch(Vector3(x, -0.43, z), Vector3(x + 0.28 * HABITAT_LINEAR_SCALE, height, z - 0.20 * HABITAT_LINEAR_SCALE), 0.036 * HABITAT_LINEAR_SCALE)
    var detail_rng := RandomNumberGenerator.new()
    detail_rng.seed = 8032026
    for i in range(26):
        var p := Vector3(detail_rng.randf_range(-4.48, 4.48) * HABITAT_LINEAR_SCALE, -0.49, detail_rng.randf_range(-3.08, 3.08) * HABITAT_LINEAR_SCALE)
        var size := detail_rng.randf_range(0.85, 1.35)
        _ellipsoid(p, Vector3(0.11, 0.04, 0.16) * size, Color(0.15 + 0.02 * (i % 3), 0.28, 0.105))

func _create_climbable_branch() -> void:
    # A tall living support plant. Its visible stem and foot-contact path share
    # the same geometry so the mantis can climb from the soil into the canopy.
    var stem_radius := 0.16
    var stem_color := Color(0.23, 0.34, 0.14)
    _segment(self, climb_branch_start, climb_branch_end, stem_radius, stem_color)
    _walkable_wood(self, climb_branch_start, climb_branch_end, stem_radius)
    var rng := RandomNumberGenerator.new()
    rng.seed = 10142026
    var leaf_mesh := _leaf_mesh()
    var leaf_material := _material(Color(0.83, 0.92, 0.68))
    leaf_material.vertex_color_use_as_albedo = true
    leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    leaf_material.albedo_texture = foliage_texture
    leaf_material.normal_enabled = foliage_normal_texture != null
    leaf_material.normal_texture = foliage_normal_texture
    leaf_material.normal_scale = 0.10
    leaf_material.roughness = 0.94
    for level in range(1, 8):
        var t := float(level) / 8.0
        var cent…23030 tokens truncated…[SAVE_PATH, BACKUP_PATH, V6_SAVE_PATH, V6_BACKUP_PATH, V5_SAVE_PATH, V4_SAVE_PATH, PREVIOUS_SAVE_PATH, LEGACY_SAVE_PATH]
    for path in candidates:
        if not FileAccess.file_exists(path):
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if parsed is Dictionary and int(parsed.get("version", 0)) in [2, 3, 4, 5, 6, 7, 8]:
            _restore_mantis_state(parsed, show_message, path in [BACKUP_PATH, V6_BACKUP_PATH])
            return
    if show_message:
        notice.text = "저장된 데이터가 없습니다."

func _restore_mantis_state(parsed: Dictionary, show_message: bool, recovered_backup: bool = false) -> void:
    _clear_decorations()
    var saved_decor: Variant = parsed.get("decorations", [])
    if saved_decor is Array:
        for entry in saved_decor:
            if entry is Dictionary and decorations.size() < MAX_DECORATIONS:
                var kind: String = str(entry.get("kind", "rock"))
                var x: float = clampf(float(entry.get("x", 0.0)), -ROAM_HALF_X, ROAM_HALF_X)
                var z: float = clampf(float(entry.get("z", 0.0)), -ROAM_HALF_Z, ROAM_HALF_Z)
                if kind in ["rock", "wood"]:
                    _add_decoration(kind, Vector3(x, -0.50, z))
    life_age = maxf(0.0, float(parsed.get("life_age", 0.0)))
    life_stage = String(parsed.get("life_stage", "성체"))
    if not LIFE_STAGES.has(life_stage):
        life_stage = "성체"
    molt_count = clampi(int(parsed.get("molt_count", 0)), 0, 6)
    growth = clampf(float(parsed.get("growth", 0.35)), 0.35, 1.0)
    _apply_life_stage()
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
                _spawn_prey(Vector3(clampf(float(coords[0]), -ROAM_HALF_X, ROAM_HALF_X), -0.38, clampf(float(coords[2]), -ROAM_HALF_Z, ROAM_HALF_Z)))
        food_count = prey_nodes.size()
    else:
        _sync_prey()
    var pos: Variant = parsed.get("animal_position", [])
    if pos is Array and pos.size() == 3:
        animal.position = Vector3(clampf(float(pos[0]), -ROAM_HALF_X, ROAM_HALF_X), -0.38, clampf(float(pos[2]), -ROAM_HALF_Z, ROAM_HALF_Z))
    if stage_picker != null:
        stage_picker.select(_life_stage_index())
    if show_message:
        notice.text = "불러오기 완료" + (" (백업 복구)" if recovered_backup else "")
    _refresh()

func _load_mantis_collection() -> void:
    saved_mantises.clear()
    for path in [MANTIS_COLLECTION_PATH, MANTIS_COLLECTION_BACKUP_PATH]:
        if not FileAccess.file_exists(path):
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
            continue
        var records: Variant = parsed.get("mantises", [])
        if records is Array:
            for entry in records:
                if entry is Dictionary and entry.get("state", null) is Dictionary and saved_mantises.size() < MAX_SAVED_MANTISES:
                    saved_mantises.append(entry.duplicate(true))
        break
    _refresh_mantis_collection_picker()

func _write_mantis_collection() -> bool:
    if FileAccess.file_exists(MANTIS_COLLECTION_PATH):
        var previous := FileAccess.get_file_as_string(MANTIS_COLLECTION_PATH)
        var backup := FileAccess.open(MANTIS_COLLECTION_BACKUP_PATH, FileAccess.WRITE)
        if backup != null:
            backup.store_string(previous)
            backup.close()
    var file := FileAccess.open(MANTIS_COLLECTION_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"version": 1, "mantises": saved_mantises}))
    file.close()
    return true

func _refresh_mantis_collection_picker(selected_index: int = -1) -> void:
    if mantis_save_picker == null:
        return
    mantis_save_picker.clear()
    for index in range(saved_mantises.size()):
        var record := saved_mantises[index]
        var state: Dictionary = record.get("state", {})
        mantis_save_picker.add_item("%02d · %s · %s" % [index + 1, String(record.get("name", "사마귀")), String(state.get("life_stage", "성체"))])
    if saved_mantises.is_empty():
        return
    var chosen := selected_index if selected_index >= 0 else mini(mantis_save_picker.selected, saved_mantises.size() - 1)
    chosen = clampi(chosen, 0, saved_mantises.size() - 1)
    mantis_save_picker.select(chosen)
    _on_mantis_profile_selected(chosen)

func _on_mantis_profile_selected(index: int) -> void:
    if index < 0 or index >= saved_mantises.size() or mantis_name_input == null:
        return
    mantis_name_input.text = String(saved_mantises[index].get("name", ""))

func _save_current_mantis_profile() -> void:
    if current_species != "mantis":
        notice.text = "사마귀 서식지에서 개체를 저장해 주세요."
        return
    if saved_mantises.size() >= MAX_SAVED_MANTISES:
        notice.text = "저장 슬롯은 최대 24개입니다. 기존 슬롯을 갱신하거나 삭제해 주세요."
        return
    var profile_name := mantis_name_input.text.strip_edges() if mantis_name_input != null else ""
    if profile_name.is_empty():
        profile_name = "사마귀 %02d" % (saved_mantises.size() + 1)
    saved_mantises.append({"id": str(Time.get_unix_time_from_system()), "name": profile_name, "state": _capture_mantis_state()})
    if not _write_mantis_collection():
        saved_mantises.pop_back()
        notice.text = "개체 저장 실패: 보관함 파일을 열 수 없습니다."
        return
    _refresh_mantis_collection_picker(saved_mantises.size() - 1)
    notice.text = "‘%s’ 개체를 보관함에 저장했습니다." % profile_name

func _load_selected_mantis_profile() -> void:
    if current_species != "mantis":
        notice.text = "사마귀 서식지에서 개체를 불러와 주세요."
        return
    if mantis_save_picker == null or mantis_save_picker.selected < 0 or mantis_save_picker.selected >= saved_mantises.size():
        notice.text = "먼저 불러올 개체를 선택해 주세요."
        return
    var profile: Dictionary = saved_mantises[mantis_save_picker.selected]
    var state: Variant = profile.get("state", {})
    if not (state is Dictionary):
        notice.text = "개체 저장 데이터가 손상되었습니다."
        return
    _save_state(false)
    var profile_state: Dictionary = state
    _restore_mantis_state(profile_state, false)
    notice.text = "‘%s’ 개체를 불러왔습니다." % String(profile.get("name", "사마귀"))

func _update_selected_mantis_profile() -> void:
    if mantis_save_picker == null or mantis_save_picker.selected < 0 or mantis_save_picker.selected >= saved_mantises.size():
        notice.text = "먼저 갱신할 개체를 선택해 주세요."
        return
    var index := mantis_save_picker.selected
    var previous: Dictionary = saved_mantises[index].duplicate(true)
    var profile_name := mantis_name_input.text.strip_edges() if mantis_name_input != null else ""
    if not profile_name.is_empty():
        saved_mantises[index]["name"] = profile_name
    saved_mantises[index]["state"] = _capture_mantis_state()
    if not _write_mantis_collection():
        saved_mantises[index] = previous
        notice.text = "개체 갱신 실패: 보관함 파일을 열 수 없습니다."
        return
    _refresh_mantis_collection_picker(index)
    notice.text = "선택한 개체의 정보를 갱신했습니다."

func _delete_selected_mantis_profile() -> void:
    if mantis_save_picker == null or mantis_save_picker.selected < 0 or mantis_save_picker.selected >= saved_mantises.size():
        notice.text = "먼저 삭제할 개체를 선택해 주세요."
        return
    var index := mantis_save_picker.selected
    var removed: Dictionary = saved_mantises[index]
    saved_mantises.remove_at(index)
    if not _write_mantis_collection():
        saved_mantises.insert(index, removed)
        notice.text = "개체 삭제 실패: 보관함 파일을 열 수 없습니다."
        return
    _refresh_mantis_collection_picker(mini(index, saved_mantises.size() - 1))
    if saved_mantises.is_empty() and mantis_name_input != null:
        mantis_name_input.clear()
    notice.text = "선택한 개체를 보관함에서 삭제했습니다."

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and animal != null:
        _save_state()

func _add_food() -> void:
    if prey_nodes.size() >= MAX_FOOD:
        notice.text = "먹이는 최대 12개까지 넣을 수 있습니다."
        return
    _spawn_prey(Vector3(randf_range(-ROAM_HALF_X, ROAM_HALF_X), -0.38, randf_range(-ROAM_HALF_Z, ROAM_HALF_Z)))
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
        _spawn_prey(Vector3(randf_range(-ROAM_HALF_X, ROAM_HALF_X), -0.38, randf_range(-ROAM_HALF_Z, ROAM_HALF_Z)))
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
        if base1_mantis_player != null and base1_mantis_clip == "STRIKE" and use_base1_mantis_visual:
            base1_mantis_player.seek(0.0, true)
    if animation_label != null:
        animation_label.text = "애니메이션: " + clip

func _set_frontleg_animation(index: int) -> void:
    if index < 0:
        selected_frontleg_animation = -1
        if rigged_pose_driver != null:
            rigged_pose_driver.stop_front_leg_animation()
        use_base1_mantis_visual = true
        use_rigged_visual = false
        _apply_visual_mode()
        if frontleg_animation_label != null:
            frontleg_animation_label.text = "앞다리 동작: Base 1 기본 포획 자세"
        return
    if not rigged_available or rigged_pose_driver == null:
        notice.text = "Base 1 앞다리 리그를 불러오지 못했습니다."
        return
    selected_frontleg_animation = posmod(index, FRONT_LEG_VARIANT_COUNT)
    if use_base1_mantis_visual:
        use_base1_mantis_visual = false
        use_rigged_visual = true
        _apply_visual_mode()
        notice.text = "Base 1 GLB에서 세부 앞다리 관절 시연을 재생합니다."
    if rigged_pose_driver != null:
        rigged_pose_driver.play_front_leg_animation(selected_frontleg_animation)
        if frontleg_animation_label != null:
            frontleg_animation_label.text = "앞다리 동작: %03d / 100 · %s" % [selected_frontleg_animation + 1, rigged_pose_driver.get_front_leg_animation_name()]
    elif frontleg_animation_label != null:
        frontleg_animation_label.text = "앞다리 동작: 리깅 모델을 불러오지 못했습니다"
    notice.text = "앞다리 애니메이션 %03d / 100 재생 중" % (selected_frontleg_animation + 1)

func _step_frontleg_animation(step: int) -> void:
    var next_index := selected_frontleg_animation + step
    if selected_frontleg_animation < 0:
        next_index = 0 if step >= 0 else FRONT_LEG_VARIANT_COUNT - 1
    _set_frontleg_animation(next_index)

func _restart_frontleg_animation() -> void:
    _set_frontleg_animation(0 if selected_frontleg_animation < 0 else selected_frontleg_animation)

func _resolve_animation() -> String:
    if molting:
        return "MOLT"
    match manual_command:
        "THREATEN":
            return "DEFEND"
        "FIGHT":
            return "STRIKE" if int(floor(command_elapsed / 1.1)) % 2 == 0 else "DEFEND"
        "MATE":
            return "IDLE"
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
                outward = Vector3.RIGHT
            desired_world = on_axis + outward.normalized() * 0.20
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
