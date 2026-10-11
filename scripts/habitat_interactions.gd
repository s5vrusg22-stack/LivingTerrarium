class_name HabitatInteractions
extends Node3D

# 30 small, budgeted visual/behavior interactions. No physics simulation is implied.
const MAX_TOUCH_DISTANCE := 0.24
const MAX_PREY := 12
const UPDATE_INTERVAL := 0.08
var active := true
var host
var clock := 0.0
var accumulator := 0.0
var leaf_offsets: Dictionary = {}
var leaf_velocities: Dictionary = {}
var plant_health: Dictionary = {}
var prey_states: Dictionary = {}
var branch_nodes: Array[Node3D] = []
var branch_velocities: Dictionary = {}
var interactions: Dictionary = {}
var ground_specks: Array[Node3D] = []
var water_drops: Array[Node3D] = []
var fungal_spots: Array[Node3D] = []
var light_node: DirectionalLight3D
var last_animal_position := Vector3.ZERO
var humidity_trend := 0.0
var pulse := 0.0
var leaf_touch_count := 0
var prey_hide_count := 0
var branch_touch_count := 0
var prey_leaf_touch_count := 0
var last_leaf_contact: Dictionary = {}
var animal_contact_radius := 0.24
var prey_contact_radius := 0.12
var _rng := RandomNumberGenerator.new()

func setup(main: Node3D) -> void:
    host = main
    _rng.seed = 1801026
    last_animal_position = host.animal.global_position
    for child in host.get_children():
        if child is DirectionalLight3D:
            light_node = child
            break
    for i in range(host.plant_pivots.size()):
        var joint: Node3D = host.plant_pivots[i]
        leaf_offsets[joint.get_instance_id()] = 0.0
        leaf_velocities[joint.get_instance_id()] = 0.0
        plant_health[joint.get_instance_id()] = _rng.randf_range(0.82, 1.0)
    for prey in host.prey_nodes:
        register_prey(prey)
    _build_ambient_details()

func register_prey(prey: Node3D) -> void:
    if prey_states.size() >= MAX_PREY:
        return
    prey_states[prey.get_instance_id()] = {"node": prey, "fear": 0.0, "rest": 0.0, "hide": false, "last": prey.position, "wander": _rng.randf_range(0.0, TAU)}

func unregister_prey(prey: Node3D) -> void:
    prey_states.erase(prey.get_instance_id())

func on_decoration_added(root: Node3D, kind: String) -> void:
    if kind == "wood":
        branch_nodes.append(root)
        branch_velocities[root.get_instance_id()] = 0.0

func leaf_displacement(joint: Node3D) -> float:
    return float(leaf_offsets.get(joint.get_instance_id(), 0.0)) if active else 0.0

func _build_ambient_details() -> void:
    var pebble := SphereMesh.new()
    pebble.radial_segments = 6
    pebble.rings = 4
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.21, 0.20, 0.12)
    var damp := StandardMaterial3D.new()
    damp.albedo_color = Color(0.22, 0.31, 0.24, 0.65)
    damp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var fungus := StandardMaterial3D.new()
    fungus.albedo_color = Color(0.50, 0.48, 0.32)
    for i in range(20):
        var speck := MeshInstance3D.new()
        speck.mesh = pebble
        speck.material_override = dark
        speck.scale = Vector3(0.012, 0.004, 0.008)
        speck.position = Vector3(_rng.randf_range(-1.42, 1.42), -0.541, _rng.randf_range(-1.02, 1.02))
        add_child(speck)
        ground_specks.append(speck)
    for i in range(10):
        var drop := MeshInstance3D.new()
        drop.mesh = pebble
        drop.material_override = damp
        drop.scale = Vector3(0.009, 0.006, 0.009)
        drop.position = Vector3(_rng.randf_range(-1.3, 1.3), -0.53, _rng.randf_range(-0.92, 0.92))
        add_child(drop)
        water_drops.append(drop)
    for i in range(8):
        var spot := MeshInstance3D.new()
        spot.mesh = pebble
        spot.material_override = fungus
        spot.scale = Vector3(0.009, 0.002, 0.012)
        spot.position = Vector3(_rng.randf_range(-1.3, 1.3), -0.537, _rng.randf_range(-0.92, 0.92))
        add_child(spot)
        fungal_spots.append(spot)

func simulate(dt: float) -> void:
    if not active or host == null:
        return
    clock += dt
    accumulator += dt
    if accumulator < UPDATE_INTERVAL:
        return
    var step := minf(accumulator, 0.2)
    accumulator = 0.0
    _plant_interactions(step)
    _prey_interactions(step)
    _habitat_interactions(step)

