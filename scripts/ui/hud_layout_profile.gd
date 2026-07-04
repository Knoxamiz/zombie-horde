class_name HudLayoutProfile
extends RefCounted

const SAVE_PATH := "user://hud_layout.cfg"
const SECTION := "hud_layout"
const SAVE_VERSION := 4
const MIN_PANEL_WIDTH := 120.0
const MIN_PANEL_HEIGHT := 48.0

static var PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]

var panels: Dictionary = {}


static func load_from_disk(viewport_size: Vector2 = Vector2(1600.0, 900.0)):
	var profile: HudLayoutProfile = create_default_profile(viewport_size)
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return profile

	var version: int = int(config.get_value(SECTION, "version", 0))
	if version < SAVE_VERSION:
		return profile

	for panel_id in PANEL_IDS:
		var prefix: String = "%s_" % panel_id
		if not config.has_section_key(SECTION, "%soffset_left" % prefix):
			continue
		var data: Dictionary = {
			"anchor_left": 0.0,
			"anchor_top": 0.0,
			"anchor_right": 0.0,
			"anchor_bottom": 0.0,
			"offset_left": float(config.get_value(SECTION, "%soffset_left" % prefix, 0.0)),
			"offset_top": float(config.get_value(SECTION, "%soffset_top" % prefix, 0.0)),
			"offset_right": float(config.get_value(SECTION, "%soffset_right" % prefix, 0.0)),
			"offset_bottom": float(config.get_value(SECTION, "%soffset_bottom" % prefix, 0.0)),
			"visible": bool(config.get_value(SECTION, "%svisible" % prefix, true)),
		}
		if _is_panel_data_valid(data, viewport_size):
			profile.panels[panel_id] = data
	return profile


static func create_default_profile(viewport_size: Vector2 = Vector2(1600.0, 900.0)) -> HudLayoutProfile:
	var profile: HudLayoutProfile = HudLayoutProfile.new()
	var margin: float = 40.0
	var right: float = viewport_size.x - margin
	var bottom: float = viewport_size.y - margin

	# Corner layout matching the streamer default screenshot (1600x900).
	profile.panels = {
		# Top-left tall: Race Status
		"top": _panel_dict(margin, margin, margin + 360.0, margin + 380.0, true),
		# Bottom-left strip: Chat Command
		"command": _panel_dict(margin, bottom - 56.0, margin + 420.0, bottom, true),
		# Top-right wide: Live Feed
		"roster": _panel_dict(right - 680.0, margin, right, margin + 220.0, true),
		# Bottom-right tall: Top 10 Standings
		"leaderboard": _panel_dict(right - 360.0, margin + 240.0, right, bottom - 72.0, true),
		# Countdown stays centered; hidden during layout edit
		"countdown": _panel_dict(
			viewport_size.x * 0.5 - 110.0,
			viewport_size.y * 0.5 - 110.0,
			viewport_size.x * 0.5 + 110.0,
			viewport_size.y * 0.5 + 110.0,
			true
		),
	}
	return profile


static func _panel_dict(
	offset_left: float,
	offset_top: float,
	offset_right: float,
	offset_bottom: float,
	is_visible: bool
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
	}


static func capture_from(hud_controller: Node) -> HudLayoutProfile:
	var profile: HudLayoutProfile = HudLayoutProfile.new()
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


func is_valid_for_viewport(viewport_size: Vector2) -> bool:
	if panels.is_empty():
		return false
	for panel_id in PANEL_IDS:
		var data: Dictionary = panels.get(panel_id, {})
		if data.is_empty() or not _is_panel_data_valid(data, viewport_size):
			return false
	return true


func save_to_disk() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "version", SAVE_VERSION)
	for panel_id in PANEL_IDS:
		var data: Dictionary = panels.get(panel_id, {})
		if data.is_empty():
			continue
		var prefix: String = "%s_" % panel_id
		config.set_value(SECTION, "%sanchor_left" % prefix, 0.0)
		config.set_value(SECTION, "%sanchor_top" % prefix, 0.0)
		config.set_value(SECTION, "%sanchor_right" % prefix, 0.0)
		config.set_value(SECTION, "%sanchor_bottom" % prefix, 0.0)
		config.set_value(SECTION, "%soffset_left" % prefix, data.get("offset_left", 0.0))
		config.set_value(SECTION, "%soffset_top" % prefix, data.get("offset_top", 0.0))
		config.set_value(SECTION, "%soffset_right" % prefix, data.get("offset_right", 0.0))
		config.set_value(SECTION, "%soffset_bottom" % prefix, data.get("offset_bottom", 0.0))
		config.set_value(SECTION, "%svisible" % prefix, data.get("visible", true))
	return config.save(SAVE_PATH)


static func clear_saved_layout() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


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
	}


static func _apply_panel(panel: Control, data: Dictionary) -> void:
	set_absolute_rect(panel, get_absolute_rect_from_data(data))
	panel.visible = bool(data.get("visible", true))


static func get_absolute_rect_from_data(data: Dictionary) -> Rect2:
	return Rect2(
		float(data.get("offset_left", 0.0)),
		float(data.get("offset_top", 0.0)),
		float(data.get("offset_right", 0.0)) - float(data.get("offset_left", 0.0)),
		float(data.get("offset_bottom", 0.0)) - float(data.get("offset_top", 0.0))
	)


static func _is_panel_data_valid(data: Dictionary, viewport_size: Vector2) -> bool:
	var width: float = float(data.get("offset_right", 0.0)) - float(data.get("offset_left", 0.0))
	var height: float = float(data.get("offset_bottom", 0.0)) - float(data.get("offset_top", 0.0))
	if width < MIN_PANEL_WIDTH or height < MIN_PANEL_HEIGHT:
		return false
	if width > viewport_size.x or height > viewport_size.y:
		return false
	return true


static func flatten_panel_to_absolute(panel: Control) -> void:
	var parent: Control = panel.get_parent() as Control
	if parent == null:
		return
	var global_rect: Rect2 = panel.get_global_rect()
	var local_pos: Vector2 = parent.get_global_transform_with_canvas().affine_inverse() * global_rect.position
	set_absolute_rect(panel, Rect2(local_pos, get_absolute_rect(panel).size))


static func set_absolute_rect(panel: Control, rect: Rect2) -> void:
	var clamped_size: Vector2 = Vector2(
		maxf(rect.size.x, MIN_PANEL_WIDTH),
		maxf(rect.size.y, MIN_PANEL_HEIGHT)
	)
	panel.layout_mode = 0
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = rect.position.x
	panel.offset_top = rect.position.y
	panel.offset_right = rect.position.x + clamped_size.x
	panel.offset_bottom = rect.position.y + clamped_size.y
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2.ZERO


static func get_absolute_rect(panel: Control) -> Rect2:
	return Rect2(
		panel.offset_left,
		panel.offset_top,
		panel.offset_right - panel.offset_left,
		panel.offset_bottom - panel.offset_top
	)
