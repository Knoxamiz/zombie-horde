class_name BrokenBridgeArena
extends Node3D

const ROAD_WIDTH: float = 32.0
const ROAD_THICKNESS: float = 0.12
const BRIDGE_HEIGHT: float = 6.0
const RAIL_OFFSET: float = 16.7
const RAIL_HEIGHT: float = 0.9
const RAIL_THICKNESS: float = 0.45
const GROUND_WIDTH: float = 64.0
const TRACK_LENGTH: float = 192.0
const SPAWN_Z: float = -84.0
const GOAL_Z: float = 84.0

const MAT_GROUND := preload("res://assets/materials/arena_ground.tres")
const MAT_ROAD := preload("res://assets/materials/road_asphalt.tres")
const MAT_LINE := preload("res://assets/materials/road_line.tres")
const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")
const MAT_DARK := preload("res://assets/materials/city_building_dark.tres")

var _segments: Array[Dictionary] = [
	{"z0": -58.0, "z1": -34.0, "y": BRIDGE_HEIGHT},
	{"z0": -22.0, "z1": 6.0, "y": BRIDGE_HEIGHT},
	{"z0": 18.0, "z1": 46.0, "y": BRIDGE_HEIGHT},
	{"z0": 58.0, "z1": 74.0, "y": BRIDGE_HEIGHT},
]

var _gaps: Array[Dictionary] = [
	{"z0": -34.0, "z1": -26.0},
	{"z0": 6.0, "z1": 14.0},
	{"z0": 46.0, "z1": 54.0},
]


func _ready() -> void:
	_build_environment()
	_build_water()
	_build_ground_apron()
	_build_approaches()
	_build_bridge_segments()
	_build_gaps()
	_build_ramps()
	_build_rails()
	_build_markers()
	_build_pillars()


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_color = Color(0.64, 0.7, 0.82, 1.0)
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	add_child(sun)

	_add_omni(Vector3(0.0, 8.0, -72.0), Color(0.52, 1.0, 0.35, 1.0), 2.4, 28.0)
	_add_omni(Vector3(0.0, 8.0, 72.0), Color(1.0, 0.32, 0.12, 1.0), 2.1, 28.0)
	_add_omni(Vector3(-18.0, 7.0, -20.0), Color(1.0, 0.64, 0.18, 1.0), 1.5, 22.0)
	_add_omni(Vector3(18.0, 7.0, 28.0), Color(1.0, 0.64, 0.18, 1.0), 1.4, 22.0)


func _add_omni(position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	add_child(light)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(GROUND_WIDTH + 24.0, 0.08, TRACK_LENGTH + 24.0)
	water.mesh = mesh
	water.position = Vector3(0.0, -5.5, 0.0)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.03, 0.08, 0.12, 0.92)
	water_mat.metallic = 0.35
	water_mat.roughness = 0.18
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.02, 0.08, 0.14, 1.0)
	water_mat.emission_energy_multiplier = 0.35
	water.material_override = water_mat
	add_child(water)


func _build_ground_apron() -> void:
	_add_static_box(
		"GroundApron",
		Vector3(GROUND_WIDTH, 0.18, TRACK_LENGTH),
		Vector3(0.0, -0.11, 0.0),
		MAT_GROUND
	)


func _build_approaches() -> void:
	_add_static_box(
		"StartApproach",
		Vector3(ROAD_WIDTH, ROAD_THICKNESS, 14.0),
		Vector3(0.0, 0.0, -77.0),
		MAT_ROAD
	)
	_add_static_box(
		"FinishApproach",
		Vector3(ROAD_WIDTH, ROAD_THICKNESS, 8.0),
		Vector3(0.0, 0.0, 80.0),
		MAT_ROAD
	)


func _build_bridge_segments() -> void:
	for index in range(_segments.size()):
		var segment: Dictionary = _segments[index]
		var length: float = float(segment["z1"]) - float(segment["z0"])
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		var deck_y: float = float(segment["y"])
		_add_static_box(
			"BridgeDeck_%d" % index,
			Vector3(ROAD_WIDTH, ROAD_THICKNESS, length),
			Vector3(0.0, deck_y, center_z),
			MAT_ROAD
		)
		_add_line_strip(center_z, length, deck_y + 0.08)


func _build_gaps() -> void:
	for index in range(_gaps.size()):
		var gap: Dictionary = _gaps[index]
		var length: float = float(gap["z1"]) - float(gap["z0"])
		var center_z: float = (float(gap["z0"]) + float(gap["z1"])) * 0.5
		_add_static_box(
			"GapMarker_%d" % index,
			Vector3(ROAD_WIDTH - 2.0, 0.04, length),
			Vector3(0.0, BRIDGE_HEIGHT - 0.2, center_z),
			MAT_DARK,
			false
		)


