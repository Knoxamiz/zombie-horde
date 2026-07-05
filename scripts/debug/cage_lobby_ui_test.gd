extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Cage lobby UI duplication test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("Could not load main game scene")
		quit(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout

	var lobby_boards: Node3D = main_game.get_node_or_null(
		"SpectatorCamera/Camera3D/WorldMenus3D/LobbyBoards"
	) as Node3D
	var pre_round_ui: PreRoundUIController = main_game.get_node_or_null("PreRoundUI") as PreRoundUIController
	if lobby_boards == null or pre_round_ui == null:
		push_error("Lobby UI nodes missing")
		quit(FAIL)
		return

	pre_round_ui.set_screen_mode("lobby")
	await create_timer(0.1).timeout

	if lobby_boards.visible:
		push_error("3D LobbyBoards should stay hidden while 2D lobby UI is active")
		quit(FAIL)
		return

	var lobby_panel: Control = pre_round_ui.get_node_or_null("Root/LobbyPanel") as Control
	if lobby_panel == null or not lobby_panel.visible:
		push_error("2D lobby panel should remain visible in lobby mode")
		quit(FAIL)
		return

	var debug_source: DebugJoinSource = main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	var feed_label: Label = pre_round_ui.get_node_or_null(
		"Root/LobbyPanel/Margin/VBox/LobbyNamesScroll/LobbyNamesLabel"
	) as Label
	if debug_source == null or feed_label == null:
		push_error("Lobby join feed nodes missing")
		quit(FAIL)
		return

	debug_source.submit_join("TestViewer")
	await create_timer(0.1).timeout

	if not feed_label.text.contains("TestViewer joins the horde."):
		push_error("Lobby join feed missing line: %s" % feed_label.text)
		quit(FAIL)
		return

	var showcase: ZombieModelShowcaseMenu = pre_round_ui.get_node_or_null(
		"Root/ZombieModelShowcase"
	) as ZombieModelShowcaseMenu
	if showcase == null or not showcase.visible:
		push_error("Zombie model showcase should be visible in lobby mode")
		quit(FAIL)
		return

	print("PASS: single 2D lobby UI with join feed, 3D boards hidden")
	quit(PASS)
