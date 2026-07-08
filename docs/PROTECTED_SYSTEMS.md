# Protected Systems

This document lists gameplay and infrastructure systems that must not be changed casually. It reflects the architecture hardened in PRs #38–#42.

Related docs:

- [TESTING.md](TESTING.md) — headless test tiers and commands
- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md) — map promotion and certification gate
- [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md) — Cursor/Codex workflow rules

---

## Race lifecycle

**Files:** `scripts/core/round_manager.gd`, `resources/config/round_config.tres`, `scripts/core/round_config.gd`, `scripts/ui/hud_controller.gd` (lifecycle display only)

**Why protected:** PR #38 established timeout, auto-reset, and recovery paths. Silent changes here break races, scoring windows, and streamer expectations.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Log messages, comments, debug-only diagnostics | `RoundState` enum values or transition order |
| HUD text that reflects state (with HUD rules) | `start_round`, `reset_round`, timeout, or auto-reset timing without explicit request |
| New debug tests that assert existing behavior | Skipping ENDED → IDLE recovery or post-round reset |

**Required tests before merge:** `--tier=smoke` + `--tier=core` (`race_lifecycle_smoke_test.gd`, `race_quick_smoke_test.gd`)

---

## RoundManager state transitions

**Files:** `scripts/core/round_manager.gd`

**States:** `IDLE` → `COUNTDOWN` → `RUNNING` → `ENDED` → (reset) → `IDLE`

**Why protected:** All join, spawn, finish, death, and timeout logic assumes this contract.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Helper extraction that preserves behavior | Adding states or merging RUNNING/ENDED |
| Read-only accessors | Emitting `GameEvents` from the wrong transition |
| Test-only configuration via `round_config` in debug scripts | Allowing joins during RUNNING without explicit design approval |

**Required tests before merge:** `--tier=smoke` + `--tier=core`

---

## GameEvents signal bus

**Files:** `scripts/core/game_events.gd` (autoload `GameEvents`)

**Why protected:** Decoupled UI, Twitch, scoring, and gameplay subscribe to these signals. Renaming or removing signals breaks multiple systems silently.

| Safe to change | Do not change casually |
|----------------|------------------------|
| New signals with clear consumers and tests | Renaming or removing existing signals |
| Documentation | Changing payload meaning of `zombie_died`, `zombie_reached_base`, `round_ended`, etc. |
| Debug-only reporting | Routing finish/death through parallel ad-hoc paths |

**Required tests before merge:** `--tier=smoke`; add `--tier=core` if race/finish/OOB signals are touched

---

## RaceMapDefinition

**Files:** `scripts/maps/race_map_definition.gd`, `resources/maps/*.tres`

**Why protected:** Single source of truth for spawn, goal, base, OOB, hazard placement, and camera framing per map.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Values on a specific map resource after certification | Removing or repurposing fields used by `RaceMapController` or `ZombieConfig` |
| New optional fields with controller support + tests | Hardcoding map dimensions in zombie or round code |
| Prototype map `.tres` files (`enabled=false`) | Promoting map fields without updating certification |

**Required tests before merge:** `--tier=certification` for map definition changes; `--tier=smoke` minimum

---

## RaceMapController map loading

**Files:** `scripts/maps/race_map_controller.gd`, `scripts/maps/map_catalog.gd`, `scripts/maps/map_certification.gd`

**Why protected:** PR #42 added loud failure in debug/headless and removed silent City Highway substitution during tests. Fake success is a major map-development risk.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Log/diagnostic output | Re-enabling silent City Highway fallback in debug or headless |
| Certification checklist extensions with tests | Bypassing `MapCertification` or scene contract validation |
| Catalog entries for prototype/test maps | Setting `enabled=true` / `status=playable` without certification |
| Release-only fallback (documented) | Weakening `_fail_map_load` / `_fail_prototype_load` guards |

**Required tests before merge:** `--tier=smoke` + `--tier=certification`; `--tier=map` for bridge gameplay changes

See [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md) for fallback behavior.

---

## StreamerBase / StreamerBaseGoal finish authority

**Files:** `scripts/base/streamer_base_goal.gd`, `scenes/base/streamer_base.tscn`, `scripts/maps/race_map_controller.gd` (`_enforce_finish_contract`)

**Why protected:** PR #39 made `World/StreamerBase` (`StreamerBaseGoal`) the **sole** race finish trigger. Map `GoalCatch` zones are visual only.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Visuals on base scene (no collision/trigger behavior) | Adding a second finish trigger (map GoalCatch, Area3D, etc.) |
| Debug tests that assert single authority | Emitting `zombie_reached_base` from map scenes |
| Alignment fixes via `RaceMapDefinition.base_position` | Moving finish detection out of `StreamerBaseGoal` |

**Required tests before merge:** `--tier=smoke` + `--tier=core` (`race_finish_contract_test.gd`)

---

## Zombie `_check_out_of_bounds` fall/OOB authority

**Files:** `scripts/zombies/zombie.gd` (`_check_out_of_bounds`), `scripts/zombies/zombie_config.gd`, `scripts/maps/bridge_void_kill_zone.gd` (visual only)

