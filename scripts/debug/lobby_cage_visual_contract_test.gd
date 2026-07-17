extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1
const MAX_LOBBY_FOG_DENSITY: float = 0.004
const MAX_SCREEN_WASH_ALPHA: float = 0.24
const LOBBY_CAMERA_POSITION := Vector3(0.0, 7.2, 10.5)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Lobby cage visual contract test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.7).timeout

	var game_flow: Node = main_game.get_node_or_null("Systems/GameFlowController")
	if (
		game_flow == null
		or not game_flow.has_method("get_current_phase")
		or str(game_flow.call("get_current_phase")) != "lobby"
	):
		_fail("Game must boot into the lobby phase")
		return

	var lobby_world: Node3D = main_game.get_node_or_null("LobbyWorld") as Node3D
	if lobby_world == null or not lobby_world.is_visible_in_tree():
		_fail("LobbyWorld is missing or hidden")
		return

	var required_cage_nodes: PackedStringArray = PackedStringArray([
		"LobbyWorld/JoinLobby/VoidStage/StageFloor",
		"LobbyWorld/JoinLobby/ContainmentYard/OuterFloor",
		"LobbyWorld/JoinLobby/LobbyBox/Floor/FloorMesh",
		"LobbyWorld/JoinLobby/LobbyBox/CageBars/FrontBarA",
	])
	for node_path in required_cage_nodes:
		var cage_node: Node3D = main_game.get_node_or_null(NodePath(node_path)) as Node3D
		if cage_node == null or not cage_node.is_visible_in_tree():
			_fail("Required lobby cage node is missing or hidden: %s" % node_path)
			return

	var camera_rig: Node3D = main_game.get_node_or_null("SpectatorCamera") as Node3D
	if camera_rig == null or camera_rig.global_position.distance_to(LOBBY_CAMERA_POSITION) > 0.05:
		_fail("Lobby camera is not framed at the cage")
		return

	var world_environment: WorldEnvironment = main_game.get_node_or_null(
		"WorldEnvironment"
	) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		_fail("Lobby world environment is missing")
		return
	if world_environment.environment.fog_density > MAX_LOBBY_FOG_DENSITY:
		_fail("Lobby fog is too dense to keep the cage readable")
		return

	var screen_wash: ColorRect = main_game.get_node_or_null(
		"PreRoundUI/Root/ScreenWash"
	) as ColorRect
	if screen_wash == null or screen_wash.color.a > MAX_SCREEN_WASH_ALPHA:
		_fail("Lobby screen wash obscures the 3D cage")
		return

	print("PASS: lobby cage, camera, and presentation clarity are intact")
	quit(PASS)


func _fail(message: String) -> void:
	push_error(message)
	quit(FAIL)
