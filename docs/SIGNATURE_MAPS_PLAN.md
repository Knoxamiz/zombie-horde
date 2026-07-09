# Four Signature Maps — Design Plan

Planning document only. **No maps are implemented, certified, or promoted to playable.**

Related:

- [AI_MAP_BUILDING_PIPELINE.md](AI_MAP_BUILDING_PIPELINE.md)
- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)
- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md)

---

## Mission alignment

**Zombie Horde is a Twitch streamer engagement game.** Maps are not the product — they are **ride-shaped content** that makes races easy to watch, react to, and rematch.

Every signature map must help:

| Goal | How maps support it |
|------|---------------------|
| Viewers understand what happened | One dominant visual mechanic per map; high contrast danger zones |
| Streamer reacts quickly | Predictable beat structure (setup → danger → payoff → finish) |
| Race resets fast | Short-to-medium prototype loops where possible; clear spawn/finish bands |
| Deaths/falls feel funny | Side falls and gaps use OOB min-Y — splats, not invisible kills |
| Winner moment feels obvious | Straight finish approach; no finish inside gap/split/crusher |
| OBS view stays readable | Camera padding per segment hints; avoid ultra-narrow chaos on map 1 |

**Protected authorities (unchanged):**

- Finish: `World/StreamerBase` (`StreamerBaseGoal`)
- Falls/OOB: `Zombie._check_out_of_bounds()` + `RaceMapDefinition` / `ZombieConfig`
- Never: `GoalCatch`, authoritative `bridge_void_kill_zone`, scene `Camera3D.current`

---

## System context (current state)

The AI Map Building System can **validate and build in-memory prototypes** from approved segment grammar. Known gaps before any signature map can race for real:

1. **Spawn/goal Z mismatch** — `to_race_map_definition()` uses a symmetric formula; builder assembles from Z=0 forward. Must be fixed before export/load.
2. **No export path** — builder output is not yet saved as `RoadArena` `.tscn` + `RaceMapDefinition` `.tres` + `MapCatalog` prototype entry.
3. **Phase 3 obstacles** — `MapMovingObstacle` blocks kinematically; no `BounceObstacle` / `GameEvents` hazard wiring yet.
4. **Phase 4 splits** — lateral offset floors + visuals; zombies do **not** pathfind branches (documented limitation).
5. **Ramp collision** — `height_delta` is visual deck stepping; safe floor plates stay flat.

Signature maps are designed **within these constraints** unless a prerequisite fix is listed in the readiness checklist.

---

## Map comparison at a glance

| Map | Size | Target length | Ideal viewers | Main mechanic | Danger type | Primary phases |
|-----|------|---------------|---------------|---------------|-------------|----------------|
| **The Drop Bridge** | Medium | ~72–80 m | 15–30 | Elevated bridge + broken rails | Side falls, center gap, void below | 1 + 2 |
| **The Crusher Hall** | Small / fast | ~48–56 m | 10–25 | Timed crusher corridor | Moving blocks, gates, pushers | 1 + 3 |
| **The Forked Gamble** | Large / wide | ~88–96 m | 25–50 | Split → gamble → merge | Risk shortcut vs safe lane (+ optional gap branch) | 1 + 2 + 4 |
| **The Long Fall Express** | Huge / cinematic | ~128–160 m | 50–100 | Long downhill endurance | Ramps, drops, recovery beats, final bridge | 1 + 2 |

---

## 1. The Drop Bridge

### Hook

*Ride the skywalk — rails snap, edges crumble, and the crowd watches who drifts off into the void.*

### Profile

| Field | Value |
|-------|-------|
| **Map id (planned)** | `signature_drop_bridge` |
| **Size category** | Medium |
| **Target race length** | ~72–80 m (9–10 segments × 8 m) |
| **Ideal viewer count** | 15–30 |
| **Main mechanic** | Elevated bridge with broken/missing rails, side falls, water/void below |
| **Danger type** | Environmental fall (OOB min-Y), not obstacle kills |
| **Streamer readability** | High — lateral falls are visible; void color contrast below deck |
| **Required system phases** | **Phase 1** + **Phase 2** |

