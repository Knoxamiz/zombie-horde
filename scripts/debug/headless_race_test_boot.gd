class_name HeadlessRaceTestBoot
extends RefCounted

## Shared boot helpers for headless race integration tests.

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"


static func load_main_game_scene() -> PackedScene:
	return load(MAIN_GAME_SCENE) as PackedScene


static func get_race_systems(main_game: Node) -> Dictionary:
	if main_game == null:
		return {}
	return {
		"main_game": main_game,
		"map_controller": main_game.get_node_or_null("Systems/RaceMapController") as RaceMapController,
		"round_manager": main_game.get_node_or_null("Systems/RoundManager") as RoundManager,
		"zombie_manager": main_game.get_node_or_null("Systems/ZombieManager") as ZombieManager,
		"debug_join": main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource,
		"game_flow": main_game.get_node_or_null("Systems/GameFlowController") as GameFlowController,
	}


static func configure_standard_test_round(
	round_manager: RoundManager,
	map_controller: RaceMapController = null
) -> void:
	if round_manager == null:
		return
	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.max_race_duration_seconds = 90.0
		round_manager.round_config.post_round_auto_reset_seconds = 0.0
	if map_controller == null:
		return
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0


static func activate_race_phase(main_game: Node) -> void:
	if main_game == null:
		return
	var flow: GameFlowController = main_game.get_node_or_null(
		"Systems/GameFlowController"
	) as GameFlowController
	if flow != null:
		flow.show_race()
	var world: Node3D = main_game.get_node_or_null("World") as Node3D
	if world != null:
		world.visible = true
