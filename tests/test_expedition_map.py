"""Expedition vector map config."""

import json
from pathlib import Path

import pytest


def test_expedition_map_json_schema():
    root = Path(__file__).resolve().parents[1]
    p = root / "config" / "expedition_map.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    for key in ("overview", "region"):
        assert key in data
        assert "width" in data[key] and "height" in data[key]
        assert "bbox" in data[key]
        b = data[key]["bbox"]
        assert {"west", "east", "south", "north"} <= b.keys()
    assert len(data.get("route_coordinates", [])) >= 4
    assert isinstance(data.get("rivers"), list)


@pytest.mark.parametrize("mode", ["overview", "region"])
def test_build_surface(mode):
    import os

    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    import pygame

    pygame.init()
    pygame.display.set_mode((1, 1))
    from lewis_clark.expedition_map import build_surface, invalidate_cache

    invalidate_cache()
    s = build_surface(mode)
    assert s.get_width() > 100 and s.get_height() > 100