### Route sequence

```
start_straight
→ straight_road_short
→ ramp_up
→ elevated_straight
→ narrow_no_rails_bridge
→ left_side_drop
→ broken_bridge_gap
→ recovery_straight_after_gap
→ double_side_drop
→ finish_straight
```

**Blueprint flags:** `water_enabled = true`, `fall_enabled = true`, `deck_y ≈ 2.0`, `moving_obstacles_enabled = false`

**Pacing beats:**

1. **Launch** (start + short straight) — establish lane
2. **Climb** (ramp_up + elevated_straight) — camera lifts with deck
3. **First gasp** (narrow_no_rails_bridge + left_side_drop) — missing rails, first side fall risk
4. **Center punch** (broken_bridge_gap) — classic gap splat moment
5. **Breather** (recovery_straight_after_gap) — survivors regroup
6. **Final squeeze** (double_side_drop) — both edges hot before finish

### Required asset categories

| Category | Examples (phase ids) |
|----------|----------------------|
| `road` | `phase1_road_straight_8`, `phase1_road_cracked_heavy` |
| `bridge` | `phase2_elevated_bridge_deck`, `phase2_safe_floor_plate` |
| `ramp` | `phase1_ramp_surface_8` |
| `rail` / `barrier` | `phase2_broken_guardrail`, `phase2_missing_rail_section` |
| `gap` / `drop` | `phase2_broken_bridge_gap`, `phase2_side_fall_opening`, `phase2_drop_off_section` |
| `water` | `phase2_water_river_plane`, `phase2_void_floor_visual` |
| `hazard` | `phase2_warning_stripes` |
| `support` | `phase2_support_pillar` |
| `decoration` | `phase2_edge_cone`, `phase2_edge_light`, `phase2_deco_debris` |

### Phase dependencies

| Phase | What this map needs |
|-------|---------------------|
| **Phase 1** | `start_straight`, `straight_road_short`, `ramp_up`, base road tiles |
| **Phase 2** | `elevated_straight`, `narrow_no_rails_bridge`, `left_side_drop`, `broken_bridge_gap`, `recovery_straight_after_gap`, `double_side_drop`, water/void visuals |
| **Phase 3** | Not used |
| **Phase 4** | Not used |

### Streamer moment

Elevated deck with **missing rails** — chat sees a zombie drift wide and **drop into the void** while others hug center. Gap segment creates a **single obvious “they fell through the bridge”** clip.

### Failure risks

| Risk | Mitigation |
|------|------------|
| Spawn/goal misaligned with geometry | Fix `to_race_map_definition()` Z before build |
| `out_of_bounds_min_y` too high — deck walkers die | `fall_enabled = true`; segment `recommended_oob_min_y`; validator elevated water rules |
| Hidden giant safe floor on gaps | Keep `safe_floor_width_ratio ≤ 0.75` on gap segments |
| Camera too low on elevated route | `recommended_camera_padding` on elevated segments; validator elevated camera check |
| Boring if everyone falls | Recovery segment before finish; double_side_drop is last danger |

### Validation requirements

- `fall_enabled = true` (gap/drop segments present)
- Gap preceded by safe floor; gap followed by `recovery_straight_after_gap`
- Spawn/finish not on gap/drop segments
- `deck_y` above `water_void_y` when `water_enabled`
- Hidden floor width checks pass
- Blueprint + generated scene contract (no GoalCatch, no void-kill, no scene camera)

### Certification concerns

- `void_oob_authority_test.gd` — elevated bridge layout
- `race_finish_contract_test.gd` — `base_position.z` aligns with goal after spawn/goal fix
- `map_certification_test.gd` — full checklist once exported to `RoadArena` scene
- Finish approach must be **flat safe straight**, not inside gap

### What must NOT be custom-coded

- Zombie movement, lane logic, or branch selection
- `GoalCatch` or void-kill `Area3D` scripts
- Custom fall kill volumes
- Scene-owned cameras
- Twitch/scoring hooks
- Hand-authored collision on GLTF props (safe floor plates only)

