class_name StreamerSettingsApplier
extends Node

@export var hazard_config: HazardConfig
@export var zombie_config: ZombieConfig
@export var minigun_config: MinigunConfig
@export var powerup_config: PowerupConfig
@export var human_defender_config: HumanDefenderConfig
@export var visual_config: StreamerVisualConfig
@export var feature_config: FeatureAccessConfig
@export var race_map_controller_path: NodePath

var active_profile: StreamerSettingsProfile
var _applied: bool = false
var _race_map_controller: RaceMapController

func _ready() -> void:
	# Map loading needs the complete main-game tree, including World and its anchors.
	# This is the single initial profile application; RaceMapController is a loader.
	call_deferred("_apply_saved_profile_once")

func reload_and_apply() -> void:
	_race_map_controller = get_node_or_null(race_map_controller_path) as RaceMapController
	active_profile = StreamerSettingsProfile.load_from_disk()
	active_profile.apply_to_configs(
		hazard_config,
		zombie_config,
		minigun_config,
		powerup_config,
		human_defender_config,
		visual_config,
		feature_config
	)
	if _race_map_controller != null:
		_race_map_controller.apply_profile(active_profile)
	_applied = true

func _apply_saved_profile_once() -> void:
	if _applied:
		return
	reload_and_apply()
