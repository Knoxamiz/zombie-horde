extends SceneTree

## Exports a machine-readable Godot project snapshot for AI agents and CI.
## Writes artifacts/godot_project_snapshot.json
##
## Usage:
##   bash scripts/debug/run_godot.sh snapshot
##   godot --headless --path . -s res://scripts/debug/godot_project_snapshot.gd

const OUTPUT_PATH := "res://artifacts/godot_project_snapshot.json"
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Godot project snapshot ===")
	var snapshot: Dictionary = build_full_snapshot()

	if not _write_snapshot(snapshot):
		_finish(FAIL)
		return

	print("Wrote %s" % OUTPUT_PATH)
	print("SUITE RESULT: PASSED")
	quit(PASS)


static func build_full_snapshot() -> Dictionary:
	return {
		"version": 1,
		"kind": "godot_project_snapshot",
		"engine": _engine_info(),
		"project": _project_info(),
		"autoloads": _autoload_info(),
		"input_actions": _input_action_names(),
		"physics_layers": _physics_layer_names(),
		"playable_maps": _playable_maps(),
		"scene_index": _scene_index(),
		"class_scripts": _class_script_index(),
		"timestamp_utc": Time.get_datetime_string_from_system(true),
	}


static func _engine_info() -> Dictionary:
	return {
		"version": Engine.get_version_info(),
		"is_editor": Engine.is_editor_hint(),
		"is_debug": OS.is_debug_build(),
		"headless": DisplayServer.get_name() == "headless",
	}


static func _project_info() -> Dictionary:
	return {
		"name": ProjectSettings.get_setting("application/config/name", ""),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"features": ProjectSettings.get_setting("application/config/features", PackedStringArray()),
		"viewport": Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
		),
	}


static func _autoload_info() -> Array:
	var rows: Array = []
	var names: PackedStringArray = ProjectSettings.get_setting("autoload", PackedStringArray())
	for entry in names:
		var text: String = str(entry)
		var parts: PackedStringArray = text.split("=", false, 1)
		if parts.is_empty():
			continue
		rows.append({
			"name": parts[0].strip_edges().trim_prefix("*"),
			"path": parts[1].strip_edges() if parts.size() > 1 else "",
		})
	return rows


static func _input_action_names() -> Array[String]:
	var actions: Array[String] = []
	for action in InputMap.get_actions():
		actions.append(str(action))
	actions.sort()
	return actions


static func _physics_layer_names() -> Dictionary:
	var names: Dictionary = {}
	for layer_index in range(1, 33):
		var key: String = "layer_names/3d_physics/layer_%d" % layer_index
		if ProjectSettings.has_setting(key):
			var label: String = str(ProjectSettings.get_setting(key, ""))
			if not label.is_empty():
				names[str(layer_index)] = label
	return names


static func _playable_maps() -> Array:
	var rows: Array = []
	for entry in MapCatalog.get_playable_entries():
		rows.append({
			"id": str(entry.get("id", "")),
			"display_name": str(entry.get("display_name", "")),
			"scene_path": str(entry.get("scene_path", "")),
		})
	return rows


static func _scene_index() -> Array:
	var rows: Array = []
	_scan_dir("res://scenes", rows)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("path", "")) < str(b.get("path", ""))
	)
	return rows


static func _class_script_index() -> Array:
	var rows: Array = []
	var files: PackedStringArray = _list_files_recursive("res://scripts", ".gd")
	for file_path in files:
		if file_path.ends_with(".gd.uid"):
			continue
		var script: Variant = load(file_path)
		if script is GDScript:
			var global_name: String = (script as GDScript).get_global_name()
			if not global_name.is_empty():
				rows.append({"class_name": global_name, "path": file_path})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("class_name", "")) < str(b.get("class_name", ""))
	)
	return rows


static func _scan_dir(dir_path: String, rows: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var item_name: String = dir.get_next()
	while not item_name.is_empty():
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue
		var full_path: String = "%s/%s" % [dir_path, item_name]
		if dir.current_is_dir():
			_scan_dir(full_path, rows)
		elif item_name.ends_with(".tscn"):
			rows.append({"path": full_path, "kind": "scene"})
		item_name = dir.get_next()
	dir.list_dir_end()


static func _list_files_recursive(dir_path: String, extension: String) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var item_name: String = dir.get_next()
	while not item_name.is_empty():
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue
		var full_path: String = "%s/%s" % [dir_path, item_name]
		if dir.current_is_dir():
			for nested in _list_files_recursive(full_path, extension):
				results.append(nested)
		elif item_name.ends_with(extension):
			results.append(full_path)
		item_name = dir.get_next()
	dir.list_dir_end()
	return results


static func _write_snapshot(snapshot: Dictionary) -> bool:
	_ensure_artifacts_dir()
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % OUTPUT_PATH)
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	return true


static func _ensure_artifacts_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))


func _finish(exit_code: int) -> void:
	if not _failures.is_empty():
		for failure in _failures:
			print("FAIL: %s" % failure)
		print("SUITE RESULT: FAILED")
	quit(exit_code)
