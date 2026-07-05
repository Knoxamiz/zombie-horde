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
