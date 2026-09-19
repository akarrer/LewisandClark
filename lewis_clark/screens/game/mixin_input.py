"""Mouse / keyboard handling for the gameplay screen."""

from __future__ import annotations

import pygame
from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.hex_grid import hex_terrain
from lewis_clark.input import Action


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
            return

        self.journal_panel.handle(event)
        if self.mode == "inventory":
            self.scroll_panel.handle(event)

        # P1 — ability hitboxes drawn onto party strip
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            for hb in getattr(self, "_ability_hitboxes", []):
                if hb["ready"] and hb["rect"].collidepoint(event.pos):
                    self._use_ability(hb["char_key"])
                    return

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

    def handle_action(self, action, on_save):
        ovr = getattr(self, "_narrative_overlay", None)
        if ovr:
            if ovr.get("choices"):
                self._step_narrative_choice(action)
            elif action == Action.CONFIRM:
                self.dismiss_narrative_overlay()
            return

        if action == Action.SAVE:
            on_save()
        elif action == Action.ZOOM_IN:
            self.map_view.zoom_in()
        elif action == Action.ZOOM_OUT:
            self.map_view.zoom_out()
        elif action == Action.ZOOM_RESET:
            self.map_view.zoom_reset()
        elif action == Action.MAP_MODE_OVERVIEW:
            self.map_view.set_map_mode("overview")
        elif action == Action.MAP_MODE_REGION:
            self.map_view.set_map_mode("region")
        elif action == Action.MAP_MODE_HEX:
            self.map_view.set_map_mode("hex")

    def _step_narrative_choice(self, action):
        """Pick an event choice without a mouse: NEXT/PREV move, CONFIRM chooses."""
        # Hover is a row position in the drawn hitbox list (same as mouse hover).
        hitboxes = getattr(self, "_narrative_choice_hitboxes", [])
        rows = [i for i, hb in enumerate(hitboxes) if not hb["disabled"]]
        if not rows:
            return
        hover = self._narrative_choice_hover
        pos = rows.index(hover) if hover in rows else -1
        if action == Action.NEXT:
            self._narrative_choice_hover = rows[(pos + 1) % len(rows)]
        elif action == Action.PREV:
            self._narrative_choice_hover = rows[(pos - 1) % len(rows)]
        elif action == Action.CONFIRM and pos >= 0:
            self._resolve_event(hitboxes[hover]["index"])

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
