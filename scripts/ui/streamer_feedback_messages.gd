class_name StreamerFeedbackMessages
extends RefCounted

static func format_join_rejected(display_name: String, reason: String) -> String:
	var who: String = display_name.strip_edges()
	if who.is_empty():
		who = "Viewer"
	match reason:
		"race_running":
			return "Join rejected — race already live."
		"race_ended":
			return "Join rejected — race over. Press Enter to restart or reset for lobby."
		"queue_full":
			return "Queue full — wait for next race."
		"duplicate_name":
			return "Join rejected — %s is already queued or racing." % who
		"invalid_name":
			return "Join rejected — invalid viewer name."
		"countdown_spawn_failed":
			return "Join rejected — could not add %s during countdown." % who
		_:
			return "Join rejected — %s cannot join right now." % who


static func format_join_accepted_late(display_name: String) -> String:
	var who: String = display_name.strip_edges()
	if who.is_empty():
		who = "Viewer"
	return "+ %s joined during countdown — racing!" % who


static func format_time_limit_feed(winner_name: String, base_won: bool) -> String:
	if base_won:
		return "TIME LIMIT — base holds. No zombie reached the goal."
	return "TIME LIMIT — %s led on progress and wins." % winner_name


static func format_time_limit_podium_title(base_won: bool) -> String:
	if base_won:
		return "TIME LIMIT — BASE HOLDS!"
	return "TIME LIMIT — ZOMBIE WINS!"


static func format_auto_reset_command(seconds_remaining: int) -> String:
	if seconds_remaining <= 0:
		return "Next race: Press Enter to restart, or R to return to lobby."
	return (
		"Auto-reset in %ds — Press Enter to restart, or R for lobby."
		% seconds_remaining
	)
