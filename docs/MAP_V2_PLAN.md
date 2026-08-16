# Map V2 Plan

## Goal

Build new Zombie Horde maps from one authoritative course model so visible
playable ground, collision, navigation, spawn placement, and legal race bounds
cannot drift apart.

City Highway remains the production baseline while Map V2 is developed through
disabled prototypes. Retired maps are references only; Map V2 will not patch or
extend their generation paths.

## Core Contract

Each authored course primitive must produce all of the following from the same
dimensions and transform:

1. A visible playable surface.
2. Layer-1 walk collision using `MapSurfacePiece`.
3. Navigation coverage for NPC runners.
4. A surface query used by hazards, power-ups, defenders, and spawn points.
5. Playable bounds used to derive OOB configuration.

Decorative geometry may have no collision, but it must be visually separated
from playable ground. Dressing cannot silently extend the apparent course.

## V2 Scene Contract

Every V2 map prototype will expose this structure:

```text
MapRoot
├── GameplayLayer
│   ├── Surfaces
│   ├── Boundaries
│   └── Navigation
├── VisualLayer
│   ├── PlayableSurfaceVisuals
│   └── Dressing
└── Markers
    ├── Spawn
    └── Finish
```

- `GameplayLayer/Surfaces` contains only authoritative `MapSurfacePiece` nodes.
- `PlayableSurfaceVisuals` are generated from the same primitive records as the
  matching collision surfaces.
- `Dressing` is sanitized to collision layer 0.
- Finish authority remains `World/StreamerBase` (`StreamerBaseGoal`).
- Fall and lateral OOB authority remains `Zombie._check_out_of_bounds()`.

## Authoring Model

The first version supports a deliberately small primitive set:

- Rectangular deck
- Straight ramp
- Explicit gap
- Boundary wall
- Spawn apron
- Finish apron

Each primitive owns a stable ID, transform, dimensions, surface role, and visual
material key. Curves, branches, moving platforms, and multi-level overlaps are
deferred until the basic contract is proven.

## Required Proof

A V2 prototype cannot become selectable until automated tests prove:

- Every playable visual primitive has matching enabled layer-1 collision.
- Every collision primitive has a matching playable visual.
- Collision height and visual height agree within tolerance at sampled points.
- Navigation coverage stays on authored playable surfaces.
- Object placement resolves against the actual surface at its X/Z position.
- OOB bounds enclose all playable surfaces and exclude decorative terrain.
- Spawn and finish sit on valid surfaces.
- A real NPC race reaches the authoritative finish.
- Smoke and certification remain green.

## Delivery Sequence

### Phase 1 — Stable baseline

- City Highway is the only production map.
- Legacy maps remain disabled and preserved in Git.

### Phase 2 — V2 gray-box foundation

- Add the minimal course primitive resource.
- Add one builder that emits matching visuals and `MapSurfacePiece` collision.
- Add a disabled, flat gray-box prototype.
- Add visual/collision parity and surface-height tests.

### Phase 3 — Gameplay proof

- Derive navigation and placement queries from built surfaces.
- Derive safe OOB bounds from surface extents plus an explicit margin.
- Run repeatable NPC completion tests before adding art.

### Phase 4 — First replacement map

- Design one signature course using only proven primitives.
- Add dressing after gameplay proof passes.
- Certify and promote only after manual race review.

### Phase 5 — Expansion

- Add one new primitive type at a time with its own parity tests.
- Build additional maps only from certified primitive capabilities.
- Delete legacy map files only after their useful assets have been migrated.

## Explicit Non-Goals

- No production promotion during the gray-box phase.
- No changes to zombie movement to compensate for map geometry.
- No duplicate finish or kill-zone authority.
- No invisible rescue floors under visible gaps.
- No visual-only terrain that appears to be part of the playable course.
