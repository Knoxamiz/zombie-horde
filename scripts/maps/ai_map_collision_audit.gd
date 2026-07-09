class_name AIMapCollisionAudit
extends RefCounted

const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")

## Dev/test helpers for AI-generated map gameplay collision.
## Authoritative walk surfaces must live under GameplayLayer/SafeFloor on layer 1.

const ZOMBIE_WALK_COLLISION_LAYER: int = 1
const MAX_CENTER_ROUTE_WALL_HEIGHT: float = 2.5
const FLOOR_Y_TOLERANCE: float = 0.25
const CENTER_ROUTE_X_TOLERANCE: float = 1.25

const SIGNATURE_DROP_BRIDGE_MAP_ID := "ai_generated_signature_drop_bridge"
const PHASE2_DROP_GAP_PROBE_MAP_ID := "ai_generated_phase2_drop_gap_probe"
const PHASE3_MOVING_HAZARD_PROBE_MAP_ID := "ai_generated_phase3_moving_hazard_probe"

const FOCUS_MAP_IDS: Array[String] = [
	SIGNATURE_DROP_BRIDGE_MAP_ID,
	PHASE2_DROP_GAP_PROBE_MAP_ID,
	PHASE3_MOVING_HAZARD_PROBE_MAP_ID,
]


static func print_collision_audit(root: Node3D, map_label: String = "") -> void:
	if root == null:
		print("AIMapCollisionAudit: null root (%s)" % map_label)
		return

	print("=== AI Map Collision Audit: %s ===" % map_label)
	var count: int = 0
	for entry in collect_collision_entries(root):
		count += 1
		print(
			(
				"- %s | layer_bucket=%s | pos=%s | scale=%s | shape=%s | size=%s | "
				+ "collision_layer=%s collision_mask=%s disabled=%s"
			)
			% [
				str(entry.get("path", "")),
				str(entry.get("layer_bucket", "")),
				str(entry.get("global_position", Vector3.ZERO)),
				str(entry.get("scale", Vector3.ONE)),
				str(entry.get("shape_type", "")),
				str(entry.get("shape_size", "")),
				str(entry.get("collision_layer", 0)),
				str(entry.get("collision_mask", 0)),
				str(entry.get("disabled", false)),
			]
		)
	print("collision entries: %d" % count)


static func collect_collision_entries(root: Node3D) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if root == null:
		return entries
	_collect_collision_entries_recursive(root, entries)
	return entries


static func validate_generated_collision(
	root: Node3D,
	blueprint,
	definition: RaceMapDefinition
) -> Array[String]:
	var errors: Array[String] = []
	if root == null:
		errors.append("generated map root is null")
		return errors

	var gameplay_layer: Node = root.get_node_or_null("GameplayLayer")
	var visual_layer: Node = root.get_node_or_null("VisualLayer")
	if gameplay_layer == null:
		errors.append("GameplayLayer is missing")
	if visual_layer == null:
		errors.append("VisualLayer is missing")

	var safe_floor: Node = gameplay_layer.get_node_or_null("SafeFloor") if gameplay_layer != null else null
	if safe_floor == null:
		errors.append("GameplayLayer/SafeFloor is missing")
	elif safe_floor.get_child_count() <= 0:
		errors.append("SafeFloor has no collision plates")

	if safe_floor != null:
		for plate in safe_floor.get_children():
			errors.append_array(_validate_safe_floor_plate(plate, definition, blueprint))

	if visual_layer != null:
		errors.append_array(_validate_visual_layer_has_no_gameplay_collision(visual_layer))

	errors.append_array(_validate_no_suspicious_center_walls(root, blueprint))
	return errors


