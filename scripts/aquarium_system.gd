extends Node3D

const FISH_LIMIT := 24
const STARTING_FISH := 12
const WATER_BOTTOM := -0.52
const WATERLINE := 0.40

var clock := 0.0
var flow_enabled := true
var fish_records: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var current_dashes: Array[MeshInstance3D] = []
var bubbles: Array[MeshInstance3D] = []
var bubble_phases: Array[float] = []
var ripple_rings: Array[MeshInstance3D] = []
var water_surface: MeshInstance3D

var fish_body_mesh: ArrayMesh
var leaf_mesh: ArrayMesh
var gravel_mesh: SphereMesh
var stone_texture: Texture2D
var foliage_texture: Texture2D
var foliage_normal: Texture2D
var foliage_roughness: Texture2D

var water_material: StandardMaterial3D
var flow_material: StandardMaterial3D
var bubble_material: StandardMaterial3D
var plant_materials: Array[StandardMaterial3D] = []
var species_view := "fish"
var burrow_root: Node3D
var crayfish_root: Node3D
var crayfish_legs: Array[Dictionary] = []
var crayfish_claws: Array[Dictionary] = []
var crayfish_antennae: Array[Node3D] = []
var crayfish_state := "sheltered"
var crayfish_state_clock := 0.0
var crayfish_state_duration := 8.0
var crayfish_cycle := 0
var crayfish_home := Vector3(-1.43, WATER_BOTTOM + 0.218, -1.08)
var crayfish_exit := Vector3(-1.34, WATER_BOTTOM + 0.218, -0.63)
var crayfish_patrol_center := Vector3(-0.88, WATER_BOTTOM + 0.218, -0.43)


func _ready() -> void:
	stone_texture = load("res://assets/textures/stone_albedo.png")
	foliage_texture = load("res://assets/textures/foliage_albedo.png")
	foliage_normal = load("res://assets/textures/foliage_normal.png")
	foliage_roughness = load("res://assets/textures/foliage_roughness.png")
	_create_water_volume()
	_create_gravel_and_rocks()
	_create_filter()
	_create_aquatic_plants()
	_create_flow_and_bubbles()
	_create_surface_ripples()
	for i in range(STARTING_FISH):
		_create_fish(i, i % 3)
	_create_crayfish_burrow()
	_create_crayfish()
	set_species_view("fish")


func fish_count() -> int:
	return fish_records.size()


func add_fish() -> bool:
	if fish_records.size() >= FISH_LIMIT:
		return false
	var index := fish_records.size()
	_create_fish(index, index % 3)
	return true


func remove_fish() -> bool:
	if fish_records.size() <= 1:
		return false
	var record: Dictionary = fish_records.pop_back()
	var fish_root: Node3D = record["root"]
	fish_root.queue_free()
	return true


func toggle_flow() -> bool:
	flow_enabled = not flow_enabled
	for dash in current_dashes:
		dash.visible = flow_enabled
	for bubble in bubbles:
		bubble.visible = flow_enabled
	return flow_enabled


func set_species_view(mode: String) -> void:
	var next_view := "crayfish" if mode == "crayfish" else "fish"
	var entering_crayfish := next_view == "crayfish" and species_view != "crayfish"
	species_view = next_view
	for record in fish_records:
		var fish_root: Node3D = record["root"]
		fish_root.visible = species_view == "fish"
	if burrow_root != null:
		burrow_root.visible = species_view == "crayfish"
	if entering_crayfish:
		crayfish_state = "sheltered"
		crayfish_state_clock = 0.0
		crayfish_state_duration = 6.0
		crayfish_root.position = crayfish_home
	if crayfish_root != null:
		crayfish_root.visible = species_view == "crayfish" and crayfish_state != "sheltered"


func encourage_crayfish() -> void:
	if species_view != "crayfish":
		return
	if crayfish_state == "sheltered":
		_begin_crayfish_emergence()


func retreat_crayfish() -> void:
	if species_view == "crayfish" and crayfish_state in ["emerging", "active"]:
		_begin_crayfish_retreat()


func crayfish_status() -> String:
	match crayfish_state:
		"sheltered": return "바위 틈 굴에서 휴식"
		"emerging": return "굴 밖으로 나오는 중"
		"active": return "바닥을 탐색하며 활동 중"
		"returning": return "바위 틈 굴로 돌아가는 중"
	return "굴 주변을 살피는 중"


func simulate(dt: float) -> void:
	clock += dt
	if species_view == "fish":
		_animate_school()
	else:
		_animate_crayfish(dt)
	_animate_plants()
	_animate_water_effects()


func _begin_crayfish_emergence() -> void:
	crayfish_state = "emerging"
	crayfish_state_clock = 0.0
	crayfish_state_duration = 2.8
	crayfish_root.visible = true
	crayfish_root.position = crayfish_home
	crayfish_root.rotation.y = PI


func _begin_crayfish_retreat() -> void:
	crayfish_state = "returning"
	crayfish_state_clock = 0.0
	crayfish_state_duration = 3.2


