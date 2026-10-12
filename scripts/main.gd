extends Node3D

const SAVE_PATH := "user://terrarium_save_v6.json"
const BACKUP_PATH := "user://terrarium_save_v6_backup.json"
const V5_SAVE_PATH := "user://terrarium_save_v5.json"
const V4_SAVE_PATH := "user://terrarium_save_v4.json"
const MAX_DECORATIONS := 32
const PREVIOUS_SAVE_PATH := "user://terrarium_save_v3.json"
const LEGACY_SAVE_PATH := "user://terrarium_save_v2.json"
const MAX_FOOD := 36
const SAVE_SLOT_COUNT := 12
const ACTIVE_SLOT_PATH := "user://active_mantis_slot.txt"
const LATEST_MODEL_LOCK := "res://assets/models/mantis_rigged.glb"
const LATEST_MODEL_MIN_BONES := 61
const LATEST_MODEL_MIN_CLIPS := 10
const LATEST_MODEL_MIN_MESHES := 30
const SPECIES_NAMES: Array[String] = ["치앙마이형 (Hierodula sp.)", "왕사마귀", "중국사마귀", "유럽사마귀", "고스트사마귀", "꽃사마귀"]
const PREY_TYPES: Array[String] = ["귀뚜라미", "두비아바퀴", "초파리", "검정파리", "밀웜", "왁스웜", "풀무치", "나방"]
const BIOME_NAMES: Array[String] = ["열대 우림", "건조 초원", "사막", "온대림"]
const LIFE_STAGES: Array[String] = ["1령 약충", "2령 약충", "3령 약충", "4령 약충", "5령 약충", "6령 약충", "성체"]
const NYMPH_SIZE_FACTORS: Array[float] = [0.23, 0.30, 0.40, 0.52, 0.67, 0.84]
const NYMPH_WING_PAD_FACTORS: Array[float] = [0.34, 0.43, 0.54, 0.68, 0.83, 1.0]
const LATEST_MODEL_REQUIRED_CLIPS: Array[String] = ["IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND"]
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
var orbit_distance := 9.4
var camera_pan := Vector3.ZERO
const CAMERA_MIN_DISTANCE := 0.65
const CAMERA_MAX_DISTANCE := 240.0
const CAMERA_MOVE_SPEED := 20.0
const CAMERA_BOOST_MULTIPLIER := 4.0
const WALK_BOUND_X := 5.05
const WALK_BOUND_Z := 3.72
const PREY_BOUND_X := 5.28
const PREY_BOUND_Z := 3.92
var pointer_last := Vector2.ZERO
var touching := false
var touch_points: Dictionary = {}
var pinch_previous := 0.0
var roam_target := Vector3.ZERO
var roam_time := 0.0
var roam_target_valid := false
var roam_pause_time := 2.4
var roam_speed := 0.0
var elapsed := 0.0
var legs: Array[Node3D] = []
var antennae: Array[Node3D] = []
var root_ui: Control
var prey_nodes: Array[Node3D] = []
var prey_kinds: Dictionary = {}
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
var prey_pause_timers: Dictionary = {}
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
var model_status_label: Label
var species_picker: OptionButton
var stage_picker: OptionButton
var biome_picker: OptionButton
var prey_picker: OptionButton
var save_slot_picker: OptionButton
var mantis_name_edit: LineEdit
var camera_touch_directions: Dictionary = {}
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
var wing_texture: Texture2D
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
const FOOT_SWING_DURATION := 0.30

# v2.4: imported skinned GLB is the visible model; the existing procedural
# hierarchy remains an invisible motion/IK fallback and physics reference.
const LATEST_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_rigged.glb")
var rigged_visual: Node3D
var rigged_player: AnimationPlayer
var rigged_clip := ""
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
var selected_species := "치앙마이형 (Hierodula sp.)"
var life_stage := "성체"
var selected_biome := "열대 우림"
var selected_prey_type := "귀뚜라미"
var active_save_slot := 1
var mantis_name := "초록이"
var juvenile_wing_buds: Node3D
var habitat_floor: MeshInstance3D
var world_environment: Environment
var directional_light: DirectionalLight3D
var biome_accent_root: Node3D
var biome_base_colors: Dictionary = {}
# v2.6: scripted traversal of a real, collidable inclined branch.
var climb_active := false
var climb_progress := 0.0
var climb_cooldown := 18.0
var climb_branch_start := Vector3(-0.48, -0.48, 0.62)
var climb_branch_end := Vector3(-0.18, 0.92, 0.38)
const CLIMB_SPEED := 0.34
const CLIMB_BODY_CLEARANCE := 0.205
var climb_direction := 1.0
var climb_pause := 0.0
var climb_midpoint_pause_used := false
var flight_demo_clock := 0.0
var flight_start_position := Vector3.ZERO
var flight_start_yaw := 0.0
const FLIGHT_TAKEOFF_DURATION := 0.95
var feed_demo_prey: Node3D
var manual_command := ""
var command_timer := 0.0
var command_elapsed := 0.0
var jump_start := Vector3.ZERO
var jump_end := Vector3.ZERO
var hang_start := Vector3.ZERO
var social_partner: Node3D
var social_partner_player: AnimationPlayer
var social_partner_clip := ""
var command_origin := Vector3.ZERO
var command_origin_rotation := Quaternion.IDENTITY







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
    active_save_slot = _read_active_save_slot()
    _load_textures()
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
    habitat_motion_root.scale = Vector3(1.28, 1.0, 1.28)
    habitat_interactions = HabitatInteractions.new()
    habitat_interactions.name = "HabitatInteractions"
    add_child(habitat_interactions)
    habitat_interactions.setup(self)
    _load_state(false)
    _sync_prey()
    _apply_biome_profile()
    _apply_species_appearance()
    _apply_life_stage()
    _sync_profile_selectors()
    _update_camera()
    _refresh()

func _initialize_rigged_visual() -> void:
    # The latest photo-guided rig is the only visible mantis model.
    # Procedural meshes stay hidden and serve only as pose and physics references.
    procedural_meshes.clear()
    _collect_procedural_meshes(animal)
    for part in procedural_meshes:
        if is_instance_valid(part):
            part.visible = false
    var imported := LATEST_MANTIS_SCENE.instantiate()
    if not imported is Node3D:
        rigged_import_warnings.append("GLB root is not Node3D")
        print("Mantis rig initialization failed: ", rigged_import_warnings.back())
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
        print("Mantis rig initialization failed: ", rigged_import_warnings.back())
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
    rigged_skeleton = _find_rigged_skeleton(rigged_visual)
    var model_mesh_count := _count_model_meshes(rigged_visual)
    var required_clips_present := true
    for required_clip in LATEST_MODEL_REQUIRED_CLIPS:
        if not rigged_clips.has(required_clip):
            required_clips_present = false
            break
    var required_bones_present := _has_latest_model_bones(rigged_skeleton)
    var model_path_matches := LATEST_MANTIS_SCENE.resource_path == LATEST_MODEL_LOCK
    rigged_available = (
        model_path_matches
        and rigged_clips.size() >= LATEST_MODEL_MIN_CLIPS
        and required_clips_present
        and rigged_skeleton != null
        and rigged_skeleton.get_bone_count() >= LATEST_MODEL_MIN_BONES
        and required_bones_present
        and model_mesh_count >= LATEST_MODEL_MIN_MESHES
    )
    if not rigged_available:
        rigged_import_warnings.append("Latest model contract failed: path_matches=%s meshes=%d bones=%d clips=%d required_clips=%s required_bones=%s" % [str(model_path_matches), model_mesh_count, rigged_skeleton.get_bone_count() if rigged_skeleton != null else 0, rigged_clips.size(), str(required_clips_present), str(required_bones_present)])
        print("Mantis rig initialization failed: ", rigged_import_warnings.back())
        rigged_visual.visible = false
    _apply_visual_mode()
    if rigged_available:
        rigged_pose_driver = RiggedPoseDriver.new()
        rigged_pose_driver.name = "RiggedPoseDriver"
        rigged_visual.add_child(rigged_pose_driver)
        rigged_pose_driver.setup(rigged_skeleton, rigged_player)
        rigged_pose_status = rigged_pose_driver.validation_message
        if not rigged_pose_driver.hierarchical_chains:
            rigged_import_warnings.append("Hierarchical leg IK unavailable; using fallback")
        rigged_ik_enabled = rigged_pose_driver.valid
        _create_juvenile_wing_buds()
        _apply_life_stage()
        _play_rigged_clip("IDLE")

func _has_latest_model_bones(skeleton: Skeleton3D) -> bool:
    if skeleton == null:
        return false
    for side in ["L", "R"]:
        for index in range(3):
            for prefix in ["Coxa", "Joint", "Tibia", "Foot"]:
                if skeleton.find_bone("Rig_%s_%s%d" % [prefix, side, index]) < 0:
                    return false
        for prefix in ["ForeFemur", "ForeTibia", "Antenna"]:
            if skeleton.find_bone("Rig_%s_%s" % [prefix, side]) < 0:
                return false
    for name in ["Rig_Head", "Rig_Thorax"]:
        if skeleton.find_bone(name) < 0:
            return false
    return true

func _count_model_meshes(root: Node) -> int:
    var count := 0
    var candidates: Array = root.find_children("*", "MeshInstance3D", true, false)
    for candidate in candidates:
        var part := candidate as MeshInstance3D
        if part != null and part.mesh != null:
            count += 1
    return count

func _create_juvenile_wing_buds() -> void:
    if rigged_visual == null or juvenile_wing_buds != null:
        return
    juvenile_wing_buds = Node3D.new()
    juvenile_wing_buds.name = "JuvenileWingBudModel"
    rigged_visual.add_child(juvenile_wing_buds)
    for side in [-1.0, 1.0]:
        var bud := MeshInstance3D.new()
        bud.name = "NymphWingBud_%d" % int(side)
        var mesh := SphereMesh.new()
        mesh.radial_segments = 16
        mesh.rings = 8
        bud.mesh = mesh
        bud.scale = Vector3(0.22, 0.075, 0.37)
        bud.position = Vector3(side * 0.105, 0.205, 0.13)
        var material := StandardMaterial3D.new()
        material.albedo_color = _species_tint().lightened(0.14)
        material.roughness = 0.58
        bud.material_override = material
        juvenile_wing_buds.add_child(bud)

func _style_rigged_materials(root: Node) -> void:
    # Use the imported vertex palette with the repository's cuticle, wing, and
    # eye maps. GLB surfaces have no embedded materials, so set them explicitly.
    var body_material := StandardMaterial3D.new()
    body_material.vertex_color_use_as_albedo = true
    body_material.albedo_color = _species_tint()
    body_material.albedo_texture = body_texture
    body_material.uv1_triplanar = true
    body_material.uv1_triplanar_sharpness = 8.0
    body_material.uv1_scale = Vector3(18.0, 18.0, 18.0)
    body_material.roughness = 0.72
    _apply_pbr(body_material, "mantis_cuticle")
    body_material.roughness = 0.72

    var wing_material := StandardMaterial3D.new()
    wing_material.vertex_color_use_as_albedo = true
    wing_material.albedo_color = _species_tint().lightened(0.06)
    wing_material.albedo_texture = wing_texture
    wing_material.roughness = 0.82
    wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _apply_pbr(wing_material, "mantis_wing")
    wing_material.roughness = 0.82
    wing_material.normal_scale = 0.24

    var hindwing_material := wing_material.duplicate() as StandardMaterial3D
    hindwing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hindwing_material.albedo_color.a = 0.82

    var eye_material := StandardMaterial3D.new()
    eye_material.albedo_texture = eye_texture
    eye_material.albedo_color = Color(0.82, 0.87, 0.60)
    eye_material.roughness = 0.34
    _apply_pbr(eye_material, "mantis_eye")

    var pupil_material := StandardMaterial3D.new()
    pupil_material.albedo_color = Color(0.10, 0.16, 0.045)
    pupil_material.roughness = 0.34

    var glint_material := StandardMaterial3D.new()
    glint_material.albedo_color = Color(0.76, 0.84, 0.58)
    glint_material.roughness = 0.22

    _apply_rigged_materials_recursive(
        root,
        body_material,
        wing_material,
        hindwing_material,
        eye_material,
        pupil_material,
        glint_material
    )

