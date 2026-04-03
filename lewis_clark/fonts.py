"""Pygame font bundle — loads bundled OFL fonts with SysFont fallback."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pygame

_FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"
_GARAMOND = _FONT_DIR / "EBGaramond.ttf"
_GARAMOND_IT = _FONT_DIR / "EBGaramond-Italic.ttf"
_CINZEL = _FONT_DIR / "Cinzel.ttf"


def _load_font(size: int, bold: bool = False, italic: bool = False):
    try:
        path = _GARAMOND_IT if italic else _GARAMOND
        if path.exists():
            f = pygame.font.Font(str(path), size)
            if bold:
                f.set_bold(True)
            return f
    except Exception:
        pass
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


def _load_display(size: int, bold: bool = True):
    try:
        if _CINZEL.exists():
            f = pygame.font.Font(str(_CINZEL), size)
            if bold:
                f.set_bold(True)
            return f
    except Exception:
        pass
    return _load_font(size, bold=bold)


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
        "huge": _load_display(44, bold=True),
        "display": _load_display(30, bold=True),
        "title": _load_display(20, bold=True),
        "cine": _load_display(17, bold=True),
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
        "btn_lg": _load_display(15, bold=True),
        "year": _load_font(11, italic=True),
    }
