extends RefCounted

const SAVE_PATH := "user://hud_layout.cfg"
const SECTION := "hud_layout"
const SAVE_VERSION := 1

static var PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]

var panels: Dictionary = {}

static func load_from_disk():
	var profile = create_default_profile()
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return profile

	var version: int = int(config.get_value(SECTION, "version", 0))
	if version < SAVE_VERSION:
		return profile

	for panel_id in PANEL_IDS:
		var prefix: String = "%s_" % panel_id
		if not config.has_section_key(SECTION, "%sanchor_left" % prefix):
			continue
		profile.panels[panel_id] = {
			"anchor_left": float(config.get_value(SECTION, "%sanchor_left" % prefix, 0.0)),
			"anchor_top": float(config.get_value(SECTION, "%sanchor_top" % prefix, 0.0)),
			"anchor_right": float(config.get_value(SECTION, "%sanchor_right" % prefix, 0.0)),
			"anchor_bottom": float(config.get_value(SECTION, "%sanchor_bottom" % prefix, 0.0)),
			"offset_left": float(config.get_value(SECTION, "%soffset_left" % prefix, 0.0)),
			"offset_top": float(config.get_value(SECTION, "%soffset_top" % prefix, 0.0)),
			"offset_right": float(config.get_value(SECTION, "%soffset_right" % prefix, 0.0)),
			"offset_bottom": float(config.get_value(SECTION, "%soffset_bottom" % prefix, 0.0)),
			"visible": bool(config.get_value(SECTION, "%svisible" % prefix, true)),
			"min_width": float(config.get_value(SECTION, "%smin_width" % prefix, 0.0)),
			"min_height": float(config.get_value(SECTION, "%smin_height" % prefix, 0.0)),
		}
	return profile

static func create_default_profile():
	var profile = load("res://scripts/ui/hud_layout_profile.gd").new()
	profile.panels = {
		"top": _panel_dict(0.0, 0.0, 0.0, 0.0, 40.0, 40.0, 460.0, 248.0, true, 420.0, 0.0),
		"roster": _panel_dict(1.0, 0.0, 1.0, 0.0, -400.0, 40.0, -40.0, 300.0, true, 360.0, 0.0),
		"leaderboard": _panel_dict(1.0, 0.5, 1.0, 0.5, -370.0, -120.0, -40.0, 300.0, true, 330.0, 0.0),
		"command": _panel_dict(0.0, 1.0, 0.0, 1.0, 40.0, -96.0, 460.0, -40.0, true, 420.0, 0.0),
		"countdown": _panel_dict(0.5, 0.5, 0.5, 0.5, -110.0, -110.0, 110.0, 110.0, true, 0.0, 0.0),
	}
	return profile

static func _panel_dict(
	anchor_left: float,
	anchor_top: float,
	anchor_right: float,
	anchor_bottom: float,
	offset_left: float,
	offset_top: float,
	offset_right: float,
	offset_bottom: float,
	is_visible: bool,
	min_width: float,
	min_height: float
) -> Dictionary:
	return {
		"anchor_left": anchor_left,
		"anchor_top": anchor_top,
		"anchor_right": anchor_right,
		"anchor_bottom": anchor_bottom,
		"offset_left": offset_left,
		"offset_top": offset_top,
		"offset_right": offset_right,
		"offset_bottom": offset_bottom,
		"visible": is_visible,
		"min_width": min_width,
		"min_height": min_height,
	}

static func capture_from(hud_controller: Node):
	var profile = load("res://scripts/ui/hud_layout_profile.gd").new()
	for panel_id in PANEL_IDS:
		if not hud_controller.has_method("get_layout_panel"):
			continue
		var panel: Control = hud_controller.call("get_layout_panel", panel_id) as Control
		if panel != null:
			profile.panels[panel_id] = _capture_panel(panel)
	return profile

