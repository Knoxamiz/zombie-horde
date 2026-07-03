class_name RaceWorldBoardsGuard
extends Node3D

func _ready() -> void:
	_hide_boards()

func _process(_delta: float) -> void:
	_hide_boards()

func _hide_boards() -> void:
	if visible:
		visible = false
