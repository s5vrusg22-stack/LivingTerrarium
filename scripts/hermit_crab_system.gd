extends Node3D

const MAX_CRABS := 6
const MAX_SPARE_SHELLS := 16
const FLOOR_Y := -0.45

var clock := 0.0
var temperature := 25.0
var humidity := 78.0
var water_level := 1.0
var crabs: Array[Dictionary] = []
var spare_shells: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var warm_light: OmniLight3D
var water_surface_fresh: MeshInstance3D
var water_surface_salt: MeshInstance3D
var sand_texture: Texture2D
var shell_texture: Texture2D

const SHELL_COLORS := [
	Color(0.70, 0.22, 0.15),
	Color(0.88, 0.51, 0.19),
	Color(0.38, 0.35, 0.56),
	Color(0.83, 0.69, 0.42),
	Color(0.48, 0.25, 0.18),
	Color(0.79, 0.36, 0.28)
]


func _ready() -> void:
	rng.randomize()
	shell_texture = _create_shell_texture()
	_create_tank()
	for i in range(3):
		_create_crab(i)
	for i in range(5):
		_create_spare_shell(Vector3(-1.48 + float(i) * 0.72, FLOOR_Y + 0.035, 1.02 + (0.08 if i % 2 == 0 else -0.06)))
	_update_light()


func _create_tank() -> void:
	_box(self, Vector3(0.0, -0.59, 0.0), Vector3(4.58, 0.16, 3.18), Color(0.14, 0.12, 0.10), "TankBase")
	sand_texture = _create_sand_texture()
	var substrate := _box(self, Vector3(0.0, -0.49, 0.0), Vector3(4.32, 0.09, 2.92), Color(0.69, 0.49, 0.29), "DeepSandSubstrate")
	var sand_material := substrate.material_override as StandardMaterial3D
	sand_material.albedo_texture = sand_texture
	sand_material.roughness = 0.98
	for x in [-2.12, 2.12]:
		for z in [-1.44, 1.44]:
			_rod(self, Vector3(x, -0.50, z), Vector3(x, 0.53, z), 0.025, Color(0.28, 0.23, 0.18))
	for z in [-1.44, 1.44]:
		_rod(self, Vector3(-2.12, 0.48, z), Vector3(2.12, 0.48, z), 0.020, Color(0.36, 0.29, 0.21))
	_create_glass_panels()
	for i in range(10):
		var dune := _ellipsoid(self, Vector3(rng.randf_range(-1.75, 1.75), FLOOR_Y + 0.005, rng.randf_range(-1.12, 1.12)), Vector3(rng.randf_range(0.30, 0.65), 0.018, rng.randf_range(0.20, 0.40)), Color(0.71, 0.52, 0.33).lerp(Color(0.77, 0.61, 0.42), rng.randf()))
		dune.name = "SoftSandDune"
	for i in range(150):
		var speck := _ellipsoid(self, Vector3(rng.randf_range(-2.02, 2.02), FLOOR_Y + 0.012, rng.randf_range(-1.30, 1.30)), Vector3(rng.randf_range(0.012, 0.036), 0.006, rng.randf_range(0.012, 0.034)), Color(0.83, 0.68, 0.47).lerp(Color(0.39, 0.28, 0.20), rng.randf()))
		speck.name = "SandGrain"
	for i in range(42):
		var pebble := _ellipsoid(self, Vector3(rng.randf_range(-1.95, 1.95), FLOOR_Y + 0.012, rng.randf_range(-1.25, 1.25)), Vector3(rng.randf_range(0.018, 0.050), rng.randf_range(0.010, 0.022), rng.randf_range(0.018, 0.045)), Color(0.43, 0.39, 0.32).lerp(Color(0.66, 0.59, 0.47), rng.randf()))
		pebble.name = "RoundedGravel"
	_create_rock_hide()
	_create_driftwood()
	_create_water_dish(Vector3(-1.48, FLOOR_Y, 0.88), Color(0.30, 0.70, 0.79), true)
	_create_water_dish(Vector3(1.48, FLOOR_Y, 0.88), Color(0.53, 0.72, 0.84), false)
	for x in [-1.88, 1.88]:
		_create_leaf_cluster(Vector3(x, FLOOR_Y, -1.18), Color(0.26, 0.39, 0.20))
	warm_light = OmniLight3D.new()
	warm_light.name = "WarmTerrariumLight"
	warm_light.position = Vector3(-0.6, 1.35, 0.4)
	warm_light.light_color = Color(1.0, 0.83, 0.63)
	warm_light.light_energy = 0.72
	warm_light.omni_range = 5.8
	add_child(warm_light)
	warm_light.shadow_enabled = true
	warm_light.light_size = 0.32
	var fill_light := OmniLight3D.new()
	fill_light.name = "SoftCoolFillLight"
	fill_light.position = Vector3(1.6, 0.72, 0.8)
	fill_light.light_color = Color(0.64, 0.78, 0.90)
	fill_light.light_energy = 0.22
	fill_light.omni_range = 3.8
	add_child(fill_light)