func apply_to(hud_controller: Node) -> void:
	for panel_id in PANEL_IDS:
		if not hud_controller.has_method("get_layout_panel"):
			continue
		var panel: Control = hud_controller.call("get_layout_panel", panel_id) as Control
		if panel == null:
			continue
		var data: Dictionary = panels.get(panel_id, {})
		if data.is_empty():
			continue
		_apply_panel(panel, data)

func save_to_disk() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SECTION, "version", SAVE_VERSION)
	for panel_id in PANEL_IDS:
		var data: Dictionary = panels.get(panel_id, {})
		if data.is_empty():
			continue
		var prefix: String = "%s_" % panel_id
		config.set_value(SECTION, "%sanchor_left" % prefix, data.get("anchor_left", 0.0))
		config.set_value(SECTION, "%sanchor_top" % prefix, data.get("anchor_top", 0.0))
		config.set_value(SECTION, "%sanchor_right" % prefix, data.get("anchor_right", 0.0))
		config.set_value(SECTION, "%sanchor_bottom" % prefix, data.get("anchor_bottom", 0.0))
		config.set_value(SECTION, "%soffset_left" % prefix, data.get("offset_left", 0.0))
		config.set_value(SECTION, "%soffset_top" % prefix, data.get("offset_top", 0.0))
		config.set_value(SECTION, "%soffset_right" % prefix, data.get("offset_right", 0.0))
		config.set_value(SECTION, "%soffset_bottom" % prefix, data.get("offset_bottom", 0.0))
		config.set_value(SECTION, "%svisible" % prefix, data.get("visible", true))
		config.set_value(SECTION, "%smin_width" % prefix, data.get("min_width", 0.0))
		config.set_value(SECTION, "%smin_height" % prefix, data.get("min_height", 0.0))
	return config.save(SAVE_PATH)

static func _capture_panel(panel: Control) -> Dictionary:
	return {
		"anchor_left": panel.anchor_left,
		"anchor_top": panel.anchor_top,
		"anchor_right": panel.anchor_right,
		"anchor_bottom": panel.anchor_bottom,
		"offset_left": panel.offset_left,
		"offset_top": panel.offset_top,
		"offset_right": panel.offset_right,
		"offset_bottom": panel.offset_bottom,
		"visible": panel.visible,
		"min_width": panel.custom_minimum_size.x,
		"min_height": panel.custom_minimum_size.y,
	}

static func _apply_panel(panel: Control, data: Dictionary) -> void:
	panel.anchor_left = float(data.get("anchor_left", panel.anchor_left))
	panel.anchor_top = float(data.get("anchor_top", panel.anchor_top))
	panel.anchor_right = float(data.get("anchor_right", panel.anchor_right))
	panel.anchor_bottom = float(data.get("anchor_bottom", panel.anchor_bottom))
	panel.offset_left = float(data.get("offset_left", panel.offset_left))
	panel.offset_top = float(data.get("offset_top", panel.offset_top))
	panel.offset_right = float(data.get("offset_right", panel.offset_right))
	panel.offset_bottom = float(data.get("offset_bottom", panel.offset_bottom))
	panel.visible = bool(data.get("visible", true))
	var min_width: float = float(data.get("min_width", 0.0))
	var min_height: float = float(data.get("min_height", 0.0))
	if min_width > 0.0 or min_height > 0.0:
		panel.custom_minimum_size = Vector2(min_width, min_height)

static func flatten_panel_to_absolute(panel: Control) -> void:
	var global_rect: Rect2 = panel.get_global_rect()
	var parent: Control = panel.get_parent() as Control
	if parent == null:
		return
	var parent_transform: Transform2D = parent.get_global_transform_with_canvas()
	var local_pos: Vector2 = parent_transform.affine_inverse() * global_rect.position
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = local_pos.x
	panel.offset_top = local_pos.y
	panel.offset_right = local_pos.x + global_rect.size.x
	panel.offset_bottom = local_pos.y + global_rect.size.y
