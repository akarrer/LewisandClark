"""Main gameplay screen coordinator (map + right panel)."""

from __future__ import annotations

import pygame
from lewis_clark.map_view import MapView
from lewis_clark.screens.game import layout
from lewis_clark.screens.game.mixin_draw import DrawMixin
from lewis_clark.screens.game.mixin_events import EventsMixin
from lewis_clark.screens.game.mixin_input import InputMixin
from lewis_clark.screens.game.mixin_journal import JournalMixin
from lewis_clark.screens.game.mixin_objectives import ObjectivesMixin
from lewis_clark.screens.game.mixin_trade_camp import TradeCampMixin
from lewis_clark.screens.game.mixin_travel import TravelMixin
from lewis_clark.ui.scroll_panel import ScrollPanel


class GameScreen(
    InputMixin,
    DrawMixin,
    ObjectivesMixin,
    TradeCampMixin,
    EventsMixin,
    TravelMixin,
    JournalMixin,
):
    PANEL_X = layout.PANEL_X
    PANEL_W = layout.PANEL_W
    HEADER_H = layout.HEADER_H
    BTN_Y_TRAVEL = layout.BTN_Y_TRAVEL
    BTN_Y_EVENT = layout.BTN_Y_EVENT
    BTN_Y_TRADE = layout.BTN_Y_TRADE

    def __init__(self, state, on_menu):
        self.state = state
        self.on_menu = on_menu
        self.map_view = MapView()
        self.mode = "travel"
        self.pending_event = None
        self.pending_route_choices = []
        self.action_btns = []
        self._last_hover_hex = None
        self._trade_tribe = None
        self._next_wp_hint = ""
        self.scroll_panel = ScrollPanel(
            pygame.Rect(self.PANEL_X + 8, self.BTN_Y_EVENT - 10, self.PANEL_W - 16, 110)
        )
        self.journal_panel = ScrollPanel(
            pygame.Rect(self.PANEL_X + 8, self.HEADER_H + 230, self.PANEL_W - 16, 180)
        )
        self._build_travel_ui()
        self._update_journal()
        self._check_objectives()
        self.map_view.zoom_reset()