func _apply_rigged_materials_recursive(
    root: Node,
    body_material: StandardMaterial3D,
    wing_material: StandardMaterial3D,
    hindwing_material: StandardMaterial3D,
    eye_material: StandardMaterial3D,
    pupil_material: StandardMaterial3D,
    glint_material: StandardMaterial3D
) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var part := child as MeshInstance3D
            # Keep the anatomically correct two walking pairs plus the raptorial pair.
            # The imported asset's third ordinary pair is redundant; retain its bones
            # for clip compatibility, but hide its six mesh segments.
            if part.name in ["Coxa_L2", "Joint_L2", "Tibia_L2", "Coxa_R2", "Joint_R2", "Tibia_R2"]:
                part.visible = false
            elif part.name.begins_with("Hindwing_"):
                part.material_override = hindwing_material
            elif part.name.begins_with("Wing_") or part.name.begins_with("WingVeinDetail_"):
                part.material_override = wing_material
            elif part.name.begins_with("EyePupil_"):
                part.material_override = pupil_material
            elif part.name.begins_with("EyeGlint_"):
                part.material_override = glint_material
            elif part.name.begins_with("Eye_"):
                part.material_override = eye_material
            else:
                part.material_override = body_material
        _apply_rigged_materials_recursive(
            child,
            body_material,
            wing_material,
            hindwing_material,
            eye_material,
            pupil_material,
            glint_material
        )

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
    # Never switch back to the older procedural rendering path.
    for part in procedural_meshes:
        if is_instance_valid(part):
            part.visible = false
    if rigged_visual != null:
        rigged_visual.visible = rigged_available
    if rigged_player != null:
        if rigged_available:
            rigged_player.speed_scale = 1.0
        else:
            rigged_player.stop()
    rigged_clip = ""
    if rigged_pose_driver != null:
        rigged_pose_driver.enabled = rigged_available and rigged_ik_enabled
        if not rigged_available:
            rigged_pose_driver.reset_offsets()

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
    if not rigged_available or rigged_visual == null:
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
    wing_texture = load("res://assets/textures/mantis_wing_albedo.png")
    eye_texture = load("res://assets/textures/mantis_eye_albedo.png")
    bark_texture = load("res://assets/textures/bark_albedo.png")
    substrate_texture = load("res://assets/textures/substrate_albedo.png")
    stone_texture = load("res://assets/textures/stone_albedo.png")
    for kind in ["mantis_cuticle", "mantis_wing", "mantis_eye", "bark", "substrate", "stone"]:
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
    env.ambient_light_energy = 0.98
    world_environment = env
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.48
    sun.shadow_enabled = true
    directional_light = sun
    add_child(sun)
    # Adult and juvenile habitats now have an 11.2 x 8.2 x 7.1 walkable volume.
    habitat_floor = _box(Vector3(11.2, 0.2, 8.2), Vector3(0, -0.65, 0), Color(0.23, 0.15, 0.09))
    _box(Vector3(11.2, 7.1, 0.06), Vector3(0, 2.90, -4.12), Color(0.13, 0.19, 0.16, 0.42), true)
    _box(Vector3(11.0, 6.95, 0.035), Vector3(0, 2.90, -4.075), Color(0.66, 0.72, 0.48))
    _box(Vector3(0.05, 7.1, 8.2), Vector3(-5.62, 2.90, 0), Color(0.5, 0.7, 0.7, 0.12), true)
    _box(Vector3(0.05, 7.1, 8.2), Vector3(5.62, 2.90, 0), Color(0.5, 0.7, 0.7, 0.12), true)
    var branch_rng := RandomNumberGenerator.new()
    branch_rng.seed = 9182026
    var branch_clusters: Array[Vector2] = [Vector2(-2.22, -1.42), Vector2(-2.30, -0.60), Vector2(-2.16, 0.42), Vector2(-1.82, 1.48), Vector2(-0.92, 1.48), Vector2(0.88, 1.48), Vector2(1.88, 1.40), Vector2(2.24, 0.63), Vector2(2.28, -0.42), Vector2(1.92, -1.42), Vector2(0.74, -1.48), Vector2(-0.84, -1.45)]
    # A crooked, buttressed tree line builds a deep forest edge and canopy;
    # the center stays open enough to watch the mantis move and feed.
    var trunk_sites: Array[Vector2] = [Vector2(-2.28, -1.47), Vector2(-1.70, -1.57), Vector2(-0.95, -1.60), Vector2(0.10, -1.62), Vector2(1.22, -1.58), Vector2(2.18, -1.43), Vector2(-2.30, -0.44), Vector2(-2.25, 0.72), Vector2(-1.88, 1.48), Vector2(1.84, 1.48), Vector2(2.28, 0.69), Vector2(2.25, -0.65), Vector2(-2.84, -1.83), Vector2(-2.86, -0.24), Vector2(-2.82, 1.58), Vector2(2.83, -1.80), Vector2(2.88, -0.26), Vector2(2.82, 1.72)]
    for i in range(trunk_sites.size()):
        var site: Vector2 = trunk_sites[i]
        var start := Vector3(site.x + branch_rng.randf_range(-0.13, 0.13), -0.53, site.y + branch_rng.randf_range(-0.12, 0.12))
        var bend := Vector3(branch_rng.randf_range(-0.28, 0.28), branch_rng.randf_range(0.50, 0.85), branch_rng.randf_range(-0.20, 0.20))
        var mid := start + bend
        var top := Vector3(clampf(mid.x + branch_rng.randf_range(-0.34, 0.34), -2.98, 2.98), branch_rng.randf_range(3.55, 4.35), clampf(mid.z + branch_rng.randf_range(-0.30, 0.30), -2.22, 2.22))
        var trunk_radius := branch_rng.randf_range(0.115, 0.17)
        _tapered_branch(start, mid, trunk_radius, trunk_radius * 0.70)
        _tapered_branch(mid, top, trunk_radius * 0.72, branch_rng.randf_range(0.035, 0.060))
        # Roots flare out at different angles and lengths rather than repeating
        # a regular row of thin upright poles.
        for root_index in range(branch_rng.randi_range(3, 5)):
            var angle := float(root_index) * TAU / 3.0 + branch_rng.randf_range(-0.3, 0.3)
            var root_end := Vector3(clampf(start.x + cos(angle) * branch_rng.randf_range(0.22, 0.38), -3.0, 3.0), -0.485, clampf(start.z + sin(angle) * branch_rng.randf_range(0.20, 0.37), -2.25, 2.25))
            _tapered_branch(root_end, start + Vector3(0.0, 0.08, 0.0), 0.025, trunk_radius * 0.48)
        var fork_count := branch_rng.randi_range(3, 5)
        for fork_index in range(fork_count):
            var fork_start := start.lerp(top, branch_rng.randf_range(0.48, 0.90))
            var fork_end := Vector3(clampf(fork_start.x + branch_rng.randf_range(-0.56, 0.56), -3.0, 3.0), minf(5.08, fork_start.y + branch_rng.randf_range(0.42, 0.88)), clampf(fork_start.z + branch_rng.randf_range(-0.48, 0.48), -2.25, 2.25))
            _tapered_branch(fork_start, fork_end, branch_rng.randf_range(0.040, 0.070), branch_rng.randf_range(0.012, 0.022))
    # Fallen wood is scattered among the planted edges and leaf litter.
    for i in range(18):
        var cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var start := Vector3(cluster.x + branch_rng.randf_range(-0.24, 0.24), -0.49, cluster.y + branch_rng.randf_range(-0.22, 0.22))
        var end := Vector3(clampf(start.x + branch_rng.randf_range(-0.56, 0.56), -3.0, 3.0), start.y + branch_rng.randf_range(0.04, 0.26), clampf(start.z + branch_rng.randf_range(-0.48, 0.48), -2.25, 2.25))
        _tapered_branch(start, end, branch_rng.randf_range(0.050, 0.085), branch_rng.randf_range(0.016, 0.030))
    for i in range(88):
        var rock_cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var p := Vector3(clampf(rock_cluster.x + branch_rng.randf_range(-0.38, 0.38), -3.0, 3.0), -0.49, clampf(rock_cluster.y + branch_rng.randf_range(-0.34, 0.34), -2.25, 2.25))
        var pebble_size: Vector3 = Vector3(branch_rng.randf_range(0.040, 0.105), branch_rng.randf_range(0.014, 0.039), branch_rng.randf_range(0.035, 0.095))
        var pebble_color: Color = Color(0.19, 0.23, 0.18).lerp(Color(0.39, 0.34, 0.25), branch_rng.randf())
        _ellipsoid(p, pebble_size, pebble_color)
    for i in range(24):
        var cluster: Vector2 = branch_clusters[branch_rng.randi_range(0, branch_clusters.size() - 1)]
        var rock_pos := Vector3(clampf(cluster.x + branch_rng.randf_range(-0.30, 0.30), -3.0, 3.0), -0.49, clampf(cluster.y + branch_rng.randf_range(-0.28, 0.28), -2.25, 2.25))
        var rock_size := Vector3(branch_rng.randf_range(0.12, 0.24), branch_rng.randf_range(0.045, 0.12), branch_rng.randf_range(0.10, 0.22))
        _ellipsoid(rock_pos, rock_size, Color(0.19, 0.25, 0.19).lerp(Color(0.42, 0.36, 0.27), branch_rng.randf()))

func _create_climbable_branch() -> void:
    # A tall, slightly leaning trunk has a continuous collider so the animal
    # can grip the bark all the way into the upper canopy.
    climb_branch_start = Vector3(-0.72, -0.48, -0.54)
    climb_branch_end = Vector3(-0.38, 4.72, -0.22)
    _tapered_branch(climb_branch_start, climb_branch_end, 0.160, 0.082)
    var fork_levels := [0.24, 0.42, 0.60, 0.78, 0.90]
    for i in range(fork_levels.size()):
        var t: float = fork_levels[i]
        var fork_start := climb_branch_start.lerp(climb_branch_end, t)
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var fork_end := fork_start + Vector3(side * (0.62 + 0.13 * float(i)), 0.54 + 0.12 * float(i), -0.22)
        _tapered_branch(fork_start, fork_end, 0.058 - float(i) * 0.006, 0.014)
        var twig_start := fork_start.lerp(fork_end, 0.58)
        _tapered_branch(twig_start, twig_start + Vector3(side * 0.31, 0.23, 0.08), 0.026, 0.008)
    _walkable_wood(self, climb_branch_start, climb_branch_end, 0.145)
    var canopy_leaf_mesh := _leaf_mesh()
    var canopy_leaf_material := _material(Color(0.28, 0.48, 0.20))
    canopy_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    canopy_leaf_material.vertex_color_use_as_albedo = true
    canopy_leaf_material.roughness = 0.82
    for i in range(12):
        var t: float = 0.26 + float(floori(float(i) / 2.0)) * 0.115
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var leaf_joint := Node3D.new()
        leaf_joint.name = "HighPerchLeaf_%02d" % i
        leaf_joint.position = climb_branch_start.lerp(climb_branch_end, minf(t, 0.92)) + Vector3(side * 0.10, 0.015, 0.0)
        leaf_joint.rotation = Vector3(-0.30, side * (0.55 + float(i % 3) * 0.40), side * 0.10)
        var leaf := MeshInstance3D.new()
        leaf.mesh = canopy_leaf_mesh
        leaf.material_override = canopy_leaf_material
        leaf.scale = Vector3(1.15, 0.90, 1.75)
        leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        leaf_joint.add_child(leaf)
        add_child(leaf_joint)
        plant_pivots.append(leaf_joint)
        plant_phases.append(float(i) * 0.71)
        plant_stiffness.append(0.62)

func _advance_climb(dt: float, force_demo: bool = false) -> void:
    if not climb_active:
        if (climb_cooldown > 0.0 and not force_demo) or molting or (stress > 65.0 and not force_demo) or (hunger > 45.0 and not force_demo):
            return
        # Walk towards the foot of the branch before starting the ascent.
        var approach := Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        var planar := Vector2(animal.position.x - approach.x, animal.position.z - approach.z)
        if planar.length() > 0.13:
            animal.position.x = move_toward(animal.position.x, approach.x, dt * 0.55)
            animal.position.z = move_toward(animal.position.z, approach.z, dt * 0.55)
            behavior = "나뭇가지 접근"
            return
        climb_active = true
        climb_progress = 0.0
        climb_midpoint_pause_used = false
        climb_direction = 1.0
        climb_pause = 0.0
        for i in range(foot_in_swing.size()):
            foot_in_swing[i] = false
        behavior = "나뭇가지 등반"
    if climb_pause > 0.0:
        climb_pause = maxf(0.0, climb_pause - dt)
    elif climb_direction > 0.0 and not climb_midpoint_pause_used and climb_progress >= 0.50:
        climb_midpoint_pause_used = true
        climb_pause = randf_range(1.4, 3.0)
    elif climb_direction > 0.0:
        climb_progress = minf(1.0, climb_progress + dt * CLIMB_SPEED / climb_branch_start.distance_to(climb_branch_end))
    else:
        climb_progress = maxf(0.0, climb_progress - dt * CLIMB_SPEED / climb_branch_start.distance_to(climb_branch_end))
    var center := climb_branch_start.lerp(climb_branch_end, climb_progress)
    var tangent := (climb_branch_end - climb_branch_start).normalized()
    var radial := Vector3(0.0, 0.0, 1.0)
    radial = (radial - tangent * radial.dot(tangent)).normalized()
    var across := tangent.cross(radial).normalized()
    var travel_direction := tangent * climb_direction
    # A wall-hugging climb follows the trunk surface with small alternating
    # weight shifts; the body does not translate like a lift along one rail.
    var weight_shift := across * sin(climb_progress * TAU * 5.0 + elapsed * 1.7) * 0.035
    var body_bob := radial * sin(elapsed * 4.2) * 0.012
    var target := center + radial * CLIMB_BODY_CLEARANCE + weight_shift + body_bob
    var target_basis := Basis.looking_at(travel_direction, radial)
    animal.position = animal.position.lerp(target, clampf(dt * 8.0, 0.0, 1.0))
    animal.quaternion = animal.quaternion.slerp(target_basis.get_rotation_quaternion(), clampf(dt * 7.0, 0.0, 1.0))
    behavior = "가지에 매달림" if climb_pause > 0.0 else "나뭇가지 등반"
    if climb_direction > 0.0 and climb_progress >= 1.0 and animal.position.distance_to(target) < 0.035:
        climb_direction = -1.0
        climb_pause = randf_range(2.0, 3.6)
    elif climb_direction < 0.0 and climb_progress <= 0.0 and animal.position.distance_to(target) < 0.045:
        climb_active = false
        climb_cooldown = 38.0
        animal.position = Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        animal.quaternion = Quaternion.IDENTITY
        roam_target = Vector3(climb_branch_start.x, -0.38, climb_branch_start.z)
        roam_target_valid = false
        roam_pause_time = 1.2
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
    var x_extent: float = minf(0.84, maxf(0.0, 4.72 - absf(flight_start_position.x)))
    var z_extent: float = minf(1.12, maxf(0.0, 3.35 - absf(flight_start_position.z)))
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

