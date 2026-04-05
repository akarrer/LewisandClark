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


def _sz(n: float, scale: float) -> int:
    return max(6, min(96, int(round(n * scale))))


def compute_ui_scale(assets: Any) -> float:
    """Scale factor vs design resolution (REF_SW × REF_SH)."""
    ref_w = getattr(assets, "REF_SW", assets.SW)
    ref_h = getattr(assets, "REF_SH", assets.SH)
    ref_m = min(ref_w, ref_h)
    m = min(assets.SW, assets.SH)
    if ref_m <= 0:
        return 1.0
    return max(0.65, min(1.85, m / ref_m))


def load_fonts(assets: Any, scale: float | None = None) -> None:
    """Attach ``assets.F`` dict of pygame.font.Font instances.

    If *scale* is None, uses :func:`compute_ui_scale` from current ``assets.SW``/``SH``.
    """
    if scale is None:
        scale = compute_ui_scale(assets)
    assets.UI_SCALE = scale

    s = scale
    assets.F = {
        "huge": _load_display(_sz(44, s), bold=True),
        "display": _load_display(_sz(30, s), bold=True),
        "title": _load_display(_sz(20, s), bold=True),
        "cine": _load_display(_sz(17, s), bold=True),
        "header": _load_font(_sz(16, s), bold=True),
        "subhead": _load_font(_sz(13, s), bold=True),
        "body": _load_font(_sz(12, s)),
        "body_i": _load_font(_sz(12, s), italic=True),
        "small": _load_font(_sz(10, s)),
        "small_i": _load_font(_sz(10, s), italic=True),
        "tiny": _load_font(_sz(8, s)),
        "tiny_b": _load_font(_sz(8, s), bold=True),
        "map_lbl": _load_font(_sz(9, s), italic=True),
        "map_sm": _load_font(_sz(7, s), italic=True),
        "mono": _load_mono(_sz(10, s)),
        "mono_sm": _load_mono(_sz(8, s)),
        "narr": _load_font(_sz(13, s)),
        "btn": _load_font(_sz(12, s), bold=True),
        "btn_lg": _load_display(_sz(15, s), bold=True),
        "year": _load_font(_sz(11, s), italic=True),
    }
