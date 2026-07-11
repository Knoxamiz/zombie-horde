extends SceneTree

## Validates map IDs, file paths, kit preset names, and banned legacy IDs.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/map_naming_audit_test.gd

const PASS := 0
const FAIL := 1
const MapNamingScript := preload("res://scripts/maps/map_naming.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Map naming audit ===")
	_failures.append_array(MapNamingScript.validate_all_catalog_entries())
	_validate_blueprint_registry()
	_validate_banned_ids_absent_from_catalog()
	_finish()


func _validate_blueprint_registry() -> void:
	for entry in AIMapBlueprintRegistry.get_all_entries():
		var generated_id: String = str(entry.get("generated_map_id", ""))
		if generated_id.is_empty():
			_fail("blueprint registry entry missing generated_map_id")
			continue
		var catalog_entry: Dictionary = MapCatalog.get_entry_by_id(generated_id)
		if catalog_entry.is_empty():
			_fail("generated map '%s' missing from MapCatalog" % generated_id)
			continue
		var definition_path: String = str(entry.get("definition_path", ""))
		var scene_path: String = str(entry.get("scene_path", ""))
		if definition_path != MapNamingScript.expected_resource_path(generated_id):
			_fail(
				"registry definition_path for '%s' should be %s"
				% [generated_id, MapNamingScript.expected_resource_path(generated_id)]
			)
		if scene_path != MapNamingScript.expected_scene_path(generated_id):
			_fail(
				"registry scene_path for '%s' should be %s"
				% [generated_id, MapNamingScript.expected_scene_path(generated_id)]
			)


func _validate_banned_ids_absent_from_catalog() -> void:
	for entry in MapCatalog.get_all_entries():
		var map_id: String = str(entry.get("id", ""))
		if MapNamingScript.is_banned_map_id(map_id):
			_fail("banned map id present in catalog: %s" % map_id)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED")
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(FAIL)
