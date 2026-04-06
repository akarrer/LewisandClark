"""Smoke tests: import graph and optional pygame init (no long-running loop)."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parent.parent
from lewis_clark import assets
from lewis_clark.config import load_all
from lewis_clark.hex_grid import _build_hex_contents
from lewis_clark.map_view import MapView


def test_load_all_idempotent_enough():
    """Second load_all refreshes scalars without breaking structure."""
    load_all(assets)
    assert isinstance(assets.WAYPOINTS, list)
    assert hasattr(assets, "game_config")
    assert assets.game_config.SW == assets.SW


def test_build_hex_contents_populates():
    _build_hex_contents()
    assert len(assets.HEX_CONTENTS) > 0
    # Camp Dubois hex from config
    c, r = assets.WP_HEX[0]
    assert (c, r) in assets.HEX_CONTENTS
    assert assets.HEX_CONTENTS[(c, r)]["type"] == "waypoint"


def test_map_view_instantiates():
    """MapView only needs pygame module for Rect constants at class body."""
    mv = MapView()
    assert mv.zoom > 0
    assert MapView.CANVAS_W > MapView.MAP_RECT.w


@pytest.mark.skipif(
    os.environ.get("SKIP_PYGAME_SMOKE"),
    reason="SKIP_PYGAME_SMOKE set",
)
def test_pygame_font_bundle_smoke():
    """Init pygame + fonts like the real game (headless-friendly with dummy driver)."""
    pygame = pytest.importorskip("pygame")
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    pygame.init()
    pygame.font.init()
    try:
        from lewis_clark.fonts import load_fonts

        load_fonts(assets)
        assert "btn" in assets.F
        assert assets.F["tiny"].get_height() > 0
    finally:
        pygame.quit()


def test_app_class_importable():
    """App pulls in pygame + screens; ensure import works when pygame installed."""
    pytest.importorskip("pygame")
    from lewis_clark.app import App, AppScene

    app = App()
    assert app.scene == AppScene.TITLE
    assert app.title is not None


def test_main_module_imports_without_prefilled_assets():
    """Cold start: conftest already called load_all, so this uses a fresh interpreter.

    Matches ``python3 Main`` / ``python -c 'import lewis_clark.main'`` where no
    prior code has populated :mod:`lewis_clark.assets`.
    """
    r = subprocess.run(
        [sys.executable, "-c", "import lewis_clark.main"],
        cwd=_REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert r.returncode == 0, r.stderr or r.stdout or "(no output)"
