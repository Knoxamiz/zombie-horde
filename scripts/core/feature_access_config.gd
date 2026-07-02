class_name FeatureAccessConfig
extends Resource

enum Edition {
	BASIC,
	PAID_PREMIUM
}

@export_enum("Basic", "Paid Premium") var edition: int = Edition.PAID_PREMIUM

func has_premium_access() -> bool:
	return edition == Edition.PAID_PREMIUM

func can_use_streamer_settings() -> bool:
	return has_premium_access()

func can_use_map_selection() -> bool:
	return has_premium_access()

func can_use_presets() -> bool:
	return has_premium_access()

func get_edition_name() -> String:
	return "Paid Premium" if has_premium_access() else "Basic"

func get_edition_detail() -> String:
	if has_premium_access():
		return "Full street controls, map selection, presets, and chaos tuning"
	return "Basic locks settings and runs one fixed map"
