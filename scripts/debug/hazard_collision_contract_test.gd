extends SceneTree

const HAZARD_SCENES := [
	preload("res://scenes/hazards/mine_trap.tscn"),
	preload("res://scenes/hazards/sewer_hole_trap.tscn"),
	preload("res://scenes/hazards/road_obstacle.tscn"),
	preload("res://scenes/hazards/traffic_cone_obstacle.tscn"),
	preload("res://scenes/hazards/vehicle_obstacle.tscn"),
	preload("res://scenes/hazards/mine_explosion_effect.tscn"),
	preload("res://scenes/powerups/boost_pad.tscn"),
]

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for hazard_scene in HAZARD_SCENES:
		var instance: Node = hazard_scene.instantiate()
		root.add_child(instance)
		await process_frame
		_assert_no_hidden_navigation_obstacles(instance)
		_assert_no_solid_hazard_collision(instance)
		instance.queue_free()

	_finish()


func _assert_no_hidden_navigation_obstacles(node: Node) -> void:
	if node is NavigationObstacle3D:
		_fail("Hazards must not add NavigationObstacle3D avoidance blockers: %s" % node.get_path())
	for child in node.get_children():
		_assert_no_hidden_navigation_obstacles(child)


func _assert_no_solid_hazard_collision(node: Node) -> void:
	if node is Area3D:
		var area := node as Area3D
		if area.collision_layer != 0:
			_fail("Hazard triggers must use a detection mask only: %s" % node.get_path())
	if node is StaticBody3D or node is CharacterBody3D or node is RigidBody3D:
		var collision_object := node as CollisionObject3D
		if collision_object.collision_layer != 0:
			_fail("Hazards must use trigger areas, not solid collision: %s" % node.get_path())
	for child in node.get_children():
		_assert_no_solid_hazard_collision(child)


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Hazard collision contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
