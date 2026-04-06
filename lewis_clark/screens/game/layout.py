"""Layout helpers for the gameplay screen (dynamic SW/SH, bottom strip + right panel)."""

from __future__ import annotations

import pygame

# Right column fixed width (map column fills the rest at any window size).
_RIGHT_PANEL_W = 472

MAP_TOP_BASE = 50
HEADER_BASE = 52
# Minimum design height; actual card may be taller (see expedition_stats_card_h).
STATS_CARD_H = 60


def expedition_stats_card_h(ui_scale: float, label_h: int, bar_h: int) -> int:
    """Height of EXPEDITION STATUS card: draw_panel title strip + labels + bar."""
    title_strip = 20  # matches drawing.draw_panel
    pad_top = max(2, int(3 * ui_scale))
    gap = max(2, int(3 * ui_scale))
    bottom_pad = max(2, int(2 * ui_scale))
    inner = title_strip + pad_top + label_h + gap + bar_h + bottom_pad
    return max(int(STATS_CARD_H * ui_scale), inner)


CHAR_H_BASE = 92
JOURNAL_LABEL_H = 14
STATS_TO_OBJECTIVES_GAP = 6
# Space between objectives card bottom and travel / mode header (avoids border clash).
OBJECTIVES_TO_MODE_GAP = 12


def panel_x(sw: int) -> int:
    return sw - _RIGHT_PANEL_W - 4


def panel_w(sw: int) -> int:
    return sw - panel_x(sw) - 4


def map_top(ui_scale: float) -> int:
    return max(44, int(MAP_TOP_BASE * ui_scale))


def header_h(ui_scale: float) -> int:
    return max(40, int(HEADER_BASE * ui_scale))


def char_h(ui_scale: float) -> int:
    return max(64, int(CHAR_H_BASE * ui_scale))


def party_row_height(ui_scale: float) -> int:
    """Target row height for one stacked party member (portrait + text)."""
    return max(44, int(50 * ui_scale))


def party_stack_min_height(num_chars: int, ui_scale: float) -> int:
    """Minimum strip height to fit *num_chars* stacked rows."""
    if num_chars <= 0:
        return 0
    gap = max(3, int(4 * ui_scale))
    row = party_row_height(ui_scale)
    return num_chars * row + max(0, num_chars - 1) * gap + 12


def bottom_bar_h(sw: int, sh: int, ui_scale: float) -> int:
    """Height of the bottom strip (map column only): party | journal."""
    stack_need = party_stack_min_height(5, ui_scale)
    jh = max(96, int(140 * ui_scale))
    label_gap = JOURNAL_LABEL_H + 10
    journal_need = jh + label_gap
    need = max(stack_need, journal_need)
    return min(max(sh // 2, 200), max(need, int(sh * 0.26)))


def main_col_w(sw: int) -> int:
    return panel_x(sw)


def party_strip_w(sw: int) -> int:
    return main_col_w(sw) // 3


def log_strip_w(sw: int) -> int:
    return main_col_w(sw) - party_strip_w(sw)


def map_rect(sw: int, sh: int, ui_scale: float) -> pygame.Rect:
    top = map_top(ui_scale)
    bb = bottom_bar_h(sw, sh, ui_scale)
    h = max(120, sh - top - bb)
    return pygame.Rect(0, top, main_col_w(sw), h)


def bottom_strip_top(sw: int, sh: int, ui_scale: float) -> int:
    return sh - bottom_bar_h(sw, sh, ui_scale)


def _stats_card_h(ui_scale: float, stats_card_h: int | None) -> int:
    if stats_card_h is not None:
        return stats_card_h
    return int(STATS_CARD_H * ui_scale)


def stats_bottom_y(ui_scale: float, stats_card_h: int | None = None) -> int:
    return header_h(ui_scale) + 4 + _stats_card_h(ui_scale, stats_card_h)


def right_panel_footer_h(ui_scale: float) -> int:
    """Reserved height at bottom of right panel (calendar + waypoint)."""
    return max(58, int(76 * ui_scale))


def objectives_block_h(ui_scale: float) -> int:
    """Height of objectives panel between stats bars and mode / travel UI."""
    return max(200, int(268 * ui_scale))


def right_panel_inventory_strip_h(ui_scale: float) -> int:
    """Reserved height above journey footer for the View Inventory control (travel mode)."""
    return max(44, int(52 * ui_scale))


def objectives_top_y(ui_scale: float, stats_card_h: int | None = None) -> int:
    return stats_bottom_y(ui_scale, stats_card_h) + STATS_TO_OBJECTIVES_GAP


def objectives_bottom_y(ui_scale: float, stats_card_h: int | None = None) -> int:
    return objectives_top_y(ui_scale, stats_card_h) + objectives_block_h(ui_scale)


def mode_header_y(ui_scale: float, stats_card_h: int | None = None) -> int:
    """Top of travel / event / trade mode section (below objectives)."""
    return objectives_bottom_y(ui_scale, stats_card_h) + OBJECTIVES_TO_MODE_GAP


def right_panel_footer_top(sh: int, ui_scale: float) -> int:
    return sh - right_panel_footer_h(ui_scale)


def btn_y_travel(ui_scale: float, stats_card_h: int | None = None) -> int:
    """First travel action row — below panel title strip and optional goal hint."""
    from lewis_clark import assets
    from lewis_clark.drawing import panel_title_metrics

    top = mode_header_y(ui_scale, stats_card_h)
    _, title_strip = panel_title_metrics(assets.F["header"], None)
    gap1 = max(4, int(4 * ui_scale))
    hint_h = max(14, int(14 * ui_scale))
    gap2 = max(8, int(10 * ui_scale))
    return top + title_strip + gap1 + hint_h + gap2


def btn_y_event(ui_scale: float, stats_card_h: int | None = None) -> int:
    return btn_y_travel(ui_scale, stats_card_h) + int(108 * ui_scale)


def btn_y_trade(ui_scale: float, stats_card_h: int | None = None) -> int:
    return btn_y_travel(ui_scale, stats_card_h) + int(108 * ui_scale)
