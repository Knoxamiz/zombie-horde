class_name ZombieTierShowcaseCard
extends PanelContainer

const ZOMBIE_VISUAL_SCENE: PackedScene = preload("res://scenes/zombies/visuals/zombie_basic_visual.tscn")
const PREVIEW_SPIN_SPEED: float = 0.85

var _tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var _preview_pivot: Node3D
var _glow_materials: Array[ShaderMaterial] = []
var _glow_time: float = 0.0
var _bits_champion_light: OmniLight3D


func setup(tier: ParticipantJoinInfo.SupporterTier, title_text: String, perk_text: String, accent_color: Color) -> void:
	_tier = tier
	custom_minimum_size = Vector2(148, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _make_panel_style(accent_color))
	_build_card_contents(title_text, perk_text, accent_color)


func _build_card_contents(title_text: String, perk_text: String, accent_color: Color) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(0, 118)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	column.add_child(viewport_container)

	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(132, 118)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var world: Node3D = Node3D.new()
	viewport.add_child(world)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.05, 1.05, 2.35)
	camera.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
	world.add_child(camera)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	key_light.light_energy = 1.15
	world.add_child(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.position = Vector3(-0.8, 1.2, 1.0)
	fill_light.light_energy = 0.55
	world.add_child(fill_light)

	_preview_pivot = Node3D.new()
	_preview_pivot.position = Vector3(0.0, -0.72, 0.0)
	_preview_pivot.scale = Vector3(0.92, 0.92, 0.92)
	world.add_child(_preview_pivot)

	var zombie_visual: Node3D = ZOMBIE_VISUAL_SCENE.instantiate() as Node3D
	_preview_pivot.add_child(zombie_visual)

	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(_tier, 1)
	ZombieCharacterVisuals.apply_color_tint_for_join_info(zombie_visual, join_info)
	if join_info.has_supporter_glow():
		_glow_materials = ZombieCharacterVisuals.apply_supporter_glow(zombie_visual, _tier)
		_bits_champion_light = ZombieCharacterVisuals.attach_bits_champion_glow(_preview_pivot)
	SupporterUpgradeApplier.apply_upgrades(zombie_visual, join_info)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", accent_color.lightened(0.12))
	column.add_child(title_label)

	var perk_label: Label = Label.new()
	perk_label.text = perk_text
	perk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_label.add_theme_font_size_override("font_size", 12)
	perk_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.78, 1.0))
	column.add_child(perk_label)


func _process(delta: float) -> void:
	if _preview_pivot != null:
		_preview_pivot.rotate_y(PREVIEW_SPIN_SPEED * delta)

	if _tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return

	_glow_time += delta
	ZombieCharacterVisuals.update_supporter_glow_pulse(_glow_materials, _glow_time, _tier)
	ZombieCharacterVisuals.update_bits_champion_glow(_bits_champion_light, _glow_time)


func _make_panel_style(accent_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.02, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color.lerp(Color.WHITE, 0.18)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = accent_color * Color(1.0, 1.0, 1.0, 0.35)
	style.shadow_size = 10
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style
