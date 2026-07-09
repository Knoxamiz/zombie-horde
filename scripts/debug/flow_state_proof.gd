extends SceneTree

## Tangible flow-state proof for the production map path.
## Produces a human-readable scorecard and writes artifacts/flow_state_proof_latest.txt
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/flow_state_proof.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const OUTPUT_PATH := "res://artifacts/flow_state_proof_latest.txt"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const FALLTHROUGH_TEST_MAP_ID := "ai_generated_fallthrough_lower_deck_test"
const FallthroughArenaScript := preload("res://scripts/maps/fallthrough_lower_deck_arena.gd")

const Builder := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const Registry := preload("res://scripts/maps/ai_map_blueprint_registry.gd")
const Audit := preload("res://scripts/maps/ai_map_collision_audit.gd")
const Validator := preload("res://scripts/maps/ai_map_blueprint_validator.gd")

const PASS := 0
const FAIL := 1

var _lines: PackedStringArray = PackedStringArray()
var _failures: int = 0
var _started_msec: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_started_msec = Time.get_ticks_msec()
	_print_header()
	_check_catalog_single_map()
	_check_city_highway_assets_on_disk()
	await _check_city_highway_runtime_load()
	_check_playable_map_gate()
	await _check_fallthrough_lower_deck_build()
	_print_honesty_section()
	_write_report_file()
	_finish()


func _print_header() -> void:
	_line("=".repeat(80))
	_line("FLOW STATE PROOF")
	_line("Generated: %s" % Time.get_datetime_string_from_system(true))
	_line("Git branch: %s" % _git_command(["rev-parse", "--abbrev-ref", "HEAD"]))
	_line("Git commit: %s" % _git_command(["rev-parse", "--short", "HEAD"]))
	_line("=".repeat(80))
	_line("")
	_line("%-42s %-8s %s" % ["CHECK", "STATUS", "DETAIL"])
	_line("-".repeat(80))


func _record(check_name: String, passed: bool, detail: String) -> void:
	var status: String = "PASS" if passed else "FAIL"
	if not passed:
		_failures += 1
		push_error("FLOW PROOF FAIL [%s]: %s" % [check_name, detail])
	_line("%-42s %-8s %s" % [check_name, status, detail])


func _record_manual(check_name: String, detail: String) -> void:
	_line("%-42s %-8s %s" % [check_name, "MANUAL", detail])


func _check_catalog_single_map() -> void:
	var selectable: Array[Dictionary] = MapCatalog.get_selectable_entries_for_settings()
	var has_highway: bool = false
	var has_fallthrough: bool = false
	for entry in selectable:
		var map_id: String = str(entry.get("id", ""))
		if map_id == CITY_HIGHWAY_MAP_ID:
			has_highway = true
		if map_id == FALLTHROUGH_TEST_MAP_ID:
			has_fallthrough = true
	_record(
		"Streamer map gate",
		selectable.size() == 8,
		"%d selectable maps (expected 8 playable kit + hand-authored maps)" % selectable.size()
	)


func _check_city_highway_assets_on_disk() -> void:
	var entry: Dictionary = MapCatalog.get_entry_by_id(CITY_HIGHWAY_MAP_ID)
	var scene_path: String = str(entry.get("scene_path", ""))
	var definition_path: String = str(entry.get("resource_path", ""))
	var missing: PackedStringArray = PackedStringArray()
	if not ResourceLoader.exists(scene_path):
		missing.append(scene_path)
	if not ResourceLoader.exists(definition_path):
		missing.append(definition_path)
	_record(
		"City Highway scene/tres on disk",
		missing.is_empty(),
		"missing=%s" % (", ".join(missing) if not missing.is_empty() else "none")
	)


func _check_city_highway_runtime_load() -> void:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_record("City Highway runtime load", false, "main_game.tscn missing")
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		_record("City Highway runtime load", false, "RaceMapController missing")
		main_game.queue_free()
		return

	var profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	profile.set_selected_settings_map_index(0)
	var loaded: bool = map_controller.apply_profile(profile)
	var ok: bool = (
		loaded
		and not map_controller.did_last_load_use_fallback()
		and map_controller.get_resolved_map_id() == CITY_HIGHWAY_MAP_ID
		and main_game.get_node_or_null("World/RoadArena") != null
	)
	_record(
		"City Highway runtime load",
		ok,
		"resolved=%s fallback=%s"
		% [
			map_controller.get_resolved_map_id(),
			"yes" if map_controller.did_last_load_use_fallback() else "no",
		]
	)
	main_game.queue_free()


