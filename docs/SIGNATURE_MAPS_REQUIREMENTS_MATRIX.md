# Signature Maps — Requirements Matrix & Map Factory Gap List

Planning and audit document only. **No maps implemented. No gameplay changes.**

Sources:

- [SIGNATURE_MAPS_PLAN.md](SIGNATURE_MAPS_PLAN.md)
- [AI_MAP_BUILDING_PIPELINE.md](AI_MAP_BUILDING_PIPELINE.md)
- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)
- Current code: `MapAssetLibrary`, `MapSegmentDefinition`, `AIMapBlueprint`, `AIMapBlueprintBuilder`, `AIMapBlueprintValidator`

**Note:** `docs/PRODUCT_MISSION.md` does not exist. Mission alignment is taken from `SIGNATURE_MAPS_PLAN.md` and `AI_DEVELOPMENT_GUARDRAILS.md`: Zombie Horde is a **Twitch streamer engagement game**; maps are ride-shaped content, not the product.

---

## Readiness legend

| Rating | Meaning |
|--------|---------|
| **Yes** | System supports this today for in-memory prototype build + blueprint validation |
| **Partial** | Grammar/assets exist but export, geometry alignment, or runtime load is broken/incomplete |
| **No** | Blocked by missing system piece |

| Risk | Meaning |
|------|---------|
| **Low** | Validator + docs cover most AI mistakes |
| **Medium** | Build may succeed but race/certification will fail or feel wrong |
| **High** | Silent wrong output or protected-authority violation likely |

---

## Executive summary

| Map | Overall readiness | Build safely today? | Risk |
|-----|-------------------|---------------------|------|
| **The Drop Bridge** | **Partial** | In-memory prototype only — not race-safe | Medium |
| **The Crusher Hall** | **Partial** | In-memory prototype only — obstacles block, no hazard feel | Medium |
| **The Forked Gamble** | **No** | Blocked by export + spawn/goal + branch visuals | High |
| **The Long Fall Express** | **No** | Blocked by all shared gaps + length/camera stress | High |

**First prototype target:** **The Drop Bridge** (verified — lowest phase count, fall spectacle matches mission, closest to existing `phase2_drop_gap_test`).

---

## 1. Requirements matrix (per map)

### 1.1 The Drop Bridge

| Dimension | Requirement | Current support | Missing pieces | Risk |
|-----------|-------------|-----------------|----------------|------|
| **Segment types** | `start`, `straight`, `ramp_up`, `elevated`, `narrow_no_rails_bridge`, `left_side_drop`, `broken_bridge_gap`, `recovery`, `double_side_drop`, `finish` | **Yes** — all in `MapSegmentDefinition` Phase 1+2 | None for grammar | Low |
| **Asset categories** | `road`, `bridge`, `ramp`, `rail`, `gap`, `drop`, `water`, `hazard`, `support`, `decoration` | **Yes** — `phase1_*` + `phase2_*` registered | Cosmetic: dedicated broken parapet GLTF (procedural OK) | Low |
| **Validator rules** | `fall_enabled` with gaps/drops; gap recovery; hidden floor width; spawn/finish not in fall segments; elevated water clearance; no GoalCatch/void-kill/camera | **Yes** — `AIMapBlueprintValidator` Phase 2 rules | Spawn/goal Z vs route length assertion (**missing**) | Medium |
| **Certification checks** | `map_certification_test`, `void_oob_authority_test`, `race_finish_contract_test` | **No** — no export/load path for AI maps | Export pipeline + MapCatalog prototype entry | High |
| **Camera support** | Elevated framing via `RaceMapController.compute_race_camera_view_for_definition` + segment `recommended_camera_padding` | **Partial** — validator checks non-zero camera; warns on low height | Spawn/goal Z fix required for correct framing span | Medium |
| **OOB/fall support** | `fall_enabled`, `out_of_bounds_min_y` below deck/water, side-drop deck safety | **Yes** — blueprint + validator | Runtime apply depends on fixed `RaceMapDefinition` | Medium |
| **Moving obstacles** | None | **N/A** | — | — |
| **Split/merge** | None | **N/A** | — | — |
| **Performance target** | ~72–80 m, 10 segments, 15–30 viewers | **Yes** — low node count | — | Low |

**Route (planned):** `start_straight → straight_road_short → ramp_up → elevated_straight → narrow_no_rails_bridge → left_side_drop → broken_bridge_gap → recovery_straight_after_gap → double_side_drop → finish_straight`

