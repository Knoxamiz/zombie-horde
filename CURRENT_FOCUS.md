# Current Focus

## Active Goal

Keep City Highway as the stable production baseline while a replacement Map V2
pipeline is designed and proven independently.

## Playable Maps

- `quarantine_boulevard` - City Highway

## Retired Authoring Assets

- `broken_bridge_pass` - Broken Bridge
- `spiral_descent` - Straight Descent
- `true_spiral_ramp` - Square Spiral Ramp

These assets remain in the repository for reference, but are disabled and cannot
be selected or loaded through the production map catalog.

## Evidence

- Runtime selection proof: `scripts/debug/map_selection_test.gd`
- Certification proof: `scripts/debug/map_certification_test.gd`

## Success Criteria

- [x] Settings lists exactly one playable map: City Highway.
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
