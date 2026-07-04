class_name RoundConfig
extends Resource

@export_range(1, 256, 1) var min_participants_to_start: int = 1
@export_range(1, 512, 1) var max_pending_participants: int = 128
@export_range(1, 15, 1) var countdown_seconds: int = 5
@export var command_text: String = "Type !brains to join."
@export var auto_seed_debug_roster: bool = false
@export var default_debug_names: PackedStringArray = PackedStringArray([
	"Ada",
	"ByteBiter",
	"CaptainDecay",
	"DoomSprint",
	"EchoRot",
	"GlitchGnaw",
	"HexHunger",
	"PixelMunch"
])
