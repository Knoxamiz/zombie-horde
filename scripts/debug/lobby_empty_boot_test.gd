extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Cage lobby empty boot test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("Could not load main game scene")
		quit(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.6).timeout

	var round_manager: RoundManager = main_game.get_node_or_null("Systems/RoundManager") as RoundManager
	if round_manager == null:
		push_error("RoundManager missing")
		quit(FAIL)
		return

	if round_manager.get_pending_count() != 0:
		push_error("Expected empty lobby on boot, got %d pending" % round_manager.get_pending_count())
		quit(FAIL)
		return

	var debug_source: DebugJoinSource = main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	if debug_source == null:
		push_error("DebugJoinSource missing")
		quit(FAIL)
		return

	debug_source.request_random_join()
	await create_timer(0.1).timeout

	if round_manager.get_pending_count() != 1:
		push_error("Expected one NPC after manual add, got %d" % round_manager.get_pending_count())
		quit(FAIL)
		return

	var pending_name: String = str(round_manager.get_pending_names()[0])
	if not pending_name.begins_with("NPC "):
		push_error("Expected NPC-prefixed manual join, got: %s" % pending_name)
		quit(FAIL)
		return

	print("PASS: lobby starts empty and streamer NPC add works")
	quit(PASS)
