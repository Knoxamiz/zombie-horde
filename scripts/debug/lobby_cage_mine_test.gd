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
	if join_lobby == null:
		push_error("JoinLobby manager missing")
		quit(FAIL)
		return

	var mine: LobbyCageMine = join_lobby.spawn_cage_mine(true)
	if mine == null:
		push_error("Cage mine should spawn from test API")
		quit(FAIL)
		return

	if not join_lobby.has_cage_mine():
		push_error("JoinLobby should report active cage mine")
		quit(FAIL)
		return

	var debug_source: DebugJoinSource = main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	if debug_source == null:
		push_error("Debug join source missing")
		quit(FAIL)
		return

	debug_source.request_test_tier_join(ParticipantJoinInfo.SupporterTier.BITS_DONOR)
	await create_timer(0.1).timeout

	if not join_lobby.has_cage_mine():
		push_error("Bits join should keep cage mine active")
		quit(FAIL)
		return

	print("PASS: lobby cage mine spawns for test button and bits joins")
	quit(PASS)
