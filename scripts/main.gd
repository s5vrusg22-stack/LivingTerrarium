extends Node3D

const SAVE_PATH := "user://terrarium_save_v6.json"
const BACKUP_PATH := "user://terrarium_save_v6_backup.json"
const V5_SAVE_PATH := "user://terrarium_save_v5.json"
const V4_SAVE_PATH := "user://terrarium_save_v4.json"
const MAX_DECORATIONS := 32
const PREVIOUS_SAVE_PATH := "user://terrarium_save_v3.json"
const LEGACY_SAVE_PATH := "user://terrarium_save_v2.json"
const MAX_FOOD := 12
const HABITAT_LINEAR_SCALE := 1.71 # cbrt(5): five times the original enclosure volume.
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
const CAMERA_MAX_DISTANCE := 60.0
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
const RIGGED_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")
const LATEST_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")
const PHOTO_SIDE_CUTOUT: Texture2D = preload("res://assets/photo_cutouts/mantis_side_photo.png")
const PHOTO_DORSAL_CUTOUT: Texture2D = preload("res://assets/photo_cutouts/mantis_dorsal_photo.png")
const LATEST_MANTIS_MODEL_SCALE := 1.0
const AQUARIUM_SYSTEM_SCRIPT = preload("res://scripts/aquarium_system.gd")
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
var latest_mantis_visual: Node3D
var latest_mantis_player: AnimationPlayer
var latest_mantis_clips: Dictionary = {}
var latest_mantis_clip := ""
var use_latest_mantis_visual := true
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
var aquarium_system: Node3D
var butterfly_system: Node3D
var hermit_crab_system: Node3D
var stream_salamander_system: Node3D
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
    _initialize_latest_mantis_visual()
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
    _set_camera_preset(false)
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

func _initialize_latest_mantis_visual() -> void:
    var imported := LATEST_MANTIS_SCENE.instantiate()
    if not imported is Node3D:
        rigged_import_warnings.append("Latest mantis GLB root is not Node3D")
        return
    latest_mantis_visual = imported as Node3D
    latest_mantis_visual.name = "LatestMantisModel"
    latest_mantis_visual.position = Vector3.ZERO
    latest_mantis_visual.rotation = Vector3.ZERO
    latest_mantis_visual.scale = Vector3.ONE * LATEST_MANTIS_MODEL_SCALE
    animal.add_child(latest_mantis_visual)
    _style_rigged_materials(latest_mantis_visual)
    latest_mantis_player = _find_rigged_player(latest_mantis_visual)
    if latest_mantis_player == null:
        rigged_import_warnings.append("Latest mantis GLB has no AnimationPlayer")
        latest_mantis_visual.visible = false
        return
    for library_name in latest_mantis_player.get_animation_library_list():
        var library := latest_mantis_player.get_animation_library(library_name)
        if library == null:
            continue
        for clip_name in library.get_animation_list():
            var full_name := String(clip_name)
            if not String(library_name).is_empty():
                full_name = String(library_name) + "/" + full_name
            var normalized := String(clip_name).to_upper()
            latest_mantis_clips[normalized] = full_name
            var animation := library.get_animation(clip_name)
            if animation != null:
                animation.loop_mode = Animation.LOOP_LINEAR if normalized in ["IDLE", "WALK", "ALERT", "GROOM", "FEED"] else Animation.LOOP_NONE
    if latest_mantis_clips.is_empty():
        rigged_import_warnings.append("Latest mantis GLB has no animation clips")
        latest_mantis_visual.visible = false
        return
    _apply_visual_mode()
    _play_latest_mantis_clip("IDLE")

func _initialize_photo_visual() -> void:
    # Use the user's cropped, pixel-preserving side and dorsal photos in-world.
    photo_visual = Sprite3D.new()
    photo_visual.name = "LatestMantisSidePhotoCutout"
    photo_visual.texture = PHOTO_SIDE_CUTOUT
    photo_visual.position = Vector3(0.0, 1.05, 0.53) * LATEST_MANTIS_MODEL_SCALE
    photo_visual.pixel_size = 3.33 * LATEST_MANTIS_MODEL_SCALE / float(PHOTO_SIDE_CUTOUT.get_width())
    photo_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    photo_visual.shaded = false
    photo_visual.visible = false
    animal.add_child(photo_visual)

    photo_visual_dorsal = Sprite3D.new()
    photo_visual_dorsal.name = "LatestMantisDorsalPhoto"
    photo_visual_dorsal.texture = PHOTO_DORSAL_CUTOUT
    photo_visual_dorsal.position = Vector3(0.0, 1.30, 0.47) * LATEST_MANTIS_MODEL_SCALE
    photo_visual_dorsal.pixel_size = 3.33 * LATEST_MANTIS_MODEL_SCALE / float(PHOTO_DORSAL_CUTOUT.get_height())
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
    photo_visual.position = (Vector3(0.0, 1.05, 0.53) + offset) * LATEST_MANTIS_MODEL_SCALE
    photo_visual_dorsal.position = (Vector3(0.0, 1.30, 0.47) + offset) * LATEST_MANTIS_MODEL_SCALE
    photo_visual.scale = Vector3.ONE * size_factor
    photo_visual_dorsal.scale = Vector3.ONE * size_factor