---

## 2. The Crusher Hall

### Hook

*A short industrial gauntlet — crushers slam, gates snap shut, and only the well-timed survive.*

### Profile

| Field | Value |
|-------|-------|
| **Map id (planned)** | `signature_crusher_hall` |
| **Size category** | Small / fast |
| **Target race length** | ~48–56 m (6–7 segments × 8 m) |
| **Ideal viewer count** | 10–25 |
| **Main mechanic** | Dense moving-obstacle corridor (crushers, gates, push blocks) |
| **Danger type** | Timing / blockage (kinematic obstacles), not falls |
| **Streamer readability** | Very high — repetitive rhythm; easy “gate closed!” callouts |
| **Required system phases** | **Phase 1** + **Phase 3** |

### Route sequence

```
start_straight
→ straight_road_short
→ moving_block_lane
→ hazard_recovery_straight
→ crusher_corridor
→ timed_gate_straight
→ side_pusher_lane
→ finish_straight
```

**Blueprint flags:** `water_enabled = false`, `fall_enabled = false`, `moving_obstacles_enabled = true`, `obstacle_cycle_time ≈ 3.5–4.0 s`, `deck_y ≈ 0.8`

**Pacing beats:**

1. **Warm-up block** — first moving lane teaches timing
2. **Recovery breath** — full-width safe straight
3. **Crusher climax** — overhead slam rhythm (visual + block)
4. **Gate tension** — open/closed windows
5. **Side shove** — lateral push into safe lane before sprint finish

### Required asset categories

| Category | Examples (phase ids) |
|----------|----------------------|
| `road` | `phase1_road_straight_8` |
| `bridge` | `phase2_safe_floor_plate` (walk surface) |
| `moving_obstacle` | `phase3_moving_block_crate`, `phase3_crusher_plate`, `phase3_crusher_frame` |
| `moving_obstacle` | `phase3_timed_gate`, `phase3_gate_barrier`, `phase3_side_pusher`, `phase3_pusher_plate` |
| `hazard` | `phase3_warning_stripes`, `phase3_warning_light` |
| `decoration` | `phase3_safe_lane_marker`, `phase3_deco_sparks` |

### Phase dependencies

| Phase | What this map needs |
|-------|---------------------|
| **Phase 1** | `start_straight`, `straight_road_short`, `finish_straight` |
| **Phase 2** | Safe floor asset only (no fall segments) |
| **Phase 3** | `moving_block_lane`, `crusher_corridor`, `timed_gate_straight`, `side_pusher_lane`, `hazard_recovery_straight` |
| **Phase 4** | Not used |

### Streamer moment

**Crusher corridor** — predictable slam cycle lets streamer count down (“3… 2… GO”). Stuck zombies behind a **closed gate** create slapstick pileups without custom code.

### Failure risks

| Risk | Mitigation |
|------|------------|
| Obstacles block all lanes permanently | Validator: `fallback_safe_lane = true`, `fallback_safe_lane_width ≥ 1.5`, movement bounds |
| Cycle too fast for zombies | `obstacle_cycle_time` 3.5–4.0 s (within 1.5–12 s validator range) |
| Crusher on spawn/finish | Validator blocks crusher/pusher on first/last segment |
| Obstacles feel unfair (no knockback drama) | **Deferred:** `BounceObstacle` wiring — prototype accepts block-only |
| Map too long — engagement drops | Cap at ~56 m; no fall segments |

### Validation requirements

- `moving_obstacles_enabled = true`
- Each obstacle segment: `safe_lane_count ≥ 1`, `fallback_safe_lane = true`
- `obstacle_cycle_time` within [1.5, 12.0]
- Obstacle movement distance ≤ 45% segment width/length
- `hazard_recovery_straight` after `moving_block_lane` (and between crusher and gate if needed)
- No fall segments without `fall_enabled`

### Certification concerns

