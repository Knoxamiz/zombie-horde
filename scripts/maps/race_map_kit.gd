class_name RaceMapKit
extends RefCounted

enum StreetVariant { STRAIGHT, CRACK1, CRACK2 }
enum MapStyle { LONG_ROAD, BROKEN_BRIDGE }

const TILE_SIZE: float = 8.0
const TILE_HALF: float = TILE_SIZE * 0.5

const SCENE_STREET_STRAIGHT := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight.gltf"
)
const SCENE_STREET_CRACK1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack1.gltf"
)
const SCENE_STREET_CRACK2 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack2.gltf"
)
const SCENE_PLASTIC_BARRIER := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/PlasticBarrier.gltf"
)
const SCENE_TRAFFIC_BARRIER_1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_1.gltf"
)
const SCENE_TRAFFIC_BARRIER_2 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_2.gltf"
)
const SCENE_TRAFFIC_CONE_1 := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficCone_1.gltf"
)
const SCENE_STREET_LIGHT := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/StreetLights.gltf"
)
const SCENE_PALLET_BROKEN := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pallet_Broken.gltf"
)
const SCENE_PIPES := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pipes.gltf"
)
const SCENE_CINDER_BLOCK := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/CinderBlock.gltf"
)
const SCENE_CONTAINER_RED := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Red.gltf"
)
const SCENE_CONTAINER_GREEN := preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Green.gltf"
)

const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")

var _root: Node3D
var _collision_root: Node3D
var _visual_root: Node3D
var _style: MapStyle = MapStyle.LONG_ROAD
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func attach(root: Node3D, style: MapStyle, random_seed: int) -> void:
	_root = root
	_style = style
	_rng.seed = random_seed
	_collision_root = _make_child("Collision", root)
	_visual_root = _make_child("VisualKit", root)


func build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_color = Color(0.64, 0.7, 0.82, 1.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	_root.add_child(sun)

	_add_omni("StartPoolLight", Vector3(0.0, 5.2, -76.0), Color(0.52, 1.0, 0.35, 1.0), 2.25, 36.0)
	_add_omni("FinishPoolLight", Vector3(0.0, 5.2, 76.0), Color(1.0, 0.32, 0.12, 1.0), 2.0, 36.0)
	_add_omni("RoadAmberLightA", Vector3(-14.0, 4.4, -20.0), Color(1.0, 0.64, 0.18, 1.0), 1.45, 24.0)
	_add_omni("RoadAmberLightB", Vector3(14.0, 4.4, 36.0), Color(1.0, 0.64, 0.18, 1.0), 1.35, 24.0)


func build_water(width: float, length: float, y: float = -6.0) -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width + 16.0, 0.06, length + 16.0)
	water.mesh = mesh
	water.position = Vector3(0.0, y, 0.0)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
	water_mat.metallic = 0.3
	water_mat.roughness = 0.2
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.02, 0.07, 0.12, 1.0)
	water_mat.emission_energy_multiplier = 0.28
	water.material_override = water_mat
	_root.add_child(water)


func build_continuous_play_surface(
	road_width: float,
	z_start: float,
	z_end: float,
	y: float = 0.0,
	thickness: float = 0.12
) -> void:
	var length: float = z_end - z_start
	var center_z: float = (z_start + z_end) * 0.5
	_add_invisible_collision_box(
		"PlaySurface",
		Vector3(road_width, thickness, length),
		Vector3(0.0, y, center_z)
	)


