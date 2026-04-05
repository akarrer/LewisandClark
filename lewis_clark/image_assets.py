"""Load PNG game art from assets/images/.

Static art is committed to the repo (regenerate via ``scripts/bake_game_assets.py``).

8-bit authoring (Dwarf Fortress–style):
- Portraits: native 48×60; per-character outer frame + light mat behind the bust (readability); ink outlines; nearest-neighbor scaling in UI.
- Hex terrain: 160×148 tiles; no smooth blur when scaling.
- Cinematic panels: 840×900 for SW=1400 (60% art column); same chunky-pixel look.
- Compass rose: ``compass_rose.png`` (128×128), produced by ``compass_rose.render_compass_rose_surface``.
- Louisiana cartouche: ``louisiana_cartouche.png`` (~537×360), from ``louisiana_cartouche.render_louisiana_cartouche_surface``.
- If a required file is missing at runtime, a RuntimeError is raised unless the
  environment variable ``LEWIS_CLARK_ALLOW_PROCEDURAL_ASSETS=1`` is set, in which
  case :func:`lewis_clark.pixel_assets_bake.bake_all_to_disk` is invoked once.
"""

from __future__ import annotations

import os
from pathlib import Path

import pygame

from lewis_clark import assets

_REPO = Path(__file__).resolve().parent.parent
IMG_DIR = _REPO / "assets" / "images"
ANIMAL_DIR = IMG_DIR / "animals"

_FILENAMES = {
    "title": "title_bg.png",
    "parchment": "parchment_tile.png",
    "compass_rose": "compass_rose.png",
    "louisiana_cartouche": "louisiana_cartouche.png",
    "terrains": {
        "plains": "terrain_plains.png",
        "river": "terrain_river.png",
        "mountain": "terrain_mountain.png",
        "forest": "terrain_forest.png",
        "coast": "terrain_coast.png",
    },
    "portraits": {
        "lewis": "portrait_lewis.png",
        "clark": "portrait_clark.png",
        "york": "portrait_york.png",
        "drouillard": "portrait_drouillard.png",
        "sacagawea": "portrait_sacagawea.png",
        "inactive": "portrait_inactive.png",
    },
    "figures": {
        "jefferson": "portrait_jefferson.png",
        "napoleon": "portrait_napoleon.png",
        "corps": "portrait_corps.png",
    },
    "waypoints": {
        "fort": "waypoint_fort.png",
        "pass": "waypoint_pass.png",
        "dead_end": "waypoint_dead_end.png",
        "junction": "waypoint_junction.png",
        "camp": "waypoint_camp.png",
    },
    "cinematics": {
        "secret_message": "cine_secret_message.png",
        "napoleon": "cine_napoleon.png",
        "lewis_prepares": "cine_lewis_prepares.png",
        "clark_recruited": "cine_clark_recruited.png",
        "corps_assembled": "cine_corps_assembled.png",
        "the_river": "cine_the_river.png",
        "depart": "cine_depart.png",
    },
    "animals": {
        "grizzly": "animal_grizzly.png",
        "buffalo": "animal_buffalo.png",
        "elk": "animal_elk.png",
        "generic": "animal_generic.png",
    },
}


def _required_paths() -> list[Path]:
    paths: list[Path] = [
        IMG_DIR / _FILENAMES["title"],
        IMG_DIR / _FILENAMES["parchment"],
        IMG_DIR / _FILENAMES["compass_rose"],
        IMG_DIR / _FILENAMES["louisiana_cartouche"],
    ]
    paths.extend(IMG_DIR / n for n in _FILENAMES["terrains"].values())
    paths.extend(IMG_DIR / n for n in _FILENAMES["portraits"].values())
    paths.extend(IMG_DIR / n for n in _FILENAMES["figures"].values())
    paths.extend(IMG_DIR / n for n in _FILENAMES["waypoints"].values())
    paths.extend(IMG_DIR / n for n in _FILENAMES["cinematics"].values())
    paths.extend(ANIMAL_DIR / n for n in _FILENAMES["animals"].values())
    return paths


def ensure_png_assets(sw: int, sh: int) -> None:
    """Verify committed PNGs exist, or optionally regenerate (dev only)."""
    del sw, sh  # display size; baked assets are fixed resolution
    missing = [p for p in _required_paths() if not p.exists()]
    if not missing:
        return
    if os.environ.get("LEWIS_CLARK_ALLOW_PROCEDURAL_ASSETS") != "1":
        names = "\n".join(f"  - {p.relative_to(_REPO)}" for p in missing[:20])
        more = f"\n  ... and {len(missing) - 20} more" if len(missing) > 20 else ""
        raise RuntimeError(
            "Missing static image file(s). Run from repo root:\n"
            "  PYTHONPATH=. python3 scripts/bake_game_assets.py\n"
            f"Missing:\n{names}{more}"
        )
    from lewis_clark.pixel_assets_bake import bake_all_to_disk

    bake_all_to_disk()


def load_game_images() -> None:
    """After pygame.display.set_mode: load PNGs onto assets (with convert_alpha)."""
    ensure_png_assets(assets.SW, assets.SH)

    def _load(path: Path) -> pygame.Surface | None:
        if not path.exists():
            return None
        try:
            s = pygame.image.load(str(path))
            return s.convert_alpha()
        except Exception:
            return None

    assets.IMG_TITLE_BG = _load(IMG_DIR / _FILENAMES["title"])
    assets.IMG_COMPASS_ROSE = _load(IMG_DIR / _FILENAMES["compass_rose"])
    assets.IMG_LOUISIANA_CARTOUCHE = _load(IMG_DIR / _FILENAMES["louisiana_cartouche"])
    tile = _load(IMG_DIR / _FILENAMES["parchment"])
    assets.IMG_PARCHMENT_TILE = tile
    if tile is not None:
        assets.TEX_PARCHMENT = tile

    assets.IMG_TERRAIN_HEX = {}
    for terr, name in _FILENAMES["terrains"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_TERRAIN_HEX[terr] = im

    assets.IMG_PORTRAITS = {}
    for pk, name in _FILENAMES["portraits"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_PORTRAITS[pk] = im

    assets.IMG_FIGURES = {}
    for fk, name in _FILENAMES["figures"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_FIGURES[fk] = im

    assets.IMG_WAYPOINTS = {}
    for wk, name in _FILENAMES["waypoints"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_WAYPOINTS[wk] = im
    if assets.IMG_WAYPOINTS.get("fort") is not None:
        assets.IMG_WAYPOINTS["start"] = assets.IMG_WAYPOINTS["fort"]

    assets.IMG_CINEMATIC = {}
    for cid, name in _FILENAMES["cinematics"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_CINEMATIC[cid] = im

    assets.IMG_ANIMALS = {}
    for ak, name in _FILENAMES["animals"].items():
        im = _load(ANIMAL_DIR / name)
        if im is not None:
            assets.IMG_ANIMALS[ak] = im
