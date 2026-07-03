extends SceneTree

func _initialize() -> void:
	var screen_script: Script = preload("res://scripts/ui/main_lobby_screen.gd")
	var modal_script: Script = preload("res://scripts/ui/settings_modal.gd")

	var screen: MainLobbyScreen = screen_script.new() as MainLobbyScreen
	root.add_child(screen)
	await process_frame
	screen.set_actions([
		{"id": &"ready", "icon": ">", "label": "Ready", "primary": true},
		{"id": &"settings", "icon": "G", "label": "Game Settings"},
	])
	screen.set_lobby_status("8 zombies shaking the cage", "01  ByteBiter\n02  GraveSnarl", "Chat: Twitch live", "Joining")
	screen.set_records("Fastest Times\n1. Ada  8.92s", "Last Winners\n1. Ada  8.92s")
	screen.set_chat_activity(PackedStringArray(["ByteBiter: !brains", "GraveSnarl: !chaos"]))
	screen.set_bottom_items([{"label": "Map", "value": "Quarantine Boulevard"}])

	var modal: SettingsModal = modal_script.new() as SettingsModal
	root.add_child(modal)
	await process_frame
	modal.set_title("Game Settings")
	var group: VBoxContainer = modal.add_group("Audio")
	var button := Button.new()
	button.text = "DONE"
	modal.add_row(group, "Master", button)
	modal.show_modal()

	var file := FileAccess.open("res://.codex_ui_validation.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("ok")
	quit()
