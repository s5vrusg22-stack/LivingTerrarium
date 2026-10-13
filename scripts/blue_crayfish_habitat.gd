extends Node3D
class_name BlueCrayfishHabitat

const CRAYFISH_SCENE: PackedScene = preload("res://assets/models/blue_yabby.glb")

var actor: Node3D
var paused := false
var filter_enabled := true
var is_outside := false
var elapsed := 0.0
var home_position := Vector3(0.0, 0.10, -0.72)
var active_position := Vector3(0.0, 0.10, 0.05)
var bubbles: Array[MeshInstance3D] = []
var bubble_speeds: Array[float] = []
var antenna_pivots: Array[Node3D] = []
var cheliped_pivots: Array[Node3D] = []
var leg_pivots: Array[Node3D] = []
var filter_material: StandardMaterial3D
var aquarium_light: OmniLight3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261012
	_build_tank()
	_build_gravel()
	_build_rocks_and_burrow()
	_build_plants()
	_build_filter()
	_build_crayfish()
	_build_bubbles()
	_build_lighting()


func _process(delta: float) -> void:
	if paused:
		return
	var dt := minf(delta, 0.1)
	elapsed += dt
	if actor != null:
		var target := active_position if is_outside else home_position
		actor.position = actor.position.lerp(target, 1.0 - exp(-dt * 0.72))
		actor.rotation.y = PI + sin(elapsed * 0.55) * 0.035
		actor.position.y = target.y + sin(elapsed * 1.6) * 0.012
		_animate_pivots()
	for i in range(bubbles.size()):
		var bubble := bubbles[i]
		if not is_instance_valid(bubble):
			continue
		bubble.position.y += bubble_speeds[i] * dt
		if bubble.position.y > 3.16:
			bubble.position.y = 0.18 + rng.randf_range(0.0, 0.34)
			bubble.position.x = 3.08 + rng.randf_range(-0.13, 0.13)


func lure_out() -> void:
	is_outside = true


func return_to_burrow() -> void:
	is_outside = false


func toggle_filter() -> void:
	filter_enabled = not filter_enabled
	for bubble in bubbles:
		bubble.visible = filter_enabled
	if aquarium_light != null:
		aquarium_light.light_energy = 1.35 if filter_enabled else 1.05


func toggle_paused() -> void:
	paused = not paused


func status_text() -> String:
	var behavior := "굴 밖을 탐색하는 중" if is_outside else "바위 틈 굴에서 휴식 중"
	if paused:
		behavior = "일시정지 · " + behavior
	return "파란가재: 1마리 | 은신처: 바위 틈 굴\n행동: %s\n여과기: %s | 수조: 맑음" % [behavior, "켜짐" if filter_enabled else "꺼짐"]


func _build_tank() -> void:
	var floor_mat := _material(Color(0.065, 0.105, 0.12), 0.88)
	var back_mat := _material(Color(0.012, 0.043, 0.060), 0.92)
	var glass_mat := _material(Color(0.27, 0.74, 0.82, 0.105), 0.16, 0.32)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim_mat := _material(Color(0.095, 0.19, 0.22), 0.38, 0.48)
	var water_mat := _material(Color(0.28, 0.78, 0.88, 0.16), 0.12, 0.18)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_box("Substrate bed", Vector3(8.5, 0.26, 5.55), Vector3(0.0, -0.18, 0.0), floor_mat)
	_box("Aquarium rear", Vector3(8.5, 3.55, 0.10), Vector3(0.0, 1.62, -2.78), back_mat)
	_box("Water surface", Vector3(8.32, 0.018, 5.32), Vector3(0.0, 3.32, 0.0), water_mat)
	_box("Left glass panel", Vector3(0.035, 3.55, 5.48), Vector3(-4.24, 1.62, 0.0), glass_mat)
	_box("Right glass panel", Vector3(0.035, 3.55, 5.48), Vector3(4.24, 1.62, 0.0), glass_mat)
	_box("Front glass panel", Vector3(8.5, 3.55, 0.025), Vector3(0.0, 1.62, 2.77), glass_mat)
	for x in [-4.25, 4.25]:
		for z in [-2.78, 2.78]:
			_box("Glass corner trim", Vector3(0.075, 3.58, 0.075), Vector3(x, 1.62, z), trim_mat)
	for y in [-0.30, 3.40]:
		_box("Aquarium rim", Vector3(8.62, 0.085, 5.72), Vector3(0.0, y, 0.0), trim_mat)


