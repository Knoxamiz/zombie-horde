class_name HudLayoutProfile
extends RefCounted

const SAVE_PATH := "user://hud_layout.cfg"
const SECTION := "hud_layout"
const SAVE_VERSION := 2

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
		"top": _panel_dict(40.0, 40.0, 460.0, 248.0, true, 420.0, 208.0),
		"roster": _panel_dict(1200.0, 40.0, 1560.0, 300.0, true, 360.0, 260.0),
		"leaderboard": _panel_dict(1230.0, 330.0, 1560.0, 750.0, true, 330.0, 420.0),
		"command": _panel_dict(40.0, 804.0, 460.0, 860.0, true, 420.0, 56.0),
		"countdown": _panel_dict(690.0, 340.0, 910.0, 560.0, true, 220.0, 220.0),
	}
	return profile

static func _panel_dict(
	offset_left: float,
	offset_top: float,
	offset_right: float,
	offset_bottom: float,
	is_visible: bool,
	min_width: float,
	min_height: float
) -> Dictionary:
	return {
		"anchor_left": 0.0,
		"anchor_top": 0.0,
		"anchor_right": 0.0,
		"anchor_bottom": 0.0,
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
	flatten_panel_to_absolute(panel)
	return {
		"anchor_left": 0.0,
		"anchor_top": 0.0,
		"anchor_right": 0.0,
		"anchor_bottom": 0.0,
		"offset_left": panel.offset_left,
		"offset_top": panel.offset_top,
		"offset_right": panel.offset_right,
		"offset_bottom": panel.offset_bottom,
		"visible": panel.visible,
		"min_width": panel.size.x,
		"min_height": panel.size.y,
	}

static func _apply_panel(panel: Control, data: Dictionary) -> void:
	panel.layout_mode = 0
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = float(data.get("offset_left", panel.offset_left))
	panel.offset_top = float(data.get("offset_top", panel.offset_top))
	panel.offset_right = float(data.get("offset_right", panel.offset_right))
	panel.offset_bottom = float(data.get("offset_bottom", panel.offset_bottom))
	panel.visible = bool(data.get("visible", true))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var min_width: float = float(data.get("min_width", 0.0))
	var min_height: float = float(data.get("min_height", 0.0))
	if min_width > 0.0:
		panel.custom_minimum_size.x = min_width
	if min_height > 0.0:
		panel.custom_minimum_size.y = min_height

static func flatten_panel_to_absolute(panel: Control) -> void:
	var global_rect: Rect2 = panel.get_global_rect()
	var parent: Control = panel.get_parent() as Control
	if parent == null:
		return
	var parent_transform: Transform2D = parent.get_global_transform_with_canvas()
	var local_pos: Vector2 = parent_transform.affine_inverse() * global_rect.position
	set_absolute_rect(panel, Rect2(local_pos, global_rect.size))

static func set_absolute_rect(panel: Control, rect: Rect2) -> void:
	panel.layout_mode = 0
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = rect.position.x
	panel.offset_top = rect.position.y
	panel.offset_right = rect.position.x + max(rect.size.x, 120.0)
	panel.offset_bottom = rect.position.y + max(rect.size.y, 72.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func get_absolute_rect(panel: Control) -> Rect2:
	return Rect2(
		panel.offset_left,
		panel.offset_top,
		panel.offset_right - panel.offset_left,
		panel.offset_bottom - panel.offset_top
	)
