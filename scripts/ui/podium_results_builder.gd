class_name PodiumResultsBuilder
extends RefCounted

const PLACE_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.2, 1.0),
	Color(0.78, 0.82, 0.9, 1.0),
	Color(0.86, 0.55, 0.28, 1.0),
]


static func build_top_three(
	winner_name: String,
	base_won: bool,
	stats: Dictionary,
	zombie_manager: ZombieManager = null
) -> Array[Dictionary]:
	var runner_ups: Array = []
	var raw_runner_ups: Variant = stats.get("runner_up_results", [])
	if typeof(raw_runner_ups) == TYPE_ARRAY:
		runner_ups = raw_runner_ups

	var podium: Array[Dictionary] = []
	if base_won:
		for index in range(mini(3, runner_ups.size())):
			if typeof(runner_ups[index]) != TYPE_DICTIONARY:
				continue
			podium.append(_with_position(runner_ups[index], index + 1))
		return podium

	var winner_entry: Dictionary = {}
	if zombie_manager != null:
		winner_entry = zombie_manager.get_result_for_display_name(winner_name)
	else:
		winner_entry = {
			"display_name": winner_name,
			"progress": 1.0,
			"alive": true,
			"tier": ParticipantJoinInfo.SupporterTier.NONE,
			"tier_label": "Viewer",
		}
	podium.append(_with_position(winner_entry, 1))

	for index in range(mini(2, runner_ups.size())):
		if typeof(runner_ups[index]) != TYPE_DICTIONARY:
			continue
		podium.append(_with_position(runner_ups[index], index + 2))

	return podium


static func get_place_color(position: int) -> Color:
	var index: int = clampi(position - 1, 0, PLACE_COLORS.size() - 1)
	return PLACE_COLORS[index]


static func get_podium_display_order(podium: Array[Dictionary]) -> Array[Dictionary]:
	if podium.size() <= 1:
		return podium

	var ordered: Array[Dictionary] = []
	var by_position: Dictionary = {}
	for entry in podium:
		by_position[int(entry.get("position", 0))] = entry

	if by_position.has(2):
		ordered.append(by_position[2])
	if by_position.has(1):
		ordered.append(by_position[1])
	if by_position.has(3):
		ordered.append(by_position[3])
	return ordered


static func _with_position(entry: Dictionary, position: int) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	result["position"] = position
	return result
