# Testing

Headless Godot tests live under `scripts/debug/`. Use the unified runner for pre/post change checks.

## Quick start

```bash
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
```

## Tiers

| Tier | Command | Purpose |
|------|---------|---------|
| **smoke** | `--tier=smoke` | Fast sanity check after almost every task |
| **core** | `--tier=core` | Deeper contract + lifecycle regression |
| **map** | `--tier=map` | Map catalog + lightweight Broken Bridge gameplay |
| **certification** | `--tier=certification` | Map catalog + strict per-map certification gate |
| **all** | `--tier=all` | Broader stable debug suite |

### smoke (target under 60 seconds)

- `race_quick_smoke_test.gd` — minimum loop: boot, join, RUNNING, quick finish, reset, rejoin (City Highway + Broken Bridge TEST)
- `map_selection_test.gd` — catalog, profile migration, runtime map load

**When to run:** before and after every automated code change.

**Required before merge:** yes (minimum bar).

### core (~7 minutes)

- `race_lifecycle_smoke_test.gd` — full finish + timeout lifecycle on both maps
- `race_finish_contract_test.gd` — single finish authority
- `void_oob_authority_test.gd` — deck safety, fall death, lateral OOB
- `map_selection_test.gd` — catalog and runtime load

**When to run:** before merging race loop, map, zombie, or round-manager changes.

**Required before merge:** yes for gameplay-adjacent PRs.

### map (~5–8 minutes)

- `map_selection_test.gd`
- `broken_bridge_real_gameplay_test.gd --zombies=5 --skip-stress`

**When to run:** before merging map content, bridge layout, or map controller changes.

**Required before merge:** recommended for map PRs; not required for docs-only changes.

### certification (~2–4 minutes)

- `map_selection_test.gd`
- `map_certification_test.gd` — City Highway + Broken Bridge TEST (catalog, load, contracts, mini race, reset)

**When to run:** before merging map controller, map catalog, or promoting a map to playable.

**Required before merge:** yes for map certification / map controller PRs. See [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md).

**Not in smoke:** certification stays on its own tier to keep smoke under 60 seconds.

### all (~12–18 minutes)

Core + map tiers, plus stable unit/integration debug suites:

- `race_finish_window_test.gd`
- `podium_results_test.gd`
- `supporter_upgrade_test.gd`
- `zombie_color_variant_test.gd`
- `streaming_bootstrap_test.gd`
- `lobby_empty_boot_test.gd`
- `prototype_map_load_test.gd`

**When to run:** before release branches or large refactors.

**Required before merge:** optional; use core as the merge gate.

## Intentionally excluded from `all`

| Test | Reason |
|------|--------|
| `broken_bridge_real_gameplay_test.gd` (default 5/20/100) | Too slow for routine runs; map tier uses `--zombies=5 --skip-stress` |
| `zombie_flow_analyzer_test.gd` | Experimental; requires dev-only ZombieFlowAnalyzer wiring |
| `twitch_channel_setup_test.gd` | External Twitch integration |
| `race_hud_integration_test.gd` | Heavy HUD scene integration |
| `hud_layout_*_test.gd` | HUD layout editor tooling |
| `cage_lobby_ui_test.gd`, `lobby_cage_mine_test.gd` | Lobby UI flows |
| `main_menu_join_feed_test.gd` | Menu feed integration |
| `map_lab_material_uid_test.gd` | Map lab / editor only |

## Running individual tests

Individual scripts still work directly:

```bash
godot --headless --path . -s res://scripts/debug/race_quick_smoke_test.gd
godot --headless --path . -s res://scripts/debug/race_lifecycle_smoke_test.gd
godot --headless --path . -s res://scripts/debug/race_finish_contract_test.gd
godot --headless --path . -s res://scripts/debug/void_oob_authority_test.gd
godot --headless --path . -s res://scripts/debug/map_selection_test.gd
godot --headless --path . -s res://scripts/debug/map_certification_test.gd
godot --headless --path . -s res://scripts/debug/map_certification_test.gd -- --map_id=quarantine_boulevard
godot --headless --path . -s res://scripts/debug/broken_bridge_real_gameplay_test.gd -- --zombies=5 --skip-stress
godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=certification
```

## Death cause categories (debug reports)

| Cause | Category |
|-------|----------|
| `fell` | Fall below river/void threshold (`out_of_bounds_min_y`) |
| `out_of_bounds` | Lateral X/Z bounds |
| `sewer` | Sewer hazard |

Do not lump `fell` into generic "killed/other" buckets in debug reports.

## Exit codes

- `0` — all tests in the tier passed
- `1` — one or more tests failed

Failed test names are printed in the `TEST RUNNER RESULT` summary. Smoke tier also prints `smoke target` and `smoke status`.