func _animate_crayfish(dt: float) -> void:
	if crayfish_root == null:
		return
	crayfish_state_clock += dt
	var gait := sin(clock * 8.0)
	for entry in crayfish_legs:
		var pivot: Node3D = entry["pivot"]
		var side := float(entry["side"])
		var phase := float(entry["phase"])
		pivot.rotation.y = side * (0.10 + sin(clock * 7.2 + phase) * 0.13)
		pivot.rotation.z = sin(clock * 7.2 + phase) * 0.09
	for entry in crayfish_claws:
		var pivot: Node3D = entry["pivot"]
		var side := float(entry["side"])
		pivot.rotation.y = side * (0.08 + sin(clock * 2.4 + side) * 0.11)
		pivot.rotation.z = side * (0.04 + sin(clock * 3.4 + side) * 0.055)
	for i in range(crayfish_antennae.size()):
		var antenna: Node3D = crayfish_antennae[i]
		antenna.rotation.y = sin(clock * 2.3 + float(i) * PI) * 0.10
		antenna.rotation.x = cos(clock * 1.8 + float(i)) * 0.055
	if crayfish_state == "sheltered":
		if crayfish_state_clock >= crayfish_state_duration:
			_begin_crayfish_emergence()
		return
	if crayfish_state == "emerging":
		var progress := clampf(crayfish_state_clock / crayfish_state_duration, 0.0, 1.0)
		crayfish_root.position = crayfish_home.lerp(crayfish_exit, _ease_smooth(progress))
		crayfish_root.position.z += progress * 0.15
		crayfish_root.rotation.y = lerpf(PI, 2.88, progress)
		if progress >= 1.0:
			crayfish_state = "active"
			crayfish_state_clock = 0.0
			crayfish_state_duration = 11.0 + fposmod(float(crayfish_cycle * 5 + 3), 7.0)
			crayfish_cycle += 1
		return
	if crayfish_state == "active":
		var angle := clock * 0.42
		var patrol := crayfish_patrol_center + Vector3(cos(angle) * 0.42, 0.0, sin(angle) * 0.34)
		patrol.x = clampf(patrol.x, -1.63, 0.46)
		patrol.z = clampf(patrol.z, -0.78, 0.22)
		crayfish_root.position = crayfish_root.position.lerp(patrol, minf(dt * 1.7, 1.0))
		var direction := Vector3(-sin(angle), 0.0, cos(angle))
		crayfish_root.rotation.y = lerp_angle(crayfish_root.rotation.y, atan2(-direction.x, -direction.z), minf(dt * 2.0, 1.0))
		crayfish_root.position.y = WATER_BOTTOM + 0.218 + gait * 0.003
		if crayfish_state_clock >= crayfish_state_duration:
			_begin_crayfish_retreat()
		return
	if crayfish_state == "returning":
		var progress := clampf(crayfish_state_clock / crayfish_state_duration, 0.0, 1.0)
		crayfish_root.position = crayfish_root.position.lerp(crayfish_home, minf(dt * (0.9 + progress * 2.0), 1.0))
		crayfish_root.position.z -= dt * 0.035
		crayfish_root.rotation.y = lerp_angle(crayfish_root.rotation.y, PI, minf(dt * 1.4, 1.0))
		if progress >= 1.0:
			crayfish_state = "sheltered"
			crayfish_state_clock = 0.0
			crayfish_state_duration = 12.0 + fposmod(float(crayfish_cycle * 5 + 2), 8.0)
			crayfish_root.position = crayfish_home
			crayfish_root.visible = false


func _ease_smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _create_crayfish_burrow() -> void:
	burrow_root = Node3D.new()
	burrow_root.name = "CrayfishRockCreviceBurrow"
	add_child(burrow_root)
	var rock_material := _material(Color(0.63, 0.66, 0.62), 0.94)
	rock_material.albedo_texture = stone_texture
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 16
	rock_mesh.rings = 10
	var dark_entrance := MeshInstance3D.new()
	dark_entrance.name = "ShadowedBurrowOpening"
	dark_entrance.mesh = rock_mesh
	dark_entrance.position = Vector3(-1.39, WATER_BOTTOM + 0.18, -0.90)
	dark_entrance.scale = Vector3(0.34, 0.22, 0.075)
	dark_entrance.material_override = _material(Color(0.018, 0.027, 0.026), 1.0)
	burrow_root.add_child(dark_entrance)
	var boulders: Array[Dictionary] = [
		{"p": Vector3(-1.73, WATER_BOTTOM + 0.11, -0.83), "s": Vector3(0.29, 0.20, 0.34)},
		{"p": Vector3(-1.08, WATER_BOTTOM + 0.12, -0.83), "s": Vector3(0.30, 0.22, 0.35)},
		{"p": Vector3(-1.40, WATER_BOTTOM + 0.34, -0.89), "s": Vector3(0.40, 0.15, 0.30)},
		{"p": Vector3(-1.68, WATER_BOTTOM + 0.30, -0.68), "s": Vector3(0.23, 0.13, 0.26)},
		{"p": Vector3(-1.12, WATER_BOTTOM + 0.31, -0.69), "s": Vector3(0.22, 0.14, 0.25)},
		{"p": Vector3(-1.43, WATER_BOTTOM + 0.10, -0.62), "s": Vector3(0.39, 0.12, 0.23)}
	]
	for i in range(boulders.size()):
		var entry: Dictionary = boulders[i]
		var rock := MeshInstance3D.new()
		rock.name = "BurrowBoulder_%02d" % i
		rock.mesh = rock_mesh
		rock.position = entry["p"]
		rock.scale = entry["s"]
		rock.rotation.y = float(i) * 0.71
		rock.material_override = rock_material
		burrow_root.add_child(rock)
	var moss := MeshInstance3D.new()
	moss.name = "CreviceMoss"
	moss.mesh = rock_mesh
	moss.position = Vector3(-1.56, WATER_BOTTOM + 0.48, -0.83)
	moss.scale = Vector3(0.22, 0.035, 0.17)
	moss.material_override = _material(Color(0.13, 0.33, 0.19), 0.9)
	burrow_root.add_child(moss)


