# Map Kit Pipeline

This document describes the asset-first map construction system for Zombie Horde.

## Golden rule

**Visual layer and gameplay layer are always separate.**

| Layer | Purpose | Technology |
|-------|---------|------------|
| Visual | What the camera sees | GLTF kit assets, dressing, water/void |
| Gameplay | What zombies use | Invisible collision, spawn/goal markers, hazard/OOB zones |

The visual layer may look broken, elevated, or uneven. The gameplay layer must stay simple, stable, and predictable.

Never rely on imported GLTF collision for zombie pathing unless an asset is explicitly marked safe.

## Playable roster

Only maps listed in `MapCatalog` with:

- `enabled: true`
- `status: "playable"`

appear in Streamer Settings → Level.

Currently only **City Highway** (`quarantine_boulevard`) is playable. Experimental maps remain in the repo but are disabled.

Saved map indices that point to disabled maps fall back to City Highway with a single warning.

## Asset registry

**File:** `scripts/maps/map_asset_registry.gd`  
**Class:** `MapAssetRegistry`

Canonical inventory of Lego pieces. Does not build maps.

Each entry includes:

- `id`, `display_name`, `scene_path`
- `category`, `footprint`, `tags`
- `collision_policy` (`visual_only`, `visual_with_sanitized_collision`, etc.)

### Adding a new asset

1. Add a row to `ASSETS` in `map_asset_registry.gd`
2. Set `collision_policy` to `visual_only` unless proven safe
3. Run Map Lab or call `MapAssetRegistry.print_asset_report()`

Missing assets log a warning and are skipped — they do not crash gameplay.

## Blueprint format

**File:** `scripts/maps/map_blueprint.gd`  
**Class:** `MapBlueprint`

Grid-based layout description:

- **Z** = forward (spawn → goal)
- **X** = left/right
- **Y** = height (usually 0)

Default tile size: **8 meters**.

### Cell vocabulary

`VOID`, `SAFE_ROAD`, `ROAD`, `CRACK_ROAD`, `BROKEN_EDGE`, `GAP_VISUAL`, `LEFT_RAIL`, `RIGHT_RAIL`, `CONE`, `BARRIER`, `DEBRIS`, `LIGHT`, `CONTAINER`, `HAZARD`, `SPAWN`, `GOAL`

Mark safe route cells with `safe_path: true` or type `SAFE_ROAD` / `SPAWN` / `GOAL`.

### Authoring status

| Status | Meaning |
|--------|---------|
| `lab_only` | Map Lab only |
| `prototype` | Experimental, disabled from roster |
| `validated` | Passed review, not yet playable |
| `playable` | May appear in roster if `enabled_for_selection` |
| `disabled` | Archived / off |

## Builder

**File:** `scripts/maps/map_kit_builder.gd`  
**Class:** `MapKitBuilder`

Builds this hierarchy:

```
MapRoot
├── VisualLayer
├── GameplayLayer
│   ├── SafeFloor
│   ├── HazardZones
│   ├── OOBZones
│   ├── SpawnZone
│   └── GoalZone
└── DebugLayer
```

- `build_from_blueprint(blueprint, parent)` — full build
- Visual instances are sanitized (collision stripped) by default
- GameplayLayer is never sanitized

## Validator

**File:** `scripts/maps/map_validator.gd`  
**Class:** `MapValidator`

Checks blueprint data and optional generated scene nodes.

A map must pass validation before promotion to playable.

```gdscript
var result = MapValidator.validate_blueprint(blueprint)
MapValidator.print_validation_report(result)
```

## Map Lab

**Scene:** `scenes/maps/map_lab.tscn`  
**Script:** `scripts/maps/map_lab.gd`

Internal sandbox. Does not affect saved map or playable roster.

### Inspector

- `blueprint_id` — default `bridge_lab_test`
- `debug_visible`, `show_safe_floor`, `show_hazards`
- `rebuild_on_ready`

### Shortcuts

| Key | Action |
|-----|--------|
| R | Rebuild blueprint |
| D | Toggle debug layer |
| H | Toggle hazard preview (rebuild) |
| F | Toggle safe floor preview (rebuild) |

### How to test in Godot

1. Open `scenes/maps/map_lab.tscn`
2. Press F6 (Run Current Scene)
3. Confirm bridge test builds with no red errors in Output
4. Press D / F / H to inspect layers

## Lab blueprint

**File:** `scripts/maps/blueprints/bridge_lab_test.gd`

- `authoring_status = lab_only`
- `enabled_for_selection = false`
- Narrow 3-column broken bridge test with safe center path

## Promotion process

A lab map becomes playable only after:

1. Asset registry entries exist for all required assets
2. Blueprint passes `MapValidator`
3. Scene builds in Map Lab without errors
4. Gameplay layer has continuous safe floor + spawn/goal
5. City Highway still loads and plays
6. Startup has no red map errors
7. Manual review of camera readability
8. Set `authoring_status = playable` and `enabled = true` in `MapCatalog`

## Do-not-do rules

- Do not auto-enable experimental maps
- Do not use GLTF collision for zombie pathing by default
- Do not fill the entire play apron with road tiles
- Do not place props on the zombie route
- Do not use Godot boxes as primary visible art (debug/fallback only)
- Do not modify City Highway during experimental passes

## Legacy files

These remain for future re-enable but are **not** in the playable roster:

- `scripts/maps/race_map_kit.gd` — earlier procedural builder
- `scripts/maps/long_road_arena.gd`, `broken_bridge_arena.gd`
- `resources/maps/long_road.tres`, `broken_bridge.tres`, etc.

Re-enable by setting `enabled: true` and `status: "playable"` in `MapCatalog` after validation.
