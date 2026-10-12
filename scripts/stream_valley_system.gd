extends Node3D

const SALAMANDER_LIMIT := 6
const FLOOR_Y := -0.46

var clock := 0.0
var temperature := 19.0
var humidity := 92.0
var flow_enabled := true
var salamanders: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var mist_motes: Array[Dictionary] = []
var stream_light: OmniLight3D
var water_surface: MeshInstance3D
var rng := RandomNumberGenerator.new()

const MARKING_COLORS := [
	Color(1.00, 0.72, 0.10),
	Color(1.00, 0.39, 0.08),
	Color(0.96, 0.84, 0.30),
	Color(0.92, 0.22, 0.12),
]
const ROCK_COLORS := [
	Color(0.34, 0.37, 0.36),
	Color(0.43, 0.43, 0.39),
	Color(0.27, 0.31, 0.31),
	Color(0.50, 0.48, 0.42),
]


func _ready() -> void:
	rng.randomize()
	_create_valley()
	for i in range(3):
		_create_salamander(i)


func _create_valley() -> void:
	_box(self, Vector3(0.0, -0.60, 0.0), Vector3(4.75, 0.20, 3.20), Color(0.22, 0.25, 0.20), "ValleyEarthBed")
	_box(self, Vector3(0.0, -0.47, 0.0), Vector3(4.48, 0.10, 2.98), Color(0.31, 0.30, 0.24), "DampForestFloor")
	# A clear, shallow channel cuts across the valley floor.
	water_surface = _box(self, Vector3(0.0, -0.265, 0.10), Vector3(4.52, 0.055, 0.84), Color(0.24, 0.66, 0.76, 0.78), "ClearCreekWater")
	var water_material := water_surface.material_override as StandardMaterial3D
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.18
	water_material.metallic = 0.06
	water_material.emission_enabled = true
	water_material.emission = Color(0.035, 0.20, 0.24)
	for x in [-2.10, 2.10]:
		_ellipsoid(self, Vector3(x, -0.10, 0.12), Vector3(0.50, 0.20, 0.68), ROCK_COLORS[1])
		_ellipsoid(self, Vector3(x, -0.08, -0.40), Vector3(0.47, 0.25, 0.54), ROCK_COLORS[2])
	for i in range(15):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := -2.02 + float(i) * 0.29
		var z := 0.10 + side * rng.randf_range(0.56, 1.03)
		var size := Vector3(rng.randf_range(0.18, 0.34), rng.randf_range(0.12, 0.24), rng.randf_range(0.17, 0.34))
		var rock := _ellipsoid(self, Vector3(x, FLOOR_Y + size.y * 0.55, z), size, ROCK_COLORS[i % ROCK_COLORS.size()])
		rock.rotation.y = rng.randf_range(-0.6, 0.6)
		if i % 2 == 0:
			var moss := _ellipsoid(self, Vector3(x - 0.025, FLOOR_Y + size.y * 1.05, z - 0.018), Vector3(size.x * 0.52, 0.025, size.z * 0.42), Color(0.23, 0.43, 0.20))
			moss.name = "VelvetGreenMoss"
	_create_rock_cave()
	_create_ferns()
	_create_fallen_branch()
	_create_creekbed_pebbles()
	_create_ripples()
	_create_mist()
	_create_aquarium_glass()
	stream_light = OmniLight3D.new()
	stream_light.name = "CoolValleyLight"
	stream_light.position = Vector3(-0.8, 1.45, 0.3)
	stream_light.light_color = Color(0.67, 0.84, 0.87)
	stream_light.light_energy = 0.86
	stream_light.omni_range = 6.2
	add_child(stream_light)
	var sunbeam := _ellipsoid(self, Vector3(-1.55, -0.405, -0.02), Vector3(0.46, 0.008, 0.32), Color(0.80, 0.87, 0.53, 0.18))
	var sunbeam_material := sunbeam.material_override as StandardMaterial3D
	sunbeam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sunbeam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _create_aquarium_glass() -> void:
	var glass_color := Color(0.50, 0.75, 0.78, 0.075)
	var panes: Array[MeshInstance3D] = [
		_box(self, Vector3(0.0, 0.36, 1.72), Vector3(5.05, 1.92, 0.018), glass_color, "FrontAquariumGlass"),
		_box(self, Vector3(0.0, 0.36, -1.72), Vector3(5.05, 1.92, 0.018), glass_color, "RearAquariumGlass"),
		_box(self, Vector3(-2.52, 0.36, 0.0), Vector3(0.018, 1.92, 3.44), glass_color, "LeftAquariumGlass"),
		_box(self, Vector3(2.52, 0.36, 0.0), Vector3(0.018, 1.92, 3.44), glass_color, "RightAquariumGlass")
	]
	for pane in panes:
		var material := _material(glass_color, 0.12)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.metallic = 0.035
		pane.material_override = material
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame := Color(0.16, 0.24, 0.22)
	for x in [-2.52, 2.52]:
		for z in [-1.72, 1.72]:
			_rod(self, Vector3(x, -0.60, z), Vector3(x, 1.32, z), 0.024, frame)
	for y in [-0.60, 1.32]:
		for z in [-1.72, 1.72]:
			_rod(self, Vector3(-2.52, y, z), Vector3(2.52, y, z), 0.023, frame)
		for x in [-2.52, 2.52]:
			_rod(self, Vector3(x, y, -1.72), Vector3(x, y, 1.72), 0.023, frame)


