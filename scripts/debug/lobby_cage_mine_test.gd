extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const BITS_CAGE_MINE_MESSAGE := "1 bit = Cage mine!!!"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Lobby cage mine test ===")
	await create_timer(0.1).timeout
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("Could not load main game scene")
		quit(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout

	var join_lobby: Node = main_game.get_node_or_null("LobbyWorld/JoinLobby")
	var pre_round_ui: Node = main_game.get_node_or_null("PreRoundUI")
	var debug_source: Node = main_game.get_node_or_null("Systems/DebugJoinSource")
	if (
		join_lobby == null
		or pre_round_ui == null
		or debug_source == null
		or not join_lobby.has_method("has_cage_mine")
		or not pre_round_ui.has_method("set_screen_mode")
		or not debug_source.has_method("request_test_bits_cheer")
	):
		push_error("Lobby cage mine test nodes missing")
		quit(FAIL)
		return

	pre_round_ui.call("set_screen_mode", "lobby")
	await create_timer(0.1).timeout

	debug_source.call("request_test_bits_cheer")
	await create_timer(0.1).timeout

	if not bool(join_lobby.call("has_cage_mine")):
		push_error("Bits cheer should spawn a cage mine")
		quit(FAIL)
		return

	var feed_label: Label = pre_round_ui.get_node_or_null(
		"Root/LobbyPanel/Margin/VBox/LobbyNamesScroll/LobbyNamesLabel"
	) as Label
	if feed_label == null or not feed_label.text.contains(BITS_CAGE_MINE_MESSAGE):
		push_error("Bits cheer feed missing cage mine message: %s" % feed_label.text)
		quit(FAIL)
		return

	debug_source.call("request_test_tier_join", ParticipantJoinInfo.SupporterTier.BITS_DONOR)
	await create_timer(0.1).timeout

	var mine_count: int = 0
	for child in join_lobby.get_children():
		if _is_lobby_cage_mine(child):
			mine_count += 1
	if mine_count != 1:
		push_error("Bits join alone should not add another mine, found %d" % mine_count)
		quit(FAIL)
		return

	print("PASS: bits cheer spawns cage mine and posts cage mine message")
	quit(PASS)


func _is_lobby_cage_mine(node: Node) -> bool:
	var script: Script = node.get_script() as Script
	return script != null and script.resource_path.ends_with("lobby_cage_mine.gd")
