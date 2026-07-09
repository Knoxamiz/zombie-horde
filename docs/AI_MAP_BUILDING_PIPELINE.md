# AI Map Building Pipeline

Controlled map assembly for Cursor/Codex. AI must **not** hand-author full Godot race scenes. Use approved assets, segment grammar, blueprints, builder, and validator — then promote through certification.

Related:

- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)
- [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md)
- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md)
- [MAP_KIT_PIPELINE.md](MAP_KIT_PIPELINE.md) — existing grid `MapBlueprint` / `MapKitBuilder` path

---

## Pipeline overview

```
MapAssetLibrary  →  approved reusable parts (visual + metadata)
MapSegmentDefinition  →  segment grammar (length, assets, difficulty)
AIMapBlueprint  →  map_id + segment_sequence + flags
AIMapBlueprintBuilder  →  VisualLayer + GameplayLayer prototype scene
AIMapBlueprintValidator  →  blueprint + scene contract checks
RaceMapDefinition  →  spawn/goal/OOB/camera values (from builder preview)
MapCertification  →  required before MapCatalog playable promotion
```

**Finish authority:** `World/StreamerBase` (`StreamerBaseGoal`) only.  
**Fall/OOB authority:** `Zombie._check_out_of_bounds()` + `RaceMapDefinition` / `ZombieConfig`.  
**Never:** `GoalCatch`, authoritative `bridge_void_kill_zone`, scene `Camera3D.current`.

---

## How AI should build maps

1. **Audit assets** — `MapAssetLibrary.print_audit_report()` or read `get_audit_report()`.
2. **Pick segment sequence** — must start with one `start` segment and end with one `finish` segment.
3. **Create `AIMapBlueprint`** — set `deck_y`, `target_length`, flags (`water_enabled`, `fall_enabled`, etc.).
4. **Validate blueprint** — `AIMapBlueprintValidator.validate_blueprint(blueprint)`.
5. **Build prototype only** — `AIMapBlueprintBuilder.build_prototype(parent, blueprint)`.
6. **Validate scene** — `AIMapBlueprintValidator.validate_generated_scene(map_root, blueprint, definition)`.
7. **Preview definition** — `builder.build_race_map_definition(blueprint)` for spawn/goal/OOB values.
8. **Certify before playable** — see [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md). Do not add to `MapCatalog` dropdown until certified.

---

## Approved asset categories

| Category | Purpose |
|----------|---------|
| `road` | Street tiles, cracks |
| `bridge` | Deck plates, safe floor collision |
| `ramp` | Procedural ramp boxes (no GLTF yet) |
| `gap` / `drop` | Visual void lips; falls use OOB min-Y |
| `rail` / `barrier` | Edge guides (visual; sanitized collision) |
| `support` | Pillars (placeholder cinder block) |
| `water` | Void visuals only |
| `hazard` | Warning markers — not kill volumes |
| `moving_obstacle` | Slot markers for future MapLab movers |
| `decoration` | Cones, lights, containers |
| `spawn` / `finish` | Visual markers only |

Registry: `scripts/maps/map_asset_library.gd`

---

## Segment grammar

Segment types (`MapSegmentDefinition`):

`start`, `straight`, `ramp_up`, `ramp_down`, `bridge`, `narrow_bridge`, `gap`, `drop`, `split_lane`, `merge_lane`, `moving_block_lane`, `hazard_lane`, `finish`

Rules:

- Sequence must contain **exactly one** `start` and **one** `finish`.
- `start` must be first; `finish` must be last.
- Each segment lists `required_assets` that must exist in `MapAssetLibrary`.
- `gap` / `drop` may use `fall_enabled` on the blueprint; set `out_of_bounds_min_y` below deck.
- `moving_block_lane` requires `moving_obstacles_enabled` on blueprint (prototype slots only today).

---

## Blueprint example

`example_bridge_segments_test` (non-playable, not in map dropdown):

```gdscript
var blueprint := ExampleBridgeSegmentsTestBlueprint.create()
# segment_sequence:
# seg_start_8 → seg_straight_8 → seg_gap_8 → seg_straight_8 → seg_finish_8
```

Factory: `scripts/maps/blueprints/example_bridge_segments_test.gd`

---

## Rules for drops / falls

- Visual gap/drop assets do **not** kill zombies.
- Enable `fall_enabled` on blueprint; builder sets `out_of_bounds_min_y` below `deck_y`.
- Safe floor plates may narrow on `gap` / `narrow_bridge` segments but must remain continuous enough to certify later.
- Do not add `bridge_void_kill_zone` or monitoring `Area3D` kill volumes.

---

## Rules for moving blocks

- Use `moving_block_lane` segment + `moving_block_slot` asset only in prototype/test maps.
- Movers are **not** wired to gameplay in this pass; MapLab simulation is the future hook.
- Do not alter zombie movement or round lifecycle for obstacle motion.

---

## Rules for rails / barriers

- GLTF barriers/rails are **visual only** (collision sanitized at instantiate).
- Gameplay walk surface = `safe_floor_plate` in `GameplayLayer/SafeFloor`.
- Do not block the center safe lane with barrier collision.

---

## What AI must never do

| Banned | Why |
|--------|-----|
| Hand-build full `RoadArena` scenes | Broken collision, duplicate finish, bad cameras |
| Add `GoalCatch` or second finish trigger | PR #39 single finish contract |
| Authoritative void kill zones | PR #40 OOB authority in `Zombie` |
| `Camera3D.current = true` on map scenes | Spectator camera owns race view |
| Promote to `MapCatalog` playable without certification | MAP_CERTIFICATION gate |
| Change zombie movement / round lifecycle in map tooling | Protected systems |
| Patch `zombie.gd` for map-specific hacks | Use `RaceMapDefinition` fields |

---

## Promotion path

| Stage | `authoring_status` / catalog | Action |
|-------|------------------------------|--------|
| Prototype | `AIMapBlueprint.STATUS_PROTOTYPE` | Build + validate only |
| Test | `STATUS_TEST`, `enabled_for_testing` if catalog entry added | Lab / headless prototype load |
| Certified | Pass `map_certification_test.gd` | Add to `DEFAULT_CERTIFIED_MAP_IDS` when required |
| Playable | `MapCatalog` `enabled=true`, `status=playable` | Settings dropdown + production |

`example_bridge_segments_test` stays at **test/prototype** — do not promote.

---

## Commands

```bash
# Pipeline unit test (not in smoke tier)
godot --headless --path . -s res://scripts/debug/ai_map_pipeline_test.gd

# Regression — must still pass after map pipeline work
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
```

---

## What's missing before rich AI maps

- Dedicated ramp / bridge deck GLTF modules with snap metadata
- Certified moving-obstacle prefabs wired to MapLab simulation
- Automatic `.tscn` + `.tres` export from builder (manual hook-up still required)
- Segment catalog expansion (curves, multi-lane highway, indoor modules)
- Art-directed themes beyond kit placeholders
- Integration test loading AI prototype into `RaceMapController` (future; not required for this pass)