func _create_crayfish() -> void:
	crayfish_root = Node3D.new()
	crayfish_root.name = "FreshwaterCrayfish"
	crayfish_root.position = crayfish_home
	crayfish_root.scale = Vector3.ONE * 1.30
	crayfish_root.visible = false
	add_child(crayfish_root)
	var shell := _material(Color(0.025, 0.22, 0.69), 0.31, 0.16)
	var shell_light := _material(Color(0.075, 0.47, 0.96), 0.27, 0.14)
	var shell_dark := _material(Color(0.012, 0.085, 0.29), 0.40, 0.08)
	var joints := _material(Color(0.18, 0.58, 0.96), 0.30, 0.12)
	var shell_glint := _material(Color(0.36, 0.78, 1.0), 0.24, 0.10)
	var dark := _material(Color(0.018, 0.021, 0.022), 0.18)
	_add_crayfish_ellipsoid(crayfish_root, "Carapace", Vector3(0, 0.035, -0.075), Vector3(0.20, 0.115, 0.25), shell)
	_add_rod(crayfish_root, Vector3(0, 0.126, -0.20), Vector3(0, 0.119, 0.10), 0.008, shell_glint.albedo_color)
	for side in [-1.0, 1.0]:
		_add_rod(crayfish_root, Vector3(side * 0.12, 0.105, -0.20), Vector3(side * 0.18, 0.075, 0.08), 0.007, shell_light.albedo_color)
		_add_crayfish_ellipsoid(crayfish_root, "GillCover_%s" % ("L" if side < 0.0 else "R"), Vector3(side * 0.174, -0.002, -0.01), Vector3(0.035, 0.062, 0.125), shell_dark)
		for gill_rib in range(4):
			var gill_z := -0.075 + float(gill_rib) * 0.042
			_add_rod(crayfish_root, Vector3(side * 0.187, -0.035, gill_z), Vector3(side * 0.184, 0.028, gill_z - 0.012), 0.0035, joints.albedo_color)
	_add_rod(crayfish_root, Vector3(0, 0.064, -0.235), Vector3(0, 0.035, -0.465), 0.021, shell_light.albedo_color)
	for side in [-1.0, 1.0]:
		_add_rod(crayfish_root, Vector3(0, 0.050, -0.30), Vector3(side * 0.055, 0.026, -0.405), 0.010, shell_glint.albedo_color)
		_add_crayfish_ellipsoid(crayfish_root, "RostralTooth", Vector3(side * 0.047, 0.046, -0.327), Vector3(0.012, 0.012, 0.035), joints)
	# Fine raised speckles catch the aquarium light across the blue carapace.
	for side in [-1.0, 1.0]:
		for spot in range(7):
			var spot_z: float = -0.19 + float(spot) * 0.037
			var spot_x: float = side * (0.171 - absf(float(spot) - 3.0) * 0.002)
			var spot_y: float = 0.066 + sin(float(spot) * 0.9) * 0.012
			_add_crayfish_ellipsoid(crayfish_root, "CarapaceSpeckle_%s_%02d" % ["L" if side < 0.0 else "R", spot], Vector3(spot_x, spot_y, spot_z), Vector3(0.008, 0.006, 0.010), shell_glint if spot % 3 == 0 else shell_light)
	_add_crayfish_ellipsoid(crayfish_root, "ThroatPlate", Vector3(0, -0.02, 0.09), Vector3(0.16, 0.055, 0.17), shell_dark)
	for i in range(5):
		var plate := MeshInstance3D.new()
		plate.name = "AbdominalSegment_%02d" % i
		var plate_mesh := SphereMesh.new()
		plate_mesh.radial_segments = 24
		plate_mesh.rings = 16
		plate.mesh = plate_mesh
		plate.position = Vector3(0, 0.025 - float(i) * 0.004, 0.145 + float(i) * 0.075)
		var width := 0.143 - float(i) * 0.017
		plate.scale = Vector3(width, 0.067 - float(i) * 0.006, 0.060)
		plate.material_override = shell_light if i % 2 == 0 else shell_dark if i == 3 else shell
		crayfish_root.add_child(plate)
		_add_rod(crayfish_root, Vector3(-width * 0.76, 0.047, plate.position.z - 0.025), Vector3(width * 0.76, 0.047, plate.position.z - 0.025), 0.008, shell_dark.albedo_color)
		_add_rod(crayfish_root, Vector3(-width * 0.66, 0.066, plate.position.z + 0.020), Vector3(width * 0.66, 0.066, plate.position.z + 0.020), 0.004, shell_glint.albedo_color)
	for side in [-1.0, 1.0]:
		_add_crayfish_ellipsoid(crayfish_root, "EyeSocket", Vector3(side * 0.108, 0.105, -0.225), Vector3(0.040, 0.038, 0.038), shell_dark)
		_add_crayfish_ellipsoid(crayfish_root, "EyeStalk", Vector3(side * 0.105, 0.135, -0.225), Vector3(0.019, 0.048, 0.019), joints)
		_add_crayfish_ellipsoid(crayfish_root, "CompoundEye", Vector3(side * 0.108, 0.175, -0.236), Vector3(0.033, 0.032, 0.034), dark)
		_add_crayfish_ellipsoid(crayfish_root, "EyeGlint", Vector3(side * 0.118, 0.184, -0.260), Vector3(0.009, 0.010, 0.007), shell_glint)
		var antenna := Node3D.new()
		antenna.name = "Antenna_%s" % ("L" if side < 0.0 else "R")
		antenna.position = Vector3(side * 0.045, 0.105, -0.28)
		crayfish_root.add_child(antenna)
		_add_crayfish_ellipsoid(antenna, "AntennaSocket", Vector3.ZERO, Vector3(0.025, 0.019, 0.025), shell_dark)
		_add_rod(antenna, Vector3.ZERO, Vector3(side * 0.09, 0.075, -0.18), 0.006, joints.albedo_color)
		_add_rod(antenna, Vector3(side * 0.09, 0.075, -0.18), Vector3(side * 0.14, 0.10, -0.34), 0.004, shell_light.albedo_color)
		_add_rod(antenna, Vector3(side * 0.14, 0.10, -0.34), Vector3(side * 0.19, 0.12, -0.48), 0.0025, shell_glint.albedo_color)
		crayfish_antennae.append(antenna)
	for side in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.name = "PincerArm_%s" % ("L" if side < 0.0 else "R")
		claw.position = Vector3(side * 0.158, -0.005, -0.19)
		crayfish_root.add_child(claw)
		_add_rod(claw, Vector3.ZERO, Vector3(side * 0.12, -0.035, -0.095), 0.047, shell_dark.albedo_color)
		_add_crayfish_ellipsoid(claw, "Elbow", Vector3(side * 0.12, -0.035, -0.095), Vector3(0.058, 0.052, 0.057), joints)
		_add_rod(claw, Vector3(side * 0.12, -0.035, -0.095), Vector3(side * 0.205, -0.055, -0.17), 0.039, shell_light.albedo_color)
		_add_crayfish_ellipsoid(claw, "WristShield", Vector3(side * 0.205, -0.055, -0.17), Vector3(0.070, 0.064, 0.075), shell_dark)
		_add_crayfish_ellipsoid(claw, "PincerPalm", Vector3(side * 0.265, -0.058, -0.215), Vector3(0.135, 0.080, 0.165), shell_light)
		_add_crayfish_ellipsoid(claw, "PalmDorsalRidge", Vector3(side * 0.265, 0.016, -0.215), Vector3(0.105, 0.012, 0.125), shell_glint)
		for ridge in range(4):
			var ridge_z := -0.31 + float(ridge) * 0.060
			_add_rod(claw, Vector3(side * 0.19, 0.025, ridge_z), Vector3(side * 0.34, 0.025, ridge_z - 0.008), 0.0045, shell_glint.albedo_color)
		for spine in range(4):
			var spine_z := -0.32 + float(spine) * 0.052
			_add_crayfish_ellipsoid(claw, "PalmSpine_%02d" % spine, Vector3(side * 0.386, 0.002, spine_z), Vector3(0.021, 0.026, 0.023), shell_dark)
		var inner_base := Vector3(side * 0.18, -0.066, -0.32)
		var inner_tip := Vector3(side * 0.23, -0.084, -0.515)
		var outer_base := Vector3(side * 0.35, -0.066, -0.31)
		var outer_tip := Vector3(side * 0.255, -0.084, -0.50)
		_add_rod(claw, inner_base, inner_tip, 0.026, shell_dark.albedo_color)
		_add_rod(claw, outer_base, outer_tip, 0.029, shell_dark.albedo_color)
		_add_crayfish_ellipsoid(claw, "PincerTip", (inner_tip + outer_tip) * 0.5, Vector3(0.025, 0.020, 0.032), shell_glint)
		for tooth in range(4):
			var tooth_z := -0.355 - float(tooth) * 0.034
			var tooth_y := -0.072
			_add_rod(claw, Vector3(side * 0.195, tooth_y, tooth_z), Vector3(side * 0.235, tooth_y - 0.006, tooth_z - 0.016), 0.008, shell_glint.albedo_color)
			_add_rod(claw, Vector3(side * 0.32, tooth_y, tooth_z - 0.008), Vector3(side * 0.27, tooth_y - 0.006, tooth_z - 0.022), 0.008, shell_glint.albedo_color)
		crayfish_claws.append({"pivot": claw, "side": side})
	var leg_index := 0
	for side in [-1.0, 1.0]:
		for leg_number in range(4):
			var leg := Node3D.new()
			leg.name = "WalkingLeg_%02d" % leg_index
			var z := -0.07 + float(leg_number) * 0.075
			leg.position = Vector3(side * (0.135 - float(leg_number) * 0.012), -0.015, z)
			crayfish_root.add_child(leg)
			var knee := Vector3(side * 0.095, -0.065, 0.035)
			var foot := Vector3(side * (0.17 - float(leg_number) * 0.008), -0.135, 0.105)
			_add_crayfish_ellipsoid(leg, "CoxaPlate", Vector3.ZERO, Vector3(0.033, 0.026, 0.038), shell_dark)
			_add_rod(leg, Vector3.ZERO, knee, 0.017, shell_light.albedo_color)
			_add_crayfish_ellipsoid(leg, "LegJoint", knee, Vector3(0.023, 0.021, 0.023), joints)
			_add_rod(leg, knee, foot, 0.010, shell_dark.albedo_color)
			_add_rod(leg, foot, foot + Vector3(0, -0.018, -0.040), 0.0055, shell_glint.albedo_color)
			crayfish_legs.append({"pivot": leg, "side": side, "phase": float(leg_index) * 1.37})
			leg_index += 1
	for side in [-1.0, 1.0]:
		var swimmer := MeshInstance3D.new()
		var swimmer_mesh := SphereMesh.new()
		swimmer_mesh.radial_segments = 10
		swimmer_mesh.rings = 6
		swimmer.mesh = swimmer_mesh
		swimmer.position = Vector3(side * 0.07, -0.03, 0.33)
		swimmer.scale = Vector3(0.075, 0.020, 0.084)
		swimmer.material_override = shell_light
		crayfish_root.add_child(swimmer)
	_add_crayfish_ellipsoid(crayfish_root, "TailFan", Vector3(0, 0.015, 0.49), Vector3(0.105, 0.026, 0.095), shell_dark)
	for side in [-1.0, 1.0]:
		var tail_lobe := MeshInstance3D.new()
		var lobe_mesh := SphereMesh.new()
		lobe_mesh.radial_segments = 20
		lobe_mesh.rings = 12
		tail_lobe.mesh = lobe_mesh
		tail_lobe.position = Vector3(side * 0.073, 0.015, 0.535)
		tail_lobe.scale = Vector3(0.064, 0.028, 0.105)
		tail_lobe.rotation.y = side * 0.30
		tail_lobe.material_override = shell_light
		crayfish_root.add_child(tail_lobe)


