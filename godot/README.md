# Lewis & Clark — Godot spike

Third-person 3D prototype (see `docs/adr/0007-third-person-3d-in-godot.md`): Lewis walking
Council Bluff country in August 1804 with the Corps, a Day Clock, and Trail Moments.

## Setup

1. Install Godot 4.7 (standard, not .NET): `winget install GodotEngine.GodotEngine`
2. Fetch the CC0 assets (not committed): `python godot/tools/fetch_assets.py`
3. Import once: `godot --headless --path godot --import`

The baked terrain in `data/terrain/` is committed. To rebuild it from the USGS tiles (after
step 2): `python godot/tools/build_heightmap.py` — this also writes a shaded-relief preview.

## Run

- Play: `godot --path godot`
- Tests: `godot --headless --path godot -s tests/run_tests.gd`
- Hands-free playthrough with screenshots and frame times:
  `godot --path godot -- --autopilot --fast-moments --shots=<dir>`

## Controls

| | Keyboard / mouse | Controller |
|---|---|---|
| Walk / jog | WASD (click to capture mouse) | Left stick (half tilt walks) |
| Look | Mouse | Right stick |
| Sprint | Shift | L3 |
| Interact | E / Enter | A |
| Release mouse | Esc | Start |

## Layout

- `scripts/rules/` — engine-agnostic rules ported from the Python build (`ExpeditionState`, `TrailMomentDirector`)
- `scripts/world/` — terrain (real USGS elevation, 1804 river course), foliage, sky and weather, props
- `tools/build_heightmap.py` — bakes `data/terrain/` from USGS 3DEP tiles
- `scripts/player/` — the Leader's third-person controller and the Corps following behind
- `data/trail_moments.json` — the six spike Trail Moments
- `assets/ASSETS.json` — third-party asset manifest (all CC0, Quaternius)
