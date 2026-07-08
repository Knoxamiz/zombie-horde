# AI Development Guardrails

Permanent rules for **Cursor**, **Codex**, and human contributors working in this repo. These guardrails do not replace code review; they prevent silent regressions in hardened systems (PRs #38–#42).

Related docs:

- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md) — what is protected and why
- [TESTING.md](TESTING.md) — test tiers and commands
- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md) — map promotion gate

---

## 1. General AI rules

1. **One task at a time.** Do not bundle unrelated refactors, map work, zombie tuning, and UI polish in one change.
2. **No broad refactors** without an explicit user request (rename-everything, architecture rewrites, “cleanup while here”).
3. **No silent fallbacks in debug/headless.** Invalid map loads must fail loudly. See `RaceMapController._should_refuse_city_highway_fallback()`.
4. **No gameplay changes hidden inside tooling work.** Debug analyzers, map lab, and test scripts must not alter race/finish/OOB/movement behavior.
5. **No map promotion without certification.** Playable maps require `map_certification_test.gd` and checklist in [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md).
6. **No zombie movement edits without regression tests.** At minimum `--tier=smoke` + `--tier=core`.
7. **No UI / Twitch / scoring edits** unless the task explicitly says so.

When in doubt, read [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md) before editing.

---

## 2. Required test matrix

| Task type | Headless tests |
|-----------|----------------|
| **Docs only** (no code) | None required |
| **Small code task** (isolated fix, no protected systems) | `--tier=smoke` |
| **Race lifecycle** (`round_manager.gd`, `round_config`, lifecycle HUD wiring) | `--tier=smoke` + `--tier=core` |
| **Finish / OOB / zombie authority** | `--tier=smoke` + `--tier=core` |
| **Zombie movement / anti-clump** | `--tier=smoke` + `--tier=core` |
| **Map content / catalog / controller** | `--tier=smoke` + `--tier=certification` + relevant map test |
| **Bridge map gameplay** | Above + `broken_bridge_real_gameplay_test.gd --zombies=5 --skip-stress` (or `--tier=map`) |
| **Before merge (any gameplay-adjacent PR)** | `--tier=smoke` + any deeper tier from this table |

### Commands

```bash
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=core
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=certification
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=map
```

Tier details: [TESTING.md](TESTING.md).

---

## 3. Standard task ending

Every Cursor/Codex implementation report **must** include:

| Section | Content |
|---------|---------|
| **Files changed** | Paths and short purpose per file |
| **Behavior changed** | Explicit “none” if docs-only or test-only |
| **Tests run** | Exact commands |
| **Test results** | Pass/fail and runtime (especially smoke seconds) |
| **Manual test needed** | Yes/no and what to click/watch in editor |
| **Remaining risks** | What was not covered |

---

## 4. Anti-patterns (banned unless explicitly requested)

| Anti-pattern | Why banned |
|--------------|------------|
| Silently falling back to City Highway in debug/headless | Masks broken maps; violates PR #42 |
| Adding a second finish trigger | Violates PR #39 single finish contract |
| Map kill zones that compete with `Zombie._check_out_of_bounds` | Violates PR #40 OOB authority |
| Hardcoding map-specific behavior in `zombie.gd` | Unmaintainable; bypasses `RaceMapDefinition` |
| Changing zombie movement while building visual tools | Unreviewable side effects |
| Making smoke slow again (>60s target) | Violates PR #41 fast smoke runner |
| Enabling prototype maps as playable without certification | Violates map certification gate |
| Leaving hidden duplicate UI/HUD paths active | OBS/layout regressions |
| Ignoring `MAP LOAD FAILED` / `MAP CERTIFICATION FAILED` in logs | Fake green tests |
| Disabling certification guards to “make tests green” | Breaks map safety net |

---

## 5. Map rules

1. **New maps start as prototype or test only** — `enabled=false` or `enabled_for_testing=true`, not production playable.
2. **Must use `RaceMapDefinition`** — spawn, goal, base, OOB, hazards, camera data live in `.tres` + scene contract.
3. **Must pass map certification before playable** — see [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md).
4. **Must not hijack camera** — spectator camera is framed by `RaceMapController`; map scene cameras stay disabled.
5. **Must not add competing `GoalCatch`** — finish authority is `World/StreamerBase` only.
6. **Must not add authoritative void kill zones** — `bridge_void_kill_zone.gd` is visual-only.
7. **Must not rely on City Highway fallback** — fix the map; fallback is release-only safety net.

Promotion checklist: certification → finish contract → OOB (if bridge) → bridge gameplay test (if bridge) → add to `MapCertification.DEFAULT_CERTIFIED_MAP_IDS`.

---

## 6. Zombie rules

1. **Zombie movement is protected** — see [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md).
2. **OOB / fell authority stays in `Zombie._check_out_of_bounds()`** — not in map scripts.
3. **Per-map values come from `RaceMapDefinition` / `ZombieConfig`** — applied by `RaceMapController`.
4. **No special-case map hacks in `zombie.gd`** without explicit approval and tests.
5. **Death causes:** use `fell` (min-Y) and `out_of_bounds` (lateral) distinctly in reports — see [TESTING.md](TESTING.md).

---

## 7. Testing rules

1. **Keep smoke under 60 seconds** — `race_quick_smoke_test.gd` + `map_selection_test.gd` only.
2. **Do not add slow tests to smoke** — use core, map, certification, or all tiers.
3. **Slow movement / map stress** → `broken_bridge_real_gameplay_test.gd`, `race_lifecycle_smoke_test.gd`, or `--tier=map` / `--tier=core`.
4. **Fail loud with clear messages** — print map id and failed requirement; use `push_error` for certification/load failures.
5. **Do not treat City Highway in logs as success** when another map was requested.

---

## Cursor rules (`.cursor/rules/`)

Project rules ship as `.mdc` files for Cursor:

| File | Scope |
|------|--------|
| `.cursor/rules/project-guardrails.mdc` | Global — always applied |
| `.cursor/rules/maps.mdc` | Map scripts, scenes, resources |
| `.cursor/rules/zombies.mdc` | Zombie scripts and scenes |
| `.cursor/rules/testing.mdc` | Debug tests and testing docs |

Keep these files aligned with this document when guardrails change.

---

## Architecture anchors (do not bypass)

| Concern | Authority |
|---------|-----------|
| Race finish | `World/StreamerBase` → `StreamerBaseGoal` |
| Fall / OOB death | `Zombie._check_out_of_bounds()` + `ZombieConfig` |
| Map geometry & bounds | `RaceMapDefinition` + `RaceMapController` |
| Round flow | `RoundManager` + `GameEvents` |
| Map load validation | `MapCertification` + `map_certification_test.gd` |
| Default production map | `quarantine_boulevard` (City Highway) |