func _create_glass_panels() -> void:
	var glass_color := Color(0.54, 0.78, 0.88, 0.12)
	var panels: Array[MeshInstance3D] = [
		_box(self, Vector3(0.0, -0.01, 1.43), Vector3(4.18, 0.90, 0.018), glass_color, "FrontGlassPane"),
		_box(self, Vector3(0.0, -0.01, -1.43), Vector3(4.18, 0.90, 0.018), glass_color, "RearGlassPane"),
		_box(self, Vector3(-2.11, -0.01, 0.0), Vector3(0.018, 0.90, 2.86), glass_color, "LeftGlassPane"),
		_box(self, Vector3(2.11, -0.01, 0.0), Vector3(0.018, 0.90, 2.86), glass_color, "RightGlassPane")
	]
	for panel in panels:
		var material := _material(glass_color, 0.16)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.metallic = 0.05
		panel.material_override = material
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _create_sand_texture() -> Texture2D:
	var image := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	var broad_noise := FastNoiseLite.new()
	broad_noise.frequency = 0.055
	var grain_noise := FastNoiseLite.new()
	grain_noise.frequency = 0.34
	for y in range(160):
		for x in range(160):
			var grain := broad_noise.get_noise_2d(float(x), float(y)) * 0.68 + grain_noise.get_noise_2d(float(x), float(y)) * 0.32
			var value := clampf((grain + 1.0) * 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.50, 0.34, 0.20).lerp(Color(0.86, 0.72, 0.52), value))
	return ImageTexture.create_from_image(image)


func _create_shell_texture() -> Texture2D:
	var image := Image.create(192, 128, false, Image.FORMAT_RGBA8)
	var mottling := FastNoiseLite.new()
	mottling.frequency = 0.075
	mottling.fractal_octaves = 3
	var fine_grain := FastNoiseLite.new()
	fine_grain.frequency = 0.42
	for y in range(128):
		for x in range(192):
			var u := float(x) / 192.0
			var v := float(y) / 128.0
			var noise := mottling.get_noise_2d(float(x), float(y)) * 0.72 + fine_grain.get_noise_2d(float(x), float(y)) * 0.20
			var growth_lines := absf(sin(v * TAU * 22.0 + noise * 2.2))
			var shade := clampf(0.49 + noise * 0.27 - growth_lines * 0.12, 0.08, 0.94)
			var tint := Color(0.95, 0.78, 0.53).lerp(Color(0.35, 0.20, 0.15), shade)
			image.set_pixel(x, y, tint)
	return ImageTexture.create_from_image(image)


