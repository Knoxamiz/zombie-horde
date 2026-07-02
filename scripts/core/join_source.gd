class_name JoinSource
extends Node

signal participant_join_requested(display_name: String)

func submit_join(display_name: String) -> void:
	var clean_name: String = display_name.strip_edges()
	if clean_name.is_empty():
		return

	participant_join_requested.emit(clean_name)

