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

```
MapAssetLibrary  →  approved reusable parts (visual + metadata)
MapSegmentDefinition  →  segment grammar (length, assets, difficulty)
AIMapBlueprint  →  map_id + segment_sequence + flags
AIMapBlueprintBuilder  →  VisualLayer + GameplayLayer prototype scene
AIMapRouteLayout  →  shared spawn/goal/OOB Z alignment
AIMapBlueprintValidator  →  blueprint + scene + geometry contract checks
AIMapBlueprintExporter  →  RaceMapDefinition .tres (prototype only)
AIGeneratedMapArena  →  RoadArena/CoreRoad runtime build wrapper
RaceMapController.load_prototype_map_for_test  →  prototype load path
MapCertification / ai_generated_map_certification_test  →  pass/fail gate
```

**Finish authority:** `World/StreamerBase` (`StreamerBaseGoal`) only.  
**Fall/OOB authority:** `Zombie._check_out_of_bounds()` + `RaceMapDefinition` / `ZombieConfig`.  
**Never:** `GoalCatch`, authoritative `bridge_void_kill_zone`, scene `Camera3D.current`.

---

## Minimum map factory loop (closed)

Prototype maps now follow this loop:

```
AIMapBlueprint (phase1_bridge_ramp_test)
  → AIMapBlueprintBuilder.build_prototype()
  → AIMapBlueprintExporter.export_phase1_bridge_ramp_prototype()
  → resources/maps/ai_generated_phase1_bridge_ramp_test.tres
  → scenes/maps/ai_generated_phase1_bridge_ramp_test.tscn
  → MapCatalog id: ai_generated_phase1_bridge_ramp_test (prototype only)
  → RaceMapController.load_prototype_map_for_test()
  → ai_generated_map_certification_test.gd
```

**Canonical first example:** `phase1_bridge_ramp_test` → exported as `ai_generated_phase1_bridge_ramp_test`.

Commands:

```bash
# Regenerate exported RaceMapDefinition from blueprint grammar
godot --headless --path . -s res://scripts/debug/export_ai_generated_prototype.gd

# Pipeline unit tests (layout alignment + negative cases)
godot --headless --path . -s res://scripts/debug/ai_map_pipeline_test.gd

# Generated prototype certification (prototype loader + mini race)
godot --headless --path . -s res://scripts/debug/ai_generated_map_certification_test.gd
```

### Current limitations (prototype-only)

| Limitation | Status |
|------------|--------|
| **No true branch pathfinding** | Phase 4 splits are offset floors + visuals only |
| **Moving obstacles prototype-safe** | `MapMovingObstacle` blocks kinematically; no live `BounceObstacle` / `GameEvents` hazard wiring yet |
| **Flat ramp collision** | `height_delta` is visual deck stepping; safe floors stay flat |
| **Generated maps not playable** | `enabled=false`, `status=prototype` — not in production dropdown |
| **Phase 2–4 are advanced** | Start with Phase 1 segments; add fall/obstacle/split packs only after export loop passes |

Phase 2–4 packs remain available in grammar/tests but are **advanced/later** for new AI-authored maps. Use Phase 1 for first prototypes.

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

## Phase 2 asset pack (drops, falls, gaps, water/void)

**Scope:** vertical danger — gaps, side drops, elevated paths, water/void visuals. No moving obstacles.

### Phase 2 asset categories

| Category | Phase 2 ids (examples) |
|----------|------------------------|
| `gap` | `phase2_gap_edge_left`, `phase2_gap_edge_right`, `phase2_broken_bridge_gap` |
| `drop` | `phase2_drop_off_section`, `phase2_side_fall_opening`, `phase2_cracked_road_edge` |
| `bridge` | `phase2_elevated_bridge_deck`, `phase2_safe_floor_plate` |
| `water` | `phase2_water_river_plane`, `phase2_void_floor_visual`, `phase2_lower_river_catch` |
| `hazard` | `phase2_warning_stripes` |
| `rail` | `phase2_broken_guardrail`, `phase2_missing_rail_section` |
| `support` | `phase2_support_pillar` |
| `decoration` | `phase2_deco_debris`, `phase2_edge_cone`, `phase2_edge_light` |

