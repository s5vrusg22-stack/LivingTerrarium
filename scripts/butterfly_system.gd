extends Node3D

const BUTTERFLY_LIMIT := 8
const FLOWER_LIMIT := 24
const FLOOR_Y := -0.52

var clock := 0.0
var temperature := 25.0
var daylight := true
var wind_enabled := true
var wind_strength := 0.35
var pollination_count := 0
var butterflies: Array[Dictionary] = []
var flowers: Array[Dictionary] = []
var pollen_motes: Array[Dictionary] = []
var garden_light: OmniLight3D
var rng := RandomNumberGenerator.new()

const FLOWER_COLORS := [
	Color(0.93, 0.34, 0.39),
	Color(0.98, 0.68, 0.19),
	Color(0.76, 0.43, 0.88),
	Color(0.95, 0.81, 0.37),
	Color(0.42, 0.73, 0.88)
]


func _ready() -> void:
	rng.randomize()
	_create_garden()
	for i in range(8):
		_create_flower(Vector3(-1.62 + float(i % 4) * 1.08, FLOOR_Y, -0.92 if i < 4 else 0.92), i % FLOWER_COLORS.size())
	for i in range(3):
		_create_butterfly(i)
	_create_pollen_motes()
	_update_light()


func _create_garden() -> void:
	var bed := MeshInstance3D.new()
	bed.name = "ButterflyGardenSoilBed"
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(4.35, 0.12, 2.95)
	bed.mesh = bed_mesh
	bed.position = Vector3(0, -0.57, 0)
	bed.material_override = _material(Color(0.22, 0.27, 0.13), 0.98)
	add_child(bed)
	for x in [-2.08, 2.08]:
		_rod(self, Vector3(x, FLOOR_Y, -1.45), Vector3(x, FLOOR_Y + 0.78, -1.45), 0.022, Color(0.31, 0.25, 0.17))
		_rod(self, Vector3(x, FLOOR_Y, 1.45), Vector3(x, FLOOR_Y + 0.78, 1.45), 0.022, Color(0.31, 0.25, 0.17))
	for z in [-1.45, 1.45]:
		_rod(self, Vector3(-2.08, FLOOR_Y + 0.78, z), Vector3(2.08, FLOOR_Y + 0.78, z), 0.022, Color(0.31, 0.25, 0.17))
	for i in range(11):
		var x := -1.88 + float(i) * 0.37
		var tuft := _ellipsoid(self, Vector3(x, FLOOR_Y + 0.04, 0.0), Vector3(0.20, 0.035, 0.12), Color(0.23, 0.39, 0.18))
		tuft.rotation.y = float(i) * 0.44
	for i in range(5):
		var stone := _ellipsoid(self, Vector3(-1.55 + float(i) * 0.76, FLOOR_Y + 0.045, 0.0), Vector3(0.22, 0.045, 0.13), Color(0.40, 0.39, 0.31))
		stone.rotation.y = float(i) * 0.31
	garden_light = OmniLight3D.new()
	garden_light.name = "WarmGardenSunlight"
	garden_light.position = Vector3(-0.6, 1.55, 0.6)
	garden_light.light_color = Color(1.0, 0.88, 0.66)
	garden_light.light_energy = 0.75
	garden_light.omni_range = 5.5
	add_child(garden_light)
	var sun_patch := _ellipsoid(self, Vector3(-1.45, -0.509, 0.0), Vector3(0.62, 0.006, 0.48), Color(0.92, 0.72, 0.35, 0.22))
	sun_patch.name = "WarmSunPatch"
	var sun_mat := sun_patch.material_override as StandardMaterial3D
	sun_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _create_flower(base: Vector3, palette_index: int) -> void:
	if flowers.size() >= FLOWER_LIMIT:
		return
	var flower_root := Node3D.new()
	flower_root.name = "NectarFlower_%02d" % flowers.size()
	flower_root.position = base
	add_child(flower_root)
	var height := rng.randf_range(0.38, 0.62)
	var bloom := Vector3(0.0, height, 0.0)
	var color: Color = FLOWER_COLORS[palette_index % FLOWER_COLORS.size()]
	var stem_color := Color(0.18, 0.38, 0.17)
	_rod(flower_root, Vector3.ZERO, bloom, 0.018, stem_color)
	for leaf_index in range(3):
		var side := -1.0 if leaf_index % 2 == 0 else 1.0
		var y := 0.14 + float(leaf_index) * 0.105
		var leaf := _ellipsoid(flower_root, Vector3(side * (0.055 + float(leaf_index) * 0.018), y, 0.0), Vector3(0.11, 0.024, 0.043), Color(0.24, 0.48, 0.20))
		leaf.rotation.z = side * -0.42
		leaf.rotation.y = side * 0.28
	var center := _ellipsoid(flower_root, bloom, Vector3(0.055, 0.045, 0.055), Color(0.98, 0.76, 0.22))
	center.name = "NectarCup"
	for petal_index in range(8):
		var angle := TAU * float(petal_index) / 8.0
		var petal := _ellipsoid(flower_root, bloom + Vector3(cos(angle) * 0.080, sin(angle) * 0.058, 0.0), Vector3(0.052, 0.095, 0.018), color.lightened(0.08))
		petal.rotation.z = -angle + PI * 0.5
		petal.rotation.y = sin(angle) * 0.12
	flowers.append({"root": flower_root, "base": base, "bloom": base + bloom, "nectar": rng.randf_range(0.72, 1.0), "color": color})


