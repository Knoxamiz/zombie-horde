# Map Certification

Every selectable map must pass certification before it becomes playable.
Certification is strict: a failed map load fails loudly and never substitutes
City Highway or leaves the old map running.

See [MAP_NAMING.md](MAP_NAMING.md) for the one catalog / definition / scene
contract.

## Map States

| State | Meaning |
|---|---|
| Disabled asset | `enabled=false`, `status=disabled`. Kept for authoring only. It is not selectable or loadable by the game. |
| Certified map | Passes `map_certification_test.gd` in headless runs. |
| Playable map | `enabled=true`, `status=playable`. Listed in settings and loaded by `RaceMapController.set_active_map_by_id(map_id)`. |

## Certification Checklist

`MapCertification` validates:

1. Map ID exists in `MapCatalog` and is playable.
2. Definition resource and scene path exist.
3. Spawn, goal, base, OOB, hazard placement, and camera data are valid.
4. The instantiated map has the `RoadArena` and `CoreRoad` scene contract.
5. `World/StreamerBase` aligns with `definition.base_position`.
6. OOB values are applied to `ZombieConfig`.
7. A mini race can join, start, resolve, reset, and rejoin.
8. No fallback map was used.

## Commands

```bash
# All required maps
godot --headless --path . -s res://scripts/debug/map_certification_test.gd

# One map
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=quarantine_boulevard
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=broken_bridge_pass
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=spiral_descent
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=true_spiral_ramp

# Selection plus certification
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=certification
```

## Enabling A Map

1. Add the definition and scene under the canonical paths.
2. Add one disabled catalog entry.
3. Pass map certification, finish contract, and OOB checks as applicable.
4. Add the ID to `MapCertification.DEFAULT_CERTIFIED_MAP_IDS`.
5. Set only that catalog entry to `enabled=true`, `status=playable`.
6. Run smoke and certification again.

## Non-Negotiable Rules

- Do not add a second loader or scene-export map slot.
- Do not ignore `MAP LOAD FAILED` output.
- Do not disable certification checks to make a test pass.
- Do not add a silent fallback.
- Do not make map scenes their own finish or OOB authority.