func _create_rock_hide() -> void:
	var rock_color := Color(0.31, 0.29, 0.25)
	var dark_color := Color(0.075, 0.061, 0.050)
	_ellipsoid(self, Vector3(-1.31, FLOOR_Y + 0.15, -0.90), Vector3(0.48, 0.32, 0.35), rock_color)
	_ellipsoid(self, Vector3(-0.80, FLOOR_Y + 0.14, -0.91), Vector3(0.43, 0.30, 0.35), rock_color.lightened(0.08))
	_ellipsoid(self, Vector3(-1.06, FLOOR_Y + 0.37, -0.91), Vector3(0.64, 0.20, 0.39), rock_color.lightened(0.13))
	var opening := _ellipsoid(self, Vector3(-1.06, FLOOR_Y + 0.07, -0.59), Vector3(0.33, 0.16, 0.025), dark_color)
	opening.name = "ShadedRockHide"
	for i in range(3):
		var pebble := _ellipsoid(self, Vector3(0.92 + float(i) * 0.28, FLOOR_Y + 0.08 + float(i % 2) * 0.03, -0.96), Vector3(0.28, 0.16, 0.25), rock_color.lightened(float(i) * 0.05))
		pebble.rotation.y = float(i) * 0.39


func _create_driftwood() -> void:
	_rod(self, Vector3(-0.10, FLOOR_Y + 0.05, -1.18), Vector3(0.86, FLOOR_Y + 0.42, -0.98), 0.095, Color(0.30, 0.20, 0.13))
	_rod(self, Vector3(0.45, FLOOR_Y + 0.26, -1.06), Vector3(0.18, FLOOR_Y + 0.56, -0.88), 0.055, Color(0.36, 0.24, 0.15))
	_rod(self, Vector3(0.66, FLOOR_Y + 0.35, -1.02), Vector3(1.04, FLOOR_Y + 0.60, -0.89), 0.045, Color(0.34, 0.22, 0.14))


func _create_water_dish(center: Vector3, water_color: Color, freshwater: bool) -> void:
	var dish_color := Color(0.29, 0.35, 0.39) if freshwater else Color(0.32, 0.29, 0.40)
	var base := _cylinder(self, center + Vector3(0.0, 0.045, 0.0), 0.27, 0.22, 0.085, dish_color)
	base.name = "FreshWaterDish" if freshwater else "SaltWaterDish"
	var basin := _cylinder(self, center + Vector3(0.0, 0.043, 0.0), 0.222, 0.178, 0.045, dish_color.darkened(0.36))
	basin.name = "WaterBowlInnerBasin"
	var rim := _cylinder(self, center + Vector3(0.0, 0.084, 0.0), 0.275, 0.275, 0.016, dish_color.lightened(0.22))
	rim.name = "WaterBowlRim"
	var water := _cylinder(self, center + Vector3(0.0, 0.069, 0.0), 0.205, 0.205, 0.006, water_color)
	water.name = "FreshWaterSurface" if freshwater else "SaltWaterSurface"
	var water_material := water.material_override as StandardMaterial3D
	water_material.roughness = 0.18
	water_material.metallic = 0.12
	water_material.emission_enabled = true
	water_material.emission = water_color.darkened(0.30)
	if freshwater:
		water_surface_fresh = water
	else:
		water_surface_salt = water


func _create_leaf_cluster(base: Vector3, color: Color) -> void:
	for i in range(5):
		var side := -1.0 if i % 2 == 0 else 1.0
		var leaf := _ellipsoid(self, base + Vector3(side * (0.08 + float(i % 3) * 0.07), 0.12 + float(i % 3) * 0.055, float(i - 2) * 0.08), Vector3(0.16, 0.035, 0.06), color.lightened(float(i % 2) * 0.12))
		leaf.rotation.z = side * 0.45
		leaf.rotation.y = float(i) * 0.55


