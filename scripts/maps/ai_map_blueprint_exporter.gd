class_name AIMapBlueprintExporter
extends RefCounted

const AIMapBlueprintValidatorScript := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const AIMapBlueprintBuilderScript := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const AIMapRouteLayoutScript := preload("res://scripts/maps/ai_map_route_layout.gd")
const AIMapBlueprintRegistryScript := preload("res://scripts/maps/ai_map_blueprint_registry.gd")


static func export_validated_blueprint_prototype(blueprint_id: String) -> Dictionary:
	var trimmed_id: String = blueprint_id.strip_edges()
	if trimmed_id.is_empty():
		return _failure_result("", "", "", ["blueprint_id is empty"])

	var registry_entry: Dictionary = AIMapBlueprintRegistryScript.get_entry_by_blueprint_id(trimmed_id)
	if registry_entry.is_empty():
		return _failure_result(
			trimmed_id,
			"",
			"",
			["unknown blueprint_id '%s'; no registered prototype export path" % trimmed_id]
		)

	var blueprint = AIMapBlueprintRegistryScript.resolve_blueprint(trimmed_id)
	if blueprint == null:
		return _failure_result(
			trimmed_id,
			str(registry_entry.get("generated_map_id", "")),
			str(registry_entry.get("definition_path", "")),
			["failed to resolve blueprint factory for '%s'" % trimmed_id]
		)

	return export_blueprint(
		blueprint,
		str(registry_entry.get("generated_map_id", "")),
		str(registry_entry.get("scene_path", "")),
		str(registry_entry.get("definition_path", ""))
	)


static func export_all_registered_prototypes() -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"exports": [],
		"errors": [],
	}
	for blueprint_id in AIMapBlueprintRegistryScript.get_all_blueprint_ids():
		var export_result: Dictionary = export_validated_blueprint_prototype(blueprint_id)
		result["exports"].append(export_result)
		if not bool(export_result.get("ok", false)):
			result["ok"] = false
			result["errors"].append(
				"export failed for '%s': %s"
				% [blueprint_id, str(export_result.get("errors", []))]
			)
	return result


static func export_phase1_bridge_ramp_prototype() -> Dictionary:
	return export_validated_blueprint_prototype("phase1_bridge_ramp_test")


static func export_phase2_drop_gap_probe() -> Dictionary:
	return export_validated_blueprint_prototype("phase2_drop_gap_probe")


static func export_blueprint(
	blueprint,
	map_id: String,
	scene_path: String,
	definition_path: String
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"blueprint_id": str(blueprint.map_id if blueprint != null else ""),
		"map_id": map_id,
		"scene_path": scene_path,
		"definition_path": definition_path,
		"errors": [],
	}

	if blueprint == null:
		result["errors"].append("blueprint is null")
		return result

	blueprint.map_id = map_id
	blueprint.authoring_status = "test"

	var validation: Dictionary = AIMapBlueprintValidatorScript.validate_blueprint(blueprint)
	if not bool(validation.get("ok", false)):
		result["errors"].append("blueprint validation failed")
		result["errors"].append_array(validation.get("errors", []))
		return result

	var host := Node3D.new()
	var builder = AIMapBlueprintBuilderScript.new()
	var map_root: Node3D = builder.build_prototype(host, blueprint)
	if map_root == null:
		host.free()
		result["errors"].append("build_prototype returned null")
		return result

	var definition: RaceMapDefinition = builder.build_race_map_definition(blueprint)
	var scene_validation: Dictionary = AIMapBlueprintValidatorScript.validate_generated_scene(
		map_root, blueprint, definition
	)
	if not bool(scene_validation.get("ok", false)):
		result["errors"].append("generated scene validation failed")
		result["errors"].append_array(scene_validation.get("errors", []))
		host.free()
		return result

	if not ResourceLoader.exists(scene_path):
		result["errors"].append("scene wrapper missing at %s (commit scene before export)" % scene_path)
		host.free()
		return result

	definition.scene = load(scene_path) as PackedScene
	if definition.scene == null:
		host.free()
		result["errors"].append("failed to load scene wrapper at %s" % scene_path)
		return result

	var layout_errors: Array = AIMapRouteLayoutScript.definition_matches_layout(definition, blueprint)
	if not layout_errors.is_empty():
		result["errors"].append_array(layout_errors)
		host.free()
		return result

	var save_error: int = ResourceSaver.save(definition, definition_path)
	host.free()
	if save_error != OK:
		result["errors"].append(
			"ResourceSaver.save failed for %s (error=%d)" % [definition_path, save_error]
		)
		return result

	result["ok"] = true
	result["definition"] = definition
	return result


static func _failure_result(
	blueprint_id: String,
	map_id: String,
	definition_path: String,
	errors: Array
) -> Dictionary:
	return {
		"ok": false,
		"blueprint_id": blueprint_id,
		"map_id": map_id,
		"definition_path": definition_path,
		"errors": errors,
	}