func _add_crayfish_ellipsoid(parent: Node3D, node_name: String, local_position: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var body_part := MeshInstance3D.new()
	body_part.name = node_name
	var mesh := SphereMesh.new()
	mesh.radial_segments = 20
	mesh.rings = 12
	body_part.mesh = mesh
	body_part.position = local_position
	body_part.scale = dimensions
	body_part.material_override = material
	parent.add_child(body_part)
	return body_part


func _create_water_volume() -> void:
	var volume := MeshInstance3D.new()
	volume.name = "ClearAquariumWater"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(3.86, WATERLINE - WATER_BOTTOM, 2.68)
	volume.mesh = water_mesh
	volume.position.y = (WATERLINE + WATER_BOTTOM) * 0.5
	water_material = _material(Color(0.15, 0.47, 0.52, 0.12), 0.16, 0.04)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	volume.material_override = water_material
	add_child(volume)

	water_surface = MeshInstance3D.new()
	water_surface.name = "WaterlineSurface"
	var surface_mesh := PlaneMesh.new()
	surface_mesh.size = Vector2(3.84, 2.64)
	water_surface.mesh = surface_mesh
	water_surface.position.y = WATERLINE
	var surface_material := _material(Color(0.43, 0.83, 0.86, 0.30), 0.14, 0.12)
	surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	surface_material.emission_enabled = true
	surface_material.emission = Color(0.06, 0.20, 0.20)
	surface_material.emission_energy_multiplier = 0.22
	water_surface.material_override = surface_material
	add_child(water_surface)


func _create_gravel_and_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 841207
	gravel_mesh = SphereMesh.new()
	gravel_mesh.radial_segments = 7
	gravel_mesh.rings = 4
	var gravel_colors: Array[Color] = [
		Color(0.58, 0.48, 0.34), Color(0.40, 0.43, 0.38),
		Color(0.72, 0.64, 0.47), Color(0.31, 0.36, 0.34)
	]
	for i in range(92):
		var grain := MeshInstance3D.new()
		grain.name = "AquariumGravel_%03d" % i
		grain.mesh = gravel_mesh
		grain.position = Vector3(rng.randf_range(-1.84, 1.84), WATER_BOTTOM + 0.008, rng.randf_range(-1.27, 1.27))
		var radius := rng.randf_range(0.012, 0.034)
		grain.scale = Vector3(radius * rng.randf_range(0.8, 1.4), radius * 0.48, radius * rng.randf_range(0.8, 1.5))
		grain.rotation.y = rng.randf_range(-PI, PI)
		grain.material_override = _material(gravel_colors[i % gravel_colors.size()], 0.90)
		add_child(grain)

	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radial_segments = 14
	boulder_mesh.rings = 9
	var boulder_material := _material(Color(0.72, 0.78, 0.75), 0.92)
	boulder_material.albedo_texture = stone_texture
	for i in range(9):
		var rock := MeshInstance3D.new()
		rock.name = "AquariumStone_%02d" % i
		rock.mesh = boulder_mesh
		var x := -1.45 + float(i) * 0.36 + rng.randf_range(-0.12, 0.12)
		var z := -0.86 if i % 2 == 0 else 0.78
		var size := rng.randf_range(0.12, 0.24)
		rock.position = Vector3(x, WATER_BOTTOM + size * 0.28, z + rng.randf_range(-0.15, 0.15))
		rock.scale = Vector3(size * rng.randf_range(0.85, 1.35), size * 0.68, size * rng.randf_range(0.85, 1.45))
		rock.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-PI, PI), rng.randf_range(-0.2, 0.2))
		rock.material_override = boulder_material
		add_child(rock)
		# Small moss pads soften the joins between stone and gravel.
		if i % 2 == 0:
			var moss := MeshInstance3D.new()
			moss.mesh = boulder_mesh
			moss.position = rock.position + Vector3(0.0, size * 0.44, size * 0.12)
			moss.scale = Vector3(size * 0.48, size * 0.12, size * 0.30)
			moss.material_override = _material(Color(0.16, 0.38, 0.20), 0.88)
			add_child(moss)


