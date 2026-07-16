class_name StreamerSettingsProfile
extends Resource

const SAVE_PATH := "user://streamer_settings.cfg"
const SECTION := "streamer_settings"
const PRESET_SECTION_PREFIX := "streamer_preset_"
const PRESET_COUNT := 4
const SAVE_VERSION := 5

enum TimeOfDay {
	NIGHT,
	DAY
}

enum MenuTier {
	BASIC,
	PAID_PREMIUM
}

@export_enum("Basic", "Paid Premium") var menu_tier: int = MenuTier.PAID_PREMIUM
@export_range(0, 100, 1) var audience_balance: int = 50
@export_enum("Night", "Day") var time_of_day: int = TimeOfDay.NIGHT
@export_enum("City", "Industrial Yard", "Skyline") var backdrop_style: int = 0
@export_enum("Matt", "Lis", "Sam", "Shaun") var streamer_avatar: int = 0
@export var streamer_name: String = "Streamer"
@export_enum("Random", "Pistol", "SMG", "Rifle", "Shotgun") var tower_gun: int = 0
@export var show_tower_weapons: bool = true
@export_range(0, 32, 1) var selected_map_index: int = 0
@export var selected_map_id: String = ""
@export_range(0, 96, 1) var premium_mine_count: int = 6
@export_range(0, 96, 1) var premium_obstacle_count: int = 12
@export_range(0, 32, 1) var premium_boost_pad_count: int = 3
@export_range(0, 32, 1) var premium_sewer_hole_count: int = 2
@export_range(0, 12, 1) var premium_defender_count: int = 2
@export_range(0, 100, 1) var premium_vehicle_weight: int = 18
@export_range(0, 100, 1) var premium_cone_weight: int = 40
@export_range(0, 100, 1) var premium_barrier_weight: int = 42

static func load_from_disk() -> StreamerSettingsProfile:
	var profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	var config_file: ConfigFile = ConfigFile.new()
	var error: Error = config_file.load(SAVE_PATH)
	if error != OK:
		return profile

	var saved_version: int = int(config_file.get_value(SECTION, "version", 0))
	_read_section_values(profile, config_file, SECTION, saved_version)
	profile.sanitize_map_selection()
	return profile

func save_to_disk() -> Error:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.load(SAVE_PATH)
	_write_section_values(config_file, SECTION)
	return config_file.save(SAVE_PATH)

static func create_default_profile() -> StreamerSettingsProfile:
	return StreamerSettingsProfile.new()

static func create_factory_preset(slot_index: int) -> StreamerSettingsProfile:
	var preset: StreamerSettingsProfile = StreamerSettingsProfile.new()
	match int(clamp(slot_index, 0, PRESET_COUNT - 1)):
		0:
			preset.audience_balance = 50
			preset.premium_mine_count = 6
			preset.premium_obstacle_count = 12
			preset.premium_boost_pad_count = 3
			preset.premium_sewer_hole_count = 2
			preset.premium_defender_count = 2
			preset.selected_map_index = 0
			preset.tower_gun = HumanDefenderConfig.GunType.RANDOM
		1:
			preset.audience_balance = 18
			preset.premium_mine_count = 8
			preset.premium_obstacle_count = 16
			preset.premium_boost_pad_count = 2
			preset.premium_sewer_hole_count = 3
			preset.premium_defender_count = 4
			preset.selected_map_index = 0
			preset.tower_gun = HumanDefenderConfig.GunType.RIFLE
		2:
			preset.audience_balance = 84
			preset.premium_mine_count = 4
			preset.premium_obstacle_count = 8
			preset.premium_boost_pad_count = 6
			preset.premium_sewer_hole_count = 1
			preset.premium_defender_count = 1
			preset.selected_map_index = 0
			preset.tower_gun = HumanDefenderConfig.GunType.RANDOM
		3:
			preset.audience_balance = 64
			preset.premium_mine_count = 10
			preset.premium_obstacle_count = 18
			preset.premium_boost_pad_count = 5
			preset.premium_sewer_hole_count = 3
			preset.premium_defender_count = 3
			preset.premium_vehicle_weight = 24
			preset.premium_cone_weight = 34
			preset.premium_barrier_weight = 42
			preset.selected_map_index = 0
			preset.tower_gun = HumanDefenderConfig.GunType.SMG
	return preset