func _build_ramps() -> void:
	_add_ramp("StartRamp", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 18.0), Vector3(0.0, 3.0, -64.0), -19.0)
	_add_ramp("GapRampA", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, -30.0), 22.0)
	_add_ramp("GapRampB", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, 10.0), 22.0)
	_add_ramp("GapRampC", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, 50.0), 22.0)
	_add_ramp("GapRampD", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, -22.0), -22.0)
	_add_ramp("GapRampE", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, 14.0), -22.0)
	_add_ramp("GapRampF", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 6.0), Vector3(0.0, 4.2, 54.0), -22.0)
	_add_ramp("FinishRamp", Vector3(ROAD_WIDTH, ROAD_THICKNESS, 16.0), Vector3(0.0, 3.0, 76.0), 19.0)


func _build_rails() -> void:
	for segment in _segments:
		var length: float = float(segment["z1"]) - float(segment["z0"])
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		var deck_y: float = float(segment["y"]) + 0.45
		_add_static_box(
			"LeftRail",
			Vector3(RAIL_THICKNESS, RAIL_HEIGHT, length),
			Vector3(-RAIL_OFFSET, deck_y, center_z),
			MAT_CONCRETE
		)
		_add_static_box(
			"RightRail",
			Vector3(RAIL_THICKNESS, RAIL_HEIGHT, length),
			Vector3(RAIL_OFFSET, deck_y, center_z),
			MAT_CONCRETE
		)

	_add_static_box(
		"StartRailLeft",
		Vector3(RAIL_THICKNESS, RAIL_HEIGHT, 14.0),
		Vector3(-RAIL_OFFSET, 0.45, -77.0),
		MAT_CONCRETE
	)
	_add_static_box(
		"StartRailRight",
		Vector3(RAIL_THICKNESS, RAIL_HEIGHT, 14.0),
		Vector3(RAIL_OFFSET, 0.45, -77.0),
		MAT_CONCRETE
	)


func _build_markers() -> void:
	_add_static_box(
		"SpawnZone",
		Vector3(28.0, 0.06, 8.0),
		Vector3(0.0, 0.12, SPAWN_Z),
		MAT_SPAWN,
		false
	)
	_add_static_box(
		"GoalGuide",
		Vector3(28.0, 0.06, 8.0),
		Vector3(0.0, 0.13, GOAL_Z),
		MAT_GOAL,
		false
	)
	_add_static_box(
		"StartLine",
		Vector3(28.0, 0.07, 0.45),
		Vector3(0.0, 0.12, -76.0),
		MAT_SPAWN,
		false
	)
	_add_static_box(
		"FinishLine",
		Vector3(28.0, 0.07, 0.45),
		Vector3(0.0, 0.12, 76.0),
		MAT_GOAL,
		false
	)
	_add_gate(Vector3(-15.2, 3.2, -76.0), Vector3(15.2, 3.2, -76.0), MAT_SPAWN)
	_add_gate(Vector3(-15.2, 3.2, 76.0), Vector3(15.2, 3.2, 76.0), MAT_GOAL)


func _build_pillars() -> void:
	for segment in _segments:
		var center_z: float = (float(segment["z0"]) + float(segment["z1"])) * 0.5
		for side in [-1.0, 1.0]:
			_add_static_box(
				"Pillar",
				Vector3(1.2, BRIDGE_HEIGHT, 1.2),
				Vector3(side * (ROAD_WIDTH * 0.5 + 1.8), BRIDGE_HEIGHT * 0.5 - 0.2, center_z),
				MAT_CONCRETE
			)


func _add_gate(left_pos: Vector3, right_pos: Vector3, accent: Material) -> void:
	_add_static_box("GatePost", Vector3(0.28, 3.2, 0.28), left_pos, MAT_CONCRETE, false)
	_add_static_box("GatePost", Vector3(0.28, 3.2, 0.28), right_pos, MAT_CONCRETE, false)
	var center := (left_pos + right_pos) * 0.5
	center.y = max(left_pos.y, right_pos.y) + 1.55
	_add_static_box("GateHeader", Vector3(31.0, 0.42, 0.42), center, accent, false)


func _add_line_strip(center_z: float, length: float, y: float) -> void:
	var center := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.04, length - 1.0)
	center.mesh = mesh
	center.position = Vector3(0.0, y, center_z)
	center.material_override = MAT_LINE
	add_child(center)

	for side in [-13.5, 13.5]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.18, 0.05, length - 1.0)
		edge.mesh = edge_mesh
		edge.position = Vector3(side, y + 0.02, center_z)
		edge.material_override = MAT_LINE
		add_child(edge)


func _add_ramp(name: String, size: Vector3, position: Vector3, pitch_degrees: float) -> void:
	_add_static_box(name, size, position, MAT_ROAD, true, Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0))


func _add_static_box(
	name: String,
	size: Vector3,
	position: Vector3,
	material: Material,
	with_collision: bool = true,
	rotation_radians: Vector3 = Vector3.ZERO
) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	body.rotation = rotation_radians
	body.collision_layer = 1 if with_collision else 0
	body.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	if with_collision:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)

	add_child(body)