static func probe_signature_drop_bridge(root: Node3D, blueprint, definition: RaceMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if root == null or blueprint == null or definition == null:
		errors.append("probe requires root, blueprint, and definition")
		return errors

	var spawn_z: float = definition.spawn_origin.z
	if not _has_enabled_floor_near(root, Vector3(0.0, definition.deck_y, spawn_z)):
		errors.append("spawn area missing enabled floor collision near deck_y")

	var safe_segment_ids: Array[String] = [
		"start_straight",
		"straight_road_medium",
		"elevated_straight",
		"recovery_straight_after_gap",
		"finish_straight",
	]
	for segment_id in safe_segment_ids:
		if not blueprint.segment_sequence.has(segment_id):
			continue
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var center_z: float = _segment_center_z(blueprint, segment_id)
		if not _has_enabled_floor_near(root, Vector3(0.0, definition.deck_y, center_z)):
			errors.append("safe segment '%s' missing floor collision near z=%.1f" % [segment_id, center_z])

	if blueprint.segment_sequence.has("broken_bridge_gap"):
		var gap_center_z: float = _segment_center_z(blueprint, "broken_bridge_gap")
		var gap_segment: Dictionary = MapSegmentDefinitionScript.get_segment("broken_bridge_gap")
		var gap_half_width: float = (
			float(gap_segment.get("width", 10.0))
			* float(gap_segment.get("safe_floor_width_ratio", 0.4))
			* 0.5
		)
		if _has_enabled_floor_blocking_x(root, 0.0, gap_center_z, gap_half_width + 0.75):
			errors.append("broken_bridge_gap has full-width floor collision across center gap")

	if blueprint.segment_sequence.has("recovery_straight_after_gap"):
		var recovery_z: float = _segment_center_z(blueprint, "recovery_straight_after_gap")
		if not _has_enabled_floor_near(root, Vector3(0.0, definition.deck_y, recovery_z)):
			errors.append("recovery floor collision missing after broken_bridge_gap")

	errors.append_array(_validate_no_suspicious_center_walls(root, blueprint))
	return errors


static func _collect_collision_entries_recursive(node: Node, entries: Array[Dictionary]) -> void:
	if node is CollisionShape3D:
		var shape_node: CollisionShape3D = node as CollisionShape3D
		var body: CollisionObject3D = shape_node.get_parent() as CollisionObject3D
		if body == null:
			return
		var shape_info: Dictionary = _shape_info(shape_node)
		var body_node: Node3D = body as Node3D
		var entry: Dictionary = {
			"path": str(body.get_path()),
			"layer_bucket": _layer_bucket_name(body),
			"global_position": body_node.position if body_node != null else Vector3.ZERO,
			"scale": body_node.scale if body_node != null else Vector3.ONE,
			"shape_type": shape_info.get("type", ""),
			"shape_size": shape_info.get("size", ""),
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
			"disabled": shape_node.disabled,
		}
		if shape_info.has("box_size"):
			entry["box_size"] = shape_info.get("box_size")
		entries.append(entry)
		return

	if node is StaticBody3D or node is AnimatableBody3D:
		if node.get_child_count() == 0:
			entries.append(
				{
					"path": str(node.get_path()),
					"layer_bucket": _layer_bucket_name(node),
					"global_position": (node as Node3D).global_position,
					"scale": (node as Node3D).scale,
					"shape_type": "missing",
					"shape_size": "",
					"collision_layer": (node as CollisionObject3D).collision_layer,
					"collision_mask": (node as CollisionObject3D).collision_mask,
					"disabled": true,
				}
			)

	for child in node.get_children():
		_collect_collision_entries_recursive(child, entries)


static func _validate_safe_floor_plate(plate: Node, definition: RaceMapDefinition, blueprint) -> Array[String]:
	var errors: Array[String] = []
	if not (plate is StaticBody3D):
		errors.append("SafeFloor child '%s' must be StaticBody3D" % plate.name)
		return errors

	var body: StaticBody3D = plate as StaticBody3D
	if body.collision_layer != ZOMBIE_WALK_COLLISION_LAYER:
		errors.append(
			"SafeFloor plate '%s' collision_layer=%d (expected %d)"
			% [plate.name, body.collision_layer, ZOMBIE_WALK_COLLISION_LAYER]
		)

	var shape_node: CollisionShape3D = null
	for child in body.get_children():
		if child is CollisionShape3D:
			shape_node = child as CollisionShape3D
			break
	if shape_node == null:
		errors.append("SafeFloor plate '%s' missing CollisionShape3D" % plate.name)
		return errors
	if shape_node.disabled:
		errors.append("SafeFloor plate '%s' CollisionShape3D is disabled" % plate.name)
	if shape_node.shape == null:
		errors.append("SafeFloor plate '%s' has null collision shape" % plate.name)
		return errors

	if definition != null:
		var expected_deck_y: float = _expected_deck_y_at_z(blueprint, body.position.z)
		var top_y: float = body.position.y + _shape_top_offset_y(shape_node.shape)
		if absf(top_y - expected_deck_y) > FLOOR_Y_TOLERANCE:
			errors.append(
				"SafeFloor plate '%s' top Y %.2f not near deck_y %.2f at z=%.1f"
				% [plate.name, top_y, expected_deck_y, body.position.z]
			)

	var shape_info: Dictionary = _shape_info(shape_node)
	if str(shape_info.get("type", "")) == "Box":
		var size: Vector3 = shape_info.get("box_size", Vector3.ZERO)
		if size.y > 1.0:
			errors.append("SafeFloor plate '%s' suspicious wall height %.2f" % [plate.name, size.y])
	return errors


static func _validate_visual_layer_has_no_gameplay_collision(visual_layer: Node) -> Array[String]:
	var errors: Array[String] = []
	for entry in collect_collision_entries(visual_layer as Node3D):
		if bool(entry.get("disabled", true)):
			continue
		if int(entry.get("collision_layer", 0)) == 0:
			continue
		errors.append(
			"VisualLayer contains active gameplay collision: %s (layer=%d)"
			% [entry.get("path", ""), int(entry.get("collision_layer", 0))]
		)
	return errors


static func _validate_no_suspicious_center_walls(root: Node3D, blueprint) -> Array[String]:
	var errors: Array[String] = []
	var lane_half: float = blueprint.lane_half_width if blueprint != null else 4.0
	for entry in collect_collision_entries(root):
		var path: String = str(entry.get("path", ""))
		if "/SafeFloor/" in path or "/MovingObstacles/" in path:
			continue
		if bool(entry.get("disabled", true)):
			continue
		if int(entry.get("collision_layer", 0)) != ZOMBIE_WALK_COLLISION_LAYER:
			continue
		var pos: Vector3 = entry.get("global_position", Vector3.ZERO)
		if absf(pos.x) > lane_half:
			continue
		var shape_type: String = str(entry.get("shape_type", ""))
		if shape_type != "Box":
			continue
		var size: Vector3 = entry.get("box_size", Vector3.ZERO)
		if size.y > MAX_CENTER_ROUTE_WALL_HEIGHT:
			errors.append(
				"suspicious center-route wall collision at %s (size=%s)"
				% [path, size]
			)
	return errors


static func _has_enabled_floor_near(root: Node3D, sample: Vector3) -> bool:
	var safe_floor: Node = root.get_node_or_null("GameplayLayer/SafeFloor")
	if safe_floor == null:
		return false
	for plate in safe_floor.get_children():
		if not (plate is StaticBody3D):
			continue
		var body: StaticBody3D = plate as StaticBody3D
		if body.collision_layer != ZOMBIE_WALK_COLLISION_LAYER:
			continue
		for child in body.get_children():
			if not (child is CollisionShape3D):
				continue
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node.disabled or shape_node.shape == null:
				continue
			var half: Vector3 = _shape_half_extents(shape_node.shape)
			var min_pos: Vector3 = body.position - half
			var max_pos: Vector3 = body.position + half
			if (
				sample.x >= min_pos.x - 0.05
				and sample.x <= max_pos.x + 0.05
				and sample.z >= min_pos.z - 0.05
				and sample.z <= max_pos.z + 0.05
				and absf(body.position.y + half.y - sample.y) <= FLOOR_Y_TOLERANCE + half.y
			):
				return true
	return false


static func _has_enabled_floor_blocking_x(
	root: Node3D,
	center_x: float,
	center_z: float,
	allowed_half_width: float
) -> bool:
	var safe_floor: Node = root.get_node_or_null("GameplayLayer/SafeFloor")
	if safe_floor == null:
		return false
	for plate in safe_floor.get_children():
		if not (plate is StaticBody3D):
			continue
		var body: StaticBody3D = plate as StaticBody3D
		for child in body.get_children():
			if not (child is CollisionShape3D):
				continue
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node.disabled or shape_node.shape == null:
				continue
			var half: Vector3 = _shape_half_extents(shape_node.shape)
			if absf(body.position.z - center_z) > half.z + 0.1:
				continue
			var plate_half_x: float = half.x
			if plate_half_x > allowed_half_width + 0.1:
				return true
	return false


static func _segment_center_z(blueprint, segment_id: String) -> float:
	var cursor: float = 0.0
	for segment_key in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(segment_key))
		var length: float = float(segment.get("length", 8.0))
		if str(segment_key) == segment_id:
			return cursor + length * 0.5
		cursor += length
	return 0.0


