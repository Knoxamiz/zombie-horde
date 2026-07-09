extends SceneTree

const AIMapBlueprintExporterScript := preload("res://scripts/maps/ai_map_blueprint_exporter.gd")

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Export AI generated prototype ===")
	var result: Dictionary = AIMapBlueprintExporterScript.export_phase1_bridge_ramp_prototype()
	if not bool(result.get("ok", false)):
		for error in result.get("errors", []):
			push_error(str(error))
		print("EXPORT RESULT: FAILED")
		quit(FAIL)
		return
	print("EXPORT RESULT: PASSED")
	print("map_id=%s" % result.get("map_id", ""))
	print("definition_path=%s" % result.get("definition_path", ""))
	quit(PASS)