func _create_rock_cave() -> void:
	var cave_center := Vector3(-1.28, FLOOR_Y, -0.78)
	_ellipsoid(self, cave_center + Vector3(-0.32, 0.13, 0.0), Vector3(0.48, 0.30, 0.42), ROCK_COLORS[2])
	_ellipsoid(self, cave_center + Vector3(0.32, 0.13, 0.0), Vector3(0.48, 0.32, 0.42), ROCK_COLORS[0])
	_ellipsoid(self, cave_center + Vector3(0.0, 0.36, -0.04), Vector3(0.72, 0.24, 0.48), ROCK_COLORS[1])
	var opening := _ellipsoid(self, cave_center + Vector3(0.0, 0.035, 0.28), Vector3(0.34, 0.15, 0.035), Color(0.045, 0.055, 0.047))
	opening.name = "MoistRockCreviceHide"
	for i in range(7):
		var moss := _ellipsoid(self, cave_center + Vector3(-0.46 + float(i) * 0.15, 0.39, 0.04), Vector3(0.10, 0.035, 0.16), Color(0.18, 0.38 + float(i % 2) * 0.05, 0.18))
		moss.rotation.y = float(i) * 0.32


func _create_ferns() -> void:
	for fern_index in range(7):
		var side := -1.0 if fern_index % 2 == 0 else 1.0
		var base := Vector3(-1.78 + float(fern_index) * 0.59, FLOOR_Y, side * rng.randf_range(0.98, 1.30))
		var height := rng.randf_range(0.42, 0.68)
		_rod(self, base, base + Vector3(0.0, height, 0.0), 0.016, Color(0.25, 0.39, 0.19))
		for frond in range(5):
			var t := float(frond) / 4.0
			var y := height * (0.28 + t * 0.58)
			var spread := 0.20 * (1.0 - t * 0.42)
			for direction in [-1.0, 1.0]:
				var end := base + Vector3(direction * spread, y + 0.06, float(frond - 2) * 0.025)
				var leaf := _ellipsoid(self, end, Vector3(0.14, 0.026, 0.042), Color(0.22, 0.43, 0.20).lightened(float(frond % 2) * 0.08))
				leaf.rotation.z = -direction * 0.48
				leaf.rotation.y = direction * 0.24
		var fiddlehead := _ellipsoid(self, base + Vector3(0.015, height + 0.015, 0.0), Vector3(0.055, 0.055, 0.055), Color(0.30, 0.52, 0.23))
		fiddlehead.name = "FernFiddlehead"


