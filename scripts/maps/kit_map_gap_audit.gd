class_name KitMapGapAudit
extends RefCounted

## Headless "eyes" for kit-map gap crossings: compares gameplay collision vs visual planks.
## Catches invisible full-width bridge floors that debug collision view shows as grey slabs.

const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const KIT_ARENA := preload("res://scripts/maps/kit_map_arena.gd")
const SURFACE_BUILDER := preload("res://scripts/maps/kit_map_surface_builder.gd")
const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")

const DEFAULT_MAX_DECK_SPAN_RATIO: float = 0.65
const VISUAL_COLLISION_TOLERANCE: float = 0.12


static func audit_preset(preset_id: String, arena: Node3D = null) -> Dictionary:
	var layout: Dictionary = PRESETS.get_preset(preset_id)
	var owned_arena: bool = arena == null
	if arena == null:
		arena = KIT_ARENA.new()
		arena.layout_preset_id = preset_id
		arena.ensure_built()

	var path_half_width: float = float(layout.get("path_half_width", 4.5))
	var visual_ratio: float = float(
		layout.get("gap_crossing_width_ratio", SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO)
	)
	var expected_visual_half: float = SURFACE_BUILDER.gap_crossing_half_width(path_half_width, visual_ratio)
	var gaps: Array = layout.get("gaps", [])

	var gap_reports: Array[Dictionary] = []
	var issues: PackedStringArray = PackedStringArray()

	var surfaces: Node = arena.get_node_or_null("KitSurfaces")
	var visual_kit: Node = arena.get_node_or_null("VisualKit")
	var collision_by_z: Dictionary = {}
	var visual_by_index: Dictionary = {}

	if surfaces != null:
		for child in surfaces.get_children():
			if child is MapSurfacePiece and str((child as MapSurfacePiece).segment_id) == "gap_crossing":
				var piece: MapSurfacePiece = child as MapSurfacePiece
				var shape_node: CollisionShape3D = piece.get_node_or_null("Collision") as CollisionShape3D
				if shape_node == null or shape_node.shape == null:
					continue
				var box: BoxShape3D = shape_node.shape as BoxShape3D
				if box == null:
					continue
				collision_by_z["%.2f" % piece.position.z] = {
					"collision_half_width": box.size.x * 0.5,
					"collision_length": box.size.z,
					"center_z": piece.position.z,
				}

	if visual_kit != null:
		for child in visual_kit.get_children():
			if not str(child.name).begins_with("GapCrossingPlank"):
				continue
			var plank: MeshInstance3D = child as MeshInstance3D
			if plank == null or plank.mesh == null:
				continue
			var mesh: BoxMesh = plank.mesh as BoxMesh
			if mesh == null:
				continue
			var index_text: String = str(child.name).trim_prefix("GapCrossingPlank_")
			visual_by_index[index_text] = {
				"visual_half_width": mesh.size.x * 0.5,
				"visual_length": mesh.size.z,
				"center_z": plank.position.z,
			}

	for gap_index in range(gaps.size()):
		var gap: Dictionary = gaps[gap_index]
		var z0: float = float(gap.get("z0", 0.0))
		var z1: float = float(gap.get("z1", z0))
		var center_z: float = (z0 + z1) * 0.5
		var collision: Dictionary = collision_by_z.get("%.2f" % center_z, {})
		var visual: Dictionary = visual_by_index.get(str(gap_index), {})
		var collision_half: float = float(collision.get("collision_half_width", 0.0))
		var visual_half: float = float(visual.get("visual_half_width", expected_visual_half))
		var deck_span_ratio: float = (
			0.0 if path_half_width <= 0.0 else collision_half / path_half_width
		)

		var gap_issues: PackedStringArray = PackedStringArray()
		if collision.is_empty():
			gap_issues.append("missing gameplay collision piece")
		else:
			if deck_span_ratio > DEFAULT_MAX_DECK_SPAN_RATIO:
				gap_issues.append(
					"invisible bridge: collision spans %.0f%% of deck (max %.0f%%)"
					% [deck_span_ratio * 100.0, DEFAULT_MAX_DECK_SPAN_RATIO * 100.0]
				)
			if visual_half > 0.0 and collision_half > visual_half + VISUAL_COLLISION_TOLERANCE:
				gap_issues.append(
					"collision wider than visual plank (%.2fm vs %.2fm half-width)"
					% [collision_half, visual_half]
				)
			if abs(collision_half - expected_visual_half) > VISUAL_COLLISION_TOLERANCE + 0.05:
				gap_issues.append(
					"collision does not match configured crossing ratio (%.2fm vs expected %.2fm)"
					% [collision_half, expected_visual_half]
				)

		for issue in gap_issues:
			issues.append("[%s gap %d z=%.0f..%.0f] %s" % [preset_id, gap_index, z0, z1, issue])

		gap_reports.append(
			{
				"gap_index": gap_index,
				"z0": z0,
				"z1": z1,
				"center_z": center_z,
				"path_half_width": path_half_width,
				"visual_ratio": visual_ratio,
				"expected_visual_half_width": expected_visual_half,
				"collision_half_width": collision_half,
				"visual_half_width": visual_half,
				"deck_span_ratio": deck_span_ratio,
				"issues": gap_issues,
			}
		)

	if owned_arena and is_instance_valid(arena):
		arena.queue_free()

	return {
		"preset_id": preset_id,
		"gap_count": gaps.size(),
		"path_half_width": path_half_width,
		"visual_ratio": visual_ratio,
		"gaps": gap_reports,
		"issues": issues,
		"passed": issues.is_empty(),
	}


static func audit_presets(preset_ids: Array[String]) -> Dictionary:
	var reports: Array[Dictionary] = []
	var all_issues: PackedStringArray = PackedStringArray()
	for preset_id in preset_ids:
		var report: Dictionary = audit_preset(preset_id)
		reports.append(report)
		for issue in report.get("issues", PackedStringArray()):
			all_issues.append(str(issue))
	return {
		"presets": reports,
		"issues": all_issues,
		"passed": all_issues.is_empty(),
	}


static func format_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Kit Map Gap Audit: %s ===" % str(report.get("preset_id", "?")))
	lines.append(
		"path_half_width=%.2f visual_ratio=%.2f gaps=%d"
		% [
			float(report.get("path_half_width", 0.0)),
			float(report.get("visual_ratio", 0.0)),
			int(report.get("gap_count", 0)),
		]
	)
	for gap_report_variant in report.get("gaps", []):
		if gap_report_variant is not Dictionary:
			continue
		var gap_report: Dictionary = gap_report_variant
		lines.append(
			"  gap %d z=[%.0f,%.0f] collision_half=%.2f visual_half=%.2f deck_span=%.0f%%"
			% [
				int(gap_report.get("gap_index", -1)),
				float(gap_report.get("z0", 0.0)),
				float(gap_report.get("z1", 0.0)),
				float(gap_report.get("collision_half_width", 0.0)),
				float(gap_report.get("visual_half_width", 0.0)),
				float(gap_report.get("deck_span_ratio", 0.0)) * 100.0,
			]
		)
		for issue in gap_report.get("issues", PackedStringArray()):
			lines.append("    ISSUE: %s" % str(issue))
	if not bool(report.get("passed", false)):
		lines.append("RESULT: FAILED")
	else:
		lines.append("RESULT: PASSED")
	return "\n".join(lines)


static func write_report_file(report: Dictionary, file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return true