func _create_butterfly(index: int) -> void:
	var root := Node3D.new()
	root.name = "Swallowtail_%02d" % (index + 1)
	root.position = Vector3(-0.46 + float(index) * 0.42, 0.20 + float(index % 2) * 0.18, -0.15 + float(index % 3) * 0.22)
	add_child(root)
	var wing_pivots: Array[Node3D] = []
	var body_dark := Color(0.12, 0.10, 0.075)
	var body_gold := Color(0.89, 0.69, 0.29)
	_ellipsoid(root, Vector3(0, -0.09, 0), Vector3(0.045, 0.19, 0.046), body_dark)
	_ellipsoid(root, Vector3(0, 0.045, 0), Vector3(0.066, 0.095, 0.068), Color(0.17, 0.13, 0.09))
	_ellipsoid(root, Vector3(0, 0.165, 0), Vector3(0.078, 0.071, 0.072), body_gold)
	for segment in range(5):
		var y := -0.21 + float(segment) * 0.055
		_rod(root, Vector3(-0.035, y, 0), Vector3(0.035, y, 0), 0.006, Color(0.65, 0.48, 0.22))
	for side in [-1.0, 1.0]:
		var eye := _ellipsoid(root, Vector3(side * 0.058, 0.178, 0.045), Vector3(0.022, 0.026, 0.022), Color(0.045, 0.035, 0.025))
		eye.name = "CompoundEye"
		var antenna_base := Vector3(side * 0.035, 0.205, 0.0)
		var antenna_mid := Vector3(side * 0.095, 0.295, 0.012)
		var antenna_tip := Vector3(side * 0.15, 0.32, 0.018)
		_rod(root, antenna_base, antenna_mid, 0.0045, body_dark)
		_rod(root, antenna_mid, antenna_tip, 0.004, body_dark)
		for leg_index in range(3):
			var z := -0.045 + float(leg_index) * 0.048
			_rod(root, Vector3(side * 0.035, 0.005, z), Vector3(side * 0.12, -0.095, z + 0.015), 0.005, body_dark)
			_rod(root, Vector3(side * 0.12, -0.095, z + 0.015), Vector3(side * 0.15, -0.14, z + 0.025), 0.004, body_gold)
		var fore := Node3D.new()
		fore.name = "ForewingPivot_%d" % int(side)
		fore.position = Vector3(side * 0.035, 0.07, 0.018)
		root.add_child(fore)
		_build_wing(fore, side, true)
		wing_pivots.append(fore)
		var hind := Node3D.new()
		hind.name = "HindwingPivot_%d" % int(side)
		hind.position = Vector3(side * 0.035, -0.015, -0.012)
		root.add_child(hind)
		_build_wing(hind, side, false)
		wing_pivots.append(hind)
	butterflies.append({
		"root": root,
		"wings": wing_pivots,
		"state": "비행",
		"timer": 0.0,
		"target": Vector3(-1.0 + float(index) * 0.7, 0.35, 0.0),
		"phase": float(index) * 2.1,
		"speed": 0.28 + 0.04 * float(index % 3),
		"flower": -1
	})