func _create_crab(index: int) -> void:
	var root := Node3D.new()
	root.name = "LandHermitCrab_%02d" % (index + 1)
	if index < 3:
		root.position = Vector3(-0.78 + float(index) * 0.78, FLOOR_Y, -0.05 + float(index % 2) * 0.44)
	else:
		root.position = Vector3(rng.randf_range(-1.55, 1.55), FLOOR_Y, rng.randf_range(-0.95, 0.95))
	root.scale = Vector3.ONE * 1.12
	add_child(root)
	var shell_color: Color = SHELL_COLORS[index % SHELL_COLORS.size()]
	var body_color := Color(0.83, 0.34, 0.20).lightened(float(index % 3) * 0.045)
	var carapace := _ellipsoid(root, Vector3(0.0, 0.115, 0.035), Vector3(0.17, 0.073, 0.145), body_color)
	carapace.name = "RaisedCarapacePlate"
	(carapace.material_override as StandardMaterial3D).roughness = 0.48
	_ellipsoid(root, Vector3(0.0, 0.105, 0.145), Vector3(0.085, 0.052, 0.055), body_color.lightened(0.08)).name = "Rostrum"
	for spot_index in range(16):
		var spot_angle := TAU * float(spot_index) / 16.0
		var spot_x := cos(spot_angle) * 0.118
		var spot_z := 0.035 + sin(spot_angle) * 0.090
		var spot_y := 0.115 + 0.073 * sqrt(maxf(0.08, 1.0 - pow(spot_x / 0.17, 2.0) - pow((spot_z - 0.035) / 0.145, 2.0)))
		var spot := _ellipsoid(root, Vector3(spot_x, spot_y, spot_z), Vector3(0.009, 0.0045, 0.008), Color(0.98, 0.72, 0.43))
		spot.name = "CarapacePore_%02d" % spot_index
	for segment_index in range(4):
		var segment := _ellipsoid(root, Vector3(0.0, 0.050 - float(segment_index) * 0.005, -0.085 - float(segment_index) * 0.024), Vector3(0.086 - float(segment_index) * 0.008, 0.022, 0.038), body_color.darkened(0.10 + float(segment_index) * 0.10))
		segment.name = "AbdominalPlate_%02d" % segment_index
	_create_shell_form(root, Vector3(0.0, 0.235, -0.045), Vector3(0.15, 0.145, 0.17), shell_color, "CrabSpiralShell")
	var mouth := _ellipsoid(root, Vector3(0.0, 0.075, 0.173), Vector3(0.050, 0.032, 0.022), Color(0.28, 0.10, 0.08))
	mouth.name = "MouthPlate"
	for side in [-1.0, 1.0]:
		_rod(root, Vector3(side * 0.018, 0.076, 0.18), Vector3(side * 0.036, 0.044, 0.204), 0.009, Color(0.52, 0.19, 0.12))
	var antenna_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		_rod(root, Vector3(side * 0.052, 0.16, 0.105), Vector3(side * 0.071, 0.252, 0.145), 0.013, body_color.darkened(0.17))
		var eye := _ellipsoid(root, Vector3(side * 0.074, 0.263, 0.157), Vector3(0.030, 0.031, 0.028), Color(0.055, 0.036, 0.030))
		eye.name = "CompoundEye"
		_ellipsoid(root, Vector3(side * 0.081, 0.273, 0.180), Vector3(0.006, 0.007, 0.004), Color(1.0, 0.86, 0.67)).name = "EyeCatchlight"
		var antenna := Node3D.new()
		antenna.name = "BifidAntenna_%s" % ("L" if side < 0.0 else "R")
		antenna.position = Vector3(side * 0.035, 0.145, 0.13)
		root.add_child(antenna)
		_rod(antenna, Vector3.ZERO, Vector3(side * 0.04, 0.055, 0.085), 0.006, Color(0.61, 0.29, 0.16))
		_rod(antenna, Vector3(side * 0.04, 0.055, 0.085), Vector3(side * 0.105, 0.095, 0.125), 0.004, Color(0.74, 0.41, 0.22))
		antenna_pivots.append(antenna)
	var claw_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.name = "Cheliped_%s" % ("L" if side < 0.0 else "R")
		claw.position = Vector3(side * 0.13, 0.087, 0.105)
		root.add_child(claw)
		var elbow := Vector3(side * 0.075, -0.023, 0.042)
		var wrist := Vector3(side * 0.118, -0.038, 0.090)
		var palm := Vector3(side * 0.140, -0.045, 0.125)
		_rod(claw, Vector3.ZERO, elbow, 0.026, body_color)
		_ellipsoid(claw, elbow, Vector3(0.030, 0.027, 0.027), body_color.lightened(0.06)).name = "ElbowJoint"
		_rod(claw, elbow, wrist, 0.020, body_color.darkened(0.06))
		_ellipsoid(claw, wrist, Vector3(0.024, 0.023, 0.024), Color(0.54, 0.19, 0.13)).name = "WristJoint"
		_rod(claw, wrist, palm, 0.025, body_color)
		var claw_scale := 1.0 if side < 0.0 else 0.84
		var palm_mesh := _ellipsoid(claw, palm, Vector3(0.066, 0.053, 0.074) * claw_scale, Color(0.92, 0.37, 0.20) if side < 0.0 else Color(0.76, 0.29, 0.20))
		palm_mesh.name = "ChelipedPalm"
		for dot_index in range(5):
			var dot_side := -1.0 if dot_index % 2 == 0 else 1.0
			_ellipsoid(claw, palm + Vector3(dot_side * 0.030, 0.015, -0.005 + float(dot_index % 3) * 0.018), Vector3(0.006, 0.006, 0.006), Color(1.0, 0.76, 0.43)).name = "ClawPore"
		var finger_root := palm + Vector3(0.0, 0.0, 0.055)
		_rod(claw, finger_root + Vector3(0.0, 0.022, 0.0), finger_root + Vector3(side * 0.024, 0.034, 0.063), 0.013, Color(0.96, 0.69, 0.39))
		_rod(claw, finger_root + Vector3(0.0, -0.022, 0.0), finger_root + Vector3(-side * 0.010, -0.034, 0.065), 0.012, Color(0.90, 0.59, 0.34))
		claw_pivots.append(claw)
	var leg_pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		for leg_index in range(4):
			var pivot := Node3D.new()
			pivot.name = "WalkingLeg_%s_%d" % ["L" if side < 0.0 else "R", leg_index]
			var rear_scale := 0.70 if leg_index == 3 else 1.0
			var start := Vector3(side * 0.115, 0.070, 0.060 - float(leg_index) * 0.067)
			var elbow := Vector3(side * 0.205 * rear_scale, 0.018, 0.015 - float(leg_index) * 0.080)
			var tip := Vector3(side * 0.300 * rear_scale, -0.060, 0.030 - float(leg_index) * 0.085)
			pivot.position = start
			root.add_child(pivot)
			_rod(pivot, Vector3.ZERO, elbow - start, 0.018 * rear_scale, Color(0.77, 0.30, 0.20))
			_ellipsoid(pivot, elbow - start, Vector3(0.021, 0.020, 0.021) * rear_scale, Color(0.96, 0.52, 0.29)).name = "WalkingLegJoint"
			_rod(pivot, elbow - start, tip - start, 0.010 * rear_scale, body_color.darkened(0.12))
			_ellipsoid(pivot, tip - start, Vector3(0.012, 0.010, 0.016) * rear_scale, body_color.lightened(0.18)).name = "DactylTip"
			leg_pivots.append(pivot)
	crabs.append({
		"root": root,
		"legs": leg_pivots,
		"antennae": antenna_pivots,
		"claws": claw_pivots,
		"state": "탐색",
		"timer": rng.randf_range(0.6, 2.4),
		"phase": float(index) * 1.9,
		"target": Vector3(root.position.x + rng.randf_range(-0.55, 0.55), FLOOR_Y, root.position.z + rng.randf_range(-0.45, 0.45))
	})