static func load_preset_from_disk(slot_index: int) -> StreamerSettingsProfile:
	var preset: StreamerSettingsProfile = create_factory_preset(slot_index)
	var config_file: ConfigFile = ConfigFile.new()
	var error: Error = config_file.load(SAVE_PATH)
	if error != OK:
		return preset

	var section: String = _get_preset_section(slot_index)
	if not config_file.has_section(section):
		return preset

	var saved_version: int = int(config_file.get_value(section, "version", SAVE_VERSION))
	_read_section_values(preset, config_file, section, saved_version)
	return preset

func save_preset_to_disk(slot_index: int) -> Error:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.load(SAVE_PATH)
	_write_section_values(config_file, _get_preset_section(slot_index))
	return config_file.save(SAVE_PATH)

func apply_preset_values(source: StreamerSettingsProfile) -> void:
	if source == null:
		return

	var current_name: String = get_clean_streamer_name()
	var current_avatar: int = streamer_avatar
	copy_values_from(source)
	streamer_name = current_name
	streamer_avatar = current_avatar

func copy_values_from(source: StreamerSettingsProfile) -> void:
	if source == null:
		return

	menu_tier = source.menu_tier
	audience_balance = source.audience_balance
	time_of_day = source.time_of_day
	backdrop_style = source.backdrop_style
	streamer_avatar = source.streamer_avatar
	streamer_name = source.get_clean_streamer_name()
	tower_gun = source.tower_gun
	show_tower_weapons = source.show_tower_weapons
	selected_map_index = source.selected_map_index
	selected_map_id = source.selected_map_id
	premium_mine_count = source.premium_mine_count
	premium_obstacle_count = source.premium_obstacle_count
	premium_boost_pad_count = source.premium_boost_pad_count
	premium_sewer_hole_count = source.premium_sewer_hole_count
	premium_defender_count = source.premium_defender_count
	premium_vehicle_weight = source.premium_vehicle_weight
	premium_cone_weight = source.premium_cone_weight
	premium_barrier_weight = source.premium_barrier_weight

func apply_to_configs(
	hazard_config: HazardConfig,
	zombie_config: ZombieConfig,
	minigun_config: MinigunConfig,
	powerup_config: PowerupConfig,
	human_defender_config: HumanDefenderConfig,
	visual_config: StreamerVisualConfig,
	feature_config: FeatureAccessConfig = null
) -> void:
	var chat_bias: float = get_chat_bias()
	var premium_enabled: bool = is_paid_premium(feature_config)

	if hazard_config != null:
		if premium_enabled:
			hazard_config.mine_count = premium_mine_count
			hazard_config.obstacle_count = premium_obstacle_count
			hazard_config.sewer_hole_count = premium_sewer_hole_count
			hazard_config.vehicle_obstacle_weight = premium_vehicle_weight
			hazard_config.cone_obstacle_weight = premium_cone_weight
			hazard_config.barrier_obstacle_weight = premium_barrier_weight
		else:
			hazard_config.mine_count = _mix_int(4, 1, chat_bias)
			hazard_config.obstacle_count = _mix_int(7, 4, chat_bias)
			hazard_config.sewer_hole_count = _mix_int(1, 0, chat_bias)
			hazard_config.vehicle_obstacle_weight = 16
			hazard_config.cone_obstacle_weight = 46
			hazard_config.barrier_obstacle_weight = 38
		hazard_config.crawler_chance = _mix_float(0.22, 0.48, chat_bias)
		hazard_config.damage_chance = _mix_float(0.7, 0.36, chat_bias)

	if zombie_config != null:
		zombie_config.runner_speed = _mix_float(3.45, 4.65, chat_bias)
		zombie_config.drift_strength = _mix_float(0.48, 0.68, chat_bias)
		zombie_config.lethal_dismember_chance = _mix_float(0.52, 0.28, chat_bias)

	if minigun_config != null:
		minigun_config.hit_chance = _mix_float(0.84, 0.56, chat_bias)
		minigun_config.seconds_between_bursts = _mix_float(1.15, 2.05, chat_bias)
		minigun_config.damage_per_hit = _mix_float(38.0, 27.0, chat_bias)

	if powerup_config != null:
		powerup_config.boost_pad_count = premium_boost_pad_count if premium_enabled else _mix_int(1, 2, chat_bias)
		powerup_config.boost_multiplier = _mix_float(1.55, 2.05, chat_bias)
		powerup_config.boost_duration = _mix_float(1.8, 2.65, chat_bias)

	if human_defender_config != null:
		human_defender_config.defender_count = premium_defender_count if premium_enabled else _mix_int(1, 0, chat_bias)
		human_defender_config.gun_type = tower_gun if premium_enabled else HumanDefenderConfig.GunType.RANDOM
		human_defender_config.show_weapon_visuals = true if not premium_enabled else show_tower_weapons
		human_defender_config.damage_per_hit = _mix_float(31.0, 21.0, chat_bias)
		human_defender_config.hit_chance = _mix_float(0.84, 0.62, chat_bias)
		human_defender_config.seconds_between_shots = _mix_float(0.88, 1.35, chat_bias)

	if visual_config != null:
		visual_config.time_of_day = time_of_day
		visual_config.backdrop_style = backdrop_style
		visual_config.streamer_avatar = streamer_avatar
		visual_config.streamer_name = get_clean_streamer_name()

