class_name TwitchJoinSource
extends JoinSource

const ANONYMOUS_PASSWORD: String = "SCHMOOPIIE"

@export var config: TwitchChatConfig

var _socket: WebSocketPeer
var _status_text: String = "Twitch disabled"
var _status_detail: String = ""
var _was_open: bool = false
var _sent_auth: bool = false
var _manual_disconnect: bool = false
var _reconnect_attempts: int = 0
var _reconnect_timer: float = 0.0
var _anonymous_id: int = 0
var _pending_buffer: String = ""

func _ready() -> void:
	_anonymous_id = int(Time.get_ticks_msec() % 90000) + 10000
	if config == null:
		_publish_status("Twitch missing config", "")
		return

	if not config.enabled:
		_publish_status("Twitch disabled", "Enable resources/config/twitch_chat_config.tres to connect.")
		return

	if config.auto_connect:
		connect_to_chat()

func _process(delta: float) -> void:
	if _reconnect_timer > 0.0:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			connect_to_chat()

	if _socket == null:
		return

	_socket.poll()
	var state: int = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_reconnect_attempts = 0
			_send_login()
		_read_available_packets()
	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_publish_status("Twitch disconnected", "")
		_was_open = false
		_sent_auth = false
		_socket = null
		if not _manual_disconnect:
			_schedule_reconnect()

func connect_to_chat() -> void:
	if config == null:
		_publish_status("Twitch missing config", "")
		return

	var channel: String = config.get_normalized_channel()
	if channel.is_empty():
		_publish_status("Twitch needs channel", "Set channel_name in twitch_chat_config.tres.")
		return

	_manual_disconnect = false
	_socket = WebSocketPeer.new()
	var error: int = _socket.connect_to_url(config.websocket_url)
	if error != OK:
		_publish_status("Twitch connection error", "Error code %d" % int(error))
		_socket = null
		_schedule_reconnect()
		return

	_publish_status("Twitch connecting", channel)

func disconnect_from_chat() -> void:
	_manual_disconnect = true
	if _socket != null:
		_socket.close()
	_socket = null
	_was_open = false
	_sent_auth = false
	_publish_status("Twitch disconnected", "Manual disconnect")

func get_status_text() -> String:
	return _status_text

func get_status_detail() -> String:
	return _status_detail

func _send_login() -> void:
	if _sent_auth or config == null:
		return

	var channel: String = config.get_normalized_channel()
	var nick: String = _get_nick()
	var password: String = _get_password()
	if nick.is_empty():
		_publish_status("Twitch missing username", "Set bot_username or ZOMBIE_HORDE_TWITCH_BOT_USERNAME.")
		_close_socket_after_configuration_error()
		return
	if password.is_empty():
		_publish_status("Twitch missing OAuth", "Set %s in your environment." % config.oauth_token_environment_variable)
		_close_socket_after_configuration_error()
		return

	_send_raw("PASS %s" % password)
	_send_raw("NICK %s" % nick)
	_send_raw("CAP REQ :twitch.tv/tags twitch.tv/commands")
	_send_raw("JOIN #%s" % channel)
	_sent_auth = true
	_publish_status("Twitch live", "#%s" % channel)

func _read_available_packets() -> void:
	while _socket != null and _socket.get_available_packet_count() > 0:
		var packet_text: String = _socket.get_packet().get_string_from_utf8()
		_pending_buffer += packet_text
		_flush_complete_lines()

func _flush_complete_lines() -> void:
	while true:
		var newline_index: int = _pending_buffer.find("\n")
		if newline_index == -1:
			return

		var line: String = _pending_buffer.substr(0, newline_index).strip_edges()
		_pending_buffer = _pending_buffer.substr(newline_index + 1)
		if not line.is_empty():
			_handle_irc_line(line)

