# Zombie Horde

Zombie Horde is a Godot 4.x PC/Steam-targeted 3D horde race game foundation. The playable slice is organized around production systems: explicit round state, event-driven gameplay, configurable resources, replaceable scenes, debug joins, and Twitch chat joins.

## Run

1. Open this folder in Godot 4.x: `C:\dev\gameday\zombie-horde`.
2. Open `res://scenes/main/main_game.tscn`.
3. Press Play.
4. Use the HUD buttons or keyboard controls:
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
