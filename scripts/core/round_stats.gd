class_name RoundStats
extends RefCounted

var round_number: int = 0
var participants_started: int = 0
var mine_triggers: int = 0
var mine_kills: int = 0
var minigun_shots: int = 0
var minigun_hits: int = 0
var minigun_kills: int = 0
var other_kills: int = 0
var crawlers_created: int = 0
var dismember_survivals: int = 0
var elapsed_seconds: float = 0.0
var winner_name: String = ""
var base_won: bool = false
var runner_up_results: Array[Dictionary] = []
var kill_causes: Dictionary = {}

func reset_for_round(new_round_number: int) -> void:
	round_number = new_round_number
	participants_started = 0
	mine_triggers = 0
	mine_kills = 0
	minigun_shots = 0
	minigun_hits = 0
	minigun_kills = 0
	other_kills = 0
	crawlers_created = 0
	dismember_survivals = 0
	elapsed_seconds = 0.0
	winner_name = ""
	base_won = false
	runner_up_results.clear()
	kill_causes.clear()

func record_spawn() -> void:
	participants_started += 1

func record_mine_trigger() -> void:
	mine_triggers += 1

func record_minigun_shot(hit: bool) -> void:
	minigun_shots += 1
	if hit:
		minigun_hits += 1

func record_crawler_created() -> void:
	crawlers_created += 1

func record_dismember_survival() -> void:
	dismember_survivals += 1

func record_death(cause: String) -> void:
	var clean_cause: String = cause.strip_edges()
	if clean_cause.is_empty():
		clean_cause = "unknown"
	kill_causes[clean_cause] = int(kill_causes.get(clean_cause, 0)) + 1

	match cause:
		"mine":
			mine_kills += 1
		"minigun":
			minigun_kills += 1
		_:
			other_kills += 1

func record_winner(new_winner_name: String, did_base_win: bool, finish_seconds: float) -> void:
	winner_name = new_winner_name
	base_won = did_base_win
	elapsed_seconds = max(finish_seconds, 0.0)

func record_runner_ups(results: Array[Dictionary]) -> void:
	runner_up_results.clear()
	for result in results:
		runner_up_results.append(result.duplicate(true))

func to_dictionary(living_count: int = 0) -> Dictionary:
	return {
		"round_number": round_number,
		"participants_started": participants_started,
		"living_count": living_count,
		"mine_triggers": mine_triggers,
		"mine_kills": mine_kills,
		"minigun_shots": minigun_shots,
		"minigun_hits": minigun_hits,
		"minigun_kills": minigun_kills,
		"other_kills": other_kills,
		"crawlers_created": crawlers_created,
		"dismember_survivals": dismember_survivals,
		"elapsed_seconds": elapsed_seconds,
		"winner_name": winner_name,
		"base_won": base_won,
		"runner_up_results": _duplicate_runner_up_results(),
		"kill_causes": kill_causes.duplicate(true)
	}

func _duplicate_runner_up_results() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for runner_up in runner_up_results:
		result.append(runner_up.duplicate(true))
	return result
