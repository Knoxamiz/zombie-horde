class_name TwitchChatConfig
extends Resource

@export var enabled: bool = false
@export var auto_connect: bool = true
@export var anonymous_mode: bool = true
@export var channel_name: String = ""
@export var join_command: String = "!brains"
@export var websocket_url: String = "wss://irc-ws.chat.twitch.tv:443"
@export var bot_username: String = ""
@export var oauth_token_environment_variable: String = "ZOMBIE_HORDE_TWITCH_OAUTH"
@export_range(1.0, 60.0, 0.5) var reconnect_delay_seconds: float = 5.0
@export_range(1, 10, 1) var max_reconnect_attempts: int = 5

func get_normalized_channel() -> String:
	var normalized: String = channel_name.strip_edges().to_lower()
	if normalized.begins_with("#"):
		normalized = normalized.substr(1)
	return normalized

func get_normalized_command() -> String:
	var normalized: String = join_command.strip_edges().to_lower()
	if normalized.is_empty():
		return "!brains"
	return normalized

