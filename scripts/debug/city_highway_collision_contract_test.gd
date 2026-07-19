extends SceneTree

const CITY_HIGHWAY_SCENE := preload("res://scenes/maps/quarantine_boulevard.tscn")
const CITY_HIGHWAY_DEFINITION := preload("res://resources/maps/quarantine_boulevard.tres")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map: Node3D = CITY_HIGHWAY_SCENE.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	await process_frame

	var active_collision_paths: Array[String] = []
	_collect_active_collision_paths(map, active_collision_paths)
	var expected_paths := [
		"/root/RoadArena2/CoreRoad/Ground/GroundCollision",
		"/root/RoadArena2/CoreRoad/Road/RoadCollision",
		"/root/RoadArena2/NeighborhoodWalkableGround/CollisionShape3D",
	]
	for collision_path in active_collision_paths:
		if not expected_paths.has(collision_path):
			_fail("Unexpected active City Highway collision: %s" % collision_path)
	for expected_path in expected_paths:
		if not active_collision_paths.has(expected_path):
			_fail("Required walkable City Highway collision missing: %s" % expected_path)

	if CITY_HIGHWAY_DEFINITION.out_of_bounds_half_width < 33.6:
		_fail("City Highway OOB width must stay outside the backyard privacy fences")
	if CITY_HIGHWAY_DEFINITION.out_of_bounds_min_z > -92.0 or CITY_HIGHWAY_DEFINITION.out_of_bounds_max_z < 92.0:
		_fail("City Highway OOB length must include the full walkable neighborhood ground")

	map.queue_free()
	_finish()


func _collect_active_collision_paths(node: Node, result: Array[String]) -> void:
	if node is CollisionShape3D:
		var shape: CollisionShape3D = node as CollisionShape3D
		var owner: CollisionObject3D = shape.get_parent() as CollisionObject3D
		if not shape.disabled and owner != null and owner.collision_layer != 0:
			result.append(str(shape.get_path()))
	for child in node.get_children():
		_collect_active_collision_paths(child, result)


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: City Highway collision contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
