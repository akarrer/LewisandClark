"""Layout constants for the gameplay screen (right panel + button columns)."""

from __future__ import annotations

from lewis_clark import assets

PANEL_X = 924
PANEL_W = assets.SW - PANEL_X - 4
HEADER_H = 52

CHAR_AREA_TOP = HEADER_H + 68
CHAR_H = 92
JOURNAL_AFTER_CHAR_GAP = 8
JOURNAL_LABEL_H = 14
JOURNAL_H = 168
MODE_UNDER_JOURNAL_GAP = 6
MODE_HEADER_RESERVE = 40

BTN_Y_TRAVEL = (
    CHAR_AREA_TOP
    + CHAR_H
    + JOURNAL_AFTER_CHAR_GAP
    + JOURNAL_LABEL_H
    + JOURNAL_H
    + MODE_UNDER_JOURNAL_GAP
    + MODE_HEADER_RESERVE
)
BTN_Y_EVENT = BTN_Y_TRAVEL + 108
BTN_Y_TRADE = BTN_Y_TRAVEL + 108

OBJECTIVES_TOP_MARGIN = 138
OBJECTIVES_H = 118
