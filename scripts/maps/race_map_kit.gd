class_name RaceMapKit
extends RefCounted

enum StreetVariant { STRAIGHT, CRACK1, CRACK2 }

const TILE_SIZE: float = 8.0
const TILE_HALF: float = TILE_SIZE * 0.5
const ROAD_TILE_COLUMNS: int = 4
const APRON_TILE_COLUMNS: int = 8

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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func attach(root: Node3D) -> void:
	_root = root
	_rng.randomize()
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
	_add_omni("RoadAmberLightA", Vector3(-17.6, 4.4, -20.0), Color(1.0, 0.64, 0.18, 1.0), 1.45, 28.0)
	_add_omni("RoadAmberLightB", Vector3(17.6, 4.4, 36.0), Color(1.0, 0.64, 0.18, 1.0), 1.35, 28.0)


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


func build_segmented_play_surface(
	road_width: float,
	segments: Array[Dictionary],
	y: float = 0.0,
	thickness: float = 0.12
) -> void:
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var length: float = float(segment["z1"]) - float(segment["z0"])
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		_add_invisible_collision_box(
			"PlaySurface_%d" % index,
			Vector3(road_width, thickness, length),
			Vector3(0.0, y, center_z)
		)


func tile_highway(
	segments: Array[Dictionary],
	gaps: Array[Dictionary],
	full_apron: bool,
	crack_density: float,
	gap_edge_cracks: bool
) -> void:
	var gap_ranges: Array[Dictionary] = gaps.duplicate()
	for segment in segments:
		_tile_range(
			float(segment["z0"]),
			float(segment["z1"]),
			full_apron,
			crack_density,
			false
		)

	if gap_edge_cracks:
		for gap in gap_ranges:
			_tile_gap_edges(float(gap["z0"]), float(gap["z1"]), full_apron)


func build_gap_dressing(gaps: Array[Dictionary], heavy: bool) -> void:
	for gap in gaps:
		var gap_center: float = (float(gap["z0"]) + float(gap["z1"])) * 0.5
		var gap_length: float = float(gap["z1"]) - float(gap["z0"])
		_place_barrier_row(gap_center, -17.5)
		_place_barrier_row(gap_center, 17.5)
		_place_cone(float(gap["z0"]) - 1.0, -11.0)
		_place_cone(float(gap["z0"]) - 1.0, 11.0)
		_place_cone(float(gap["z1"]) + 1.0, -11.0)
		_place_cone(float(gap["z1"]) + 1.0, 11.0)

		if heavy:
			_place_prop(SCENE_PALLET_BROKEN, Vector3(-10.0, 0.0, gap_center), 1.35, 0.0)
			_place_prop(SCENE_PALLET_BROKEN, Vector3(10.5, 0.0, gap_center), 1.2, 180.0)
			_place_prop(SCENE_CINDER_BLOCK, Vector3(8.0, 0.0, gap_center + gap_length * 0.2), 1.25, 25.0)
			_place_prop(SCENE_PIPES, Vector3(-20.0, 0.0, gap_center), 1.6, 90.0)
			_place_prop(SCENE_PIPES, Vector3(20.0, 0.0, gap_center), 1.5, -90.0)


func build_edge_rails(segments: Array[Dictionary]) -> void:
	for segment in segments:
		var z: float = float(segment["z0"])
		var z_end: float = float(segment["z1"])
		while z < z_end - 0.5:
			_place_traffic_barrier(z + 2.0, -15.8, false)
			_place_traffic_barrier(z + 2.0, 15.8, true)
			z += 5.5


func build_street_lights(z_start: float, z_end: float, spacing: float = 24.0) -> void:
	var z: float = z_start + 8.0
	while z < z_end:
		_place_street_light(z, -21.5, 90.0)
		_place_street_light(z + spacing * 0.5, 21.5, -90.0)
		z += spacing


func build_roadside_props(z_start: float, z_end: float, heavy: bool) -> void:
	if not heavy:
		return
	_place_prop(SCENE_CONTAINER_RED, Vector3(-24.0, 0.0, z_start + 18.0), 1.15, 12.0)
	_place_prop(SCENE_CONTAINER_GREEN, Vector3(24.0, 0.0, z_end - 22.0), 1.1, -18.0)


