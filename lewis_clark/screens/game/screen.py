"""Main gameplay screen coordinator (map + right panel)."""

from __future__ import annotations

import pygame
from lewis_clark.map_view import MapView
from lewis_clark.screens.game import layout as game_layout
from lewis_clark.weather import WeatherSystem
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
    PANEL_X = game_layout.PANEL_X
    PANEL_W = game_layout.PANEL_W
    HEADER_H = game_layout.HEADER_H
    BTN_Y_TRAVEL = game_layout.BTN_Y_TRAVEL
    BTN_Y_EVENT = game_layout.BTN_Y_EVENT
    BTN_Y_TRADE = game_layout.BTN_Y_TRADE

    def __init__(self, state, on_menu):
        self.state = state
        self.on_menu = on_menu
        self.map_view = MapView()
        self.weather = WeatherSystem()
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
        _jy = (
            game_layout.CHAR_AREA_TOP
            + game_layout.CHAR_H
            + game_layout.JOURNAL_AFTER_CHAR_GAP
            + game_layout.JOURNAL_LABEL_H
        )
        self.journal_panel = ScrollPanel(
            pygame.Rect(
                self.PANEL_X + 8,
                _jy,
                self.PANEL_W - 16,
                game_layout.JOURNAL_H,
            )
        )
        self._build_travel_ui()
        self._update_journal()
        self._check_objectives()
        self.map_view.zoom_reset()
