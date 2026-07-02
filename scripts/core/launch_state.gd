class_name LaunchStateService
extends Node

const PHASE_INTRO := "intro"
const PHASE_LOBBY := "lobby"

var _requested_phase: String = PHASE_INTRO
var _debug_joins_to_seed: int = 0
var _open_settings_on_launch: bool = false

func request_intro() -> void:
	_requested_phase = PHASE_INTRO
	_debug_joins_to_seed = 0
	_open_settings_on_launch = false

func request_lobby(debug_joins_to_seed: int = 0, open_settings_on_launch: bool = false) -> void:
	_requested_phase = PHASE_LOBBY
	_debug_joins_to_seed = max(debug_joins_to_seed, 0)
	_open_settings_on_launch = open_settings_on_launch

func consume_request() -> Dictionary:
	var request: Dictionary = {
		"phase": _requested_phase,
		"debug_joins_to_seed": _debug_joins_to_seed,
		"open_settings": _open_settings_on_launch,
	}
	request_intro()
	return request
