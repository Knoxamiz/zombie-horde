# Map Certification

Every selectable map must pass certification before promotion. Certification is strict in debug and headless runs: failed maps fail loudly and never silently load City Highway.

See also: [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md), [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md), [TESTING.md](TESTING.md).

## Map stages

| Stage | Meaning |
|-------|---------|
| **Prototype map** | `enabled=false`, `status=prototype`. Loadable in map lab / prototype loader only. |
| **Testing map** | `enabled_for_testing=true` prototype (e.g. Broken Bridge TEST). Selectable in settings but not playable production. |
| **Certified map** | Passes `map_certification_test.gd` checklist in headless runs. |
| **Playable map** | `enabled=true`, `status=playable`. Shown as production map (e.g. City Highway). |

## Certification checklist

`MapCertification` validates:

1. Map id exists in `MapCatalog` and is selectable
2. `RaceMapDefinition` resource and scene path exist
3. `RaceMapDefinition` spawn/goal/base/OOB/camera values are valid
4. Map scene loads and meets scene contract (`RoadArena`, `CoreRoad`, blueprint layers)
5. `World/StreamerBase` aligns with `definition.base_position` (finish contract)
6. OOB values are applied to `ZombieConfig`
7. Mini race: join → RUNNING → resolve → reset → rejoin
8. No City Highway fallback on failure (debug/headless)

## Commands

```bash
# All default certified maps (City Highway + Broken Bridge TEST)
godot --headless --path . -s res://scripts/debug/map_certification_test.gd

# Single map
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=quarantine_boulevard
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=broken_bridge_pass

# Certification tier (map selection + full certification)
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=certification
```

## Promotion requirements

Before promoting a map from testing → playable:

1. Pass `map_certification_test.gd`
2. Pass `void_oob_authority_test.gd` if elevated/bridge layout
3. Pass `race_finish_contract_test.gd`
4. Pass `broken_bridge_real_gameplay_test.gd --zombies=5 --skip-stress` (bridge maps)
5. Add to `MapCertification.DEFAULT_CERTIFIED_MAP_IDS` when it becomes a required gate map

## What Cursor/Codex must not bypass

- Do not ignore `MAP LOAD FAILED` errors in headless output
- Do not treat a failed map load as success if City Highway appears in logs
- Do not disable certification guards to "make tests green"
- Do not add silent fallback in debug/test paths
- Run `--tier=certification` before merging map controller or map content changes

## Fallback behavior

| Context | Invalid map load |
|---------|------------------|
| **Debug / headless** | Fails loudly. No City Highway substitution. |
| **Release export** | May fall back to City Highway with `push_warning` (see `RaceMapController._fail_map_load`). |

Release fallback exists only in non-debug, non-headless builds inside `RaceMapController._fail_map_load` and `_fallback_prototype_load_to_city_highway`.