**Why protected:** PR #40 made zombie min-Y and lateral checks authoritative. Map void kill zones must not kill zombies.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Death cause strings/reporting (`fell` vs `out_of_bounds`) | Re-enabling map void kill zones as authoritative |
| Applying values from `ZombieConfig` / `RaceMapDefinition` | Duplicate OOB logic in map scripts |
| Debug tests | Changing thresholds in `zombie.gd` instead of per-map config |

**Required tests before merge:** `--tier=smoke` + `--tier=core` (`void_oob_authority_test.gd`)

---

## Zombie movement / anti-clump behavior

**Files:** `scripts/zombies/zombie.gd` (`_apply_anti_clump_nudge`, locomotion), `scripts/zombies/zombie_config.gd`

**Why protected:** Movement tuning affects every race and map. Changes are hard to review when bundled with unrelated work.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Comments, dev-only diagnostics | Speed, steering, separation, or anti-clump while doing map/visual/tooling tasks |
| Config values **only** when task explicitly requests balance | Map-specific branches in `zombie.gd` |
| Visual-only zombie appearance scripts | Disabling anti-clump without regression coverage |

**Required tests before merge:** `--tier=smoke` + `--tier=core`; map tier if movement interacts with bridge layout

---

## StreamerSettingsProfile persistence

**Files:** `scripts/core/streamer_settings_profile.gd`, `user://` profile paths

**Why protected:** Corrupt or migrated settings can silently change map selection, difficulty, and streamer layout.

| Safe to change | Do not change casually |
|----------------|------------------------|
| New persisted fields with migration + tests | Breaking map id / settings index migration |
| Validation with loud warnings | Silent rewrite to City Highway without logging (except documented migration) |
| `map_selection_test.gd` coverage | Changing save format without migration |

**Required tests before merge:** `--tier=smoke` (`map_selection_test.gd`)

---

## 2D HUD / OBS-facing UI

**Files:** `scripts/ui/hud_controller.gd`, `scenes/ui/hud.tscn`, HUD layout editor scripts, race boards

**Why protected:** Streamers depend on stable OBS layout. Duplicate or hidden HUD paths caused past regressions.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Layout positions when task is explicitly HUD | Gameplay or finish logic inside HUD scripts |
| Styling when requested | Leaving duplicate active HUD/update paths |
| Debug-only overlays | Twitch/scoring integration unless task says so |

**Required tests before merge:** Task-specific; `--tier=smoke` minimum. HUD integration tests are intentionally excluded from routine tiers (see [TESTING.md](TESTING.md)).

---

## City Highway default map

**Files:** `MapCatalog.DEFAULT_MAP_ID` (`quarantine_boulevard`), `resources/maps/quarantine_boulevard.tres`, `scenes/maps/quarantine_boulevard.tscn`

**Why protected:** Production fallback and smoke baseline. Broken City Highway masks failures across the project.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Non-gameplay dressing on the map | Changing default map id without migration |
| Certified definition tweaks with tests | Relying on City Highway substitution to hide broken maps in debug/test |
| Release fallback (documented in MAP_CERTIFICATION) | Disabling certification for City Highway |

**Required tests before merge:** `--tier=smoke` + `--tier=certification`

---

## Map certification system

**Files:** `scripts/maps/map_certification.gd`, `scripts/debug/map_certification_test.gd`, `scripts/debug/test_runner.gd` (`certification` tier)

**Why protected:** PR #42 gate prevents prototype/broken maps from appearing playable in headless runs.

| Safe to change | Do not change casually |
|----------------|------------------------|
| Additional checklist items with tests | Removing or weakening guards (invalid id, fallback detection) |
| Clearer failure messages | Treating certification failures as optional |
| Adding certified map ids to `DEFAULT_CERTIFIED_MAP_IDS` after promotion | Adding slow tests to smoke tier |

**Required tests before merge:** `--tier=certification`; full checklist in [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md)

---

## Fast test runner

**Files:** `scripts/debug/test_runner.gd`, `scripts/debug/race_quick_smoke_test.gd`

**Why protected:** PR #41 set the sub-60s smoke bar used on every change.

| Safe to change | Do not change casually |
|----------------|------------------------|
| New tiers or tests outside smoke | Adding slow tests to `SMOKE_TESTS` |
| Summary output, filtering | Increasing smoke runtime above 60s target |
| Documentation | Disabling child-process isolation without cause |

**Required tests before merge:** Run `--tier=smoke` after any test_runner change and confirm runtime under 60s

---

## Quick reference: tests by system

| System | Minimum merge tests |
|--------|---------------------|
| Race lifecycle / RoundManager | smoke + core |
| GameEvents (race/finish/death) | smoke + core |
| RaceMapDefinition / MapCatalog | smoke + certification |
| RaceMapController | smoke + certification (+ map for bridge) |
| Finish authority | smoke + core |
| OOB authority | smoke + core |
| Zombie movement | smoke + core |
| StreamerSettingsProfile | smoke |
| HUD / UI | smoke (+ manual OBS check) |
| City Highway / certification | smoke + certification |
| Test runner | smoke (verify runtime) |
