# Map naming reference

Canonical rules for map IDs, files, and folders. **Smoke tier enforces these** via `map_naming_audit_test.gd`.

## Golden rule

For every catalog map:

```
map_id == resources/maps/<map_id>.tres basename
        == scenes/maps/<map_id>.tscn basename
```

For **kit maps**, also:

```
map_id == layout_preset_id on scenes/maps/<map_id>.tscn CoreRoad node
       == MapKitLayoutPresets preset key
```

## IDs vs display names

| Kind | Example ID | Example display name |
|------|------------|----------------------|
| Default production map | `quarantine_boulevard` | City Highway |
| Signature kit map | `broken_bridge_pass` | Broken Bridge |
| AI-generated map | `ai_generated_fallthrough_lower_deck_test` | Fallthrough Lower Deck |

**Never use display names as map IDs in code, tests, or issues.**

## Banned retired IDs

Do not reintroduce:

- `broken_bridge_candidate` → use `broken_bridge_pass`
- `city_highway` → use `quarantine_boulevard`
- `broken_bridge` (preset only) → use `broken_bridge_pass`

## Playable maps (8)

| Settings index | Map ID | Display name | Kit preset |
|----------------|--------|--------------|------------|
| 0 | `quarantine_boulevard` | City Highway | — (hand-authored scene) |
| 1 | `ai_generated_fallthrough_lower_deck_test` | Fallthrough Lower Deck | — (AI arena) |
| 2 | `broken_bridge_pass` | Broken Bridge | `broken_bridge_pass` |
| 3 | `mine_alley` | Mine Alley | `mine_alley` |
| 4 | `cone_slalom` | Cone Slalom | `cone_slalom` |
| 5 | `vehicle_yard` | Vehicle Yard | `vehicle_yard` |
| 6 | `defender_gauntlet` | Defender Gauntlet | `defender_gauntlet` |
| 7 | `boost_rush` | Boost Rush | `boost_rush` |

Source of truth: `scripts/maps/map_catalog.gd`

## Loading maps in code

| Map status | API |
|------------|-----|
| Playable (`enabled=true`, `status=playable`) | `RaceMapController.set_active_map_by_id(map_id)` |
| Prototype test (`enabled=false`, `status=prototype`) | `RaceMapController.load_prototype_map_for_test(map_id)` |

Constants: `scripts/maps/map_naming.gd`

## Adding a new kit map

1. Add preset to `scripts/maps/map_kit_layout_presets.gd` — preset key **must equal** planned map ID
2. Create `resources/maps/<map_id>.tres` and `scenes/maps/<map_id>.tscn`
3. Set `layout_preset_id = "<map_id>"` on `CoreRoad` in the scene
4. Add catalog entry in `scripts/maps/map_catalog.gd` with matching paths and `layout_preset_id`
5. Run `bash scripts/debug/run_tests.sh smoke` — `map_naming_audit_test` must pass

## Validation

```bash
bash scripts/debug/run_godot.sh test smoke   # includes map_naming_audit_test
godot --headless --path . -s res://scripts/debug/map_naming_audit_test.gd
```

## Related docs

- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)
- [MAP_KIT_PIPELINE.md](MAP_KIT_PIPELINE.md)
- [AGENTS.md](../AGENTS.md)
