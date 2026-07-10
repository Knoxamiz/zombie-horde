# Bug report workflow (human → AI)

Use this when you find a bug in-game and want the agent to fix it without guesswork.

## Why spray paint exists

Headless tests catch logic regressions. **Spray paint gives the agent coordinates and context** for visual/layout bugs (gap voids, misaligned tiles, wrong collision) that are hard to describe in text.

## Steps

### 1. Reproduce in a debug build

- Run from Godot editor (F5) or debug export — not release
- Load into race (`main_game.tscn` via START)
- **Stage Race** (manual launch — no auto countdown)

### 2. Enable free cam + spray

- Streamer settings → **Race Free Cam** on
- **F3** → Quick tab → **Spray paint mode** (or press **P**)
  - Panel auto-closes so you can paint
- Pick color: **Bug** (red), **Visual** (yellow), **Should walk** (green)
- Optional: add a short note in the note field

### 3. Mark the problem

- **Left-drag** on the bad area (road, gap void, lip tile, etc.)
- **Right-drag** to reposition camera without exiting paint
- **Esc** or **P** to exit paint mode

### 4. Export

- **F3** → Export (or Export button in spray card)
- Writes:
  - `artifacts/dev_annotation_latest.json` — stroke points, map id, camera pose
  - `artifacts/dev_annotation_latest.png` — screenshot

### 5. Send to the agent

Choose one:

| Method | When |
|--------|------|
| **Commit both files** | Working with cloud agent on same branch |
| **Attach to GitHub issue** | Async bug report |
| **Paste JSON in chat** | Quick one-off |

### 6. Open agent task with template

```
Map: broken_bridge_candidate
Bug: zombies walk on black gap void (should fall)
Spray: artifacts/dev_annotation_latest.json attached
Expected: fall through void outside crossing width
Do not touch: finish contract, OOB authority
Run: broken_bridge_gap_walk_test.gd + smoke tier
```

## After the fix

1. Agent runs headless tests and opens PR
2. You verify in-game
3. **Clear** spray marks when done (F3 → Clear)

## When spray is not enough

Add a headless test so the bug never returns:

```bash
godot --headless --path . -s res://scripts/debug/broken_bridge_gap_walk_test.gd
```

See [TESTING.md](TESTING.md) for tier requirements.

## Troubleshooting spray

| Symptom | Fix |
|---------|-----|
| Paint: unavailable | Reload race scene; check F3 self-check |
| No stamps on drag | Close F3 panel; enable Race Free Cam |
| Stamps on road but not gap | Fixed in PR #89+ (deck-plane fallback) |
| Export empty | Left-drag at least one stroke before Export |
