extends SceneTree

## Guards the Broken Bridge contract: visible outer bridge decks remain solid
## continuously, including alongside the intentionally broken center crossings.

const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const KIT_ARENA := preload("res://scripts/maps/kit_map_arena.gd")
const SURFACE_SCRIPT := preload("res://scripts/maps/map_surface_piece.gd")
const PASS := 0
const FAIL := 1
const SHOULDER_X: float = 6.0
const SHOULDER_SAMPLE_ZS: PackedFloat32Array = PackedFloat32Array([-62.0, -44.0, -4.0, 36.0, 62.0])

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := KIT_ARENA.new()
	arena.layout_preset_id = "broken_bridge_pass"
	root.add_child(arena)
	arena.ensure_built()
	await physics_frame

	var surfaces: Node = arena.get_node_or_null("KitSurfaces")
	if surfaces == null:
		_fail("broken_bridge_pass is missing KitSurfaces")
	else:
		for side_value in [-1.0, 1.0]:
			var side: float = float(side_value)
			for sample_z: float in SHOULDER_SAMPLE_ZS:
				if not _has_walk_surface_at(surfaces, side * SHOULDER_X, sample_z):
					_fail(
						"solid bridge shoulder on side %.0f is missing walk collision at z %.1f"
						% [side, sample_z]
					)

	arena.queue_free()
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
		return
	for failure in _failures:
		push_error(failure)
	quit(FAIL)


func _has_walk_surface_at(surfaces: Node, sample_x: float, sample_z: float) -> bool:
	for child in surfaces.get_children():
		var surface: StaticBody3D = child as StaticBody3D
		if surface == null or not surface.is_in_group(SURFACE_SCRIPT.NAVIGATION_GROUP):
			continue
		var collision: CollisionShape3D = surface.get_node_or_null("Collision") as CollisionShape3D
		var box: BoxShape3D = collision.shape as BoxShape3D if collision != null else null
		if box == null or surface.collision_layer != 1:
			continue
		var half_width: float = box.size.x * 0.5
		var half_length: float = box.size.z * 0.5
		if absf(sample_x - surface.position.x) <= half_width and absf(sample_z - surface.position.z) <= half_length:
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