func build_markers(
	road_width: float,
	spawn_z: float,
	goal_z: float,
	start_gate_z: float,
	finish_gate_z: float
) -> void:
	_add_marker_box("SpawnZone", Vector3(road_width - 4.0, 0.06, 8.0), Vector3(0.0, 0.12, spawn_z), MAT_SPAWN)
	_add_marker_box("GoalGuide", Vector3(road_width - 4.0, 0.06, 8.0), Vector3(0.0, 0.13, goal_z), MAT_GOAL)
	_add_marker_box("StartLine", Vector3(road_width - 4.0, 0.07, 0.45), Vector3(0.0, 0.12, start_gate_z), MAT_SPAWN)
	_add_marker_box("FinishLine", Vector3(road_width - 4.0, 0.07, 0.45), Vector3(0.0, 0.12, finish_gate_z), MAT_GOAL)
	_add_gate(Vector3(-15.2, 1.6, start_gate_z), Vector3(15.2, 1.6, start_gate_z), MAT_SPAWN)
	_add_gate(Vector3(-15.2, 1.6, finish_gate_z), Vector3(15.2, 1.6, finish_gate_z), MAT_GOAL)


func _tile_range(
	z_start: float,
	z_end: float,
	full_apron: bool,
	crack_density: float,
	force_crack: bool
) -> void:
	var column_centers: PackedFloat32Array = _get_tile_column_centers(full_apron)
	var z: float = z_start
	var row_index: int = 0
	while z < z_end - 0.01:
		var tile_center_z: float = z + TILE_HALF
		for column_index in range(column_centers.size()):
			var x: float = column_centers[column_index]
			var variant: StreetVariant = _pick_street_variant(row_index, column_index, crack_density, force_crack)
			_place_street_tile(x, 0.0, tile_center_z, variant)
		z += TILE_SIZE
		row_index += 1


func _tile_gap_edges(z0: float, z1: float, full_apron: bool) -> void:
	var column_centers: PackedFloat32Array = _get_tile_column_centers(full_apron)
	for edge_z in [z0 - TILE_HALF, z1 + TILE_HALF]:
		for column_index in range(column_centers.size()):
			var variant: StreetVariant = StreetVariant.CRACK1 if column_index % 2 == 0 else StreetVariant.CRACK2
			_place_street_tile(column_centers[column_index], 0.0, edge_z, variant)


func _get_tile_column_centers(full_apron: bool) -> PackedFloat32Array:
	if full_apron:
		return PackedFloat32Array([-28.0, -20.0, -12.0, -4.0, 4.0, 12.0, 20.0, 28.0])
	return PackedFloat32Array([-12.0, -4.0, 4.0, 12.0])


func _pick_street_variant(row_index: int, column_index: int, crack_density: float, force_crack: bool) -> StreetVariant:
	if force_crack:
		return StreetVariant.CRACK1 if (row_index + column_index) % 2 == 0 else StreetVariant.CRACK2
	if crack_density <= 0.0:
		return StreetVariant.STRAIGHT
	if _rng.randf() > crack_density:
		return StreetVariant.STRAIGHT
	return StreetVariant.CRACK1 if _rng.randi_range(0, 1) == 0 else StreetVariant.CRACK2


func _place_street_tile(x: float, y: float, z: float, variant: StreetVariant) -> void:
	var scene: PackedScene = _scene_for_variant(variant)
	_place_prop(scene, Vector3(x, y, z), 1.0, 0.0)


func _scene_for_variant(variant: StreetVariant) -> PackedScene:
	match variant:
		StreetVariant.CRACK1:
			return SCENE_STREET_CRACK1
		StreetVariant.CRACK2:
			return SCENE_STREET_CRACK2
		_:
			return SCENE_STREET_STRAIGHT


func _place_barrier_row(z: float, x: float) -> void:
	_place_prop(SCENE_PLASTIC_BARRIER, Vector3(x, 0.0, z), 1.45, 90.0 if x < 0.0 else -90.0)


func _place_traffic_barrier(z: float, x: float, flip: bool) -> void:
	var scene: PackedScene = SCENE_TRAFFIC_BARRIER_1 if int(z) % 11 < 6 else SCENE_TRAFFIC_BARRIER_2
	_place_prop(scene, Vector3(x, 0.0, z), 1.35, 90.0 if flip else -90.0)


func _place_cone(z: float, x: float) -> void:
	_place_prop(SCENE_TRAFFIC_CONE_1, Vector3(x, 0.0, z), 1.2, 0.0)


func _place_street_light(z: float, x: float, yaw_degrees: float) -> void:
	_place_prop(SCENE_STREET_LIGHT, Vector3(x, 0.0, z), 1.35, yaw_degrees)


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
	_add_marker_box("GateHeader", Vector3(31.0, 0.42, 0.42), center, accent)


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
