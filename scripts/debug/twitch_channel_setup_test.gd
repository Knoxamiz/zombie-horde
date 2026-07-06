extends SceneTree

const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Twitch channel setup test ===")

	var normalized: String = TwitchConfigResolver.normalize_channel_name("#Knoxamiz")
	if normalized != "knoxamiz":
		push_error("Unexpected normalized channel: %s" % normalized)
		quit(FAIL)
		return

	if not TwitchConfigResolver.is_valid_channel_name("stream_test_01"):
		push_error("Expected valid channel name")
		quit(FAIL)
		return

	if TwitchConfigResolver.is_valid_channel_name("ab"):
		push_error("Expected short channel name to be invalid")
		quit(FAIL)
		return

	var save_error: Error = TwitchConfigResolver.save_local_channel("stream_test_01")
	if save_error != OK:
		push_error("Could not save local channel: %s" % str(save_error))
		quit(FAIL)
		return

	var resolved: TwitchChatConfig = TwitchConfigResolver.resolve_config()
	if resolved.get_normalized_channel() != "stream_test_01":
		push_error("Resolved channel mismatch: %s" % resolved.get_normalized_channel())
		quit(FAIL)
		return

	if not TwitchConfigResolver.has_configured_channel():
		push_error("Expected configured channel after save")
		quit(FAIL)
		return

	print("PASS: Twitch channel can be saved and resolved from user config")
	quit(PASS)