func compose_map(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	match _style:
		MapStyle.BROKEN_BRIDGE:
			_compose_broken_bridge(segments, gaps)
		_:
			_compose_long_road(segments, gaps)


func build_markers(
	visual_width: float,
	spawn_z: float,
	goal_z: float,
	start_gate_z: float,
	finish_gate_z: float
) -> void:
	var gate_half: float = max(visual_width * 0.5 - 1.0, 6.0)
	_add_marker_box("SpawnZone", Vector3(visual_width, 0.06, 8.0), Vector3(0.0, 0.12, spawn_z), MAT_SPAWN)
	_add_marker_box("GoalGuide", Vector3(visual_width, 0.06, 8.0), Vector3(0.0, 0.13, goal_z), MAT_GOAL)
	_add_marker_box("StartLine", Vector3(visual_width, 0.07, 0.45), Vector3(0.0, 0.12, start_gate_z), MAT_SPAWN)
	_add_marker_box("FinishLine", Vector3(visual_width, 0.07, 0.45), Vector3(0.0, 0.12, finish_gate_z), MAT_GOAL)
	_add_gate(Vector3(-gate_half, 1.6, start_gate_z), Vector3(gate_half, 1.6, start_gate_z), MAT_SPAWN)
	_add_gate(Vector3(-gate_half, 1.6, finish_gate_z), Vector3(gate_half, 1.6, finish_gate_z), MAT_GOAL)


func _compose_long_road(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	var lane_columns: PackedFloat32Array = PackedFloat32Array([-8.0, 0.0, 8.0])
	var edge_x: float = 10.5
	var light_x: float = 15.0

	for segment in segments:
		_tile_authored_range(
			float(segment["z0"]),
			float(segment["z1"]),
			lane_columns,
			0.04,
			0.0,
			false
		)
		_place_sparse_shoulders(float(segment["z0"]), float(segment["z1"]), 11.5, 0.22)

	_compose_gap_visuals(gaps, edge_x, false)
	_place_edge_guides(segments, edge_x, 7.5, 0.35)
	_place_street_lights_authored(-72.0, 72.0, light_x, 28.0, 5.0)
	_place_scattered_props(
		[
			{"scene": SCENE_CONTAINER_RED, "pos": Vector3(-26.0, 0.0, -58.0), "scale": 1.1, "yaw": 14.0},
			{"scene": SCENE_CONTAINER_GREEN, "pos": Vector3(27.0, 0.0, 52.0), "scale": 1.05, "yaw": -12.0},
		]
	)


func _compose_broken_bridge(segments: Array[Dictionary], gaps: Array[Dictionary]) -> void:
	var deck_columns: PackedFloat32Array = PackedFloat32Array([-4.0, 0.0, 4.0])
	var edge_x: float = 6.2
	var light_x: float = 11.0
	var damage_clusters: Array[Dictionary] = [
		{"z": -62.0, "radius": 10.0, "side_loss": 0.55, "crack": 0.7},
		{"z": -24.0, "radius": 12.0, "side_loss": 0.75, "crack": 0.85},
		{"z": 16.0, "radius": 11.0, "side_loss": 0.65, "crack": 0.8},
		{"z": 58.0, "radius": 9.0, "side_loss": 0.5, "crack": 0.65},
	]

	for segment in segments:
		_tile_authored_range(
			float(segment["z0"]),
			float(segment["z1"]),
			deck_columns,
			0.12,
			0.42,
			true,
			damage_clusters
		)

	_compose_gap_visuals(gaps, edge_x, true)
	_place_bridge_edge_rails(segments, edge_x)
	_place_street_lights_authored(-70.0, 70.0, light_x, 22.0, 7.0)
	_place_bridge_void_props(damage_clusters)
	_place_deck_supports(segments, edge_x)


func _tile_authored_range(
	z_start: float,
	z_end: float,
	columns: PackedFloat32Array,
	base_crack_density: float,
	side_tile_loss: float,
	is_bridge: bool,
	damage_clusters: Array[Dictionary] = []
) -> void:
	var z: float = z_start
	var row_index: int = 0
	while z < z_end - 0.01:
		var tile_center_z: float = z + TILE_HALF
		for column_index in range(columns.size()):
			var x: float = columns[column_index]
			if _should_skip_tile(x, tile_center_z, columns, side_tile_loss, damage_clusters):
				continue
			var crack_density: float = _cluster_crack_density(
				tile_center_z, base_crack_density, damage_clusters
			)
			var variant: StreetVariant = _pick_authored_variant(
				row_index, column_index, tile_center_z, crack_density, is_bridge
			)
			_place_street_tile(x, 0.0, tile_center_z, variant)
		z += TILE_SIZE
		row_index += 1


func _place_sparse_shoulders(z_start: float, z_end: float, shoulder_x: float, chance: float) -> void:
	var z: float = z_start + 4.0
	while z < z_end - 4.0:
		if _hashf(int(z), 17) < chance:
			for side in [-1.0, 1.0]:
				if _hashf(int(z + side * 3.0), 23) < chance * 0.85:
					_place_street_tile(side * shoulder_x, 0.0, z, StreetVariant.STRAIGHT)
		z += TILE_SIZE * 2.0


func _compose_gap_visuals(gaps: Array[Dictionary], edge_x: float, heavy: bool) -> void:
	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap["z0"])
		var z1: float = float(gap["z1"])
		var gap_center: float = (z0 + z1) * 0.5
		var lane_offsets: Array[float] = [-8.0, 0.0, 8.0] if _style == MapStyle.LONG_ROAD else [-4.0, 0.0, 4.0]

		for edge_z in [z0 - TILE_HALF, z1 + TILE_HALF]:
			for x in lane_offsets:
				var variant: StreetVariant = (
					StreetVariant.CRACK1 if _hashf(int(edge_z + x), 41 + gap_index) > 0.5 else StreetVariant.CRACK2
				)
				_place_street_tile(x, 0.0, edge_z, variant)

		_place_cone(z0 - 0.5, -2.5)
		_place_cone(z0 - 0.5, 2.5)
		_place_cone(z1 + 0.5, -2.5)
		_place_cone(z1 + 0.5, 2.5)
		_place_plastic_barrier(gap_center, -edge_x)
		_place_plastic_barrier(gap_center, edge_x)

		if heavy:
			_place_prop(SCENE_PIPES, Vector3(-edge_x - 5.5, 0.0, gap_center), 1.45, 88.0)
			_place_prop(SCENE_PIPES, Vector3(edge_x + 5.5, 0.0, gap_center), 1.4, -92.0)
			if gap_index % 2 == 0:
				_place_prop(SCENE_PALLET_BROKEN, Vector3(-edge_x - 3.0, 0.0, gap_center + 1.5), 1.2, 30.0)
				_place_prop(SCENE_CINDER_BLOCK, Vector3(edge_x + 3.5, 0.0, gap_center - 1.0), 1.15, -20.0)


func _place_edge_guides(
	segments: Array[Dictionary],
	edge_x: float,
	spacing: float,
	skip_chance: float
) -> void:
	for segment in segments:
		var z: float = float(segment["z0"]) + 3.0
		var z_end: float = float(segment["z1"]) - 2.0
		while z < z_end:
			if _hashf(int(z * 10.0), 57) > skip_chance:
				_place_traffic_barrier(z, -edge_x, false)
				if _hashf(int(z * 7.0), 61) > 0.25:
					_place_traffic_barrier(z + 2.2, edge_x, true)
			z += spacing + _hashf(int(z), 3) * 2.0


func _place_bridge_edge_rails(segments: Array[Dictionary], edge_x: float) -> void:
	for segment in segments:
		var z: float = float(segment["z0"]) + 1.5
		var z_end: float = float(segment["z1"]) - 1.0
		while z < z_end:
			_place_traffic_barrier(z, -edge_x, false)
			_place_traffic_barrier(z + 1.8, edge_x, true)
			if _hashf(int(z), 71) > 0.55:
				_place_plastic_barrier(z + 3.5, -edge_x - 0.8)
			z += 6.0 + _hashf(int(z), 5) * 1.5


func _place_street_lights_authored(
	z_start: float,
	z_end: float,
	light_x: float,
	spacing: float,
	jitter: float
) -> void:
	var z: float = z_start + 6.0
	var side_toggle: bool = false
	while z < z_end:
		var offset: float = (_hashf(int(z), 11) - 0.5) * jitter * 2.0
		var x: float = -light_x if side_toggle else light_x
		_place_street_light(z + offset, x, 90.0 if x < 0.0 else -90.0)
		side_toggle = not side_toggle
		z += spacing + _hashf(int(z), 19) * 3.0


func _place_bridge_void_props(damage_clusters: Array[Dictionary]) -> void:
	_place_scattered_props(
		[
			{"scene": SCENE_CONTAINER_RED, "pos": Vector3(-22.0, 0.0, -36.0), "scale": 1.05, "yaw": 18.0},
			{"scene": SCENE_CONTAINER_GREEN, "pos": Vector3(23.0, 0.0, 28.0), "scale": 1.0, "yaw": -16.0},
			{"scene": SCENE_PALLET_BROKEN, "pos": Vector3(-19.0, 0.0, 44.0), "scale": 1.25, "yaw": 40.0},
		]
	)
	for cluster in damage_clusters:
		var cluster_z: float = float(cluster["z"])
		if _hashf(int(cluster_z), 29) > 0.4:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(-14.5, 0.0, cluster_z + 2.0), 1.1, 12.0)
		if _hashf(int(cluster_z), 31) > 0.45:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(14.5, 0.0, cluster_z - 2.5), 1.1, -8.0)


