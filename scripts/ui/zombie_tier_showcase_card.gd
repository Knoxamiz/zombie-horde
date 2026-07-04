class_name ZombieTierShowcaseCard
extends VBoxContainer

var _tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var _glow_materials: Array[ShaderMaterial] = []
var _glow_time: float = 0.0
var _bits_champion_light: OmniLight3D


func setup(tier: ParticipantJoinInfo.SupporterTier, title_text: String, perk_text: String, accent_color: Color) -> void:
	_tier = tier
	var viewport_size: Vector2 = ZombieTierPreviewFraming.get_viewport_size_vector()
	custom_minimum_size = viewport_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 8)
	_build_slot(title_text, perk_text, accent_color)


func _build_slot(title_text: String, perk_text: String, accent_color: Color) -> void:
	var viewport_size: Vector2i = ZombieTierPreviewFraming.get_viewport_size()

	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.custom_minimum_size = viewport_size
	viewport_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	viewport_container.stretch = true
	add_child(viewport_container)

	var viewport: SubViewport = SubViewport.new()
	viewport.size = viewport_size
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.42, 1.0)
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var zombie_visual: Node3D = ZombieTierVisuals.get_visual_scene_for_tier(_tier).instantiate() as Node3D
	zombie_visual.transform = ZombieTierPreviewFraming.get_model_transform()
	viewport.add_child(zombie_visual)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.transform = ZombieTierPreviewFraming.PREVIEW_LIGHT_TRANSFORM
	light.light_energy = 1.4
	viewport.add_child(light)

	var camera: Camera3D = Camera3D.new()
	camera.transform = ZombieTierPreviewFraming.build_camera_transform(_tier)
	camera.fov = ZombieTierPreviewFraming.CAMERA_FOV
	camera.current = true
	viewport.add_child(camera)

	call_deferred("_apply_preview_visuals", zombie_visual)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", accent_color.lightened(0.1))
	add_child(title_label)

	var perk_label: Label = Label.new()
	perk_label.text = perk_text
	perk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_label.add_theme_font_size_override("font_size", 12)
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
	SupporterUpgradeApplier.apply_upgrades(
		zombie_visual,
		join_info,
		ZombieTierPreviewFraming.get_showcase_icon_scale()
	)
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
