class_name FakeViewerSimulator
extends Node

enum SimMode {
	STOPPED,
	INSTANT,
	TRICKLE,
	BURST,
}

const TRICKLE_SECONDS := 20.0
const TRICKLE_RATE_PER_SEC := 1.0
const BURST_VIEWER_COUNT := 20
const BURST_SECONDS := 3.0

const NORMAL_PREFIXES: Array[String] = [
	"Pixel",
	"Neon",
	"Turbo",
	"Crimson",
	"Shadow",
	"Nova",
	"Echo",
	"Glitch",
	"Byte",
	"Turbo",
]
const NORMAL_SUFFIXES: Array[String] = [
	"Runner",
	"Rider",
	"Fan",
	"Zombie",
	"Chaser",
	"Hopper",
	"Drifter",
	"Sprinter",
	"Nomad",
	"Crew",
]
const FUNNY_NAMES: Array[String] = [
	"BrainsForBreakfast",
	"CoffeeAndCrawlers",
	"LateToTheHorde",
	"OneMoreLapPls",
	"ChatGoesBrrr",
	"JustHereForChaos",
	"SnackAttackSam",
	"QueueDancer",
	"RespawnWaitingRoom",
	"TrailMixTyrant",
]

var _debug_join_source: DebugJoinSource
var _round_manager: RoundManager
var _zombie_manager: ZombieManager
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _mode: SimMode = SimMode.STOPPED
var _mode_text: String = "stopped"
var _running: bool = false
var _joins_sent: int = 0
var _joins_rejected: int = 0
var _name_sequence: int = 0

var _scheduled_joins: int = 0
var _tick_timer: float = 0.0
var _tick_interval: float = 1.0


func _enter_tree() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_rng.randomize()
	if not GameEvents.round_reset.is_connected(_on_round_reset):
		GameEvents.round_reset.connect(_on_round_reset)


func _exit_tree() -> void:
	stop_simulation()


func configure(
	debug_join_source: DebugJoinSource,
	round_manager: RoundManager,
	zombie_manager: ZombieManager
) -> void:
	_debug_join_source = debug_join_source
	_round_manager = round_manager
	_zombie_manager = zombie_manager


func is_running() -> bool:
	return _running


func get_mode_text() -> String:
	return _mode_text


func get_joins_sent() -> int:
	return _joins_sent


func get_joins_rejected() -> int:
	return _joins_rejected


func get_pending_simulated_joins() -> int:
	return _scheduled_joins


func simulate_viewers(count: int) -> void:
	stop_simulation()
	if count <= 0:
		return
	_mode = SimMode.INSTANT
	_mode_text = "instant x%d" % count
	_running = true
	for _index in range(count):
		_send_generated_join()
	_stop_running()


func start_trickle_joins(duration_sec: float = TRICKLE_SECONDS, rate_per_sec: float = TRICKLE_RATE_PER_SEC) -> void:
	stop_simulation()
	var total_joins: int = int(duration_sec * rate_per_sec)
	if total_joins <= 0:
		return
	_mode = SimMode.TRICKLE
	_mode_text = "trickle %d/s for %.0fs" % [rate_per_sec, duration_sec]
	_running = true
	_scheduled_joins = total_joins
	_tick_interval = 1.0 / max(rate_per_sec, 0.1)
	_tick_timer = 0.0
	set_process(true)


func start_burst_joins(count: int = BURST_VIEWER_COUNT, duration_sec: float = BURST_SECONDS) -> void:
	stop_simulation()
	if count <= 0:
		return
	_mode = SimMode.BURST
	_mode_text = "burst %d in %.0fs" % [count, duration_sec]
	_running = true
	_scheduled_joins = count
	_tick_interval = duration_sec / float(count)
	_tick_timer = 0.0
	set_process(true)


func clear_simulator_queue() -> void:
	_scheduled_joins = 0
	if _mode in [SimMode.TRICKLE, SimMode.BURST]:
		_stop_running()


func stop_simulation() -> void:
	_scheduled_joins = 0
	_tick_timer = 0.0
	_stop_running()


func _process(delta: float) -> void:
	if not _running or _mode == SimMode.STOPPED or _mode == SimMode.INSTANT:
		set_process(false)
		return

	_tick_timer += delta
	while _tick_timer >= _tick_interval and _scheduled_joins > 0:
		_tick_timer -= _tick_interval
		_send_generated_join()
		_scheduled_joins -= 1

	if _scheduled_joins <= 0:
		_stop_running()


func _send_generated_join() -> bool:
	if _debug_join_source == null or _round_manager == null:
		_joins_rejected += 1
		return false

	var join_info: ParticipantJoinInfo = _build_join_info()
	var before_pending: int = _round_manager.get_pending_count()
	var before_zombies: int = _zombie_manager.get_total_count() if _zombie_manager != null else 0

	_debug_join_source.submit_join(join_info.display_name, join_info)
	_joins_sent += 1

	var accepted: bool = _was_join_accepted(before_pending, before_zombies)
	if not accepted:
		_joins_rejected += 1
	return accepted


func _was_join_accepted(before_pending: int, before_zombies: int) -> bool:
	match _round_manager.state:
		RoundManager.RoundState.IDLE:
			return _round_manager.get_pending_count() > before_pending
		RoundManager.RoundState.COUNTDOWN:
			if _zombie_manager == null:
				return false
			return _zombie_manager.get_total_count() > before_zombies
		_:
			return false


func _build_join_info() -> ParticipantJoinInfo:
	var display_name: String = _generate_display_name()
	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.for_name(display_name)
	var tier_roll: float = _rng.randf()
	if tier_roll < 0.05:
		join_info.is_bits_donor = true
		join_info.bits_amount = _rng.randi_range(1, 500)
	elif tier_roll < 0.15:
		join_info.is_gift_recipient = true
		join_info.is_subscriber = true
	elif tier_roll < 0.30:
		join_info.is_subscriber = true
	return join_info


func _generate_display_name() -> String:
	_name_sequence += 1
	var style_roll: int = _rng.randi_range(0, 2)
	match style_roll:
		0:
			var prefix: String = NORMAL_PREFIXES[_rng.randi_range(0, NORMAL_PREFIXES.size() - 1)]
			var suffix: String = NORMAL_SUFFIXES[_rng.randi_range(0, NORMAL_SUFFIXES.size() - 1)]
			return "%s%s_%04d" % [prefix, suffix, _name_sequence]
		1:
			var funny_name: String = FUNNY_NAMES[_rng.randi_range(0, FUNNY_NAMES.size() - 1)]
			return "%s_%04d" % [funny_name, _name_sequence]
		_:
			return "Viewer_%04d" % _name_sequence


func _on_round_reset() -> void:
	stop_simulation()


func _stop_running() -> void:
	_running = false
	_mode = SimMode.STOPPED
	_mode_text = "stopped"
	set_process(false)
