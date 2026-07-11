extends Node

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MapNamingScript := preload("res://scripts/maps/map_naming.gd")
const DEFAULT_MAP_ID := MapNamingScript.SIGNATURE_MAP_ID

@export var map_id: String = DEFAULT_MAP_ID
@export var auto_load_on_ready: bool = true
@export var show_race_world: bool = true
@export var frame_camera: bool = true

var _main_game: Node


func _ready() -> void:
	if auto_load_on_ready:
		call_deferred("_run_map_load")


func _run_map_load() -> void:
	print("=== Playable map load test runner ===")
	print("Loading main game and map: %s" % map_id)

	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		push_error("MapLoadTestRunner: could not load main game scene")
		return

	_main_game = packed.instantiate()
	get_tree().root.add_child(_main_game)

	await get_tree().create_timer(0.8).timeout
	_execute_map_load()


func _execute_map_load() -> void:
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		push_error("MapLoadTestRunner: RaceMapController missing")
		return

	if show_race_world:
		var world: Node3D = _main_game.get_node_or_null("World") as Node3D
		if world != null:
			world.visible = true

	var loaded: bool = map_controller.set_active_map_by_id(map_id)
	if not loaded or map_controller.active_map_id != map_id:
		push_error("MapLoadTestRunner: failed to load map '%s'" % map_id)
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(map_id)
	if frame_camera and definition != null:
		var spectator: SpectatorCameraController = _main_game.get_node_or_null(
			"SpectatorCamera"
		) as SpectatorCameraController
		map_controller.frame_spectator_camera_for_definition(spectator, definition, true)

	print("Map '%s' is loaded for dev inspection." % map_id)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_clear_map_load()


func _clear_map_load() -> void:
	if _main_game == null:
		return
	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller != null:
		map_controller.set_active_map_by_id(MapNamingScript.DEFAULT_MAP_ID)
	print("MapLoadTestRunner: restored default map")