---

### 1.2 The Crusher Hall

| Dimension | Requirement | Current support | Missing pieces | Risk |
|-----------|-------------|-----------------|----------------|------|
| **Segment types** | `start`, `straight`, `moving_block_lane`, `hazard_recovery`, `crusher_corridor`, `timed_gate_straight`, `side_pusher_lane`, `finish` | **Yes** — Phase 3 segments | None for grammar | Low |
| **Asset categories** | `road`, `bridge` (safe floor), `moving_obstacle`, `hazard`, `decoration` | **Yes** — `phase3_*` + safe floor | Dedicated crusher/arm GLTF (procedural placeholders OK) | Low |
| **Validator rules** | `moving_obstacles_enabled`; safe lane + fallback width; cycle time bounds; movement bounds; no crusher on spawn/finish; recovery after platform gaps | **Yes** — Phase 3 rules | — | Low |
| **Certification checks** | Scene contract + mini-race + no camera/finish hijack | **Partial** — rules exist; no AI map in catalog | Export + load path | Medium |
| **Camera support** | Standard lane framing (flat, short) | **Yes** | Spawn/goal Z fix | Low |
| **OOB/fall support** | Flat course, `fall_enabled = false` | **Yes** | — | Low |
| **Moving obstacles** | `MapMovingObstacle` kinematic block; cycle 3.5–4 s | **Partial** — motion + collision yes; **no** `BounceObstacle`/`GameEvents` damage | Hazard gameplay wiring (deferred) | Medium |
| **Split/merge** | None | **N/A** | — | — |
| **Performance target** | ~48–56 m, 8 segments, 10–25 viewers, fast rematch | **Yes** | — | Low |

**Route (planned):** `start_straight → straight_road_short → moving_block_lane → hazard_recovery_straight → crusher_corridor → timed_gate_straight → side_pusher_lane → finish_straight`

---

### 1.3 The Forked Gamble

| Dimension | Requirement | Current support | Missing pieces | Risk |
|-----------|-------------|-----------------|----------------|------|
| **Segment types** | `start`, `straight`, `risk_reward_split`, `split_two_lane`, `narrow_shortcut`, `wide_safe_route`, `merge_two_lane`, `merge_recovery`, `broken_bridge_gap`, `recovery`, `finish` | **Yes** — Phase 4 + Phase 2 grammar | — | Low |
| **Asset categories** | `road`, `bridge`, `gap`, `water`, `rail`, `barrier`, `route_marker`, split/merge pieces | **Yes** — `phase4_*` registered | Branch **visual** placement at `branch_offsets` (builder floors only) | High |
| **Validator rules** | Split/merge balance; low-risk branch; branch safe floors; hidden branch floors; wide OOB; spawn/finish not on split/branch | **Yes** — Phase 4 rules | — | Medium |
| **Certification checks** | Wide-route camera; hidden floor audit; finish contract | **No** | Export + spawn/goal + branch visual fix | High |
| **Camera support** | Wide route (`route_half_width ≈ 7`); split camera warnings | **Partial** — validator warns tight camera | Correct spawn/goal span for wide Z extent | High |
| **OOB/fall support** | Post-merge gap: `fall_enabled`, recovery before finish | **Yes** — validator | — | Medium |
| **Moving obstacles** | Optional (not in v1 plan) | **N/A** | — | — |
| **Split/merge** | Offset safe floors; sequential branch segments | **Partial** — floors offset; **no** zombie pathfinding; visuals centered | Branch visual builder; document illusion limits | **High** |
| **Performance target** | ~88–96 m, 11 segments, 25–50 viewers | **Yes** — moderate node count | — | Low |

**Route (planned):** `start_straight → straight_road_medium → risk_reward_split → split_two_lane → narrow_shortcut → wide_safe_route → merge_two_lane → merge_recovery_straight → broken_bridge_gap → recovery_straight_after_gap → finish_straight`

---

### 1.4 The Long Fall Express