- Moving obstacles must not hijack camera or finish
- Scene contract: `GameplayLayer/MovingObstacles` present
- **Gameplay fairness** not fully certifiable today — certify geometry + contract first; hazard feel is follow-up
- Short map → verify mini-race loop completes quickly in `map_certification_test.gd`

### What must NOT be custom-coded

- Per-map obstacle scripts outside `MapMovingObstacle`
- Direct `zombie.gd` edits for timing
- Kill volumes on crushers
- Custom tween frameworks
- Map-specific race lifecycle changes

---

## 3. The Forked Gamble

### Hook

*The path splits — daredevils bite the narrow shortcut while cowards cruise the wide safe lane, and everyone merges before the finish line.*

### Profile

| Field | Value |
|-------|-------|
| **Map id (planned)** | `signature_forked_gamble` |
| **Size category** | Large / wide |
| **Target race length** | ~88–96 m (11–12 segments × 8 m) |
| **Ideal viewer count** | 25–50 |
| **Main mechanic** | Split → risky shortcut vs safe wide route → merge |
| **Danger type** | Route shape + optional gap on risky branch (visual gamble, not AI path choice) |
| **Streamer readability** | Medium-high — wide camera; sign markers; **chat illusion of “choices”** |
| **Required system phases** | **Phase 1** + **Phase 2** + **Phase 4** |

### Route sequence

```
start_straight
→ straight_road_medium
→ risk_reward_split
→ split_two_lane
→ narrow_shortcut
→ wide_safe_route
→ merge_two_lane
→ merge_recovery_straight
→ broken_bridge_gap
→ recovery_straight_after_gap
→ finish_straight
```

**Blueprint flags:** `water_enabled = true`, `fall_enabled = true`, `moving_obstacles_enabled = false`, `route_half_width ≈ 7.0`, `lane_half_width ≈ 5.0`, `deck_y ≈ 1.2`

**Pacing beats:**

1. **Setup straight** — establish wide course
2. **Sign + fork** — `risk_reward_split` + `split_two_lane` with route arrows
3. **Gamble beats** — sequential `narrow_shortcut` then `wide_safe_route` (offset floors, not pathfinding)
4. **Merge exhale** — `merge_two_lane` + `merge_recovery_straight`
5. **Final test** — one gap before finish to punish survivors who got complacent

### Required asset categories

| Category | Examples (phase ids) |
|----------|----------------------|
| `road` | `phase1_road_straight_8`, `phase4_fork_road_left`, `phase4_fork_road_right` |
| `bridge` | `phase4_split_bridge`, `phase4_wide_safe_bridge`, `phase4_narrow_shortcut_bridge`, `phase4_safe_floor_plate` |
| `gap` | `phase2_broken_bridge_gap` (post-merge sting) |
| `rail` / `barrier` | `phase4_split_guardrail`, `phase4_divider_barrier` |
| `route_marker` | `phase4_route_sign_arrow`, `phase4_lane_merge_marking` |
| `water` | `phase2_void_floor_visual` |
| `merge` | `phase4_merge_road` |

### Phase dependencies

| Phase | What this map needs |
|-------|---------------------|
| **Phase 1** | Start, medium straight, finish |
| **Phase 2** | Post-merge gap + recovery; void visual |
| **Phase 3** | Not required (`obstacle_route_choice` optional later) |
| **Phase 4** | Full split/merge grammar: `risk_reward_split`, `split_two_lane`, `narrow_shortcut`, `wide_safe_route`, `merge_two_lane`, `merge_recovery_straight` |

### Streamer moment

**Fork signage** — streamer hypes “left is risky, right is safe” even though zombies stay on forward track. **Merge squeeze** creates a tight pack before the final gap. Clip-friendly **“they gambled and ate the gap”** after merge recovery.

### Failure risks

| Risk | Mitigation |
|------|------------|
| Chat expects real branch AI | Document in map notes: offset lanes only; no pathfinding |
| Split without merge | Validator split/merge balance rules |
| Branch floors wider than visible route | `hidden_branch_floors` validator |
| OOB too narrow for wide route | `out_of_bounds_half_width ≥ route_max_half_width + 1` |
| Branch visuals at X=0 while floors offset | **Prerequisite:** builder places branch visuals at `branch_offsets` (currently floors only) |
| Low-risk branch missing | Validator: `wide_safe_route` satisfies low-risk requirement |

