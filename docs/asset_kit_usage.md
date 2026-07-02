# Zombie Apocalypse Kit Usage

Zombie Horde uses the Quaternius Zombie Apocalypse Kit as a production source asset set, not as gameplay architecture.

## Source Asset Boundary

- Raw kit files live under `res://assets/third_party/zombie_apocalypse_kit/`.
- Game scenes should prefer local wrapper scenes under `res://scenes/` instead of instancing raw kit files directly when the asset has gameplay meaning.
- Raw kit visuals are replaceable. Gameplay code must not depend on mesh names, imported collider behavior, or third-party scene internals.

## Zombie Character Policy

- The playable race contestant is currently `Zombie_Basic`.
- `Zombie_Basic.gltf` includes the required state animations for this loop: `Idle`, `Walk`, `Run`, `Crawl`, `HitReact`, `Jump`, and `Death`.
- Race crawlers should use the same contestant model and the kit `Crawl` animation. Chubby, ribcage, arm, dog, and survivor characters are reserved for future modes or visual variants, not starter contestants.
- The active wrapper scene is `res://scenes/zombies/visuals/zombie_basic_visual.tscn`.

## Physics Policy

- Imported visual assets are treated as art only.
- Gameplay collision is authored in Zombie Horde scenes and scripts.
- Road/rail/floor bodies are intentional solids.
- Mines, boosts, the base goal, and bounce obstacles use explicit trigger areas.
- Cars, cones, barriers, city props, and zombie visual meshes must not create hidden physical blockers.

## Current Fit

The low-poly kit supports the intended streamer-friendly tone: readable silhouettes, silly zombie motion, clear props, fast scene dressing, and lightweight visuals. The production risk is not the art style; the risk is letting imported art define gameplay rules. The project should keep the kit charm while owning all collisions, state changes, round flow, and Twitch join behavior.
