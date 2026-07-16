# Current Focus

## Active Goal

One authoritative map catalog and loader: every selectable map must resolve from
the same catalog entry, definition resource, and scene path.

## Playable Maps

- `quarantine_boulevard` - City Highway
- `broken_bridge_pass` - Broken Bridge
- `spiral_descent` - Straight Descent
- `true_spiral_ramp` - Square Spiral Ramp

## Evidence

- Runtime selection proof: `scripts/debug/map_selection_test.gd`
- Certification proof: `scripts/debug/map_certification_test.gd`

## Success Criteria

- [x] Settings lists exactly the four playable maps above.
- [x] Each selection loads its matching definition and scene.
- [x] Failed loads report an error instead of swapping in another map.
- [x] Smoke suite passes.
- [x] Certification suite passes.

## Do Not Touch

- Finish contract: `StreamerBaseGoal`
- OOB authority: `Zombie._check_out_of_bounds`
- Twitch, scoring, and HUD layout unless the user explicitly requests it.

## Map Contract

- Catalog: `scripts/maps/map_catalog.gd`
- Loader: `scripts/maps/race_map_controller.gd`
- Definition: `resources/maps/<map_id>.tres`
- Scene: `scenes/maps/<map_id>.tscn`
- Disabled assets may be retained for authoring, but the game cannot select or load them.
