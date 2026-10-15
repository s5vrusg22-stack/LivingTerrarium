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

    if app.get("use_base1_mantis_visual") != true:
        _fail("Base 1 is not selected by default")
        return
    var model := app.get("base1_mantis_visual") as Node3D
    if model == null or not model.visible:
        _fail("Base 1 is missing or hidden")
        return
    if model.name != "Base1":
        _fail("Imported mantis root is not named Base1")
        return
    if app.get("follow_animal") != true or app.get("habitat_framing") != false:
        _fail("Startup camera does not focus on the approved mantis")
        return
    if not is_equal_approx(float(app.get("orbit_distance")), 3.80):
        _fail("Startup camera does not frame the full mantis model")
        return
    var clips: Dictionary = app.get("base1_mantis_clips")
    if clips.is_empty():
        _fail("Base 1 imported without any animation clips")
        return
    print("Base 1 animation clips: ", clips.keys())
    if app.get("use_photo_visual") != false:
        _fail("A photo cutout was selected instead of the Base 1 GLB")
        return
    var rigged := app.get("rigged_visual") as Node3D
    if rigged != null and rigged.visible:
        _fail("A second mantis visual is visible alongside the Base 1 GLB")
        return
    var photo := app.get("photo_visual") as Sprite3D
    var dorsal_photo := app.get("photo_visual_dorsal") as Sprite3D
    if (photo != null and photo.visible) or (dorsal_photo != null and dorsal_photo.visible):
        _fail("A photo cutout is visible instead of the Base 1 GLB")
        return
    var procedural: Array = app.get("procedural_meshes")
    for fallback in procedural:
        var mesh_instance := fallback as MeshInstance3D
        if mesh_instance != null and mesh_instance.visible:
            _fail("A procedural fallback mesh is visible instead of the Base 1 GLB")
            return

    var retained_cuticle_palette := false
    var retained_light_cuticle := false
    var retained_dark_cuticle := false
    var cuticle_color := Color.BLACK
    var light_color := Color.BLACK
    var dark_color := Color.BLACK
    for candidate in model.find_children("*", "MeshInstance3D", true, false):
        var part := candidate as MeshInstance3D
        if part == null or part.mesh == null:
            continue
        for surface_index in range(part.mesh.get_surface_count()):
            var material := part.get_active_material(surface_index) as StandardMaterial3D
            if material == null:
                continue
            var material_name := String(material.resource_name).to_lower()
            if material_name == "cuticle":
                cuticle_color = material.albedo_color
                if material.detail_enabled:
                    _fail("The cuticle material still has a noisy detail overlay")
                    return
                retained_cuticle_palette = true
            elif material_name == "cuticle_light":
                light_color = material.albedo_color
                retained_light_cuticle = true
            elif material_name == "cuticle_dark":
                dark_color = material.albedo_color
                retained_dark_cuticle = true
    if not retained_cuticle_palette or not retained_light_cuticle or not retained_dark_cuticle:
        _fail("The Base 1 base, light, or dark cuticle material is missing")
        return
    print("Base 1 cuticle palette: dark=", dark_color, " base=", cuticle_color, " light=", light_color)
    if (
        dark_color.r >= cuticle_color.r or dark_color.g >= cuticle_color.g or dark_color.b >= cuticle_color.b
        or cuticle_color.r >= light_color.r or cuticle_color.g >= light_color.g or cuticle_color.b >= light_color.b
    ):
        _fail("The Base 1 dark, olive, and light cuticle shades lost their authored color separation")
        return

    var pronotum := model.find_child("Pronotum", true, false) as MeshInstance3D
    var head := model.find_child("Head", true, false) as MeshInstance3D
    if pronotum == null or head == null or pronotum.mesh == null:
        _fail("The elongated neck or head mesh is missing")
        return
    var pronotum_vertices: PackedVector3Array = pronotum.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var neck_min_z := 0.0
    for vertex in pronotum_vertices:
        neck_min_z = minf(neck_min_z, vertex.z)
    if neck_min_z > -1.50 or head.position.z > -0.30:
        _fail("The pronotum and head do not show the requested longer neck profile")
        return

    for side in ["L", "R"]:
        var femur := model.find_child("Raptor_%s_Femur" % side, true, false) as MeshInstance3D
        if femur == null or femur.mesh == null or femur.mesh.get_surface_count() < 4:
            _fail("A raptorial femur with inward spines is missing")
            return
        for surface_index in [2, 3]:
            var femur_vertices: PackedVector3Array = femur.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
            var mean_x := 0.0
            for vertex in femur_vertices:
                mean_x += vertex.x
            mean_x /= maxf(float(femur_vertices.size()), 1.0)
            if (side == "L" and mean_x <= 0.0) or (side == "R" and mean_x >= 0.0):
                _fail("%s femur spines point outward instead of toward the center" % side)
                return

    var stage_picker := app.get("stage_picker") as OptionButton
    if stage_picker == null or stage_picker.item_count != 7:
        _fail("Expected selectable instars 1 through 6 and adult")
        return
    var animal := app.get("animal") as Node3D
    var buds := app.get("juvenile_wing_buds") as Node3D
    var stage_factors := [0.23, 0.30, 0.40, 0.52, 0.67, 0.84]
    var wing_parts: Array[MeshInstance3D] = []
    for candidate in model.find_children("*", "MeshInstance3D", true, false):
        var part := candidate as MeshInstance3D
        if part != null and part.name.begins_with("Wing_"):
            wing_parts.append(part)
    if wing_parts.size() < 2:
        _fail("Base 1 is missing the paired adult wing meshes")
        return
    for stage_index in range(6):
        app.call("_on_stage_selected", stage_index)
        var expected_scale := float(app.call("_growth_visual_scale")) * float(stage_factors[stage_index])
        if str(app.get("life_stage")) != ["1령 약충", "2령 약충", "3령 약충", "4령 약충", "5령 약충", "6령 약충"][stage_index] or not is_equal_approx(animal.scale.x, expected_scale):
            _fail("Instar %d did not apply its stage and body size" % (stage_index + 1))
            return
        if buds == null or not buds.visible:
            _fail("Instar %d did not show its wing buds" % (stage_index + 1))
            return
        for wing in wing_parts:
            if wing.visible:
                _fail("Adult wings were visible at instar %d" % (stage_index + 1))
                return
    app.call("_on_stage_selected", 6)
    if str(app.get("life_stage")) != "성체" or buds.visible:
        _fail("Adult stage did not hide the juvenile wing buds")
        return
    for wing in wing_parts:
        if not wing.visible:
            _fail("Adult stage did not restore both adult wings")
            return

    var save_name := app.get("mantis_name_input") as LineEdit
    var save_picker := app.get("mantis_save_picker") as OptionButton
    if save_name == null or save_picker == null:
        _fail("The multiple-mantis save controls are missing")
        return
    save_name.text = "검사용 1령"
    app.call("_on_stage_selected", 0)
    app.call("_save_current_mantis_profile")
    save_name.text = "검사용 6령"
    app.call("_on_stage_selected", 5)
    app.call("_save_current_mantis_profile")
    var profiles: Array = app.get("saved_mantises")
    if profiles.size() != 2 or save_picker.item_count != 2:
        _fail("Two separate mantis profiles were not saved")
        return
    save_picker.select(0)
    app.call("_load_selected_mantis_profile")
    if str(app.get("life_stage")) != "1령 약충":
        _fail("Loading a saved individual did not restore its instar")
        return
    var collection_file := FileAccess.open("user://mantis_collection_v1.json", FileAccess.READ)
    if collection_file == null:
        _fail("The saved mantis collection file was not created")
        return
    var collection_data: Variant = JSON.parse_string(collection_file.get_as_text())
    collection_file.close()
    if not (collection_data is Dictionary):
        _fail("The saved mantis collection could not be read")
        return
    var saved_individuals: Variant = collection_data.get("mantises", [])
    if not (saved_individuals is Array) or saved_individuals.size() != 2:
        _fail("The save file does not retain both individual mantises")
        return
    for path in ["user://mantis_collection_v1.json", "user://mantis_collection_v1_backup.json", "user://terrarium_save_v8.json", "user://terrarium_save_v8_backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

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
    app.call("_on_stage_selected", 6)
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
        if button != null and button.text in ["3D 모델 전환 (GLB / 기본)", "첨부 사진 보기 / 3D 복귀"]:
            _fail("Obsolete procedural model switch is still exposed")
            return

    print("Mantis simulation check passed: Base 1 GLB, six instars, flight and social behavior, and free camera")
    quit()

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