func _handle_irc_line(line: String) -> void:
	if line.begins_with("PING"):
		_send_raw("PONG :tmi.twitch.tv")
		return

	if line.find(" PRIVMSG ") == -1:
		return

	var message_text: String = _extract_chat_message(line)
	if message_text.is_empty():
		return

	var command: String = config.get_normalized_command()
	var lower_message: String = message_text.to_lower()
	if lower_message != command and not lower_message.begins_with("%s " % command):
		return

	var display_name: String = _sanitize_display_name(_extract_display_name(line))
	if display_name.is_empty():
		return

	submit_join(display_name)

func _extract_chat_message(line: String) -> String:
	var privmsg_index: int = line.find(" PRIVMSG ")
	if privmsg_index == -1:
		return ""

	var message_marker: String = " :"
	var message_index: int = line.find(message_marker, privmsg_index)
	if message_index == -1:
		return ""

	return line.substr(message_index + message_marker.length()).strip_edges()

func _extract_display_name(line: String) -> String:
	var display_name: String = _extract_display_name_from_tags(line)
	if not display_name.is_empty():
		return display_name

	var working_line: String = line
	if working_line.begins_with("@"):
		var first_space: int = working_line.find(" ")
		if first_space != -1:
			working_line = working_line.substr(first_space + 1)

	if working_line.begins_with(":"):
		var bang_index: int = working_line.find("!")
		if bang_index > 1:
			return working_line.substr(1, bang_index - 1)

	return ""

func _extract_display_name_from_tags(line: String) -> String:
	if not line.begins_with("@"):
		return ""

	var first_space: int = line.find(" ")
	if first_space == -1:
		return ""

	var tag_block: String = line.substr(1, first_space - 1)
	var tags: PackedStringArray = tag_block.split(";")
	for tag in tags:
		var pair: PackedStringArray = tag.split("=", false, 1)
		if pair.size() == 2 and pair[0] == "display-name":
			return _decode_irc_tag_value(pair[1])
	return ""

func _decode_irc_tag_value(value: String) -> String:
	return value.replace("\\s", " ").replace("\\:", ";").replace("\\r", "").replace("\\n", "")

func _sanitize_display_name(raw_name: String) -> String:
	var trimmed: String = raw_name.strip_edges()
	var result: String = ""
	for index in range(trimmed.length()):
		var character: String = trimmed.substr(index, 1)
		var codepoint: int = character.unicode_at(0)
		if codepoint >= 32 and codepoint != 127:
			result += character

	if result.length() > 32:
		result = result.substr(0, 32)
	return result

func _send_raw(line: String) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	_socket.send_text("%s\r\n" % line)

func _schedule_reconnect() -> void:
	if config == null:
		return

	if _reconnect_attempts >= config.max_reconnect_attempts:
		_publish_status("Twitch offline", "Reconnect limit reached.")
		return

	_reconnect_attempts += 1
	_reconnect_timer = config.reconnect_delay_seconds
	_publish_status("Twitch reconnecting", "Attempt %d/%d" % [_reconnect_attempts, config.max_reconnect_attempts])

func _publish_status(status_text: String, detail: String) -> void:
	_status_text = status_text
	_status_detail = detail
	GameEvents.chat_connection_status_changed.emit(status_text, detail)

func _get_nick() -> String:
	if config.anonymous_mode:
		return "justinfan%d" % _anonymous_id

	var configured_name: String = config.bot_username.strip_edges().to_lower()
	if not configured_name.is_empty():
		return configured_name

	var env_name: String = OS.get_environment("ZOMBIE_HORDE_TWITCH_BOT_USERNAME").strip_edges().to_lower()
	if not env_name.is_empty():
		return env_name

	return ""

func _get_password() -> String:
	if config.anonymous_mode:
		return ANONYMOUS_PASSWORD

	var token: String = OS.get_environment(config.oauth_token_environment_variable).strip_edges()
	if token.is_empty():
		return ""
	if token.begins_with("oauth:"):
		return token
	return "oauth:%s" % token

func _close_socket_after_configuration_error() -> void:
	_manual_disconnect = true
	if _socket != null:
		_socket.close()
	_socket = null
	_was_open = false
	_sent_auth = false