func _create_shell_form(parent: Node3D, center: Vector3, size: Vector3, color: Color, prefix: String) -> void:
	var shell_body := _ellipsoid(parent, center, size, color)
	shell_body.name = prefix + "Body"
	var shell_material := shell_body.material_override as StandardMaterial3D
	shell_material.roughness = 0.30
	shell_material.metallic = 0.025
	shell_material.albedo_texture = shell_texture
	var whorl := _ellipsoid(parent, center + Vector3(0.0, size.y * 0.28, -size.z * 0.35), Vector3(size.x * 0.58, size.y * 0.66, size.z * 0.62), color.lightened(0.11))
	whorl.name = prefix + "Whorl"
	(whorl.material_override as StandardMaterial3D).roughness = 0.27
	(whorl.material_override as StandardMaterial3D).albedo_texture = shell_texture
	var aperture_lip := _ellipsoid(parent, center + Vector3(0.0, -size.y * 0.10, size.z * 0.72), Vector3(size.x * 0.52, size.y * 0.49, size.z * 0.20), color.lightened(0.18))
	aperture_lip.name = prefix + "ApertureLip"
	(aperture_lip.material_override as StandardMaterial3D).albedo_texture = shell_texture
	_ellipsoid(parent, center + Vector3(0.0, -size.y * 0.13, size.z * 0.86), Vector3(size.x * 0.30, size.y * 0.30, size.z * 0.085), Color(0.10, 0.065, 0.045)).name = prefix + "ApertureShadow"
	# A continuous raised rim makes the opening read as a hollow shell aperture.
	var lip_center := center + Vector3(0.0, -size.y * 0.12, size.z * 0.79)
	for lip_segment in range(32):
		var a0 := TAU * float(lip_segment) / 32.0
		var a1 := TAU * float(lip_segment + 1) / 32.0
		var p0 := lip_center + Vector3(cos(a0) * size.x * 0.34, sin(a0) * size.y * 0.34, 0.0)
		var p1 := lip_center + Vector3(cos(a1) * size.x * 0.34, sin(a1) * size.y * 0.34, 0.0)
		_rod(parent, p0, p1, maxf(0.0018, size.x * 0.028), color.lightened(0.29))
	var ridge_color := color.darkened(0.18).lerp(Color(0.95, 0.72, 0.48), 0.26)
	for ridge_index in range(12):
		var t := -0.84 + float(ridge_index) * 0.152
		var z_offset := t * size.z * 0.90
		var half_width := size.x * sqrt(maxf(0.10, 1.0 - t * t)) * 0.88
		var ridge_color_local := ridge_color if ridge_index % 2 == 0 else color.darkened(0.12)
		for segment_index in range(8):
			var x0 := -half_width + 2.0 * half_width * float(segment_index) / 8.0
			var x1 := -half_width + 2.0 * half_width * float(segment_index + 1) / 8.0
			var z := center.z + z_offset
			var nx0 := x0 / size.x
			var nx1 := x1 / size.x
			var nz := z_offset / size.z
			var y0 := center.y + size.y * sqrt(maxf(0.08, 1.0 - nx0 * nx0 - nz * nz)) * 1.008
			var y1 := center.y + size.y * sqrt(maxf(0.08, 1.0 - nx1 * nx1 - nz * nz)) * 1.008
			_rod(parent, Vector3(center.x + x0, y0, z), Vector3(center.x + x1, y1, z), maxf(0.0015, size.x * 0.018), ridge_color_local)
	for side in [-1.0, 1.0]:
		var spiral_points: Array[Vector3] = []
		for point_index in range(49):
			var fraction := float(point_index) / 48.0
			var angle := fraction * TAU * 2.7
			var radius := 0.025 + fraction * 0.29
			var dy := cos(angle) * size.y * radius
			var dz := -size.z * 0.24 + sin(angle) * size.z * radius
			var normalized := pow(dy / size.y, 2.0) + pow(dz / size.z, 2.0)
			var dx: float = side * size.x * sqrt(maxf(0.18, 1.0 - normalized)) * 1.018
			spiral_points.append(center + Vector3(dx, dy, dz))
		for point_index in range(1, spiral_points.size()):
			_rod(parent, spiral_points[point_index - 1], spiral_points[point_index], maxf(0.0015, size.x * 0.014), ridge_color)
	for speck_index in range(52):
		var longitude := rng.randf_range(-0.78, 0.78)
		var angle := rng.randf_range(0.0, TAU)
		var ring_radius := sqrt(maxf(0.0, 1.0 - longitude * longitude))
		var speck_position := center + Vector3(size.x * cos(angle) * ring_radius * 1.008, size.y * sin(angle) * ring_radius * 1.008, size.z * longitude * 1.008)
		var speck_size := rng.randf_range(0.022, 0.043)
		var speck_color := color.lightened(0.28) if speck_index % 3 != 0 else color.darkened(0.20)
		var shell_speck := _ellipsoid(parent, speck_position, Vector3(size.x * speck_size, size.y * 0.018, size.z * speck_size), speck_color)
		shell_speck.name = prefix + "Speckle_%02d" % speck_index
		(shell_speck.material_override as StandardMaterial3D).roughness = 0.36


