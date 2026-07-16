# Map Naming And Loading

This is the canonical contract for every map Zombie Horde can play.

## One Map, One Home

For every map in `scripts/maps/map_catalog.gd`:

```
map_id == resources/maps/<map_id>.tres basename
       == scenes/maps/<map_id>.tscn basename
```

For kit maps, `map_id` must also equal the `layout_preset_id` on that scene's
`CoreRoad` and the key in `scripts/maps/map_kit_layout_presets.gd`.

The catalog is the only selection source. The definition resource is the only
data source. The definition's packed scene is the only scene source.

## Playable Map Order

| Settings index | Map ID | Display name | Scene type |
|---|---|---|---|
| 0 | `quarantine_boulevard` | City Highway | Hand-authored road scene |
| 1 | `broken_bridge_pass` | Broken Bridge | Kit map |
| 2 | `spiral_descent` | Straight Descent | Kit map |
| 3 | `true_spiral_ramp` | Square Spiral Ramp | Hand-authored ramp scene |

Source of truth: `scripts/maps/map_catalog.gd`.

Entries marked `enabled=false`, `status=disabled` are stored authoring assets.
They do not appear in settings and the game loader refuses to instantiate them.

## Loading Contract

All playable maps use exactly one API:

```gdscript
RaceMapController.set_active_map_by_id(map_id)
```

The controller resolves the ID through `MapCatalog`, loads
`resources/maps/<map_id>.tres`, then instantiates the definition's scene. A
load failure is reported loudly. It never replaces the requested map with City
Highway or keeps the prior map in place.

## IDs And Display Names

Use IDs in code, tests, save data, and bug reports. Display names are UI only.

| ID | Display name |
|---|---|
| `quarantine_boulevard` | City Highway |
| `broken_bridge_pass` | Broken Bridge |
| `spiral_descent` | Straight Descent |
| `true_spiral_ramp` | Square Spiral Ramp |

Do not reintroduce these retired IDs:

- `broken_bridge_candidate` -> `broken_bridge_pass`
- `city_highway` -> `quarantine_boulevard`
- `broken_bridge` -> `broken_bridge_pass`

## Adding A Map

1. Choose a stable ID.
2. Create `resources/maps/<map_id>.tres` and `scenes/maps/<map_id>.tscn`.
3. For kit maps, add a matching layout preset and set `CoreRoad.layout_preset_id`.
4. Add one disabled catalog entry with the matching resource and scene paths.
5. Pass certification.
6. Change only that entry to `enabled=true`, `status=playable`.
7. Run smoke and certification before merging.

## Verification

```bash
bash scripts/debug/run_tests.sh smoke
bash scripts/debug/run_tests.sh certification
```

`map_selection_test.gd` loads every playable catalog map through the real
controller and verifies the resulting scene identity.

## Related Docs

- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)
- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md)
- [AGENTS.md](../AGENTS.md)
