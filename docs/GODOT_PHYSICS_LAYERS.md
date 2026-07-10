# Godot physics layers

Named in `project.godot` under `[layer_names]`. Values are **bitmasks** in code.

| Layer | Name | Bit value | Used by |
|-------|------|-----------|---------|
| 1 | `walk_surfaces` | `1` | `MapSurfacePiece`, kit walk collision |
| 2 | (unused) | `2` | — |
| 3 | `zombies` | `4` | `Zombie` CharacterBody3D |
| 4 | `hazards` | `8` | Mines, sewers, obstacles (when enabled) |
| 5 | `pickups` | `16` | Boost pads, powerups |
| 6 | `streamer_base` | `32` | Finish goal trigger |

## Common masks

| Actor | `collision_layer` | `collision_mask` | Notes |
|-------|-------------------|------------------|-------|
| Zombie | 4 (layer 3) | 1 (walk) | Walks on `MapSurfacePiece` only |
| MapSurfacePiece | 1 | 0 | Static walk surface |
| Visual kit meshes | 0 | 0 | Stripped by `VisualCollisionSanitizer` |
| Void kill zones | 0 | 0 | Visual only — authority is `Zombie._check_gap_void()` |

## Spray paint / raycast

`DevAnnotationPainter` raycasts with full mask (`0x7FFFFFFF`) then falls back to deck plane for gap void **visuals** that have no physics.

## Groups

| Group | Purpose |
|-------|---------|
| `map_walk_surfaces` | `MapSurfacePiece` nodes |
| `dev_annotation_painter` | Spray paint singleton lookup |
