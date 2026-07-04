class_name JoinSource
extends Node

signal participant_join_requested(join_info: ParticipantJoinInfo)

func submit_join(display_name: String, join_info: ParticipantJoinInfo = null) -> void:
	var clean_name: String = display_name.strip_edges()
	if clean_name.is_empty():
		return

	var payload: ParticipantJoinInfo = join_info
	if payload == null:
		payload = ParticipantJoinInfo.for_name(clean_name)
	elif payload.display_name.is_empty():
		payload.display_name = clean_name

	participant_join_requested.emit(payload)
