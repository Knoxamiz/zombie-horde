# AI development setup

How this repo is configured for human + AI collaborative game development.

## The four loops

| Loop | What | Where |
|------|------|-------|
| **Brain** | Rules, architecture, priorities | `AGENTS.md`, `.cursor/rules/`, `docs/AI_DEVELOPMENT_GUARDRAILS.md` |
| **Hands** | Edit code + run tests | Godot headless, `scripts/debug/run_godot.sh`, GitHub Actions |
| **Eyes** | Spatial bug reports | Spray paint → `artifacts/dev_annotation_latest.json` |
| **Memory** | CI + docs prevent repeat failures | `.github/workflows/godot-tests.yml`, `artifacts/godot_project_snapshot.json` |

## Quick start for humans

### Local (Windows)

1. Godot 4.4 — open `project.godot`
2. Read [AI_DEVELOPMENT_GUARDRAILS.md](AI_DEVELOPMENT_GUARDRAILS.md)
3. Before commits: `godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke`

### Cursor Cloud Agents

1. `.cursor/environment.json` installs Godot, imports project, and exports snapshot on boot
2. Agent reads `AGENTS.md`, `CURRENT_FOCUS.md`, and `artifacts/godot_project_snapshot.json`
3. Agent runs `bash scripts/debug/run_tests.sh smoke` before every PR

### Reporting a bug to the agent

See [BUG_REPORT_WORKFLOW.md](BUG_REPORT_WORKFLOW.md).

## Files in this setup

| File | Purpose |
|------|---------|
| [AGENTS.md](../AGENTS.md) | Primary AI playbook (cloud + local) |
| [CURRENT_FOCUS.md](../CURRENT_FOCUS.md) | Living session brief — update when starting work |
| [.cursor/environment.json](../.cursor/environment.json) | Cloud agent Godot install + import + snapshot |
| [.cursor/install-godot.sh](../.cursor/install-godot.sh) | Idempotent Godot 4.4 download |
| [.env.godot](../.env.godot) | Godot version pin |
| [scripts/debug/run_godot.sh](../scripts/debug/run_godot.sh) | Unified headless CLI (import/snapshot/test) |
| [scripts/debug/run_tests.sh](../scripts/debug/run_tests.sh) | Test wrapper script |
| [docs/GODOT_DEV_STACK.md](GODOT_DEV_STACK.md) | Full Godot-native dev guide |
| [.github/workflows/godot-tests.yml](../.github/workflows/godot-tests.yml) | CI: smoke on PR, core on main |
| [artifacts/README.md](../artifacts/README.md) | What to commit vs ignore |

## CI behavior

| Trigger | Tests |
|---------|-------|
| Pull request | smoke |
| Push to `main` | smoke → core |
| Nightly (06:00 UTC) | smoke → core |
| Manual dispatch | choose tier |

## Session workflow

1. Update `CURRENT_FOCUS.md` with goal, map, constraints
2. If visual bug: spray → export → commit or attach JSON to issue
3. One focused task per agent run
4. Agent runs tests → opens PR → CI confirms
5. You do quick manual verify → merge

## Related docs

- [TESTING.md](TESTING.md) — test tiers and commands
- [DEV_TOOLS_OVERVIEW.md](DEV_TOOLS_OVERVIEW.md) — F3 dev panel
- [PROTECTED_SYSTEMS.md](PROTECTED_SYSTEMS.md) — do not break casually
- [MAP_CERTIFICATION.md](MAP_CERTIFICATION.md) — map promotion gate
