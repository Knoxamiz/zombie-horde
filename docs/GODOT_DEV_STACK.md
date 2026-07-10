# Godot development stack

How this project uses Godot 4.4 natively for human + AI development.

## Philosophy

Use Godot's built-in strengths instead of fighting them:

| Godot feature | How we use it |
|---------------|---------------|
| **SceneTree headless tests** | `scripts/debug/*_test.gd` — fast CI, no extra frameworks |
| **Resources (`.tres`)** | Map definitions, configs — data-driven, agent-readable |
| **Signals / autoloads** | `GameEvents` bus — decoupled systems |
| **class_name** | Global types agents can reference (`RoundManager`, `MapCatalog`) |
| **Physics layers** | Named in `project.godot` — walk/zombie/hazard layers |
| **InputMap** | Runtime setup via `InputMapSetup` + documented actions |
| **EditorPlugin** | `addons/agent_context_exporter` — snapshot for local AI |
| **Headless CLI** | `--headless`, `--import`, `--display-driver headless` |
| **GDScript LSP** | `godot-tools` VS Code/Cursor extension |

## Quick commands

```bash
# Install Godot (cloud agents + local Linux)
bash .cursor/install-godot.sh

# Import project (required once per clean checkout)
bash scripts/debug/run_godot.sh import

# Run tests
bash scripts/debug/run_godot.sh test smoke
bash scripts/debug/run_tests.sh core

# Export machine-readable project snapshot for agents
bash scripts/debug/run_godot.sh snapshot
# → artifacts/godot_project_snapshot.json
```

## Local Cursor + Godot editor (full power)

### 1. Godot Tools extension

Install **geequl.godot-tools** (recommended in `.vscode/extensions.json`).

- Open Godot editor with this project
- Editor → Editor Settings → Text Editor → External → enable **Use External Editor**
- Point to Cursor; flags: `{project} --goto {file}:{line}:{col}`

This gives agents + you: real GDScript LSP, go-to-definition against engine API.

### 2. MCP (optional — live editor eyes)

Copy `.cursor/mcp.json.example` → `.cursor/mcp.json` and adjust paths.

MCP servers can read live scene trees, run scenes, and capture editor errors. Best for **local** sessions when Godot editor is open.

Cloud agents use **headless snapshot + spray JSON** instead.

### 3. Editor plugin — Agent Context Exporter

Enabled in `project.godot`. In Godot:

**Project → Tools → Export AI Project Snapshot**

Writes `artifacts/godot_project_snapshot.json` with open scenes, edited root, playable maps.

## Cloud agents

1. `.cursor/environment.json` installs Godot + imports project on boot
2. Read `artifacts/godot_project_snapshot.json` after `run_godot.sh snapshot`
3. Read `AGENTS.md` + `CURRENT_FOCUS.md`
4. Run `bash scripts/debug/run_tests.sh smoke` before every PR

## Headless test patterns

```gdscript
extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var main_game: Node = ...
    # Use HeadlessRaceTestBoot helpers for race integration tests
    print("SUITE RESULT: PASSED")
    quit(0)
```

Rules:

- Always `add_child` scene roots to `root` before `_ready()`-dependent logic
- Use `configure_immediate_launch_for_tests()` for round tests
- Call `launch_round()` if stuck in `COUNTDOWN` with manual launch enabled
- Disable hazards in tests unless testing hazards

## Physics layers

See [GODOT_PHYSICS_LAYERS.md](GODOT_PHYSICS_LAYERS.md).

## CI environment variables

| Variable | Purpose |
|----------|---------|
| `GODOT_DISABLE_LEAK_CHECKS=1` | Prevent false CI failures from leak warnings |
| `GODOT_VERSION` | Pinned in `.env.godot` |

## Optional future: GUT

[GUT](https://github.com/bitwes/Gut) adds unit-test syntax + signal assertions. This repo uses native SceneTree tests for speed. GUT can be added under `addons/gut/` if we want `@test` style tests — not required today.

## Related docs

- [AI_DEV_SETUP.md](AI_DEV_SETUP.md) — four-loop agent workflow
- [TESTING.md](TESTING.md) — test tiers
- [AUDIT_BACKLOG.md](AUDIT_BACKLOG.md) — roadmap