func _create_filter() -> void:
	var filter := Node3D.new()
	filter.name = "SubmersiblePowerFilter"
	filter.position = Vector3(1.73, -0.02, -1.13)
	add_child(filter)
	var housing := MeshInstance3D.new()
	var housing_mesh := CylinderMesh.new()
	housing_mesh.top_radius = 0.095
	housing_mesh.bottom_radius = 0.115
	housing_mesh.height = 0.70
	housing_mesh.radial_segments = 18
	housing.mesh = housing_mesh
	housing.material_override = _material(Color(0.12, 0.17, 0.17), 0.42, 0.18)
	filter.add_child(housing)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.10
	cap_mesh.bottom_radius = 0.10
	cap_mesh.height = 0.045
	cap_mesh.radial_segments = 18
	cap.mesh = cap_mesh
	cap.position.y = 0.36
	cap.material_override = _material(Color(0.21, 0.34, 0.31), 0.34, 0.20)
	filter.add_child(cap)
	for i in range(7):
		var slot := MeshInstance3D.new()
		var slot_mesh := BoxMesh.new()
		slot_mesh.size = Vector3(0.075, 0.012, 0.009)
		slot.mesh = slot_mesh
		slot.position = Vector3(-0.004, -0.25 + float(i) * 0.064, 0.108)
		slot.material_override = _material(Color(0.035, 0.055, 0.055), 0.55)
		filter.add_child(slot)
	_add_rod(filter, Vector3(0.02, 0.29, 0.0), Vector3(0.02, 0.29, 0.22), 0.026, Color(0.18, 0.29, 0.27))
	var outlet := MeshInstance3D.new()
	var outlet_mesh := BoxMesh.new()
	outlet_mesh.size = Vector3(0.43, 0.075, 0.09)
	outlet.mesh = outlet_mesh
	outlet.position = Vector3(-0.19, 0.29, 0.22)
	outlet.material_override = _material(Color(0.16, 0.25, 0.23), 0.37, 0.12)
	filter.add_child(outlet)
	for i in range(5):
		var nozzle := MeshInstance3D.new()
		var nozzle_mesh := SphereMesh.new()
		nozzle_mesh.radial_segments = 7
		nozzle_mesh.rings = 4
		nozzle.mesh = nozzle_mesh
		nozzle.scale = Vector3(0.012, 0.010, 0.018)
		nozzle.position = Vector3(-0.34 + float(i) * 0.075, 0.29, 0.265)
		nozzle.material_override = _material(Color(0.42, 0.81, 0.77), 0.3)
		filter.add_child(nozzle)
	var intake := MeshInstance3D.new()
	var intake_mesh := CylinderMesh.new()
	intake_mesh.top_radius = 0.022
	intake_mesh.bottom_radius = 0.022
	intake_mesh.height = 0.20
	intake_mesh.radial_segments = 10
	intake.mesh = intake_mesh
	intake.position = Vector3(0.0, -0.43, 0.0)
	intake.material_override = _material(Color(0.10, 0.14, 0.14), 0.45)
	filter.add_child(intake)