List: `MapAssetLibrary.get_phase2_asset_ids()`

Each asset entry includes: `asset_id`, `display_name`, `category`, `scene_path`, dimensions, offsets, `deck_y_offset`, `fall_enabled`, `collision_mode` (`visual_only` or `gameplay_collision`), `notes`.

### Phase 2 approved segments

| Segment id | Type | Length | fall_risk |
|------------|------|--------|-----------|
| `small_center_gap` | small_center_gap | 8m | 2 |
| `left_side_drop` | left_side_drop | 8m | 2 |
| `right_side_drop` | right_side_drop | 8m | 2 |
| `double_side_drop` | double_side_drop | 8m | 3 |
| `narrow_no_rails_bridge` | narrow_no_rails_bridge | 8m | 2 |
| `broken_bridge_gap` | broken_bridge_gap | 8m | 3 |
| `elevated_straight` | elevated | 8m | 1 |
| `elevated_ramp_drop` | elevated_ramp_drop | 8m (−0.8m) | 2 |
| `cracked_edge_lane` | cracked_edge_lane | 8m | 1 |
| `water_underpass` | water_underpass | 8m | 1 |
| `recovery_straight_after_gap` | recovery | 8m | 0 |

List: `MapSegmentDefinition.get_phase2_segment_ids()`

Each segment defines: `length`, `width`, `height_delta`, `safe_lane_count`, `allows_fall_edges`, `fall_risk_level`, `required_assets`, `optional_assets`, `recommended_oob_min_y`, `recommended_camera_padding`, `difficulty`, `notes`.

### Phase 2 blueprint example

`phase2_drop_gap_test` (non-playable, not in map dropdown):

```gdscript
var blueprint := Phase2DropGapTestBlueprint.create()
# start_straight → straight_road_medium → elevated_straight → left_side_drop
# → broken_bridge_gap → recovery_straight_after_gap → double_side_drop → finish_straight
```

Factory: `scripts/maps/blueprints/phase2_drop_gap_test.gd`

### Rules for elevated maps (Phase 2)

- `deck_y` must be above `water_void_y` (`deck_y - 4.0` when `water_enabled`).
- `out_of_bounds_min_y` must be below `water_void_y` on elevated routes.
- Use `elevated_straight` or `water_underpass` for elevated deck sections.
- `recommended_camera_padding` on segments hints camera framing needs; validator warns if camera is too low.
- Falls use `Zombie._check_out_of_bounds` only — never authoritative void kill scripts.

### Rules for gaps (Phase 2)

- Gap segments (`small_center_gap`, `broken_bridge_gap`) require `fall_enabled = true`.
- Every gap must have a **valid safe floor segment before it** (not another gap).
- Every gap must be followed by `recovery_straight_after_gap` or a full-width safe straight/bridge/finish.
- `safe_floor_width_ratio` on gap segments must stay ≤ 0.75 — no hidden giant floor beyond visible road.
- Spawn and finish **cannot** be placed inside gap segments.

### Rules for side drops (Phase 2)

- `left_side_drop`, `right_side_drop`, `double_side_drop` keep a center safe lane.
- `out_of_bounds_min_y` must be below `deck_y` so zombies at deck height do not die from side falls.
- Optional visual helpers (`phase2_broken_guardrail`, `phase2_edge_cone`, `phase2_warning_stripes`) are **visual only**.

### Rules for water/void visuals (Phase 2)

- `phase2_water_river_plane`, `phase2_void_floor_visual`, `phase2_lower_river_catch` are **visual only**.
- Never attach `bridge_void_kill_zone` or monitoring void-kill `Area3D` nodes.
- Water sits below deck; death happens only when zombie Y drops below `out_of_bounds_min_y`.

