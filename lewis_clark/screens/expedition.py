"""The Expedition Map: route overview, and where Legs between Regions are chosen.

Opened two ways:
- **view** (M / View in the field): the route so far, where the Corps is, and
  what's still ahead. Back returns to the field.
- **depart** (interacting with the landing): the Leg options out of this Region,
  each with its cost, arrival date, and a Winter Lock warning. Confirm sets out.
"""

from __future__ import annotations

import pygame
from lewis_clark import assets, corps, expedition_map, legs
from lewis_clark.drawing import darken, draw_text
from lewis_clark.input import Action
from lewis_clark.map_view import MapView

VIEW, DEPART = "view", "depart"

_RISK_COL = {"low": (120, 170, 100), "medium": (214, 170, 72), "high": (206, 110, 60), "very_high": (200, 64, 52)}


class ExpeditionMapScreen:
    def __init__(self, state, mode, on_close, on_take_leg, on_save=None, inp=None):
        self.state = state
        self.inp = inp
        self.mode = mode
        self.on_close = on_close
        self.on_take_leg = on_take_leg
        self.on_save = on_save or (lambda: None)
        self.options = legs.options_from(state.current_region) if mode == DEPART else []
        self.selected = 0
        self._option_rects: list[pygame.Rect] = []
        self._setout_rect = pygame.Rect(0, 0, 0, 0)
        self._back_rect = pygame.Rect(0, 0, 0, 0)
        self.map_view = MapView()
        self._sync_marker()
        self.on_resize()
        self.map_view.set_map_mode("region")  # resets zoom to fit the rect set above
        self._centre_on_corps()

    # ------------------------------------------------------------ layout

    def on_resize(self):
        self.panel_w = max(420, int(assets.SW * 0.34))
        self.map_view.set_map_rect(pygame.Rect(0, 0, assets.SW - self.panel_w, assets.SH))
        self.map_view.invalidate()
        if self.map_view.map_mode == "region":
            self.map_view.zoom_reset()
            self._centre_on_corps()

    def _corps_landmark(self) -> dict:
        """Where the Corps stands: its latest visited Landmark here, else the Region's first."""
        marks = assets.REGIONS[self.state.current_region]["landmarks"]
        visited = [lm for lm in marks if lm["id"] in self.state.landmarks_visited]
        return visited[-1] if visited else marks[0]

    def _to_screen(self, lonlat) -> tuple[int, int]:
        mode = "region"
        bbox = expedition_map._load_data()[mode]["bbox"]
        w, h = expedition_map.canvas_size(mode)
        cx, cy = expedition_map.lonlat_to_canvas(lonlat[0], lonlat[1], bbox, w, h)
        return self.map_view.canvas_to_screen(cx, cy)

    def _centre_on_corps(self):
        mv = self.map_view
        lon, lat = self._corps_landmark()["lonlat"]
        bbox = expedition_map._load_data()["region"]["bbox"]
        w, h = expedition_map.canvas_size("region")
        cx, cy = expedition_map.lonlat_to_canvas(lon, lat, bbox, w, h)
        R = mv.MAP_RECT
        mv.pan_x = cx - (R.w / mv.zoom) / 2
        mv.pan_y = cy - (R.h / mv.zoom) / 2
        mv._clamp_pan(R)

    def _sync_marker(self):
        """Point the map's Corps marker at the current Region's first Landmark on the old route."""
        region = assets.REGIONS[self.state.current_region]
        wps = [lm["waypoint"] for lm in region["landmarks"] if "waypoint" in lm]
        if wps and wps[0] in assets.WP_HEX:
            self.state.hex_col, self.state.hex_row = assets.WP_HEX[wps[0]]

    # ------------------------------------------------------------- input

    def handle(self, event):
        self.map_view.handle(event, self.state, lambda c, r: None)
        if event.type == pygame.MOUSEMOTION:
            for i, r in enumerate(self._option_rects):
                if r.collidepoint(event.pos):
                    self.selected = i
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            for i, r in enumerate(self._option_rects):
                if r.collidepoint(event.pos):
                    self.selected = i
            if self._setout_rect.collidepoint(event.pos):
                self._set_out()
            elif self._back_rect.collidepoint(event.pos):
                self.on_close()

    def handle_action(self, action):
        if action in (Action.BACK, Action.TOGGLE_MAP, Action.MENU):
            self.on_close()
        elif action == Action.SAVE:
            self.on_save()
        elif action == Action.ZOOM_IN:
            self.map_view.zoom_in()
        elif action == Action.ZOOM_OUT:
            self.map_view.zoom_out()
        elif action == Action.ZOOM_RESET:
            self.map_view.zoom_reset()
        elif self.options and action == Action.NEXT:
            self.selected = (self.selected + 1) % len(self.options)
        elif self.options and action == Action.PREV:
            self.selected = (self.selected - 1) % len(self.options)
        elif action == Action.CONFIRM:
            self._set_out()

    def _set_out(self):
        if self.mode == DEPART and self.options:
            self.on_take_leg(self.options[self.selected])

    # -------------------------------------------------------------- draw

    def draw(self, surf):
        self.map_view.draw(surf, self.state)
        self._draw_route_marks(surf)
        s = self.state
        F = assets.F
        x0 = assets.SW - self.panel_w
        pygame.draw.rect(surf, (28, 22, 16), (x0, 0, self.panel_w, assets.SH))
        pygame.draw.line(surf, assets.GOLD, (x0, 0), (x0, assets.SH), 2)
        pad = 18
        x, w = x0 + pad, self.panel_w - pad * 2
        y = pad

        y = draw_text(surf, "EXPEDITION MAP", F["title"], assets.GOLD, (x, y)) + 6
        y = draw_text(surf, f"{s.full_date_str}  ·  {s.season}", F["body_i"], assets.PARCH_LT, (x, y)) + 4
        y = draw_text(surf, f"Food {s.food}   Morale {s.morale}   Corps {s.corps_strength} men (health {s.health})",
                      F["small"], assets.PARCH_LT, (x, y)) + 4
        party = []
        for key in s.party:
            m = s.party[key]
            if not m["alive"]:
                party.append(f"{corps.name(key)} (died)")
            elif s.characters[key].get("active"):
                conds = "".join(f", {corps.condition(c['id'])['name'].lower()}" for c in m["conditions"])
                party.append(f"{corps.name(key)} {m['health']}{conds}")
        y = draw_text(surf, "  ·  ".join(party), F["small_i"], assets.PARCH_LT, (x, y), max_w=w) + 12

        # Route: every Region in order, marking where the Corps is.
        order = list(assets.REGIONS)
        here = order.index(s.current_region)
        for i, rid in enumerate(order):
            r = assets.REGIONS[rid]
            if i < here:
                col = darken(assets.PARCH_LT, 0.7)
            elif i == here:
                col = assets.GOLD
            else:
                col = darken(assets.PARCH_LT, 0.5)
            fs = F["subhead"] if i == here else F["small"]
            dot = (x + 7, y + fs.get_linesize() // 2)
            pygame.draw.circle(surf, col, dot, 6 if i == here else 4, 0 if i <= here else 1)
            draw_text(surf, r["name"], fs, col, (x + 20, y))
            draw_text(surf, r["span"], F["tiny"], col, (x + w, y + 2), anchor="topright")
            y += fs.get_linesize() + 2
        y += 10
        pygame.draw.line(surf, darken(assets.GOLD, 0.5), (x, y), (x + w, y), 1)
        y += 12

        if self.mode == VIEW:
            region = assets.REGIONS[s.current_region]
            left = [lm["name"] for lm in region["landmarks"] if lm["id"] not in s.landmarks_visited]
            msg = ("Walk to the landing at the upriver end of the Region to set out on the next Leg."
                   if region["legs"] else "The Pacific lies ahead. This is the last Region of the westward route.")
            y = draw_text(surf, msg, F["body"], assets.PARCH_LT, (x, y), max_w=w) + 8
            if left:
                y = draw_text(surf, "Not yet visited: " + ", ".join(left), F["small_i"], assets.PARCH_LT, (x, y), max_w=w)
            self._option_rects = []
            self._setout_rect = pygame.Rect(0, 0, 0, 0)
            self._back_rect = self._button(surf, self._label("Back to the field", Action.BACK), x, assets.SH - pad - 40, w, True)
            return

        self._draw_departure(surf, x, y, w, pad)

    def _draw_route_marks(self, surf):
        """Landmarks along the route, and a pulsing marker where the Corps is."""
        s = self.state
        clip = surf.get_clip()
        surf.set_clip(self.map_view.MAP_RECT)
        order = list(assets.REGIONS)
        here = order.index(s.current_region)
        for i, rid in enumerate(order):
            for lm in assets.REGIONS[rid]["landmarks"]:
                if "lonlat" not in lm:
                    continue
                px, py = self._to_screen(lm["lonlat"])
                seen = lm["id"] in s.landmarks_visited
                col = assets.GOLD if seen else ((120, 96, 60) if i <= here else (150, 138, 112))
                pygame.draw.circle(surf, col, (px, py), 5)
                pygame.draw.circle(surf, (40, 28, 16), (px, py), 5, 1)
        corps = self._corps_landmark()
        px, py = self._to_screen(corps["lonlat"])
        pulse = 12 + int(4 * abs(((pygame.time.get_ticks() // 30) % 20) - 10) / 10)
        pygame.draw.circle(surf, (170, 40, 30), (px, py), pulse, 2)
        pygame.draw.circle(surf, (170, 40, 30), (px, py), 4)
        draw_text(surf, corps["name"], assets.F["small"], (60, 30, 16), (px + 16, py - 8))
        surf.set_clip(clip)

    def _draw_departure(self, surf, x, y, w, pad):
        s = self.state
        F = assets.F
        region = assets.REGIONS[s.current_region]
        self._option_rects = []
        if not self.options:
            draw_text(surf, "No Leg leads on from here yet.", F["body"], assets.PARCH_LT, (x, y), max_w=w)
            self._setout_rect = pygame.Rect(0, 0, 0, 0)
            self._back_rect = self._button(surf, self._label("Back to the field", Action.BACK), x, assets.SH - pad - 40, w, True)
            return

        dest = self.options[0].destination_name
        y = draw_text(surf, f"Choose a Leg to {dest}", F["header"], assets.CREAM, (x, y)) + 8
        left = [lm["name"] for lm in region["landmarks"] if lm["id"] not in s.landmarks_visited]
        if left:
            y = draw_text(surf, "Leaving without visiting: " + ", ".join(left), F["small_i"],
                          (214, 170, 72), (x, y), max_w=w) + 8

        for i, opt in enumerate(self.options):
            sel = i == self.selected
            top = y
            inner = x + 12
            iw = w - 24
            y += 10
            y = draw_text(surf, f"{opt.name}  ·  {opt.tag}", F["subhead"], assets.GOLD if sel else assets.CREAM, (inner, y)) + 2
            y = draw_text(surf, opt.desc, F["small"], assets.PARCH_LT, (inner, y), max_w=iw) + 4
            p = legs.plan(s, opt)
            if p.winter_until:
                y = draw_text(surf, f"Winter here until {legs.date_str(p.winter_until)}, then set out.",
                              F["small"], (150, 190, 220), (inner, y), max_w=iw) + 2
            y = draw_text(surf, f"{opt.days} days  ·  arrive {legs.date_str(p.arrive)}", F["small"], assets.CREAM, (inner, y)) + 2
            cost = f"Food {opt.food:+d}   Health {opt.health:+d}   Morale {opt.morale:+d}"
            draw_text(surf, cost, F["small"], assets.PARCH_LT, (inner, y))
            pct = int(assets.CONDITIONS["leg_hazards"]["chance_per_companion"].get(opt.risk, 0) * 100)
            draw_text(surf, f"Risk: {opt.risk.replace('_', ' ')} ({pct}% each)", F["small"],
                      _RISK_COL.get(opt.risk, assets.CREAM), (inner + iw, y), anchor="topright")
            y += F["small"].get_linesize() + 2
            hungry = legs.starving_days(s, opt)
            if hungry:
                y = draw_text(surf, f"Supplies run out: about {hungry} days without food.", F["small"],
                              (220, 90, 70), (inner, y)) + 2
            if p.winter_lock:
                y = draw_text(surf, "Winter will catch the Corps on this Leg.", F["small"], (220, 90, 70), (inner, y)) + 2
            y += 8
            rect = pygame.Rect(x, top, w, y - top)
            pygame.draw.rect(surf, assets.GOLD if sel else darken(assets.GOLD, 0.35), rect, 2 if sel else 1, border_radius=4)
            self._option_rects.append(rect)
            y += 10

        by = assets.SH - pad - 40
        half = (w - 10) // 2
        self._back_rect = self._button(surf, self._label("Stay", Action.BACK), x, by, half, False)
        self._setout_rect = self._button(surf, self._label("Set out", Action.CONFIRM), x + half + 10, by, half, True)

    def _label(self, text, action):
        if self.inp is None:
            return text
        if action == Action.BACK and self.inp.last_device == "keyboard":
            action = Action.MENU  # Esc closes the map from the keyboard
        key = self.inp.hint(action)
        return f"{text}   [{key}]" if key else text

    def _button(self, surf, label, x, y, w, primary):
        rect = pygame.Rect(x, y, w, 40)
        fill = assets.GOLD if primary else (60, 48, 34)
        pygame.draw.rect(surf, fill, rect, border_radius=4)
        pygame.draw.rect(surf, darken(assets.GOLD, 0.6), rect, 1, border_radius=4)
        col = (30, 22, 14) if primary else assets.CREAM
        draw_text(surf, label, assets.F["btn"], col, rect.center, anchor="center")
        return rect