func _create_aquatic_plants() -> void:
	leaf_mesh = _make_aquatic_leaf_mesh()
	var tints: Array[Color] = [Color(0.45, 0.84, 0.52), Color(0.34, 0.72, 0.47), Color(0.61, 0.79, 0.38)]
	for tint in tints:
		var mat := _material(tint, 0.72)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = foliage_texture
		mat.normal_enabled = foliage_normal != null
		mat.normal_texture = foliage_normal
		mat.normal_scale = 0.42
		mat.roughness_texture = foliage_roughness
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		plant_materials.append(mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30082026
	for i in range(13):
		var plant := Node3D.new()
		plant.name = "AquaticPlant_%02d" % i
		var x := rng.randf_range(-1.63, 1.56)
		var z := rng.randf_range(-1.12, 1.12)
		plant.position = Vector3(x, WATER_BOTTOM + 0.02, z)
		add_child(plant)
		var leaf_count := rng.randi_range(5, 8)
		var leaf_joints: Array[Node3D] = []
		for j in range(leaf_count):
			var joint := Node3D.new()
			joint.position.y = rng.randf_range(0.0, 0.13)
			joint.rotation.y = TAU * float(j) / float(leaf_count) + rng.randf_range(-0.24, 0.24)
			joint.rotation.z = rng.randf_range(-0.13, 0.13)
			plant.add_child(joint)
			var blade := MeshInstance3D.new()
			blade.mesh = leaf_mesh
			blade.scale = Vector3(rng.randf_range(0.72, 1.18), rng.randf_range(0.56, 1.0), rng.randf_range(0.68, 1.15))
			blade.rotation.z = rng.randf_range(-0.22, 0.22)
			blade.material_override = plant_materials[(i + j) % plant_materials.size()]
			joint.add_child(blade)
			leaf_joints.append(joint)
		plants.append({"root": plant, "leaves": leaf_joints, "phase": rng.randf_range(0.0, TAU), "stiffness": rng.randf_range(0.55, 1.20)})


func _make_aquatic_leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height_steps := 18
	var width_steps := 6
	for i in range(height_steps + 1):
		var t := float(i) / float(height_steps)
		var half_width := 0.052 * pow(maxf(0.0, sin(PI * t)), 0.68)
		var bend := sin(t * PI * 0.85) * 0.035
		for j in range(width_steps + 1):
			var across := float(j) / float(width_steps) * 2.0 - 1.0
			var rib := 0.006 * (1.0 - absf(across)) * sin(PI * t)
			surface.set_color(Color(0.72 + rib * 4.0, 0.88 + rib * 2.0, 0.68 + rib * 3.0))
			surface.set_uv(Vector2(float(j) / float(width_steps), t))
			surface.add_vertex(Vector3(across * half_width + bend, t * 0.82, across * across * 0.009 + rib))
	for i in range(height_steps):
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


func _create_flow_and_bubbles() -> void:
	flow_material = _material(Color(0.40, 0.89, 0.92, 0.70), 0.18)
	flow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flow_material.emission_enabled = true
	flow_material.emission = Color(0.05, 0.34, 0.38)
	flow_material.emission_energy_multiplier = 0.45
	var dash_mesh := SphereMesh.new()
	dash_mesh.radial_segments = 8
	dash_mesh.rings = 5
	for i in range(21):
		var dash := MeshInstance3D.new()
		dash.name = "FilterCurrent_%02d" % i
		dash.mesh = dash_mesh
		dash.scale = Vector3(0.015, 0.009, 0.060)
		dash.material_override = flow_material
		add_child(dash)
		current_dashes.append(dash)

	bubble_material = _material(Color(0.72, 0.94, 0.92, 0.36), 0.10)
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.emission_enabled = true
	bubble_material.emission = Color(0.14, 0.34, 0.35)
	bubble_material.emission_energy_multiplier = 0.25
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radial_segments = 9
	bubble_mesh.rings = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	for i in range(14):
		var bubble := MeshInstance3D.new()
		bubble.name = "FilterBubble_%02d" % i
		bubble.mesh = bubble_mesh
		var size := rng.randf_range(0.012, 0.027)
		bubble.scale = Vector3(size, size, size)
		bubble.material_override = bubble_material
		add_child(bubble)
		bubbles.append(bubble)
		bubble_phases.append(rng.randf())


func _create_surface_ripples() -> void:
	var ripple_material := _material(Color(0.72, 0.94, 0.89, 0.35), 0.20)
	ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_material.emission_enabled = true
	ripple_material.emission = Color(0.10, 0.25, 0.22)
	for i in range(5):
		var ripple := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.012
		torus.outer_radius = 0.12 + float(i) * 0.035
		torus.rings = 4
		torus.ring_segments = 28
		ripple.mesh = torus
		ripple.position = Vector3(1.14, WATERLINE + 0.012, -0.73)
		ripple.scale = Vector3.ONE * (0.70 + float(i) * 0.12)
		ripple.material_override = ripple_material
		add_child(ripple)
		ripple_rings.append(ripple)


func _create_fish(index: int, school_id: int) -> void:
	var fish_root := Node3D.new()
	fish_root.name = "NeonTetra_%02d" % index
	add_child(fish_root)
	var base_colors: Array[Color] = [
		Color(0.66, 0.80, 0.74), Color(0.72, 0.77, 0.62),
		Color(0.58, 0.78, 0.83), Color(0.78, 0.75, 0.68)
	]
	var cyan := Color(0.10, 0.72, 0.98) if index % 3 != 2 else Color(0.22, 0.62, 1.0)
	var ruby := Color(0.97, 0.17, 0.22) if index % 4 != 1 else Color(0.97, 0.33, 0.12)
	var fin_color := Color(0.88, 0.54, 0.34).lerp(cyan, 0.27)
	var body := MeshInstance3D.new()
	body.name = "ScaledIridescentBody"
	body.mesh = _make_fish_body_mesh(base_colors[index % base_colors.size()], cyan, ruby)
	var body_material := _material(Color.WHITE, 0.28, 0.11)
	body_material.vertex_color_use_as_albedo = true
	body_material.metallic_specular = 0.46
	body.material_override = body_material
	fish_root.add_child(body)
	_add_body_fins(fish_root, fin_color)
	var tail := Node3D.new()
	tail.name = "OscillatingForkedTail"
	tail.position.z = 0.205
	fish_root.add_child(tail)
	var tail_mesh := _polygon_mesh(PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.085, 0.12),
		Vector3(0.0, 0.125, 0.25), Vector3(0.0, 0.025, 0.17),
		Vector3(0.0, 0.0, 0.105), Vector3(0.0, -0.025, 0.17),
		Vector3(0.0, -0.125, 0.25), Vector3(0.0, -0.085, 0.12)
	]), fin_color.lerp(cyan, 0.20))
	var tail_fin := MeshInstance3D.new()
	tail_fin.mesh = tail_mesh
	tail_fin.material_override = _fin_material(fin_color.lerp(cyan, 0.20))
	tail.add_child(tail_fin)
	for side in [-1.0, 1.0]:
		_add_rod(tail, Vector3(0.003 * side, 0.0, 0.01), Vector3(0.003 * side, 0.092 * side, 0.205), 0.0035, Color(0.95, 0.78, 0.58, 0.78))
		_add_rod(tail, Vector3(0.003 * side, 0.0, 0.015), Vector3(0.003 * side, 0.025 * side, 0.15), 0.0025, Color(0.95, 0.78, 0.58, 0.68))
	var pectoral_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var iris := MeshInstance3D.new()
		var iris_mesh := SphereMesh.new()
		iris_mesh.radial_segments = 12
		iris_mesh.rings = 8
		iris.mesh = iris_mesh
		iris.position = Vector3(side * 0.052, 0.037, -0.174)
		iris.scale = Vector3(0.020, 0.020, 0.012)
		iris.material_override = _material(Color(0.94, 0.66, 0.18), 0.24, 0.12)
		fish_root.add_child(iris)
		var pupil := MeshInstance3D.new()
		pupil.mesh = iris_mesh
		pupil.position = iris.position + Vector3(side * 0.006, 0.001, -0.006)
		pupil.scale = Vector3(0.010, 0.011, 0.009)
		pupil.material_override = _material(Color(0.015, 0.025, 0.030), 0.08)
		fish_root.add_child(pupil)
		var gill := MeshInstance3D.new()
		gill.mesh = iris_mesh
		gill.position = Vector3(side * 0.069, 0.0, -0.075)
		gill.scale = Vector3(0.008, 0.052, 0.034)
		gill.material_override = _material(Color(0.83, 0.75, 0.56, 0.82), 0.5)
		fish_root.add_child(gill)
	for side in [-1.0, 1.0]:
		var pectoral := Node3D.new()
		pectoral.name = "PectoralFin_%s" % ("L" if side < 0.0 else "R")
		pectoral.position = Vector3(side * 0.072, -0.018, -0.025)
		fish_root.add_child(pectoral)
		var fin := MeshInstance3D.new()
		fin.mesh = _polygon_mesh(PackedVector3Array([
			Vector3(0, 0, 0), Vector3(side * 0.10, -0.068, 0.025), Vector3(side * 0.018, -0.006, -0.11)
		]), fin_color.lerp(Color(0.95, 0.78, 0.58), 0.42))
		fin.material_override = _fin_material(fin_color.lerp(Color(0.95, 0.78, 0.58), 0.42))
		pectoral.add_child(fin)
		pectoral_pivots.append(pectoral)
	var fish_scale := 0.83 + float(index % 4) * 0.055
	fish_root.scale = Vector3.ONE * fish_scale
	fish_root.position = Vector3(0.0, -0.02, 0.0)
	fish_records.append({"root": fish_root, "tail": tail, "pectoral": pectoral_pivots, "school": school_id, "phase": float(index) * 1.73, "scale": fish_scale})