func _build_gravel() -> void:
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 1.0
	pebble_mesh.height = 1.0
	pebble_mesh.radial_segments = 10
	pebble_mesh.rings = 6
	var pebble_mat := StandardMaterial3D.new()
	pebble_mat.vertex_color_use_as_albedo = true
	pebble_mat.roughness = 0.91
	var pebble_cloud := MultiMesh.new()
	pebble_cloud.transform_format = MultiMesh.TRANSFORM_3D
	pebble_cloud.use_colors = true
	pebble_cloud.mesh = pebble_mesh
	var count := 620
	pebble_cloud.instance_count = count
	for i in range(count):
		var x := rng.randf_range(-4.04, 4.04)
		var z := rng.randf_range(-2.58, 2.58)
		var sx := rng.randf_range(0.025, 0.085)
		var sy := rng.randf_range(0.018, 0.052)
		var sz := rng.randf_range(0.025, 0.083)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2)))
		basis = basis.scaled(Vector3(sx, sy, sz))
		pebble_cloud.set_instance_transform(i, Transform3D(basis, Vector3(x, -0.035 + sy * 0.25, z)))
		var color := Color(0.26, 0.28, 0.27).lerp(Color(0.72, 0.61, 0.43), rng.randf())
		if rng.randf() < 0.42:
			color = Color(0.105, 0.15, 0.17).lerp(Color(0.43, 0.49, 0.48), rng.randf())
		pebble_cloud.set_instance_color(i, color)
	var pebbles := MultiMeshInstance3D.new()
	pebbles.name = "Fine river gravel"
	pebbles.multimesh = pebble_cloud
	pebbles.material_override = pebble_mat
	add_child(pebbles)


func _build_rocks_and_burrow() -> void:
	var cave_mat := _material(Color(0.004, 0.012, 0.016), 1.0)
	var dark := _sphere("Burrow entrance", Vector3(0.0, 0.50, -2.47), Vector3(0.77, 0.55, 0.055), cave_mat)
	dark.rotation.x = -0.10
	var stones := [
		[Vector3(-1.10, 0.16, -1.86), Vector3(0.88, 0.66, 0.62), Color(0.21, 0.24, 0.22)],
		[Vector3(1.05, 0.18, -1.92), Vector3(0.93, 0.74, 0.70), Color(0.26, 0.25, 0.21)],
		[Vector3(-0.48, 0.82, -2.33), Vector3(0.78, 0.52, 0.63), Color(0.32, 0.31, 0.27)],
		[Vector3(0.55, 0.88, -2.35), Vector3(0.81, 0.56, 0.61), Color(0.19, 0.23, 0.22)],
		[Vector3(-2.85, 0.24, -1.90), Vector3(1.05, 0.70, 0.76), Color(0.27, 0.30, 0.28)],
		[Vector3(2.84, 0.25, -1.88), Vector3(1.03, 0.72, 0.77), Color(0.30, 0.28, 0.24)],
		[Vector3(-3.35, 0.18, 0.35), Vector3(0.72, 0.52, 0.61), Color(0.18, 0.23, 0.23)],
		[Vector3(3.34, 0.18, 0.48), Vector3(0.75, 0.58, 0.66), Color(0.28, 0.27, 0.23)],
	]
	for stone in stones:
		var rock_mat := _material(stone[2], 0.92)
		var rock := _sphere("River boulder", stone[0], stone[1], rock_mat, 28, 18)
		rock.rotation = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.0, TAU), rng.randf_range(-0.12, 0.12))
	# The broad roof rock rests on two shoulders, leaving a clearly readable dark arch.
	_sphere("Burrow roof lip", Vector3(0.0, 1.20, -2.12), Vector3(1.14, 0.27, 0.54), _material(Color(0.30, 0.29, 0.25), 0.90), 36, 20)


func _build_plants() -> void:
	var leaf_mat := _material(Color(0.11, 0.37, 0.22), 0.78)
	var stem_mat := _material(Color(0.19, 0.34, 0.19), 0.82)
	var plant_positions: Array[float] = [-3.25, -2.65, -1.80, 1.90, 2.66, 3.30, 0.0]
	for clump in range(7):
		var base_x: float = plant_positions[clump]
		var base_z := -1.90 if clump % 2 == 0 else -0.68
		for leaf in range(5):
			var angle := TAU * float(leaf) / 5.0 + rng.randf_range(-0.18, 0.18)
			var height := rng.randf_range(0.28, 0.72)
			var direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
			var tip := Vector3(base_x, 0.0, base_z) + direction * rng.randf_range(0.20, 0.42) + Vector3(0.0, height, 0.0)
			_rod("Aquatic plant stem", Vector3(base_x, 0.02, base_z), tip, 0.014, stem_mat)
			var blade := _sphere("Anubias leaf", tip.lerp(Vector3(base_x, 0.06, base_z), 0.38), Vector3(0.105, 0.028, 0.24), leaf_mat, 24, 12)
			blade.look_at(tip + direction * 0.8 + Vector3(0.0, 0.25, 0.0), Vector3.UP)
	

