class_name ZombieModelShowcaseMenu
extends PanelContainer

const SHOWCASE_ENTRIES: Array[Dictionary] = [
	{
		"tier": ParticipantJoinInfo.SupporterTier.NONE,
		"title": "Viewer",
		"perk": "Type !brains to join",
		"accent": ZombieCharacterVisuals.COLOR_NON_SUB,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.SUBSCRIBER,
		"title": "Subscriber",
		"perk": "Red body + horns",
		"accent": ZombieCharacterVisuals.COLOR_SUBSCRIBER,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT,
		"title": "Gift Sub",
		"perk": "Red body + bandana",
		"accent": ZombieCharacterVisuals.COLOR_SUBSCRIBER,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.BITS_DONOR,
		"title": "Bits Cheer",
		"perk": "Gold glow + crown",
		"accent": ZombieCharacterVisuals.GLOW_BITS_PULSE,
	},
]


func _ready() -> void:
	_build_showcase()


func _build_showcase() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var title_label: Label = Label.new()
	title_label.text = "ZOMBIE MODEL SHOWCASE — WHAT YOU CAN GET"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.58, 1.0))
	column.add_child(title_label)

	var tier_row: HBoxContainer = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 10)
	tier_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(tier_row)

	for entry in SHOWCASE_ENTRIES:
		var card: ZombieTierShowcaseCard = ZombieTierShowcaseCard.new()
		card.setup(
			entry["tier"],
			entry["title"],
			entry["perk"],
			entry["accent"]
		)
		tier_row.add_child(card)