### Validation requirements

- Split must merge before finish
- Spawn/finish not on split/merge/branch segments
- At least one low-risk branch per split section
- `merge_recovery_straight` recommended after merge
- Gap after merge requires recovery before finish
- Split route camera framing warnings addressed via wide `route_half_width`

### Certification concerns

- Widest map — camera side offset must frame full route
- Branch safe floors must not extend past visible road (certification trap if hidden floors cheat)
- **Do not claim shortcut changes race length** — progress is spawn→goal dot product; both branches are sequential segments for prototype
- `race_finish_contract_test.gd` after spawn/goal fix

### What must NOT be custom-coded

- Zombie branch selection / pathfinding
- Per-branch progress meters
- Separate finish triggers per lane
- Custom merge logic in `zombie.gd`
- Fake “choice” UI tied to Twitch votes (future idea — out of scope)

---

## 4. The Long Fall Express

### Hook

*A cinematic downhill marathon — ramps, drops, recovery platforms, and one last bridge ride before the finish grandstand.*

### Profile

| Field | Value |
|-------|-------|
| **Map id (planned)** | `signature_long_fall_express` |
| **Size category** | Huge / cinematic |
| **Target race length** | ~128–160 m (16–20 segments × 8 m) |
| **Ideal viewer count** | 50–100 |
| **Main mechanic** | Long endurance descent with ramp chains, drops, recovery platforms, final bridge |
| **Danger type** | Sustained fall risk + elevation change (visual); fatigue pacing |
| **Streamer readability** | High at macro scale — “who’s still on the track” is obvious over long Z span |
| **Required system phases** | **Phase 1** + **Phase 2** (Phase 3/4 optional garnish only) |

### Route sequence

```
start_straight
→ straight_road_long
→ ramp_up
→ elevated_straight
→ straight_road_medium
→ left_side_drop
→ elevated_ramp_drop
→ recovery_straight_after_gap
→ straight_road_medium
→ cracked_edge_lane
→ broken_bridge_gap
→ recovery_straight_after_gap
→ ramp_down
→ bridge_straight
→ straight_road_long
→ water_underpass
→ finish_straight
```

**Blueprint flags:** `water_enabled = true`, `fall_enabled = true`, `deck_y ≈ 3.0` (start high, net descent), `moving_obstacles_enabled = false`, `route_half_width ≈ 5.5`

**Computed length:** 8+24+8+8+16+8+8+8+16+8+8+8+8+8+24+8+8 = **168 m** (tune by swapping one `straight_road_medium` → `straight_road_short` for ~160 m)

**Pacing beats:**

1. **Epic intro** — long opening straight sets scale for big lobbies
2. **Ascent fake-out** — ramp_up + elevated (camera establishes height)
3. **First descent chapter** — side drop + elevated_ramp_drop
4. **Recovery platform** — breathe before mid-course
5. **Mid-course crack + gap** — two danger types back-to-back with recovery between
6. **Final descent** — ramp_down into bridge
7. **Victory lap** — long straight + water underpass under final approach

### Required asset categories

| Category | Examples (phase ids) |
|----------|----------------------|
| `road` | `phase1_road_straight_8`, cracked variants |
| `bridge` | `phase1_bridge_deck_8`, `phase2_elevated_bridge_deck` |
| `ramp` | `phase1_ramp_surface_8` |
| `drop` / `gap` | `phase2_drop_off_section`, `phase2_broken_bridge_gap`, `phase2_cracked_road_edge` |
| `water` | `phase2_water_river_plane`, `phase2_water_underpass` segment visuals |
| `rail` | `phase1_rail_traffic_a`, `phase2_broken_guardrail` |
| `support` | `phase1_support_pillar`, `phase2_support_pillar` |
| `hazard` | `phase2_warning_stripes` |

### Phase dependencies

