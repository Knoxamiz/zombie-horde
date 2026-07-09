# Dev Tools Overview

Debug-only tooling for local race testing. **Nothing in this document applies to release/export builds** — dev UI is removed when `OS.is_debug_build()` is false.

Related docs:

- [TESTING.md](TESTING.md) — automated headless test tiers
- [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md) — what not to change casually
- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md) — race/finish/OOB authority

---

## How to open the dev panel

1. Run the game from the **editor** or a **debug export** (not a release build).
2. Load into the race scene (`main_game.tscn` via **START** from the main menu).
3. Press **F3** to open the **Dev Control Panel**.
4. Press **F3** again or **Esc** to close it.

A small hint appears in the bottom-right corner in debug builds: **Dev Tools: Press F3**.

---

## What to click first

Recommended first-time flow:

1. **Run Dev Tools Self Check** (top of panel) — confirms systems are wired.
2. **Fake Viewer Simulator → Sim 5** — queue a few test viewers.
3. **Race Controls → Start Race** — run a short test loop.
4. **Active Config Inspector → Copy / Print Config Snapshot** — verify map/runtime values.
5. Optional: enable **Zombie Flow Analyzer** and run another race to see spawn/finish/death markers.

---

## Panel sections

| Section | What it does |
|---------|----------------|
| **Dev Tools Home** | Overview of all tools + **Run Dev Tools Self Check** |
| **Race Controls** | Start, reset, force-end, or return to lobby for a test race. |
| **NPC Controls** | Add 1/5/20 random NPC joins or clear the join queue. |
| **Fake Viewer Simulator** | Add fake stream viewers (tier mix) without Twitch. |
| **Active Config Inspector** | Read-only runtime map/round/zombie config after map load. |
| **Zombie Flow Analyzer** | Shows where zombies spawn, finish, fall, die, or get stuck (markers + console report). |
| **Performance / Stress Profiler** | Measures FPS with 20/100/250/500 simulated viewers. |
| **Debug Toggles** | Blueprint debug layer for prototype maps (when available). |

### Short descriptions

- **Race Controls:** start, reset, or force-end a test race.
- **NPC Controls:** manually queue individual test joins.
- **Map info:** active map id appears in Self Check and Active Config Inspector.
- **Active Config Inspector:** read-only snapshot of loaded map and race settings.
- **Fake Viewer Simulator:** add fake stream viewers without Twitch.
- **Zombie Flow Analyzer:** shows where zombies spawn, finish, fall, die, or get stuck.
- **Performance Profiler:** measures FPS with 20/100/250/500 zombies.

---

## What to ignore for now

| Item | Why |
|------|-----|
| **Blueprint Debug Layer** | Map-lab overlay only; not needed for normal race testing. |
| **Stress 250 / 500** | Heavy manual runs; start with Stress 20 or 100. |
| **Trickle / Burst sim modes** | Stream soak testing; use **Sim 5/20** first. |
| **Zombie Flow markers** | Optional diagnostics; disable when not analyzing a race. |
| Old open HUD PR branches (#5, #6, #14) | Superseded by current dev panel; do not merge without rebasing. |

---

## Automated tests vs dev tools

| Tier | Command | When to use |
|------|---------|-------------|
| **smoke** | `godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke` | After almost every code change (~6s). |
| **core** | `--tier=core` | Race lifecycle, finish, OOB changes (~7 min). |
| **certification** | `--tier=certification` | Map controller / map promotion gate. |
| **map** | `--tier=map` | Map content + light Broken Bridge gameplay. |
| **all** | `--tier=all` | Broader pre-release sweep. |

**smoke** is the merge gate. **certification** is for map promotion, not routine edits. Dev panel tools are **manual** and complement — but do not replace — headless tests.

Standalone dev-tool tests (not in smoke):

```bash
godot --headless --path . -s res://scripts/debug/fake_viewer_simulator_test.gd
godot --headless --path . -s res://scripts/debug/zombie_flow_analyzer_test.gd
godot --headless --path . -s res://scripts/debug/performance_stress_profiler_test.gd
```

---

## Self check output

Press **Run Dev Tools Self Check** to print:

```
DEV TOOLS SELF CHECK
- Dev panel loaded: yes
- RoundManager found: yes
- DebugJoinSource found: yes
- RaceMapController found: yes
- FakeViewerSimulator found: yes
- ActiveConfigInspector found: yes
- ZombieFlowAnalyzer available: yes
- PerformanceStressProfiler available: yes
- Active map id: city_highway
- Current round state: Idle
```

This check is read-only and does not change gameplay.