func _make_fish_body_mesh(base: Color, stripe: Color, tail_stripe: Color) -> ArrayMesh:
	var profile: Array[Vector3] = [
		Vector3(-0.255, 0.006, 0.008), Vector3(-0.225, 0.044, 0.046),
		Vector3(-0.17, 0.071, 0.076), Vector3(-0.075, 0.094, 0.104),
		Vector3(0.035, 0.097, 0.105), Vector3(0.13, 0.078, 0.082),
		Vector3(0.205, 0.043, 0.047), Vector3(0.242, 0.014, 0.018)
	]
	var sides := 24
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profile.size()):
		var ring := profile[i]
		for j in range(sides + 1):
			var angle := TAU * float(j) / float(sides)
			var x := cos(angle) * ring.y
			var y := sin(angle) * ring.z + 0.003
			var color := base
			var flank := absf(cos(angle)) > 0.58 and absf(sin(angle)) < 0.74
			if flank and ring.x > -0.19 and ring.x < 0.105:
				color = color.lerp(stripe, 0.88)
			elif flank and ring.x >= 0.105 and ring.x < 0.22:
				color = color.lerp(tail_stripe, 0.90)
			if sin(angle) > 0.45:
				color = color.darkened(0.12)
			surface.set_color(color)
			surface.set_uv(Vector2(float(j) / float(sides), float(i) / float(profile.size() - 1)))
			surface.add_vertex(Vector3(x, y, ring.x))
	for i in range(profile.size() - 1):
		for j in range(sides):
			var a := i * (sides + 1) + j
			var b := a + 1
			var d := a + sides + 1
			var c := d + 1
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(d)
	surface.generate_normals()
	return surface.commit()