func _create_spare_shell(position_value: Vector3) -> void:
	if spare_shells.size() >= MAX_SPARE_SHELLS:
		return
	var shell_root := Node3D.new()
	shell_root.name = "SpareShell_%02d" % (spare_shells.size() + 1)
	shell_root.position = position_value
	shell_root.rotation.y = rng.randf_range(-PI, PI)
	add_child(shell_root)
	var color: Color = SHELL_COLORS[rng.randi_range(0, SHELL_COLORS.size() - 1)]
	_create_shell_form(shell_root, Vector3(0.0, 0.075, 0.0), Vector3(0.11, 0.075, 0.14), color, "SpareShell")
	spare_shells.append(shell_root)


func simulate(delta: float) -> void:
	var dt := minf(delta, 0.08)
	clock += dt
	water_level = maxf(0.0, water_level - dt * 0.0009)
	_update_water_visuals()
	for i in range(crabs.size()):
		var record: Dictionary = crabs[i]
		var root: Node3D = record["root"]
		var legs: Array[Node3D] = record["legs"]
		var antennae: Array[Node3D] = record["antennae"]
		var claws: Array[Node3D] = record["claws"]
		var state := String(record["state"])
		var timer := float(record["timer"]) - dt
		var phase := float(record["phase"])
		if timer <= 0.0:
			var roll := rng.randf()
			if roll < 0.18:
				state = "은신"
				record["target"] = Vector3(-1.05, FLOOR_Y, -0.58)
				timer = rng.randf_range(2.8, 5.0)
			elif roll < 0.35:
				state = "휴식"
				record["target"] = root.position
				timer = rng.randf_range(1.8, 3.6)
			elif roll < 0.53:
				state = "껍데기 살피기"
				if spare_shells.is_empty():
					record["target"] = Vector3(rng.randf_range(-1.7, 1.7), FLOOR_Y, rng.randf_range(-0.8, 0.8))
				else:
					var shell: Node3D = spare_shells[rng.randi_range(0, spare_shells.size() - 1)]
					record["target"] = Vector3(shell.position.x, FLOOR_Y, shell.position.z)
				timer = rng.randf_range(2.0, 4.0)
			elif roll < 0.68:
				state = "물그릇 탐색"
				var water_x := -1.48 if rng.randi_range(0, 1) == 0 else 1.48
				record["target"] = Vector3(water_x, FLOOR_Y, 0.88)
				timer = rng.randf_range(2.5, 4.2)
			else:
				state = "탐색"
				record["target"] = Vector3(rng.randf_range(-1.75, 1.75), FLOOR_Y, rng.randf_range(-1.12, 1.12))
				timer = rng.randf_range(3.0, 6.5)
		var target: Vector3 = record["target"]
		var offset := target - root.position
		var moving_state := state in ["탐색", "은신", "껍데기 살피기", "물그릇 탐색"]
		if state == "물그릇 탐색" and offset.length() < 0.10:
			state = "물 마시기"
			moving_state = false
		if offset.length() > 0.035 and moving_state:
			root.position = root.position.move_toward(target, dt * (0.13 if state == "은신" else 0.20))
			root.rotation.y = lerp_angle(root.rotation.y, atan2(offset.x, offset.z), dt * 2.6)
		var walking := moving_state and offset.length() > 0.05
		root.position.y = FLOOR_Y + sin(clock * 5.0 + phase) * (0.006 if walking else 0.002)
		for leg_index in range(legs.size()):
			var leg: Node3D = legs[leg_index]
			var side := -1.0 if leg_index < 4 else 1.0
			var leg_slot := leg_index % 4
			var stride := sin(clock * 8.5 + phase + float(leg_slot) * PI * 0.75 + (PI if side > 0.0 else 0.0))
			leg.rotation.y = stride * 0.14 * side if walking else 0.012 * side
			leg.rotation.z = absf(stride) * 0.045 if walking else 0.0
		for antenna_index in range(antennae.size()):
			var antenna: Node3D = antennae[antenna_index]
			var antenna_side := -1.0 if antenna_index == 0 else 1.0
			antenna.rotation.z = sin(clock * 3.2 + phase + float(antenna_index) * 1.3) * 0.11 * antenna_side
			antenna.rotation.x = cos(clock * 2.1 + phase + float(antenna_index)) * 0.045
		for claw_index in range(claws.size()):
			var claw: Node3D = claws[claw_index]
			var claw_side := -1.0 if claw_index == 0 else 1.0
			claw.rotation.z = sin(clock * 2.4 + phase + float(claw_index)) * 0.035 * claw_side if walking else 0.0
		record["state"] = state
		record["timer"] = timer
		record["phase"] = phase
		crabs[i] = record


