class_name ZombieModelShowcaseMenu
extends HBoxContainer

const SHOWCASE_ENTRIES: Array[Dictionary] = [
	{
		"tier": ParticipantJoinInfo.SupporterTier.NONE,
		"title": "Viewer",
		"perk": "Ribcage",
		"accent": ZombieCharacterVisuals.COLOR_NON_SUB,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.SUBSCRIBER,
		"title": "Sub",
		"perk": "Green zombie",
		"accent": ZombieCharacterVisuals.COLOR_NON_SUB,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT,
		"title": "Gift",
		"perk": "Red + gift",
		"accent": ZombieCharacterVisuals.COLOR_SUBSCRIBER,
	},
	{
		"tier": ParticipantJoinInfo.SupporterTier.BITS_DONOR,
		"title": "Bits",
		"perk": "Glow + bits",
		"accent": ZombieCharacterVisuals.GLOW_BITS_PULSE,
	},
]


func _ready() -> void:
	_build_showcase()


func _build_showcase() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_END

	for index in range(SHOWCASE_ENTRIES.size()):
		if index > 0:
			add_child(_make_divider())

		var entry: Dictionary = SHOWCASE_ENTRIES[index]
		var card: ZombieTierShowcaseCard = ZombieTierShowcaseCard.new()
		card.setup(
			entry["tier"],
			entry["title"],
			entry["perk"],
			entry["accent"]
		)
		add_child(card)


func _make_divider() -> Control:
	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 108)
	divider.color = Color(1.0, 0.55, 0.1, 0.75)
	return divider
