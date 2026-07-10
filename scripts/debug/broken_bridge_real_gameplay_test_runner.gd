extends Node

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_candidate"

@export var prototype_map_id: String = MAP_ID
@export var zombie_count: int = 5
@export var auto_start_on_ready: bool = true
@export var frame_camera: bool = true
@export var restore_on_escape: bool = true

var _main_game: Node


func _ready() -> void:
	if auto_start_on_ready:
		call_deferred("_run_gameplay_test")


func _run_gameplay_test() -> void:
	print("=== Broken Bridge Real Gameplay Test Runner ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("BrokenBridgeGameplayTestRunner: could not load main game scene")
		return

	_main_game = packed.instantiate()
	get_tree().root.add_child(_main_game)
	await get_tree().create_timer(0.8).timeout
	await _start_prototype_race()


func _start_prototype_race() -> void:
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	var round_manager: RoundManager = _main_game.get_node_or_null(
		"Systems/RoundManager"
	) as RoundManager
	var debug_join: DebugJoinSource = _main_game.get_node_or_null(
		"Systems/DebugJoinSource"
	) as DebugJoinSource
	if map_controller == null or round_manager == null or debug_join == null:
		push_error("BrokenBridgeGameplayTestRunner: missing core systems")
		return

	if not map_controller.load_prototype_map_for_test(prototype_map_id):
		push_error("BrokenBridgeGameplayTestRunner: failed to load '%s'" % prototype_map_id)
		return

	round_manager.configure_immediate_launch_for_tests()
		map_controller.human_defender_config.defender_count = 0

	var world: Node3D = _main_game.get_node_or_null("World") as Node3D
	if world != null:
		world.visible = true

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(prototype_map_id)
	if frame_camera and definition != null:
		var spectator: SpectatorCameraController = _main_game.get_node_or_null(
			"SpectatorCamera"
		) as SpectatorCameraController
		map_controller.frame_spectator_camera_for_definition(spectator, definition, true)

	for _index in range(max(zombie_count, 1)):
		debug_join.request_random_join()
	await get_tree().create_timer(0.15).timeout
	round_manager.start_round()

	var hud: HudController = _main_game.get_node_or_null("HUD") as HudController
	if hud != null:
		hud.visible = true
		if hud.has_method("refresh_display"):
			hud.refresh_display()

	print(
		"Started real gameplay test on '%s' with %d zombies. Press Esc to restore City Highway."
		% [prototype_map_id, zombie_count]
	)


func _unhandled_input(event: InputEvent) -> void:
	if not restore_on_escape:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_restore_saved_map()


func _restore_saved_map() -> void:
	if _main_game == null:
		return
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller != null:
		map_controller.clear_prototype_test_load(true)
	print("BrokenBridgeGameplayTestRunner: restored saved playable map")
