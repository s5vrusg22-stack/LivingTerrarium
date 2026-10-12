extends SceneTree

const VIEWS := [
    {"name": "front", "yaw": PI},
    {"name": "left", "yaw": PI * 0.5},
    {"name": "rear", "yaw": 0.0},
    {"name": "right", "yaw": PI * 1.5},
]

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
    var mesh_instances := app.animal.find_children("*", "MeshInstance3D", true, false)
    if mesh_instances.size() < 30:
        push_error("The procedural mantis hierarchy is incomplete: %d mesh instances." % mesh_instances.size())
        quit(1)
        return

    app.simulation_paused = true
    app.wind_enabled = false
    app.follow_animal = true
    app.root_ui.visible = false
    app.orbit_distance = 2.05
    app.orbit_pitch = 0.12
    app.camera_pan = Vector3.ZERO

    var output_dir := OS.get_environment("GITHUB_WORKSPACE").path_join("build/model-renders")
    if OS.get_environment("GITHUB_WORKSPACE").is_empty():
        output_dir = OS.get_user_data_dir().path_join("reference_model_renders")
    var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
    if dir_error != OK:
        push_error("Unable to create render output directory: %s" % output_dir)
        quit(1)
        return

    for view in VIEWS:
        app.orbit_yaw = float(view["yaw"])
        app._update_camera()
        for _frame in range(4):
            await process_frame
        var image: Image = get_root().get_texture().get_image()
        if image == null or image.is_empty():
            push_error("The renderer returned an empty image for %s." % view["name"])
            quit(1)
            return
        var image_path := output_dir.path_join("%s.png" % view["name"])
        var save_error := image.save_png(image_path)
        if save_error != OK:
            push_error("Unable to write %s: %s" % [image_path, save_error])
            quit(1)
            return
        print("Captured %s mantis view: %s" % [view["name"], image_path])

    quit(0)
