class_name HoldToConfirmButton
extends Button

signal hold_confirmed()

@export var hold_seconds: float = 3.0

var _holding: bool = false
var _hold_elapsed: float = 0.0
var _base_text: String = ""


func _ready() -> void:
	_base_text = text
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _process(delta: float) -> void:
	if not _holding or disabled:
		return

	_hold_elapsed += delta
	var remaining: float = maxf(hold_seconds - _hold_elapsed, 0.0)
	text = "%s (%.0f)" % [_base_text, ceil(remaining)]
	if _hold_elapsed >= hold_seconds:
		_cancel_hold()
		hold_confirmed.emit()


func set_base_text(new_text: String) -> void:
	_base_text = new_text
	if not _holding:
		text = _base_text


func _on_button_down() -> void:
	if disabled:
		return
	_holding = true
	_hold_elapsed = 0.0


func _on_button_up() -> void:
	_cancel_hold()


func _cancel_hold() -> void:
	_holding = false
	_hold_elapsed = 0.0
	text = _base_text
