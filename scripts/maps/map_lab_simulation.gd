@tool
class_name MapLabSimulation
extends Node3D

const MOVER_SCRIPT := preload("res://scripts/maps/map_lab_sim_mover.gd")

var _blueprint: MapBlueprint
var _map_root: Node3D
var _movers: Array[MapLabSimMover] = []
var _active: bool = false
var _show_paths: bool = true
var _test_hazards: bool = true
var _hazard_zones: Array = []


func setup(
	blueprint: MapBlueprint,
	map_root: Node3D,
	mover_count: int,
	speed: float,
	show_paths: bool,
	test_hazards: bool
) -> void:
	_blueprint = blueprint
	_map_root = map_root
	_show_paths = show_paths
	_test_hazards = test_hazards
	_hazard_zones = blueprint.hazard_zones if blueprint != null else []
	_spawn_movers(mover_count, speed)
	if _show_paths:
		_build_path_markers()
	_active = not _movers.is_empty()
	set_process(_active)


func clear_simulation() -> void:
	_active = false
	set_process(false)
	_movers.clear()
	for child in get_children():
		child.queue_free()


func _process(delta: float) -> void:
	if not _active:
		return

	var all_finished: bool = true
	for mover in _movers:
		if mover == null or not is_instance_valid(mover):
			continue
		mover.tick(delta, _hazard_zones)
		if not mover.is_finished():
			all_finished = false

	if all_finished:
		_active = false
		set_process(false)
		_print_report()


func _spawn_movers(mover_count: int, speed: float) -> void:
	if _blueprint == null:
		return

	var safe_half_width: float = _blueprint.safe_path_width_meters * 0.5
	var spawn_z: float = _blueprint.spawn_z + 2.0
	var goal_z: float = _blueprint.goal_z - 1.0

	for index in range(mover_count):
		var lane_offset: float = float(index - int(mover_count / 2)) * 0.55
		var start := Vector3(lane_offset, 0.9, spawn_z - float(index) * 1.5)
		var mover: MapLabSimMover = MOVER_SCRIPT.new()
		mover.setup(
			"SimMover_%02d" % (index + 1),
			start,
			false,
			speed,
			goal_z,
			safe_half_width
		)
		add_child(mover)
		_movers.append(mover)

	if not _test_hazards or _hazard_zones.is_empty():
		return

	var hazard_targets: Array[Vector3] = []
	for hazard in _hazard_zones:
		if hazard is Dictionary:
			hazard_targets.append(hazard.get("position", Vector3.ZERO))
		if hazard_targets.size() >= 2:
			break

	for hazard_index in range(hazard_targets.size()):
		var target: Vector3 = hazard_targets[hazard_index]
		var start := Vector3(0.0, 0.9, _blueprint.spawn_z + 4.0 + float(hazard_index) * 2.0)
		var direction: Vector3 = (target - start)
		direction.y = 0.0
		var mover: MapLabSimMover = MOVER_SCRIPT.new()
		mover.setup(
			"SimHazardMover_%02d" % (hazard_index + 1),
			start,
			true,
			speed * 0.95,
			goal_z,
			safe_half_width,
			direction
		)
		add_child(mover)
		_movers.append(mover)


func _build_path_markers() -> void:
	if _blueprint == null:
		return

	var markers := Node3D.new()
	markers.name = "PathMarkers"
	add_child(markers)

	var safe_mat := _make_marker_material(Color(0.2, 0.95, 0.35, 0.45))
	var step: float = max(_blueprint.tile_size * 0.5, 4.0)
	var z: float = _blueprint.spawn_z
	while z <= _blueprint.goal_z + 0.01:
		_add_path_marker(markers, Vector3(0.0, 0.22, z), Vector3(0.35, 0.08, 0.35), safe_mat)
		z += step

	if _test_hazards:
		var hazard_mat := _make_marker_material(Color(1.0, 0.25, 0.2, 0.55))
		for hazard in _hazard_zones:
			if hazard is not Dictionary:
				continue
			var zone_position: Vector3 = hazard.get("position", Vector3.ZERO)
			var zone_size: Vector3 = hazard.get("size", Vector3(4, 2, 4))
			_add_path_marker(markers, zone_position, zone_size * 0.35, hazard_mat)
			var start := Vector3(0.0, 0.35, _blueprint.spawn_z + 4.0)
			_add_path_line(markers, start, zone_position, hazard_mat)


func _add_path_marker(parent: Node3D, marker_position: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = marker_position
	marker.material_override = material
	parent.add_child(marker)


func _add_path_line(
	parent: Node3D,
	start: Vector3,
	end: Vector3,
	material: StandardMaterial3D
) -> void:
	var line_root := Node3D.new()
	line_root.name = "HazardProbeLine"
	parent.add_child(line_root)
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.01:
		return
	var segment_count: int = max(int(length / 2.5), 2)
	for step_index in range(segment_count + 1):
		var t: float = float(step_index) / float(segment_count)
		var point: Vector3 = start.lerp(end, t)
		_add_path_marker(line_root, point, Vector3(0.2, 0.06, 0.2), material)


func _make_marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _print_report() -> void:
	var safe_spawned: int = 0
	var safe_reached: int = 0
	var safe_failed: int = 0
	var hazard_spawned: int = 0
	var hazard_hit: int = 0

	for mover in _movers:
		if mover == null:
			continue
		if mover.get_result_category() == "hazard":
			hazard_spawned += 1
			if mover.state == MapLabSimMover.State.FELL_HAZARD:
				hazard_hit += 1
			continue

		safe_spawned += 1
		if mover.state == MapLabSimMover.State.REACHED_GOAL:
			safe_reached += 1
		elif mover.is_finished():
			safe_failed += 1

	var passed: bool = (
		safe_spawned > 0
		and safe_reached == safe_spawned
		and safe_failed == 0
		and (hazard_spawned == 0 or hazard_hit == hazard_spawned)
	)

	print("=== MAP LAB SIMULATION RESULT ===")
	print("safe movers spawned: %d" % safe_spawned)
	print("safe movers reached goal: %d" % safe_reached)
	print("safe movers failed: %d" % safe_failed)
	print("hazard movers spawned: %d" % hazard_spawned)
	print("hazard movers hit hazard: %d" % hazard_hit)
	print("result: %s" % ("PASSED" if passed else "FAILED"))
