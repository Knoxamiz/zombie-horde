extends SceneTree

const AIMapBlueprintExporterScript := preload("res://scripts/maps/ai_map_blueprint_exporter.gd")
const AIMapBlueprintRegistryScript := preload("res://scripts/maps/ai_map_blueprint_registry.gd")

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Export AI generated prototype ===")
	var blueprint_id: String = _read_cli_arg("--blueprint_id=").strip_edges()
	var result: Dictionary
	if blueprint_id.is_empty():
		result = AIMapBlueprintExporterScript.export_all_registered_prototypes()
	else:
		result = AIMapBlueprintExporterScript.export_validated_blueprint_prototype(blueprint_id)

	if blueprint_id.is_empty():
		_report_batch_export(result)
	else:
		_report_single_export(result)

	if bool(result.get("ok", false)):
		print("EXPORT RESULT: PASSED")
		quit(PASS)
	else:
		print("EXPORT RESULT: FAILED")
		quit(FAIL)


func _read_cli_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	return ""


func _report_single_export(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		for error in result.get("errors", []):
			push_error(str(error))
		return
	print("blueprint_id=%s" % result.get("blueprint_id", ""))
	print("map_id=%s" % result.get("map_id", ""))
	print("definition_path=%s" % result.get("definition_path", ""))


func _report_batch_export(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		for error in result.get("errors", []):
			push_error(str(error))
	for export_result in result.get("exports", []):
		var export_dict: Dictionary = export_result
		var status: String = "PASSED" if bool(export_dict.get("ok", false)) else "FAILED"
		print(
			"%s blueprint_id=%s map_id=%s"
			% [
				status,
				export_dict.get("blueprint_id", ""),
				export_dict.get("map_id", ""),
			]
		)
		if not bool(export_dict.get("ok", false)):
			for error in export_dict.get("errors", []):
				push_error(str(error))
	print(
		"registered prototypes: %s"
		% str(AIMapBlueprintRegistryScript.get_all_blueprint_ids())
	)
