extends SceneTree

func _initialize() -> void:
    call_deferred("_verify_blue_yabby")

func _verify_blue_yabby() -> void:
    if not ResourceLoader.exists("res://assets/models/blue_yabby.glb"):
        _fail("The blue yabby GLB is missing")
        return
    var model_scene := load("res://assets/models/blue_yabby.glb") as PackedScene
    if model_scene == null:
        _fail("The blue yabby GLB did not import as a PackedScene")
        return

    var app_scene := load("res://scenes/main.tscn") as PackedScene
    if app_scene == null:
        _fail("Could not load the main scene")
        return
    var app := app_scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    app.call("_set_species_mode", 2, false)
    await process_frame
    var habitat := app.get("blue_crayfish_habitat") as Node3D
    if habitat == null:
        _fail("The main scene did not create the blue crayfish habitat")
        return
    if not habitat.visible:
        _fail("Selecting crayfish left the blue crayfish habitat hidden")
        return
    var aquarium := app.get("aquarium_system") as Node3D
    if aquarium == null or aquarium.visible:
        _fail("The old procedural crayfish aquarium is still selected")
        return

    var actor := habitat.get_node_or_null("BlueCrayfishActor") as Node3D
    if actor == null:
        _fail("The blue crayfish actor was not instantiated")
        return
    if actor.find_children("*", "MeshInstance3D", true, false).is_empty():
        _fail("The selected crayfish has no imported model meshes")
        return
    if actor.find_children("ChelipedPivot_*", "Node3D", true, false).is_empty():
        _fail("The imported model is missing its animated claw pivots")
        return

    app.call("_encourage_crayfish")
    if not bool(habitat.get("is_outside")):
        _fail("The crayfish lure control is not connected to the selected habitat")
        return
    var label := String(habitat.call("status_text"))
    if not label.contains("파란가재"):
        _fail("The crayfish status does not identify the modeled blue yabby")
        return
    app.call("_retreat_crayfish")
    if bool(habitat.get("is_outside")):
        _fail("The return-to-burrow control did not reset the crayfish state")
        return

    print("Runtime blue yabby check passed: imported GLB, visible selector, animated claws, and habitat controls")
    quit()

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