### Bad examples AI must avoid

| Bad pattern | Why |
|-------------|-----|
| Gap → gap with no recovery between | No safe landing after fall |
| `broken_bridge_gap` → `finish_straight` (no recovery) | Missing recovery floor |
| `start_straight` replaced by `broken_bridge_gap` | Spawn inside gap |
| `finish_straight` replaced by gap segment | Finish inside gap |
| `fall_enabled = false` with drop/gap segments | No OOB min-Y for falls |
| `safe_floor_width_ratio > 0.75` on gaps | Hidden floor beyond visible road |
| `GoalCatch` or void-kill `Area3D` | Competes with protected OOB/finish authority |
| Promoting `phase2_drop_gap_test` to playable | Requires certification gate |

---

## Phase 3 asset pack (moving obstacles)

**Scope:** reusable moving obstacle modules — blocks, pushers, crushers, gates, platforms. No new playable maps.

### Obstacle audit (existing repo)

| Exists | Path / notes |
|--------|----------------|
| `BounceObstacle` | `scripts/hazards/bounce_obstacle.gd` — approved hazard path via `GameEvents.obstacle_triggered` |
| `HazardManager` road obstacles | `scripts/hazards/hazard_manager.gd` — runtime placement, not map-embedded |
| `MapLabSimMover` | `scripts/maps/map_lab_sim_mover.gd` — MapLab simulation probes only |
| Kit meshes | `Container_Red`, `Container_Green`, `PlasticBarrier`, `TrafficBarrier_*`, `Pallet`, `Pipes`, `CinderBlock` |
| `moving_block_slot` | Phase 0 placeholder in `MapAssetLibrary` — superseded by `phase3_*` assets |
| **Missing** | Dedicated swinging arm GLTF, certified crusher prefab scenes, tween library for map obstacles, production hazard wiring from AI builder |

### Phase 3 moving obstacle assets

List: `MapAssetLibrary.get_phase3_asset_ids()` (18 `phase3_*` ids)

Categories: `moving_obstacle`, `pusher`, `crusher`, `rotating_arm`, `sliding_wall`, `timed_gate`, `moving_platform`, `blocker`, `warning_visual`, `decoration`

Each entry includes: `movement_type`, `movement_axis`, `movement_distance`, `cycle_time`, `phase_offset`, `collision_expectation`, `hazard_behavior`, `collision_mode`, `notes`.

### Movement controller

`scripts/maps/obstacles/map_moving_obstacle.gd` (`MapMovingObstacle` extends `AnimatableBody3D`):

- Supports `linear`, `ping_pong`, `rotation`
- Configurable axis, distance, cycle time, phase offset, pause at ends
- `reset_obstacle()` / `pause_obstacle()` for clean prototype resets
- **Kinematic collision only** — does not kill zombies or edit `zombie.gd`
- Damage/knockback must use existing paths (e.g. `BounceObstacle` + `GameEvents`)

### Phase 3 approved segments

| Segment id | Type |
|------------|------|
| `moving_block_lane` | moving_block_lane |
| `side_pusher_lane` | side_pusher_lane |
| `crusher_corridor` | crusher_corridor |
| `rotating_arm_bridge` | rotating_arm_bridge |
| `timed_gate_straight` | timed_gate_straight |
| `sliding_wall_lane` | sliding_wall_lane |
| `moving_platform_gap` | moving_platform_gap |
| `obstacle_slalom` | obstacle_slalom |
| `hazard_recovery_straight` | hazard_recovery |

List: `MapSegmentDefinition.get_phase3_segment_ids()`

### Phase 3 blueprint example

`phase3_moving_obstacle_test` (non-playable, not in map dropdown):

```gdscript
var blueprint := Phase3MovingObstacleTestBlueprint.create()
# start_straight → straight_road_medium → moving_block_lane → recovery_straight_after_gap
# → side_pusher_lane → timed_gate_straight → finish_straight
```

