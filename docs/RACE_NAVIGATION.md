# Race Navigation

Zombie Horde uses Godot's 3D navigation stack for runner movement. Map route
order and physical pathfinding are intentionally separate:

- `RaceMapDefinition.race_path_points` defines race checkpoint order for turns,
  ramps, stacked decks, progress, and leaderboard ranking.
- `RaceNavigationWorld` creates `NavigationRegion3D` nodes from authoritative
  walk collision after the selected map loads.
- Each zombie owns a `NavigationAgent3D`; it requests a path to its current
  ordered checkpoint and uses Godot RVO avoidance to pass other zombies and
  registered hazards.

## Map authoring contract

Every walkable surface must opt into the `race_navigation_surfaces` group.

- `MapSurfacePiece` does this automatically.
- Procedural map builders should add the group only to road, deck, ramp, and
  intentionally narrow crossing collision bodies.
- Never add barriers, void kill volumes, decoration, or sight blockers to the
  group.

`RaceNavigationWorld` creates links only where opted-in surfaces touch in X/Z
and share an elevation range. This joins a narrow bridge crossing to its deck
without connecting separate stacked levels.

## Dynamic hazards

Hazards that runners should move around use `NavigationObstacle3D`. Vehicles
are registered as avoidance obstacles, so they influence RVO steering without
changing finish, fall, or collision authority.

## Verification

`scripts/debug/race_navigation_world_test.gd` validates navigation surfaces
and a complete NavigationServer path across every selectable map. Run it with:

```powershell
& "C:\Tools\Godot\Godot_v4.4-stable_win64.exe" --headless --path . -s res://scripts/debug/race_navigation_world_test.gd
```