func _create_fallen_branch() -> void:
	_rod(self, Vector3(0.45, FLOOR_Y + 0.04, -1.17), Vector3(1.84, FLOOR_Y + 0.25, -0.91), 0.09, Color(0.28, 0.21, 0.14))
	_rod(self, Vector3(0.98, FLOOR_Y + 0.14, -1.05), Vector3(0.77, FLOOR_Y + 0.48, -0.93), 0.05, Color(0.34, 0.24, 0.15))
	for i in range(4):
		var lichen := _ellipsoid(self, Vector3(0.72 + float(i) * 0.25, FLOOR_Y + 0.22 + float(i) * 0.025, -0.96), Vector3(0.09, 0.025, 0.055), Color(0.48, 0.56, 0.34))
		lichen.rotation.y = float(i) * 0.4


func _create_creekbed_pebbles() -> void:
	for i in range(38):
		var pebble := _ellipsoid(self, Vector3(rng.randf_range(-2.15, 2.15), -0.30, rng.randf_range(-0.31, 0.49)), Vector3(rng.randf_range(0.035, 0.10), 0.025, rng.randf_range(0.035, 0.085)), ROCK_COLORS[i % ROCK_COLORS.size()].lightened(0.12))
		pebble.name = "RoundedCreekPebble"


func _create_ripples() -> void:
	for i in range(12):
		var ripple := _ellipsoid(self, Vector3(-2.1 + float(i) * 0.36, -0.228, rng.randf_range(-0.25, 0.38)), Vector3(rng.randf_range(0.06, 0.13), 0.005, 0.012), Color(0.72, 0.92, 0.92, 0.43))
		var material := ripple.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ripples.append({"root": ripple, "phase": rng.randf_range(0.0, TAU), "origin_z": ripple.position.z})


func _create_mist() -> void:
	for i in range(9):
		var mote := _ellipsoid(self, Vector3(rng.randf_range(-1.75, 1.70), rng.randf_range(-0.16, 0.30), rng.randf_range(-0.12, 0.32)), Vector3(0.032, 0.042, 0.032), Color(0.70, 0.84, 0.88, 0.10))
		mote.name = "CoolCreekMist"
		var material := mote.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mist_motes.append({"root": mote, "origin": mote.position, "phase": rng.randf_range(0.0, TAU)})
	_update_mist()


func _update_mist() -> void:
	var alpha := lerpf(0.025, 0.15, inverse_lerp(55.0, 100.0, humidity))
	for record in mist_motes:
		var mote: MeshInstance3D = record["root"]
		if mote != null and is_instance_valid(mote):
			var material := mote.material_override as StandardMaterial3D
			material.albedo_color = Color(0.70, 0.84, 0.88, alpha)