Factory: `scripts/maps/blueprints/phase3_moving_obstacle_test.gd`

### How AI should request a moving obstacle map

1. Pick segments from Phase 3 approved list; include Phase 1/2 straights/recovery as needed.
2. Set `moving_obstacles_enabled = true` and optional `obstacle_cycle_time` (1.5–12.0s).
3. Ensure each obstacle segment keeps `fallback_safe_lane = true` and `safe_lane_count >= 1`.
4. Follow obstacle segment with `hazard_recovery_straight` or `recovery_straight_after_gap` when needed.
5. Validate + build prototype only — do not add to `MapCatalog`.

### Allowed movement patterns

| Pattern | Use |
|---------|-----|
| `ping_pong` + `x` | Lane blockers, gates, pushers |
| `ping_pong` + `z` | Sliding walls along segment |
| `ping_pong` + `y` | Crushers, moving platforms |
| `rotation` + `y` | Rotating arms |
| `linear` | One-shot pushers (short travel) |

### Safe-lane rules

- Every moving obstacle segment must leave at least one passable route (`fallback_safe_lane_width >= 1.5m`).
- `cycle_time` must be 1.5–12.0 seconds so zombies can time crossings.
- `movement_distance` must stay inside segment bounds (≤ 45% of segment width/length on axis).
- `moving_platform_gap` requires recovery floor after (like gap segments).
- Crushers/pushers cannot be spawn or finish segments.

### Banned obstacle patterns

| Banned | Why |
|--------|-----|
| `fallback_safe_lane = false` | Blocks all lanes forever |
| `obstacle_cycle_time < 1.5` or `> 12` | Unfair or untestable timing |
| Obstacle `Area3D` void kill | Competes with OOB authority |
| `GoalCatch` on obstacle nodes | Competes with finish authority |
| `Camera3D.current` on obstacle scripts | Hijacks spectator camera |
| Direct `zombie.gd` edits for obstacle motion | Protected system |
| Authoritative kill in `MapMovingObstacle` | Must use existing hazard events |

---

## Phase 4 asset pack (split lanes, alternate routes, merge lanes)

**Scope:** route variety via split/merge shapes — visual lane offsets and branch floors. **No zombie pathfinding changes.**

### Route assumptions audit (current engine — unchanged)

| System | Assumption | Impact on splits |
|--------|------------|------------------|
| **Race axis** | Single spawn→goal Z axis (`zombie._get_race_forward`) | Branches are lateral offsets, not separate paths |
| **Progress** | Dot product along spawn→goal vector (`zombie.get_progress`) | Shortcut length does not change progress metric |
| **OOB bounds** | Axis-aligned box: `abs(x) <= out_of_bounds_half_width`, Z min/max | Branch offsets must stay inside OOB half-width |
| **Lane width** | `lane_half_width` soft-clamps lateral position | All branches share one lane clamp — no per-branch AI |
| **Camera** | `RaceMapController.compute_race_camera_view_for_definition` uses spawn/goal Z span + `lane_half_width + 6` side offset | Wide splits need larger `route_half_width` / OOB |
| **Zombie pathing** | Forward velocity + lateral lane offset toward goal side vector | No branch selection — zombies do not "choose" shortcuts |
| **Finish/base** | `goal_position.z` / `base_position.z` aligned on center axis | Merge returns to center lane before finish |

**Limitation:** Phase 4 splits are **forward-compatible route shapes** (visual + offset safe floors), not true alternate-path pathfinding. Document this when authoring risk/reward maps.

### Phase 4 assets (15 `phase4_*` ids)

List: `MapAssetLibrary.get_phase4_asset_ids()`

Categories: `split_lane`, `merge_lane`, `alternate_route`, `shortcut`, `safe_route`, `divider`, `route_marker`, `bridge`, `ramp`, `rail`, `decoration`

