extends Node

const DEFAULT_CONFIG_PATH := "res://resources/config/twitch_chat_config.tres"


func _ready() -> void:
	call_deferred("_bootstrap_streaming")


func _bootstrap_streaming() -> void:
	TwitchConfigResolver.publish_join_command()
	_warn_if_twitch_channel_missing()


func _warn_if_twitch_channel_missing() -> void:
	var config: TwitchChatConfig = TwitchConfigResolver.resolve_config()
	if not config.enabled:
		return
	if not config.get_normalized_channel().is_empty():
		return

	push_warning(
		"Twitch chat is enabled but channel_name is empty. "
		+ "Set your channel in user://twitch_chat_config.local.tres or resources/config/twitch_chat_config.tres."
	)
	GameEvents.chat_connection_status_changed.emit(
		"Twitch needs channel",
		"Set channel_name in twitch_chat_config.local.tres"
	)