func _build_filter() -> void:
	filter_material = _material(Color(0.06, 0.10, 0.12), 0.86)
	_box("Sponge filter", Vector3(0.72, 1.22, 0.62), Vector3(3.15, 0.69, -2.20), filter_material)
	var rib_mat := _material(Color(0.13, 0.20, 0.21), 0.78)
	for i in range(8):
		_box("Filter foam rib", Vector3(0.82, 0.075, 0.68), Vector3(3.15, 0.22 + i * 0.135, -2.20), rib_mat)
	var tube_mat := _material(Color(0.14, 0.35, 0.39), 0.42, 0.16)
	_rod("Filter air line", Vector3(3.14, 1.28, -2.20), Vector3(3.14, 3.10, -2.20), 0.033, tube_mat)
	for i in range(9):
		var stone := _sphere("Filter outlet", Vector3(3.12, 1.28 + i * 0.18, -2.20), Vector3(0.055, 0.036, 0.055), _material(Color(0.22, 0.46, 0.51), 0.35, 0.18), 14, 8)
		stone.rotation.z = 0.2


func _build_crayfish() -> void:
	var model := CRAYFISH_SCENE.instantiate()
	actor = Node3D.new()
	actor.name = "BlueCrayfishActor"
	actor.scale = Vector3.ONE * 0.64
	actor.position = home_position
	actor.rotation.y = PI
	add_child(actor)
	actor.add_child(model)
	for node in actor.find_children("AntennaPivot_*", "Node3D", true, false):
		if node is Node3D:
			antenna_pivots.append(node as Node3D)
	for node in actor.find_children("ChelipedPivot_*", "Node3D", true, false):
		if node is Node3D:
			cheliped_pivots.append(node as Node3D)
	for node in actor.find_children("WalkingLegPivot_*", "Node3D", true, false):
		if node is Node3D:
			leg_pivots.append(node as Node3D)


func _build_bubbles() -> void:
	var bubble_mat := _material(Color(0.44, 0.86, 0.93, 0.37), 0.08, 0.14)
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(18):
		var size := rng.randf_range(0.025, 0.055)
		var bubble := _sphere("Air bubble", Vector3(3.08 + rng.randf_range(-0.12, 0.12), 0.18 + float(i) * 0.16, -2.20), Vector3.ONE * size, bubble_mat, 16, 10)
		bubbles.append(bubble)
		bubble_speeds.append(rng.randf_range(0.36, 0.66))


func _build_lighting() -> void:
	aquarium_light = OmniLight3D.new()
	aquarium_light.name = "Aquarium softbox"
	aquarium_light.position = Vector3(-1.0, 3.04, 1.35)
	aquarium_light.light_color = Color(0.67, 0.86, 1.0)
	aquarium_light.light_energy = 1.35
	aquarium_light.omni_range = 9.0
	aquarium_light.shadow_enabled = true
	add_child(aquarium_light)
	var rim := DirectionalLight3D.new()
	rim.name = "Blue water rim light"
	rim.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	rim.light_color = Color(0.28, 0.64, 0.90)
	rim.light_energy = 0.48
	add_child(rim)


func _animate_pivots() -> void:
	for i in range(antenna_pivots.size()):
		var side := -1.0 if i % 2 == 0 else 1.0
		antenna_pivots[i].rotation.z = sin(elapsed * 1.2 + i * 0.9) * 0.08 * side
		antenna_pivots[i].rotation.x = cos(elapsed * 0.8 + i * 0.6) * 0.035
	for i in range(cheliped_pivots.size()):
		cheliped_pivots[i].rotation.y = sin(elapsed * 0.72 + i * 1.7) * 0.045
	for i in range(leg_pivots.size()):
		leg_pivots[i].rotation.z = sin(elapsed * 1.4 + i * 1.1) * 0.026


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _box(label: String, dimensions: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.position = point
	item.material_override = material
	add_child(item)
	return item


func _sphere(label: String, point: Vector3, dimensions: Vector3, material: Material, segments: int = 28, rings: int = 18) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	item.mesh = mesh
	item.position = point
	item.scale = dimensions
	item.material_override = material
	add_child(item)
	return item


func _rod(label: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.66
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	item.mesh = mesh
	item.position = from.lerp(to, 0.5)
	item.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	item.material_override = material
	add_child(item)
	return item
