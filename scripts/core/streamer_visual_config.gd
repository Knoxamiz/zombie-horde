class_name StreamerVisualConfig
extends Resource

enum TimeOfDay {
	NIGHT,
	DAY
}

enum BackdropStyle {
	CITY,
	INDUSTRIAL,
	SKYLINE
}

enum StreamerAvatar {
	MATT,
	LIS,
	SAM,
	SHAUN
}

@export_enum("Night", "Day") var time_of_day: int = TimeOfDay.NIGHT
@export_enum("City", "Industrial Yard", "Skyline") var backdrop_style: int = BackdropStyle.CITY
@export_enum("Matt", "Lis", "Sam", "Shaun") var streamer_avatar: int = StreamerAvatar.MATT
@export var streamer_name: String = "Streamer"
