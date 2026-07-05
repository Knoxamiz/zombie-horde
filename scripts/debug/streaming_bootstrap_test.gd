extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Streaming bootstrap test ===")
	var command_text: String = TwitchConfigResolver.get_join_command_text()
	if not command_text.contains("!brains"):
		push_error("Join command text should include !brains: %s" % command_text)
		quit(FAIL)
		return

	var config: TwitchChatConfig = TwitchConfigResolver.resolve_config()
	if config == null:
		push_error("Twitch config resolver returned null")
		quit(FAIL)
		return

	var game_settings: GameSettingsController = get_node_or_null("/root/GameSettings") as GameSettingsController
	if game_settings == null:
		push_error("GameSettings autoload missing")
		quit(FAIL)
		return

	game_settings.apply_obs_stream_defaults()
	if not game_settings.should_hide_screen_wash():
		push_error("OBS defaults should hide screen wash")
		quit(FAIL)
		return

	if game_settings.should_show_debug_lobby_controls():
		push_error("OBS defaults should hide lobby debug controls")
		quit(FAIL)
		return

	print("PASS: Twitch command sync and OBS defaults are available")
	quit(PASS)
