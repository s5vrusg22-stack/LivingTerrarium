extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")


func _run_checks() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Could not load the main terrarium scene.")
        return

    var app := packed.instantiate() as Node3D
    if app == null:
        _fail("The main scene root is not Node3D.")
        return
    root.add_child(app)
    await process_frame

    var ecosystem := app.get_node_or_null("AnimatedEcosystem") as Node3D
    if ecosystem == null:
        _fail("The animated ecosystem was not created.")
        app.queue_free()
        return
    if not ecosystem.scale.is_equal_approx(Vector3.ONE):
        _fail("Plant dimensions are being enlarged with the enclosure.")
        app.queue_free()
        return

    var plant_count := 0
    for child in ecosystem.get_children():
        if child is Node3D and String(child.name).begins_with("Plant_"):
            plant_count += 1
            var position := (child as Node3D).position
            if absf(position.x) < 5.2 and absf(position.z) < 3.7:
                _fail("A plant was generated inside the central viewing lane.")
                app.queue_free()
                return

    if plant_count != 300:
        _fail("Expected 300 perimeter plants, found %d." % plant_count)
        app.queue_free()
        return

    print("Canopy check passed: 300 perimeter plants, readable scale, clear center.")
    app.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
