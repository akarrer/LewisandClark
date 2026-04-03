"""Sanity checks on loaded JSON → assets."""

from __future__ import annotations

from lewis_clark import assets
from lewis_clark.config import load_game_config
from lewis_clark.game_config import GameConfig


def test_display_dimensions_positive():
    assert assets.SW > 0 and assets.SH > 0
    assert assets.FPS > 0


def test_hex_grid_dimensions_match_json():
    assert assets.HEX_COLS == 32
    assert assets.HEX_ROWS == 20


def test_waypoints_and_wp_hex_aligned():
    assert len(assets.WAYPOINTS) == 20
    assert set(assets.WP_HEX.keys()) == set(range(20))


def test_tribes_and_trade_tables():
    assert len(assets.TRIBES) >= 5
    assert "Trade Beads" in assets.TRADE_GOOD_VALUES


def test_events_and_cine_non_empty():
    assert len(assets.EVENTS) >= 5
    assert len(assets.CINE_SCENES) >= 3


def test_load_game_config_matches_assets():
    cfg = load_game_config()
    assert isinstance(cfg, GameConfig)
    assert cfg.SW == assets.SW
    assert cfg.HEX_COLS == assets.HEX_COLS
    assert "PARCH" in cfg.palette
