class_name TwitchConfigResolver
extends RefCounted

const DEFAULT_CONFIG_PATH := "res://resources/config/twitch_chat_config.tres"
const LOCAL_CONFIG_PATH := "user://twitch_chat_config.local.tres"


static func resolve_config(base_config: TwitchChatConfig = null) -> TwitchChatConfig:
	var resolved: TwitchChatConfig = base_config
	if resolved == null:
		resolved = load(DEFAULT_CONFIG_PATH) as TwitchChatConfig
	if resolved == null:
		return TwitchChatConfig.new()

	var merged: TwitchChatConfig = resolved.duplicate(true)
	if ResourceLoader.exists(LOCAL_CONFIG_PATH):
		var local_config: TwitchChatConfig = load(LOCAL_CONFIG_PATH) as TwitchChatConfig
		if local_config != null:
			_apply_overrides(merged, local_config)
	return merged


static func get_join_command_text(config: TwitchChatConfig = null) -> String:
	var active_config: TwitchChatConfig = resolve_config(config)
	return "Type %s to join." % active_config.get_normalized_command()


static func publish_join_command(config: TwitchChatConfig = null) -> void:
	GameEvents.command_text_changed.emit(get_join_command_text(config))


static func normalize_channel_name(raw_channel: String) -> String:
	var normalized: String = raw_channel.strip_edges().to_lower()
	if normalized.begins_with("#"):
		normalized = normalized.substr(1)
	return normalized


static func is_valid_channel_name(channel: String) -> bool:
	var normalized: String = normalize_channel_name(channel)
	if normalized.length() < 3 or normalized.length() > 25:
		return false
	for index in range(normalized.length()):
		var character: String = normalized.substr(index, 1)
		var is_letter: bool = character >= "a" and character <= "z"
		var is_digit: bool = character >= "0" and character <= "9"
		if not is_letter and not is_digit and character != "_":
			return false
	return true


static func has_configured_channel(config: TwitchChatConfig = null) -> bool:
	var active_config: TwitchChatConfig = resolve_config(config)
	return active_config.enabled and not active_config.get_normalized_channel().is_empty()


static func save_local_channel(raw_channel: String) -> Error:
	var normalized_channel: String = normalize_channel_name(raw_channel)
	if not is_valid_channel_name(normalized_channel):
		return ERR_INVALID_PARAMETER

	var local_config: TwitchChatConfig = null
	if ResourceLoader.exists(LOCAL_CONFIG_PATH):
		local_config = load(LOCAL_CONFIG_PATH) as TwitchChatConfig
	if local_config == null:
		local_config = TwitchChatConfig.new()
		local_config.enabled = true
		local_config.auto_connect = true
		local_config.anonymous_mode = true
		local_config.join_command = "!brains"

	local_config.channel_name = normalized_channel
	local_config.enabled = true
	return ResourceSaver.save(local_config, LOCAL_CONFIG_PATH)


static func _apply_overrides(target: TwitchChatConfig, overrides: TwitchChatConfig) -> void:
	if not overrides.channel_name.strip_edges().is_empty():
		target.channel_name = overrides.channel_name
	if not overrides.join_command.strip_edges().is_empty():
		target.join_command = overrides.join_command
	if not overrides.bot_username.strip_edges().is_empty():
		target.bot_username = overrides.bot_username
	if not overrides.oauth_token_environment_variable.strip_edges().is_empty():
		target.oauth_token_environment_variable = overrides.oauth_token_environment_variable
	if not overrides.websocket_url.strip_edges().is_empty():
		target.websocket_url = overrides.websocket_url

	target.enabled = overrides.enabled
	target.auto_connect = overrides.auto_connect
	target.anonymous_mode = overrides.anonymous_mode
	target.reconnect_delay_seconds = overrides.reconnect_delay_seconds
	target.max_reconnect_attempts = overrides.max_reconnect_attempts