func encourage_activity() -> void:
	for i in range(crabs.size()):
		var record: Dictionary = crabs[i]
		record["state"] = "탐색"
		record["timer"] = 0.0
		record["target"] = Vector3(rng.randf_range(-1.7, 1.7), FLOOR_Y, rng.randf_range(-1.12, 1.12))
		crabs[i] = record


func add_crab() -> bool:
	if crabs.size() >= MAX_CRABS:
		return false
	_create_crab(crabs.size())
	return true


func add_shell() -> bool:
	if spare_shells.size() >= MAX_SPARE_SHELLS:
		return false
	_create_spare_shell(Vector3(rng.randf_range(-1.75, 1.75), FLOOR_Y + 0.035, rng.randf_range(-1.20, 1.20)))
	return true


func change_humidity(amount: float) -> void:
	humidity = clampf(humidity + amount, 45.0, 95.0)


func change_temperature(amount: float) -> void:
	temperature = clampf(temperature + amount, 18.0, 32.0)
	_update_light()


func refill_water() -> void:
	water_level = 1.0
	_update_water_visuals()


func water_percent() -> int:
	return int(round(water_level * 100.0))


func crab_count() -> int:
	return crabs.size()


func shell_count() -> int:
	return spare_shells.size()


func hide_count() -> int:
	return 1