func _create_salamander(index: int) -> void:
	var root := Node3D.new()
	root.name = "ColorfulCreekSalamander_%02d" % (index + 1)
	root.position = Vector3(-0.95 + float(index) * 0.80, FLOOR_Y, -0.12 + float(index % 2) * 0.48)
	root.rotation.y = -0.12 + float(index) * 0.21
	add_child(root)
	var body := Node3D.new()
	body.name = "LivingBody"
	root.add_child(body)
	var body_color: Color = [Color(0.075, 0.082, 0.072), Color(0.12, 0.075, 0.055), Color(0.055, 0.08, 0.085)][index % 3]
	var marking_color: Color = MARKING_COLORS[index % MARKING_COLORS.size()]
	var trunk := MeshInstance3D.new()
	trunk.name = "SmoothTaperedTrunk"
	trunk.mesh = _tapered_tube_mesh(
		PackedFloat32Array([-0.34, -0.27, -0.17, -0.04, 0.10, 0.22, 0.32, 0.39]),
		PackedFloat32Array([0.14, 0.145, 0.15, 0.15, 0.15, 0.155, 0.16, 0.16]),
		PackedFloat32Array([0.065, 0.115, 0.15, 0.17, 0.17, 0.15, 0.13, 0.11]),
		PackedFloat32Array([0.052, 0.072, 0.09, 0.10, 0.10, 0.092, 0.083, 0.070])
	)
	var trunk_material := _material(body_color, 0.42)
	trunk_material.metallic = 0.015
	trunk.material_override = trunk_material
	body.add_child(trunk)
	var head := _skin_ellipsoid(body, Vector3(0.0, 0.18, 0.44), Vector3(0.17, 0.105, 0.19), body_color)
	head.name = "BroadSalamanderHead"
	_skin_ellipsoid(body, Vector3(0.0, 0.227, 0.48), Vector3(0.095, 0.025, 0.105), marking_color)
	for side in [-1.0, 1.0]:
		var eye_socket := _skin_ellipsoid(body, Vector3(side * 0.115, 0.232, 0.49), Vector3(0.052, 0.050, 0.052), marking_color.darkened(0.13))
		eye_socket.name = "AmberEyeRing"
		var eye := _skin_ellipsoid(body, Vector3(side * 0.132, 0.24, 0.51), Vector3(0.031, 0.032, 0.034), Color(0.045, 0.032, 0.020))
		_skin_ellipsoid(body, Vector3(side * 0.142, 0.252, 0.531), Vector3(0.010, 0.011, 0.010), Color(1.0, 0.92, 0.68))
		_skin_ellipsoid(body, Vector3(side * 0.046, 0.165, 0.592), Vector3(0.010, 0.007, 0.007), Color(0.025, 0.025, 0.022))
		for spot_index in range(4):
			var z := 0.25 - float(spot_index) * 0.16
			var spot := _skin_ellipsoid(body, Vector3(side * (0.165 - float(spot_index % 2) * 0.018), 0.205, z), Vector3(0.040 + float(spot_index % 2) * 0.008, 0.025, 0.052), MARKING_COLORS[(index + spot_index) % MARKING_COLORS.size()])
			spot.rotation.z = side * 0.16
			spot.name = "IrregularBrightSkinPatch"
	for spot_index in range(5):
		var z := 0.22 - float(spot_index) * 0.13
		var spot := _skin_ellipsoid(body, Vector3(0.0, 0.253, z), Vector3(0.046, 0.018, 0.048), MARKING_COLORS[(index + spot_index + 1) % MARKING_COLORS.size()])
		spot.rotation.y = float(spot_index % 2) * 0.3
	var legs: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		for leg_index in range(2):
			var leg := Node3D.new()
			leg.name = "Leg_%s_%d" % ["L" if side < 0.0 else "R", leg_index]
			var hip_z := 0.24 if leg_index == 0 else -0.23
			var hip := Vector3(side * 0.15, 0.12, hip_z)
			var elbow := Vector3(side * 0.29, 0.07, hip_z + (0.10 if leg_index == 0 else -0.11))
			var foot := Vector3(side * 0.31, 0.012, hip_z + (0.20 if leg_index == 0 else -0.21))
			leg.position = hip
			body.add_child(leg)
			_rod(leg, Vector3.ZERO, elbow - hip, 0.034, body_color.lightened(0.14))
			_ellipsoid(leg, elbow - hip, Vector3(0.043, 0.038, 0.043), body_color.lightened(0.18))
			_rod(leg, elbow - hip, foot - hip, 0.024, body_color.lightened(0.16))
			for toe_index in range(3):
				var toe_side := float(toe_index - 1)
				var toe_start := foot - hip
				var toe_end := toe_start + Vector3(side * toe_side * 0.045, -0.008, 0.045 + absf(toe_side) * 0.018)
				_rod(leg, toe_start, toe_end, 0.009, marking_color.darkened(0.18))
			legs.append(leg)
	var tail := Node3D.new()
	tail.name = "FlexingTaperedTail"
	tail.position = Vector3(0.0, 0.14, -0.30)
	body.add_child(tail)
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.name = "RoundedTailTip"
	tail_mesh.mesh = _tapered_tube_mesh(
		PackedFloat32Array([-0.68, -0.58, -0.47, -0.36, -0.25, -0.14, -0.04, 0.06]),
		PackedFloat32Array([-0.036, -0.030, -0.023, -0.016, -0.009, -0.004, 0.0, 0.0]),
		PackedFloat32Array([0.012, 0.033, 0.050, 0.067, 0.082, 0.096, 0.104, 0.095]),
		PackedFloat32Array([0.010, 0.022, 0.033, 0.043, 0.052, 0.062, 0.067, 0.061])
	)
	tail_mesh.material_override = _material(body_color, 0.42)
	tail.add_child(tail_mesh)
	for segment in range(1, 7, 2):
		var tail_z := -0.14 * float(segment)
		var tail_y := 0.062 - float(segment) * 0.006
		_skin_ellipsoid(tail, Vector3(0.0, tail_y, tail_z), Vector3(0.034, 0.012, 0.042), MARKING_COLORS[(index + segment) % MARKING_COLORS.size()])
	salamanders.append({
		"root": root,
		"body": body,
		"tail": tail,
		"legs": legs,
		"state": "젖은 바위 탐색" if index != 0 else "바위 그늘에서 휴식",
		"target": _random_shore_target(),
		"timer": rng.randf_range(1.0, 4.0),
		"phase": float(index) * 1.8,
		"speed": 0.19 + float(index % 3) * 0.025,
	})


