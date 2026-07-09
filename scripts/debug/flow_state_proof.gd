extends SceneTree

## Tangible flow-state proof for the AI map factory and prototype review path.
## Produces a human-readable scorecard and writes artifacts/flow_state_proof_latest.txt
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/flow_state_proof.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const OUTPUT_PATH := "res://artifacts/flow_state_proof_latest.txt"
const DEV_PANEL_SCRIPT := "res://scripts/debug/dev_control_panel_controller.gd"

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
	await _check_registry_and_catalog()
	await _check_export_files_on_disk()
	await _check_blueprint_build_and_collision()
	await _check_runtime_prototype_loads()
	_check_playable_map_gate()
	_check_f3_phase3_button()
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


func _check_registry_and_catalog() -> void:
	var registry_ids: Array[String] = Registry.get_all_generated_map_ids()
	var catalog_entries: Array[Dictionary] = MapCatalog.get_ai_generated_prototype_entries()
	var catalog_ids: Array[String] = []
	for entry in catalog_entries:
		catalog_ids.append(str(entry.get("id", "")))

	var aligned: bool = registry_ids.size() == catalog_ids.size()
	for map_id in registry_ids:
		if map_id not in catalog_ids:
			aligned = false

	_record(
		"Registry/catalog alignment",
		aligned and registry_ids.size() == 4,
		"%d registry ids, %d catalog prototypes" % [registry_ids.size(), catalog_ids.size()]
	)

	var prototype_safe: bool = true
	for entry in catalog_entries:
		if bool(entry.get("enabled", false)):
			prototype_safe = false
		if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
			prototype_safe = false
	_record(
		"Prototypes stay disabled",
		prototype_safe,
		"enabled=false, status=prototype for all AI maps"
	)


func _check_export_files_on_disk() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for entry in Registry.get_all_entries():
		var scene_path: String = str(entry.get("scene_path", ""))
		var definition_path: String = str(entry.get("definition_path", ""))
		if not ResourceLoader.exists(scene_path):
			missing.append(scene_path)
		if not ResourceLoader.exists(definition_path):
			missing.append(definition_path)
	_record(
		"Exported scene/tres on disk",
		missing.is_empty(),
		"missing=%s" % (", ".join(missing) if not missing.is_empty() else "none")
	)


func _check_blueprint_build_and_collision() -> void:
	var builder := Builder.new()
	var failed_maps: PackedStringArray = PackedStringArray()
	for entry in Registry.get_all_entries():
		var map_id: String = str(entry.get("generated_map_id", ""))
		var blueprint = Registry.resolve_blueprint(str(entry.get("blueprint_id", "")))
		if blueprint == null:
			failed_maps.append("%s (no blueprint)" % map_id)
			continue

		var blueprint_validation: Dictionary = Validator.validate_blueprint(blueprint)
		if not bool(blueprint_validation.get("ok", false)):
			failed_maps.append("%s (blueprint invalid)" % map_id)
			continue

		var host := Node3D.new()
		root.add_child(host)
		var map_root: Node3D = builder.build_prototype(host, blueprint)
		if map_root == null:
			failed_maps.append("%s (build failed)" % map_id)
			host.queue_free()
			continue

		var definition: RaceMapDefinition = builder.build_race_map_definition(blueprint)
		var scene_validation: Dictionary = Validator.validate_generated_scene(
			map_root, blueprint, definition
		)
		if not bool(scene_validation.get("ok", false)):
			failed_maps.append("%s (scene invalid)" % map_id)
			host.queue_free()
			continue

		var collision_errors: Array[String] = Audit.validate_generated_collision(
			map_root, blueprint, definition
		)
		if not collision_errors.is_empty():
			failed_maps.append("%s (%d collision errors)" % [map_id, collision_errors.size()])
		host.queue_free()

	_record(
		"Blueprint build + collision",
		failed_maps.is_empty(),
		"failed=%s" % (", ".join(failed_maps) if not failed_maps.is_empty() else "none")
	)