func _plant_interactions(dt: float) -> void:
    var animal_pos: Vector3 = host.animal.global_position
    var animal_velocity := (animal_pos - last_animal_position) / maxf(dt, 0.01)
    # 01 body/leaf contact; 02 velocity-scaled impulse; 03 impulse springback
    # 04 damped oscillation; 05 near-contact airflow; 06 gust shielding
    # 07 leaf-to-leaf propagation; 08 plant health tint/tilt;
    # 09 humidity droop; 10 stem/leaf stiffness diversity.
    var propagation: Dictionary = {}
    for i in range(host.plant_pivots.size()):
        var joint: Node3D = host.plant_pivots[i]
        if not is_instance_valid(joint):
            continue
        var id := joint.get_instance_id()
        var distance := joint.global_position.distance_to(animal_pos)
        var impulse := 0.0
        if distance < animal_contact_radius:
            impulse = (1.0 - distance / animal_contact_radius) * 0.36
            impulse *= clampf(0.4 + animal_velocity.length() * 1.8, 0.4, 2.0)
            if impulse > 0.08 and clock - float(last_leaf_contact.get(id, -10.0)) > 0.45:
                leaf_touch_count += 1
                last_leaf_contact[id] = clock
        elif distance < 0.42:
            impulse = (0.42 - distance) * 0.035
        # Nearby moving prey also brush the leaves; cap the contribution so
        # large prey populations cannot destabilize the spring animation.
        var prey_impulse := 0.0
        for prey in host.prey_nodes:
            if not is_instance_valid(prey):
                continue
            var prey_distance := joint.global_position.distance_to(prey.global_position)
            if prey_distance < prey_contact_radius:
                var prey_speed: Vector3 = host.prey_velocities.get(prey.get_instance_id(), Vector3.ZERO)
                prey_impulse = maxf(prey_impulse, (1.0 - prey_distance / prey_contact_radius) * minf(prey_speed.length() * 0.65, 0.22))
        if prey_impulse > 0.06 and clock - float(last_leaf_contact.get(id, -10.0)) > 0.45:
            prey_leaf_touch_count += 1
            last_leaf_contact[id] = clock
        impulse += prey_impulse
        var velocity := float(leaf_velocities.get(id, 0.0))
        var offset := float(leaf_offsets.get(id, 0.0))
        var stiffness := float(host.plant_stiffness[i])
        var shelter := 0.7 if joint.global_position.z < -0.3 else 1.0
        velocity += (impulse * shelter - offset * 10.0 * stiffness - velocity * 4.0) * dt
        offset = clampf(offset + velocity * dt, -0.32, 0.32)
        leaf_offsets[id] = offset
        leaf_velocities[id] = velocity
        if impulse > 0.03 and joint.get_parent() != null:
            propagation[joint.get_parent().get_instance_id()] = impulse * 0.05
        var droop := clampf((55.0 - float(host.humidity)) / 90.0, 0.0, 0.22)
        # Humidity droop is applied in the visual animation pass, not here.
        # Otherwise _animate_ecosystem() overwrites this rotation each frame.
        plant_health[id] = lerpf(float(plant_health.get(id, 1.0)), 1.0 - droop, minf(dt, 1.0))
    for joint in host.plant_pivots:
        if not is_instance_valid(joint) or joint.get_parent() == null:
            continue
        var parent_id := joint.get_parent().get_instance_id()
        if propagation.has(parent_id):
            var id := joint.get_instance_id()
            leaf_velocities[id] = float(leaf_velocities.get(id, 0.0)) + float(propagation[parent_id])

