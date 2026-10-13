extends SceneTree

func _initialize() -> void:
    call_deferred("_verify_latest_model")

func _verify_latest_model() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Could not load the main scene")
        return
    var app := packed.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    if app.get("use_latest_mantis_visual") != true:
        _fail("The latest mantis is not selected by default")
        return
    var model := app.get("latest_mantis_visual") as Node3D
    if model == null:
        _fail("The latest mantis GLB was not instantiated")
        return
    if not model.visible:
        _fail("The latest mantis GLB is not visible at startup")
        return
    var clips: Dictionary = app.get("latest_mantis_clips")
    if clips.size() < 10:
        _fail("Expected at least ten imported animation clips, found %d" % clips.size())
        return

    print("Runtime mantis check passed: latest GLB visible with %d clips" % clips.size())
    quit()

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