func _command_mantis(command: String) -> void:
    if molting and command != "MOLT":
        notice.text = "탈피가 끝난 뒤 다른 명령을 내릴 수 있습니다."
        return
    if command == manual_command:
        _finish_manual_command()
        return
    if not manual_command.is_empty():
        _finish_manual_command()
    if command in ["FLY", "CLIMB"]:
        if command == "FLY":
            _set_animation_preview("AUTO" if animation_preview == "FLY" else "FLY")
        else:
            _set_animation_preview("CLIMB")
        return
    if command == "MOLT":
        if molting:
            notice.text = "이미 탈피 중입니다."
            return
        if not _is_juvenile():
            notice.text = "성충은 마지막 탈피를 마쳤습니다."
            return
        manual_command = ""
        molting = true
        molt_progress = 0.0
        behavior = "탈피 시작"
        notice.text = "탈피를 시작했습니다. 안전한 자세를 유지합니다."
        return
    if command == "MATE" and life_stage != "성체":
        notice.text = "짝짓기 행동은 성체 단계에서 시작할 수 있습니다."
        return
    command_origin = animal.position
    command_origin_rotation = animal.quaternion
    command_elapsed = 0.0
    manual_command = command
    match command:
        "HUNT":
            if prey_nodes.is_empty():
                _add_food()
            hunger = maxf(hunger, 46.0)
            command_timer = 45.0
            behavior = "사냥 시작"
            notice.text = "가장 가까운 먹이를 추적합니다."
        "JUMP":
            var facing := Vector3(-sin(animal.rotation.y), 0.0, -cos(animal.rotation.y))
            jump_start = animal.position
            jump_end = animal.position + facing * 1.05 + Vector3(0.30 if facing.x >= 0.0 else -0.30, 0.0, 0.0)
            jump_end.x = clampf(jump_end.x, -WALK_BOUND_X, WALK_BOUND_X)
            jump_end.z = clampf(jump_end.z, -WALK_BOUND_Z, WALK_BOUND_Z)
            command_timer = 0.95
            behavior = "점프 준비"
        "HANG":
            hang_start = animal.position
            command_timer = 7.0
            behavior = "잎 뒷면을 찾는 중"
        "THREATEN", "FIGHT", "MATE":
            command_timer = 8.0 if command == "THREATEN" else 9.0 if command == "FIGHT" else 12.0
            if not _spawn_social_partner(command):
                manual_command = ""
                notice.text = "최신 모델 검증이 끝난 뒤 상대 개체를 불러올 수 있습니다."
                return
            behavior = "위협 자세" if command == "THREATEN" else "싸움 행동 시연" if command == "FIGHT" else "짝짓기 행동 시연"
            notice.text = behavior + " · 피해 없는 행동 시연"

func _spawn_social_partner(command: String) -> bool:
    _clear_social_partner()
    if not rigged_available:
        return false
    var instance := LATEST_MANTIS_SCENE.instantiate()
    if not instance is Node3D:
        return false
    social_partner = instance as Node3D
    social_partner.name = "LatestRiggedSocialPartner"
    add_child(social_partner)
    social_partner.position = animal.position + Vector3(0.95, 0.0, -0.42)
    social_partner.scale = animal.scale * (0.78 if command == "MATE" else 0.94)
    _style_rigged_materials(social_partner)
    social_partner_player = _find_rigged_player(social_partner)
    social_partner_clip = ""
    _play_social_partner_clip("IDLE")
    return true

func _play_social_partner_clip(clip: String) -> void:
    if social_partner_player == null or social_partner_clip == clip:
        return
    for library_name in social_partner_player.get_animation_library_list():
        var library := social_partner_player.get_animation_library(library_name)
        if library == null:
            continue
        for clip_name in library.get_animation_list():
            if String(clip_name).to_upper() != clip:
                continue
            var full_name := String(clip_name)
            if not String(library_name).is_empty():
                full_name = String(library_name) + "/" + full_name
            social_partner_player.play(full_name, 0.18)
            social_partner_clip = clip
            return

func _clear_social_partner() -> void:
    if social_partner != null and is_instance_valid(social_partner):
        social_partner.queue_free()
    social_partner = null
    social_partner_player = null
    social_partner_clip = ""

func _advance_manual_command(dt: float) -> void:
    command_elapsed += dt
    command_timer = maxf(0.0, command_timer - dt)
    match manual_command:
        "HUNT":
            var prey := _nearest_prey()
            if prey == null:
                _finish_manual_command()
                return
            behavior = "먹이 추적"
            var delta_to_prey := prey.position - animal.position
            if delta_to_prey.length() > 0.015:
                animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-delta_to_prey.x, -delta_to_prey.z), dt * 3.4)
                animal.position = animal.position.move_toward(prey.position, dt * 0.28)
            if animal.position.distance_to(prey.position) < 0.20:
                _consume_prey(prey)
                if hunger < 25.0 or prey_nodes.is_empty():
                    _finish_manual_command()
            elif command_timer <= 0.0:
                _finish_manual_command()
        "JUMP":
            var t := clampf(command_elapsed / 0.95, 0.0, 1.0)
            var eased := t * t * (3.0 - 2.0 * t)
            animal.position = jump_start.lerp(jump_end, eased)
            animal.position.y = jump_start.y + sin(t * PI) * 0.78
            behavior = "점프 중" if t < 1.0 else "착지"
            if t >= 1.0:
                animal.position = jump_end
                _finish_manual_command()
        "HANG":
            var t := clampf(command_elapsed / 1.25, 0.0, 1.0)
            var perch := Vector3(climb_branch_end.x + 0.08, climb_branch_end.y + 0.26, climb_branch_end.z)
            animal.position = hang_start.lerp(perch, t)
            animal.quaternion = animal.quaternion.slerp(Quaternion(Vector3.RIGHT, PI), clampf(dt * 2.4, 0.0, 1.0))
            behavior = "잎 뒷면에 거꾸로 매달림"
            if command_timer <= 0.0:
                _finish_manual_command()
        "THREATEN", "FIGHT", "MATE":
            _advance_social_display()
            if command_timer <= 0.0:
                _finish_manual_command()

func _advance_social_display() -> void:
    if social_partner == null or not is_instance_valid(social_partner):
        _finish_manual_command()
        return
    var face := Vector3(-sin(animal.rotation.y), 0.0, -cos(animal.rotation.y))
    var spacing := 0.78 if manual_command == "MATE" else 0.96
    var approach := 0.5 + 0.5 * sin(command_elapsed * 1.25)
    var offset := face * lerpf(spacing + 0.18, spacing - 0.12, approach)
    social_partner.position = animal.position + offset
    social_partner.rotation.y = animal.rotation.y + PI
    if manual_command == "THREATEN":
        _play_rigged_clip("DEFEND")
        _play_social_partner_clip("DEFEND")
        behavior = "서로 위협 자세를 보임"
    elif manual_command == "FIGHT":
        var strike_phase := int(floor(command_elapsed / 1.1)) % 2 == 0
        _play_rigged_clip("STRIKE" if strike_phase else "DEFEND")
        _play_social_partner_clip("DEFEND" if strike_phase else "STRIKE")
        behavior = "앞다리로 겨루는 중"
    else:
        _play_rigged_clip("IDLE")
        _play_social_partner_clip("IDLE")
        animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-offset.x, -offset.z), 0.04)
        behavior = "짝짓기 행동 시연"

func _finish_manual_command() -> void:
    var ended_command := manual_command
    manual_command = ""
    command_timer = 0.0
    _clear_social_partner()
    if ended_command == "HANG":
        animal.position = hang_start
        animal.quaternion = command_origin_rotation
    elif ended_command == "JUMP":
        animal.position = jump_end
        animal.position.y = -0.38
        animal.quaternion = command_origin_rotation
        _initialize_foot_anchors()
    elif ended_command in ["THREATEN", "FIGHT", "MATE"]:
        animal.quaternion = command_origin_rotation
    behavior = "행동 종료 · 주변 탐색"

func _consume_prey(prey: Node3D) -> void:
    if prey == null or not is_instance_valid(prey):
        return
    if habitat_interactions != null:
        habitat_interactions.unregister_prey(prey)
    var id := prey.get_instance_id()
    prey_appendages.erase(id)
    prey_velocities.erase(id)
    prey_pause_timers.erase(id)
    prey_kinds.erase(id)
    prey_nodes.erase(prey)
    prey.queue_free()
    food_count = prey_nodes.size()
    hunger = maxf(0.0, hunger - 35.0)
    energy = maxf(0.0, energy - 2.0)
    strike_time = 0.45
    _refresh()

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
    box_shape.size = Vector3(11.2, 0.2, 8.2)
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
    # Keep procedural nodes for physics and pose references; render the latest GLB only.
    animal = Node3D.new()
    animal.name = "Mantis_01"
    animal.position = Vector3(0, -0.38, 0)
    animal.scale = Vector3.ONE * (0.42 * (0.90 + growth * 0.30))
    add_child(animal)
    var mint := Color(0.48, 0.69, 0.43)
    var mint_light := Color(0.66, 0.80, 0.57)
    var mint_shadow := Color(0.28, 0.45, 0.29)
    var eye_color := Color(0.075, 0.14, 0.046)

    abdomen = Node3D.new()
    abdomen.name = "AbdomenPivot"
    animal.add_child(abdomen)
    # A continuous high-density shell gives the abdomen real side, underside,
    # and dorsal volume; pigment bands sit in the mesh instead of stacked balls.
    _create_abdomen_volume(abdomen, mint, mint_light, mint_shadow)
    for spiracle_index in range(9):
        var t: float = float(spiracle_index) / 8.0
        var z: float = -0.13 + t * 0.68
        var taper: float = 0.72 + 0.28 * sin(t * PI)
        for side in [-1.0, 1.0]:
            _part(abdomen, Vector3(side * 0.171 * taper, 0.145, z), Vector3(0.0048, 0.0035, 0.007), mint_shadow)
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
    # Long, narrow pronotum with a slightly widened rear shield.
    _create_prothorax_volume(thorax_pivot, mint, mint_light, mint_shadow)
    _part(thorax_pivot, Vector3(0, -0.003, 0.12), Vector3(0.067, 0.047, 0.11), mint_light)
    _part(thorax_pivot, Vector3(0, 0.031, -0.105), Vector3(0.047, 0.018, 0.075), mint_light)
    for thorax_rib in range(4):
        var rib_z := -0.045 + float(thorax_rib) * 0.074
        _segment(thorax_pivot, Vector3(-0.042, -0.012, rib_z), Vector3(0.042, -0.012, rib_z), 0.0022, mint_shadow)
    _segment(thorax_pivot, Vector3(0, 0.058, 0.15), Vector3(0, 0.058, -0.27), 0.006, mint_light)

    head_pivot = Node3D.new()
    head_pivot.name = "HeadPivot"
    head_pivot.position = Vector3(0, 0.29, -0.64)
    animal.add_child(head_pivot)
    _create_triangular_head_volume(head_pivot, mint, mint_light, mint_shadow)
    _part(head_pivot, Vector3(0, -0.045, -0.087), Vector3(0.084, 0.054, 0.036), mint)
    _part(head_pivot, Vector3(0, -0.078, -0.097), Vector3(0.036, 0.019, 0.025), mint_shadow)
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
        _part(head_pivot, Vector3(side * 0.094, 0.02, -0.024), Vector3(0.052, 0.058, 0.055), eye_color)
        # Compound facets live in the eye atlas so they stay flush with the rounded eye shell.
        _part(head_pivot, Vector3(side * 0.143, 0.045, -0.073), Vector3(0.0065, 0.009, 0.0045), Color(0.55, 0.67, 0.34))
        var feeler := Node3D.new()
        feeler.name = "Antenna_%d" % int(side)
        feeler.position = Vector3(side * 0.045, 0.075, -0.085)
        head_pivot.add_child(feeler)
        var antenna_start := Vector3.ZERO
        for segment_index in range(12):
            var t: float = float(segment_index + 1) / 12.0
            var antenna_end := Vector3(side * (0.018 + 0.105 * t + 0.035 * sin(t * PI)), 0.022 * sin(t * PI * 1.3), -0.78 * t)
            _segment(feeler, antenna_start, antenna_end, 0.0035 * (1.0 - 0.55 * t), mint_shadow)
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
            var upper := _make_gait_bone(joint, 0.011, mint_light)
            var lower := _make_gait_bone(joint, 0.008, mint_shadow)
            leg_pivots.append(joint)
            gait_segments.append([upper, lower])
            var leg_foot := Vector3(side * 0.32, -0.47, leg_z + (0.19 if i == 0 else 0.22))
            gait_feet.append(leg_foot)
            step_targets.append(leg_foot)
            var tarsomeres: Array[MeshInstance3D] = []
            for tarsomere_index in range(5):
                var tarsomere := _make_gait_bone(joint, 0.0045 - float(tarsomere_index) * 0.00038, mint_shadow)
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

