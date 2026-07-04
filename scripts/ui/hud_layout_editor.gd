extends CanvasLayer

signal finished(save_changes: bool)

const HUD_LAYOUT_PROFILE := preload("res://scripts/ui/hud_layout_profile.gd")
const PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]

var _hud_controller: Node
var _toolbar: PanelContainer


func setup(hud_controller: Node) -> void:
	_hud_controller = hud_controller
	layer = 20
	_build_toolbar()
	visible = false


func begin() -> void:
	if _hud_controller == null:
		return
	visible = true
	await _hud_controller.get_tree().process_frame
	_activate_panels()


func end() -> void:
	_deactivate_panels()
	visible = false


func _activate_panels() -> void:
	for panel_id in PANEL_IDS:
		var panel: HudLayoutPanel = _get_layout_panel(panel_id)
		if panel == null or not panel.visible:
			continue
		if not panel.edit_hide_requested.is_connected(_on_panel_hide_requested):
			panel.edit_hide_requested.connect(_on_panel_hide_requested)
		panel.set_edit_active(true)


func _deactivate_panels() -> void:
	for panel_id in PANEL_IDS:
		var panel: HudLayoutPanel = _get_layout_panel(panel_id)
		if panel == null:
			continue
		if panel.edit_hide_requested.is_connected(_on_panel_hide_requested):
			panel.edit_hide_requested.disconnect(_on_panel_hide_requested)
		panel.set_edit_active(false)


func _get_layout_panel(panel_id: String) -> HudLayoutPanel:
	if _hud_controller == null:
		return null
	return _hud_controller.call("get_layout_panel", panel_id) as HudLayoutPanel


func _build_toolbar() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toolbar = PanelContainer.new()
	_toolbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toolbar.offset_left = -280.0
	_toolbar.offset_top = -54.0
	_toolbar.offset_right = 280.0
	_toolbar.offset_bottom = -14.0
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.016, 0.026, 0.018, 0.94)
	toolbar_style.corner_radius_top_left = 10
	toolbar_style.corner_radius_top_right = 10
	toolbar_style.corner_radius_bottom_left = 10
	toolbar_style.corner_radius_bottom_right = 10
	toolbar_style.border_color = Color(0.28, 0.95, 0.24, 0.55)
	toolbar_style.set_border_width_all(1)
	toolbar_style.content_margin_left = 14.0
	toolbar_style.content_margin_top = 8.0
	toolbar_style.content_margin_right = 14.0
	toolbar_style.content_margin_bottom = 8.0
	_toolbar.add_theme_stylebox_override("panel", toolbar_style)
	root.add_child(_toolbar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbar.add_child(row)

	var hint := Label.new()
	hint.text = "Drag header to move · corners to resize"
	hint.add_theme_color_override("font_color", Color(0.82, 1.0, 0.45, 0.9))
	hint.add_theme_font_size_override("font_size", 14)
	row.add_child(hint)

	row.add_child(_make_button("Reset", Color(1.0, 0.48, 0.08, 1.0), _on_reset_pressed))
	row.add_child(_make_button("Cancel", Color(0.74, 0.34, 1.0, 1.0), _on_cancel_pressed))
	row.add_child(_make_button("Save", Color(0.72, 0.95, 0.2, 1.0), _on_save_pressed))


func _make_button(label: String, accent: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 34)
	button.text = label
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.038, 0.032, 0.022, 0.94)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_right = 10.0
	normal.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.95, 0.91, 0.76, 1.0))
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	return button


func _on_panel_hide_requested(panel_id: String) -> void:
	var panel: HudLayoutPanel = _get_layout_panel(panel_id)
	if panel == null:
		return
	panel.visible = false
	panel.set_edit_active(false)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finished.emit(false)
		get_viewport().set_input_as_handled()


func _on_reset_pressed() -> void:
	if _hud_controller != null:
		HUD_LAYOUT_PROFILE.clear_saved_layout()
		_hud_controller.reset_layout_to_defaults()
		if _hud_controller.has_method("_ensure_layout_panels_visible_for_edit"):
			_hud_controller.call("_ensure_layout_panels_visible_for_edit")
	_deactivate_panels()
	_activate_panels()


func _on_cancel_pressed() -> void:
	finished.emit(false)


func _on_save_pressed() -> void:
	finished.emit(true)
