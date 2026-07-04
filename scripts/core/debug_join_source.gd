class_name DebugJoinSource
extends JoinSource

@export var round_config: RoundConfig
@export var auto_seed_on_boot: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _generated_count: int = 0

func _ready() -> void:
	_rng.randomize()

func seed_default_participants() -> void:
	if round_config == null or not round_config.auto_seed_debug_roster:
		return

	for display_name in round_config.default_debug_names:
		submit_join(display_name)

func request_random_join() -> void:
	_generated_count += 1
	if round_config != null and round_config.default_debug_names.size() > 0:
		var index: int = _rng.randi_range(0, round_config.default_debug_names.size() - 1)
		submit_join("NPC %s_%02d" % [round_config.default_debug_names[index], _generated_count])
		return

	submit_join("NPC Runner_%02d" % _generated_count)

