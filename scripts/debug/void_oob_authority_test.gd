extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const BROKEN_BRIDGE_MAP_ID := "broken_bridge_candidate"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []
var _death_cause: String = ""


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Void / OOB authority test ===")
	await _test_broken_bridge_deck_safety()
	await _test_broken_bridge_fall_death()
	await _test_city_highway_lateral_oob()
	await _test_map_void_zones_non_authoritative(BROKEN_BRIDGE_MAP_ID, true)

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _test_broken_bridge_deck_safety() -> void:
	print("-- Broken Bridge deck safety probe --")
	var ctx: Dictionary = await _boot_map(BROKEN_BRIDGE_MAP_ID, true)
	if ctx.is_empty():
		return

	var zombie_manager: ZombieManager = ctx.zombie_manager
	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	debug_join.request_random_join()
	await create_timer(0.2).timeout
	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("deck safety: never entered RUNNING")
		main_game.queue_free()
		return

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.is_empty():
		_fail("deck safety: no zombie spawned")
		main_game.queue_free()
		return

	var zombie: Zombie = zombies[0]
	if not zombie.died.is_connected(_on_probe_zombie_died):
		zombie.died.connect(_on_probe_zombie_died)

	var deck_probe := Vector3(0.0, BrokenBridgeTestLayout.ZOMBIE_SPAWN_Y, -10.0)
	zombie.global_position = deck_probe
	zombie.velocity = Vector3.ZERO

	_disable_combat(ctx.main_game)

	await create_timer(4.0).timeout

	if not zombie.is_alive():
		_fail("deck safety: zombie died on bridge deck (cause=%s)" % _death_cause)
	elif zombie.global_position.y < BrokenBridgeTestLayout.BRIDGE_DECK_Y - 1.0:
		_fail(
			"deck safety: zombie fell through deck (y=%.2f)"
			% zombie.global_position.y
		)
	else:
		print("deck safety probe passed")

	main_game.queue_free()


func _test_broken_bridge_fall_death() -> void:
	print("-- Broken Bridge fall death probe --")
	_death_cause = ""
	var ctx: Dictionary = await _boot_map(BROKEN_BRIDGE_MAP_ID, true)
	if ctx.is_empty():
		return

	var zombie_manager: ZombieManager = ctx.zombie_manager
	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	debug_join.request_random_join()
	await create_timer(0.2).timeout
	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("fall death: never entered RUNNING")
		main_game.queue_free()
		return

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.is_empty():
		_fail("fall death: no zombie spawned")
		main_game.queue_free()
		return

	var zombie: Zombie = zombies[0]
	if not zombie.died.is_connected(_on_probe_zombie_died):
		zombie.died.connect(_on_probe_zombie_died)

	var start_y: float = BrokenBridgeTestLayout.ZOMBIE_SPAWN_Y
	zombie.global_position = Vector3(7.5, start_y, 0.0)
	zombie.velocity = Vector3.ZERO

	var saw_fall: bool = false
	var elapsed: float = 0.0
	while elapsed < 12.0 and zombie.is_alive():
		if zombie.global_position.y < BrokenBridgeTestLayout.BRIDGE_DECK_Y - 0.5:
			saw_fall = true
		await create_timer(0.1).timeout
		elapsed += 0.1

	if zombie.is_alive():
		_fail("fall death: zombie did not die after leaving bridge deck")
		main_game.queue_free()
		return
	if not saw_fall:
		_fail("fall death: zombie died without visibly falling below deck")
		main_game.queue_free()
		return
	if _death_cause != "fell":
		_fail("fall death: expected cause 'fell', got '%s'" % _death_cause)
		main_game.queue_free()
		return

	print("fall death probe passed")
	main_game.queue_free()


func _test_city_highway_lateral_oob() -> void:
	print("-- City Highway lateral OOB regression --")
	_death_cause = ""
	var ctx: Dictionary = await _boot_map(CITY_HIGHWAY_MAP_ID, false)
	if ctx.is_empty():
		return

	var zombie_manager: ZombieManager = ctx.zombie_manager
	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	debug_join.request_random_join()
	await create_timer(0.2).timeout
	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("city highway OOB: never entered RUNNING")
		main_game.queue_free()
		return

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.is_empty():
		_fail("city highway OOB: no zombie spawned")
		main_game.queue_free()
		return

	var zombie: Zombie = zombies[0]
	if not zombie.died.is_connected(_on_probe_zombie_died):
		zombie.died.connect(_on_probe_zombie_died)

	var definition: RaceMapDefinition = ctx.map_controller.get_active_map_definition()
	var oob_x: float = definition.out_of_bounds_half_width + 2.0
	zombie.global_position = Vector3(oob_x, definition.spawn_origin.y, 0.0)
	zombie.velocity = Vector3.ZERO

	var elapsed: float = 0.0
	while elapsed < 6.0 and zombie.is_alive():
		await create_timer(0.1).timeout
		elapsed += 0.1

	if zombie.is_alive():
		_fail("city highway OOB: zombie survived beyond lateral bounds")
		main_game.queue_free()
		return
	if _death_cause != "out_of_bounds":
		_fail("city highway OOB: expected cause 'out_of_bounds', got '%s'" % _death_cause)
		main_game.queue_free()
		return

	print("city highway OOB regression passed")
	main_game.queue_free()


