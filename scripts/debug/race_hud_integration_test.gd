extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _main_game: Node
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== Race HUD integration test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail(_failures, "Could not load main game scene")
		_finish(FAIL)
		return

	_main_game = packed.instantiate()
	root.add_child(_main_game)
	await create_timer(0.5).timeout

	var round_manager: Node = _main_game.get_node_or_null("Systems/RoundManager")
	var zombie_manager: Node = _main_game.get_node_or_null("Systems/ZombieManager")
	var debug_join: Node = _main_game.get_node_or_null("Systems/DebugJoinSource")
	var hud: Node = _main_game.get_node_or_null("HUD")

	_assert_not_null(round_manager, "RoundManager")
	_assert_not_null(zombie_manager, "ZombieManager")
	_assert_not_null(debug_join, "DebugJoinSource")
	_assert_not_null(hud, "HUD")

	if hud.get_script() == null:
		_fail(_failures, "HUD has no script attached (HudController failed to compile?)")

	var world_boards: Node = _main_game.get_node_or_null(
		"SpectatorCamera/Camera3D/WorldMenus3D/RaceBoards"
	)
	_assert_not_null(world_boards, "RaceBoards")

	if not _failures.is_empty():
		_finish(FAIL)
		return

	for join_index in range(5):
		debug_join.call("request_random_join")
	await create_timer(0.2).timeout

	round_manager.call("configure_immediate_launch_for_tests")
	round_manager.call("start_round")
	await create_timer(0.3).timeout

	var state_text: String = str(round_manager.call("get_state_text"))
	if state_text != "Running":
		_fail(_failures, "Expected Running after start_round, got: %s" % state_text)

	var living_count: int = int(zombie_manager.call("get_living_count"))
	var total_count: int = int(zombie_manager.call("get_total_count"))
	if total_count <= 0:
		_fail(_failures, "Expected spawned zombies after start_round, got total=%d" % total_count)

	hud.visible = true
	if hud.has_method("refresh_display"):
		hud.call("refresh_display")
	await create_timer(0.3).timeout

	var status_board: Node = _main_game.get_node_or_null(
		"SpectatorCamera/Camera3D/WorldMenus3D/RaceBoards/RaceStatusBoard"
	)
	if status_board != null:
		var body_text: String = str(status_board.get("body_text"))
		if body_text.contains("0 alive / 0 total") and living_count > 0:
			_fail(
				_failures,
				"Race status board still shows 0 alive while zombie manager has %d living" % living_count
			)
		if not body_text.contains(state_text):
			_fail(
				_failures,
				"Race status board missing state '%s'. Body: %s" % [state_text, body_text]
			)
	else:
		_fail(_failures, "RaceStatusBoard not found")

	var leaders_board: Node = _main_game.get_node_or_null(
		"SpectatorCamera/Camera3D/WorldMenus3D/RaceBoards/RaceLeadersBoard"
	)
	if leaders_board != null:
		var leaders_text: String = str(leaders_board.get("body_text"))
		if leaders_text == "-" and living_count > 0:
			_fail(_failures, "Top 10 board is empty while zombies are alive")
	else:
		_fail(_failures, "RaceLeadersBoard not found")

	if _failures.is_empty():
		print("PASS: state=%s zombies=%d/%d" % [state_text, living_count, total_count])
		_finish(PASS)
		return

	for failure in _failures:
		push_error(failure)
	print("FAIL: %d issue(s)" % _failures.size())
	_finish(FAIL)

func _assert_not_null(node: Node, label: String) -> void:
	if node == null:
		_fail(_failures, "%s not found" % label)

func _fail(failures: Array[String], message: String) -> void:
	failures.append(message)
	print("FAIL: ", message)

func _finish(exit_code: int) -> void:
	if _main_game != null and is_instance_valid(_main_game):
		_main_game.queue_free()
	quit(exit_code)
