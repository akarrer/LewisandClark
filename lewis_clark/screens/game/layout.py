"""Layout constants for the gameplay screen (right panel + button columns)."""

from __future__ import annotations

from lewis_clark import assets

PANEL_X = 924
PANEL_W = assets.SW - PANEL_X - 4
HEADER_H = 50
# Derived layout Y positions (travel buttons start here)
BTN_Y_TRAVEL = (
    50 + 60 + 80 + 20 + 194 + 24
)  # = 428  header+stats+chars+jlbl+journal+mode
BTN_Y_EVENT = BTN_Y_TRAVEL + 118
BTN_Y_TRADE = BTN_Y_TRAVEL + 118