func _build_wing(parent: Node3D, side: float, forewing: bool) -> void:
	var outline: Array[Vector2]
	if forewing:
		outline = [Vector2(0.0, 0.0), Vector2(0.10, 0.12), Vector2(0.22, 0.25), Vector2(0.38, 0.23), Vector2(0.36, 0.14), Vector2(0.33, 0.06), Vector2(0.29, -0.02), Vector2(0.20, -0.11), Vector2(0.08, -0.10), Vector2(0.01, -0.045)]
	else:
		outline = [Vector2(0.0, 0.015), Vector2(0.12, 0.03), Vector2(0.27, -0.015), Vector2(0.34, -0.10), Vector2(0.25, -0.17), Vector2(0.22, -0.31), Vector2(0.15, -0.25), Vector2(0.10, -0.33), Vector2(0.07, -0.23), Vector2(0.0, -0.12)]
	var wing_mesh := _wing_surface(outline, side)
	var surface := MeshInstance3D.new()
	surface.name = "ForewingMembrane" if forewing else "HindwingMembrane"
	surface.mesh = wing_mesh
	var base_color := Color(0.91, 0.73, 0.31) if forewing else Color(0.86, 0.70, 0.28)
	surface.material_override = _material(base_color, 0.9)
	(surface.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(surface)
	var vein_color := Color(0.17, 0.12, 0.075)
	for vein_index in range(6):
		var t := float(vein_index) / 5.0
		var end_x := (0.13 + t * 0.21) * side
		var end_y := (0.20 - t * 0.30) if forewing else (-0.02 - t * 0.22)
		_rod(parent, Vector3(side * 0.018, 0.0, 0.006), Vector3(end_x, end_y, 0.008), 0.0036, vein_color)
	if forewing:
		for stripe in range(4):
			var x := side * (0.12 + float(stripe) * 0.054)
			var y := 0.135 - float(stripe) * 0.052
			_rod(parent, Vector3(x, y, 0.010), Vector3(x + side * 0.055, y - 0.035, 0.010), 0.008, Color(0.20, 0.14, 0.07))
	else:
		_add_wing_spot(parent, Vector3(side * 0.22, -0.22, 0.014), Vector3(0.050, 0.035, 0.008), Color(0.22, 0.44, 0.62))
		_add_wing_spot(parent, Vector3(side * 0.22, -0.22, 0.020), Vector3(0.023, 0.020, 0.007), Color(0.93, 0.48, 0.22))
		_add_wing_spot(parent, Vector3(side * 0.29, -0.115, 0.014), Vector3(0.027, 0.018, 0.007), Color(0.91, 0.84, 0.55))
		_rod(parent, Vector3(side * 0.22, -0.19, 0.009), Vector3(side * 0.22, -0.31, 0.009), 0.003, vein_color)


func _wing_surface(outline: Array[Vector2], side: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(outline.size()):
		var a := Vector3(0.018 * side, -0.015, 0.0)
		var b := Vector3(outline[i].x * side, outline[i].y, 0.0)
		var c := Vector3(outline[(i + 1) % outline.size()].x * side, outline[(i + 1) % outline.size()].y, 0.0)
		vertices.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK]))
		uvs.append_array(PackedVector2Array([Vector2(0.05, 0.5), Vector2(outline[i].x * 2.2, 0.5 - outline[i].y * 1.8), Vector2(outline[(i + 1) % outline.size()].x * 2.2, 0.5 - outline[(i + 1) % outline.size()].y * 1.8)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_wing_spot(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var spot := _ellipsoid(parent, pos, size, color)
	spot.name = "WingEyespot"


func _create_pollen_motes() -> void:
	for i in range(16):
		var mote := _ellipsoid(self, Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-0.22, 0.72), rng.randf_range(-1.15, 1.15)), Vector3(0.012, 0.012, 0.012), Color(1.0, 0.83, 0.34))
		var material := mote.material_override as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color(0.8, 0.48, 0.13)
		pollen_motes.append({"root": mote, "phase": rng.randf_range(0.0, TAU), "origin": mote.position})


func simulate(delta: float) -> void:
	var dt := minf(delta, 0.08)
	clock += dt
	for i in range(butterflies.size()):
		var record: Dictionary = butterflies[i]
		var root: Node3D = record["root"]
		var state := String(record["state"])
		var phase := float(record["phase"])
		var wings: Array[Node3D] = record["wings"]
		if not daylight:
			state = "휴식"
			root.position.y = move_toward(root.position.y, 0.12, dt * 0.4)
		elif temperature < 17.0 or temperature > 35.0:
			state = "온도 대기"
			root.position.y = move_toward(root.position.y, 0.14, dt * 0.25)
		else:
			var timer := float(record["timer"])
			if state == "흡밀" or state == "휴식" or state == "온도 대기":
				timer -= dt
				if timer <= 0.0:
					if state == "흡밀":
						pollination_count += 1
						state = "휴식"
						timer = rng.randf_range(1.0, 2.8)
					else:
						state = "비행"
						_select_flower_target(record)
						timer = rng.randf_range(5.0, 9.0)
			else:
				var target: Vector3 = record["target"]
				var sway := Vector3(sin(clock * 2.2 + phase) * 0.07, sin(clock * 3.0 + phase) * 0.065, cos(clock * 1.7 + phase) * 0.06)
				var destination := target + sway
				var delta_to_target := destination - root.position
				if delta_to_target.length() > 0.015:
					root.position = root.position.move_toward(destination, dt * float(record["speed"]))
					root.rotation.y = lerp_angle(root.rotation.y, atan2(-delta_to_target.x, -delta_to_target.z), dt * 2.0)
					state = "비행"
				else:
					var flower_index := int(record["flower"])
					if flower_index >= 0 and flower_index < flowers.size() and float(flowers[flower_index]["nectar"]) > 0.02:
						state = "흡밀"
						timer = rng.randf_range(2.8, 4.8)
						flowers[flower_index]["nectar"] = maxf(0.0, float(flowers[flower_index]["nectar"]) - 0.12)
					else:
						state = "휴식"
						timer = rng.randf_range(1.0, 2.4)
			root.position.x = clampf(root.position.x, -1.82, 1.82)
			root.position.y = clampf(root.position.y, -0.08, 1.05)
			root.position.z = clampf(root.position.z, -1.18, 1.18)
			record["timer"] = timer
		root.position.y += sin(clock * 4.0 + phase) * dt * (0.018 if state == "비행" else 0.003)
		var flap := sin(clock * (8.5 if state == "비행" else 2.2) + phase) * (0.68 if state == "비행" else 0.08)
		for wing_index in range(wings.size()):
			var wing: Node3D = wings[wing_index]
			var side := -1.0 if String(wing.name).ends_with("-1") else 1.0
			wing.rotation.z = flap * side
			wing.rotation.x = sin(clock * 5.0 + phase + float(wing_index) * 0.4) * 0.035
		record["state"] = state
		record["phase"] = phase
		butterflies[i] = record
	for mote_record in pollen_motes:
		var mote: Node3D = mote_record["root"]
		var phase := float(mote_record["phase"])
		var origin: Vector3 = mote_record["origin"]
		mote.position = origin + Vector3(sin(clock * 0.46 + phase) * 0.12, sin(clock * 0.9 + phase) * 0.08, cos(clock * 0.38 + phase) * 0.12)
	for flower_record in flowers:
		var flower_root: Node3D = flower_record["root"]
		flower_root.rotation.z = sin(clock * 1.4 + flower_root.position.x) * wind_strength * 0.018 if wind_enabled else 0.0


func _select_flower_target(record: Dictionary) -> void:
	var available: Array[int] = []
	for i in range(flowers.size()):
		if float(flowers[i]["nectar"]) > 0.12:
			available.append(i)
	if available.is_empty():
		record["flower"] = -1
		record["target"] = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.1, 0.85), rng.randf_range(-0.9, 0.9))
	else:
		var flower_index: int = available[rng.randi_range(0, available.size() - 1)]
		var flower: Dictionary = flowers[flower_index]
		var bloom: Vector3 = flower["bloom"]
		record["flower"] = flower_index
		record["target"] = bloom + Vector3(0.0, 0.10, 0.0)


