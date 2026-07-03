class_name RecordsPanel
extends InfoPanel

func set_records(fastest: String, recent: String) -> void:
	var body := "%s\n\n%s" % [_clean_section(fastest), _clean_section(recent)]
	set_panel_text("CAGE RECORDS", body)
	set_body_font_size(20)

func _clean_section(text: String) -> String:
	if text.strip_edges().is_empty():
		return "-"
	return text.strip_edges()