| Phase | What this map needs |
|-------|---------------------|
| **Phase 1** | Long straights, ramps, bridge, rails, supports |
| **Phase 2** | Elevated, drops, gaps, recovery, cracked edge, water underpass |
| **Phase 3** | **Deferred** — optional single `timed_gate_straight` mid-course only after Crusher Hall proves obstacles |
| **Phase 4** | **Not used** — keep single lane for 50–100 zombie readability |

### Streamer moment

**Scale** — long Z span keeps pack spread visible on OBS. **Elevated_ramp_drop** creates a “roller coaster dip” clip. **Water underpass** before finish gives a cinematic approach. Streamer can narrate **chapters** (“top of the mountain”, “broken section”, “home stretch”).

### Failure risks

| Risk | Mitigation |
|------|------------|
| Map too long — dead air | Chapter pacing with recovery segments every 2–3 dangers |
| Cumulative `height_delta` extreme | Validator warns if route height swings > ±12 m from start deck |
| Camera loses track on 160 m span | Max `recommended_camera_padding`; verify `compute_race_camera_view_for_definition` |
| Ramp visuals ≠ walk surface | Document flat safe floors; avoid rapid ramp chains until sloped collision exists |
| 50–100 zombies amplify OOB edge cases | Wide `lane_half_width`; generous `out_of_bounds_half_width` |
| Spawn/goal error amplified by length | **Critical** — fix Z alignment before building this map |

### Validation requirements

- All Phase 2 gap/drop rules (recovery floors, fall_enabled, hidden floor width)
- No gap→gap without recovery
- Elevated water clearance
- Route length vs `target_length` warning threshold (set `target_length ≈ 160`)
- Cumulative height transition warnings reviewed manually

### Certification concerns

- Longest mini-race in certification suite — verify join → resolve → reset timing
- `void_oob_authority_test.gd` across full elevation range
- `broken_bridge_real_gameplay_test.gd` style soak with `--zombies=50` (manual gate, not blocking prototype)
- Performance: many segments = many safe floor plates — watch scene node count

### What must NOT be custom-coded

- Endurance mechanics (stamina, speed decay)
- Mid-race checkpoints
- Custom camera rails per chapter
- Void kill zones for “express” pacing
- Lobby-size-specific zombie logic

---

## Recommended build order

| Order | Map | Why |
|-------|-----|-----|
| **1** | **The Drop Bridge** | Smallest phase surface (1+2 only). Proves **fall spectacle** — core streamer moment. Exercises elevated deck, gaps, water, recovery — the highest-value mechanic for clips. Fixes spawn/goal + export on the simplest interesting map before adding obstacle or split complexity. |
| **2** | **The Crusher Hall** | Shortest route; fast iteration on **Phase 3**. Proves obstacle rhythm without fall/OOB interactions. Validates moving obstacle validator rules in isolation. Quick rematch loop matches engagement mission. |
| **3** | **The Forked Gamble** | Requires **widest system maturity** (Phase 4 + branch builder fixes). Risk/reward is meaningless until Drop Bridge (falls) and spawn/goal export work. Wide camera/OOB stress test before the huge map. |
| **4** | **The Long Fall Express** | **Largest blast radius** — every system weakness (Z alignment, camera, flat ramps, node count) scales with length. Build last when grammar, export, and certification path are proven on maps 1–3. |

**Safest first prototype:** **The Drop Bridge** — fewest phases, assets already in `phase2_drop_gap_test`, no moving obstacles, no split illusions, medium length.

---

## Readiness checklist (per map)

### The Drop Bridge

| Item | Status |
|------|--------|
| **Can current system support this now?** | **Partially** — segment grammar yes; spawn/goal Z and export no |
| **Missing assets** | None critical — reuse Phase 2 pack; optional more broken rail GLTF variants (cosmetic) |
| **Validator rules needed** | Existing Phase 2 rules sufficient; add spawn/goal Z vs route length assertion (system fix) |
| **Certification tests needed** | `map_certification_test`, `void_oob_authority_test`, `race_finish_contract_test` on exported prototype |
| **Defer** | Sloped ramp collision; themes; playable promotion |

