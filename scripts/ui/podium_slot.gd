class_name PodiumSlot
extends VBoxContainer

const PREVIEW_MODEL_TRANSFORM := Transform3D(
	Vector3(0.82, 0.0, 0.0),
	Vector3(0.0, 0.82, 0.0),
	Vector3(0.0, 0.0, 0.82),
	Vector3(0.0, -0.95, 0.0)
)
const PREVIEW_LIGHT_TRANSFORM := Transform3D(
	Vector3(0.866025, 0.0, -0.5),
	Vector3(-0.25, 0.866025, -0.433013),
	Vector3(0.433013, 0.5, 0.75),
	Vector3(0.0, 4.0, 4.0)
)
const PREVIEW_CAMERA_TRANSFORM := Transform3D(
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.0, 0.965926, -0.258819),
	Vector3(0.0, 0.258819, 0.965926),
	Vector3(0.0, 1.05, 4.5)
)
const PEDESTAL_HEIGHTS: Dictionary = {
	1: 118,
	2: 88,
	3: 68,
}

var _tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var _glow_materials: Array[ShaderMaterial] = []
var _glow_time: float = 0.0
var _bits_champion_light: OmniLight3D


func setup(entry: Dictionary) -> void:
	var position: int = int(entry.get("position", 0))
	var display_name: String = str(entry.get("display_name", "Zombie"))
	var progress: float = float(entry.get("progress", 0.0))
	var tier_value: Variant = entry.get("tier", ParticipantJoinInfo.SupporterTier.NONE)
	_tier = int(tier_value) as ParticipantJoinInfo.SupporterTier
	var tier_label: String = str(entry.get("tier_label", "Viewer"))
	var place_color: Color = PodiumResultsBuilder.get_place_color(position)
	var accent_color: Color = ZombieCharacterVisuals.get_label_color_for_tier(_tier)

	custom_minimum_size = Vector2(196, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END

	_build_header(position, place_color)
	_build_preview(accent_color)
	_build_pedestal(position, place_color)
	_build_footer(display_name, tier_label, progress, accent_color)


func _build_header(position: int, place_color: Color) -> void:
	var rank_label: Label = Label.new()
	rank_label.text = "#%d" % position
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 28 if position == 1 else 22)
	rank_label.add_theme_color_override("font_color", place_color)
	add_child(rank_label)


func _build_preview(accent_color: Color) -> void:
	var preview_box: PanelContainer = PanelContainer.new()
	preview_box.custom_minimum_size = Vector2(0, 132)
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.add_theme_stylebox_override("panel", _make_preview_frame(accent_color))
	add_child(preview_box)

	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.offset_left = 4.0
	viewport_container.offset_top = 4.0
	viewport_container.offset_right = -4.0
	viewport_container.offset_bottom = -4.0
	viewport_container.stretch = true
	preview_box.add_child(viewport_container)

	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(188, 124)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.012, 0.01, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.42, 1.0)
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var visual_scene: PackedScene = ZombieTierVisuals.get_visual_scene_for_tier(_tier)
	var zombie_visual: Node3D = visual_scene.instantiate() as Node3D
	zombie_visual.transform = PREVIEW_MODEL_TRANSFORM
	viewport.add_child(zombie_visual)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.transform = PREVIEW_LIGHT_TRANSFORM
	light.light_energy = 1.35
	viewport.add_child(light)

	var camera: Camera3D = Camera3D.new()
	camera.transform = PREVIEW_CAMERA_TRANSFORM
	camera.fov = 42.0
	camera.current = true
	viewport.add_child(camera)

	call_deferred("_apply_preview_visuals", zombie_visual)


func _build_pedestal(position: int, place_color: Color) -> void:
	var pedestal: PanelContainer = PanelContainer.new()
	pedestal.custom_minimum_size = Vector2(0, int(PEDESTAL_HEIGHTS.get(position, 72)))
	pedestal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pedestal.add_theme_stylebox_override("panel", _make_pedestal_style(place_color))
	add_child(pedestal)


func _build_footer(
	display_name: String,
	tier_label: String,
	progress: float,
	accent_color: Color
) -> void:
	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18 if display_name.length() <= 14 else 15)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.86, 1.0))
	add_child(name_label)

	var detail_label: Label = Label.new()
	detail_label.text = "%s  |  %d%%" % [tier_label, int(round(progress * 100.0))]
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", accent_color)
	add_child(detail_label)


func _apply_preview_visuals(zombie_visual: Node3D) -> void:
	if not is_instance_valid(zombie_visual):
		return

	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(_tier, 1)
	join_info.display_name = "PodiumPreview"
	ZombieCharacterVisuals.apply_color_tint_for_join_info(zombie_visual, join_info)
	if join_info.has_supporter_glow():
		_glow_materials = ZombieCharacterVisuals.apply_supporter_glow(zombie_visual, _tier)
		_bits_champion_light = ZombieCharacterVisuals.attach_bits_champion_glow(zombie_visual)
	SupporterUpgradeApplier.apply_upgrades(zombie_visual, join_info)
	_play_idle_animation(zombie_visual)


func _play_idle_animation(root: Node) -> void:
	var animation_player: AnimationPlayer = _find_animation_player(root)
	if animation_player == null or not animation_player.has_animation("Idle"):
		return

	var animation: Animation = animation_player.get_animation("Idle")
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play("Idle")


func _find_animation_player(root: Node) -> AnimationPlayer:
	var animation_player: AnimationPlayer = root as AnimationPlayer
	if animation_player != null:
		return animation_player

	for child in root.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null


func _process(delta: float) -> void:
	if _tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return

	_glow_time += delta
	ZombieCharacterVisuals.update_supporter_glow_pulse(_glow_materials, _glow_time, _tier)
	ZombieCharacterVisuals.update_bits_champion_glow(_bits_champion_light, _glow_time)


func _make_preview_frame(accent_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.012, 0.01, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color.lerp(Color(0.35, 0.35, 0.35, 1.0), 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	return style


func _make_pedestal_style(place_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = place_color.lerp(Color(0.08, 0.08, 0.08, 1.0), 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = place_color.lerp(Color.WHITE, 0.18)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = place_color.lerp(Color.BLACK, 0.2)
	style.shadow_size = 16
	return style
