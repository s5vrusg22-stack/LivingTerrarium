extends SceneTree

func _initialize() -> void:
    call_deferred("_verify_mantis_simulation")

func _verify_mantis_simulation() -> void:
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
    if model == null or not model.visible:
        _fail("The latest mantis GLB is missing or hidden")
        return
    var clips: Dictionary = app.get("latest_mantis_clips")
    if clips.size() < 10 or not clips.has("FLY"):
        _fail("Expected the current GLB animation set to include FLY")
        return

    var stage_picker := app.get("stage_picker") as OptionButton
    if stage_picker == null or stage_picker.item_count != 7:
        _fail("Expected selectable instars 1 through 6 and adult")
        return
    app.call("_on_stage_selected", 0)
    var animal := app.get("animal") as Node3D
    var expected_scale := float(app.call("_growth_visual_scale")) * 0.23
    if str(app.get("life_stage")) != "1령 약충" or not is_equal_approx(animal.scale.x, expected_scale):
        _fail("First instar stage or size was not applied")
        return
    var buds := app.get("juvenile_wing_buds") as Node3D
    if buds == null or not buds.visible:
        _fail("Juvenile wing buds were not shown")
        return
    app.call("_on_stage_selected", 6)
    if str(app.get("life_stage")) != "성체" or buds.visible:
        _fail("Adult stage did not restore the adult wing state")
        return

    app.call("_command_mantis", "FLAP")
    if str(app.get("animation_preview")) != "FLY":
        _fail("Wing flapping did not select the imported FLY animation")
        return
    app.call("_end_mantis_action")
    app.call("_command_mantis", "FLY")
    var flight_start: Vector3 = animal.position
    app.call("_advance_flight", 0.5)
    if animal.position == flight_start:
        _fail("Flight demonstration did not move the mantis")
        return
    app.call("_end_mantis_action")
    if animal.position.distance_to(flight_start) > 0.001:
        _fail("Flight demonstration did not return the mantis to its starting point")
        return

    app.call("_command_mantis", "THREATEN")
    if str(app.get("manual_command")) != "THREATEN" or app.get("social_partner") == null:
        _fail("Threat display did not create a social partner")
        return
    app.call("_command_mantis", "FIGHT")
    if str(app.get("manual_command")) != "FIGHT":
        _fail("Fight demonstration did not start")
        return
    app.call("_command_mantis", "MATE")
    if str(app.get("manual_command")) != "MATE":
        _fail("Adult mating demonstration did not start")
        return
    app.call("_end_mantis_action")

    if app.find_child("CameraDirectionPad", true, false) == null:
        _fail("On-screen camera navigation pad is missing")
        return
    var directions: Dictionary = app.get("camera_touch_directions")
    directions["right"] = true
    var pan_before: Vector3 = app.get("camera_pan")
    app.call("_process_camera_navigation", 0.25)
    directions.erase("right")
    if app.get("camera_pan") == pan_before:
        _fail("Touch camera navigation did not move the view")
        return

    var buttons: Array = app.find_children("*", "Button", true, false)
    for button_node in buttons:
        var button := button_node as Button
        if button != null and button.text == "3D 모델 전환 (GLB / 기본)":
            _fail("Obsolete procedural model switch is still exposed")
            return

    print("Mantis simulation check passed: latest GLB, six instars, flight and social behavior, and free camera")
    quit()

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
