"""Unit tests for hex map helpers (require loaded config)."""

from __future__ import annotations

import pytest
from lewis_clark import assets
from lewis_clark.hex_grid import (
    get_season,
    hex_neighbours,
    hex_terrain,
    hex_to_world,
    world_to_hex,
    wp_display_name,
)


@pytest.mark.parametrize(
    "month,expected",
    [
        (3, "Spring"),
        (5, "Spring"),
        (6, "Summer"),
        (8, "Summer"),
        (9, "Autumn"),
        (11, "Autumn"),
        (1, "Winter"),
        (12, "Winter"),
    ],
)
def test_get_season(month, expected):
    assert get_season(month) == expected


def test_hex_neighbours_even_row_count_and_bounds():
    n = hex_neighbours(5, 4)
    assert len(n) == 6
    for c, r in n:
        assert 0 <= c < assets.HEX_COLS
        assert 0 <= r < assets.HEX_ROWS


def test_hex_neighbours_odd_row_different_offsets():
    """Odd rows use different diagonal neighbours than even rows."""
    even = set(hex_neighbours(10, 4))
    odd = set(hex_neighbours(10, 5))
    assert even != odd


def test_hex_to_world_and_back_center():
    wx, wy = hex_to_world(16, 10)
    c, r = world_to_hex(wx, wy)
    assert (c, r) == (16, 10)


def test_hex_terrain_coast_west_edge():
    assert hex_terrain(0, 10) == "coast"
    assert hex_terrain(2, 10) == "coast"


def test_hex_terrain_plains_far_south():
    assert hex_terrain(20, 19) == "plains"


def test_hex_terrain_river_corridor_before_mountain_band():
    """River segments through the Rocky column band must classify as river, not mountain."""
    assert hex_terrain(5, 6) == "river"


def test_wp_display_name_revealed_shows_real_name():
    wp0 = assets.WAYPOINTS[0]
    old = wp0["revealed"]
    try:
        wp0["revealed"] = True
        name = wp_display_name(0, [])
        assert name == wp0["name"]
    finally:
        wp0["revealed"] = old


def test_wp_display_name_unrevealed_uses_generic():
    wp = next(w for w in assets.WAYPOINTS if not w["revealed"] and w["type"] == "fort")
    wp_id = wp["id"]
    old = wp["revealed"]
    try:
        wp["revealed"] = False
        generic = assets.WP_GENERIC.get(wp["type"], "Unknown Settlement")
        assert wp_display_name(wp_id, []) == generic
    finally:
        wp["revealed"] = old
