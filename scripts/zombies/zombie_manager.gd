class_name ZombieManager
extends Node3D

@export var zombie_scene: PackedScene
@export var zombie_config: ZombieConfig
@export var spawn_origin: Vector3 = Vector3(0.0, 0.8, -42.0)
@export var spawn_area_size: Vector2 = Vector2(10.0, 4.0)
@export var goal_position: Vector3 = Vector3(0.0, 0.8, 42.0)
@export var leader_update_interval: float = 0.2

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _all_zombies: Array[Zombie] = []
var _living_zombies: Array[Zombie] = []
var _round_active: bool = false
var _leader_timer: float = 0.0
var _last_leader_name: String = ""

func _ready() -> void:
	_rng.randomize()
	_publish_counts()

func _process(delta: float) -> void:
	_leader_timer -= delta
	if _leader_timer <= 0.0:
		_leader_timer = leader_update_interval
		_publish_leader()

func spawn_participants(display_names: Array[String]) -> void:
	for display_name in display_names:
		spawn_zombie(display_name)

func spawn_participants_with_info(display_names: Array[String], join_info_lookup: Dictionary) -> void:
	for display_name in display_names:
		var lookup_key: String = str(display_name).to_lower()
		var join_info: ParticipantJoinInfo = join_info_lookup.get(lookup_key) as ParticipantJoinInfo
		if join_info == null:
			join_info = ParticipantJoinInfo.for_name(str(display_name))
		spawn_zombie(str(display_name), join_info)

func spawn_zombie(display_name: String, join_info: ParticipantJoinInfo = null) -> Zombie:
	if zombie_scene == null:
		return null

	var zombie: Zombie = zombie_scene.instantiate() as Zombie
	if zombie == null:
		return null

	var spawn_position: Vector3 = _get_spawn_position()
	add_child(zombie)
	zombie.name = "Zombie_%03d" % (_all_zombies.size() + 1)
	zombie.global_position = spawn_position
	var payload: ParticipantJoinInfo = join_info
	if payload == null:
		payload = ParticipantJoinInfo.for_name(display_name)
	zombie.configure_zombie(display_name, zombie_config, goal_position, spawn_position, int(_rng.randi()), payload)
	zombie.set_round_active(_round_active)
	zombie.died.connect(_on_zombie_died)

	_all_zombies.append(zombie)
	_living_zombies.append(zombie)
	GameEvents.zombie_spawned.emit(zombie)
	_publish_counts()
	_publish_leader()
	return zombie

func clear_all_zombies() -> void:
	for zombie in _all_zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()

	_all_zombies.clear()
	_living_zombies.clear()
	_last_leader_name = ""
	_publish_counts()
	GameEvents.leader_changed.emit("", 0.0)

func set_round_active(active: bool) -> void:
	_round_active = active
	for zombie in _living_zombies:
		if is_instance_valid(zombie):
			zombie.set_round_active(active)

func get_living_count() -> int:
	_remove_invalid_living()
	return _living_zombies.size()

func get_total_count() -> int:
	_remove_invalid_all()
	return _all_zombies.size()

func get_living_zombies() -> Array[Zombie]:
	_remove_invalid_living()
	var result: Array[Zombie] = []
	for zombie in _living_zombies:
		result.append(zombie)
	return result

func get_living_zombies_in_range(origin: Vector3, radius: float) -> Array[Zombie]:
	_remove_invalid_living()
	var result: Array[Zombie] = []
	var radius_squared: float = radius * radius
	for zombie in _living_zombies:
		if zombie.global_position.distance_squared_to(origin) <= radius_squared:
			result.append(zombie)
	return result

func get_leader_zombie() -> Zombie:
	_remove_invalid_living()
	if _living_zombies.is_empty():
		return null

	var leader: Zombie = _living_zombies[0]
	var leader_progress: float = leader.get_progress()
	for zombie in _living_zombies:
		var progress: float = zombie.get_progress()
		if progress > leader_progress:
			leader = zombie
			leader_progress = progress
	return leader

func get_ranked_results(max_results: int, excluded_display_name: String = "") -> Array[Dictionary]:
	_remove_invalid_all()
	var excluded_lower_name: String = excluded_display_name.to_lower()
	var results: Array[Dictionary] = []
	for zombie in _all_zombies:
		if not is_instance_valid(zombie):
			continue
		if not excluded_lower_name.is_empty() and zombie.display_name.to_lower() == excluded_lower_name:
			continue

		results.append(_build_result_entry(zombie))

	results.sort_custom(_sort_result_by_progress)
	while results.size() > max_results:
		results.remove_at(results.size() - 1)
	return results

func has_display_name(display_name: String) -> bool:
	var lower_name: String = display_name.to_lower()
	_remove_invalid_all()
	for zombie in _all_zombies:
		if zombie.display_name.to_lower() == lower_name:
			return true
	return false

func _get_spawn_position() -> Vector3:
	var half_width: float = spawn_area_size.x * 0.5
	var half_depth: float = spawn_area_size.y * 0.5
	return spawn_origin + Vector3(
		_rng.randf_range(-half_width, half_width),
		0.0,
		_rng.randf_range(-half_depth, half_depth)
	)

func _on_zombie_died(zombie: Zombie, cause: String) -> void:
	_living_zombies.erase(zombie)
	_publish_counts()
	_publish_leader()
	GameEvents.zombie_died.emit(zombie, cause)

func _publish_counts() -> void:
	GameEvents.zombie_count_changed.emit(get_living_count(), get_total_count())

func _publish_leader() -> void:
	_remove_invalid_living()
	if _living_zombies.is_empty():
		if not _last_leader_name.is_empty():
			_last_leader_name = ""
			GameEvents.leader_changed.emit("", 0.0)
		return

	var leader: Zombie = get_leader_zombie()
	if leader == null:
		return
	var leader_progress: float = leader.get_progress()

	_last_leader_name = leader.display_name
	GameEvents.leader_changed.emit(leader.display_name, leader_progress)

func _remove_invalid_living() -> void:
	for index in range(_living_zombies.size() - 1, -1, -1):
		if not is_instance_valid(_living_zombies[index]):
			_living_zombies.remove_at(index)

func _remove_invalid_all() -> void:
	for index in range(_all_zombies.size() - 1, -1, -1):
		if not is_instance_valid(_all_zombies[index]):
			_all_zombies.remove_at(index)

func get_result_for_display_name(display_name: String) -> Dictionary:
	_remove_invalid_all()
	var lower_name: String = display_name.to_lower()
	for zombie in _all_zombies:
		if zombie.display_name.to_lower() == lower_name:
			return _build_result_entry(zombie)
	return {
		"display_name": display_name,
		"progress": 1.0,
		"alive": true,
		"tier": ParticipantJoinInfo.SupporterTier.NONE,
		"tier_label": "Viewer",
	}


func _build_result_entry(zombie: Zombie) -> Dictionary:
	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	var tier_label: String = "Viewer"
	var join_info: ParticipantJoinInfo = zombie.get_join_info()
	if join_info != null:
		tier = join_info.get_supporter_tier()
		tier_label = join_info.get_tier_label()

	return {
		"display_name": zombie.display_name,
		"progress": zombie.get_progress(),
		"alive": zombie.is_alive(),
		"tier": tier,
		"tier_label": tier_label,
	}


func _sort_result_by_progress(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("progress", 0.0)) > float(b.get("progress", 0.0))
