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
        self._event_art_surf = None
        self._narrative_overlay = None
        self._narrative_continue_rect = pygame.Rect(0, 0, 0, 0)
        self._narrative_choice_hitboxes: list[dict] = []
        self._narrative_choice_hover = -1
        self._resource_popup_coords = None
        self.PANEL_X = 0
        self.PANEL_W = 0
        self.HEADER_H = 52
        self.BTN_Y_TRAVEL = 0
        self.BTN_Y_EVENT = 0
        self.BTN_Y_TRADE = 0
        self._bottom_strip_top = 0
        self._bottom_bar_h = 0
        self.scroll_panel = ScrollPanel(pygame.Rect(0, 0, 8, 8))
        self.journal_panel = ScrollPanel(pygame.Rect(0, 0, 8, 8))
        self._sync_layout()
        self._build_travel_ui()
        self._update_journal()
        self._check_objectives()
        self.map_view.zoom_reset()

    def _sync_layout(self):
        from lewis_clark import assets

        sw, sh = assets.SW, assets.SH
        us = getattr(assets, "UI_SCALE", 1.0)
        self.PANEL_X = game_layout.panel_x(sw)
        self.PANEL_W = game_layout.panel_w(sw)
        self.HEADER_H = game_layout.header_h(us)
        label_h = max(
            assets.F["small"].get_height(),
            assets.F["header"].get_height(),
        )
        bar_h = max(10, int(14 * us))
        self._stats_card_h = game_layout.expedition_stats_card_h(us, label_h, bar_h)
        self.BTN_Y_TRAVEL = game_layout.btn_y_travel(us, self._stats_card_h)
        self.BTN_Y_EVENT = game_layout.btn_y_event(us, self._stats_card_h)
        self.BTN_Y_TRADE = game_layout.btn_y_trade(us, self._stats_card_h)
        self._bottom_strip_top = game_layout.bottom_strip_top(sw, sh, us)
        self._bottom_bar_h = game_layout.bottom_bar_h(sw, sh, us)
        self.map_view.set_map_rect(game_layout.map_rect(sw, sh, us))
        log_x = game_layout.party_strip_w(sw) + 4
        log_w = game_layout.log_strip_w(sw) - 8
        jy = self._bottom_strip_top + 6
        lh = game_layout.JOURNAL_LABEL_H
        jh = max(60, sh - jy - lh - 6)
        self.journal_panel.rect = pygame.Rect(log_x, jy + lh, log_w, jh)

    def dismiss_narrative_overlay(self):
        self._narrative_overlay = None

    def on_resize(self):
        if self.mode == "travel":
            self._build_travel_ui()
        elif self.mode == "inventory":
            self._build_inventory_ui()
        elif self.mode == "event" and self.pending_event:
            self._build_event_ui(self.pending_event, _resize_only=True)
        elif self.mode == "event" and self._resource_popup_coords:
            col, row, ct = self._resource_popup_coords
            self._show_resource_popup(ct, col, row, _resize_only=True)
        elif self.mode == "trade" and self._trade_tribe:
            self._build_trade_ui(self._trade_tribe, _resize_only=True)
        elif self.mode == "end":
            self._rebuild_end_buttons()
        else:
            self._sync_layout()
        self.map_view.invalidate()
