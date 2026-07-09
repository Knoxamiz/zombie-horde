class_name AIMapBlueprintExporter
extends RefCounted

const AIMapBlueprintValidatorScript := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const AIMapBlueprintBuilderScript := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const AIMapRouteLayoutScript := preload("res://scripts/maps/ai_map_route_layout.gd")
const Phase1BridgeRampTestBlueprint := preload(
	"res://scripts/maps/blueprints/phase1_bridge_ramp_test.gd"
)

const GENERATED_MAP_ID := "ai_generated_phase1_bridge_ramp_test"
const SCENE_PATH := "res://scenes/maps/ai_generated_phase1_bridge_ramp_test.tscn"
const DEFINITION_PATH := "res://resources/maps/ai_generated_phase1_bridge_ramp_test.tres"


static func export_phase1_bridge_ramp_prototype() -> Dictionary:
	return export_blueprint(
		Phase1BridgeRampTestBlueprint.create(),
		GENERATED_MAP_ID,
		SCENE_PATH,
		DEFINITION_PATH
	)


static func export_blueprint(
	blueprint,
	map_id: String,
	scene_path: String,
	definition_path: String
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
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
