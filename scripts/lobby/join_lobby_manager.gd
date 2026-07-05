class_name JoinLobbyManager
extends Node3D

const BITS_CAGE_MINE_MESSAGE := "1 bit = Cage mine!!!"

@export var lobby_zombie_scene: PackedScene
@export var lobby_cage_mine_scene: PackedScene
@export var round_manager_path: NodePath
@export var spawn_area_size: Vector3 = Vector3(5.4, 0.0, 4.0)
@export var drop_height: float = 7.6
@export var cage_mine_floor_y: float = 0.24
@export var cage_mine_spawn_half_extents: Vector2 = Vector2(2.8, 1.8)
@export var cage_half_extents_xz: Vector2 = Vector2(5.7, 3.7)
@export var cage_floor_y: float = -0.75
@export var cage_ground_contact_max_y: float = 1.35
@export_range(1, 160, 1) var max_displayed_zombies: int = 96

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lobby_zombies: Dictionary = {}
var _round_manager: RoundManager
var _lobby_open: bool = true
var _cage_mine: LobbyCageMine

@onready var _zombie_container: Node3D = get_node_or_null("Zombies") as Node3D

func _ready() -> void:
	_rng.randomize()
	_round_manager = get_node_or_null(round_manager_path) as RoundManager

	GameEvents.participant_queue_changed.connect(_on_participant_queue_changed)
	GameEvents.round_state_changed.connect(_on_round_state_changed)
	GameEvents.round_reset.connect(_on_round_reset)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.bits_cheer_received.connect(_on_bits_cheer_received)

	if _zombie_container == null:
		_zombie_container = self
	if _round_manager != null:
		_lobby_open = _round_manager.get_state_text() == "Joining"
		_sync_queue(_round_manager.get_pending_names())

func _on_participant_queue_changed(display_names: PackedStringArray) -> void:
	if not _lobby_open:
		return

	_sync_queue(display_names)

func _on_round_state_changed(state_text: String) -> void:
	_lobby_open = state_text == "Joining"
	if not _lobby_open:
		_clear_lobby()
	elif _round_manager != null:
		_sync_queue(_round_manager.get_pending_names())

func _on_round_reset() -> void:
	_clear_lobby()

func _on_round_started(_round_number: int) -> void:
	_clear_lobby()

func _sync_queue(display_names: PackedStringArray) -> void:
	var desired_keys: Dictionary = {}
	for display_name in display_names:
		var clean_name: String = str(display_name).strip_edges()
		if clean_name.is_empty():
			continue

		var key: String = _get_lobby_key(clean_name)
		desired_keys[key] = true
		if not _lobby_zombies.has(key):
			_spawn_lobby_zombie(clean_name, key)

	var existing_keys: Array = _lobby_zombies.keys()
	for existing_key in existing_keys:
		if not desired_keys.has(existing_key):
			_remove_lobby_zombie(str(existing_key))

func _spawn_lobby_zombie(display_name: String, key: String) -> void:
	if lobby_zombie_scene == null or _lobby_zombies.size() >= max_displayed_zombies:
		return

	var lobby_zombie: LobbyZombie = lobby_zombie_scene.instantiate() as LobbyZombie
	if lobby_zombie == null:
		return

	_zombie_container.add_child(lobby_zombie)
	lobby_zombie.name = "LobbyZombie_%s" % _get_node_safe_name(display_name)
	lobby_zombie.position = _get_spawn_position()
	var join_info: ParticipantJoinInfo = _get_join_info(display_name)
	lobby_zombie.configure_lobby_zombie(display_name, int(_rng.randi()), join_info)
	_lobby_zombies[key] = lobby_zombie

func _on_bits_cheer_received(_display_name: String, bits_amount: int) -> void:
	if not _lobby_open or bits_amount <= 0:
		return

	var mine: LobbyCageMine = spawn_cage_mine(true)
	if mine == null:
		return

	GameEvents.world_feedback_requested.emit(
		mine.global_position + Vector3.UP * 0.9,
		BITS_CAGE_MINE_MESSAGE,
		ZombieCharacterVisuals.GLOW_BITS_PULSE
	)

func _remove_lobby_zombie(key: String) -> void:
	var lobby_zombie: LobbyZombie = _lobby_zombies.get(key) as LobbyZombie
	if lobby_zombie != null and is_instance_valid(lobby_zombie):
		lobby_zombie.queue_free()
	_lobby_zombies.erase(key)

func _clear_lobby() -> void:
	var existing_keys: Array = _lobby_zombies.keys()
	for existing_key in existing_keys:
		_remove_lobby_zombie(str(existing_key))
	_clear_cage_mine()

func _get_join_info(display_name: String) -> ParticipantJoinInfo:
	if _round_manager == null:
		return ParticipantJoinInfo.for_name(display_name)
	return _round_manager.get_join_info_for_name(display_name)

func _get_spawn_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
		drop_height,
		_rng.randf_range(-spawn_area_size.z * 0.5, spawn_area_size.z * 0.5)
	)


func get_respawn_position() -> Vector3:
	return to_global(_get_spawn_position())


func is_outside_cage_on_ground(world_position: Vector3) -> bool:
	var local_position: Vector3 = to_local(world_position)
	var outside_horizontally: bool = (
		absf(local_position.x) > cage_half_extents_xz.x
		or absf(local_position.z) > cage_half_extents_xz.y
	)
	if not outside_horizontally:
		return false

	return (
		local_position.y >= cage_floor_y
		and local_position.y <= cage_ground_contact_max_y
	)


func spawn_cage_mine(reposition: bool = true) -> LobbyCageMine:
	if lobby_cage_mine_scene == null:
		return null

	if _cage_mine == null or not is_instance_valid(_cage_mine):
		_cage_mine = lobby_cage_mine_scene.instantiate() as LobbyCageMine
		if _cage_mine == null:
			return null
		add_child(_cage_mine)

	if reposition:
		_cage_mine.global_position = _get_cage_mine_position()
	_cage_mine.rearm()
	return _cage_mine


func has_cage_mine() -> bool:
	return _cage_mine != null and is_instance_valid(_cage_mine)


func _get_cage_mine_position() -> Vector3:
	return to_global(Vector3(
		_rng.randf_range(-cage_mine_spawn_half_extents.x, cage_mine_spawn_half_extents.x),
		cage_mine_floor_y,
		_rng.randf_range(-cage_mine_spawn_half_extents.y, cage_mine_spawn_half_extents.y)
	))


func _clear_cage_mine() -> void:
	if _cage_mine != null and is_instance_valid(_cage_mine):
		_cage_mine.queue_free()
	_cage_mine = null


func _get_lobby_key(display_name: String) -> String:
	return display_name.to_lower()

func _get_node_safe_name(display_name: String) -> String:
	var safe_name: String = display_name.strip_edges()
	var blocked_tokens: PackedStringArray = PackedStringArray([".", ":", "/", "\\", "@", "\"", "%"])
	for blocked_token in blocked_tokens:
		safe_name = safe_name.replace(blocked_token, "_")
	safe_name = safe_name.replace(" ", "_")
	if safe_name.is_empty():
		return "Zombie"
	return safe_name