func _create_triangular_head_volume(parent: Node3D, base_color: Color, dorsal_color: Color, seam_color: Color) -> void:
    # A broad eye line tapers into the clypeus, matching the triangular mantid
    # head seen from above while preserving a rounded, volumetric profile.
    const AXIAL_STEPS := 32
    const RADIAL_STEPS := 36
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for axial in range(AXIAL_STEPS + 1):
        var t: float = float(axial) / float(AXIAL_STEPS)
        var shape: float = pow(maxf(0.0, sin(PI * t)), 0.58)
        var width: float = 0.010 + shape * (0.096 + 0.014 * sin(PI * t))
        var height: float = 0.009 + shape * (0.063 + 0.005 * sin(PI * t))
        var center_y: float = 0.012 + 0.006 * sin(PI * t)
        var z: float = 0.106 - t * 0.224
        var dt: float = 1.0 / float(AXIAL_STEPS)
        var ta: float = clampf(t - dt, 0.0, 1.0)
        var tb: float = clampf(t + dt, 0.0, 1.0)
        for radial in range(RADIAL_STEPS + 1):
            var angle: float = TAU * float(radial) / float(RADIAL_STEPS)
            var c: float = cos(angle)
            var s: float = sin(angle)
            var point := Vector3(width * c, center_y + height * s, z)
            var shape_a: float = pow(maxf(0.0, sin(PI * ta)), 0.58)
            var shape_b: float = pow(maxf(0.0, sin(PI * tb)), 0.58)
            var width_a: float = 0.010 + shape_a * (0.096 + 0.014 * sin(PI * ta))
            var width_b: float = 0.010 + shape_b * (0.096 + 0.014 * sin(PI * tb))
            var height_a: float = 0.009 + shape_a * (0.063 + 0.005 * sin(PI * ta))
            var height_b: float = 0.009 + shape_b * (0.063 + 0.005 * sin(PI * tb))
            var center_a: float = 0.012 + 0.006 * sin(PI * ta)
            var center_b: float = 0.012 + 0.006 * sin(PI * tb)
            var point_a := Vector3(width_a * c, center_a + height_a * s, 0.106 - ta * 0.224)
            var point_b := Vector3(width_b * c, center_b + height_b * s, 0.106 - tb * 0.224)
            var around := Vector3(-width * s, height * c, 0.0)
            normals.append((point_b - point_a).cross(around).normalized())
            vertices.append(point)
            uv.append(Vector2(float(radial) / float(RADIAL_STEPS), t))
            var dorsal: float = clampf((s + 0.05) * 0.82, 0.0, 1.0)
            var temple_edge: float = pow(maxf(0.0, 1.0 - absf(sin(t * TAU * 2.0))), 12.0)
            colors.append(base_color.lerp(dorsal_color, 0.15 + dorsal * 0.50).lerp(seam_color, temple_edge * 0.06))
    var stride: int = RADIAL_STEPS + 1
    for axial in range(AXIAL_STEPS):
        for radial in range(RADIAL_STEPS):
            var a: int = axial * stride + radial
            var b: int = (axial + 1) * stride + radial
            var c: int = b + 1
            var d: int = a + 1
            indices.append_array(PackedInt32Array([a, b, d, b, c, d]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var shell := MeshInstance3D.new()
    shell.name = "TriangularCompoundEyeHeadShell"
    shell.mesh = mesh
    var material := _material(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if body_texture != null:
        material.albedo_texture = body_texture
        _apply_pbr(material, "mantis_cuticle")
    shell.material_override = material
    parent.add_child(shell)

func _create_prothorax_volume(parent: Node3D, base_color: Color, dorsal_color: Color, seam_color: Color) -> void:
    const AXIAL_STEPS := 40
    const RADIAL_STEPS := 32
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for axial in range(AXIAL_STEPS + 1):
        var t: float = float(axial) / float(AXIAL_STEPS)
        var shape: float = pow(maxf(0.0, sin(PI * t)), 0.62)
        var rx: float = 0.020 + shape * (0.018 + 0.013 * sin(PI * t))
        var ry: float = 0.017 + shape * (0.012 + 0.010 * sin(PI * t))
        var center_y: float = 0.012 + 0.009 * sin(PI * t)
        var z: float = 0.325 - t * 0.635
        var dt: float = 1.0 / float(AXIAL_STEPS)
        var ta: float = clampf(t - dt, 0.0, 1.0)
        var tb: float = clampf(t + dt, 0.0, 1.0)
        for radial in range(RADIAL_STEPS + 1):
            var angle: float = TAU * float(radial) / float(RADIAL_STEPS)
            var c: float = cos(angle)
            var s: float = sin(angle)
            var p := Vector3(rx * c, center_y + ry * s, z)
            var shape_a: float = pow(maxf(0.0, sin(PI * ta)), 0.62)
            var shape_b: float = pow(maxf(0.0, sin(PI * tb)), 0.62)
            var rx_a: float = 0.020 + shape_a * (0.018 + 0.013 * sin(PI * ta))
            var rx_b: float = 0.020 + shape_b * (0.018 + 0.013 * sin(PI * tb))
            var ry_a: float = 0.017 + shape_a * (0.012 + 0.010 * sin(PI * ta))
            var ry_b: float = 0.017 + shape_b * (0.012 + 0.010 * sin(PI * tb))
            var y_a: float = 0.012 + 0.009 * sin(PI * ta)
            var y_b: float = 0.012 + 0.009 * sin(PI * tb)
            var point_a := Vector3(rx_a * c, y_a + ry_a * s, 0.325 - ta * 0.635)
            var point_b := Vector3(rx_b * c, y_b + ry_b * s, 0.325 - tb * 0.635)
            var around := Vector3(-rx * s, ry * c, 0.0)
            normals.append((point_b - point_a).cross(around).normalized())
            vertices.append(p)
            uv.append(Vector2(float(radial) / float(RADIAL_STEPS), t))
            var dorsal: float = clampf((s + 0.05) * 0.82, 0.0, 1.0)
            var band: float = pow(maxf(0.0, 1.0 - absf(sin(t * TAU * 5.0))), 13.0)
            colors.append(base_color.lerp(dorsal_color, 0.16 + dorsal * 0.48).lerp(seam_color, band * 0.10))
    var stride: int = RADIAL_STEPS + 1
    for axial in range(AXIAL_STEPS):
        for radial in range(RADIAL_STEPS):
            var a: int = axial * stride + radial
            var b: int = (axial + 1) * stride + radial
            var c: int = b + 1
            var d: int = a + 1
            indices.append_array(PackedInt32Array([a, b, d, b, c, d]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var shell := MeshInstance3D.new()
    shell.name = "LongProthoraxShell"
    shell.mesh = mesh
    var material := _material(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if body_texture != null:
        material.albedo_texture = body_texture
        _apply_pbr(material, "mantis_cuticle")
    shell.material_override = material
    parent.add_child(shell)

func _create_abdomen_volume(parent: Node3D, base_color: Color, dorsal_color: Color, seam_color: Color) -> void:
    const AXIAL_STEPS := 64
    const RADIAL_STEPS := 48
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for axial in range(AXIAL_STEPS + 1):
        var t: float = float(axial) / float(AXIAL_STEPS)
        var profile: float = pow(maxf(0.0, sin(PI * pow(t, 0.78))), 0.72)
        var rx: float = 0.010 + profile * (0.115 + 0.040 * sin(PI * t))
        var ry: float = 0.010 + profile * (0.074 + 0.030 * sin(PI * t))
        var center_y: float = 0.164 + 0.018 * sin(PI * t) - 0.012 * t
        var z: float = -0.175 + t * 0.805
        var dt: float = 1.0 / float(AXIAL_STEPS)
        var ta: float = clampf(t - dt, 0.0, 1.0)
        var tb: float = clampf(t + dt, 0.0, 1.0)
        for radial in range(RADIAL_STEPS + 1):
            var angle: float = TAU * float(radial) / float(RADIAL_STEPS)
            var c: float = cos(angle)
            var s: float = sin(angle)
            var p := Vector3(rx * c, center_y + ry * s, z)
            var profile_a: float = pow(maxf(0.0, sin(PI * pow(ta, 0.78))), 0.72)
            var profile_b: float = pow(maxf(0.0, sin(PI * pow(tb, 0.78))), 0.72)
            var rx_a: float = 0.010 + profile_a * (0.115 + 0.040 * sin(PI * ta))
            var rx_b: float = 0.010 + profile_b * (0.115 + 0.040 * sin(PI * tb))
            var ry_a: float = 0.010 + profile_a * (0.074 + 0.030 * sin(PI * ta))
            var ry_b: float = 0.010 + profile_b * (0.074 + 0.030 * sin(PI * tb))
            var center_a: float = 0.164 + 0.018 * sin(PI * ta) - 0.012 * ta
            var center_b: float = 0.164 + 0.018 * sin(PI * tb) - 0.012 * tb
            var point_a := Vector3(rx_a * c, center_a + ry_a * s, -0.175 + ta * 0.805)
            var point_b := Vector3(rx_b * c, center_b + ry_b * s, -0.175 + tb * 0.805)
            var around := Vector3(-rx * s, ry * c, 0.0)
            normals.append(around.cross(point_b - point_a).normalized())
            vertices.append(p)
            uv.append(Vector2(float(radial) / float(RADIAL_STEPS), t))
            var ventral: float = clampf((-s + 0.16) * 0.79, 0.0, 1.0)
            var band_edge: float = pow(maxf(0.0, 1.0 - absf(sin(t * TAU * 9.0))), 15.0)
            var pigment: Color = base_color.lerp(dorsal_color, 0.12 + (1.0 - ventral) * 0.28)
            pigment = pigment.lerp(dorsal_color.lightened(0.12), (1.0 - ventral) * 0.10)
            pigment = pigment.lerp(seam_color, band_edge * 0.17 + ventral * 0.10)
            var mottling: float = sin(t * 47.0 + angle * 5.0) * 0.025 + sin(t * 83.0 - angle * 11.0) * 0.012
            colors.append(Color(clampf(pigment.r + mottling, 0.0, 1.0), clampf(pigment.g + mottling, 0.0, 1.0), clampf(pigment.b + mottling * 0.55, 0.0, 1.0), 1.0))
    var stride: int = RADIAL_STEPS + 1
    for axial in range(AXIAL_STEPS):
        for radial in range(RADIAL_STEPS):
            var a: int = axial * stride + radial
            var b: int = (axial + 1) * stride + radial
            var c: int = b + 1
            var d: int = a + 1
            indices.append_array(PackedInt32Array([a, d, b, d, c, b]))
    var first_cap: int = vertices.size()
    vertices.append(Vector3(0.0, 0.164, -0.175))
    normals.append(Vector3(0.0, 0.0, -1.0))
    uv.append(Vector2(0.5, 0.0))
    colors.append(dorsal_color)
    var last_cap: int = vertices.size()
    vertices.append(Vector3(0.0, 0.152, 0.630))
    normals.append(Vector3(0.0, 0.0, 1.0))
    uv.append(Vector2(0.5, 1.0))
    colors.append(base_color)
    for radial in range(RADIAL_STEPS):
        indices.append_array(PackedInt32Array([first_cap, radial + 1, radial]))
        var last_ring: int = AXIAL_STEPS * stride
        indices.append_array(PackedInt32Array([last_cap, last_ring + radial, last_ring + radial + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var item := MeshInstance3D.new()
    item.name = "VolumetricSegmentedAbdomen"
    item.mesh = mesh
    var material := _material(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    if body_texture != null:
        material.albedo_texture = body_texture
        _apply_pbr(material, "mantis_cuticle")
    item.material_override = material
    parent.add_child(item)

func _create_mantis_wing(parent: Node3D, side: float, hindwing: bool) -> void:
    var segments := 48
    var start_z: float = -0.015 if hindwing else -0.13
    var end_z: float = 0.57 if hindwing else 0.69
    var y: float = 0.245 if hindwing else 0.272
    var max_width: float = 0.34 if hindwing else 0.155
    var hinge := Vector3(side * 0.035, y, start_z)
    var wing_mesh := _make_volumetric_wing_mesh(segments, 18, side, end_z - start_z, max_width, hindwing)
    var wing_pivot := Node3D.new()
    wing_pivot.name = ("HindwingPivot" if hindwing else "ForewingPivot") + ("_L" if side < 0.0 else "_R")
    wing_pivot.position = hinge
    wing_pivot.set_meta("wing_side", side)
    wing_pivot.set_meta("hindwing", hindwing)
    if hindwing:
        # The broad membrane stays folded beneath the tegmina while resting.
        wing_pivot.scale.x = 0.36
    parent.add_child(wing_pivot)
    var wing_instance := MeshInstance3D.new()
    wing_instance.name = "WingMembrane"
    wing_instance.mesh = wing_mesh
    var wing_color: Color = Color(0.88, 0.94, 0.78, 0.58) if hindwing else Color(0.67, 0.82, 0.53)
    var wing_material := _material(wing_color)
    if wing_texture != null:
        wing_material.albedo_texture = wing_texture
        wing_material.vertex_color_use_as_albedo = true
        _apply_pbr(wing_material, "mantis_wing")
    elif body_texture != null:
        wing_material.albedo_texture = body_texture
        wing_material.vertex_color_use_as_albedo = true
        _apply_pbr(wing_material, "mantis_cuticle")
    wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if hindwing:
        wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        wing_material.roughness = 0.38
    else:
        wing_material.roughness = 0.56
    wing_instance.material_override = wing_material
    wing_pivot.add_child(wing_instance)
    var vein_color: Color = Color(0.43, 0.57, 0.29) if hindwing else Color(0.39, 0.54, 0.25)
    var vein_points := PackedVector3Array()
    var vein_radii := PackedFloat32Array()
    vein_points.append_array(PackedVector3Array([Vector3(0, 0.020, 0.018), Vector3(side * 0.018, 0.021, end_z - start_z - 0.012)]))
    vein_radii.append(0.0028)
    for vein_index in range(25):
        var t: float = 0.045 + float(vein_index) * 0.038
        var z: float = (end_z - start_z) * t
        var width: float = _mantis_wing_profile(t, hindwing) * max_width
        var origin := Vector3(side * width * 0.035, 0.018 + 0.016 * sin(PI * t), z * 0.18)
        var tip := Vector3(side * width * (0.88 if hindwing else 0.91), 0.014 + 0.015 * sin(PI * t), z)
        vein_points.append_array(PackedVector3Array([origin, tip]))
        vein_radii.append(0.00145 if hindwing else 0.0019)
    # Repeated cross-veins and a fine perimeter give the flight membrane a
    # fan of cells while the forewing keeps its long, leathery leaf outline.
    for cross_index in range(17 if hindwing else 15):
        var t: float = 0.08 + float(cross_index) * (0.052 if hindwing else 0.057)
        var z: float = (end_z - start_z) * t
        var width: float = _mantis_wing_profile(t, hindwing) * max_width
        var cross_start := Vector3(side * width * 0.24, 0.018, z - 0.018)
        var cross_end := Vector3(side * width * 0.80, 0.018, z + 0.026)
        vein_points.append_array(PackedVector3Array([cross_start, cross_end]))
        vein_radii.append(0.00105)
        var next_t: float = minf(1.0, t + 0.04)
        var next_width: float = _mantis_wing_profile(next_t, hindwing) * max_width
        var edge_start := Vector3(side * width, 0.012, z)
        var edge_end := Vector3(side * next_width, 0.012, minf(end_z - start_z, z + (end_z - start_z) * 0.04))
        vein_points.append_array(PackedVector3Array([edge_start, edge_end]))
        vein_radii.append(0.0015)
    if not hindwing:
        # A subtle, elongated stigma sits on each leathery mint forewing.
        _part(wing_pivot, Vector3(side * 0.102, 0.021, 0.12), Vector3(0.010, 0.003, 0.032), Color(0.78, 0.84, 0.48))
    _create_wing_veins(wing_pivot, vein_points, vein_radii, vein_color)
    wing_pivots.append(wing_pivot)

func _create_wing_veins(parent: Node3D, points: PackedVector3Array, radii: PackedFloat32Array, tint: Color) -> void:
    const RADIAL_STEPS := 6
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for tube in range(radii.size()):
        var a: Vector3 = points[tube * 2]
        var b: Vector3 = points[tube * 2 + 1]
        var axis: Vector3 = (b - a).normalized()
        var tangent: Vector3 = axis.cross(Vector3.UP)
        if tangent.length_squared() < 0.0001:
            tangent = axis.cross(Vector3.RIGHT)
        tangent = tangent.normalized()
        var bitangent: Vector3 = axis.cross(tangent).normalized()
        var start_index: int = vertices.size()
        for end_index in range(2):
            var center: Vector3 = a if end_index == 0 else b
            var radius_scale: float = 1.12 if end_index == 0 else 0.82
            for radial in range(RADIAL_STEPS):
                var angle: float = TAU * float(radial) / float(RADIAL_STEPS)
                var normal: Vector3 = (tangent * cos(angle) + bitangent * sin(angle)).normalized()
                vertices.append(center + normal * radii[tube] * radius_scale)
                normals.append(normal)
                uvs.append(Vector2(float(radial) / float(RADIAL_STEPS), float(end_index)))
        for radial in range(RADIAL_STEPS):
            var next: int = (radial + 1) % RADIAL_STEPS
            var a0: int = start_index + radial
            var a1: int = start_index + next
            var b0: int = start_index + RADIAL_STEPS + radial
            var b1: int = start_index + RADIAL_STEPS + next
            indices.append_array(PackedInt32Array([a0, a1, b0, a1, b1, b0]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var detail := MeshInstance3D.new()
    detail.name = "RaisedWingVeins"
    detail.mesh = mesh
    detail.material_override = _material(tint)
    parent.add_child(detail)

func _make_volumetric_wing_mesh(longitudinal_steps: int, chord_steps: int, side: float, length: float, max_width: float, hindwing: bool) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    var row_width: int = chord_steps + 1
    var surface_size: int = (longitudinal_steps + 1) * row_width
    for surface in range(2):
        var underside: bool = surface == 1
        var vertex_offset: int = surface * surface_size
        for i in range(longitudinal_steps + 1):
            var t: float = float(i) / float(longitudinal_steps)
            var t0: float = maxf(0.0, t - 1.0 / float(longitudinal_steps))
            var t1: float = minf(1.0, t + 1.0 / float(longitudinal_steps))
            for j in range(chord_steps + 1):
                var u: float = float(j) / float(chord_steps)
                var p := _volumetric_wing_point(t, u, side, length, max_width, hindwing, underside)
                var along := _volumetric_wing_point(t1, u, side, length, max_width, hindwing) - _volumetric_wing_point(t0, u, side, length, max_width, hindwing)
                var u0: float = maxf(0.0, u - 0.02)
                var u1: float = minf(1.0, u + 0.02)
                var across := _volumetric_wing_point(t, u1, side, length, max_width, hindwing) - _volumetric_wing_point(t, u0, side, length, max_width, hindwing)
                var normal := along.cross(across).normalized() * side
                if underside:
                    normal = -normal
                vertices.append(p)
                normals.append(normal)
                uvs.append(Vector2(u, t))
                var edge_glow: float = 0.94 + 0.06 * (1.0 - absf(2.0 * u - 1.0))
                var vein_tone: float = 1.0 + 0.025 * cos(t * TAU * 24.0) * sin(u * PI)
                colors.append(Color(edge_glow * vein_tone, edge_glow * vein_tone, edge_glow * (0.98 + (1.0 - u) * 0.025), 1.0))
        for i in range(longitudinal_steps):
            for j in range(chord_steps):
                var a: int = vertex_offset + i * row_width + j
                var b: int = a + row_width
                var c: int = b + 1
                var d: int = a + 1
                if underside:
                    indices.append_array(PackedInt32Array([a, b, d, b, c, d]))
                else:
                    indices.append_array(PackedInt32Array([a, d, b, d, c, b]))
    # Seal the rounded outer edge and the tapered tip so the wing keeps visible
    # thickness when seen edge-on or from underneath.
    for i in range(longitudinal_steps):
        var top_a: int = i * row_width + chord_steps
        var top_b: int = top_a + row_width
        var bottom_a: int = surface_size + top_a
        var bottom_b: int = surface_size + top_b
        indices.append_array(PackedInt32Array([top_a, bottom_a, top_b, bottom_a, bottom_b, top_b]))
        var inner_top_a: int = i * row_width
        var inner_top_b: int = inner_top_a + row_width
        var inner_bottom_a: int = surface_size + inner_top_a
        var inner_bottom_b: int = surface_size + inner_top_b
        indices.append_array(PackedInt32Array([inner_top_a, inner_top_b, inner_bottom_a, inner_top_b, inner_bottom_b, inner_bottom_a]))
    for j in range(chord_steps):
        var root_top: int = j
        var root_next: int = j + 1
        var root_bottom: int = surface_size + j
        indices.append_array(PackedInt32Array([root_top, root_next, root_bottom, root_next, surface_size + j + 1, root_bottom]))
        var tip_row: int = longitudinal_steps * row_width + j
        var tip_next: int = tip_row + 1
        var tip_bottom: int = surface_size + tip_row
        indices.append_array(PackedInt32Array([tip_row, tip_bottom, tip_next, tip_next, tip_bottom, surface_size + tip_row + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _volumetric_wing_point(t: float, u: float, side: float, length: float, max_width: float, hindwing: bool, underside: bool = false) -> Vector3:
    var profile: float = _mantis_wing_profile(t, hindwing)
    var width: float = 0.004 + profile * max_width
    var edge_ripple: float = 0.0035 * sin(t * PI * (18.0 if hindwing else 14.0)) * sin(PI * t)
    var cupped_surface: float = (0.021 if hindwing else 0.029) * sin(PI * t) * sin(PI * u)
    var camber: float = 0.013 * sin(PI * t) + cupped_surface + edge_ripple * u
    var thickness: float = (0.010 if hindwing else 0.014) * sin(PI * t) * (0.42 + 0.58 * sin(PI * u))
    return Vector3(side * (width * u + edge_ripple * u * u), camber - (thickness if underside else 0.0), length * t)

func _mantis_wing_profile(t: float, hindwing: bool) -> float:
    var safe_t: float = clampf(t, 0.0, 1.0)
    if hindwing:
        # Broad distal fan with a rounded, slightly scalloped trailing edge.
        var flare: float = 0.12 + 0.88 * sin(safe_t * PI * 0.5)
        var taper: float = pow(maxf(0.0, 1.0 - safe_t), 0.30)
        return flare * taper
    return pow(maxf(0.0, sin(PI * safe_t)), 0.72)

func _ellipsoid_limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
    var delta := b - a
    var length: float = delta.length()
    if length < 0.0001:
        return
    var item := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radial_segments = 28
    mesh.rings = 16
    item.mesh = mesh
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.BACK, delta.normalized())
    item.scale = Vector3(radius, radius, length * 0.64)
    item.material_override = _cuticle_material(tint)
    parent.add_child(item)

# The cuticle albedo is a neutral, tileable microtexture; tinting keeps the
# individual pale-green body plates and warm joints visible.

func _apply_pbr(mat: StandardMaterial3D, kind: String) -> void:
    if pbr_normal.has(kind):
        mat.normal_enabled = true
        mat.normal_texture = pbr_normal[kind]
        mat.normal_scale = 0.28 if kind == "mantis_eye" else (0.16 if kind == "mantis_wing" else 0.30)
    if pbr_roughness.has(kind):
        mat.roughness_texture = pbr_roughness[kind]
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if kind == "mantis_eye":
        mat.metallic = 0.02
        mat.roughness = 0.25
    elif kind == "mantis_wing":
        mat.metallic = 0.0
        mat.roughness = 0.70
    elif kind == "mantis_cuticle":
        mat.metallic = 0.04
        mat.roughness = 0.54

func _cuticle_material(color: Color) -> StandardMaterial3D:
    var mat := _material(color)
    if body_texture != null and color.g > color.r * 1.15:
        mat.albedo_texture = body_texture
        mat.albedo_color = color
        _apply_pbr(mat, "mantis_cuticle")
    return mat

func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radial_segments = 32
    mesh.rings = 20
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
        # The near-neutral texture adds fine cuticle grain while this tint preserves
        # the natural light-green, olive, and shadow colors selected per body part.
        mat.albedo_texture = body_texture
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
        mat = _cuticle_material(color)
    item.material_override = mat
    parent.add_child(item)

func _branch(a: Vector3, b: Vector3, radius: float) -> void:
    _segment(self, a, b, radius, Color(0.32, 0.21, 0.12))

func _tapered_branch(a: Vector3, b: Vector3, base_radius: float, tip_radius: float) -> void:
    var item := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = maxf(0.004, tip_radius)
    mesh.bottom_radius = maxf(0.006, base_radius)
    mesh.height = a.distance_to(b)
    mesh.radial_segments = 18
    item.mesh = mesh
    item.position = (a + b) * 0.5
    item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    var mat := _material(Color(0.34, 0.22, 0.13))
    if bark_texture != null:
        mat.albedo_texture = bark_texture
        _apply_pbr(mat, "bark")
    item.material_override = mat
    add_child(item)

func _box(size: Vector3, pos: Vector3, color: Color, transparent := false) -> MeshInstance3D:
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
    add_child(item)
    return item

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
    model_status_label = Label.new()
    model_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    model_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if rigged_available:
        model_status_label.text = "모델 잠금: %s · %d본 · %d개 애니메이션" % [LATEST_MODEL_LOCK.get_file(), rigged_skeleton.get_bone_count(), rigged_clips.size()]
        model_status_label.add_theme_color_override("font_color", Color(0.65, 0.92, 0.68))
    else:
        model_status_label.text = "최신 사마귀 모델을 검증하지 못했습니다. 구형 모델은 표시하지 않습니다. " + str(rigged_import_warnings)
        model_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
    column.add_child(model_status_label)
    species_picker = _add_profile_option(column, "사마귀 종류", SPECIES_NAMES, selected_species, _on_species_selected)
    stage_picker = _add_profile_option(column, "성장 단계", LIFE_STAGES, life_stage, _on_stage_selected)
    biome_picker = _add_profile_option(column, "사육장 환경", BIOME_NAMES, selected_biome, _on_biome_selected)
    prey_picker = _add_profile_option(column, "먹이 곤충", PREY_TYPES, selected_prey_type, _on_prey_selected)
    save_slot_picker = OptionButton.new()
    save_slot_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for slot_number in range(1, SAVE_SLOT_COUNT + 1):
        save_slot_picker.add_item("사육장 저장 %02d" % slot_number)
    save_slot_picker.select(active_save_slot - 1)
    save_slot_picker.item_selected.connect(_on_save_slot_selected)
    column.add_child(save_slot_picker)
    mantis_name_edit = LineEdit.new()
    mantis_name_edit.placeholder_text = "사마귀 이름"
    mantis_name_edit.text = mantis_name
    mantis_name_edit.text_changed.connect(func(value: String): mantis_name = value)
    column.add_child(mantis_name_edit)
    _button(column, "새 사육장 개체 만들기", func(): _create_new_slot_profile())
    _button(column, "이 사육장 저장", func(): _save_state())
    _button(column, "선택한 사육장 불러오기", func(): _load_state(true))
    var command_title := Label.new()
    command_title.text = "직접 명령"
    command_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(command_title)
    _button(column, "날아다니기", func(): _command_mantis("FLY"))
    _button(column, "사냥하기", func(): _command_mantis("HUNT"))
    _button(column, "점프하기", func(): _command_mantis("JUMP"))
    _button(column, "잎 뒷면에 거꾸로 매달리기", func(): _command_mantis("HANG"))
    _button(column, "탈피하기", func(): _command_mantis("MOLT"))
    _button(column, "위협 자세", func(): _command_mantis("THREATEN"))
    _button(column, "다른 개체와 싸움 시연", func(): _command_mantis("FIGHT"))
    _button(column, "짝짓기 행동 시연", func(): _command_mantis("MATE"))
    _button(column, "나무 줄기 타기", func(): _command_mantis("CLIMB"))
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
            clip_label = "자세 시연: 나무 줄기 타기"
        _button(column, clip_label, func(): _set_animation_preview(selected_clip))
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
    edit_hint = Label.new()
    edit_hint.text = "관찰 모드"
    edit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(edit_hint)
    notice = Label.new()
    notice.text = "방향키/WASD: 자유 이동 · Shift: 빠르게 · 드래그: 회전 · +/-: 확대"
    notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(notice)

    var zoom_controls := VBoxContainer.new()
    zoom_controls.anchor_left = 1.0
    zoom_controls.anchor_top = 0.5
    zoom_controls.anchor_right = 1.0
    zoom_controls.anchor_bottom = 0.5
    zoom_controls.offset_left = -84.0
    zoom_controls.offset_top = -102.0
    zoom_controls.offset_right = -14.0
    zoom_controls.offset_bottom = 102.0
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
    zoom_reset.pressed.connect(func(): orbit_distance = 9.4; orbit_pitch = 0.25; camera_pan = Vector3.ZERO; _update_camera())
    zoom_controls.add_child(zoom_reset)
    _create_camera_pad()

func _add_profile_option(column: VBoxContainer, title_text: String, values: Array[String], selected_value: String, handler: Callable) -> OptionButton:
    var title := Label.new()
    title.text = title_text
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(title)
    var option := OptionButton.new()
    option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for value in values:
        option.add_item(value)
    var selected_index := values.find(selected_value)
    option.select(maxi(0, selected_index))
    option.item_selected.connect(handler)
    column.add_child(option)
    return option

func _create_camera_pad() -> void:
    var pad := GridContainer.new()
    pad.name = "CameraDirectionPad"
    pad.columns = 3
    pad.anchor_left = 1.0
    pad.anchor_top = 1.0
    pad.anchor_right = 1.0
    pad.anchor_bottom = 1.0
    pad.offset_left = -182.0
    pad.offset_top = -176.0
    pad.offset_right = -16.0
    pad.offset_bottom = -12.0
    pad.add_theme_constant_override("h_separation", 4)
    pad.add_theme_constant_override("v_separation", 4)
    root_ui.add_child(pad)
    for key in ["", "up", "", "left", "center", "right", "", "down", ""]:
        var direction_key: String = key
        var button := Button.new()
        button.text = "↑" if direction_key == "up" else "↓" if direction_key == "down" else "←" if direction_key == "left" else "→" if direction_key == "right" else "•" if direction_key == "center" else ""
        button.custom_minimum_size = Vector2(50.0, 48.0)
        button.disabled = direction_key == "" or direction_key == "center"
        if not button.disabled:
            button.button_down.connect(func(): camera_touch_directions[direction_key] = true)
            button.button_up.connect(func(): camera_touch_directions.erase(direction_key))
        pad.add_child(button)

func _on_species_selected(index: int) -> void:
    if index < 0 or index >= SPECIES_NAMES.size():
        return
    selected_species = SPECIES_NAMES[index]
    _apply_species_appearance()
    _refresh()

func _on_stage_selected(index: int) -> void:
    if index < 0 or index >= LIFE_STAGES.size():
        return
    if molting:
        if stage_picker != null:
            stage_picker.select(_life_stage_index())
        notice.text = "탈피가 끝나면 성장 단계를 바꿀 수 있습니다."
        return
    life_stage = LIFE_STAGES[index]
    molt_count = mini(index, 6)
    _apply_life_stage()
    _refresh()

func _on_biome_selected(index: int) -> void:
    if index < 0 or index >= BIOME_NAMES.size():
        return
    selected_biome = BIOME_NAMES[index]
    match selected_biome:
        "열대 우림":
            temperature = 25.0
            humidity = 72.0
        "건조 초원":
            temperature = 27.0
            humidity = 48.0
        "사막":
            temperature = 29.0
            humidity = 34.0
        _:
            temperature = 22.0
            humidity = 62.0
    _apply_biome_profile()
    _refresh()

func _on_prey_selected(index: int) -> void:
    if index >= 0 and index < PREY_TYPES.size():
        selected_prey_type = PREY_TYPES[index]

func _on_save_slot_selected(index: int) -> void:
    _switch_save_slot(index + 1)

func _sync_profile_selectors() -> void:
    if species_picker != null:
        species_picker.select(maxi(0, SPECIES_NAMES.find(selected_species)))
    if stage_picker != null:
        stage_picker.select(maxi(0, LIFE_STAGES.find(life_stage)))
    if biome_picker != null:
        biome_picker.select(maxi(0, BIOME_NAMES.find(selected_biome)))
    if prey_picker != null:
        prey_picker.select(maxi(0, PREY_TYPES.find(selected_prey_type)))
    if save_slot_picker != null:
        save_slot_picker.select(active_save_slot - 1)
    if mantis_name_edit != null:
        mantis_name_edit.text = mantis_name

func _species_tint() -> Color:
    match selected_species:
        "치앙마이형 (Hierodula sp.)":
            return Color(0.67, 0.88, 0.70)
        "중국사마귀":
            return Color(0.83, 0.89, 0.68)
        "유럽사마귀":
            return Color(0.82, 0.79, 0.56)
        "고스트사마귀":
            return Color(0.77, 0.70, 0.54)
        "꽃사마귀":
            return Color(0.94, 0.72, 0.73)
        _:
            return Color(0.78, 0.92, 0.68)

func _species_size_factor() -> float:
    match selected_species:
        "치앙마이형 (Hierodula sp.)":
            return 1.12
        "왕사마귀":
            return 1.12
        "중국사마귀":
            return 1.06
        "유럽사마귀":
            return 0.93
        "고스트사마귀":
            return 0.82
        "꽃사마귀":
            return 0.92
        _:
            return 1.0

func _apply_species_appearance() -> void:
    if rigged_visual != null and rigged_available:
        _style_rigged_materials(rigged_visual)
    if juvenile_wing_buds != null:
        for child in juvenile_wing_buds.get_children():
            var bud := child as MeshInstance3D
            if bud != null:
                var bud_material := bud.material_override as StandardMaterial3D
                if bud_material != null:
                    bud_material.albedo_color = _species_tint().lightened(0.14)
    _apply_life_stage()

func _is_juvenile() -> bool:
    return life_stage != "성체"

func _life_stage_index() -> int:
    var stage_index := LIFE_STAGES.find(life_stage)
    return clampi(stage_index, 0, LIFE_STAGES.size() - 1)

func _apply_life_stage() -> void:
    var stage_index := _life_stage_index()
    var is_juvenile := stage_index < 6
    if animal != null:
        var growth_scale := 0.42 * (0.90 + growth * 0.30)
        if is_juvenile:
            growth_scale *= NYMPH_SIZE_FACTORS[stage_index]
        animal.scale = Vector3.ONE * growth_scale * _species_size_factor()
    if rigged_visual != null:
        var wing_parts: Array = rigged_visual.find_children("*", "MeshInstance3D", true, false)
        for candidate in wing_parts:
            var part := candidate as MeshInstance3D
            if part == null:
                continue
            if part.name.begins_with("Wing_") or part.name.begins_with("Hindwing_") or part.name.begins_with("WingVeinDetail_"):
                part.visible = not is_juvenile
    if juvenile_wing_buds != null:
        juvenile_wing_buds.visible = is_juvenile
        if is_juvenile:
            var pad_factor := NYMPH_WING_PAD_FACTORS[stage_index]
            for child in juvenile_wing_buds.get_children():
                var bud := child as MeshInstance3D
                if bud != null:
                    bud.scale = Vector3(0.12 + 0.14 * pad_factor, 0.045 + 0.035 * pad_factor, 0.19 + 0.18 * pad_factor)
                    bud.position.z = 0.10 + 0.035 * pad_factor

func _apply_biome_profile() -> void:
    var sky := Color(0.065, 0.085, 0.08)
    var ambient := Color(0.70, 0.80, 0.72)
    var floor_tint := Color(0.70, 0.77, 0.58)
    var foliage_tint := Color(0.46, 0.78, 0.38)
    var light_energy := 1.48
    match selected_biome:
        "건조 초원":
            sky = Color(0.16, 0.13, 0.085)
            ambient = Color(0.84, 0.73, 0.50)
            floor_tint = Color(0.88, 0.73, 0.45)
            foliage_tint = Color(0.78, 0.68, 0.34)
            light_energy = 1.72
        "사막":
            sky = Color(0.20, 0.15, 0.10)
            ambient = Color(0.93, 0.76, 0.52)
            floor_tint = Color(0.93, 0.79, 0.56)
            foliage_tint = Color(0.70, 0.65, 0.36)
            light_energy = 1.92
        "온대림":
            sky = Color(0.075, 0.095, 0.12)
            ambient = Color(0.69, 0.77, 0.80)
            floor_tint = Color(0.63, 0.70, 0.48)
            foliage_tint = Color(0.62, 0.74, 0.43)
            light_energy = 1.30
    if world_environment != null:
        world_environment.background_color = sky
        world_environment.ambient_light_color = ambient
    if directional_light != null:
        directional_light.light_energy = light_energy
        directional_light.light_color = ambient
    if habitat_floor != null and habitat_floor.material_override is StandardMaterial3D:
        var floor_material := habitat_floor.material_override as StandardMaterial3D
        floor_material.albedo_color = floor_tint
    if habitat_motion_root != null:
        var plant_index := 0
        for child in habitat_motion_root.get_children():
            if child.name.begins_with("Plant_"):
                var plant := child as Node3D
                plant.visible = selected_biome != "사막" or plant_index % 7 == 0
                if selected_biome == "건조 초원":
                    plant.visible = plant_index % 3 != 0
                plant_index += 1
            elif child.name.begins_with("CanopyVine_"):
                child.visible = selected_biome in ["열대 우림", "온대림"]
        var foliage_parts: Array = habitat_motion_root.find_children("*", "MeshInstance3D", true, false)
        for candidate in foliage_parts:
            var part := candidate as MeshInstance3D
            if part == null or not (part.material_override is StandardMaterial3D):
                continue
            var material := part.material_override as StandardMaterial3D
            var material_id := material.get_instance_id()
            if not biome_base_colors.has(material_id):
                biome_base_colors[material_id] = material.albedo_color
            var base: Color = biome_base_colors[material_id]
            material.albedo_color = base.lerp(foliage_tint, 0.38)
    _rebuild_biome_accents()

func _rebuild_biome_accents() -> void:
    if biome_accent_root == null:
        biome_accent_root = Node3D.new()
        biome_accent_root.name = "BiomeAccents"
        add_child(biome_accent_root)
    for child in biome_accent_root.get_children():
        biome_accent_root.remove_child(child)
        child.queue_free()
    if selected_biome == "열대 우림":
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 31600 + BIOME_NAMES.find(selected_biome) * 31
    if selected_biome == "사막":
        var cactus_color := Color(0.43, 0.50, 0.34)
        for i in range(10):
            var cactus_x := rng.randf_range(-4.8, 4.8)
            var cactus_z := rng.randf_range(-3.6, 3.6)
            var cactus_height := rng.randf_range(0.58, 1.30)
            var cactus_base := Vector3(cactus_x, -0.49, cactus_z)
            var cactus_top := cactus_base + Vector3(0.0, cactus_height, 0.0)
            _segment(biome_accent_root, cactus_base, cactus_top, rng.randf_range(0.045, 0.080), cactus_color)
            if i % 2 == 0:
                var arm_y := rng.randf_range(0.34, 0.62) * cactus_height
                var arm_side := -1.0 if i % 4 == 0 else 1.0
                var elbow := cactus_base + Vector3(0.0, arm_y, 0.0)
                var arm_mid := elbow + Vector3(arm_side * 0.18, 0.0, 0.0)
                var arm_tip := arm_mid + Vector3(0.0, 0.30, 0.0)
                _segment(biome_accent_root, elbow, arm_mid, 0.032, cactus_color)
                _segment(biome_accent_root, arm_mid, arm_tip, 0.032, cactus_color)
    elif selected_biome == "건조 초원":
        for i in range(48):
            var grass_x := rng.randf_range(-5.0, 5.0)
            var grass_z := rng.randf_range(-3.8, 3.8)
            var grass_start := Vector3(grass_x, -0.50, grass_z)
            var grass_height := rng.randf_range(0.22, 0.72)
            var grass_drift := Vector3(rng.randf_range(-0.14, 0.14), grass_height, rng.randf_range(-0.12, 0.12))
            var tint := Color(0.55, 0.52, 0.30).lerp(Color(0.71, 0.61, 0.34), rng.randf())
            _segment(biome_accent_root, grass_start, grass_start + grass_drift, rng.randf_range(0.006, 0.012), tint)
    else:
        var litter := _leaf_mesh()
        var litter_tints: Array[Color] = [Color(0.52, 0.31, 0.13), Color(0.62, 0.43, 0.18), Color(0.38, 0.42, 0.19), Color(0.55, 0.28, 0.20)]
        for i in range(72):
            var item := MeshInstance3D.new()
            item.name = "TemperateLeaf_%02d" % i
            item.mesh = litter
            item.position = Vector3(rng.randf_range(-5.0, 5.0), -0.535, rng.randf_range(-3.8, 3.8))
            item.rotation.y = rng.randf_range(-PI, PI)
            item.scale = Vector3(rng.randf_range(0.30, 0.62), 0.16, rng.randf_range(0.52, 0.96))
            var material := _material(litter_tints[rng.randi_range(0, litter_tints.size() - 1)])
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            material.vertex_color_use_as_albedo = true
            item.material_override = material
            biome_accent_root.add_child(item)

func _slot_path(slot_number: int) -> String:
    return "user://mantis_terrarium_%02d_v1.json" % clampi(slot_number, 1, SAVE_SLOT_COUNT)

func _slot_backup_path(slot_number: int) -> String:
    return "user://mantis_terrarium_%02d_v1_backup.json" % clampi(slot_number, 1, SAVE_SLOT_COUNT)

func _read_active_save_slot() -> int:
    if not FileAccess.file_exists(ACTIVE_SLOT_PATH):
        return 1
    return clampi(int(FileAccess.get_file_as_string(ACTIVE_SLOT_PATH).strip_edges()), 1, SAVE_SLOT_COUNT)

func _write_active_save_slot() -> void:
    var file := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(str(active_save_slot))
        file.close()

func _switch_save_slot(slot_number: int) -> void:
    var next_slot := clampi(slot_number, 1, SAVE_SLOT_COUNT)
    if next_slot == active_save_slot:
        return
    _save_state(false)
    active_save_slot = next_slot
    _write_active_save_slot()
    _reset_profile_state()
    _load_state(false)
    _sync_prey()
    _apply_biome_profile()
    _apply_species_appearance()
    _apply_life_stage()
    _sync_profile_selectors()
    if notice != null:
        notice.text = "사육장 저장 %02d 불러옴" % active_save_slot
    _refresh()

func _create_new_slot_profile() -> void:
    _reset_profile_state()
    life_stage = LIFE_STAGES[0]
    molt_count = 0
    selected_species = "치앙마이형 (Hierodula sp.)"
    selected_biome = "열대 우림"
    selected_prey_type = "귀뚜라미"
    mantis_name = "사마귀 %02d" % active_save_slot
    _apply_biome_profile()
    _apply_species_appearance()
    _apply_life_stage()
    _sync_profile_selectors()
    _save_state(false)
    if notice != null:
        notice.text = "저장 %02d에 새 약충 개체를 만들었습니다." % active_save_slot
    _refresh()

func _reset_profile_state() -> void:
    _clear_decorations()
    for prey in prey_nodes:
        if is_instance_valid(prey):
            if habitat_interactions != null:
                habitat_interactions.unregister_prey(prey)
            prey.queue_free()
    prey_nodes.clear()
    prey_kinds.clear()
    prey_velocities.clear()
    prey_pause_timers.clear()
    prey_appendages.clear()
    food_count = 0
    hunger = 32.0
    energy = 86.0
    stress = 12.0
    humidity = 72.0
    temperature = 25.0
    life_age = 0.0
    molt_count = 0
    growth = 0.35
    molting = false
    molt_progress = 0.0
    preview_strike_clock = 0.0
    life_stage = "성체"
    selected_species = "치앙마이형 (Hierodula sp.)"
    selected_biome = "열대 우림"
    selected_prey_type = "귀뚜라미"
    mantis_name = "초록이"
    animation_preview = "AUTO"
    climb_active = false
    climb_progress = 0.0
    climb_cooldown = 0.0
    climb_pause = 0.0
    roam_speed = 0.0
    roam_target_valid = false
    target_prey = null
    behavior = "휴식"
    command_elapsed = 0.0
    if feed_demo_prey != null and is_instance_valid(feed_demo_prey):
        feed_demo_prey.queue_free()
    feed_demo_prey = null
    if animal != null:
        animal.position = Vector3(0.0, -0.38, 0.0)
        animal.quaternion = Quaternion.IDENTITY
    manual_command = ""
    command_timer = 0.0
    _clear_social_partner()
    if animation_label != null:
        animation_label.text = "애니메이션: AUTO"
    _apply_species_appearance()
    _apply_life_stage()

func _resize_ui() -> void:
    if ui_panel == null:
        return
    var screen := get_viewport().get_visible_rect().size
    ui_panel.position = Vector2(16, 74)
    ui_panel.size = Vector2(minf(320.0, screen.x * 0.68), maxf(100.0, screen.y - 94.0))


# Reusable simple leaf mesh: six triangles with a raised midrib and pointed tip.
func _leaf_mesh() -> ArrayMesh:
    # Curved leaf blade with a tapered tip, raised midrib, cupped edges, and a
    # subtle pigment gradient. Shared by canopy leaves and forest-floor litter.
    var vertices := PackedVector3Array()
    var colors := PackedColorArray()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var stations := 24
    for i in range(stations - 1):
        var t0: float = float(i) / float(stations - 1)
        var t1: float = float(i + 1) / float(stations - 1)
        var width0: float = 0.004 + pow(maxf(0.0, sin(PI * t0)), 0.82) * 0.112
        var width1: float = 0.004 + pow(maxf(0.0, sin(PI * t1)), 0.82) * 0.112
        var z0 := t0 * 0.43
        var z1 := t1 * 0.43
        var row0: Array[Vector3] = [Vector3(-width0, 0.0, z0), Vector3(0.0, 0.036 * sin(PI * t0), z0), Vector3(width0, 0.0, z0)]
        var row1: Array[Vector3] = [Vector3(-width1, 0.0, z1), Vector3(0.0, 0.036 * sin(PI * t1), z1), Vector3(width1, 0.0, z1)]
        for lane in range(2):
            var a: Vector3 = row0[lane]
            var b: Vector3 = row0[lane + 1]
            var c: Vector3 = row1[lane + 1]
            var d: Vector3 = row1[lane]
            for vertex in [a, b, c, a, c, d]:
                vertices.append(vertex)
                var center_vein: float = 1.0 if absf(vertex.x) < 0.0001 else 0.0
                colors.append(Color(0.74 + center_vein * 0.24, 0.86 + center_vein * 0.14, 0.65 + center_vein * 0.18))
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
    for tint in [Color(0.075, 0.24, 0.15), Color(0.12, 0.35, 0.20), Color(0.19, 0.43, 0.25), Color(0.28, 0.50, 0.28), Color(0.39, 0.49, 0.24), Color(0.47, 0.39, 0.18)]:
        var mat := _material(tint)
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 0.86
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
    for i in range(56):
        var plant := Node3D.new()
        plant.name = "Plant_%02d" % i
        var plant_cluster: Vector2 = plant_clusters[rng.randi_range(0, plant_clusters.size() - 1)]
        var plant_angle: float = rng.randf_range(0.0, TAU)
        var plant_radius: float = rng.randf_range(0.04, 0.53)
        plant.position = Vector3(plant_cluster.x + cos(plant_angle) * plant_radius, -0.53, plant_cluster.y + sin(plant_angle) * plant_radius)
        plant.position.x = clampf(plant.position.x, -2.95, 2.95)
        plant.position.z = clampf(plant.position.z, -2.18, 2.18)
        plant.rotation.y = rng.randf_range(-PI, PI)
        habitat_motion_root.add_child(plant)
        var plant_type := i % 3
        var height: float = rng.randf_range(1.35, 2.45) if plant_type != 1 else rng.randf_range(0.42, 0.88)
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
    for vine_index in range(18):
        var vine := Node3D.new()
        vine.name = "CanopyVine_%02d" % vine_index
        var vine_side: float = -1.0 if vine_index % 2 == 0 else 1.0
        vine.position = Vector3(rng.randf_range(-3.05, 3.05), rng.randf_range(3.25, 4.85), vine_side * rng.randf_range(1.70, 2.34))
        vine.rotation.y = rng.randf_range(-PI, PI)
        habitat_motion_root.add_child(vine)
        var vine_length := rng.randf_range(1.35, 3.20)
        var previous_point := Vector3.ZERO
        for stem_step in range(12):
            var t: float = float(stem_step + 1) / 12.0
            var current_point := Vector3(0.11 * sin(t * TAU * 1.2 + float(vine_index)), -vine_length * t, 0.055 * sin(t * TAU + float(vine_index) * 0.7))
            _segment(vine, previous_point, current_point, 0.006, Color(0.21, 0.32, 0.16))
            previous_point = current_point
        for leaf_index in range(9):
            var leaf := MeshInstance3D.new()
            leaf.mesh = leaf_mesh
            leaf.material_override = leaf_materials[rng.randi_range(0, leaf_materials.size() - 1)]
            leaf.position = Vector3(rng.randf_range(-0.13, 0.13), -vine_length * float(leaf_index + 1) / 8.0, 0.0)
            leaf.rotation = Vector3(-0.35, rng.randf_range(-PI, PI), rng.randf_range(-0.2, 0.2))
            leaf.scale = Vector3(rng.randf_range(0.92, 1.22), 0.88, rng.randf_range(0.95, 1.42))
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
        mote.position = Vector3(rng.randf_range(-3.25, 3.25), rng.randf_range(-0.3, 5.0), rng.randf_range(-2.38, 2.38))
        habitat_motion_root.add_child(mote)
        drifting_particles.append(mote)
        particle_origins.append(mote.position)

func _create_habitat_details() -> void:
    # Slim dark frame bars mark the much larger enclosure without blocking it.
    var frame_color := Color(0.14, 0.18, 0.16)
    for x in [-5.57, 5.57]:
        for z in [-4.07, 4.07]:
            _segment(self, Vector3(x, -0.53, z), Vector3(x, 6.37, z), 0.014, frame_color)
    for y in [-0.53, 6.37]:
        for z in [-4.07, 4.07]:
            _segment(self, Vector3(-5.57, y, z), Vector3(5.57, y, z), 0.014, frame_color)
        for x in [-5.57, 5.57]:
            _segment(self, Vector3(x, y, -4.07), Vector3(x, y, 4.07), 0.014, frame_color)
    var root := Node3D.new()
    root.name = "SubstrateDetails"
    root.scale = Vector3(1.38, 1.0, 1.38)
    add_child(root)
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
        item.position = Vector3(clampf(litter_cluster.x + cos(litter_angle) * litter_radius, -3.0, 3.0), -0.535, clampf(litter_cluster.y + sin(litter_angle) * litter_radius, -2.25, 2.25))
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

func _create_feeder_insect(prey: Node3D, size_factor: float, body_color: Color, kind: String = "귀뚜라미") -> void:
    # Cricket-like feeder anatomy: a shielded thorax, plated abdomen, paired
    # tegmina, long filiform antennae, cerci, and three distinct leg pairs.
    var model := Node3D.new()
    model.name = "%sFeederAnatomy" % kind
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
    if kind in ["밀웜", "왁스웜"]:
        for wing_root in wing_pivots:
            wing_root.visible = false
        for antenna_root in antenna_roots:
            antenna_root.visible = false
        for hip in leg_hips:
            hip.scale = Vector3.ONE * 0.72
        for segment_index in range(6):
            var segment_t := float(segment_index) / 5.0
            var segment_color := shell_light if segment_index % 2 == 0 else shell
            _part(model, Vector3(0.0, -0.004, 0.005 + segment_t * 0.13), Vector3(0.030 * (1.0 - segment_t * 0.25), 0.022, 0.014), segment_color)
    elif kind in ["초파리", "검정파리"]:
        for wing_root in wing_pivots:
            wing_root.scale = Vector3(1.65, 0.58, 0.74)
    elif kind == "나방":
        for wing_root in wing_pivots:
            wing_root.scale = Vector3(2.05, 0.46, 0.92)
    elif kind == "두비아바퀴":
        model.scale = Vector3(size_factor * 1.25, size_factor * 0.74, size_factor * 0.88)
        for wing_root in wing_pivots:
            wing_root.visible = false
    elif kind == "풀무치":
        for hind_index in [2, 5]:
            leg_hips[hind_index].scale = Vector3(1.28, 1.0, 1.12)
    prey_appendages[prey.get_instance_id()] = {
        "hips": leg_hips,
        "knees": leg_knees,
        "antennae": antenna_roots,
        "wings": wing_pivots
    }

func _create_prey_appendages(prey: Node3D) -> void:
    _create_feeder_insect(prey, 0.70, Color(0.35, 0.24, 0.13))

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
    _process_camera_navigation(delta)
    if rigged_player != null and rigged_available:
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
            if _is_juvenile():
                var next_stage := mini(_life_stage_index() + 1, 6)
                life_stage = LIFE_STAGES[next_stage]
                molt_count = next_stage
            _apply_life_stage()
            hunger = minf(100.0, hunger + 12.0)
            energy = maxf(15.0, energy - 22.0)
    elif _is_juvenile() and life_age > 150.0 * float(molt_count + 1) and molt_count < 6 and hunger < 65.0 and stress < 40.0:
        molting = true
        molt_progress = 0.0
    hunger = minf(100.0, hunger + dt * 0.22)
    humidity = maxf(0.0, humidity - dt * 0.018)
    var humidity_stress_limit := 25.0 if selected_biome == "사막" else 40.0
    stress = clampf(stress + (dt * 0.75 if temperature < 21.0 or temperature > 31.0 or humidity < humidity_stress_limit else -dt * 0.15), 0.0, 100.0)
    if molting:
        pass
    elif not manual_command.is_empty():
        _advance_manual_command(dt)
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
                prey_pause_timers.erase(target_prey.get_instance_id())
                prey_kinds.erase(target_prey.get_instance_id())
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
    if roam_pause_time > 0.0:
        roam_pause_time = maxf(0.0, roam_pause_time - dt)
        roam_speed = move_toward(roam_speed, 0.0, dt * 0.10)
        behavior = "잠시 멈춰 주변 관찰"
        return
    if not roam_target_valid:
        roam_target = Vector3(randf_range(-WALK_BOUND_X * 0.86, WALK_BOUND_X * 0.86), -0.38, randf_range(-WALK_BOUND_Z * 0.84, WALK_BOUND_Z * 0.84))
        roam_target_valid = true
    var direction := roam_target - animal.position
    var distance: float = direction.length()
    if distance < 0.065:
        roam_target_valid = false
        roam_pause_time = randf_range(2.4, 5.6)
        roam_speed = 0.0
        behavior = "잠시 멈춰 주변 관찰"
        return
    var target_speed: float = minf(0.058, distance * 0.38)
    roam_speed = move_toward(roam_speed, target_speed, dt * 0.060)
    if direction.length_squared() > 0.0001:
        animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), dt * 1.2)
        animal.position = animal.position.move_toward(roam_target, dt * roam_speed)
        animal.position.x = clampf(animal.position.x, -WALK_BOUND_X, WALK_BOUND_X)
        animal.position.z = clampf(animal.position.z, -WALK_BOUND_Z, WALK_BOUND_Z)
        energy = maxf(0.0, energy - dt * 0.20)
        behavior = "천천히 이동"

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
            pointer_last = event.position
    elif event is InputEventMouseMotion:
        if editing and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
            if edit_mouse_start.distance_to(event.position) > 16.0:
                edit_mouse_moved = true
        elif touching:
            _orbit(event.relative)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F:
                follow_animal = not follow_animal
            KEY_HOME:
                orbit_yaw = 0.0
                orbit_pitch = 0.25
                orbit_distance = 9.4
                camera_pan = Vector3.ZERO
                follow_animal = false
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
                orbit_distance = clampf(orbit_distance - (distance - pinch_previous) * 0.014, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
            pinch_previous = distance
    _update_camera()

func _process_camera_navigation(delta: float) -> void:
    if camera == null:
        return
    var camera_right := Vector3(cos(orbit_yaw), 0.0, -sin(orbit_yaw))
    var camera_forward := Vector3(-sin(orbit_yaw), 0.0, -cos(orbit_yaw))
    var movement := Vector3.ZERO
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or bool(camera_touch_directions.get("left", false)):
        movement -= camera_right
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or bool(camera_touch_directions.get("right", false)):
        movement += camera_right
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or bool(camera_touch_directions.get("up", false)):
        movement += camera_forward
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or bool(camera_touch_directions.get("down", false)):
        movement -= camera_forward
    if Input.is_key_pressed(KEY_Q):
        movement.y += 1.0
    if Input.is_key_pressed(KEY_E):
        movement.y -= 1.0
    var speed := CAMERA_MOVE_SPEED * (CAMERA_BOOST_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
    if movement.length_squared() > 0.0:
        camera_pan += movement.normalized() * speed * delta
        _update_camera()
    if Input.is_key_pressed(KEY_PAGEUP):
        orbit_distance = maxf(CAMERA_MIN_DISTANCE, orbit_distance - speed * delta)
        _update_camera()
    elif Input.is_key_pressed(KEY_PAGEDOWN):
        orbit_distance = minf(CAMERA_MAX_DISTANCE, orbit_distance + speed * delta)
        _update_camera()

func _orbit(motion: Vector2) -> void:
    orbit_yaw -= motion.x * 0.008
    orbit_pitch = clampf(orbit_pitch + motion.y * 0.006, -1.42, 1.42)

func _set_camera_zoom(distance_delta: float) -> void:
    orbit_distance = clampf(orbit_distance + distance_delta, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
    _update_camera()

func _update_camera() -> void:
    if camera == null:
        return
    var center_base := animal.position + Vector3(0, 0.35, 0) if follow_animal and animal != null else Vector3(0, 2.10, 0)
    var center := center_base + camera_pan
    camera.position = center + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
    camera.look_at(center, Vector3.UP)

func _refresh() -> void:
    if status == null:
        return
    status.text = "%s · %s · %s\n사육장 %02d · %s\n%.1f°C | 습도 %.0f%% · 배고픔 %.0f · 체력 %.0f\n스트레스 %.0f · 먹이 개체 %d마리\n탈피 %d회 · 성장 %.0f%%\n행동: %s%s" % [mantis_name, selected_species, life_stage, active_save_slot, selected_biome, temperature, humidity, hunger, energy, stress, food_count, molt_count, growth * 100.0, behavior, " (정지)" if simulation_paused else ""]

func _save_state(show_message: bool = true) -> void:
    var target_path := _slot_path(active_save_slot)
    var backup_path := _slot_backup_path(active_save_slot)
    var data := {"version": 7, "slot": active_save_slot, "name": mantis_name, "species": selected_species, "life_stage": life_stage, "biome": selected_biome, "selected_prey_type": selected_prey_type, "decorations": decoration_data, "life_age": life_age, "molt_count": molt_count, "growth": growth, "hunger": hunger, "energy": energy, "stress": stress, "humidity": humidity, "temperature": temperature, "food_count": food_count, "prey_positions": _prey_positions(), "prey": _prey_records(), "animal_position": [animal.position.x, animal.position.y, animal.position.z]}
    # Keep a last-known-good copy before replacing the main save.
    if FileAccess.file_exists(target_path):
        var previous := FileAccess.get_file_as_string(target_path)
        var backup := FileAccess.open(backup_path, FileAccess.WRITE)
        if backup != null:
            backup.store_string(previous)
            backup.close()
    var file := FileAccess.open(target_path, FileAccess.WRITE)
    if file == null:
        if show_message:
            notice.text = "저장 실패: 파일을 열 수 없습니다."
        return
    file.store_string(JSON.stringify(data))
    file.close()
    _write_active_save_slot()
    if show_message:
        notice.text = "저장 완료"

func _load_state(show_message: bool) -> void:
    var candidates: Array[String] = [_slot_path(active_save_slot), _slot_backup_path(active_save_slot)]
    if active_save_slot == 1:
        candidates.append_array([SAVE_PATH, BACKUP_PATH, V5_SAVE_PATH, V4_SAVE_PATH, PREVIOUS_SAVE_PATH, LEGACY_SAVE_PATH])
    var path := ""
    for candidate in candidates:
        if FileAccess.file_exists(candidate):
            var candidate_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
            if candidate_data is Dictionary and int(candidate_data.get("version", 0)) in [2, 3, 4, 5, 6, 7]:
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
    if not (parsed is Dictionary) or int(parsed.get("version", 0)) not in [2, 3, 4, 5, 6, 7]:
        if show_message:
            notice.text = "저장 파일 형식이 맞지 않습니다."
        return
    _clear_decorations()
    var saved_decor: Variant = parsed.get("decorations", [])
    if saved_decor is Array:
        for entry in saved_decor:
            if entry is Dictionary and decorations.size() < MAX_DECORATIONS:
                var kind: String = str(entry.get("kind", "rock"))
                var x: float = clampf(float(entry.get("x", 0.0)), -5.35, 5.35)
                var z: float = clampf(float(entry.get("z", 0.0)), -3.85, 3.85)
                if kind in ["rock", "wood"]:
                    _add_decoration(kind, Vector3(x, -0.50, z))
    var saved_species := str(parsed.get("species", "왕사마귀"))
    selected_species = saved_species if SPECIES_NAMES.has(saved_species) else "왕사마귀"
    var saved_molt_count := clampi(int(parsed.get("molt_count", 0)), 0, 6)
    var saved_stage := str(parsed.get("life_stage", "성체"))
    if saved_stage == "약충":
        life_stage = LIFE_STAGES[mini(saved_molt_count, 5)]
    else:
        life_stage = saved_stage if LIFE_STAGES.has(saved_stage) else "성체"
    var saved_biome := str(parsed.get("biome", "열대 우림"))
    selected_biome = saved_biome if BIOME_NAMES.has(saved_biome) else "열대 우림"
    var saved_prey_kind := str(parsed.get("selected_prey_type", "귀뚜라미"))
    selected_prey_type = saved_prey_kind if PREY_TYPES.has(saved_prey_kind) else "귀뚜라미"
    mantis_name = str(parsed.get("name", "초록이"))
    life_age = maxf(0.0, float(parsed.get("life_age", 0.0)))
    molt_count = saved_molt_count
    growth = clampf(float(parsed.get("growth", 0.35)), 0.35, 1.0)
    _apply_species_appearance()
    hunger = clampf(float(parsed.get("hunger", 32.0)), 0.0, 100.0)
    energy = clampf(float(parsed.get("energy", 86.0)), 0.0, 100.0)
    stress = clampf(float(parsed.get("stress", 12.0)), 0.0, 100.0)
    humidity = clampf(float(parsed.get("humidity", 70.0)), 0.0, 100.0)
    temperature = clampf(float(parsed.get("temperature", 25.0)), 15.0, 38.0)
    for prey in prey_nodes:
        if is_instance_valid(prey):
            if habitat_interactions != null:
                habitat_interactions.unregister_prey(prey)
            prey.queue_free()
    prey_nodes.clear()
    prey_kinds.clear()
    prey_velocities.clear()
    prey_pause_timers.clear()
    prey_appendages.clear()
    var records: Variant = parsed.get("prey", [])
    var positions: Variant = parsed.get("prey_positions", [])
    if records is Array and not records.is_empty():
        for record in records:
            if record is Dictionary and prey_nodes.size() < MAX_FOOD:
                var pos := Vector3(clampf(float(record.get("x", 0.0)), -PREY_BOUND_X, PREY_BOUND_X), -0.38, clampf(float(record.get("z", 0.0)), -PREY_BOUND_Z, PREY_BOUND_Z))
                var kind := str(record.get("kind", selected_prey_type))
                _spawn_prey(pos, kind if PREY_TYPES.has(kind) else selected_prey_type)
        food_count = prey_nodes.size()
    elif positions is Array and positions.size() > 0:
        for coords in positions:
            if coords is Array and coords.size() == 3 and prey_nodes.size() < MAX_FOOD:
                _spawn_prey(Vector3(clampf(float(coords[0]), -PREY_BOUND_X, PREY_BOUND_X), -0.38, clampf(float(coords[2]), -PREY_BOUND_Z, PREY_BOUND_Z)), selected_prey_type)
        food_count = prey_nodes.size()
    else:
        food_count = clampi(int(parsed.get("food_count", 0)), 0, MAX_FOOD)
        _sync_prey()
    var pos: Variant = parsed.get("animal_position", [])
    if pos is Array and pos.size() == 3:
        animal.position = Vector3(clampf(float(pos[0]), -WALK_BOUND_X, WALK_BOUND_X), -0.38, clampf(float(pos[2]), -WALK_BOUND_Z, WALK_BOUND_Z))
    _apply_life_stage()
    if show_message:
        notice.text = "불러오기 완료" + (" (백업 복구)" if path == _slot_backup_path(active_save_slot) else "")
    _refresh()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and animal != null:
        _save_state()

func _add_food() -> void:
    if prey_nodes.size() >= MAX_FOOD:
        notice.text = "먹이는 최대 %d개까지 넣을 수 있습니다." % MAX_FOOD
        return
    _spawn_prey(Vector3(randf_range(-4.80, 4.80), -0.38, randf_range(-3.45, 3.45)), selected_prey_type)
    food_count = prey_nodes.size()
    _refresh()

func _spawn_prey(pos: Vector3, kind: String = "귀뚜라미") -> void:
    var prey := Node3D.new()
    prey.name = "Prey_%02d_%s" % [prey_nodes.size(), kind]
    prey.position = pos
    add_child(prey)
    _create_feeder_insect(prey, _prey_size(kind), _prey_color(kind), kind)
    prey_nodes.append(prey)
    prey_kinds[prey.get_instance_id()] = kind
    if habitat_interactions != null:
        habitat_interactions.register_prey(prey)
    var prey_speed := _prey_speed(kind)
    prey_velocities[prey.get_instance_id()] = Vector3(randf_range(-prey_speed, prey_speed), 0, randf_range(-prey_speed, prey_speed))
    prey_pause_timers[prey.get_instance_id()] = randf_range(0.25, 1.15)

func _sync_prey() -> void:
    while prey_nodes.size() < food_count:
        _spawn_prey(Vector3(randf_range(-4.80, 4.80), -0.38, randf_range(-3.45, 3.45)), selected_prey_type)
    food_count = prey_nodes.size()

func _prey_positions() -> Array:
    var result := []
    for prey in prey_nodes:
        result.append([prey.position.x, prey.position.y, prey.position.z])
    return result

func _prey_records() -> Array:
    var result: Array[Dictionary] = []
    for prey in prey_nodes:
        if not is_instance_valid(prey):
            continue
        result.append({"x": prey.position.x, "y": prey.position.y, "z": prey.position.z, "kind": str(prey_kinds.get(prey.get_instance_id(), "귀뚜라미"))})
    return result

func _prey_size(kind: String) -> float:
    match kind:
        "초파리":
            return 0.40
        "검정파리":
            return 0.62
        "밀웜", "왁스웜":
            return 0.66
        "두비아바퀴":
            return 0.82
        "풀무치":
            return 0.92
        "나방":
            return 0.76
        _:
            return 0.70

func _prey_color(kind: String) -> Color:
    match kind:
        "두비아바퀴":
            return Color(0.28, 0.18, 0.12)
        "초파리":
            return Color(0.48, 0.31, 0.20)
        "검정파리":
            return Color(0.20, 0.36, 0.31)
        "밀웜":
            return Color(0.70, 0.51, 0.25)
        "왁스웜":
            return Color(0.82, 0.69, 0.40)
        "풀무치":
            return Color(0.42, 0.42, 0.18)
        "나방":
            return Color(0.62, 0.56, 0.45)
        _:
            return Color(0.35, 0.24, 0.13)

func _prey_speed(kind: String) -> float:
    match kind:
        "초파리", "검정파리":
            return 0.32
        "풀무치":
            return 0.22
        "귀뚜라미":
            return 0.16
        "두비아바퀴":
            return 0.12
        "밀웜", "왁스웜":
            return 0.055
        "나방":
            return 0.20
        _:
            return 0.14

func _make_gait_bone(parent: Node3D, radius: float, tint: Color) -> MeshInstance3D:
    var bone := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 0.85
    mesh.height = 1.0
    bone.mesh = mesh
    bone.material_override = _cuticle_material(tint)
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
    if not manual_command.is_empty():
        _finish_manual_command()
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
        if rigged_player != null and rigged_clip == "STRIKE" and rigged_available:
            rigged_player.seek(0.0, true)
    if animation_label != null:
        animation_label.text = "애니메이션: " + clip

func _resolve_animation() -> String:
    if molting:
        return "MOLT"
    match manual_command:
        "HUNT":
            return "HUNT"
        "JUMP":
            return "FLY"
        "HANG":
            return "CLIMB"
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
    if behavior.contains("관찰") or behavior.contains("멈춤"):
        return "SCAN" if fmod(elapsed, 6.8) < 1.6 else "IDLE"
    if behavior.contains("이동") or behavior.contains("접근") or behavior.contains("탐색"):
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
    walking_phase += dt * (2.25 if next_state == "CLIMB" else 4.4 if next_state == "HUNT" else 4.8)
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
        elif next_state == "CLIMB" and manual_command == "HANG":
            var perch_foot := Vector3(side * 0.20, 0.18, -0.10 if index == 0 else 0.16)
            foot_world = joint.to_global(perch_foot)
            foot_anchors[i] = foot_world
            foot_in_swing[i] = false
            foot = joint.to_local(foot_world)
        elif next_state == "CLIMB" and climb_active:
            var axis := climb_branch_end - climb_branch_start
            var tangent := axis.normalized()
            var radial := Vector3(0.0, 0.0, 1.0)
            radial = (radial - tangent * radial.dot(tangent)).normalized()
            var around := tangent.cross(radial).normalized()
            var step_cycle := fposmod(walking_phase / TAU + float(i) * 0.25, 1.0)
            var step_offset := 0.065 * climb_direction
            var step_lift := 0.0
            if step_cycle < 0.28:
                var step_t := step_cycle / 0.28
                step_offset = lerpf(-0.075, 0.080, step_t) * climb_direction
                step_lift = sin(step_t * PI) * 0.035
            var t_axis := clampf(climb_progress + step_offset, 0.0, 1.0)
            var on_axis := climb_branch_start + axis * t_axis
            var angle := (-0.70 if i < 2 else 0.70) + (-0.16 if index == 0 else 0.16)
            var contact_normal := (radial * cos(angle) + around * sin(angle)).normalized()
            var trunk_radius := lerpf(0.160, 0.082, t_axis)
            foot_world = on_axis + contact_normal * (trunk_radius + 0.014 + step_lift)
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
        var prey_speed := _prey_speed(str(prey_kinds.get(id, "귀뚜라미")))
        var velocity: Vector3 = prey_velocities.get(id, Vector3.ZERO)
        var away := prey.position - animal.position
        if away.length() < prey_alert_radius and away.length() > 0.001:
            velocity = away.normalized() * prey_speed * 1.8
            prey_pause_timers[id] = 0.0
        else:
            var pause_time: float = float(prey_pause_timers.get(id, 0.0))
            if pause_time > 0.0:
                pause_time = maxf(0.0, pause_time - dt)
                velocity = velocity.move_toward(Vector3.ZERO, dt * 0.45)
                prey_pause_timers[id] = pause_time
            elif randf() < dt * 0.7:
                if randf() < 0.34:
                    velocity = Vector3.ZERO
                    prey_pause_timers[id] = randf_range(0.35, 1.20)
                else:
                    velocity = Vector3(randf_range(-prey_speed, prey_speed), 0, randf_range(-prey_speed, prey_speed))
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
    if absf(point.x) > 5.35 or absf(point.z) > 3.85:
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
