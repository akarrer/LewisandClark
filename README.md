# Lewis & Clark — Corps of Discovery

Pygame exploration game. Game code lives under `lewis_clark/`; JSON data under `config/`.

## Repository layout

```
LewisandClark/
├── Main                    # Launcher (calls lewis_clark.main)
├── config_loader.py        # Legacy re-export of load_all; prefer lewis_clark.config
├── requirements-dev.txt
├── config/                 # Game data: JSON only (no Python here)
├── lewis_clark/            # Application package
│   ├── main.py             # Pygame init, window, App().run()
│   ├── app.py              # Main loop, scene switching, persistence hooks
│   ├── assets.py           # Module whose attributes are filled by config.load_all()
│   ├── config.py           # Reads config/*.json and populates assets
│   ├── state.py            # Expedition / game state
│   ├── hex_grid.py         # Hex map logic and contents
│   ├── map_view.py         # Map camera / zoom / drawing region
│   ├── drawing.py          # Drawing helpers (colors, primitives)
│   ├── fonts.py            # Font loading
│   ├── save_load.py        # Save / load JSON
│   ├── screens/            # Full-screen modes (title, game, cinematic, …)
│   └── ui/                 # Reusable widgets (buttons, scroll panels, …)
├── scripts/                # One-off maintenance tools (not imported by the game)
├── tests/                  # pytest suite; shared fixtures in conftest.py
└── .github/workflows/      # CI (e.g. test.yml)
```

### Where to put changes

| What you are changing | Where |
|----------------------|--------|
| Numbers, names, map data, events, tribes, palette colors, display size | `config/*.json` — keep valid JSON; many keys are loaded in `lewis_clark/config.py` |
| **New** JSON file the game should load | Add `config/YourFile.json`, extend `load_all()` in `lewis_clark/config.py`, and ensure anything the rest of the code needs ends up on `lewis_clark.assets` (or another clear module) |
| Title / game / cinematic flow | `lewis_clark/screens/` |
| Shared UI pieces used across screens | `lewis_clark/ui/` |
| Expedition rules, inventory, movement logic | `lewis_clark/state.py` (and related helpers as appropriate) |
| Hex topology, waypoint indexing, cell contents | `lewis_clark/hex_grid.py` |
| How the map is framed or zoomed | `lewis_clark/map_view.py` |
| Low-level draw helpers | `lewis_clark/drawing.py` |
| Startup, window, or scene wiring | `lewis_clark/main.py` or `lewis_clark/app.py` |
| Automated checks for behavior | `tests/` — mirror module names when practical (`test_state.py` ↔ `state.py`) |
| Bulk refactors across the package | `scripts/` (e.g. `prefix_assets.py`); run manually, not part of normal play |

Run the game from the **repository root** so `config/` resolves correctly (`lewis_clark/config.py` expects `config` next to the package).

## Requirements

- Python 3.11 or newer (matches CI)
- A graphical environment for running the game (X11, Wayland, or Windows display)

## Development setup

Create a virtual environment, then install dev dependencies (pytest and pygame):

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

## Running unit tests

From the repository root:

```bash
python -m pytest tests/ -v
```

**Headless environments** (SSH, CI, no display): use the dummy SDL video driver so pygame can initialize:

```bash
SDL_VIDEODRIVER=dummy python -m pytest tests/ -v
```

**Skipping the pygame font smoke test** (optional):

```bash
SKIP_PYGAME_SMOKE=1 python -m pytest tests/ -v
```

Useful options:

```bash
python -m pytest tests/ -q              # quiet
python -m pytest tests/test_state.py -v # single file
python -m pytest tests/ -k "hex" -v     # name filter
```

## Running the game

From the repository root (with dev deps installed):

```bash
python Main
```

or:

```bash
python -m lewis_clark.main
```

## Continuous integration

Pull requests run the test suite on Ubuntu with Python 3.11 and 3.12 (see `.github/workflows/test.yml`), using `SDL_VIDEODRIVER=dummy` for headless pygame.