### The Crusher Hall

| Item | Status |
|------|--------|
| **Can current system support this now?** | **Partially** — segments + validator yes; hazard gameplay feel no; export no |
| **Missing assets** | Dedicated crusher/swing arm GLTF (procedural placeholders OK for prototype) |
| **Validator rules needed** | Existing Phase 3 rules; confirm recovery between consecutive obstacle segments |
| **Certification tests needed** | Scene contract + mini-race; obstacle fairness manual review |
| **Defer** | `BounceObstacle` / `GameEvents` wiring; kill/damage from crushers; playable promotion |

### The Forked Gamble

| Item | Status |
|------|--------|
| **Can current system support this now?** | **No** — branch visual placement gap; spawn/goal fix; export; split illusion docs |
| **Missing assets** | None critical in registry; need **builder branch offset for visuals** |
| **Validator rules needed** | Existing Phase 4 rules; optional: warn when `narrow_shortcut` immediately follows `wide_safe_route` (ordering hint) |
| **Certification tests needed** | Wide-route camera check; hidden branch floor audit; finish contract |
| **Defer** | Real branch pathfinding; Twitch vote routing; `split_gap_choice` until falls proven |

### The Long Fall Express

| Item | Status |
|------|--------|
| **Can current system support this now?** | **No** — depends on all system fixes from maps 1–3; length stress untested |
| **Missing assets** | None critical; optional dedicated “grandstand” finish dressing (decoration only) |
| **Validator rules needed** | Cumulative height warning review; route length cap warning; chapter recovery policy (manual design rule) |
| **Certification tests needed** | Full suite + large zombie soak (50+) as manual gate |
| **Defer** | Phase 3/4 garnish; mid-course obstacles; sloped collision; playable promotion |

---

## Shared prerequisites (before any signature map races)

These are **system tasks**, not map tasks:

1. **Fix spawn/goal/base Z** — builder cursor and `to_race_map_definition()` must agree.
2. **Export pipeline** — `AIMapBlueprintBuilder` → `RoadArena/CoreRoad/MapRoot` `.tscn` + `.tres`.
3. **Prototype loader** — `MapCatalog` entry (`enabled=false`, `status=prototype`) + `load_prototype_map_for_test`.
4. **Add `ai_map_pipeline_test` to `test_runner` map tier** — regression gate.
5. **Canonical segment ids** — signature blueprints use `start_straight` / `phase1_*` / `phase2_*`, not legacy `seg_*`.

---

## Shared “do not build” list

- Map editor UI or theme packs
- Fifth signature map before one certifies
- Playable promotion without certification
- Custom per-map scripts in `zombie.gd`, `RaceMapController`, or Twitch layer
- Authoritative kill volumes for pacing
- Real multi-path AI for The Forked Gamble (v2+)

---

## Planned blueprint factories (implementation phase — not created yet)

| Map | Planned factory script |
|-----|------------------------|
| The Drop Bridge | `scripts/maps/blueprints/signature_drop_bridge.gd` |
| The Crusher Hall | `scripts/maps/blueprints/signature_crusher_hall.gd` |
| The Forked Gamble | `scripts/maps/blueprints/signature_forked_gamble.gd` |
| The Long Fall Express | `scripts/maps/blueprints/signature_long_fall_express.gd` |

Each factory will set `authoring_status = "test"` and will **not** register in `MapCatalog` until export + certification path exists.

---

## Success criteria (when implementation begins)

A signature map prototype is “done” when:

1. `AIMapBlueprintValidator.validate_blueprint` passes
2. `AIMapBlueprintBuilder.build_prototype` passes scene validation (builder must fail hard on error)
3. Exported scene loads via `load_prototype_map_for_test`
4. `map_certification_test.gd --map_id=<prototype>` passes
5. Streamer can narrate the main mechanic in one sentence without explaining engine limitations

Maps are **content for engagement**, not milestones for their own sake. Ship **The Drop Bridge** first; only then earn the right to build the rollercoaster.
