class_name MainMenuController
extends Control

const AUDIO_MANAGER_SCENE: PackedScene = preload("res://scenes/audio/audio_manager.tscn")
const GAME_SETTINGS_SCENE: PackedScene = preload("res://scenes/settings/game_settings_menu.tscn")

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/main_game.tscn"

var _transitioning: bool = false

@onready var _start_button: Button = $Center/MenuPanel/VBox/StartButton
@onready var _streamer_button: Button = $Center/MenuPanel/VBox/StreamerButton
@onready var _settings_button: Button = $Center/MenuPanel/VBox/SettingsButton
@onready var _quit_button: Button = $Center/MenuPanel/VBox/QuitButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music_controller: MusicController = _get_or_create_music_controller()
	if music_controller != null:
		music_controller.play_menu_music()

	_start_button.pressed.connect(_on_start_pressed)
	_streamer_button.pressed.connect(_on_streamer_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	_launch_lobby(0, false)

func _on_streamer_pressed() -> void:
	_launch_lobby(0, true)

func _on_settings_pressed() -> void:
	var game_settings: GameSettingsController = _get_or_create_game_settings()
	if game_settings != null:
		game_settings.open_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _launch_lobby(debug_joins_to_seed: int, open_settings: bool) -> void:
	if _transitioning:
		return

	_transitioning = true
	_set_buttons_enabled(false)
	LaunchState.request_lobby(debug_joins_to_seed, open_settings)
	var error: Error = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		_transitioning = false
		_set_buttons_enabled(true)
		push_error("Unable to load game scene: %s" % game_scene_path)

func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in [_start_button, _streamer_button, _settings_button, _quit_button]:
		if button != null:
			button.disabled = not enabled

func _get_or_create_music_controller() -> MusicController:
	var music_controller: MusicController = get_node_or_null("/root/AudioManager") as MusicController
	if music_controller != null:
		return music_controller

	music_controller = AUDIO_MANAGER_SCENE.instantiate() as MusicController
	if music_controller == null:
		return null

	music_controller.name = "AudioManager"
	get_tree().root.add_child(music_controller)
	return music_controller

func _get_or_create_game_settings() -> GameSettingsController:
	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings != null:
		return game_settings

	game_settings = GAME_SETTINGS_SCENE.instantiate() as GameSettingsController
	if game_settings == null:
		return null

	game_settings.name = "GameSettings"
	get_tree().root.add_child(game_settings)
	return game_settings