static func _layer_bucket_name(node: Node) -> String:
	var current: Node = node
	while current != null:
		if current.name in ["GameplayLayer", "VisualLayer", "SafeFloor", "MovingObstacles"]:
			return current.name
		current = current.get_parent()
	return "unknown"


static func _shape_info(shape_node: CollisionShape3D) -> Dictionary:
	if shape_node.shape is BoxShape3D:
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		return {"type": "Box", "size": str(box.size), "box_size": box.size}
	if shape_node.shape is ConcavePolygonShape3D:
		var concave: ConcavePolygonShape3D = shape_node.shape as ConcavePolygonShape3D
		return {"type": "Concave", "size": "faces=%d" % concave.get_faces().size()}
	return {"type": shape_node.shape.get_class() if shape_node.shape != null else "null", "size": ""}


static func _expected_deck_y_at_z(blueprint, plate_z: float) -> float:
	if blueprint == null:
		return 0.0
	if plate_z < -0.01:
		return float(blueprint.deck_y)
	var cursor_y: float = float(blueprint.deck_y)
	var cursor_z: float = 0.0
	for segment_id_value in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(segment_id_value))
		var length: float = float(segment.get("length", 8.0))
		if plate_z >= cursor_z - 0.01 and plate_z <= cursor_z + length + 0.01:
			return cursor_y
		cursor_y += float(segment.get("height_delta", 0.0))
		cursor_z += length
	return float(blueprint.deck_y)


static func _shape_half_extents(shape: Shape3D) -> Vector3:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size * 0.5
	if shape is ConcavePolygonShape3D:
		return Vector3(4.0, 0.06, 4.0)
	return Vector3.ONE


static func _shape_top_offset_y(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y * 0.5
	if shape is ConcavePolygonShape3D:
		return 0.06
	return 0.0


static func ensure_gameplay_collision_enabled(root: Node3D) -> int:
	var restored: int = 0
	if root == null:
		return restored
	var gameplay_layer: Node = root.get_node_or_null("GameplayLayer")
	if gameplay_layer == null:
		return restored
	restored += _restore_collision_layer_recursive(gameplay_layer, ZOMBIE_WALK_COLLISION_LAYER)
	return restored


static func _restore_collision_layer_recursive(node: Node, layer: int) -> int:
	var restored: int = 0
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		if collision_object.collision_layer != layer:
			collision_object.collision_layer = layer
			restored += 1
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node.disabled:
				shape_node.disabled = false
				restored += 1
		restored += _restore_collision_layer_recursive(child, layer)
	return restored