func simulate(delta: float) -> void:
	var dt := minf(delta, 0.08)
	clock += dt
	for ripple_record in ripples:
		var ripple: Node3D = ripple_record["root"]
		if ripple == null or not is_instance_valid(ripple):
			continue
		ripple.visible = flow_enabled
		if flow_enabled:
			ripple.position.x += dt * 0.42
			if ripple.position.x > 2.28:
				ripple.position.x = -2.25
			ripple.position.z = float(ripple_record["origin_z"]) + sin(clock * 1.7 + float(ripple_record["phase"])) * 0.018
	for mist_record in mist_motes:
		var mote: Node3D = mist_record["root"]
		var origin: Vector3 = mist_record["origin"]
		mote.position = origin + Vector3(sin(clock * 0.52 + float(mist_record["phase"])) * 0.025, sin(clock * 0.8 + float(mist_record["phase"])) * 0.035, 0.0)
	for record_index in range(salamanders.size()):
		var record: Dictionary = salamanders[record_index]
		var root: Node3D = record["root"]
		var body: Node3D = record["body"]
		var tail: Node3D = record["tail"]
		if root == null or not is_instance_valid(root):
			continue
		record["timer"] = maxf(0.0, float(record["timer"]) - dt)
		var state := String(record["state"])
		if record["timer"] <= 0.0:
			if state == "바위 그늘에서 휴식":
				record["state"] = "젖은 바위 탐색"
				record["target"] = _random_shore_target()
				record["timer"] = rng.randf_range(3.0, 6.5)
			elif state == "바위틈에 숨음":
				record["state"] = "바위 그늘에서 휴식"
				record["timer"] = rng.randf_range(3.5, 7.0)
			else:
				if rng.randf() < 0.24:
					record["state"] = "바위틈에 숨음"
					record["target"] = _hide_target(record_index)
					record["timer"] = rng.randf_range(2.5, 5.5)
				else:
					record["state"] = "젖은 바위 탐색"
					record["target"] = _random_shore_target()
					record["timer"] = rng.randf_range(3.0, 6.0)
		state = String(record["state"])
		var target: Vector3 = record["target"]
		var moving := root.position.distance_to(target) > 0.035
		if moving:
			var direction := target - root.position
			root.position = root.position.move_toward(target, float(record["speed"]) * dt)
			root.rotation.y = lerp_angle(root.rotation.y, atan2(direction.x, direction.z), dt * 3.2)
			for leg_index in range(record["legs"].size()):
				var leg: Node3D = record["legs"][leg_index]
				leg.rotation.z = sin(clock * 8.0 + float(record["phase"]) + float(leg_index) * PI * 0.5) * 0.12
		else:
			for leg in record["legs"]:
				(leg as Node3D).rotation.z = move_toward((leg as Node3D).rotation.z, 0.0, dt * 0.8)
		body.position.y = sin(clock * 2.2 + float(record["phase"])) * 0.012
		tail.rotation.y = sin(clock * 2.4 + float(record["phase"])) * (0.20 if moving else 0.08)
		tail.rotation.x = sin(clock * 1.8 + float(record["phase"])) * 0.035


func add_salamander() -> bool:
	if salamanders.size() >= SALAMANDER_LIMIT:
		return false
	_create_salamander(salamanders.size())
	return true


