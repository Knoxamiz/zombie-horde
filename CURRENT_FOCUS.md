# Current focus

Update this file at the start of each dev session. Agents read it first.

## Active goal

Raise Broken Bridge deck, support pillars, and water level for a more dramatic elevated span.

## Map / area

<!-- e.g. broken_bridge_pass, quarantine_boulevard, lobby -->
`broken_bridge_pass`

## Evidence

<!-- Link or path to spray export, issue, or test failure -->
- Spray export: `artifacts/dev_annotation_latest.json` (attach when reporting visual bugs)
- Gap test: `scripts/debug/broken_bridge_gap_walk_test.gd`

## Success criteria

<!-- How do we know we're done? -->
- [ ] `bash scripts/debug/run_tests.sh smoke` passes
- [ ] `bash scripts/debug/run_tests.sh map` passes for bridge work
- [ ] Manual: zombies fall through gap void outside crossing width
- [ ] Spray paint: left-drag marks gaps, Export produces JSON with points

## Do not touch (this session)

<!-- Protected systems or unrelated areas -->
- Finish contract (`StreamerBaseGoal`)
- OOB authority (`Zombie._check_out_of_bounds`)
- Twitch / scoring / HUD layout (unless explicitly requested)

## Notes

<!-- Freeform context for the agent -->
- Manual race start: Stage Race → Go (no auto countdown)
- F3 dev panel: Quick tab has spray paint at top
- Cloud agents need `.cursor/environment.json` for Godot