func _collect_procedural_meshes(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            procedural_meshes.append(child as MeshInstance3D)
        _collect_procedural_meshes(child)

func _style_rigged_materials(root: Node) -> void:
    # Vertex colors retain each body part's olive palette. Triplanar cuticle
    # maps add pores and micro-relief; wing UV maps carry a separate vein net.
    for child in root.get_children():
        if child is MeshInstance3D:
            var part := child as MeshInstance3D
            var mat := StandardMaterial3D.new()
            mat.vertex_color_use_as_albedo = true
            mat.albedo_color = Color(0.43, 0.54, 0.26)
            mat.metallic = 0.0
            mat.roughness = 0.84
            var is_wing_part := part.name.begins_with("Wing_") or part.name.begins_with("WingVeinDetail_") or part.name.begins_with("Hindwing_")
            if is_wing_part:
                mat.albedo_texture = wing_detail_texture
                mat.uv1_triplanar = false
                mat.roughness = 0.82
                mat.normal_enabled = true
                mat.normal_texture = load("res://assets/textures/mantis_wing_normal.png")
                mat.normal_scale = 0.24
                mat.roughness_texture = load("res://assets/textures/mantis_wing_roughness.png")
                mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
                if part.name.begins_with("Hindwing_"):
                    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    mat.albedo_color.a = 0.82
                    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
            elif part.name.begins_with("EyePupil_"):
                mat.vertex_color_use_as_albedo = false
                mat.albedo_color = Color(0.10, 0.16, 0.045)
                mat.roughness = 0.34
                mat.uv1_triplanar = false
            elif part.name.begins_with("EyeGlint_"):
                mat.vertex_color_use_as_albedo = false
                mat.albedo_color = Color(0.76, 0.84, 0.58)
                mat.roughness = 0.22
                mat.uv1_triplanar = false
            elif part.name.begins_with("Eye_"):
                mat.vertex_color_use_as_albedo = false
                mat.albedo_texture = eye_texture
                mat.albedo_color = Color(0.82, 0.87, 0.60)
                mat.uv1_triplanar = false
                _apply_pbr(mat, "mantis_eye")
            else:
                mat.albedo_texture = cuticle_detail_texture
                mat.uv1_triplanar = true
                mat.uv1_triplanar_sharpness = 8.0
                mat.uv1_scale = Vector3(18.0, 18.0, 18.0)
                mat.roughness = 0.72
                mat.normal_enabled = true
                mat.normal_texture = load("res://assets/textures/mantis_cuticle_detail_normal.png")
                mat.normal_scale = 0.22
                mat.roughness_texture = load("res://assets/textures/mantis_cuticle_detail_roughness.png")
                mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
            part.material_override = mat
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
    var show_photo := use_photo_visual and photo_visual != null
    var show_latest := not show_photo and use_latest_mantis_visual and latest_mantis_visual != null and not latest_mantis_clips.is_empty()
    var show_rigged := not show_photo and not show_latest and use_rigged_visual and rigged_available
    for part in procedural_meshes:
        if is_instance_valid(part):
            part.visible = not show_rigged and not show_latest and not show_photo
    if rigged_visual != null:
        rigged_visual.visible = show_rigged
    if latest_mantis_visual != null:
        latest_mantis_visual.visible = show_latest
    if photo_visual != null:
        photo_visual.visible = show_photo and (camera == null or (camera.global_position - animal.global_position).normalized().y <= 0.70)
    if photo_visual_dorsal != null:
        photo_visual_dorsal.visible = show_photo and camera != null and (camera.global_position - animal.global_position).normalized().y > 0.70
    if rigged_player != null:
        if show_rigged:
            rigged_player.speed_scale = 1.0
        else:
            rigged_player.stop()
    if latest_mantis_player != null:
        if show_latest:
            latest_mantis_player.speed_scale = 1.0
        else:
            latest_mantis_player.stop()
    rigged_clip = ""
    latest_mantis_clip = ""
    if rigged_pose_driver != null:
        rigged_pose_driver.enabled = show_rigged and rigged_ik_enabled
        if not show_rigged:
            rigged_pose_driver.reset_offsets()

func _toggle_visual_model() -> void:
    use_latest_mantis_visual = not use_latest_mantis_visual
    _apply_visual_mode()
    if notice != null:
        var selected_model := "최신 모델" if use_latest_mantis_visual and not latest_mantis_clips.is_empty() else "기본 3D 모델"
        notice.text = "사진 관찰 중 · 복귀할 3D 모델: " + selected_model if use_photo_visual else "3D 모델: " + selected_model

func _toggle_photo_visual() -> void:
    if photo_visual == null:
        if notice != null:
            notice.text = "원본 사진을 불러오지 못했습니다."
        return
    use_photo_visual = not use_photo_visual
    _apply_visual_mode()
    _update_photo_visual(0.0)
    if notice != null:
        notice.text = "사용자 원본 사진 오려내기 모드입니다. 위에서 보면 등면, 옆에서 보면 측면 사진이 표시됩니다." if use_photo_visual else "상세 관절형 3D 모델로 복귀했습니다."

func _play_latest_mantis_clip(clip: String) -> void:
    if latest_mantis_player == null or latest_mantis_clips.is_empty():
        return
    var resolved := clip
    var aliases := {"MOLT": "IDLE", "HUNT": "STRIKE", "CLIMB": "WALK", "DEFEND": "ALERT", "SCAN": "ALERT"}
    if aliases.has(resolved):
        resolved = aliases[resolved]
    if not latest_mantis_clips.has(resolved):
        resolved = "IDLE"
    if not latest_mantis_clips.has(resolved) or latest_mantis_clip == resolved:
        return
    var animation_name: String = latest_mantis_clips[resolved]
    if not latest_mantis_player.has_animation(animation_name):
        rigged_import_warnings.append("Missing latest mantis clip: " + animation_name)
        return
    latest_mantis_player.play(animation_name, 0.18)
    latest_mantis_clip = resolved

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
    if use_latest_mantis_visual:
        if latest_mantis_visual == null or latest_mantis_clips.is_empty():
            return
        _play_latest_mantis_clip(animation_state)
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
    env.ambient_light_color = Color(0.48, 0.52, 0.42)
    env.ambient_light_energy = 0.28
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -31, 0)
    sun.light_color = Color(0.96, 0.94, 0.82)
    sun.light_energy = 0.68
    sun.shadow_enabled = true
    add_child(sun)
    _box(Vector3(HABITAT_WIDTH, 0.2, HABITAT_DEPTH), Vector3(0, -0.65, 0), Color(0.23, 0.15, 0.09))
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
        var p := Vector3(detail_rng.randf_range(-4.48, 4.48), -0.49, detail_rng.randf_range(-3.08, 3.08))
        var size := detail_rng.randf_range(0.85, 1.35)
        _ellipsoid(p, Vector3(0.11, 0.04, 0.16) * size, Color(0.15 + 0.02 * (i % 3), 0.28, 0.105))

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
    floor_body.position = Vector3(0, -0.65, 0)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(HABITAT_WIDTH, 0.2, HABITAT_DEPTH)
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
    animal.scale = Vector3.ONE * _growth_visual_scale()
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
    _part(thorax_pivot, Vector3.ZERO, Vector3(0.071, 0.074, 0.34), dark_green)
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
        _segment(foreleg, Vector3.ZERO, elbow.position, 0.032, green)
        var femur_shape := MeshInstance3D.new()
        var femur_mesh := SphereMesh.new()
        femur_mesh.radial_segments = 24
        femur_mesh.rings = 14
        femur_shape.mesh = femur_mesh
        femur_shape.position = elbow.position * 0.5
        femur_shape.quaternion = Quaternion(Vector3.UP, elbow.position.normalized())
        femur_shape.scale = Vector3(0.056, elbow.position.length() * 1.10, 0.064)
        femur_shape.material_override = _material(green.lightened(0.06))
        foreleg.add_child(femur_shape)
        for spine_i in range(9):
            var spine_t := 0.12 + float(spine_i) * 0.095
            var spine_base := elbow.position * spine_t
            var spine_tip := spine_base + Vector3(side * 0.030, -0.036, -0.023)
            _segment(foreleg, spine_base, spine_tip, 0.0068, Color(0.58, 0.61, 0.24))
        var claw := Node3D.new()
        claw.name = "ForelegTibia_%d" % int(side)
        claw.position = Vector3(0, -0.21, -0.16)
        elbow.add_child(claw)
        _segment(elbow, Vector3.ZERO, claw.position, 0.039, dark_green)
        _segment(claw, Vector3.ZERO, Vector3(0, -0.15, -0.10), 0.018, green)
        for j in range(8):
            var t := float(j) / 8.0
            _segment(elbow, Vector3(0, -0.20 + t * 0.17, -0.17 + t * 0.13), Vector3(side * 0.032, -0.23 + t * 0.17, -0.20 + t * 0.13), 0.0075, Color(0.47, 0.55, 0.20))
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
    _part(thorax_pivot, Vector3(0, 0.048, -0.13), Vector3(0.082, 0.026, 0.070), green)
    _enhance_mantis_model()

func _growth_visual_scale() -> float:
    return 1.18 + growth * 0.45

# Maps are generated from the source color textures; they are an affordable
# material-detail approximation, not measured photogrammetric PBR data.

func _fallback_wing_mesh(side: float) -> ArrayMesh:
    var length_steps := 18
    var width_steps := 10
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(length_steps + 1):
        var t := float(i) / float(length_steps)
        var fullness := pow(maxf(0.0, sin(PI * t)), 0.72)
        for j in range(width_steps + 1):
            var across := float(j) / float(width_steps) * 2.0 - 1.0
            var x := side * (0.068 + across * 0.068 * fullness)
            var ridge := 0.020 * (1.0 - across * across) * sin(PI * t)
            surface.set_uv(Vector2(float(j) / float(width_steps), t))
            surface.add_vertex(Vector3(x, 0.212 + ridge, -0.12 + t * 0.56))
    for i in range(length_steps):
        for j in range(width_steps):
            var a := i * (width_steps + 1) + j
            var b := a + 1
            var d := a + width_steps + 1
            var c := d + 1
            if side > 0.0:
                surface.add_index(a)
                surface.add_index(c)
                surface.add_index(b)
                surface.add_index(a)
                surface.add_index(d)
                surface.add_index(c)
            else:
                surface.add_index(a)
                surface.add_index(b)
                surface.add_index(c)
                surface.add_index(a)
                surface.add_index(c)
                surface.add_index(d)
    surface.generate_normals()
    return surface.commit()