func encourage_activity() -> void:
	for record in salamanders:
		record["state"] = "젖은 바위 탐색"
		record["target"] = _random_shore_target()
		record["timer"] = rng.randf_range(4.0, 7.0)


func retreat_to_hide() -> void:
	for i in range(salamanders.size()):
		var record: Dictionary = salamanders[i]
		record["state"] = "바위틈에 숨음"
		record["target"] = _hide_target(i)
		record["timer"] = rng.randf_range(2.5, 5.5)


func toggle_flow() -> bool:
	flow_enabled = not flow_enabled
	return flow_enabled


func change_temperature(amount: float) -> float:
	temperature = clampf(temperature + amount, 12.0, 26.0)
	return temperature


func change_humidity(amount: float) -> float:
	humidity = clampf(humidity + amount, 55.0, 100.0)
	_update_mist()
	return humidity


func salamander_count() -> int:
	return salamanders.size()


func activity_status() -> String:
	var moving_count := 0
	var hiding_count := 0
	for record in salamanders:
		var state := String(record["state"])
		if state == "젖은 바위 탐색":
			moving_count += 1
		elif state == "바위틈에 숨음" or state == "바위 그늘에서 휴식":
			hiding_count += 1
		if moving_count > 0 and hiding_count > 0:
			return "물가를 살피며 바위틈에서 번갈아 휴식"
	if moving_count > 0:
		return "젖은 바위를 따라 천천히 이동"
	return "바위 그늘과 틈에서 휴식"


func focus_position() -> Vector3:
	if salamanders.is_empty():
		return Vector3(-0.15, -0.10, 0.0)
	var root: Node3D = salamanders[0]["root"]
	return root.position + Vector3(0.0, 0.16, 0.0)


func _random_shore_target() -> Vector3:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	return Vector3(rng.randf_range(-1.75, 1.75), FLOOR_Y, side * rng.randf_range(0.70, 1.20))


func _hide_target(index: int = -1) -> Vector3:
	var offset := float(maxi(index, 0) % 3) * 0.11
	return Vector3(-1.30 + offset, FLOOR_Y, -0.49 + offset * 0.3)


func _box(parent: Node3D, position_value: Vector3, dimensions: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.position = position_value
	item.material_override = _material(color)
	parent.add_child(item)
	return item


func _material(color: Color, roughness: float = 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _ellipsoid(parent: Node3D, position_value: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 14
	mesh.rings = 9
	item.mesh = mesh
	item.position = position_value
	item.scale = size
	item.material_override = _material(color)
	parent.add_child(item)
	return item


func _skin_ellipsoid(parent: Node3D, position_value: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := _ellipsoid(parent, position_value, size, color)
	var material := item.material_override as StandardMaterial3D
	material.roughness = 0.42
	material.metallic = 0.015
	return item


func _tapered_tube_mesh(z_positions: PackedFloat32Array, center_y: PackedFloat32Array, radius_x: PackedFloat32Array, radius_y: PackedFloat32Array, radial_segments: int = 20) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(z_positions.size()):
		for side in range(radial_segments + 1):
			var angle := TAU * float(side) / float(radial_segments)
			var point := Vector3(cos(angle) * radius_x[ring], center_y[ring] + sin(angle) * radius_y[ring], z_positions[ring])
			tool.set_uv(Vector2(float(side) / float(radial_segments), float(ring) / float(z_positions.size() - 1)))
			tool.add_vertex(point)
	for ring in range(z_positions.size() - 1):
		for side in range(radial_segments):
			var a := ring * (radial_segments + 1) + side
			var b := a + 1
			var d := (ring + 1) * (radial_segments + 1) + side
			var c := d + 1
			tool.add_index(a)
			tool.add_index(b)
			tool.add_index(c)
			tool.add_index(a)
			tool.add_index(c)
			tool.add_index(d)
	tool.generate_normals()
	return tool.commit()


func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = maxf(0.001, start.distance_to(end))
	mesh.radial_segments = 8
	item.mesh = mesh
	item.position = (start + end) * 0.5
	item.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	item.material_override = _material(color, 0.84)
	parent.add_child(item)
