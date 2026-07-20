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
			"YardDog", "SuburbanWaterTower", "NeighborhoodEntrySign", "SuburbanStreetExtension",
			"QuarantineFencePost", "QuarantineBreachPanel", "QuarantineWarningSign", "QuarantineStartDeck",
			"QuarantineFinishApron", "SafehouseGateBeam", "SafehouseHeader",
		]),
	},
	{
		"id": "broken_bridge_pass",
		"nodes": PackedStringArray([
			"CoastalWater", "CoastalBoatHull", "CoastalBuoy", "BrokenApproachDeckRemnant",
			"BrokenApproachDeckFragment", "BrokenApproachTornRail", "BrokenBridgeEndApproachRoad",
			"BrokenBridgeEndApproachRail", "BrokenBridgeLowerStreet",
		]),
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
	if map_id == "broken_bridge_pass":
		_validate_broken_bridge_environment(arena)
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
	var street_extensions: Array[Node] = dressing.find_children("SuburbanStreetExtension*", "", true, false)
	if street_extensions.size() != 2:
		_fail("quarantine_boulevard must continue the street beyond both race gates")
	var street_center_lines: Array[Node] = dressing.find_children("SuburbanStreetCenterLine*", "", true, false)
	if street_center_lines.size() != 2:
		_fail("quarantine_boulevard street extensions must retain center-line continuity")
	var breach_panels: Array[Node] = dressing.find_children("QuarantineBreachPanel*", "", true, false)
	if breach_panels.size() != 2:
		_fail("quarantine_boulevard must frame its spawn with two broken fence panels")
	for mesh_path in [
		"CoreRoad/SpawnZone", "CoreRoad/Road/StartLine", "CoreRoad/StartGateHeader",
		"CoreRoad/GoalGuide", "CoreRoad/Road/FinishLine", "CoreRoad/FinishGateHeader",
	]:
		var old_start_visual: MeshInstance3D = arena.get_node_or_null(mesh_path) as MeshInstance3D
		if old_start_visual == null or old_start_visual.visible:
			_fail("quarantine_boulevard must replace legacy start visual '%s'" % mesh_path)
	var start_deck: Array[Node] = dressing.find_children("QuarantineStartDeck*", "", true, false)
	if start_deck.size() != 1:
		_fail("quarantine_boulevard must build one visual-only quarantine start deck")
	else:
		var deck_mesh: MeshInstance3D = start_deck[0] as MeshInstance3D
		if deck_mesh == null or not deck_mesh.material_override is ShaderMaterial:
			_fail("quarantine_boulevard start deck must use the shared low-memory surface shader")
	var road_material: ShaderMaterial = load("res://assets/materials/road_asphalt.tres") as ShaderMaterial
	if road_material == null or road_material.shader == null:
		_fail("shared road asphalt must keep the world surface detail shader")


func _validate_broken_bridge_environment(arena: Node3D) -> void:
	var dressing: Node3D = arena.get_node_or_null("MapDressing") as Node3D
	if dressing == null:
		return
	var remnants: Array[Node] = dressing.find_children("BrokenApproachDeckRemnant*", "", true, false)
	if remnants.size() != 2:
		_fail("broken_bridge_pass must frame its spawn with deck remnants on both sides")
	var fragments: Array[Node] = dressing.find_children("BrokenApproachDeckFragment*", "", true, false)
	if fragments.size() < 6:
		_fail("broken_bridge_pass must place broken approach fragments on both sides")
	var end_roads: Array[Node] = dressing.find_children("BrokenBridgeEndApproachRoad*", "", true, false)
	if end_roads.size() != 2:
		_fail("broken_bridge_pass must continue its visual road beyond both map ends")
	var lower_streets: Array[Node] = dressing.find_children("BrokenBridgeLowerStreet*", "", true, false)
	if lower_streets.size() != 4:
		_fail("broken_bridge_pass must slope into a lower street at both map ends")


func _fail(message: String) -> void:
	_failures.append(message)
