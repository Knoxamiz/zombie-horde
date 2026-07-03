# Zombie Horde

Zombie Horde is a Godot 4.x PC/Steam-targeted 3D horde race game foundation. The playable slice is organized around production systems: explicit round state, event-driven gameplay, configurable resources, replaceable scenes, debug joins, and Twitch chat joins.

## Open The Project (Windows)

1. Use this folder: `C:\dev\zombie-horde`
   - Do **not** open `C:\dev\gameday` unless that is your active clone.
2. Launch Godot 4.4 (`Godot_v4.4-stable_win64.exe`).
3. Click **Import** (or **Edit a project**) and select `C:\dev\zombie-horde\project.godot`.
4. Wait for the first import to finish.

## Get The Latest Code

If this folder came from GitHub, pull updates before testing:

```powershell
cd C:\dev\zombie-horde
git pull origin main
```

You should be on commit `a584c3a` or newer (look for version `v1.2.0-3d` in the bottom-right of the main menu).

### Quick check that you have the 3D main menu

In Godot, open `res://scenes/main_menu/main_menu.tscn` and confirm the Scene tree contains:

- `CinematicWorld` → `CityBackdrop`
- `CinematicCamera` → `Menu3DOverlay` → `TitleBlocks`, `ButtonRack`, `ChatControlsPanel`

Open `res://scripts/main_menu/main_menu_controller.gd` and confirm `_ready()` calls `_connect_3d_buttons()`.

There should be **no** `MenuLayer` node in `main_menu.tscn` and **no** `_build_control_room_screen()` in the controller.

## Run The Main Menu

1. Open `res://scenes/main_menu/main_menu.tscn`.
2. Press **F5** (Run Project).
   - Do **not** use **F6** (Run Current Scene) on `main_game.tscn` for menu testing.
3. You should see a 3D road scene with voxel title and left-side 3D buttons.
4. Bottom-right version label should read `v1.2.0-3d`.

Expected main-menu buttons:

- `START`
- `STREAMER MODE`
- `LEADERBOARD`
- `SETTINGS`

If you instead see flat panels named `LOTTO CAGE` and `CAGE RECORDS`, you are still on the old UI build.

## Run The Game Loop

1. From the 3D main menu, click **START**.
2. In the lobby/game scene use:
   - `Enter`: start round
   - `R`: reset round
   - `J`: add a simulated chat join through the join-source interface
   - Mouse: free-look camera
   - `Esc`: release mouse, then click the game window to recapture
   - `WASD`, `Space`, `Q`: move camera
   - `Shift`: camera boost
   - `C`: snap camera to arena overview

## First Loop

Viewers are represented by participants submitted to `JoinSource`. `DebugJoinSource` and `TwitchJoinSource` both feed through `JoinSourceHub`, so the game loop is not coupled to any single chat provider.

## Twitch Joins

The project includes a real Twitch IRC-over-WebSocket join source at `res://scripts/integrations/twitch/twitch_join_source.gd`.

To enable live chat joins:

1. Open `res://resources/config/twitch_chat_config.tres`.
2. Set `enabled` to `true`.
3. Set `channel_name` to the Twitch channel to listen to.
4. Leave `anonymous_mode` enabled for read-only chat listening, or disable it and provide credentials through environment variables.

Credential mode uses environment variables only:

- `ZOMBIE_HORDE_TWITCH_OAUTH`: bot OAuth token, with or without the `oauth:` prefix
- `ZOMBIE_HORDE_TWITCH_BOT_USERNAME`: bot username, unless `bot_username` is set in the resource

Do not put OAuth tokens in committed `.tres` files. Local/secret config resource names are ignored by `.gitignore`.
