"""Travel mode UI and hex movement."""

from __future__ import annotations

import random

from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.hex_grid import hex_neighbours, hex_terrain
from lewis_clark.ui.button import Button


class TravelMixin:
    def _build_travel_ui(self, hover_hex=None):
        self.mode = "travel"
        self.action_btns = []
        s = self.state
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_TRAVEL

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

        from_col, from_row = s.hex_col, s.hex_row
        for col, row in neighbours_sorted:
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
            btn = Button(
                (PX, by, BW, 42),
                lbl,
                fill=fill_col,
                fill_h=tc,
                text_col=assets.PARCH,
                text_h=assets.INK,
                font=assets.F["btn"],
                sub=sub,
            )
            btn._hex_move = (col, row)
            btn.hovered = is_hov
            self.action_btns.append(btn)
            by += 50

        by += 6

        has_d = s.characters.get("drouillard", {}).get("active", False)
        b_hunt = Button(
            (PX, by, BW // 2 - 2, 34),
            "Hunt",
            fill=darken(assets.GREEN2, 0.5),
            fill_h=assets.GREEN2,
            text_col=assets.PARCH,
            sub="Drouillard leads" if has_d else "+8–18 food",
        )
        b_hunt._action = "hunt"
        self.action_btns.append(b_hunt)

        b_camp = Button(
            (PX + BW // 2 + 2, by, BW // 2 - 2, 34),
            "Make Camp",
            fill=darken(assets.BLUE2, 0.5),
            fill_h=assets.BLUE2,
            text_col=assets.PARCH,
            sub="+10hp +8mor -10food",
        )
        b_camp._action = "camp"
        self.action_btns.append(b_camp)
        by += 42

        cur_content = assets.HEX_CONTENTS.get((s.hex_col, s.hex_row))
        if cur_content and cur_content["type"] == "tribe":
            tk_key = cur_content["tribe_key"]
            tribe = assets.TRIBES[tk_key]
            rel = s.tribe_relations.get(tk_key, 50)
            rt = "Friendly" if rel >= 60 else "Neutral" if rel >= 40 else "Tense"
            b_trade = Button(
                (PX, by, BW, 34),
                f"Council — {tribe['name']} Nation",
                fill=darken(assets.TEAL2, 0.5),
                fill_h=assets.TEAL2,
                text_col=assets.PARCH,
                sub=f"Relations: {rt} ({rel}/100)",
            )
            b_trade._action = "trade"
            b_trade._tribe = tk_key
            self.action_btns.append(b_trade)
            by += 42

        next_wp_id = s.current_wp + 1
        if next_wp_id < 10:
            nwp = assets.WAYPOINTS[next_wp_id]
            nwc, nwr = assets.WP_HEX[next_wp_id]

            def cube_dist(c1, r1, c2, r2):
                def to_cube(c, r):
                    x = c - (r - (r & 1)) // 2
                    z = r
                    return x, -x - z, z

                x1, y1, z1 = to_cube(c1, r1)
                x2, y2, z2 = to_cube(c2, r2)
                return max(abs(x1 - x2), abs(y1 - y2), abs(z1 - z2))

            dist = cube_dist(s.hex_col, s.hex_row, nwc, nwr)
            self._next_wp_hint = f"Goal: {nwp['name']}  ·  {dist} hexes away"
        else:
            self._next_wp_hint = ""

        b_inv = Button(
            (PX, assets.SH - 40, BW, 34),
            "View Inventory",
            fill=assets.UI_CARD2,
            text_col=assets.DIM2,
            font=assets.F["small"],
        )
        b_inv._action = "inventory"
        self.action_btns.append(b_inv)

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
