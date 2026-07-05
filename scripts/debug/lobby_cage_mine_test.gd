extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Lobby cage mine test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("Could not load main game scene")
		quit(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout

	var join_lobby: JoinLobbyManager = main_game.get_node_or_null("LobbyWorld/JoinLobby") as JoinLobbyManager
	var pre_round_ui: PreRoundUIController = main_game.get_node_or_null("PreRoundUI") as PreRoundUIController
	var debug_source: DebugJoinSource = main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	if join_lobby == null or pre_round_ui == null or debug_source == null:
		push_error("Lobby cage mine test nodes missing")
		quit(FAIL)
		return

	pre_round_ui.set_screen_mode("lobby")
	await create_timer(0.1).timeout

	debug_source.request_test_bits_cheer()
	await create_timer(0.1).timeout

	if not join_lobby.has_cage_mine():
		push_error("Bits cheer should spawn a cage mine")
		quit(FAIL)
		return

	var feed_label: Label = pre_round_ui.get_node_or_null(
		"Root/LobbyPanel/Margin/VBox/LobbyNamesLabel"
	) as Label
	if feed_label == null or not feed_label.text.contains(JoinLobbyManager.BITS_CAGE_MINE_MESSAGE):
		push_error("Bits cheer feed missing cage mine message: %s" % feed_label.text)
		quit(FAIL)
		return

	debug_source.request_test_tier_join(ParticipantJoinInfo.SupporterTier.BITS_DONOR)
	await create_timer(0.1).timeout

	var mine_count: int = 0
	for child in join_lobby.get_children():
		if child is LobbyCageMine:
			mine_count += 1
	if mine_count != 1:
		push_error("Bits join alone should not add another mine, found %d" % mine_count)
		quit(FAIL)
		return

	print("PASS: bits cheer spawns cage mine and posts cage mine message")
	quit(PASS)
