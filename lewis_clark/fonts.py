"""Pygame font bundle (requires pygame.font.init() first)."""

from __future__ import annotations

from typing import Any

import pygame


def _load_font(size: int, bold: bool = False, italic: bool = False):
    for name in [
        "Georgia",
        "Palatino Linotype",
        "Book Antiqua",
        "Times New Roman",
        "serif",
    ]:
        try:
            f = pygame.font.SysFont(name, size, bold=bold, italic=italic)
            if f:
                return f
        except Exception:
            pass
    return pygame.font.Font(None, size)


def _load_mono(size: int):
    for name in ["Consolas", "Courier New", "Lucida Console", "monospace"]:
        try:
            f = pygame.font.SysFont(name, size)
            if f:
                return f
        except Exception:
            pass
    return pygame.font.Font(None, size)


def load_fonts(assets: Any) -> None:
    """Attach ``assets.F`` dict of pygame.font.Font instances."""
    assets.F = {
        "huge": _load_font(52, bold=True),
        "display": _load_font(36, bold=True),
        "title": _load_font(24, bold=True),
        "cine": _load_font(20, bold=True),
        "header": _load_font(16, bold=True),
        "subhead": _load_font(13, bold=True),
        "body": _load_font(12),
        "body_i": _load_font(12, italic=True),
        "small": _load_font(10),
        "small_i": _load_font(10, italic=True),
        "tiny": _load_font(8),
        "tiny_b": _load_font(8, bold=True),
        "map_lbl": _load_font(9, italic=True),
        "map_sm": _load_font(7, italic=True),
        "mono": _load_mono(10),
        "mono_sm": _load_mono(8),
        "narr": _load_font(13),
        "btn": _load_font(12, bold=True),
        "btn_lg": _load_font(15, bold=True),
        "year": _load_font(11, italic=True),
    }