func get_chat_bias() -> float:
	return clamp(float(audience_balance) / 100.0, 0.0, 1.0)

func is_paid_premium(feature_config: FeatureAccessConfig = null) -> bool:
	if feature_config == null:
		return false
	return feature_config.has_premium_access()

func get_menu_tier_name(feature_config: FeatureAccessConfig = null) -> String:
	if feature_config != null:
		return feature_config.get_edition_name()
	return "Basic"

func get_menu_tier_detail(feature_config: FeatureAccessConfig = null) -> String:
	if feature_config != null:
		return feature_config.get_edition_detail()
	return "Basic locks settings and runs one fixed map"

func get_balance_name() -> String:
	if audience_balance <= 25:
		return "Streamer Friendly"
	if audience_balance >= 75:
		return "Chat Friendly"
	return "Balanced Lotto"

func get_balance_detail() -> String:
	if audience_balance <= 25:
		return "Sharper defenses, slower horde, fewer boosts"
	if audience_balance >= 75:
		return "Faster horde, more boosts, softer defenses"
	return "Fair race pressure on both sides"

func get_time_of_day_name() -> String:
	return "Day" if time_of_day == TimeOfDay.DAY else "Night"

func get_selected_settings_map_index() -> int:
	return MapCatalog.resolve_settings_index(selected_map_id, selected_map_index)


func get_selected_map_id() -> String:
	return MapCatalog.get_settings_map_id(get_selected_settings_map_index())


func set_selected_settings_map_index(settings_index: int) -> void:
	_sync_map_selection_fields(
		int(clamp(settings_index, 0, maxi(MapCatalog.get_settings_map_count() - 1, 0)))
	)


func set_selected_map_id(map_id: String) -> void:
	_sync_map_selection_fields(MapCatalog.resolve_settings_index(map_id, -1))


func sanitize_map_selection() -> void:
	var resolved_settings_index: int = get_selected_settings_map_index()
	var resolved_map_id: String = MapCatalog.get_settings_map_id(resolved_settings_index)
	if (
		selected_map_index != resolved_settings_index
		or selected_map_id != resolved_map_id
	):
		if resolved_settings_index == 0 and selected_map_index > 1:
			push_warning(
				"StreamerSettingsProfile: migrated invalid map selection (id=%s index=%d) to City Highway."
				% [selected_map_id, selected_map_index]
			)
	_sync_map_selection_fields(resolved_settings_index)


func _sync_map_selection_fields(settings_index: int) -> void:
	var clamped_index: int = int(
		clamp(settings_index, 0, maxi(MapCatalog.get_settings_map_count() - 1, 0))
	)
	selected_map_index = clamped_index
	selected_map_id = MapCatalog.get_settings_map_id(clamped_index)

func get_avatar_name() -> String:
	match streamer_avatar:
		0:
			return "Matt"
		1:
			return "Lis"
		2:
			return "Sam"
		3:
			return "Shaun"
	return "Matt"

func get_clean_streamer_name() -> String:
	var clean_name: String = streamer_name.strip_edges()
	if clean_name.is_empty():
		return "Streamer"
	return clean_name

func _mix_float(from_value: float, to_value: float, weight: float) -> float:
	return from_value + ((to_value - from_value) * weight)

func _mix_int(from_value: int, to_value: int, weight: float) -> int:
	return int(round(_mix_float(float(from_value), float(to_value), weight)))

static func _get_preset_section(slot_index: int) -> String:
	return "%s%d" % [PRESET_SECTION_PREFIX, int(clamp(slot_index, 0, PRESET_COUNT - 1))]