Each entry includes: `branch_offsets`, `merge_offset`, `collision_expectation`, `collision_mode`, `notes`.

### Phase 4 approved segments

| Segment id | Type |
|------------|------|
| `split_two_lane` | split_two_lane |
| `merge_two_lane` | merge_two_lane |
| `risk_reward_split` | risk_reward_split |
| `narrow_shortcut` | narrow_shortcut |
| `wide_safe_route` | wide_safe_route |
| `high_low_split` | high_low_split |
| `side_bridge_route` | side_bridge_route |
| `obstacle_route_choice` | obstacle_route_choice |
| `split_gap_choice` | split_gap_choice |
| `merge_recovery_straight` | merge_recovery |

List: `MapSegmentDefinition.get_phase4_segment_ids()`

### Phase 4 blueprint example

`phase4_split_lane_test` (non-playable):

```gdscript
var blueprint := Phase4SplitLaneTestBlueprint.create()
# start_straight → straight_road_medium → split_two_lane → narrow_shortcut
# → wide_safe_route → merge_two_lane → moving_block_lane → finish_straight
```

Factory: `scripts/maps/blueprints/phase4_split_lane_test.gd`

### Allowed split route patterns

| Pattern | Sequence shape |
|---------|----------------|
| Simple fork | `split_two_lane` → branch segment(s) → `merge_two_lane` |
| Risk/reward | `risk_reward_split` → `narrow_shortcut` → `wide_safe_route` → merge |
| High/low | `high_low_split` → branch ramps → merge |
| Side bridge | `side_bridge_route` between split and merge |
| Recovery | `merge_two_lane` → `merge_recovery_straight` (recommended) |

### Risk/reward route rules

- At least one **low-risk** branch (`wide_safe_route` or `route_risk_level <= 0`) per split section.
- High-risk shortcuts (`narrow_shortcut`) should be shorter/narrower visually.
- `risk_reward_split` should include `phase4_route_sign_arrow` or similar marker.
- `split_gap_choice` requires `fall_enabled` (gap on risky branch).

### What AI must NOT do with split lanes

| Banned | Why |
|--------|-----|
| Split without merge before finish | Unclosed fork |
| Spawn/finish on split/merge/branch segments | Invalid lifecycle placement |
| Branch segment without `safe_floor_plate` | No walk surface |
| Branch offsets outside OOB half-width | Silent lateral kills |
| Hidden branch floor wider than visible route | Certification trap |
| Assume zombies pick shortcuts | No pathfinding — forward track only |
| Edit `zombie.gd` for map-specific routing | Protected system |
| Promote `phase4_split_lane_test` to playable | Requires certification |

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

## Canonical blueprint example (start here)

**Phase 1 generated prototype** — `phase1_bridge_ramp_test` (exported as `ai_generated_phase1_bridge_ramp_test`):

```gdscript
var blueprint := Phase1BridgeRampTestBlueprint.create()
# start_straight → straight_road_medium → ramp_up → bridge_straight
# → small_gap → straight_road_short → ramp_down → finish_straight
```

Factories:

- Blueprint grammar: `scripts/maps/blueprints/phase1_bridge_ramp_test.gd`
- Export: `scripts/maps/ai_map_blueprint_exporter.gd`
- Catalog id: `ai_generated_phase1_bridge_ramp_test` (prototype/test only)

Legacy `example_bridge_segments_test` (`seg_*` ids) is deprecated for new AI work — use Phase 1 ids only.

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

`example_bridge_segments_test` and `phase1_bridge_ramp_test` and `phase2_drop_gap_test` and `phase4_split_lane_test` stay at **test/prototype** — do not promote.

---

## Asset gaps before richer maps

- Dedicated ramp / bridge deck **GLTF** modules with snap metadata
- Curved road pieces and multi-lane highway segments
- Split lanes / merge lanes / curved highway segments
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