| Dimension | Requirement | Current support | Missing pieces | Risk |
|-----------|-------------|-----------------|----------------|------|
| **Segment types** | `start`, `straight` (short/medium/**long**), `ramp_up`, `ramp_down`, `elevated`, `left_side_drop`, `elevated_ramp_drop`, `recovery`, `cracked_edge_lane`, `broken_bridge_gap`, `bridge`, `water_underpass`, `finish` | **Yes** — Phase 1+2 | — | Low |
| **Asset categories** | Full Phase 1+2 set; long straights; water underpass | **Yes** | Finish “grandstand” decoration (optional) | Low |
| **Validator rules** | All Phase 2 gap/drop rules; cumulative height warning; chapter recoveries | **Partial** — height warning only (not hard fail) | Optional: max segment count / length policy rule | Medium |
| **Certification checks** | Full suite + large lobby soak (50–100) | **No** | Export + spawn/goal + performance validation | High |
| **Camera support** | Long Z span; elevated padding | **Partial** — padding hints exist | Spawn/goal Z fix critical at 160 m | High |
| **OOB/fall support** | Sustained fall risk; `deck_y` start high, net descent | **Yes** — grammar | Flat ramp collision vs visual descent | Medium |
| **Moving obstacles** | None in v1 | **N/A** | — | — |
| **Split/merge** | None (single lane for readability) | **N/A** | — | — |
| **Performance target** | ~128–168 m, 16–17 segments, 50–100 viewers | **Unverified** — many safe-floor plates | Scene node budget test; soak test | **High** |

**Route (planned):** `start_straight → straight_road_long → ramp_up → elevated_straight → straight_road_medium → left_side_drop → elevated_ramp_drop → recovery_straight_after_gap → straight_road_medium → cracked_edge_lane → broken_bridge_gap → recovery_straight_after_gap → ramp_down → bridge_straight → straight_road_long → water_underpass → finish_straight`

---

## 2. Per-map system comparison

### The Drop Bridge

| Question | Answer |
|----------|--------|
| **Build safely today?** | **Partially** — blueprint validates; in-memory scene builds; **not safe to race** until spawn/goal Z + export fixed |
| **Limitations if yes** | Ramp collision flat; builder returns scene on failed scene validation; missing assets skipped silently |
| **Blocks if no** | Export to `RoadArena` `.tscn` + `.tres`; spawn/goal Z alignment; prototype `MapCatalog` + loader |
| **AI likely messes up** | `fall_enabled = false` with gaps; gap without recovery; legacy `seg_*` ids; `safe_floor_width_ratio` too high |
| **Validator prevents** | `_validate_gap_fall_settings`, `_validate_gap_recovery_floors`, `_validate_hidden_floor_width`, `_validate_spawn_finish_not_in_fall_segments` |
| **Prototype-only** | Entire map until certification passes |
| **Defer** | Sloped ramp collision; themes; playable promotion |

### The Crusher Hall

| Question | Answer |
|----------|--------|
| **Build safely today?** | **Partially** — same export/spawn blockers; obstacle segments validate |
| **Limitations** | Obstacles block zombies only — no knockback/damage drama; no hazard events |
| **Blocks** | Shared Priority A factory gaps; optional hazard wiring for “real” crusher feel |
| **AI likely messes up** | `moving_obstacles_enabled = false`; crusher on spawn/finish; `obstacle_cycle_time` too fast; no recovery between obstacles |
| **Validator prevents** | `_validate_phase3_moving_obstacle_rules`, `_validate_moving_obstacle_spawn_finish_placement`, `_validate_moving_platform_recovery` |
| **Prototype-only** | Entire map; obstacle fairness manual review |
| **Defer** | `BounceObstacle` integration; dedicated crusher art |

### The Forked Gamble

| Question | Answer |
|----------|--------|
| **Build safely today?** | **No** — grammar validates but visual branch layout wrong; export blocked |
| **Limitations** | Splits are sequential offset floors — zombies do not choose branches |
| **Blocks** | Priority A + branch visual builder + wide-route spawn/goal/camera |
| **AI likely messes up** | Split without merge; spawn on split segment; assuming pathfinding; `route_half_width` too narrow for branches |
| **Validator prevents** | `_validate_split_merge_balance`, `_validate_split_merge_spawn_finish`, `_validate_branch_oob_bounds`, `_validate_low_risk_branch_required` |
| **Prototype-only** | Entire map; must document “illusion of choice” in blueprint notes |
| **Defer** | Real branch pathfinding; Twitch vote routing; `split_gap_choice` |

### The Long Fall Express

| Question | Answer |
|----------|--------|
| **Build safely today?** | **No** — all Priority A gaps; length amplifies spawn/goal bug; performance unproven |
| **Limitations** | Flat safe floors on ramp chains; long races may spread pack too thin without tuning |
| **Blocks** | Priority A + proven Drop Bridge export + optional length/performance gate |
| **AI likely messes up** | Gap chains without recovery; `target_length` ignored; extreme `height_delta` stack; too many segments |
| **Validator prevents** | Gap recovery, gap-before-gap, hidden floor, height transition warnings |
| **Prototype-only** | Entire map; 50+ zombie soak manual gate |
| **Defer** | Phase 3 mid-course obstacle; sloped collision; playable promotion |

---

## 3. Shared missing-pieces list

### Map assets

| Category | Status | Gap |
|----------|--------|-----|
| **Roads** | **Yes** | `phase1_road_*`; legacy `street_*` (deprecate for AI) |
| **Bridge pieces** | **Yes** | Procedural decks; no dedicated parapet GLTF |
| **Ramps** | **Partial** | Procedural `phase1_ramp_surface_8` only — no ramp GLTF |
| **Rails** | **Yes** | Kit `TrafficBarrier_*`; `phase2_broken_guardrail`, `phase2_missing_rail_section` |
| **Supports** | **Yes** | Procedural + `CinderBlock` kit |
| **Gap visuals** | **Yes** | `phase1_gap_void`, `phase2_broken_bridge_gap`, etc. |
| **Water/void visuals** | **Yes** | Procedural planes; never authoritative kill |
| **Obstacle pieces** | **Partial** | 18 `phase3_*` ids; placeholders not certified prefabs |
| **Split-lane pieces** | **Partial** | 15 `phase4_*` ids; visuals not placed at branch offsets in builder |

### Segment definitions

| Type | Status | Gap |
|------|--------|-----|
| **Straight** | **Yes** | `straight_road_short/medium/long`, `start_straight`, `finish_straight` |
| **Ramp** | **Yes** | `ramp_up`, `ramp_down`, `elevated_ramp_drop` |
| **Gap** | **Yes** | `small_center_gap`, `broken_bridge_gap`, `small_gap`, etc. |
| **Drop** | **Yes** | `left/right/double_side_drop`, `side_drop_edges`, etc. |
| **Moving obstacle** | **Yes** | 9 Phase 3 segment templates |
| **Split** | **Yes** | `split_two_lane`, `risk_reward_split`, `high_low_split`, etc. |
| **Merge** | **Yes** | `merge_two_lane`, `merge_recovery_straight` |
| **Recovery** | **Yes** | `recovery_straight_after_gap`, `hazard_recovery_straight`, `merge_recovery_straight` |

### Validator rules

| Rule | Status | Implementation |
|------|--------|----------------|
| No duplicate finish trigger | **Yes** | Builder does not create `GoalCatch`; `_validate_no_goal_catch` |
| No authoritative void kill zones | **Yes** | `_validate_no_authoritative_void_kill` |
| No hidden giant floor | **Yes** | `_validate_hidden_floor_width`, `_validate_hidden_branch_floors` |
| Gap must have recovery floor | **Partial** | Yes — but `TYPE_FINISH` allowed as gap successor (loophole) |
| Split must merge | **Yes** | `_validate_split_merge_balance` |
| Moving obstacle must leave safe route | **Yes** | `_validate_moving_obstacle_safe_lanes`, movement bounds |
| Camera must frame route | **Partial** | Non-zero camera required; wide/elevated warnings only |
| Spawn/finish cannot be in danger segment | **Yes** | Fall, gap, split, crusher spawn/finish rules |
| **Spawn/goal Z matches built route** | **No** | **Not validated — highest-risk gap** |
| Playable promotion blocked on blueprint | **Yes** | `authoring_status == playable` error |

### Builder support

| Capability | Status | Gap |
|------------|--------|-----|
| VisualLayer / GameplayLayer separation | **Yes** | — |
| Generated `RaceMapDefinition` | **Partial** | Exists via `to_race_map_definition()` but **Z values wrong** |
| Prototype-only output | **Yes** | In-memory `MapRoot` under host |
| No scene camera hijack | **Yes** | No `Camera3D` in builder output |
| No fallback fake success | **No** | Returns scene when scene validation fails; skips null assets silently |
| Export to `.tscn` / `.tres` | **No** | — |
| `RoadArena` / `CoreRoad` wrapper | **No** | Certification expects this hierarchy |
| Branch visual offset placement | **No** | Floors only |
| Asset `entry_offset` / `exit_offset` chaining | **No** | All assets at segment center Z |

---

## 4. Map factory backlog (prioritized)

### Priority A — required before **any** signature prototype can race

| # | Item | Blocks |
|---|------|--------|
| A1 | Fix spawn/goal/base/minigun Z — single source of truth (builder cursor → `to_race_map_definition`) | All 4 maps |
| A2 | Validator: assert definition Z span matches `get_total_route_length()` + builder cursor | All 4 maps |
| A3 | Builder: return `null` when `validate_generated_scene` fails | All 4 maps |
| A4 | Export: `AIMapBlueprintBuilder` → `RoadArena/CoreRoad/MapRoot` `.tscn` + `RaceMapDefinition` `.tres` | All 4 maps |
| A5 | `MapCatalog` prototype entry (`enabled=false`, `status=prototype`) + `load_prototype_map_for_test` wiring | All 4 maps |
| A6 | Add `ai_map_pipeline_test.gd` to `test_runner` **map** tier | Regression gate |
| A7 | Canonical example: deprecate `seg_*` in docs/factories; use `start_straight` / `phase1_*` only | AI confusion |
| A8 | Builder: fail loud on missing required asset instantiation | Silent incomplete maps |

### Priority B — required before **moving obstacle** maps (Crusher Hall)

| # | Item | Blocks |
|---|------|--------|
| B1 | Confirm `MapMovingObstacle` reset on race reset (prototype loader lifecycle) | Crusher Hall runtime |
| B2 | Document block-only obstacle behavior in blueprint `notes` (no fake hazard claims) | Streamer expectations |
| B3 | Optional: `BounceObstacle` / `GameEvents` wiring for crushers | Fair hazard feel — **defer if block-only OK for v1** |
| B4 | Close gap→finish validator loophole for moving platform recovery (mirror gap rules) | AI mistake prevention |

### Priority C — required before **split-lane** maps (Forked Gamble)

| # | Item | Blocks |
|---|------|--------|
| C1 | Builder: place branch visuals at `branch_offsets` (not only safe floors) | Forked Gamble readability |
| C2 | Validator: wide-route camera minimum side offset (error not warning) | OBS framing |
| C3 | Blueprint template factory `signature_forked_gamble.gd` with explicit illusion disclaimer | AI pathfinding assumptions |
| C4 | Verify `out_of_bounds_half_width` auto-sizing for `get_route_max_half_width()` after spawn/goal fix | Branch OOB kills |

### Priority D — nice later

| # | Item |
|---|------|
| D1 | Sloped / stepped safe-floor collision matching `height_delta` |
| D2 | Asset `entry_offset` / `exit_offset` chaining in builder |
| D3 | Dedicated ramp / crusher / parapet GLTF art |
| D4 | `theme` / `visual_theme` application in builder |
| D5 | Real zombie branch pathfinding |
| D6 | Map editor UI |
| D7 | Performance budget validator (max segments / safe-floor node count) |
| D8 | Automated 50–100 zombie soak in CI for Long Fall Express |

---

## 5. First prototype target

### Recommendation: **The Drop Bridge**

Verified against current system — still the safest first target.

| Factor | Why Drop Bridge wins |
|--------|---------------------|
| **Phase surface** | Phase 1 + 2 only — no moving obstacles, no splits |
| **Existing proof** | `phase2_drop_gap_test` blueprint is ~80% of the route |
| **Mission fit** | Fall spectacle = core streamer clip mechanic |
| **Validator maturity** | Phase 2 rules are the most complete non-split ruleset |
| **Certification path** | `void_oob_authority_test` is the natural first cert gate |
| **Length** | Medium (~80 m) — errors visible without 160 m amplification |

**What it proves**

- End-to-end factory: blueprint → validate → build → export → load → certify (once Priority A done)
- Elevated deck + gap + side fall + water void readability on OBS
- OOB min-Y fall authority without void-kill scripts
- Recovery pacing between danger beats

**What it risks**

- Spawn/goal misalignment makes finish contract fail until A1 fixed
- Flat ramp collision may look like zombies float on elevation changes
- `double_side_drop` immediately before finish may eliminate too many runners if OOB tuned wrong

**What must exist first (minimum)**

1. A1 — spawn/goal Z fix  
2. A3 — builder fail-hard on scene validation  
3. A4 + A5 — export + prototype load  
4. A6 — pipeline test in CI  

Themes, hazard wiring, splits, and sloped collision are **not** required for Drop Bridge v1.

---

## 6. Minimum viable map factory (MVF)

**Definition:** The smallest system that lets AI assemble a **prototype map from approved parts without breaking protected game authorities or silently producing broken races.

### MVF includes

```
MapAssetLibrary (phase1 + phase2 canonical ids)
  → MapSegmentDefinition (approved segment_sequence grammar)
  → AIMapBlueprint (flags + authoring_status = test)
  → AIMapBlueprintValidator.validate_blueprint (hard fail)
  → AIMapBlueprintBuilder.build_prototype (hard fail on scene validation)
  → AIMapBlueprintExporter (NEW) → RoadArena/CoreRoad/MapRoot .tscn
  → RaceMapDefinition .tres (spawn/goal/OOB aligned to built geometry)
  → MapCatalog prototype entry (enabled=false)
  → load_prototype_map_for_test(map_id)
  → map_certification_test.gd --map_id=signature_drop_bridge
```

### MVF explicitly excludes

- Map editor UI
- Theme/visual polish pipeline
- Phase 3 moving obstacles (until Crusher Hall)
- Phase 4 splits (until Forked Gamble)
- Playable promotion / dropdown registration
- Twitch/scoring integration
- Custom per-map scripts
- Sloped ramp collision (accept flat floors for v1)

### MVF success test

> Cursor can create `signature_drop_bridge.gd` factory using only documented segment ids, run validator + builder + export, load prototype in test harness, and pass `map_certification_test` — **without editing `zombie.gd`, race lifecycle, finish/OOB authority, or certification guards.**

---

## 7. Cross-reference: validator → AI mistake

| AI mistake | Validator function | Map(s) affected |
|------------|-------------------|-----------------|
| Gap without `fall_enabled` | `_validate_gap_fall_settings` | Drop Bridge, Forked Gamble, Long Fall |
| Gap → gap, no recovery | `_validate_safe_floor_before_gaps`, `_validate_gap_recovery_floors` | All with gaps |
| Hidden wide safe floor on gap | `_validate_hidden_floor_width` | Drop Bridge, Long Fall |
| Spawn/finish on gap or drop | `_validate_spawn_finish_not_in_fall_segments` | All with gaps |
| Split without merge | `_validate_split_merge_balance` | Forked Gamble |
| No low-risk branch | `_validate_low_risk_branch_required` | Forked Gamble |
| Obstacle blocks all lanes | `_validate_moving_obstacle_safe_lanes` | Crusher Hall |
| Crusher on spawn/finish | `_validate_moving_obstacle_spawn_finish_placement` | Crusher Hall |
| `GoalCatch` in scene | `_validate_no_goal_catch` | All |
| Void kill zone script | `_validate_no_authoritative_void_kill` | All |
| Scene camera current | `_validate_no_scene_cameras` | All |
| Promote blueprint to playable | `authoring_status == playable` check | All |
| **Spawn/goal off route** | **MISSING** | **All** |

---

## 8. Certification matrix (per map)

| Check | Drop Bridge | Crusher Hall | Forked Gamble | Long Fall Express |
|-------|-------------|--------------|---------------|-------------------|
| `map_certification_test.gd` | Required | Required | Required | Required |
| `void_oob_authority_test.gd` | **Required** (elevated) | Optional | Required (post-merge gap) | **Required** |
| `race_finish_contract_test.gd` | Required | Required | Required | Required |
| `broken_bridge_real_gameplay_test.gd` | Recommended | Skip | Recommended | Recommended |
| Scene contract `RoadArena/CoreRoad/MapRoot` | Required | Required | Required | Required |
| `World/StreamerBase` align `base_position` | Required | Required | Required | Required |
| Manual obstacle fairness review | Skip | **Required** | Skip | Skip |
| 50+ zombie soak | Skip | Skip | Optional | **Required** |

---

## 9. Implementation order (signature maps)

| Order | Map | After MVF + |
|-------|-----|-------------|
| 1 | **The Drop Bridge** | Priority A complete |
| 2 | **The Crusher Hall** | Priority A + B (block-only obstacles acceptable) |
| 3 | **The Forked Gamble** | Priority A + C |
| 4 | **The Long Fall Express** | Maps 1–3 export proven + optional D7 performance gate |

---

## 10. Related documents

| Document | Role |
|----------|------|
| [SIGNATURE_MAPS_PLAN.md](SIGNATURE_MAPS_PLAN.md) | Creative design + route sequences |
| [AI_MAP_BUILDING_PIPELINE.md](AI_MAP_BUILDING_PIPELINE.md) | System grammar + phase packs |
| [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md) | Promotion gates (unchanged) |
| [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md) | Protected systems |

---

*Last updated: planning pass after merge of AI Map Building System to `main`. No gameplay behavior changed.*
