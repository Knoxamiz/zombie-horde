class_name ZombieTierShowcaseCard
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

var _tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var _glow_materials: Array[ShaderMaterial] = []
var _glow_time: float = 0.0
var _bits_champion_light: OmniLight3D


func setup(tier: ParticipantJoinInfo.SupporterTier, title_text: String, perk_text: String, accent_color: Color) -> void:
	_tier = tier
	custom_minimum_size = Vector2(132, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_build_slot(title_text, perk_text, accent_color)


func _build_slot(title_text: String, perk_text: String, accent_color: Color) -> void:
	var preview_box: PanelContainer = PanelContainer.new()
	preview_box.custom_minimum_size = Vector2(0, 108)
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
	viewport.size = Vector2i(124, 100)
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

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", accent_color.lightened(0.1))
	add_child(title_label)

	var perk_label: Label = Label.new()
	perk_label.text = perk_text
	perk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_label.add_theme_font_size_override("font_size", 11)
	perk_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.74, 1.0))
	add_child(perk_label)


func _apply_preview_visuals(zombie_visual: Node3D) -> void:
	if not is_instance_valid(zombie_visual):
		return

	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(_tier, 1)
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
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style