func _add_body_fins(parent: Node3D, color: Color) -> void:
	var dorsal := MeshInstance3D.new()
	dorsal.name = "SailedDorsalFin"
	dorsal.mesh = _polygon_mesh(PackedVector3Array([
		Vector3(0, 0.075, -0.075), Vector3(0, 0.105, 0.005),
		Vector3(0, 0.185, 0.080), Vector3(0, 0.13, 0.155),
		Vector3(0, 0.075, 0.205)
	]), color.lerp(Color(0.94, 0.75, 0.45), 0.34))
	dorsal.material_override = _fin_material(color.lerp(Color(0.94, 0.75, 0.45), 0.34))
	parent.add_child(dorsal)
	var anal := MeshInstance3D.new()
	anal.name = "AnalFin"
	anal.mesh = _polygon_mesh(PackedVector3Array([
		Vector3(0, -0.07, 0.065), Vector3(0, -0.145, 0.11),
		Vector3(0, -0.125, 0.18), Vector3(0, -0.065, 0.215)
	]), color.lerp(Color(0.93, 0.65, 0.36), 0.26))
	anal.material_override = _fin_material(color.lerp(Color(0.93, 0.65, 0.36), 0.26))
	parent.add_child(anal)
	for ray in range(5):
		var z := -0.045 + float(ray) * 0.044
		_add_rod(parent, Vector3(0.003, 0.082, z), Vector3(0.003, 0.11 + float(ray % 2) * 0.035, z + 0.025), 0.0024, Color(0.97, 0.78, 0.54, 0.72))


func _polygon_mesh(points: PackedVector3Array, color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size() - 1):
		surface.set_color(color)
		surface.add_vertex(points[0])
		surface.add_vertex(points[i])
		surface.add_vertex(points[i + 1])
		surface.set_color(color)
		surface.add_vertex(points[0])
		surface.add_vertex(points[i + 1])
		surface.add_vertex(points[i])
	surface.generate_normals()
	return surface.commit()


func _fin_material(color: Color) -> StandardMaterial3D:
	var mat := _material(Color.WHITE, 0.33, 0.04)
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.86)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	return mat


func _animate_school() -> void:
	var school_sizes: Dictionary = {}
	for record in fish_records:
		var school := int(record["school"])
		school_sizes[school] = int(school_sizes.get(school, 0)) + 1
	var school_members: Dictionary = {}
	for record in fish_records:
		var school := int(record["school"])
		var member := int(school_members.get(school, 0))
		school_members[school] = member + 1
		var count := maxf(1.0, float(school_sizes[school]))
		var phase := clock * (0.39 + float(school) * 0.035) + float(school) * TAU / 3.0
		var heading := PI - phase
		var center := Vector3(cos(phase) * 0.78, -0.04 + sin(phase * 1.7 + float(school)) * 0.055, sin(phase) * 0.62)
		var formation := float(member) * TAU / count + sin(clock * 0.31 + float(school)) * 0.18
		var local_offset := Vector3(cos(formation) * 0.18, sin(clock * 1.1 + float(member)) * 0.035, sin(formation) * 0.27)
		local_offset = local_offset.rotated(Vector3.UP, heading)
		var position := center + local_offset
		position.x = clampf(position.x, -1.62, 1.62)
		position.y = clampf(position.y + sin(clock * 1.25 + float(record["phase"])) * 0.025, -0.27, 0.20)
		position.z = clampf(position.z, -1.08, 1.08)
		var root: Node3D = record["root"]
		root.position = position
		root.rotation.y = heading + sin(clock * 0.75 + float(record["phase"])) * 0.07
		var tail: Node3D = record["tail"]
		tail.rotation.y = sin(clock * 8.8 + float(record["phase"])) * 0.48
		var pectoral: Array = record["pectoral"]
		for pivot in pectoral:
			var fin_joint: Node3D = pivot
			fin_joint.rotation.z = sin(clock * 6.2 + float(record["phase"])) * 0.17


func _animate_plants() -> void:
	for entry in plants:
		var root: Node3D = entry["root"]
		var leaves: Array = entry["leaves"]
		var phase := float(entry["phase"])
		var stiffness := float(entry["stiffness"])
		root.rotation.z = sin(clock * 0.56 + phase) * 0.025 * stiffness
		for i in range(leaves.size()):
			var leaf: Node3D = leaves[i]
			leaf.rotation.z = sin(clock * 1.25 + phase + float(i) * 0.8) * 0.11 * stiffness
			leaf.rotation.x = cos(clock * 0.85 + phase * 0.6 + float(i)) * 0.035


func _animate_water_effects() -> void:
	for i in range(current_dashes.size()):
		var dash := current_dashes[i]
		var progress := fposmod(clock * 0.16 + float(i) / float(current_dashes.size()), 1.0)
		dash.position = Vector3(1.48 - progress * 2.9, 0.285 - sin(progress * PI) * 0.16 + sin(clock * 2.1 + float(i)) * 0.014, -1.02 + sin(progress * TAU * 1.5 + float(i) * 0.5) * 0.16)
		dash.rotation.y = -0.20 + sin(clock + float(i)) * 0.08
	for i in range(bubbles.size()):
		var bubble := bubbles[i]
		var phase := fposmod(clock * 0.21 + bubble_phases[i], 1.0)
		bubble.position = Vector3(1.70 + sin(clock * 2.1 + float(i)) * 0.045, WATER_BOTTOM + 0.08 + phase * 0.72, -0.97 + cos(clock * 1.6 + float(i) * 1.4) * 0.04)
	for i in range(ripple_rings.size()):
		var ring := ripple_rings[i]
		var pulse := 0.84 + fposmod(clock * 0.20 + float(i) * 0.19, 1.0) * 0.22
		ring.scale = Vector3.ONE * pulse
		ring.position.y = WATERLINE + 0.012 + sin(clock * 2.0 + float(i)) * 0.002


func _add_rod(parent: Node3D, start: Vector3, finish: Vector3, radius: float, color: Color) -> void:
	var rod := MeshInstance3D.new()
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = radius * 0.82
	rod_mesh.bottom_radius = radius
	rod_mesh.height = start.distance_to(finish)
	rod_mesh.radial_segments = 7
	rod.mesh = rod_mesh
	rod.position = (start + finish) * 0.5
	rod.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	rod.material_override = _material(color, 0.40)
	parent.add_child(rod)


func _material(color: Color, roughness: float = 0.68, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
