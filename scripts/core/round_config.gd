class_name RoundConfig
extends Resource

@export_range(1, 256, 1) var min_participants_to_start: int = 1
@export_range(1, 512, 1) var max_pending_participants: int = 128
@export_range(1, 15, 1) var countdown_seconds: int = 5
@export_range(0.0, 900.0, 1.0, "suffix:sec") var max_race_duration_seconds: float = 180.0
@export_range(0.0, 300.0, 1.0, "suffix:sec") var post_round_auto_reset_seconds: float = 45.0
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
