"""Mouse / keyboard handling for the gameplay screen."""

from __future__ import annotations

import pygame
from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.hex_grid import hex_terrain


class InputMixin:
    def handle(self, event, on_new_game, on_save, on_load):
        ovr = getattr(self, "_narrative_overlay", None)
        if ovr:
            if ovr.get("choices"):
                if event.type == pygame.MOUSEMOTION:
                    self._narrative_choice_hover = -1
                    for i, hb in enumerate(
                        getattr(self, "_narrative_choice_hitboxes", [])
                    ):
                        if not hb["disabled"] and hb["rect"].collidepoint(event.pos):
                            self._narrative_choice_hover = i
                            break
                elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    for hb in getattr(self, "_narrative_choice_hitboxes", []):
                        if not hb["disabled"] and hb["rect"].collidepoint(event.pos):
                            self._resolve_event(hb["index"])
                            return
                return
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if self._narrative_continue_rect.collidepoint(event.pos):
                    self.dismiss_narrative_overlay()
            elif event.type == pygame.KEYDOWN and event.key in (
                pygame.K_RETURN,
                pygame.K_SPACE,
            ):
                self.dismiss_narrative_overlay()
            return

        self.journal_panel.handle(event)
        if self.mode == "inventory":
            self.scroll_panel.handle(event)

        self.map_view.handle(event, self.state, self._on_hex_click)

        if self.mode == "travel" and event.type == pygame.MOUSEMOTION:
            hh = self.map_view.hover_hex
            if hh != self._last_hover_hex:
                self._last_hover_hex = hh
                for btn in self.action_btns:
                    if hasattr(btn, "_hex_move"):
                        was_hov = btn.hovered
                        btn.hovered = btn._hex_move == hh
                        if btn.hovered != was_hov:
                            if btn.hovered:
                                btn.fill = btn.fill_h
                            else:
                                terr = hex_terrain(*btn._hex_move)
                                TERR_COLS = {
                                    "plains": assets.GOLD,
                                    "river": assets.BLUE2,
                                    "mountain": assets.AMBER,
                                    "forest": assets.GREEN2,
                                    "coast": assets.TEAL2,
                                }
                                tc = TERR_COLS.get(terr, assets.GOLD)
                                btn.fill = darken(tc, 0.45)

        for btn in self.action_btns:
            if btn.handle(event):
                self._button_clicked(btn, on_new_game, on_save)

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_s and pygame.key.get_mods() & pygame.KMOD_CTRL:
                on_save()
            elif event.key in (pygame.K_EQUALS, pygame.K_KP_PLUS):
                self.map_view.zoom_in()
            elif event.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                self.map_view.zoom_out()
            elif event.key == pygame.K_r:
                self.map_view.zoom_reset()
            elif event.key == pygame.K_F1:
                self.map_view.set_map_mode("overview")
            elif event.key == pygame.K_F2:
                self.map_view.set_map_mode("region")
            elif event.key == pygame.K_F3:
                self.map_view.set_map_mode("hex")

    def _button_clicked(self, btn, on_new_game, on_save):
        if hasattr(btn, "_hex_move"):
            self._on_hex_click(*btn._hex_move)
            return
        if hasattr(btn, "_resource_take"):
            col, row, content = btn._resource_take
            s = self.state
            eff = content.get("effect", {})
            s.food = min(100, max(0, s.food + eff.get("food", 0)))
            s.health = min(100, max(0, s.health + eff.get("health", 0)))
            s.morale = min(100, max(0, s.morale + eff.get("morale", 0)))
            for item, qty in eff.get("inventory", {}).items():
                s.inventory[item] = s.inventory.get(item, 0) + qty
            s.used_resources.append((col, row))
            s.add_journal(f"Gathered: {content['name']}.")
            self._update_journal()
            self._build_travel_ui()
            return
        if hasattr(btn, "_route") and not hasattr(btn, "_action"):
            pass
        elif hasattr(btn, "_choice"):
            self._resolve_event(btn._choice)
        elif hasattr(btn, "_trade_action"):
            self._resolve_trade(btn._trade_action, self._trade_tribe)
        elif hasattr(btn, "_action"):
            act = btn._action
            if act == "hunt":
                self._do_hunt()
            elif act == "camp":
                self._do_camp()
            elif act == "trade":
                self._trade_tribe = btn._tribe
                self._build_trade_ui(btn._tribe)
            elif act == "inventory":
                self._build_inventory_ui()
            elif act == "close_inventory":
                self._build_travel_ui()
            elif act == "cancel_route":
                self._build_travel_ui()
            elif act == "pass_resource":
                self._build_travel_ui()
            elif act == "new":
                on_new_game()
            elif act == "save":
                on_save()
