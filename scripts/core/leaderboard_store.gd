class_name LeaderboardStore
extends Node

signal leaderboard_changed(entries: Array)

@export var save_path: String = "user://zombie_horde_fastest_winners.json"
@export_range(1, 50, 1) var max_entries: int = 10
@export_range(1, 50, 1) var max_recent_entries: int = 10

var _entries: Array[Dictionary] = []
var _recent_winners: Array[Dictionary] = []

func _ready() -> void:
	load_entries()

func submit_winner(display_name: String, elapsed_seconds: float, round_number: int) -> void:
	submit_result(display_name, elapsed_seconds, round_number, false)

func submit_result(display_name: String, elapsed_seconds: float, round_number: int, base_won: bool) -> void:
	if display_name.strip_edges().is_empty() or elapsed_seconds <= 0.0:
		return

	var entry: Dictionary = {
		"display_name": display_name,
		"elapsed_seconds": elapsed_seconds,
		"round_number": round_number,
		"base_won": base_won,
		"timestamp": Time.get_datetime_string_from_system(false, true)
	}
	_recent_winners.insert(0, entry.duplicate(true))
	while _recent_winners.size() > max_recent_entries:
		_recent_winners.remove_at(_recent_winners.size() - 1)

	if not base_won:
		_entries.append(entry.duplicate(true))
		_entries.sort_custom(_sort_by_elapsed_time)
		while _entries.size() > max_entries:
			_entries.remove_at(_entries.size() - 1)
	save_entries()
	leaderboard_changed.emit(get_entries())

func get_entries() -> Array:
	var result: Array = []
	for entry in _entries:
		result.append(entry.duplicate(true))
	return result

func get_recent_winners() -> Array:
	var result: Array = []
	for entry in _recent_winners:
		result.append(entry.duplicate(true))
	return result

func load_entries() -> void:
	_entries.clear()
	_recent_winners.clear()
	if not FileAccess.file_exists(save_path):
		leaderboard_changed.emit(get_entries())
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		leaderboard_changed.emit(get_entries())
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			if typeof(item) == TYPE_DICTIONARY:
				var loaded_entry: Dictionary = item
				_entries.append(loaded_entry)
	elif typeof(parsed) == TYPE_DICTIONARY:
		var parsed_dictionary: Dictionary = parsed
		_load_entry_array(parsed_dictionary.get("fastest", []), _entries)
		_load_entry_array(parsed_dictionary.get("recent", []), _recent_winners)
	_entries.sort_custom(_sort_by_elapsed_time)
	while _entries.size() > max_entries:
		_entries.remove_at(_entries.size() - 1)
	while _recent_winners.size() > max_recent_entries:
		_recent_winners.remove_at(_recent_winners.size() - 1)
	leaderboard_changed.emit(get_entries())

func save_entries() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save leaderboard to %s" % save_path)
		return

	file.store_string(JSON.stringify({
		"fastest": _entries,
		"recent": _recent_winners
	}, "\t"))

func _sort_by_elapsed_time(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("elapsed_seconds", 999999.0)) < float(b.get("elapsed_seconds", 999999.0))

func _load_entry_array(source: Variant, target: Array[Dictionary]) -> void:
	if typeof(source) != TYPE_ARRAY:
		return

	for item in source:
		if typeof(item) == TYPE_DICTIONARY:
			var loaded_entry: Dictionary = item
			target.append(loaded_entry)