func focus_position() -> Vector3:
	if crabs.is_empty():
		return Vector3(0.0, FLOOR_Y + 0.20, 0.0)
	var root: Node3D = crabs[0]["root"]
	return root.position + Vector3(0.0, 0.18, 0.0)


func activity_status() -> String:
	if crabs.is_empty():
		return "수조를 살펴보는 중"
	var exploring := 0
	var hiding := 0
	var resting := 0
	var seeking_water := 0
	var drinking := 0
	for record in crabs:
		match String(record["state"]):
			"탐색", "껍데기 살피기":
				exploring += 1
			"물그릇 탐색":
				seeking_water += 1
			"물 마시기":
				drinking += 1
			"은신":
				hiding += 1
			_:
				resting += 1
	if drinking > 0:
		return "물 마시는 중 %d마리" % drinking
	if seeking_water > 0:
		return "물그릇으로 이동 중 %d마리" % seeking_water
	if exploring > 0:
		return "탐색 중 %d마리" % exploring
	if hiding > 0:
		return "바위 은신처에서 휴식"
	return "모래 위에서 휴식 (%d마리)" % resting


func _update_light() -> void:
	if warm_light != null:
		warm_light.light_energy = 0.72 if temperature >= 22.0 and temperature <= 29.0 else 0.38


func _update_water_visuals() -> void:
	var has_water := water_level > 0.02
	for surface in [water_surface_fresh, water_surface_salt]:
		if surface != null:
			surface.visible = has_water
			surface.scale = Vector3.ONE
			surface.position.y = FLOOR_Y + 0.0235 + water_level * 0.037


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


func _cylinder(parent: Node3D, position_value: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 32
	item.mesh = mesh
	item.position = position_value
	item.material_override = _material(color, 0.40)
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
	mesh.radial_segments = 24
	mesh.rings = 16
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
	item.material_override = _material(color, 0.86)
	parent.add_child(item)

