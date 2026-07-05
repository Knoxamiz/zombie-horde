class_name DebugJoinSource
extends JoinSource

@export var round_config: RoundConfig
@export var auto_seed_on_boot: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _generated_count: int = 0
var _test_join_counts: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_reset_test_join_counts()
	GameEvents.round_reset.connect(_on_round_reset)


func _on_round_reset() -> void:
	_reset_test_join_counts()


func _reset_test_join_counts() -> void:
	_test_join_counts = {
		ParticipantJoinInfo.SupporterTier.NONE: 0,
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER: 0,
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT: 0,
		ParticipantJoinInfo.SupporterTier.BITS_DONOR: 0,
	}


func request_test_tier_join(tier: ParticipantJoinInfo.SupporterTier) -> void:
	var sequence: int = int(_test_join_counts.get(tier, 0)) + 1
	_test_join_counts[tier] = sequence
	var join_info: ParticipantJoinInfo = ParticipantJoinInfo.create_test_join(tier, sequence)
	submit_join(join_info.display_name, join_info)


func request_test_bits_cheer(bits_amount: int = 1) -> void:
	GameEvents.bits_cheer_received.emit("TestCheerer", max(bits_amount, 1))

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