# Twenty lightweight, named anatomical modeling passes. These meshes are
# stylized procedural geometry, not a scanned specimen or skinned GLB rig.
func _enhance_mantis_model() -> void:
    var olive := Color(0.24, 0.43, 0.15)
    var pale := Color(0.53, 0.66, 0.29)
    var dark := Color(0.13, 0.25, 0.10)
    var wing := Color(0.34, 0.55, 0.22, 0.93)
    # 01 Pronotum dorsal keel
    _segment(thorax_pivot, Vector3(0, 0.079, 0.16), Vector3(0, 0.081, -0.28), 0.009, pale)
    # 02 Pronotum left and right lateral ridges
    for side in [-1.0, 1.0]:
        _segment(thorax_pivot, Vector3(side * 0.062, 0.027, 0.14), Vector3(side * 0.057, 0.028, -0.27), 0.0075, olive)
    # 03 Pronotum anterior collar
    _part(thorax_pivot, Vector3(0, 0.026, -0.305), Vector3(0.081, 0.043, 0.030), pale)
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
    # 14 Paired leaf-shaped tegmina meet along the dorsal seam.
    for side in [-1.0, 1.0]:
        var blade := MeshInstance3D.new()
        blade.name = "ProceduralWing_%d" % int(side)
        blade.mesh = _fallback_wing_mesh(side)
        var wing_material := _material(wing)
        wing_material.albedo_texture = wing_detail_texture
        wing_material.normal_enabled = true
        wing_material.normal_texture = load("res://assets/textures/mantis_wing_normal.png")
        wing_material.normal_scale = 0.30
        wing_material.roughness_texture = load("res://assets/textures/mantis_wing_roughness.png")
        wing_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        blade.material_override = wing_material
        abdomen.add_child(blade)
    # 15 Longitudinal wing veins
    for side in [-1.0, 1.0]:
        _segment(abdomen, Vector3(side * 0.068, 0.236, -0.105), Vector3(side * 0.068, 0.236, 0.414), 0.0035, pale)
    # 16 Oblique wing cross-veins
    for side in [-1.0, 1.0]:
        for j in range(8):
            var z := -0.105 + float(j) * 0.074
            _segment(abdomen, Vector3(side * 0.068, 0.235, z), Vector3(side * 0.122, 0.232, z + 0.036), 0.0028, olive)
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
        mat.uv1_triplanar = true
        mat.uv1_triplanar_sharpness = 8.0
        mat.uv1_scale = Vector3(18.0, 18.0, 18.0)
        mat.normal_texture = cuticle_detail_normal_texture
        mat.normal_scale = 0.40
        mat.roughness_texture = cuticle_detail_roughness_texture
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        mat.roughness = 0.80
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
    elif body_texture != null and color.g > color.r * 1.15:
        mat.albedo_texture = body_texture
        mat.albedo_color = Color(0.85, 1.0, 0.83)
        mat.uv1_triplanar = true
        mat.uv1_triplanar_sharpness = 8.0
        mat.uv1_scale = Vector3(18.0, 18.0, 18.0)
        mat.normal_enabled = cuticle_detail_normal_texture != null
        mat.normal_texture = cuticle_detail_normal_texture
        mat.normal_scale = 0.40
        mat.roughness_texture = cuticle_detail_roughness_texture
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        mat.roughness = 0.80
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
    species_selector = OptionButton.new()
    species_selector.name = "SpeciesQuickSelect"
    species_selector.custom_minimum_size = Vector2(250, 52)
    species_selector.add_item("사마귀 · 열대 식물 사육장")
    species_selector.add_item("열대어 무리 · 수족관")
    species_selector.add_item("가재 · 바위 틈 굴 수조")
    species_selector.add_item("호랑나비 · 꽃밭 온실")
    species_selector.add_item("육지소라게 무리 · 모래 수조")
    species_selector.add_item("알록달록 도롱뇽 · 계곡 개울")
    species_selector.item_selected.connect(_on_species_selected)
    root_ui.add_child(species_selector)
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

    aquarium_controls = VBoxContainer.new()
    column.add_child(aquarium_controls)
    var aquarium_heading := Label.new()
    aquarium_heading.text = "수족관 관리"
    aquarium_controls.add_child(aquarium_heading)
    _button(aquarium_controls, "물고기 한 마리 추가", func(): _add_aquarium_fish())
    _button(aquarium_controls, "물고기 한 마리 줄이기", func(): _remove_aquarium_fish())
    _button(aquarium_controls, "여과기 물살 켜기/끄기", func(): _toggle_aquarium_flow())
    _button(aquarium_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())

    crayfish_controls = VBoxContainer.new()
    column.add_child(crayfish_controls)
    var crayfish_heading := Label.new()
    crayfish_heading.text = "가재 서식지 관리"
    crayfish_controls.add_child(crayfish_heading)
    _button(crayfish_controls, "가재 굴 밖으로 유도", func(): _encourage_crayfish())
    _button(crayfish_controls, "활동 중인 가재 굴로 보내기", func(): _retreat_crayfish())
    _button(crayfish_controls, "여과기 물살 켜기/끄기", func(): _toggle_aquarium_flow())
    _button(crayfish_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())

    butterfly_controls = VBoxContainer.new()
    column.add_child(butterfly_controls)
    var butterfly_heading := Label.new()
    butterfly_heading.text = "나비 꽃밭 관리"
    butterfly_controls.add_child(butterfly_heading)
    _button(butterfly_controls, "나비 한 마리 추가", func(): _add_butterfly())
    _button(butterfly_controls, "나비 비행 유도", func(): butterfly_system.call("encourage_flight"); notice.text = "나비가 꽃을 찾아 날아가도록 유도했습니다.")
    _button(butterfly_controls, "꽃 한 송이 심기", func(): _add_butterfly_flower())
    _button(butterfly_controls, "꽃꿀 보충", func(): butterfly_system.call("refill_nectar"); _refresh(); notice.text = "꽃의 꿀을 보충했습니다.")
    _button(butterfly_controls, "낮 / 밤 전환", func(): _toggle_butterfly_daylight())
    _button(butterfly_controls, "산들바람 켜기 / 끄기", func(): _toggle_butterfly_wind())
    _button(butterfly_controls, "온도 +1°C", func(): butterfly_system.call("change_temperature", 1.0); _refresh())
    _button(butterfly_controls, "온도 -1°C", func(): butterfly_system.call("change_temperature", -1.0); _refresh())
    _button(butterfly_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(butterfly_controls, "나비 가까이 보기", func(): follow_animal = true; habitat_framing = false; orbit_distance = 2.35; _update_camera())
    _button(butterfly_controls, "꽃밭 전체 보기", func(): _set_camera_preset(false))

    hermit_crab_controls = VBoxContainer.new()
    column.add_child(hermit_crab_controls)
    var hermit_crab_heading := Label.new()
    hermit_crab_heading.text = "육지소라게 모래 수조 관리"
    hermit_crab_controls.add_child(hermit_crab_heading)
    _button(hermit_crab_controls, "소라게 한 마리 추가", func(): _add_hermit_crab())
    _button(hermit_crab_controls, "활동 유도", func(): _encourage_hermit_crabs())
    _button(hermit_crab_controls, "예비 껍데기 배치", func(): _add_hermit_crab_shell())
    _button(hermit_crab_controls, "물그릇 보충", func(): _refill_hermit_crab_water())
    _button(hermit_crab_controls, "습도 +5%", func(): _adjust_hermit_crab_humidity(5.0))
    _button(hermit_crab_controls, "습도 -5%", func(): _adjust_hermit_crab_humidity(-5.0))
    _button(hermit_crab_controls, "온도 +1°C", func(): _adjust_hermit_crab_temperature(1.0))
    _button(hermit_crab_controls, "온도 -1°C", func(): _adjust_hermit_crab_temperature(-1.0))
    _button(hermit_crab_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(hermit_crab_controls, "소라게 가까이 보기", func(): follow_animal = true; habitat_framing = false; orbit_distance = 4.0; _update_camera())
    _button(hermit_crab_controls, "수조 전체 보기", func(): _set_camera_preset(false))

    stream_salamander_controls = VBoxContainer.new()
    column.add_child(stream_salamander_controls)
    var salamander_heading := Label.new()
    salamander_heading.text = "계곡 개울 도롱뇽 서식지 관리"
    stream_salamander_controls.add_child(salamander_heading)
    _button(stream_salamander_controls, "도롱뇽 한 마리 추가", func(): _add_stream_salamander())
    _button(stream_salamander_controls, "젖은 바위 탐색 유도", func(): _encourage_stream_salamanders())
    _button(stream_salamander_controls, "바위틈에 숨기", func(): _hide_stream_salamanders())
    _button(stream_salamander_controls, "개울 물살 켜기 / 끄기", func(): _toggle_stream_flow())
    _button(stream_salamander_controls, "분무 +5%", func(): _adjust_stream_humidity(5.0))
    _button(stream_salamander_controls, "온도 +1°C", func(): _adjust_stream_temperature(1.0))
    _button(stream_salamander_controls, "온도 -1°C", func(): _adjust_stream_temperature(-1.0))
    _button(stream_salamander_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(stream_salamander_controls, "도롱뇽 가까이 보기", func(): follow_animal = true; habitat_framing = false; orbit_distance = 3.8; _update_camera())
    _button(stream_salamander_controls, "계곡 전체 보기", func(): _set_camera_preset(false))

    mantis_controls = VBoxContainer.new()
    column.add_child(mantis_controls)
    var mantis_heading := Label.new()
    mantis_heading.text = "사마귀 관리"
    mantis_controls.add_child(mantis_heading)
    _button(mantis_controls, "먹이 추가", func(): _add_food())
    _button(mantis_controls, "바람 켜기/끄기", func(): wind_enabled = not wind_enabled; notice.text = "바람: " + ("켜짐" if wind_enabled else "꺼짐"))
    _button(mantis_controls, "생태계 상호작용 켜기/끄기", func(): habitat_interactions.active = not habitat_interactions.active; notice.text = "생태계 상호작용: " + ("켜짐" if habitat_interactions.active else "꺼짐"))
    _button(mantis_controls, "생태계 활동 기록", func(): notice.text = habitat_interactions.summary())
    _button(mantis_controls, "바람 세기 변경", func(): wind_strength = fmod(wind_strength + 0.25, 1.26); notice.text = "바람 세기: %.2f" % wind_strength)
    animation_label = Label.new()
    animation_label.text = "애니메이션: AUTO"
    mantis_controls.add_child(animation_label)
    _button(mantis_controls, "첨부 사진 보기 / 3D 복귀", func(): _toggle_photo_visual())
    _button(mantis_controls, "3D 모델 전환 (GLB / 기본)", func(): _toggle_visual_model())
    _button(mantis_controls, "실물 사진과 구조 비교", func(): _show_reference_overlay())
    _button(mantis_controls, "자동 행동 애니메이션", func(): _set_animation_preview("AUTO"))
    for clip in ANIMATIONS:
        var selected_clip: String = clip
        _button(mantis_controls, "동작 시연: " + selected_clip, func(): _set_animation_preview(selected_clip))
    frontleg_animation_label = Label.new()
    frontleg_animation_label.text = "앞다리 동작: 최신 모델 기본 포획 자세"
    mantis_controls.add_child(frontleg_animation_label)
    _button(mantis_controls, "앞다리 동작 재생 / 다시 시작", func(): _restart_frontleg_animation())
    _button(mantis_controls, "앞다리 동작 이전", func(): _step_frontleg_animation(-1))
    _button(mantis_controls, "앞다리 동작 다음", func(): _step_frontleg_animation(1))
    _button(mantis_controls, "앞다리 자동 동작으로 복귀", func(): _set_frontleg_animation(-1))
    _button(mantis_controls, "관찰 기록", func(): notice.text = "성장 %.0f%% / 탈피 %d회 / 경과 %.0f초" % [growth * 100.0, molt_count, life_age])
    _button(mantis_controls, "온도 +1°C", func(): temperature = minf(38.0, temperature + 1.0); _refresh())
    _button(mantis_controls, "온도 -1°C", func(): temperature = maxf(15.0, temperature - 1.0); _refresh())
    _button(mantis_controls, "분무 +10%", func(): humidity = minf(100.0, humidity + 10.0); _refresh())
    _button(mantis_controls, "일시정지 / 재개", func(): simulation_paused = not simulation_paused; _refresh())
    _button(mantis_controls, "발 접지 켜기/끄기", func(): foot_contacts_enabled = not foot_contacts_enabled; notice.text = "발 접지: " + ("켜짐" if foot_contacts_enabled else "꺼짐"))
    _button(mantis_controls, "개체 추적 켜기/끄기", func(): follow_animal = not follow_animal; habitat_framing = false; _update_camera())
    _button(mantis_controls, "사마귀 가까이 보기", func(): _set_camera_preset(true))
    _button(mantis_controls, "서식지 전체 보기", func(): _set_camera_preset(false))
    _button(mantis_controls, "돌 배치 모드", func(): _set_edit_mode("rock"))
    _button(mantis_controls, "유목 배치 모드", func(): _set_edit_mode("wood"))
    _button(mantis_controls, "장식 지우기 모드", func(): _set_edit_mode("erase"))
    _button(mantis_controls, "편집 종료", func(): editing = false; edit_hint.text = "관찰 모드")
    _button(mantis_controls, "UI 숨김/표시", func(): stats_visible = not stats_visible; ui_panel.visible = stats_visible)
    _button(mantis_controls, "저장", func(): _save_state())
    _button(mantis_controls, "불러오기", func(): _load_state(true))
    edit_hint = Label.new()
    edit_hint.text = "관찰 모드"
    mantis_controls.add_child(edit_hint)
    notice = Label.new()
    notice.text = "드래그: 자유 회전 | 휠·두 손가락: 확대/축소 | F: 시점 재설정"
    column.add_child(notice)
    camera_hint = Label.new()
    camera_hint.text = "드래그: 자유 회전 · 두 손가락: 확대/축소"
    camera_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    camera_hint.add_theme_color_override("font_color", Color(0.84, 0.90, 0.78, 0.92))
    root_ui.add_child(camera_hint)
    _create_reference_overlay()

func _on_species_selected(index: int) -> void:
    _set_species_mode(index)

func _set_species_mode(index: int, show_message: bool = true) -> void:
    if index < 0 or index > 5:
        index = 0
    current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"][index]
    var viewing_aquarium := current_species in ["fish", "crayfish"]
    var viewing_fish := current_species == "fish"
    var viewing_crayfish := current_species == "crayfish"
    var viewing_butterfly := current_species == "butterfly"
    var viewing_hermit_crab := current_species == "hermit_crab"
    var viewing_stream_salamander := current_species == "stream_salamander"
    if animal != null:
        animal.visible = current_species == "mantis"
    if aquarium_system != null:
        aquarium_system.visible = viewing_aquarium
        if viewing_aquarium:
            aquarium_system.call("set_species_view", current_species)
    if butterfly_system != null:
        butterfly_system.visible = viewing_butterfly
    if hermit_crab_system != null:
        hermit_crab_system.visible = viewing_hermit_crab
    if stream_salamander_system != null:
        stream_salamander_system.visible = viewing_stream_salamander
    for environment_root in mantis_environment_roots:
        if is_instance_valid(environment_root):
            environment_root.visible = current_species == "mantis"
    if aquarium_controls != null:
        aquarium_controls.visible = viewing_fish
    if crayfish_controls != null:
        crayfish_controls.visible = viewing_crayfish
    if butterfly_controls != null:
        butterfly_controls.visible = viewing_butterfly
    if hermit_crab_controls != null:
        hermit_crab_controls.visible = viewing_hermit_crab
    if stream_salamander_controls != null:
        stream_salamander_controls.visible = viewing_stream_salamander
    if mantis_controls != null:
        mantis_controls.visible = current_species == "mantis"
    if species_selector != null and species_selector.selected != index:
        species_selector.select(index)
    if viewing_aquarium or viewing_butterfly or viewing_hermit_crab or viewing_stream_salamander:
        _set_camera_preset(false)
        follow_animal = false
        habitat_framing = true
        if viewing_crayfish:
            orbit_distance = minf(orbit_distance, 7.4)
            orbit_pitch = 0.24
        elif viewing_butterfly:
            orbit_distance = maxf(orbit_distance, 5.1)
            orbit_pitch = 0.30
        elif viewing_hermit_crab:
            orbit_distance = maxf(orbit_distance, 5.1)
            orbit_pitch = 0.27
        elif viewing_stream_salamander:
            orbit_distance = maxf(orbit_distance, 5.2)
            orbit_pitch = 0.28
        if show_message:
            if viewing_crayfish:
                notice.text = "가재가 굴에서 쉬다가 나와 활동하는 바위 수조입니다."
            elif viewing_butterfly:
                notice.text = "호랑나비가 꽃을 찾아 날아다니고 꿀을 먹는 꽃밭입니다."
            elif viewing_hermit_crab:
                notice.text = "육지소라게가 모래, 바위 은신처, 물그릇을 오가는 전용 수조입니다."
            elif viewing_stream_salamander:
                notice.text = "알록달록한 도롱뇽이 개울가의 젖은 바위를 살피고 바위틈에서 쉬는 계곡 서식지입니다."
            else:
                notice.text = "열대어 수족관으로 전환했습니다."
    else:
        _set_camera_preset(true)
        if show_message:
            notice.text = "사마귀 사육장으로 돌아왔습니다."
    _update_camera()
    _refresh()

func _add_aquarium_fish() -> void:
    var added := bool(aquarium_system.call("add_fish"))
    notice.text = "물고기를 추가했습니다." if added else "물고기는 최대 24마리까지 넣을 수 있습니다."
func _encourage_crayfish() -> void:
    aquarium_system.call("encourage_crayfish")
    _refresh()
    notice.text = "가재가 바위 틈 굴에서 나오도록 유도했습니다."
func _retreat_crayfish() -> void:
    aquarium_system.call("retreat_crayfish")
    _refresh()
    notice.text = "가재가 굴로 돌아가도록 유도했습니다."
    _refresh()

func _remove_aquarium_fish() -> void:
    var removed := bool(aquarium_system.call("remove_fish"))
    notice.text = "물고기 한 마리를 줄였습니다." if removed else "수족관에는 물고기 한 마리 이상이 필요합니다."
    _refresh()

func _toggle_aquarium_flow() -> void:
    var running := bool(aquarium_system.call("toggle_flow"))
    notice.text = "여과기 물살: " + ("켜짐" if running else "꺼짐")

func _add_butterfly_flower() -> void:
    var added := bool(butterfly_system.call("add_flower"))
    notice.text = "꽃밭에 꽃을 심었습니다." if added else "꽃밭에는 꽃을 최대 24송이까지 심을 수 있습니다."
    _refresh()

func _add_butterfly() -> void:
    var added := bool(butterfly_system.call("add_butterfly"))
    notice.text = "나비 한 마리를 추가했습니다." if added else "나비는 최대 8마리까지 넣을 수 있습니다."
    _refresh()

func _toggle_butterfly_daylight() -> void:
    var is_day := bool(butterfly_system.call("toggle_daylight"))
    notice.text = "낮으로 바뀌어 나비가 활동합니다." if is_day else "밤이 되어 나비가 잎에서 쉽니다."
    _refresh()

func _toggle_butterfly_wind() -> void:
    var is_windy := bool(butterfly_system.call("toggle_wind"))
    notice.text = "산들바람: " + ("켜짐" if is_windy else "꺼짐")

func _add_hermit_crab() -> void:
    var added := bool(hermit_crab_system.call("add_crab"))
    notice.text = "육지소라게 한 마리를 추가했습니다." if added else "소라게는 최대 6마리까지 넣을 수 있습니다."
    _refresh()

func _encourage_hermit_crabs() -> void:
    hermit_crab_system.call("encourage_activity")
    notice.text = "소라게가 수조를 둘러보도록 유도했습니다."

func _add_hermit_crab_shell() -> void:
    var added := bool(hermit_crab_system.call("add_shell"))
    notice.text = "예비 껍데기를 모래 위에 놓았습니다." if added else "예비 껍데기는 최대 16개까지 배치할 수 있습니다."
    _refresh()

func _refill_hermit_crab_water() -> void:
    hermit_crab_system.call("refill_water")
    notice.text = "민물과 염수 물그릇을 보충했습니다."

func _adjust_hermit_crab_humidity(amount: float) -> void:
    hermit_crab_system.call("change_humidity", amount)
    _refresh()

func _adjust_hermit_crab_temperature(amount: float) -> void:
    hermit_crab_system.call("change_temperature", amount)
    _refresh()

func _add_stream_salamander() -> void:
    var added := bool(stream_salamander_system.call("add_salamander"))
    notice.text = "계곡 도롱뇽 한 마리를 추가했습니다." if added else "도롱뇽은 최대 6마리까지 둘 수 있습니다."
    _refresh()

func _encourage_stream_salamanders() -> void:
    stream_salamander_system.call("encourage_activity")
    notice.text = "도롱뇽이 물가의 젖은 바위를 살피도록 유도했습니다."

func _hide_stream_salamanders() -> void:
    stream_salamander_system.call("retreat_to_hide")
    notice.text = "도롱뇽이 그늘진 바위틈으로 숨도록 유도했습니다."

func _toggle_stream_flow() -> void:
    var running := bool(stream_salamander_system.call("toggle_flow"))
    notice.text = "계곡 개울 물살: " + ("켜짐" if running else "꺼짐")

func _adjust_stream_humidity(amount: float) -> void:
    var value := float(stream_salamander_system.call("change_humidity", amount))
    notice.text = "계곡 주변 습도: %.0f%%" % value
    _refresh()

func _adjust_stream_temperature(amount: float) -> void:
    stream_salamander_system.call("change_temperature", amount)
    _refresh()

func _cache_mantis_environment_roots() -> void:
    mantis_environment_roots.clear()
    for child in get_children():
        if child is Node3D and child not in [camera, animal, aquarium_system, butterfly_system, hermit_crab_system, stream_salamander_system]:
            mantis_environment_roots.append(child as Node3D)

func _resize_ui() -> void:
    var screen := get_viewport().get_visible_rect().size
    var compact_layout := screen.x < 600.0
    if species_selector != null:
        if compact_layout:
            species_selector.position = Vector2(16, 76)
            species_selector.size = Vector2(maxf(250.0, screen.x - 32.0), 52.0)
        else:
            species_selector.position = Vector2(188, 16)
            species_selector.size = Vector2(minf(390.0, maxf(250.0, screen.x - 204.0)), 52.0)
    if ui_panel != null:
        ui_panel.position = Vector2(16, 136 if compact_layout else 74)
        ui_panel.size = Vector2(minf(320.0, screen.x * 0.68), maxf(100.0, screen.y - (156.0 if compact_layout else 94.0)))
    if camera_hint != null:
        camera_hint.position = Vector2(16, maxf(16.0, screen.y - 42.0))
        camera_hint.size = Vector2(minf(360.0, screen.x - 32.0), 30.0)
    if reference_panel != null:
        var panel_width := minf(620.0, maxf(260.0, screen.x - 28.0))
        var panel_height := minf(700.0, maxf(420.0, screen.y - 32.0))
        reference_panel.position = (screen - Vector2(panel_width, panel_height)) * 0.5
        reference_panel.size = Vector2(panel_width, panel_height)
        if reference_photo_view != null:
            reference_photo_view.custom_minimum_size = Vector2(panel_width - 52.0, minf(350.0, screen.y * 0.43))

func _create_reference_overlay() -> void:
    reference_overlay = Control.new()
    reference_overlay.name = "MantisPhotoReferenceOverlay"
    reference_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    reference_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    reference_overlay.visible = false
    root_ui.add_child(reference_overlay)

    var dimmer := ColorRect.new()
    dimmer.name = "ReferenceBackdrop"
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.color = Color(0.015, 0.025, 0.022, 0.88)
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    reference_overlay.add_child(dimmer)

    reference_panel = PanelContainer.new()
    reference_panel.name = "ReferenceProcedurePanel"
    reference_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    reference_panel.custom_minimum_size = Vector2(280, 420)
    reference_overlay.add_child(reference_panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    reference_panel.add_child(content)

    var title := Label.new()
    title.text = "사진 속 사마귀 구조와 3D 모델 비교"
    title.add_theme_font_size_override("font_size", 21)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(title)

    reference_photo_view = TextureRect.new()
    reference_photo_view.name = "LatestUserMantisPhoto"
    reference_photo_view.texture = load("res://assets/reference/1000157363(3).jpg")
    reference_photo_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    reference_photo_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    reference_photo_view.custom_minimum_size = Vector2(300, 230)
    reference_photo_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(reference_photo_view)

    var steps := Label.new()
    steps.text = "1. 사진의 삼각형 얼굴과 양옆 겹눈, 머리에서 길게 뻗은 더듬이를 확인합니다.\n2. 가느다란 앞가슴에서 몸통으로 이어지는 선과, 두 관절로 접히는 가시 난 포획 앞다리를 비교합니다.\n3. 모델을 회전·확대해 배마디와 날개 아래쪽 구조를 살펴보고 앞다리 동작을 재생합니다."
    steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(steps)

    var detail_note := Label.new()
    detail_note.text = "이번 4.9 보완은 머리 앞면을 좁혀 삼각형 윤곽을 만들고 겹눈의 동공·광택, 가늘게 휜 한 쌍의 더듬이, 배마디와 옆판을 각각 다듬었습니다. 사진에서 가려진 면은 기존 리깅과 앞다리 구조를 유지했습니다."
    detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(detail_note)

    var close_button := Button.new()
    close_button.text = "비교 화면 닫기"
    close_button.custom_minimum_size = Vector2(240, 48)
    close_button.pressed.connect(_hide_reference_overlay)
    content.add_child(close_button)
    _resize_ui()

func _show_reference_overlay() -> void:
    if reference_overlay != null:
        reference_overlay.visible = true
        _resize_ui()

func _hide_reference_overlay() -> void:
    if reference_overlay != null:
        reference_overlay.visible = false


# Reusable curved leaf blade with a raised midrib and linked lateral veins.
func _leaf_mesh() -> ArrayMesh:
    var length_steps := 16
    var width_steps := 8
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(length_steps + 1):
        var t := float(i) / float(length_steps)
        var fullness := pow(maxf(0.0, sin(PI * t)), 0.78)
        var half_width := 0.145 * fullness
        for j in range(width_steps + 1):
            var across := float(j) / float(width_steps) * 2.0 - 1.0
            var ridge := 0.024 * (1.0 - absf(across)) * sin(PI * t)
            var curl := 0.007 * across * across * sin(PI * t)
            var vertex := Vector3(across * half_width, ridge + curl, t * 0.53)
            var vein_tint := 0.10 * (1.0 - absf(across))
            var pigment := Color(0.67 + vein_tint, 0.77 + vein_tint, 0.55 + vein_tint)
            surface.set_color(pigment)
            surface.set_uv(Vector2(float(j) / float(width_steps), t))
            surface.add_vertex(vertex)
    for i in range(length_steps):
        for j in range(width_steps):
            var a := i * (width_steps + 1) + j
            var b := a + 1
            var d := a + width_steps + 1
            var c := d + 1
            surface.add_index(a)
            surface.add_index(c)
            surface.add_index(b)
            surface.add_index(a)
            surface.add_index(d)
            surface.add_index(c)
    surface.generate_normals()
    return surface.commit()

func _create_animated_ecosystem() -> void:
    habitat_motion_root = Node3D.new()
    habitat_motion_root.name = "AnimatedEcosystem"
    # Keep plant dimensions at a readable size; scale their positions into the larger enclosure.
    add_child(habitat_motion_root)
    var rng := RandomNumberGenerator.new()
    rng.seed = 17012026
    var leaf_mesh := _leaf_mesh()
    var leaf_materials: Array[StandardMaterial3D] = []
    for tint in [Color(0.19, 0.39, 0.12), Color(0.29, 0.48, 0.16), Color(0.42, 0.39, 0.15)]:
        var mat := _material(tint)
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.vertex_color_use_as_albedo = true
        mat.albedo_texture = foliage_texture
        mat.roughness = 0.80
        mat.normal_enabled = foliage_normal_texture != null
        mat.normal_texture = foliage_normal_texture
        mat.normal_scale = 0.58
        mat.roughness_texture = foliage_roughness_texture
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        leaf_materials.append(mat)
    var stem_material := _material(Color(0.21, 0.31, 0.12))
    # Restore a full, leafy perimeter canopy while keeping a central walking lane.
    # Each plant's leaves are merged into one mesh to keep the Android draw count low.
    for i in range(300):
        var plant := Node3D.new()
        plant.name = "Plant_%02d" % i
        var plant_x := 0.0
        var plant_z := 0.0
        # Keep a clear central viewing and walking lane. Plants grow around the
        # perimeter; only their horizontal positions expand with the enclosure.
        match i % 4:
            0:
                plant_x = rng.randf_range(-4.35, 4.35)
                plant_z = rng.randf_range(-3.08, -2.30)
            1:
                plant_x = rng.randf_range(-4.35, 4.35)
                plant_z = rng.randf_range(2.30, 3.08)
            2:
                plant_x = rng.randf_range(-4.52, -3.75)
                plant_z = rng.randf_range(-2.95, 2.95)
            _:
                plant_x = rng.randf_range(3.75, 4.52)
                plant_z = rng.randf_range(-2.95, 2.95)
        plant.position = Vector3(plant_x * HABITAT_LINEAR_SCALE, -0.53, plant_z * HABITAT_LINEAR_SCALE)
        habitat_motion_root.add_child(plant)
        var canopy_plant := i % 3 == 0
        var height := rng.randf_range(1.65, 3.15) if canopy_plant else rng.randf_range(0.72, 1.80)
        var stem := MeshInstance3D.new()
        var stem_mesh := CylinderMesh.new()
        stem_mesh.top_radius = 0.009 if canopy_plant else 0.006
        stem_mesh.bottom_radius = 0.020 if canopy_plant else 0.013
        stem_mesh.height = height
        stem_mesh.radial_segments = 5
        stem.mesh = stem_mesh
        stem.material_override = stem_material
        stem.position.y = height * 0.5
        plant.add_child(stem)
        var leaf_count := rng.randi_range(10, 15) if canopy_plant else rng.randi_range(7, 11)
        var leaf_tool := SurfaceTool.new()
        leaf_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        for j in range(leaf_count):
            var leaf_height := height * (0.28 + 0.68 * (float(j) + 1.0) / float(leaf_count + 1))
            var angle := float(j) * TAU / float(leaf_count) + rng.randf_range(-0.32, 0.32)
            var reach := rng.randf_range(0.06, 0.22) * (1.25 if canopy_plant else 1.0)
            var leaf_position := Vector3(cos(angle) * reach, leaf_height, sin(angle) * reach)
            var leaf_rotation := Vector3(rng.randf_range(-0.46, -0.12), angle, rng.randf_range(-0.18, 0.18))
            var leaf_size := rng.randf_range(1.10, 1.55) * (1.18 if canopy_plant else 1.0)
            var leaf_transform := Transform3D(Basis.from_euler(leaf_rotation).scaled(Vector3.ONE * leaf_size), leaf_position)
            leaf_tool.append_from(leaf_mesh, 0, leaf_transform)
        var leaf_cluster := MeshInstance3D.new()
        leaf_cluster.name = "DenseLeafCanopy"
        leaf_cluster.mesh = leaf_tool.commit()
        leaf_cluster.material_override = leaf_materials[rng.randi_range(0, leaf_materials.size() - 1)]
        plant.add_child(leaf_cluster)
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
        mote.position = Vector3(rng.randf_range(-4.35, 4.35) * HABITAT_LINEAR_SCALE, rng.randf_range(-0.3, 3.10), rng.randf_range(-3.05, 3.05) * HABITAT_LINEAR_SCALE)
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
    var frame_color := Color(0.12, 0.15, 0.13)
    for x in [-HABITAT_HALF_X, HABITAT_HALF_X]:
        for z in [-HABITAT_HALF_Z, HABITAT_HALF_Z]:
            _segment(self, Vector3(x, -0.53, z), Vector3(x, HABITAT_CEILING_Y, z), 0.024, frame_color)
    for y in [-0.53, HABITAT_CEILING_Y]:
        for z in [-HABITAT_HALF_Z, HABITAT_HALF_Z]:
            _segment(self, Vector3(-HABITAT_HALF_X, y, z), Vector3(HABITAT_HALF_X, y, z), 0.024, frame_color)
        for x in [-HABITAT_HALF_X, HABITAT_HALF_X]:
            _segment(self, Vector3(x, y, -HABITAT_HALF_Z), Vector3(x, y, HABITAT_HALF_Z), 0.024, frame_color)
    # Low-cost substrate details; avoids expensive transparent foliage layers.
    var root := Node3D.new()
    root.name = "SubstrateDetails"
    root.scale = Vector3(HABITAT_LINEAR_SCALE, 1.0, HABITAT_LINEAR_SCALE)
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
    for i in range(240):
        var item := MeshInstance3D.new()
        item.mesh = stone_mesh if i % 4 == 0 else leaf_mesh
        item.material_override = stone_mat if i % 4 == 0 else leaf_mat
        item.position = Vector3(rng.randf_range(-4.52, 4.52), -0.535, rng.randf_range(-3.18, 3.18))
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
    if latest_mantis_player != null and use_latest_mantis_visual:
        latest_mantis_player.speed_scale = 0.0 if simulation_paused else 1.0
    if use_photo_visual:
        _update_photo_visual(0.0 if simulation_paused else minf(delta, 0.1))
    if simulation_paused:
        return
    var dt := minf(delta, 0.1)
    elapsed += dt
    if current_species not in ["butterfly", "hermit_crab", "stream_salamander"]:
        _animate_ecosystem(dt)
    if habitat_interactions != null and current_species not in ["butterfly", "hermit_crab", "stream_salamander"]:
        habitat_interactions.simulate(dt)
    if current_species in ["fish", "crayfish"]:
        aquarium_system.call("simulate", dt)
        if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
            _refresh()
        _update_camera()
        return
    if current_species == "butterfly":
        butterfly_system.call("simulate", dt)
        if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
            _refresh()
        _update_camera()
        return
    if current_species == "hermit_crab":
        hermit_crab_system.call("simulate", dt)
        if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
            _refresh()
        _update_camera()
        return
    if current_species == "stream_salamander":
        stream_salamander_system.call("simulate", dt)
        if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
            _refresh()
        _update_camera()
        return
    if use_photo_visual:
        behavior = "원본 사진 정지 관찰"
        if int(elapsed * 2.0) != int((elapsed - dt) * 2.0):
            _refresh()
        if follow_animal:
            _update_camera()
        return
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
            animal.scale = Vector3.ONE * _growth_visual_scale()
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
            animal.position.x = clampf(animal.position.x, -ROAM_HALF_X, ROAM_HALF_X)
            animal.position.z = clampf(animal.position.z, -ROAM_HALF_Z, ROAM_HALF_Z)
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
        roam_target = Vector3(randf_range(-ROAM_HALF_X, ROAM_HALF_X), -0.38, randf_range(-ROAM_HALF_Z, ROAM_HALF_Z))
    var direction := roam_target - animal.position
    if direction.length() > 0.03:
        animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), dt * 3.0)
        animal.position = animal.position.move_toward(roam_target, dt * 0.085)
        animal.position.x = clampf(animal.position.x, -ROAM_HALF_X, ROAM_HALF_X)
        animal.position.z = clampf(animal.position.z, -ROAM_HALF_Z, ROAM_HALF_Z)
        energy = maxf(0.0, energy - dt * 0.3)

func _input(event: InputEvent) -> void:
    var camera_changed := false
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        camera_mouse_dragging = event.pressed and not editing and not _is_ui_hit(event.position)
    elif event is InputEventMouseMotion and camera_mouse_dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
        _orbit(event.relative)
        camera_changed = true
    elif event is InputEventScreenTouch:
        if event.pressed:
            if not _is_ui_hit(event.position):
                camera_touch_points[event.index] = event.position
        else:
            camera_touch_points.erase(event.index)
        camera_pinch_previous = 0.0
    elif event is InputEventScreenDrag and camera_touch_points.has(event.index):
        camera_touch_points[event.index] = event.position
        if camera_touch_points.size() == 1:
            _orbit(event.relative)
            camera_changed = true
        elif camera_touch_points.size() == 2:
            var points: Array = camera_touch_points.values()
            var distance: float = points[0].distance_to(points[1])
            if camera_pinch_previous > 0.0:
                orbit_distance = clampf(orbit_distance - (distance - camera_pinch_previous) * 0.008, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
                camera_changed = true
            camera_pinch_previous = distance
    if camera_changed:
        _update_camera()

func _is_ui_hit(position: Vector2) -> bool:
    if root_ui == null:
        return false
    return _ui_tree_hit(root_ui, position)

func _ui_tree_hit(parent: Control, position: Vector2) -> bool:
    for child in parent.get_children():
        if child is Control:
            var control := child as Control
            if control.is_visible_in_tree():
                if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(position):
                    return true
                if _ui_tree_hit(control, position):
                    return true
    return false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            orbit_distance = maxf(CAMERA_MIN_DISTANCE, orbit_distance - 0.25)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            orbit_distance = minf(CAMERA_MAX_DISTANCE, orbit_distance + 0.25)
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
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
        _set_camera_preset(true)
    _update_camera()

func _orbit(motion: Vector2) -> void:
    orbit_yaw = fposmod(orbit_yaw - motion.x * 0.008, TAU)
    orbit_pitch = clampf(orbit_pitch + motion.y * 0.006, -1.52, 1.52)

func _set_camera_preset(close_view: bool) -> void:
    follow_animal = close_view
    habitat_framing = not close_view
    orbit_yaw = 1.43 if close_view else 0.0
    orbit_pitch = 0.26 if close_view else 0.30
    if close_view:
        orbit_distance = 2.80
    else:
        var viewport_size := get_viewport().get_visible_rect().size
        var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
        var vertical_fov := deg_to_rad(camera.fov)
        var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * maxf(aspect, 0.1))
        var habitat_size := _current_habitat_size()
        var fit_width := maxf(habitat_size.x, habitat_size.z) / (2.0 * tan(horizontal_fov * 0.5)) * 1.14
        var fit_height := habitat_size.y / (2.0 * tan(vertical_fov * 0.5)) * 1.18
        orbit_distance = clampf(maxf(7.0, maxf(fit_width, fit_height)), 7.0, CAMERA_MAX_DISTANCE)
    _update_camera()

func _current_habitat_size() -> Vector3:
    match current_species:
        "fish", "crayfish":
            return Vector3(4.45, 1.35, 3.0)
        "butterfly":
            return Vector3(4.55, 1.55, 3.10)
        "hermit_crab":
            return Vector3(4.58, 1.18, 3.18) * HERMIT_TANK_LINEAR_SCALE
        "stream_salamander":
            return Vector3(5.05, 1.95, 3.48) * SALAMANDER_TANK_LINEAR_SCALE
        _:
            return Vector3(HABITAT_WIDTH, HABITAT_WALL_HEIGHT, HABITAT_DEPTH)

func _update_camera() -> void:
    if camera == null:
        return
    var center: Vector3
    if current_species in ["fish", "crayfish"]:
        center = Vector3(-0.62, -0.16, -0.28) if current_species == "crayfish" else Vector3(0, -0.04, 0)
    elif current_species == "butterfly":
        center = butterfly_system.call("focus_position") if follow_animal else Vector3(0, 0.30, 0)
    elif current_species == "hermit_crab":
        center = hermit_crab_system.to_global(hermit_crab_system.call("focus_position")) if follow_animal else Vector3(0, -0.02, 0)
    elif current_species == "stream_salamander":
        center = stream_salamander_system.to_global(stream_salamander_system.call("focus_position")) if follow_animal else Vector3(0, -0.06, 0)
    else:
        center = animal.position + Vector3(0, 0.35, 0) if follow_animal and animal != null else Vector3(0, 0.48 if habitat_framing else 0.0, 0)
    camera.position = center + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
    camera.look_at(center, Vector3.UP)

func _refresh() -> void:
    if status == null:
        return
    if current_species == "fish":
        var fish_total := int(aquarium_system.call("fish_count")) if aquarium_system != null else 0
        var flow_text := "켜짐" if aquarium_system != null and bool(aquarium_system.get("flow_enabled")) else "꺼짐"
        status.text = "열대어: %d마리 | 수초: 13군락\n여과기 물살: %s\n수조 물 높이: 90cm\n행동: 무리 지어 유영%s" % [fish_total, flow_text, " (정지)" if simulation_paused else ""]
        return
    if current_species == "crayfish":
        var crayfish_activity := String(aquarium_system.call("crayfish_status")) if aquarium_system != null else "굴 안에서 휴식"
        var flow_text := "켜짐" if aquarium_system != null and bool(aquarium_system.get("flow_enabled")) else "꺼짐"
        status.text = "가재: 1마리 | 은신처: 바위 틈 굴\n행동: %s\n여과기 물살: %s | 수초: 13군락%s" % [crayfish_activity, flow_text, " (정지)" if simulation_paused else ""]
        return
    if current_species == "butterfly":
        var butterfly_activity := String(butterfly_system.call("activity_status")) if butterfly_system != null else "정지"
        var butterfly_count := int(butterfly_system.call("butterfly_count")) if butterfly_system != null else 0
        var flower_count := int(butterfly_system.call("flower_count")) if butterfly_system != null else 0
        var nectar := int(butterfly_system.call("nectar_percent")) if butterfly_system != null else 0
        var butterfly_temp := float(butterfly_system.get("temperature")) if butterfly_system != null else 25.0
        status.text = "호랑나비: %d마리 | 꽃: %d송이\n꽃꿀: %d%% | 온도: %.1f°C\n수분 활동: %d회\n행동: %s%s" % [butterfly_count, flower_count, nectar, butterfly_temp, int(butterfly_system.get("pollination_count")), butterfly_activity, " (정지)" if simulation_paused else ""]
        return
    if current_species == "hermit_crab":
        var crab_count := int(hermit_crab_system.call("crab_count")) if hermit_crab_system != null else 0
        var shell_count := int(hermit_crab_system.call("shell_count")) if hermit_crab_system != null else 0
        var crab_activity := String(hermit_crab_system.call("activity_status")) if hermit_crab_system != null else "정지"
        var crab_temp := float(hermit_crab_system.get("temperature")) if hermit_crab_system != null else 25.0
        var crab_humidity := float(hermit_crab_system.get("humidity")) if hermit_crab_system != null else 78.0
        var crab_water := int(hermit_crab_system.call("water_percent")) if hermit_crab_system != null else 100
        status.text = "육지소라게: %d마리 | 예비 껍데기: %d개\n은신처: 바위 틈 | 민물·염수: %d%%\n온도: %.1f°C | 습도: %.0f%%\n행동: %s%s" % [crab_count, shell_count, crab_water, crab_temp, crab_humidity, crab_activity, " (정지)" if simulation_paused else ""]
        return
    if current_species == "stream_salamander":
        var salamander_count := int(stream_salamander_system.call("salamander_count")) if stream_salamander_system != null else 0
        var salamander_activity := String(stream_salamander_system.call("activity_status")) if stream_salamander_system != null else "정지"
        var salamander_temp := float(stream_salamander_system.get("temperature")) if stream_salamander_system != null else 19.0
        var salamander_humidity := float(stream_salamander_system.get("humidity")) if stream_salamander_system != null else 92.0
        var flow_text := "켜짐" if stream_salamander_system != null and bool(stream_salamander_system.get("flow_enabled")) else "꺼짐"
        status.text = "계곡 도롱뇽: %d마리 | 은신처: 젖은 바위틈\n개울 물살: %s | 온도: %.1f°C\n습도: %.0f%%\n행동: %s%s" % [salamander_count, flow_text, salamander_temp, salamander_humidity, salamander_activity, " (정지)" if simulation_paused else ""]
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
                var x: float = clampf(float(entry.get("x", 0.0)), -4.35, 4.35)
                var z: float = clampf(float(entry.get("z", 0.0)), -3.05, 3.05)
                if kind in ["rock", "wood"]:
                    _add_decoration(kind, Vector3(x, -0.50, z))
    life_age = maxf(0.0, float(parsed.get("life_age", 0.0)))
    molt_count = clampi(int(parsed.get("molt_count", 0)), 0, 5)
    growth = clampf(float(parsed.get("growth", 0.35)), 0.35, 1.0)
    animal.scale = Vector3.ONE * _growth_visual_scale()
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
        if latest_mantis_player != null and latest_mantis_clip == "STRIKE" and use_latest_mantis_visual:
            latest_mantis_player.seek(0.0, true)
    if animation_label != null:
        animation_label.text = "애니메이션: " + clip

func _set_frontleg_animation(index: int) -> void:
    if index < 0:
        selected_frontleg_animation = -1
        if rigged_pose_driver != null:
            rigged_pose_driver.stop_front_leg_animation()
        use_latest_mantis_visual = true
        _apply_visual_mode()
        if frontleg_animation_label != null:
            frontleg_animation_label.text = "앞다리 동작: 최신 모델 기본 포획 자세"
        return
    selected_frontleg_animation = posmod(index, FRONT_LEG_VARIANT_COUNT)
    if use_latest_mantis_visual:
        use_latest_mantis_visual = false
        _apply_visual_mode()
        notice.text = "세부 앞다리 관절 시연을 위해 전체 스킨 리그 모델로 전환했습니다."
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