func _test_map_void_zones_non_authoritative(map_id: String, use_prototype_loader: bool) -> void:
	print("-- %s void zone non-authority check --" % map_id)
	var ctx: Dictionary = await _boot_map(map_id, use_prototype_loader)
	if ctx.is_empty():
		return

	var main_game: Node = ctx.main_game
	var map: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	if map == null:
		_fail("%s void check: RoadArena missing" % map_id)
		main_game.queue_free()
		return

	var active_void_killers: Array[Node] = _find_active_void_kill_zones(map)
	if not active_void_killers.is_empty():
		_fail(
			"%s void check: found %d active void kill zones"
			% [map_id, active_void_killers.size()]
		)
	else:
		print("%s void zone non-authority check passed" % map_id)

	main_game.queue_free()


func _find_active_void_kill_zones(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is Area3D:
		var area: Area3D = node as Area3D
		var is_void_zone: bool = (
			area.name == "HazardZone"
			or area.name == "BridgeVoidKill"
			or area.name == "GoalCatch"
		)
		if is_void_zone and (area.monitoring or area.monitorable):
			found.append(area)
		if area.get_script() != null and str(area.get_script().resource_path).ends_with("bridge_void_kill_zone.gd"):
			found.append(area)
	for child in node.get_children():
		found.append_array(_find_active_void_kill_zones(child))
	return found


func _on_probe_zombie_died(_zombie: Zombie, cause: String) -> void:
	_death_cause = cause


func _boot_map(map_id: String, use_prototype_loader: bool) -> Dictionary:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_fail("%s: main game boot failed" % map_id)
		return {}

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("%s: missing core systems" % map_id)
		main_game.queue_free()
		return {}

	if use_prototype_loader:
		if not map_controller.load_prototype_map_for_test(map_id):
			_fail("%s: prototype map load failed" % map_id)
			main_game.queue_free()
			return {}
	else:
		map_controller.set_active_map_by_id(map_id)
		if map_controller.active_map_id != map_id:
			_fail("%s: failed to activate map" % map_id)
			main_game.queue_free()
			return {}

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)
	_disable_combat(main_game)

	return {
		"main_game": main_game,
		"map_controller": map_controller,
		"round_manager": round_manager,
		"zombie_manager": zombie_manager,
		"debug_join": debug_join,
	}


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout
	return main_game


func _configure_test_round(
	round_manager: RoundManager,
	map_controller: RaceMapController,
	main_game: Node
) -> void:
	if round_manager.round_config != null:
		round_manager.round_config.countdown_seconds = 1
		round_manager.round_config.max_race_duration_seconds = 180.0
		round_manager.round_config.post_round_auto_reset_seconds = 0.0
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if zombie_manager != null:
		zombie_manager.set_spawn_rng_seed(7703)


func _ensure_race_systems_active(main_game: Node) -> void:
	var flow: GameFlowController = _node(main_game, "Systems/GameFlowController") as GameFlowController
	if flow != null:
		flow.show_race()
	await create_timer(0.35).timeout

	var world: Node3D = _node(main_game, "World") as Node3D
	if world != null:
		world.visible = true

	for manager_path in [
		"Systems/ZombieManager",
		"Systems/HazardManager",
		"Systems/PowerupManager",
		"Systems/HumanDefenderManager",
	]:
		var manager: Node = _node(main_game, manager_path)
		if manager != null:
			manager.visible = true


func _disable_combat(main_game: Node) -> void:
	var minigun: BaseMinigun = _node(main_game, "World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)


func _wait_for_round_state(round_manager: RoundManager, target_state: int, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if round_manager.state == target_state:
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return round_manager.state == target_state


func _node(root_node: Node, path: String) -> Node:
	return root_node.get_node_or_null(path)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	await create_timer(0.1).timeout
	quit(exit_code)