func _place_deck_supports(segments: Array[Dictionary], edge_x: float) -> void:
	for segment in segments:
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		for side in [-1.0, 1.0]:
			_place_prop(SCENE_CINDER_BLOCK, Vector3(side * (edge_x + 1.2), -0.5, center_z), 1.35, 0.0)
			_place_prop(SCENE_CINDER_BLOCK, Vector3(side * (edge_x + 1.2), -0.5, center_z + 14.0), 1.2, 15.0)


func _place_scattered_props(entries: Array[Dictionary]) -> void:
	for entry in entries:
		_place_prop(
			entry.get("scene") as PackedScene,
			entry.get("pos", Vector3.ZERO) as Vector3,
			float(entry.get("scale", 1.0)),
			float(entry.get("yaw", 0.0))
		)


func _should_skip_tile(
	x: float,
	z: float,
	columns: PackedFloat32Array,
	side_tile_loss: float,
	damage_clusters: Array[Dictionary]
) -> bool:
	if columns.size() <= 0:
		return true
	var outer_x: float = columns[columns.size() - 1]
	var is_outer: bool = abs(x) >= abs(outer_x) - 0.1
	var is_center: bool = abs(x) < 0.1
	if is_center:
		for cluster in damage_clusters:
			if abs(z - float(cluster["z"])) <= float(cluster["radius"]) * 0.35:
				return _hashf(int(z * 2.0), int(x * 10.0) + 97) < 0.12
		return false
	if not is_outer:
		return false
	var loss: float = side_tile_loss
	for cluster in damage_clusters:
		var dist: float = abs(z - float(cluster["z"]))
		if dist <= float(cluster["radius"]):
			loss = max(loss, float(cluster["side_loss"]))
	if loss <= 0.0:
		return false
	return _hashf(int(z * 3.0), int(x * 7.0) + 13) < loss


