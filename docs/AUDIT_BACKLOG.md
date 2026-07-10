# Audit backlog

Follow-up work from the Jul 2026 game audit. Ordered by priority.

## Done in PR (audit fixes branch)

- [x] Fix `broken_bridge_gap_walk_test.gd` syntax + round launch
- [x] Fix same-race restart lobby flash (`game_flow_controller.gd`)
- [x] Harden `race_restart_flow_test.gd`
- [x] Rewrite `prototype_map_load_test.gd` for `broken_bridge_pass`
- [x] Add `broken_bridge_pass` to default certification list
- [x] Scrub `broken_bridge_candidate` references in focus/docs/tests
- [x] Add `headless_race_test_boot.gd` shared helper
- [x] Wire `prototype_map_load_test` into `all` tier

## Next (high value)

- [ ] Merge PR #90 (AI dev perfection: cloud Godot + CI + AGENTS.md)
- [ ] Run **core on PRs** in GitHub Actions (or `paths:` filter for gameplay)
- [ ] Add **Broken Bridge** to `race_quick_smoke_test.gd` second scenario (keep under 60s)
- [ ] Add `moving_obstacle_reset_test.gd` to **map** tier
- [ ] Fix **pause freezes hazards** — `HazardManager` + moving obstacles respect `PAUSED`

## Medium

- [ ] Align `lane_half_width` (2.0) with kit `path_half_width` (4.5) on `broken_bridge_pass.tres`
- [ ] Wire `race_finish_contract_test` duplicate-finish scenario (`_test_no_duplicate_finish_event`)
- [ ] Promote orphan tests: `race_hud_integration_test`, `cage_lobby_ui_test`
- [ ] Add `hazard_sewer_kill_test.gd` — first headless hazard death test
- [ ] Reconcile `docs/TESTING.md` tier lists with `test_runner.gd` exactly

## Low / polish

- [ ] Godot MCP for local Cursor sessions (scene tree awareness)
- [ ] Screenshot diff for map visuals
- [ ] `DevToolsSelfCheck` includes annotation painter wiring
- [ ] Nightly CI **map** tier on schedule

## Manual verify after merge

1. Broken Bridge: Stage → Go → gap void falls
2. Spray paint on gap → Export → JSON has points
3. Same-race restart (Enter) after round end
4. Pause (Backspace) during race — confirm intended hazard behavior
