# NPC Navigation

Zombie Horde uses one navigation pipeline for all runners. It is deliberately
split so each concern has a single owner and new maps can be tuned without
editing zombie behavior.

## Ownership

| Concern | Owner |
|---|---|
| Walkable navigation geometry | `RaceNavigationWorld` from `MapSurfacePiece` surfaces |
| Race order / stacked-deck sequencing | `RaceRouteNavigator` checkpoints in `RaceMapDefinition.race_path_points` |
| Per-zombie target, path query, RVO handoff | `NpcNavigationController` |
| Local drift and crowd flavor | `RaceSteering` |
| Visual facing | `Zombie._update_visual_facing()` from actual movement velocity |
| Map-specific tuning | `NpcNavigationProfile` resource referenced by `RaceMapDefinition` |

Route points are not a movement centerline. They are ordered gates. A zombie
uses `NavigationAgent3D` to reach the active gate through valid walkable space,
which preserves intended order on ramps and stacked maps without forcing every
runner into the same line.

## Map Setup

Every playable map definition references a profile in `resources/config/`:

- `npc_navigation_city_highway.tres`
- `npc_navigation_broken_bridge.tres`
- `npc_navigation_straight_descent.tres`
- `npc_navigation_square_spiral.tres`

For a new map, duplicate the closest profile, assign it to the definition's
**NPC Navigation** field, then author route points in traversal order. Keep
walkable surfaces as `MapSurfacePiece`; `RaceNavigationWorld` derives Godot
navigation regions from those same collision slabs.

## Tuning Guide

- **checkpoint reach radius:** Larger for long open roads; smaller for tight
  turns or stacked decks.
- **checkpoint / finish lane spread:** Controls how much of the navigable road
  runners naturally occupy. It is a target offset, never a corrective pull.
- **target refresh:** Lower values react more quickly to turns; higher values
  reduce path-query churn for very large hordes.
- **avoidance values:** Tune crowd density and RVO behavior without changing
  route progress or collision rules.

## Diagnostics and Tests

`Zombie.get_navigation_diagnostics()` returns the active segment, progress,
requested target, path direction, nav readiness, and whether a temporary
pre-nav fallback is active. This data is safe to expose through debug tools.

Core regression coverage:

- `npc_navigation_controller_test.gd`
- `race_steering_test.gd`
- `race_route_navigation_test.gd`
- `race_navigation_world_test.gd`

Run `--tier=core` after movement changes. Do not add map-specific movement
branches to `Zombie`; adjust the map profile or route/surface data instead.
