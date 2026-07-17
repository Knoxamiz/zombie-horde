extends SceneTree

## Visual contract for playable-map dressing. The art layer must remain
## presentation-only: distinctive enough to identify a map, but never able to
## alter walk collision, navigation, hazards, finish, or OOB behavior.

var _map_cases: Array[Dictionary] = [
	{
		"id": "quarantine_boulevard",
		"nodes": PackedStringArray([
			"SuburbanGround", "SuburbanSidewalk", "SuburbanHouseCottage",
			"SuburbanHouseFamily", "SuburbanHouseTwoStory", "SuburbanHouseRanch",
			"SuburbanDriveway", "FencePost", "Mailbox", "SuburbanTreeCanopy",
			"PicketFenceSlat", "BackyardPrivacyFence", "SuburbanGrassVerge", "SuburbanCurb", "SuburbanParkedCar",
			"YardDog", "SuburbanWaterTower", "NeighborhoodEntrySign",
		]),
	},
	{
		"id": "broken_bridge_pass",
		"nodes": PackedStringArray(["CoastalWater", "CoastalBoatHull", "CoastalBuoy"]),
	},
	{
		"id": "spiral_descent",
		"nodes": PackedStringArray(["HighwaySupport", "CollapsedBarrier", "HighwayCityBlock"]),
	},
	{
		"id": "true_spiral_ramp",
		"nodes": PackedStringArray(["ConstructionCraneTower", "GarageCornerPillar", "GarageEdgeBeam"]),
	},
]

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_case in _map_cases:
		await _validate_map_art(map_case)
	if _failures.is_empty():
		print("PASS: Map art dressing contract")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _validate_map_art(map_case: Dictionary) -> void:
	var map_id: String = str(map_case["id"])
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(map_id)
	if definition == null or definition.scene == null:
		_fail("%s art definition or scene is missing" % map_id)
		return
	var arena: Node3D = definition.scene.instantiate() as Node3D
	if arena == null:
		_fail("%s art scene did not instantiate" % map_id)
		return
	root.add_child(arena)
	await process_frame
	var dressing: Node3D = arena.get_node_or_null("MapDressing") as Node3D
	if dressing == null:
		_fail("%s is missing MapDressing" % map_id)
		arena.queue_free()
		return
	for node_prefix in map_case["nodes"] as PackedStringArray:
		if dressing.find_children("%s*" % node_prefix, "", true, false).is_empty():
			_fail("%s did not build required art node '%s'" % [map_id, node_prefix])
	if map_id == "quarantine_boulevard":
		_validate_suburban_environment(arena, definition)
	_validate_visual_only(dressing, map_id)
	arena.queue_free()
	await process_frame


func _validate_visual_only(node: Node, map_id: String) -> void:
	var collision_object := node as CollisionObject3D
	if collision_object != null and (collision_object.collision_layer != 0 or collision_object.collision_mask != 0):
		_fail("%s art node '%s' owns collision" % [map_id, node.name])
	var collision_shape := node as CollisionShape3D
	if collision_shape != null and not collision_shape.disabled:
		_fail("%s art node '%s' owns an enabled collision shape" % [map_id, node.name])
	for child in node.get_children():
		_validate_visual_only(child, map_id)


func _validate_suburban_environment(arena: Node3D, definition: RaceMapDefinition) -> void:
	for node_path in ["CoreRoad/CityBackdrop", "CoreRoad/SetDressing"]:
		var old_dressing: Node3D = arena.get_node_or_null(node_path) as Node3D
		if old_dressing != null:
			_fail("quarantine_boulevard must remove legacy dressing '%s'" % node_path)
	var dressing: Node3D = arena.get_node_or_null("MapDressing") as Node3D
	if dressing == null:
		return
	for rail_path in ["CoreRoad/LeftRail/LeftRailMesh", "CoreRoad/RightRail/RightRailMesh"]:
		var rail_mesh: MeshInstance3D = arena.get_node_or_null(rail_path) as MeshInstance3D
		if rail_mesh == null or rail_mesh.visible:
			_fail("quarantine_boulevard must hide visible side rail '%s'" % rail_path)
	for collision_path in ["CoreRoad/LeftRail/LeftRailCollision", "CoreRoad/RightRail/RightRailCollision"]:
		var rail_collision: CollisionShape3D = arena.get_node_or_null(collision_path) as CollisionShape3D
		if rail_collision == null or not rail_collision.disabled:
			_fail("quarantine_boulevard must disable legacy side rail '%s'" % collision_path)
	if definition.out_of_bounds_half_width < 33.6:
		_fail("quarantine_boulevard OOB boundary must sit outside its backyard privacy fence")


func _fail(message: String) -> void:
	_failures.append(message)
