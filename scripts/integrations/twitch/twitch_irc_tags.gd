class_name TwitchIrcTags
extends RefCounted


static func parse_line_tags(line: String) -> Dictionary:
	var tags: Dictionary = {}
	if not line.begins_with("@"):
		return tags

	var first_space: int = line.find(" ")
	if first_space == -1:
		return tags

	var tag_block: String = line.substr(1, first_space - 1)
	for tag in tag_block.split(";"):
		var pair: PackedStringArray = tag.split("=", false, 1)
		if pair.size() == 2:
			tags[pair[0]] = decode_tag_value(pair[1])
		elif pair.size() == 1 and not pair[0].is_empty():
			tags[pair[0]] = "1"
	return tags


static func decode_tag_value(value: String) -> String:
	return value.replace("\\s", " ").replace("\\:", ";").replace("\\r", "").replace("\\n", "")


static func get_display_name(line: String, tags: Dictionary) -> String:
	var display_name: String = str(tags.get("display-name", "")).strip_edges()
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


static func get_login_name(tags: Dictionary) -> String:
	return str(tags.get("login", "")).strip_edges().to_lower()


static func get_user_id(tags: Dictionary) -> String:
	return str(tags.get("user-id", "")).strip_edges()