func _check_playable_map_gate() -> void:
	var playable_count: int = MapCatalog.get_playable_count()
	_record(
		"Playable map gate",
		playable_count == 8,
		"%d playable maps (expected 8 unique playable maps)" % playable_count
	)


func _check_fallthrough_lower_deck_build() -> void:
	var entry: Dictionary = Registry.get_entry_by_blueprint_id("fallthrough_lower_deck_test")
	var scene_path: String = str(entry.get("scene_path", ""))
	var definition_path: String = str(entry.get("definition_path", ""))
	var missing: PackedStringArray = PackedStringArray()
	if not ResourceLoader.exists(scene_path):
		missing.append(scene_path)
	if not ResourceLoader.exists(definition_path):
		missing.append(definition_path)
	if not missing.is_empty():
		_record(
			"Fallthrough lower deck export",
			false,
			"missing=%s (run export_ai_generated_prototype.gd)" % ", ".join(missing)
		)
		return

	var blueprint = Registry.resolve_blueprint("fallthrough_lower_deck_test")
	if blueprint == null:
		_record("Fallthrough lower deck build", false, "blueprint missing")
		return

	var blueprint_validation: Dictionary = Validator.validate_blueprint(blueprint)
	if not bool(blueprint_validation.get("ok", false)):
		_record("Fallthrough lower deck build", false, "blueprint invalid")
		return

	var host := Node3D.new()
	root.add_child(host)
	var arena = FallthroughArenaScript.new()
	host.add_child(arena)
	var map_root: Node3D = arena.build_map()
	if map_root == null:
		_record("Fallthrough lower deck build", false, "hand-authored arena build_map failed")
		host.queue_free()
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(FALLTHROUGH_TEST_MAP_ID)
	var collision_errors: Array[String] = Audit.validate_generated_collision(
		map_root, blueprint, definition
	)
	var probe_errors: Array[String] = Audit.probe_multi_layer_fallthrough(
		map_root, blueprint, definition
	)
	var failed: bool = not collision_errors.is_empty() or not probe_errors.is_empty()
	_record(
		"Fallthrough lower deck collision",
		not failed,
		"collision=%d probe=%d"
		% [collision_errors.size(), probe_errors.size()]
	)
	host.queue_free()


func _print_honesty_section() -> void:
	_line("-".repeat(80))
	_line("")
	_line("MANUAL ONLY (automation cannot prove these):")
	_record_manual("Visual quality / art pass", "Run editor, load City Highway, inspect track and scenery")
	_record_manual("Zombie walk feel on floors", "Queue 20 NPCs on fallthrough test, watch hole → lower deck landing")
	_record_manual("Fallthrough lower deck feel", "F3 → Load Fallthrough Lower Deck TEST → queue 20 NPCs at center hole")
	_record_manual("Stream/OBS HUD layout", "Not covered by headless proof")
	_line("")
	_line("NEXT MAP WORK:")
	_line("  Confirm fallthrough test visuals and NPC hole → lower deck landing in F3.")
	_line("")
	_line("RE-RUN THIS PROOF:")
	_line("  godot --headless --path . -s res://scripts/debug/flow_state_proof.gd")
	_line("")
	var elapsed_sec: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	_line("Elapsed: %.1fs | Failures: %d" % [elapsed_sec, _failures])
	_line("=".repeat(80))


func _write_report_file() -> void:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var dir_path: String = output_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write flow proof report to %s" % output_path)
		return
	for line in _lines:
		file.store_line(line)
	file.close()
	print("Wrote flow proof report: %s" % output_path.replace(project_path, "res://"))


func _git_command(args: PackedStringArray) -> String:
	var output: Array = []
	var exit_code: int = OS.execute("git", args, output, true, false)
	if exit_code != 0 or output.is_empty():
		return "unknown"
	return str(output[0]).strip_edges()


func _line(text: String) -> void:
	print(text)
	_lines.append(text)


func _finish() -> void:
	if _failures == 0:
		_line("FLOW STATE PROOF: PASSED")
		quit(PASS)
	else:
		_line("FLOW STATE PROOF: FAILED (%d checks)" % _failures)
		quit(FAIL)
