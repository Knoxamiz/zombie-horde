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
| `ramp` | Procedural ramp surfaces (no GLTF yet) |
| `gap` / `drop` | Visual void lips; falls use OOB min-Y |
| `rail` / `barrier` | Edge guides (visual; sanitized collision) |
| `support` | Pillars / cinder blocks |
| `water` | Void visuals only |
| `decoration` | Cones, lights, barrels, pallets |
| `spawn` / `finish` | Visual markers only |

Registry: `scripts/maps/map_asset_library.gd`  
Phase 1 canonical ids use `phase1_*` prefix — see `MapAssetLibrary.get_phase1_asset_ids()`.

---

## Phase 1 asset pack (roads, bridges, ramps, rails)

**Scope:** foundational race pieces only — no moving obstacles.

### Phase 1 asset categories

| Category | Phase 1 ids (examples) |
|----------|------------------------|
| `road` | `phase1_road_straight_8`, `phase1_road_cracked_light`, `phase1_road_cracked_heavy` |
| `bridge` | `phase1_bridge_deck_8`, `phase1_safe_floor_plate` |
| `ramp` | `phase1_ramp_surface_8` |
| `rail` | `phase1_rail_traffic_a`, `phase1_rail_traffic_b` |
| `barrier` | `phase1_barrier_plastic` |
| `support` | `phase1_support_pillar`, `phase1_support_cinder` |
| `water` | `phase1_water_river`, `phase1_water_segment` |
| `gap` | `phase1_gap_void` |
| `drop` | `phase1_drop_lip`, `phase1_broken_edge_light`, `phase1_broken_edge_heavy` |
| `decoration` | `phase1_deco_cone`, `phase1_deco_light`, `phase1_deco_barrel`, `phase1_deco_pipes`, `phase1_deco_pallet` |
| `spawn` / `finish` | `phase1_spawn_marker`, `phase1_finish_marker` |

### Phase 1 approved segments

| Segment id | Type | Length |
|------------|------|--------|
| `start_straight` | start | 8m |
| `straight_road_short` | straight | 8m |
| `straight_road_medium` | straight | 16m |
| `straight_road_long` | straight | 24m |
| `bridge_straight` | bridge | 8m |
| `narrow_bridge` | narrow_bridge | 8m |
| `ramp_up` | ramp_up | 8m (+0.8m) |
| `ramp_down` | ramp_down | 8m (−0.8m) |
| `small_gap` | gap | 8m |
| `side_drop_edges` | side_drop | 8m |
| `finish_straight` | finish | 8m |

List: `MapSegmentDefinition.get_phase1_segment_ids()`

### Phase 1 blueprint example

`phase1_bridge_ramp_test` (non-playable, not in map dropdown):

```gdscript
var blueprint := Phase1BridgeRampTestBlueprint.create()
# start_straight → straight_road_medium → ramp_up → bridge_straight
# → small_gap → straight_road_short → ramp_down → finish_straight
```

Factory: `scripts/maps/blueprints/phase1_bridge_ramp_test.gd`

### How AI should request a new map (Phase 1)

1. Pick segments from the Phase 1 approved list only.
2. Set `deck_y`, `target_length`, `water_enabled`, `fall_enabled` (required when using gap/drop segments).
3. Build `AIMapBlueprint` with `segment_sequence` — one `start_*` first, one `finish_*` last.
4. Run `AIMapBlueprintValidator.validate_blueprint(blueprint)`.
5. Build prototype with `AIMapBlueprintBuilder.build_prototype(parent, blueprint)`.
6. Do **not** add to `MapCatalog` or promote without certification.

### Rules for ramps (Phase 1)

- Use `ramp_up` / `ramp_down` segments only for elevation changes.
- `ramp_up` must have positive `height_delta`; `ramp_down` must have negative.
- Do not change zombie movement — elevation is visual + safe-floor placement only.
- After a ramp sequence, bridge segments should follow at the new deck height.

### Rules for bridge rails / barriers (Phase 1)

- `bridge_straight` and `narrow_bridge` **must** include a rail or barrier asset.
- Rails/barriers are **visual only** (collision sanitized).
- Gameplay walk surface = `phase1_safe_floor_plate` under `GameplayLayer/SafeFloor`.

### Rules for drops / gaps (Phase 1)

- `small_gap` and `side_drop_edges` require `fall_enabled = true` on the blueprint.
- Visual void assets do **not** kill zombies — `out_of_bounds_min_y` handles falls.
- Never add authoritative void kill zones or `GoalCatch`.

---

## Segment grammar (all packs)

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

`example_bridge_segments_test` and `phase1_bridge_ramp_test` stay at **test/prototype** — do not promote.

---

## Asset gaps before richer maps

- Dedicated ramp / bridge deck **GLTF** modules with snap metadata
- Curved road pieces and multi-lane highway segments
- Certified moving-obstacle prefabs (Phase 2+)
- Automatic `.tscn` + `.tres` export from builder
- Art-directed themes beyond kit placeholders
- `RaceMapController` prototype loader integration

---

## Commands

```bash
# Pipeline unit test (not in smoke tier)
godot --headless --path . -s res://scripts/debug/ai_map_pipeline_test.gd

# Regression — must still pass after map pipeline work
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
```

---

## Legacy / pre-Phase-1 notes

Older `seg_*` segment ids and non-prefixed assets remain for backward compatibility with `example_bridge_segments_test`. New AI maps should prefer Phase 1 ids.