func _check_runtime_prototype_loads() -> void:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_record("Runtime prototype loads", false, "main_game.tscn missing")
		return

	var failed_maps: PackedStringArray = PackedStringArray()
	for entry in Registry.get_all_entries():
		var map_id: String = str(entry.get("generated_map_id", ""))
		var ok: bool = await _load_and_verify_prototype(packed, map_id)
		if not ok:
			failed_maps.append(map_id)

	_record(
		"Runtime prototype loads",
		failed_maps.is_empty(),
		"failed=%s" % (", ".join(failed_maps) if not failed_maps.is_empty() else "none")
	)


func _load_and_verify_prototype(packed: PackedScene, map_id: String) -> bool:
	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		main_game.queue_free()
		return false

	if not map_controller.load_prototype_map_for_test(map_id):
		main_game.queue_free()
		return false
	if map_controller.did_last_load_use_fallback():
		main_game.queue_free()
		return false
	if map_controller.get_resolved_map_id() != map_id:
		main_game.queue_free()
		return false

	var road_arena: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	if road_arena == null:
		main_game.queue_free()
		return false
	var map_root: Node3D = road_arena.get_node_or_null("CoreRoad/MapRoot") as Node3D
	if map_root == null:
		main_game.queue_free()
		return false

	var gameplay_layer: Node = map_root.get_node_or_null("GameplayLayer")
	if gameplay_layer == null:
		main_game.queue_free()
		return false

	var active_floor_shapes: int = _count_active_walk_collision_shapes(gameplay_layer)
	if active_floor_shapes < 1:
		main_game.queue_free()
		return false

	main_game.queue_free()
	return true


func _count_active_walk_collision_shapes(gameplay_layer: Node) -> int:
	var count: int = 0
	var stack: Array[Node] = [gameplay_layer]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionShape3D:
			var shape_node: CollisionShape3D = node as CollisionShape3D
			if not shape_node.disabled and shape_node.shape != null:
				count += 1
		for child in node.get_children():
			stack.append(child)
	return count


func _check_playable_map_gate() -> void:
	var playable_count: int = MapCatalog.get_playable_count()
	_record(
		"Playable map gate",
		playable_count == 1,
		"%d playable maps (expected 1: City Highway)" % playable_count
	)


func _check_f3_phase3_button() -> void:
	var text: String = FileAccess.get_file_as_string(DEV_PANEL_SCRIPT)
	var has_button: bool = text.find("Load Phase 3 Moving Hazard Probe") != -1
	_record(
		"F3 Phase 3 review button",
		has_button,
		"dev panel exposes phase3 moving hazard probe loader"
	)


func _print_honesty_section() -> void:
	_line("-".repeat(80))
	_line("")
	_line("MANUAL ONLY (automation cannot prove these):")
	_record_manual("Visual quality / art pass", "Run editor, F3 load each prototype, look at scene")
	_record_manual("Zombie walk feel on floors", "Queue 20 NPCs, watch for fall-through or snagging")
	_record_manual("Moving hazard gameplay", "Phase 3 probe: hazards move and affect zombies")
	_record_manual("Stream/OBS HUD layout", "Not covered by headless proof")
	_line("")
	_line("HONEST CAPABILITY MATRIX (what you can ask for today):")
	_line("  YES  — New AI prototype blueprint + export + certify (prototype only)")
	_line("  YES  — New drop-and-play obstacle scene (dp_* id + segment wiring)")
	_line("  YES  — Dev F3 prototype review loader buttons")
	_line("  YES  — Collision/validator fixes with headless proof")
	_line("  MAYBE — Full signature map (needs segment assets + manual fun review)")
	_line("  NO    — Promote prototype to playable without certification checklist")
	_line("  NO    — Bundle map + zombie + UI + Twitch in one task")
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