static func _read_section_values(
	profile: StreamerSettingsProfile,
	config_file: ConfigFile,
	section: String,
	saved_version: int
) -> void:
	profile.menu_tier = int(clamp(int(config_file.get_value(section, "menu_tier", profile.menu_tier)), 0, 1))
	profile.audience_balance = int(clamp(int(config_file.get_value(section, "audience_balance", profile.audience_balance)), 0, 100))
	profile.time_of_day = int(clamp(int(config_file.get_value(section, "time_of_day", profile.time_of_day)), 0, 1))
	profile.backdrop_style = int(clamp(int(config_file.get_value(section, "backdrop_style", profile.backdrop_style)), 0, 2))
	profile.streamer_avatar = int(clamp(int(config_file.get_value(section, "streamer_avatar", profile.streamer_avatar)), 0, 3))
	profile.streamer_name = str(config_file.get_value(section, "streamer_name", profile.streamer_name)).strip_edges()
	if profile.streamer_name.is_empty():
		profile.streamer_name = "Streamer"
	profile.tower_gun = int(clamp(int(config_file.get_value(section, "tower_gun", profile.tower_gun)), 0, 4))
	profile.show_tower_weapons = true if saved_version < 2 else bool(config_file.get_value(section, "show_tower_weapons", profile.show_tower_weapons))
	profile.selected_map_index = int(
		config_file.get_value(section, "selected_map_index", profile.selected_map_index)
	)
	if saved_version >= 4:
		profile.selected_map_id = str(
			config_file.get_value(section, "selected_map_id", profile.selected_map_id)
		).strip_edges()
	profile.sanitize_map_selection()
	profile.premium_mine_count = int(clamp(int(config_file.get_value(section, "premium_mine_count", profile.premium_mine_count)), 0, 96))
	profile.premium_obstacle_count = int(clamp(int(config_file.get_value(section, "premium_obstacle_count", profile.premium_obstacle_count)), 0, 96))
	profile.premium_boost_pad_count = int(clamp(int(config_file.get_value(section, "premium_boost_pad_count", profile.premium_boost_pad_count)), 0, 32))
	profile.premium_sewer_hole_count = int(clamp(int(config_file.get_value(section, "premium_sewer_hole_count", profile.premium_sewer_hole_count)), 0, 32))
	profile.premium_defender_count = int(clamp(int(config_file.get_value(section, "premium_defender_count", profile.premium_defender_count)), 0, 12))
	profile.premium_vehicle_weight = int(clamp(int(config_file.get_value(section, "premium_vehicle_weight", profile.premium_vehicle_weight)), 0, 100))
	profile.premium_cone_weight = int(clamp(int(config_file.get_value(section, "premium_cone_weight", profile.premium_cone_weight)), 0, 100))
	profile.premium_barrier_weight = int(clamp(int(config_file.get_value(section, "premium_barrier_weight", profile.premium_barrier_weight)), 0, 100))

func _write_section_values(config_file: ConfigFile, section: String) -> void:
	config_file.set_value(section, "version", SAVE_VERSION)
	config_file.set_value(section, "menu_tier", menu_tier)
	config_file.set_value(section, "audience_balance", audience_balance)
	config_file.set_value(section, "time_of_day", time_of_day)
	config_file.set_value(section, "backdrop_style", backdrop_style)
	config_file.set_value(section, "streamer_avatar", streamer_avatar)
	config_file.set_value(section, "streamer_name", get_clean_streamer_name())
	config_file.set_value(section, "tower_gun", tower_gun)
	config_file.set_value(section, "show_tower_weapons", show_tower_weapons)
	config_file.set_value(section, "selected_map_index", selected_map_index)
	config_file.set_value(section, "selected_map_id", get_selected_map_id())
	config_file.set_value(section, "premium_mine_count", premium_mine_count)
	config_file.set_value(section, "premium_obstacle_count", premium_obstacle_count)
	config_file.set_value(section, "premium_boost_pad_count", premium_boost_pad_count)
	config_file.set_value(section, "premium_sewer_hole_count", premium_sewer_hole_count)
	config_file.set_value(section, "premium_defender_count", premium_defender_count)
	config_file.set_value(section, "premium_vehicle_weight", premium_vehicle_weight)
	config_file.set_value(section, "premium_cone_weight", premium_cone_weight)
	config_file.set_value(section, "premium_barrier_weight", premium_barrier_weight)
