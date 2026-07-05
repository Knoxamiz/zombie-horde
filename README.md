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

## Streaming With OBS + Twitch (Primary Workflow)

Zombie Horde is built for Twitch chat games captured in OBS. Use **STREAMER MODE** on the main menu for the recommended setup.

### Quick start for streamers

1. Click **STREAMER MODE** on the main menu.
   - Applies OBS-friendly defaults: 1920x1080 borderless, clean capture (no screen wash), hidden lobby test buttons, 60 FPS cap.
2. In OBS, add a **Game Capture** or **Window Capture** source for `Zombie Horde`.
3. Set your Twitch channel (see below).
4. Tell chat: viewers type your join command (default `!brains`) to join the cage.

### Twitch channel setup

1. Copy `res://resources/config/twitch_chat_config.example.tres` to `user://twitch_chat_config.local.tres`.
   - In Godot: save the template into your user data folder, or duplicate it on disk as `twitch_chat_config.local.tres` beside your exported game’s user data.
2. Set `channel_name` to your Twitch channel (without `#`).
3. Optional: change `join_command` (default `!brains`). All lobby/HUD text syncs from this automatically.
4. For read-only chat listening, leave `anonymous_mode = true` (no OAuth needed).
5. For a bot account with full IRC login, set `anonymous_mode = false` and use `env.example` variables.

### OBS capture tips

| Setting | Recommendation |
|---------|----------------|
| Canvas | 1920x1080 (Settings → Streamer → OBS Canvas) |
| Display mode | Borderless |
| Capture type | Game Capture (preferred) or Window Capture |
| Facecam | Use HUD Layout Editor to keep panels in corners and leave space for cam |
| Mouse | Race free cam is on by default in STREAMER MODE so you can orbit and follow the race |

Tweak stream capture in **Settings → Streamer**: hide screen wash, hide test buttons, toggle race free cam, or click **APPLY OBS DEFAULTS**.

### Twitch features in-game

- **Chat join**: viewers type `!brains` (or your custom command) to join the lobby cage.
- **Bits**: any cheer drops a cage mine with the message `1 bit = Cage mine!!!`
- **Subs / gifts / bits tiers**: supporter visuals on zombies (glow, icons, sparkles).
- **Chat status**: shown in lobby and race HUD when Twitch is connected.

### Environment variables

See `env.example` for bot OAuth setup:

- `ZOMBIE_HORDE_TWITCH_OAUTH`
- `ZOMBIE_HORDE_TWITCH_BOT_USERNAME`
