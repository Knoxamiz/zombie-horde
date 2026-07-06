extends Node

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const DEFAULT_PROTOTYPE_MAP_ID := "broken_bridge_candidate"

@export var prototype_map_id: String = DEFAULT_PROTOTYPE_MAP_ID
@export var auto_load_on_ready: bool = true
@export var show_race_world: bool = true
@export var frame_camera: bool = true

var _main_game: Node


func _ready() -> void:
	if auto_load_on_ready:
		call_deferred("_run_prototype_load")


func _run_prototype_load() -> void:
	print("=== Prototype Map Load Test Runner ===")
	print("Loading main game and prototype map: %s" % prototype_map_id)

	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("PrototypeMapLoadTestRunner: could not load main game scene")
		return

	_main_game = packed.instantiate()
	get_tree().root.add_child(_main_game)

	await get_tree().create_timer(0.8).timeout
	_execute_prototype_load()


func _execute_prototype_load() -> void:
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		push_error("PrototypeMapLoadTestRunner: RaceMapController missing")
		return

	if show_race_world:
		var world: Node3D = _main_game.get_node_or_null("World") as Node3D
		if world != null:
			world.visible = true

	var loaded: bool = map_controller.load_prototype_map_for_test(prototype_map_id)
	if not loaded:
		push_error("PrototypeMapLoadTestRunner: failed to load prototype map '%s'" % prototype_map_id)
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(prototype_map_id)
	if frame_camera and definition != null:
		var spectator: SpectatorCameraController = _main_game.get_node_or_null(
			"SpectatorCamera"
		) as SpectatorCameraController
		map_controller.frame_spectator_camera_for_definition(spectator, definition, true)

	print("Prototype map '%s' is loaded for dev inspection." % prototype_map_id)
	print("Streamer Settings still only lists playable maps; this load does not save map selection.")


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_clear_prototype_load()


func _clear_prototype_load() -> void:
	if _main_game == null:
		return
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller != null:
		map_controller.clear_prototype_test_load(true)
	print("PrototypeMapLoadTestRunner: restored saved playable map")
