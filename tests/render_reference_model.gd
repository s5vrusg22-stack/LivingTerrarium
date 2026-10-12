extends SceneTree

const VIEWS := [
    {"name": "front", "dx": 0.0, "dy": 0.0, "dz": -1.0, "ux": 0.0, "uy": 1.0, "uz": 0.0},
    {"name": "left", "dx": 1.0, "dy": 0.0, "dz": 0.0, "ux": 0.0, "uy": 1.0, "uz": 0.0},
    {"name": "rear", "dx": 0.0, "dy": 0.0, "dz": 1.0, "ux": 0.0, "uy": 1.0, "uz": 0.0},
    {"name": "right", "dx": -1.0, "dy": 0.0, "dz": 0.0, "ux": 0.0, "uy": 1.0, "uz": 0.0},
    {"name": "top", "dx": 0.0, "dy": 1.0, "dz": 0.0, "ux": 0.0, "uy": 0.0, "uz": -1.0},
    {"name": "bottom", "dx": 0.0, "dy": -1.0, "dz": 0.0, "ux": 0.0, "uy": 0.0, "uz": -1.0},
]
const CAPTURE_WIDTH := 1280.0
const CAPTURE_HEIGHT := 720.0

func _initialize() -> void:
    call_deferred("_capture_reference_views")

func _capture_reference_views() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Unable to load the main terrarium scene.")
        quit(1)
        return

    var app := packed.instantiate()
    get_root().add_child(app)
    for _frame in range(8):
        await process_frame

    if app.animal == null or app.camera == null or app.root_ui == null:
        push_error("The scene did not initialize its mantis, camera, or UI.")
        quit(1)
        return
    var mesh_instances: Array = app.animal.find_children("*", "MeshInstance3D", true, false)
    if mesh_instances.size() < 30:
        push_error("The procedural mantis hierarchy is incomplete: %d mesh instances." % mesh_instances.size())
        quit(1)
        return

    app.simulation_paused = true
    app.wind_enabled = false
    app.follow_animal = false
    app.root_ui.visible = false
    app.animal.position = Vector3.ZERO
    app.animal.rotation = Vector3.ZERO

    var bounds := AABB()
    var has_bounds := false
    for candidate in mesh_instances:
        var part := candidate as MeshInstance3D
        if part.mesh == null:
            push_error("The mantis contains a MeshInstance3D without a mesh: %s" % part.get_path())
            quit(1)
            return
        var part_bounds: AABB = part.global_transform * part.get_aabb()
        if part_bounds.size.length_squared() <= 0.000001:
            continue
        bounds = part_bounds if not has_bounds else bounds.merge(part_bounds)
        has_bounds = true
    if not has_bounds:
        push_error("The mantis has no renderable mesh bounds.")
        quit(1)
        return

    # Reference shots isolate the insect so habitat geometry cannot obscure anatomy.
    for child in app.get_children():
        if child == app.animal or child == app.camera or child is WorldEnvironment or child is Light3D:
            continue
        if child is Node3D:
            (child as Node3D).visible = false
        elif child is CanvasItem:
            (child as CanvasItem).visible = false

    var environment_nodes: Array = app.find_children("*", "WorldEnvironment", true, false)
    if environment_nodes.is_empty():
        push_error("The main scene has no WorldEnvironment.")
        quit(1)
        return
    var world_environment := environment_nodes[0] as WorldEnvironment
    if world_environment.environment == null:
        push_error("The main scene has no Environment resource.")
        quit(1)
        return
    world_environment.environment.background_mode = Environment.BG_COLOR
    world_environment.environment.background_color = Color(0.24, 0.27, 0.29)
    world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world_environment.environment.ambient_light_color = Color(0.90, 0.92, 0.90)
    world_environment.environment.ambient_light_energy = 0.72

    var key_found := false
    for child in app.get_children():
        if child is DirectionalLight3D:
            var key := child as DirectionalLight3D
            key.light_energy = 0.82
            key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
            key.shadow_enabled = true
            key_found = true
    if not key_found:
        push_error("The main scene has no key DirectionalLight3D.")
        quit(1)
        return

    var fill := DirectionalLight3D.new()
    fill.name = "ReferenceFillLight"
    fill.rotation_degrees = Vector3(-28.0, 148.0, 0.0)
    fill.light_energy = 0.38
    fill.shadow_enabled = false
    app.add_child(fill)

    var center := bounds.position + bounds.size * 0.5
    var floor := MeshInstance3D.new()
    floor.name = "ReferenceStudioFloor"
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(200.0, 200.0)
    floor.mesh = floor_mesh
    floor.position = Vector3(center.x, bounds.position.y - 0.025, center.z)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.30, 0.32, 0.34)
    floor_material.roughness = 0.96
    floor.material_override = floor_material
    floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    app.add_child(floor)

    app.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    app.camera.near = 0.02
    app.camera.far = maxf(40.0, bounds.size.length() * 4.0)
    app.camera.current = true

    var center_to_camera := maxf(bounds.size.length() * 1.8, 1.0)
    var aspect := CAPTURE_WIDTH / CAPTURE_HEIGHT
    var framing_fill := 0.82

    var output_dir := OS.get_environment("GITHUB_WORKSPACE").path_join("build/model-renders")
    if OS.get_environment("GITHUB_WORKSPACE").is_empty():
        output_dir = OS.get_user_data_dir().path_join("reference_model_renders")
    var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
    if dir_error != OK:
        push_error("Unable to create render output directory: %s" % output_dir)
        quit(1)
        return

    for view in VIEWS:
        var camera_direction := Vector3(float(view["dx"]), float(view["dy"]), float(view["dz"])).normalized()
        var up_hint := Vector3(float(view["ux"]), float(view["uy"]), float(view["uz"])).normalized()
        var forward := -camera_direction
        var right_axis := forward.cross(up_hint).normalized()
        var screen_up := right_axis.cross(forward).normalized()
        var projected_width := absf(right_axis.x) * bounds.size.x + absf(right_axis.y) * bounds.size.y + absf(right_axis.z) * bounds.size.z
        var projected_height := absf(screen_up.x) * bounds.size.x + absf(screen_up.y) * bounds.size.y + absf(screen_up.z) * bounds.size.z
        app.camera.size = maxf(projected_height, projected_width / aspect) / framing_fill
        app.camera.position = center + camera_direction * center_to_camera
        app.camera.look_at(center, up_hint)
        for _frame in range(6):
            await process_frame

        var image: Image = get_root().get_texture().get_image()
        if image == null or image.is_empty():
            push_error("The renderer returned an empty image for %s." % view["name"])
            quit(1)
            return
        if image.get_width() != int(CAPTURE_WIDTH) or image.get_height() != int(CAPTURE_HEIGHT):
            push_error("Unexpected render size for %s: %dx%d" % [view["name"], image.get_width(), image.get_height()])
            quit(1)
            return
        var image_path := output_dir.path_join("%s.png" % view["name"])
        var save_error := image.save_png(image_path)
        if save_error != OK:
            push_error("Unable to write %s: %s" % [image_path, save_error])
            quit(1)
            return
        print("Captured %s mantis view: %s (%dx%d)" % [view["name"], image_path, image.get_width(), image.get_height()])

    quit(0)
