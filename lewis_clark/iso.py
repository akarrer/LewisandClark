"""Isometric projection helpers for the on-the-ground exploration scene.

World coordinates are in *tile units* (floats). Screen coordinates are in pixels
relative to the projection origin; the camera/centre offset is applied by the
caller. A standard 2:1 diamond tile is used.
"""

from __future__ import annotations

TILE_W = 64  # full diamond width in pixels
TILE_H = 32  # full diamond height in pixels


def world_to_screen(wx: float, wy: float) -> tuple[float, float]:
    """Tile-space (wx, wy) -> screen offset (sx, sy) of the tile centre."""
    sx = (wx - wy) * (TILE_W / 2)
    sy = (wx + wy) * (TILE_H / 2)
    return sx, sy


def screen_to_world(sx: float, sy: float) -> tuple[float, float]:
    """Inverse of :func:`world_to_screen` (screen offset -> tile space)."""
    hw, hh = TILE_W / 2, TILE_H / 2
    wx = (sx / hw + sy / hh) / 2
    wy = (sy / hh - sx / hw) / 2
    return wx, wy


def depth(wx: float, wy: float) -> float:
    """Painter's-algorithm key: larger = nearer the camera (drawn later)."""
    return wx + wy


def screen_dir_to_world(sx: float, sy: float) -> tuple[float, float]:
    """Screen-space movement intent (x right, y down) -> tile-space step.

    "Up" on screen walks diagonally into the tile grid (−x, −y). The input's
    magnitude is preserved, so a half-tilted stick walks at half speed.
    """
    s = 2**-0.5
    return (sx + sy) * s, (sy - sx) * s