func _cluster_crack_density(z: float, base_density: float, damage_clusters: Array[Dictionary]) -> float:
	var density: float = base_density
	for cluster in damage_clusters:
		var dist: float = abs(z - float(cluster["z"]))
		var radius: float = float(cluster["radius"])
		if dist <= radius:
			var falloff: float = 1.0 - clamp(dist / radius, 0.0, 1.0)
			density = max(density, float(cluster["crack"]) * falloff)
	return density


func _pick_authored_variant(
	row_index: int,
	column_index: int,
	z: float,
	crack_density: float,
	is_bridge: bool
) -> StreetVariant:
	if is_bridge and column_index == 1 and _hashf(row_index + int(z), 47) < 0.08:
		return StreetVariant.STRAIGHT
	if crack_density <= 0.0:
		return StreetVariant.STRAIGHT
	var roll: float = _hashf(row_index + column_index + int(z * 0.5), 53)
	if roll > crack_density:
		return StreetVariant.STRAIGHT
	return StreetVariant.CRACK1 if _hashf(row_index + int(z), 59) > 0.5 else StreetVariant.CRACK2


func _hashf(a: int, b: int = 0) -> float:
	var hashed: int = int(hash(int(a * 374761393 + b * 668265263))) & 0x7fffffff
	return float(hashed % 1000) / 1000.0


func _place_street_tile(x: float, y: float, z: float, variant: StreetVariant) -> void:
	_place_prop(_scene_for_variant(variant), Vector3(x, y, z), 1.0, 0.0)


func _scene_for_variant(variant: StreetVariant) -> PackedScene:
	match variant:
		StreetVariant.CRACK1:
			return SCENE_STREET_CRACK1
		StreetVariant.CRACK2:
			return SCENE_STREET_CRACK2
		_:
			return SCENE_STREET_STRAIGHT


func _place_plastic_barrier(z: float, x: float) -> void:
	_place_prop(SCENE_PLASTIC_BARRIER, Vector3(x, 0.0, z), 1.4, 90.0 if x < 0.0 else -90.0)


func _place_traffic_barrier(z: float, x: float, flip: bool) -> void:
	var scene: PackedScene = SCENE_TRAFFIC_BARRIER_1 if _hashf(int(z), 67) > 0.5 else SCENE_TRAFFIC_BARRIER_2
	_place_prop(scene, Vector3(x, 0.0, z), 1.3, 90.0 if flip else -90.0)


func _place_cone(z: float, x: float) -> void:
	_place_prop(SCENE_TRAFFIC_CONE_1, Vector3(x, 0.0, z), 1.15, _hashf(int(z + x), 73) * 40.0)


func _place_street_light(z: float, x: float, yaw_degrees: float) -> void:
	_place_prop(SCENE_STREET_LIGHT, Vector3(x, 0.0, z), 1.3, yaw_degrees)


func _place_prop(scene: PackedScene, position: Vector3, scale_value: float, yaw_degrees: float) -> void:
	if scene == null or _visual_root == null:
		return
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		return
	instance.position = position
	instance.scale = Vector3.ONE * scale_value
	instance.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	_visual_root.add_child(instance)


func _add_invisible_collision_box(box_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_collision_root.add_child(body)


func _add_marker_box(box_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var marker := MeshInstance3D.new()
	marker.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = position
	marker.material_override = material
	_root.add_child(marker)


func _add_gate(left_pos: Vector3, right_pos: Vector3, accent: Material) -> void:
	_add_marker_box("GatePost", Vector3(0.28, 3.2, 0.28), left_pos, MAT_CONCRETE)
	_add_marker_box("GatePost", Vector3(0.28, 3.2, 0.28), right_pos, MAT_CONCRETE)
	var center := (left_pos + right_pos) * 0.5
	center.y = max(left_pos.y, right_pos.y) + 1.55
	var header_width: float = abs(right_pos.x - left_pos.x) + 0.8
	_add_marker_box("GateHeader", Vector3(header_width, 0.42, 0.42), center, accent)


func _add_omni(light_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	_root.add_child(light)


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node
