class_name InputMapSetup
extends Node

const ACTION_BINDINGS: Dictionary = {
	"camera_forward": [KEY_W, KEY_UP],
	"camera_back": [KEY_S, KEY_DOWN],
	"camera_left": [KEY_A, KEY_LEFT],
	"camera_right": [KEY_D, KEY_RIGHT],
	"camera_up": [KEY_SPACE],
	"camera_down": [KEY_Q],
	"camera_boost": [KEY_SHIFT],
	"camera_overview": [KEY_C],
	"camera_director": [KEY_F],
	"round_start": [KEY_ENTER],
	"round_reset": [KEY_R],
	"debug_join": [KEY_J]
}

func _ready() -> void:
	for action_name in ACTION_BINDINGS.keys():
		var string_name: StringName = StringName(action_name)
		var key_codes: Array = ACTION_BINDINGS[action_name]
		_ensure_key_action(string_name, key_codes)

func _ensure_key_action(action_name: StringName, key_codes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for key_code in key_codes:
		var physical_keycode: int = int(key_code)
		if not _action_has_physical_key(action_name, physical_keycode):
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = physical_keycode
			InputMap.action_add_event(action_name, event)

func _action_has_physical_key(action_name: StringName, physical_keycode: int) -> bool:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for input_event in events:
		var key_event: InputEventKey = input_event as InputEventKey
		if key_event != null and key_event.physical_keycode == physical_keycode:
			return true
	return false