func _prey_interactions(dt: float) -> void:
    # 11 proximity fear; 12 alert delay; 13 panic sprint; 14 flee to cover;
    # 15 stop under cover; 16 recovery from fear; 17 rest pauses;
    # 18 orientation to travel; 19 separation; 20 obstacle avoidance.
    var animal_pos: Vector3 = host.animal.position
    for id in prey_states.keys():
        var state: Dictionary = prey_states[id]
        var prey: Node3D = state["node"]
        if not is_instance_valid(prey):
            prey_states.erase(id)
            continue
        var to_animal: Vector3 = prey.position - animal_pos
        var distance := to_animal.length()
        var fear := float(state["fear"])
        fear = clampf(fear + (dt * 2.2 if distance < 0.48 else -dt * 0.5), 0.0, 1.0)
        state["fear"] = fear
        var velocity: Vector3 = host.prey_velocities.get(id, Vector3.ZERO)
        var cover := _nearest_cover(prey.position)
        var cover_distance := prey.position.distance_to(cover)
        var hide := fear > 0.40 and cover_distance < 0.23
        if hide and not bool(state["hide"]):
            prey_hide_count += 1
        state["hide"] = hide
        if hide:
            velocity *= 0.2
        elif fear > 0.35:
            var flee := to_animal.normalized() if distance > 0.01 else Vector3.FORWARD
            var cover_dir := (cover - prey.position).normalized() if cover_distance > 0.02 else Vector3.ZERO
            velocity = (flee * 0.7 + cover_dir * 0.3).normalized() * (0.20 + fear * 0.12)
        elif fear < 0.1:
            state["rest"] = maxf(0.0, float(state["rest"]) - dt)
            if float(state["rest"]) <= 0.0 and _rng.randf() < dt * 0.4:
                state["rest"] = _rng.randf_range(0.3, 1.4)
            if float(state["rest"]) > 0.0:
                velocity *= 0.6
        for other in host.prey_nodes:
            if other == prey or not is_instance_valid(other):
                continue
            var diff := prey.position - other.position
            if diff.length_squared() > 0.0001 and diff.length_squared() < 0.012:
                velocity += diff.normalized() * 0.025
        for decor in host.decorations:
            if not is_instance_valid(decor):
                continue
            var diff := prey.position - decor.position
            if diff.length_squared() > 0.0001 and diff.length_squared() < 0.018:
                velocity += diff.normalized() * 0.035
        velocity.y = 0.0
        velocity = velocity.limit_length(0.34)
        host.prey_velocities[id] = velocity
        if velocity.length_squared() > 0.001:
            prey.rotation.y = lerp_angle(prey.rotation.y, atan2(-velocity.x, -velocity.z), dt * 7.0)
        prey.position.y = -0.38 + sin(clock * 9.0 + float(id % 13)) * 0.002 * clampf(velocity.length() * 4.0, 0.0, 1.0)
        prey_states[id] = state

func _nearest_cover(point: Vector3) -> Vector3:
    var best := point + Vector3(0.4, 0, 0)
    var nearest := INF
    for plant in host.plant_pivots:
        if not is_instance_valid(plant) or plant.get_parent() == null:
            continue
        var p: Vector3 = plant.global_position
        p.y = point.y
        var distance := point.distance_squared_to(p)
        if distance < nearest:
            nearest = distance
            best = p
    return best

func _habitat_interactions(dt: float) -> void:
    # 21 branch contact; 22 branch springback; 23 branch damping;
    # 24 wind on branches; 25 dust kicked by walking; 26 dust settling;
    # 27 humidity droplets; 28 evaporation; 29 fungi moisture response;
    # 30 gradual daylight intensity.
    var animal_pos: Vector3 = host.animal.global_position
    var speed := animal_pos.distance_to(last_animal_position) / maxf(dt, 0.01)
    for branch in branch_nodes.duplicate():
        if not is_instance_valid(branch):
            branch_nodes.erase(branch)
            continue
        var id := branch.get_instance_id()
        var sway := float(branch_velocities.get(id, 0.0))
        if branch.global_position.distance_to(animal_pos) < 0.36:
            sway += dt * clampf(speed, 0.0, 1.0) * 0.45
            branch_touch_count += 1
        sway += (-branch.rotation.z * 6.0 - sway * 3.2 + sin(clock * 1.4 + float(id % 19)) * host.wind_strength * 0.05) * dt
        branch.rotation.z = clampf(branch.rotation.z + sway * dt, -0.11, 0.11)
        branch_velocities[id] = sway
    for i in range(ground_specks.size()):
        var speck := ground_specks[i]
        var near := speck.position.distance_to(Vector3(animal_pos.x, -0.54, animal_pos.z))
        var kick := clampf(speed * (0.28 - near) * 0.1, 0.0, 0.018) if near < 0.28 else 0.0
        speck.position.y = move_toward(speck.position.y, -0.541, dt * 0.025) + kick * dt
    var wetness := clampf((float(host.humidity) - 45.0) / 55.0, 0.0, 1.0)
    for drop in water_drops:
        drop.visible = wetness > 0.2
        drop.scale.y = lerpf(0.002, 0.010, wetness)
    for spot in fungal_spots:
        spot.visible = wetness > 0.6
        spot.scale.x = lerpf(0.002, 0.013, wetness)
    if light_node != null:
        light_node.light_energy = 1.1 + sin(clock * 0.018) * 0.22
    last_animal_position = animal_pos

func summary() -> String:
    return "사마귀-잎 %d / 먹이-잎 %d / 먹이 은신 %d / 유목 %d" % [leaf_touch_count, prey_leaf_touch_count, prey_hide_count, branch_touch_count]
