"""Travel mode UI and hex movement."""

from __future__ import annotations

import random

import pygame

from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.hex_grid import hex_neighbours, hex_terrain
from lewis_clark.screens.game import layout as game_layout
from lewis_clark.ui.button import Button


class TravelMixin:
    def _build_travel_ui(self, hover_hex=None):
        self._sync_layout()
        self.mode = "travel"
        self._event_art_surf = None
        if hasattr(self, "_clear_resource_popup_state"):
            self._clear_resource_popup_state()
        self.action_btns = []
        s = self.state
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_TRAVEL
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        if s.current_wp >= 9:
            self._start_end_game()
            return

        TERR_COLS = {
            "plains": assets.GOLD,
            "river": assets.BLUE2,
            "mountain": assets.AMBER,
            "forest": assets.GREEN2,
            "coast": assets.TEAL2,
        }
        TERR_ICONS = {
            "plains": "~ ",
            "river": "≈ ",
            "mountain": "▲ ",
            "forest": "♣ ",
            "coast": "≋ ",
        }

        neighbours = hex_neighbours(s.hex_col, s.hex_row)

        def sort_key(hk):
            c, r = hk
            wp_here = assets.HEX_WP.get((c, r))
            is_goal = wp_here is not None and wp_here == s.current_wp + 1
            terr = hex_terrain(c, r)
            cost = assets.TERRAIN_DATA[terr]["food"] + abs(
                assets.TERRAIN_DATA[terr]["health"]
            )
            return (0 if is_goal else 1, cost)

        neighbours_sorted = sorted(neighbours, key=sort_key)
        n_nb = len(neighbours_sorted)
        use_2col = n_nb > 3
        gap_y = max(sz(6), int(round(8 * us)))
        col_gap = gap_y
        col_w = (BW - col_gap) // 2 if use_2col else BW
        travel_row_h = sz(40) if n_nb > 5 else sz(44)

        sh_win = assets.SH
        footer_top = game_layout.right_panel_footer_top(sh_win, us)
        strip_h = game_layout.right_panel_inventory_strip_h(us)
        inv_strip_top = footer_top - strip_h
        nav_max_bottom = inv_strip_top - gap_y
        rows_hex = (n_nb + 1) // 2 if use_2col else n_nb
        hex_block = rows_hex * (travel_row_h + gap_y)
        hunt_block = travel_row_h + gap_y
        tribe_extra = travel_row_h + gap_y
        need_nav = hex_block + hunt_block + tribe_extra
        avail_nav = nav_max_bottom - self.BTN_Y_TRAVEL
        if need_nav > avail_nav > 0:
            factor = avail_nav / max(1, need_nav)
            travel_row_h = max(sz(22), int(travel_row_h * factor))
            gap_y = max(sz(4), int(gap_y * factor))
            col_gap = gap_y
            if use_2col:
                col_w = (BW - col_gap) // 2

        row2_h = travel_row_h

        from_col, from_row = s.hex_col, s.hex_row
        for ni, (col, row) in enumerate(neighbours_sorted):
            terr = hex_terrain(col, row)
            tdata = assets.TERRAIN_DATA[terr]
            content = assets.HEX_CONTENTS.get((col, row))
            tc = TERR_COLS.get(terr, assets.GOLD)
            icon = TERR_ICONS.get(terr, "· ")
            is_hov = hover_hex == (col, row)

            if from_row % 2 == 0:
                dir_map = {
                    (1, 0): "E",
                    (-1, 0): "W",
                    (0, -1): "N",
                    (0, 1): "S",
                    (1, -1): "NE",
                    (1, 1): "SE",
                }
            else:
                dir_map = {
                    (1, 0): "E",
                    (-1, 0): "W",
                    (0, -1): "N",
                    (0, 1): "S",
                    (-1, -1): "NW",
                    (-1, 1): "SW",
                }
            direction = dir_map.get((col - from_col, row - from_row), "?")

            wp_there = assets.HEX_WP.get((col, row))
            if wp_there is not None:
                wp_name = assets.WAYPOINTS[wp_there]["name"]
                lbl = f"{direction}  {icon}{wp_name}"
                tc = assets.RED2 if wp_there == s.current_wp + 1 else assets.GOLD
            elif content and content["type"] != "waypoint":
                lbl = f"{direction}  {icon}{content['name'][:24]}"
            else:
                lbl = f"{direction}  {icon}{tdata['label']}"

            parts = []
            if tdata["food"]:
                parts.append(f"food {tdata['food']:+d}")
            if tdata["health"]:
                parts.append(f"hp {tdata['health']:+d}")
            if tdata["morale"]:
                parts.append(f"mor {tdata['morale']:+d}")
            parts.append(f"{tdata['days']}d")
            sub = "  ".join(parts)

            fill_col = tc if is_hov else darken(tc, 0.45)
            if use_2col:
                col_ix = ni % 2
                row_ix = ni // 2
                bx = PX + col_ix * (col_w + col_gap)
                b_row_y = by + row_ix * (travel_row_h + gap_y)
            else:
                bx = PX
                b_row_y = by + ni * (travel_row_h + gap_y)
            btn = Button(
                (bx, b_row_y, col_w, travel_row_h),
                lbl,
                fill=fill_col,
                fill_h=tc,
                text_col=assets.PARCH,
                text_h=assets.INK,
                font=assets.F["btn"],
                sub=sub,
                sub_font=assets.F["body"],
            )
            btn._hex_move = (col, row)
            btn.hovered = is_hov
            self.action_btns.append(btn)

        if use_2col:
            rows = (n_nb + 1) // 2
            by = by + rows * (travel_row_h + gap_y)
        else:
            by = by + n_nb * (travel_row_h + gap_y)

        has_d = s.characters.get("drouillard", {}).get("active", False)
        hunt_w = (BW - col_gap) // 2
        b_hunt = Button(
            (PX, by, hunt_w, row2_h),
            "Hunt",
            fill=darken(assets.GREEN2, 0.5),
            fill_h=assets.GREEN2,
            text_col=assets.PARCH,
            sub="Drouillard leads" if has_d else "+8–18 food",
            sub_font=assets.F["body"],
        )
        b_hunt._action = "hunt"
        self.action_btns.append(b_hunt)

        b_camp = Button(
            (PX + hunt_w + col_gap, by, BW - hunt_w - col_gap, row2_h),
            "Make Camp",
            fill=darken(assets.BLUE2, 0.5),
            fill_h=assets.BLUE2,
            text_col=assets.PARCH,
            sub="+10hp +8mor -10food",
            sub_font=assets.F["body"],
        )
        b_camp._action = "camp"
        self.action_btns.append(b_camp)
        by += row2_h + gap_y

        cur_content = assets.HEX_CONTENTS.get((s.hex_col, s.hex_row))
        if cur_content and cur_content["type"] == "tribe":
            tk_key = cur_content["tribe_key"]
            tribe = assets.TRIBES[tk_key]
            rel = s.tribe_relations.get(tk_key, 50)
            rt = "Friendly" if rel >= 60 else "Neutral" if rel >= 40 else "Tense"
            b_trade = Button(
                (PX, by, BW, row2_h),
                f"Council — {tribe['name']} Nation",
                fill=darken(assets.TEAL2, 0.5),
                fill_h=assets.TEAL2,
                text_col=assets.PARCH,
                sub=f"Relations: {rt} ({rel}/100)",
                sub_font=assets.F["body"],
            )
            b_trade._action = "trade"
            b_trade._tribe = tk_key
            self.action_btns.append(b_trade)
            by += row2_h + gap_y

        inv_h = sz(36)
        inv_y = inv_strip_top + max(0, (strip_h - inv_h) // 2)
        b_inv = Button(
            (PX, inv_y, BW, inv_h),
            "View Inventory",
            fill=assets.UI_CARD2,
            text_col=assets.DIM2,
            font=assets.F["btn"],
        )
        b_inv._action = "inventory"
        self.action_btns.append(b_inv)

    def _build_inventory_ui(self):
        """Full-height inventory list + return — does not share space with travel controls."""
        self._sync_layout()
        self.mode = "inventory"
        self._event_art_surf = None
        self.action_btns = []
        s = self.state
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        sh_win = assets.SH
        mode_y = game_layout.mode_header_y(us, self._stats_card_h)
        ft = game_layout.right_panel_footer_top(sh_win, us)
        panel_bottom = ft - 8
        title_strip = 20
        inner_top = mode_y + title_strip + sz(8)
        back_h = sz(38)
        pad_b = sz(8)
        back_y = panel_bottom - pad_b - back_h
        scroll_h = max(sz(40), back_y - inner_top - sz(8))
        self.scroll_panel.rect = pygame.Rect(PX + 6, inner_top, BW - 12, scroll_h)

        lines = []
        for item in sorted(s.inventory.keys()):
            qty = s.inventory[item]
            if qty > 0:
                lines.append((f"{item}  ×{qty}", assets.F["body"], assets.PARCH_DARK))
        if not lines:
            lines.append(("No supplies recorded.", assets.F["body_i"], assets.DIM2))
        self.scroll_panel.set_lines(lines)

        b_back = Button(
            (PX, back_y, BW, back_h),
            "← Return to travel",
            fill=darken(assets.UI_CARD2, 0.35),
            fill_h=assets.GOLD,
            text_col=assets.PARCH,
            font=assets.F["btn"],
        )
        b_back._action = "close_inventory"
        self.action_btns.append(b_back)

    def _on_hex_click(self, col, row):
        s = self.state
        neighbours = hex_neighbours(s.hex_col, s.hex_row)

        if (col, row) == (s.hex_col, s.hex_row):
            content = assets.HEX_CONTENTS.get((col, row))
            if content and content["type"] == "tribe":
                self._build_trade_ui(content["tribe_key"])
            else:
                event = self._pick_event()
                if event:
                    self.pending_event = event
                    self._build_event_ui(event)
            return

        if (col, row) not in neighbours or s.game_over:
            return

        terr = hex_terrain(col, row)
        tdata = assets.TERRAIN_DATA[terr]

        s.food = max(0, s.food + tdata["food"] - 2)
        s.health = max(0, s.health + tdata["health"])
        s.morale = max(0, s.morale + tdata["morale"])
        s.advance_date(tdata["days"])

        mods = {
            "Winter": {"health": -3, "food": -2},
            "Summer": {"food": -2},
            "Spring": {"morale": 1},
        }
        for k, v in mods.get(s.season, {}).items():
            setattr(s, k, max(0, getattr(s, k) + v))

        if terr == "mountain" and s.characters.get("sacagawea", {}).get("active"):
            s.health = min(100, s.health + 4)

        s.hex_col = col
        s.hex_row = row
        s.hex_trail.append((col, row))
        if (col, row) not in [tuple(h) for h in s.visited_hexes]:
            s.visited_hexes.append((col, row))

        s.clamp()
        self.map_view.invalidate()
        self.map_view.centre_on_hex(col, row)

        TERR_FLAVOUR = {
            "plains": "marched across the open prairie",
            "river": "followed the river upstream",
            "mountain": "pushed through the mountain terrain",
            "forest": "cut through dense forest",
            "coast": "moved along the Pacific coast",
        }
        s.add_journal(f"The corps {TERR_FLAVOUR.get(terr, 'moved forward')}.")

        arrived_wp = assets.HEX_WP.get((col, row))
        if arrived_wp is not None and arrived_wp > s.current_wp:
            wp = assets.WAYPOINTS[arrived_wp]
            wp["revealed"] = True
            wp_type = wp.get("type", "camp")
            if wp_type == "dead_end":
                s.morale = max(0, s.morale - 15)
                s.food = max(0, s.food - 10)
                s.add_journal(
                    f"★ {wp['name']}: {wp['desc']} — this is not the way to the Pacific."
                )
                s.add_journal(
                    "The corps must reconsider. The Pacific lies to the northwest."
                )
            else:
                s.current_wp = arrived_wp
                s.add_journal(f"★ Reached {wp['name']} — {wp['desc']}")
            self._check_objectives()

        content = assets.HEX_CONTENTS.get((col, row))
        if content:
            if content["type"] == "resource":
                already_used = any(tuple(u) == (col, row) for u in s.used_resources)
                if not already_used:
                    self._show_resource_popup(content, col, row)
                    return
            elif content["type"] == "tribe":
                pass

        self._update_journal()
        self._check_objectives()

        if s.food <= 0:
            s.add_journal("The corps has run out of food.")
            self._start_end_game()
            return
        if s.health <= 0:
            s.add_journal("Too many men have been lost.")
            self._start_end_game()
            return

        if random.random() < 0.18:
            event = self._pick_event()
            if event:
                self.pending_event = event
                self._build_event_ui(event)
                return

        self._build_travel_ui()
