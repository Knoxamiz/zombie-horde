# AGENTS.md — AI development playbook

This file is the **first stop** for Cursor Cloud Agents, Codex, and local AI assistants working in this repo.

## Project

- **Engine:** Godot 4.4 (`project.godot`)
- **Game:** Zombie Horde — 3D horde race with Twitch joins, round lifecycle, signature maps
- **Main scene:** `res://scenes/main_menu/main_menu.tscn` → race in `res://scenes/main/main_game.tscn`

## Cursor Cloud specific instructions

### Environment

Godot is installed via `.cursor/environment.json` → `bash .cursor/install-godot.sh`.

After boot, verify:

```bash
godot --version
bash scripts/debug/run_tests.sh smoke
```

If Godot is missing, run `bash .cursor/install-godot.sh` manually.

### Branch naming (cloud agents)

Use `cursor/<descriptive-name>-d993` for feature branches.

### Required reading before gameplay edits

| Doc | When |
|-----|------|
| [docs/PROTECTED_SYSTEMS.md](docs/PROTECTED_SYSTEMS.md) | Any race, finish, OOB, zombie, map controller change |
| [docs/AI_DEVELOPMENT_GUARDRAILS.md](docs/AI_DEVELOPMENT_GUARDRAILS.md) | Every implementation task |
| [docs/TESTING.md](docs/TESTING.md) | Before merge |
| [CURRENT_FOCUS.md](CURRENT_FOCUS.md) | Start of every session — user's active priority |

### Test commands

```bash
# Preferred wrapper (finds godot, imports on first run)
bash scripts/debug/run_tests.sh smoke
bash scripts/debug/run_tests.sh core
bash scripts/debug/run_tests.sh map
bash scripts/debug/run_tests.sh certification

# Unified Godot CLI (import, snapshot, tests)
bash scripts/debug/run_godot.sh import
bash scripts/debug/run_godot.sh snapshot   # → artifacts/godot_project_snapshot.json
bash scripts/debug/run_godot.sh test smoke

# Direct
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
```

| Tier | When to run |
|------|-------------|
| **smoke** | Every code change (~60s target) |
| **core** | Race/finish/OOB/zombie/round changes |
| **map** | Map layout, bridge gaps, collision surfaces |
| **certification** | Promoting or changing playable maps |

### Merge gate

**Always run smoke before opening a PR.** Run core (or map/certification per guardrails) for gameplay-adjacent changes.

CI runs smoke on every PR and core on `main` push + nightly schedule.

### Godot dev stack

Full guide: [docs/GODOT_DEV_STACK.md](docs/GODOT_DEV_STACK.md)

| Tool | Purpose |
|------|---------|
| `scripts/debug/run_godot.sh` | Headless import, snapshot, test tiers |
| `addons/agent_context_exporter` | Editor: Project → Tools → Export AI Project Snapshot |
| `artifacts/godot_project_snapshot.json` | Machine-readable project index for agents |
| `.env.godot` | Engine version pin |
| `docs/GODOT_PHYSICS_LAYERS.md` | Layer/mask reference |

Cloud agents: run `bash scripts/debug/run_godot.sh snapshot` at session start to refresh the snapshot.

## Architecture anchors (do not bypass)

| System | Authority |
|--------|-----------|
| Finish | `World/StreamerBase` (`StreamerBaseGoal`) only |
| Fall / OOB | `Zombie._check_out_of_bounds()` + `gap_void_zones` on config |
| Map data | `RaceMapDefinition` + `RaceMapController` |
| Round flow | `RoundManager` states + `GameEvents` signal bus |
| Walk collision | `KitSurfaces` / `MapSurfacePiece` (layer 1) — visuals may have no physics |

## In-game dev tools (manual verification)

Debug builds only (`OS.is_debug_build()`).

1. **F3** — Dev Control Panel (tabs: Quick / Maps / Testing / Info)
2. **Stage Race** — manual launch (`require_manual_launch = true`); press **Go** or Enter to start
3. **Race Free Cam** — streamer settings; required for spray paint camera control
4. **P** — toggle spray paint (F3 panel auto-closes when paint enables)
5. **Left-drag** — spray marks; **right-drag** — look while painting
6. **Export** — writes `artifacts/dev_annotation_latest.json` + `.png`

See [docs/DEV_TOOLS_OVERVIEW.md](docs/DEV_TOOLS_OVERVIEW.md) and [docs/BUG_REPORT_WORKFLOW.md](docs/BUG_REPORT_WORKFLOW.md).

## Bug report workflow (eyes for the agent)

When the user reports a visual/map bug:

1. Ask if they attached `artifacts/dev_annotation_latest.json` (spray export)
2. If gap/bridge issue, run `broken_bridge_gap_walk_test.gd` or `--tier=map`
3. Fix using map definition / kit surfaces — **not** hardcoded zombie hacks
4. Re-run required test tier; ask user to clear spray when verified

## Task report (required end of every implementation)

| Section | Content |
|---------|---------|
| Files changed | Paths + short purpose |
| Behavior changed | Explicit "none" if test-only |
| Tests run | Exact commands |
| Test results | Pass/fail + runtime |
| Manual test needed | Yes/no + what to click |
| Remaining risks | What was not covered |

## Anti-patterns (banned unless explicitly requested)

- Silent City Highway fallback in debug/headless
- Second finish trigger competing with `StreamerBaseGoal`
- Map kill zones competing with `Zombie._check_out_of_bounds`
- Hardcoded map behavior in `zombie.gd`
- Gameplay changes hidden in debug/tooling code
- Making smoke tier slower than 60 seconds
- Map promotion without `map_certification_test.gd`

## Map-specific quick reference

| Issue | Test |
|-------|------|
| Broken Bridge gap walking | `broken_bridge_gap_walk_test.gd` |
| Bridge spawn chute | `broken_bridge_spawn_chute_test.gd` |
| Bridge pass completion | `broken_bridge_pass_completion_test.gd` |
| Kit surface collision | `multi_layer_surface_collision_test.gd` |
| Gap audit JSON | `kit_map_gap_audit_test.gd` |
| Spray paint plumbing | `dev_annotation_raycast_test.gd`, `dev_annotation_export_test.gd` |

## One task at a time

Do not bundle unrelated refactors, map work, zombie tuning, and UI polish in one change.
