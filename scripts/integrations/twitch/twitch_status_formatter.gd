class_name TwitchStatusFormatter


static func shorten_detail(detail_text: String) -> String:
	var clean_detail: String = detail_text.strip_edges()
	if clean_detail.is_empty():
		return ""
	if clean_detail.contains("twitch_chat_config"):
		return "Add channel_name to twitch_chat_config.local.tres"
	if clean_detail.contains("ZOMBIE_HORDE_TWITCH"):
		return "Set Twitch OAuth env vars (see env.example)."
	if clean_detail.length() > 84:
		return "%s…" % clean_detail.substr(0, 83)
	return clean_detail


static func should_show_status(status_text: String) -> bool:
	var normalized_status: String = status_text.strip_edges().to_lower()
	if normalized_status.is_empty():
		return false
	return normalized_status != "twitch live"


static func format_headline(status_text: String) -> String:
	var clean_status: String = status_text.strip_edges()
	if clean_status.is_empty():
		return "Chat status"
	return clean_status