func encourage_flight() -> void:
	for record in butterflies:
		record["state"] = "비행"
		record["timer"] = 0.0
		_select_flower_target(record)


func add_butterfly() -> bool:
	if butterflies.size() >= BUTTERFLY_LIMIT:
		return false
	_create_butterfly(butterflies.size())
	return true


func add_flower() -> bool:
	if flowers.size() >= FLOWER_LIMIT:
		return false
	var base := Vector3(rng.randf_range(-1.7, 1.7), FLOOR_Y, rng.randf_range(-1.1, 1.1))
	_create_flower(base, rng.randi_range(0, FLOWER_COLORS.size() - 1))
	return true


func refill_nectar() -> void:
	for i in range(flowers.size()):
		flowers[i]["nectar"] = 1.0


func toggle_wind() -> bool:
	wind_enabled = not wind_enabled
	return wind_enabled


func toggle_daylight() -> bool:
	daylight = not daylight
	_update_light()
	return daylight


func change_temperature(amount: float) -> void:
	temperature = clampf(temperature + amount, 12.0, 38.0)


func butterfly_count() -> int:
	return butterflies.size()


func focus_position() -> Vector3:
	if butterflies.is_empty():
		return Vector3(0.0, 0.3, 0.0)
	var root: Node3D = butterflies[0]["root"]
	return root.position + Vector3(0.0, 0.10, 0.0)


func flower_count() -> int:
	return flowers.size()


func nectar_percent() -> int:
	if flowers.is_empty():
		return 0
	var total := 0.0
	for flower in flowers:
		total += float(flower["nectar"])
	return int(round(total / float(flowers.size()) * 100.0))


func activity_status() -> String:
	if not daylight:
		return "밤에 휴식"
	if temperature < 17.0 or temperature > 35.0:
		return "온도 대기"
	var active := 0
	var feeding := 0
	for record in butterflies:
		if String(record["state"]) == "비행":
			active += 1
		elif String(record["state"]) == "흡밀":
			feeding += 1
	if feeding > 0:
		return "꽃에서 흡밀 %d마리" % feeding
	if active > 0:
		return "꽃 사이를 비행 중"
	return "잎에서 휴식"


func _update_light() -> void:
	if garden_light != null:
		garden_light.light_energy = 0.75 if daylight else 0.12
		garden_light.light_color = Color(1.0, 0.88, 0.66) if daylight else Color(0.36, 0.43, 0.74)


func _material(color: Color, roughness: float = 0.72) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _ellipsoid(parent: Node3D, position_value: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 10
	item.mesh = mesh
	item.position = position_value
	item.scale = size
	item.material_override = _material(color)
	parent.add_child(item)
	return item


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
	item.material_override = _material(color, 0.85)
	parent.add_child(item)
