"""On-the-ground 3/4 isometric exploration scene.

The Leader walks the current Region in real time while the Day Clock runs. The
Corps follows behind, wildlife roams, and the Region's Landmarks sit along the
river as things to walk up to and interact with. The landing at the upstream
end is where the Corps departs on a Leg (via the Expedition Map).

Art is placeholder-procedural for now — the sprite-smith agent replaces the
character, companions, and tiles with baked isometric PNGs, dropped in through the
``_draw_*`` helpers without touching the controller, camera, or entity systems.
"""

from __future__ import annotations

import math
import random
from collections import deque

import pygame
from lewis_clark import assets, corps, iso
from lewis_clark.drawing import darken, draw_text, lighten
from lewis_clark.input import Action, InputState
from lewis_clark.region import BIOMES, DIRT, ROCK, SAND, WATER

_TILE_TOP = {
    DIRT: (120, 92, 54),
    WATER: (44, 86, 120),
    SAND: (196, 174, 118),
    ROCK: (110, 104, 96),
}

# Day Clock pace: 2 in-game hours per real minute.
GAME_MINUTES_PER_FRAME = 120 / (60 * 60)

# Coat colour of each Companion walking behind the Leader.
_COATS = {
    "clark": (150, 120, 70),
    "york": (120, 84, 52),
    "drouillard": (70, 104, 66),
    "sacagawea": (146, 84, 64),
}
_TRAIL_SPACING = 14  # frames of lag between each conga-line follower
_MAX_FOLLOWERS = len(_COATS)
_TOAST_FRAMES = 330  # how long a new journal line stays on screen


class ExploreScreen:
    """Real-time isometric field. Shares GameState with the map screen."""

    MOVE_SPEED = 0.075  # tiles per frame at base scale
    INTERACT_RADIUS = 1.4  # tiles

    def __init__(self, state, world, on_open_map, on_quit, on_interact=None, inp=None, news_from=None):
        self.state = state
        self.world = world
        self.inp = inp or InputState()
        self.on_open_map = on_open_map
        self.on_quit = on_quit
        self.on_interact = on_interact or (lambda kind, data: None)
        self.frame = 0
        self._rng = random.Random(world.region_id)
        self.W, self.H = world.width, world.height
        self.tiles = world.tiles
        self.props = world.props
        self._grass = BIOMES.get(world.biome, BIOMES["woodland"])["grass"]
        self.px, self.py = world.spawn
        self.facing = "N"
        self._moving = False
        self._clock_acc = 0.0
        self._trail: deque = deque(maxlen=_TRAIL_SPACING * (_MAX_FOLLOWERS + 2))
        # Followers start in a line downstream of the Leader, not stacked on them.
        for k in range(self._trail.maxlen, 0, -1):
            self._trail.append((self.px, self.py + k * 0.05, "N"))
        self._time_rng = random.Random()
        # Journal lines from ``news_from`` on (e.g. what happened on the Leg here) show on arrival.
        self._journal_seen = len(state.journal) if news_from is None else max(news_from, len(state.journal) - 4)
        self.toasts: list[list] = []  # [text, frames_left]
        self._build_entities()
        self.cam_x = 0.0
        self.cam_y = 0.0
        self._nearby = None  # (kind, data, wx, wy) currently interactable
        self._snap_camera()

    def _walkable(self, wx: float, wy: float) -> bool:
        return self.world.walkable(wx, wy)

    # -------------------------------------------------------------- entities

    def _build_entities(self):
        """Companions follow the Leader; wildlife wanders; Landmarks and the
        landing come from the Region world."""
        self.companions = {
            key: {"key": key, "col": col, "wx": self.px, "wy": self.py, "facing": "N"}
            for key, col in _COATS.items()
        }
        self.wildlife = [
            {"wx": wx, "wy": wy, "heading": self._rng.uniform(0, 2 * math.pi),
             "species": species, "timer": 0}
            for wx, wy, species in self.world.wildlife_spawns
        ]
        self.landmarks = self.world.landmarks
        lx, ly = self.world.landing
        self.landing = {"wx": lx, "wy": ly}

    def _visited(self, lm) -> bool:
        return lm["id"] in self.state.landmarks_visited

    def next_landmark(self):
        return next((lm for lm in self.landmarks if not self._visited(lm)), None)

    # --------------------------------------------------------------- camera

    def _center(self) -> tuple[int, int]:
        return assets.SW // 2, int(assets.SH * 0.52)

    def _snap_camera(self):
        sx, sy = iso.world_to_screen(self.px, self.py)
        self.cam_x, self.cam_y = -sx, -sy

    # ---------------------------------------------------------------- input

    def handle_action(self, action: Action):
        if action == Action.TOGGLE_MAP:
            self.on_open_map()
        elif action == Action.MENU:
            self.on_quit()
        elif action in (Action.INTERACT, Action.CONFIRM):
            self._interact()

    def _interact(self):
        if not self._nearby:
            return
        kind, data, _wx, _wy = self._nearby
        self.on_interact(kind, data)
        if kind == "hunt" and data in self.wildlife:
            self.wildlife.remove(data)
        self._nearby = None

    def update(self):
        self.frame += 1
        self._clock_acc += GAME_MINUTES_PER_FRAME
        if self._clock_acc >= 1.0:
            whole = int(self._clock_acc)
            self._clock_acc -= whole
            corps.pass_minutes(self.state, whole, self._time_rng)
        us = getattr(assets, "UI_SCALE", 1.0)
        speed = self.MOVE_SPEED * max(0.8, us)
        leader_speed = speed * corps.move_multiplier(self.state, corps.rules()["leader"])
        dx, dy = iso.screen_dir_to_world(*self.inp.move_vector())
        self._moving = bool(dx or dy)
        if self._moving:
            dx, dy = dx * leader_speed, dy * leader_speed
            self.facing = self._facing_for(dx, dy)
            if self._walkable(self.px + dx, self.py):
                self.px += dx
            if self._walkable(self.px, self.py + dy):
                self.py += dy
        self._trail.append((self.px, self.py, self.facing))
        self._update_companions()
        self._update_wildlife(speed)
        self._update_nearby()
        self._update_toasts()
        # Smooth camera follow.
        sx, sy = iso.world_to_screen(self.px, self.py)
        self.cam_x += (-sx - self.cam_x) * 0.15
        self.cam_y += (-sy - self.cam_y) * 0.15

    def walking_companions(self) -> list[dict]:
        return [self.companions[k] for k in corps.followers(self.state) if k in self.companions]

    def _update_companions(self):
        trail = self._trail
        for i, comp in enumerate(self.walking_companions()):
            lag = (i + 1) * _TRAIL_SPACING
            if len(trail) > lag:
                comp["wx"], comp["wy"], comp["facing"] = trail[len(trail) - 1 - lag]

    def _update_toasts(self):
        journal = self.state.journal
        for entry in journal[self._journal_seen:]:
            text = entry.split("] ", 1)[-1]
            self.toasts.append([text, _TOAST_FRAMES])
        self._journal_seen = len(journal)
        for t in self.toasts:
            t[1] -= 1
        self.toasts = [t for t in self.toasts if t[1] > 0][-4:]

    def _update_wildlife(self, speed):
        rng = self._rng
        for a in self.wildlife:
            a["timer"] -= 1
            if a["timer"] <= 0:
                a["heading"] = rng.uniform(0, 2 * math.pi)
                a["timer"] = rng.randint(40, 140)
            step = speed * 0.4
            # Convert a screen-space heading into iso world motion.
            hx, hy = math.cos(a["heading"]), math.sin(a["heading"])
            wdx = (hx + hy) * 0.5 * step
            wdy = (hy - hx) * 0.5 * step
            if self._walkable(a["wx"] + wdx, a["wy"] + wdy):
                a["wx"] += wdx; a["wy"] += wdy
            else:
                a["timer"] = 0

    def _update_nearby(self):
        best = None
        best_d = self.INTERACT_RADIUS
        candidates = [
            ("landmark", lm, lm["wx"], lm["wy"]) for lm in self.landmarks if not self._visited(lm)
        ]
        candidates.append(("depart", self.landing, self.landing["wx"], self.landing["wy"]))
        for a in self.wildlife:
            candidates.append(("hunt", a, a["wx"], a["wy"]))
        for kind, data, wx, wy in candidates:
            d = math.hypot(wx - self.px, wy - self.py)
            if d < best_d:
                best_d = d
                best = (kind, data, wx, wy)
        self._nearby = best

    @staticmethod
    def _facing_for(dx: float, dy: float) -> str:
        ssx = dx - dy
        ssy = dx + dy
        ang = math.degrees(math.atan2(ssy, ssx)) % 360
        dirs = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
        return dirs[int(ang / 45 + 0.5) % 8]

    # ----------------------------------------------------------------- draw

    def draw(self, surf):
        cx, cy = self._center()
        ox = cx + self.cam_x
        oy = cy + self.cam_y
        surf.fill((38, 46, 40))

        for ty in range(self.H):
            for tx in range(self.W):
                sx, sy = iso.world_to_screen(tx + 0.5, ty + 0.5)
                px, py = sx + ox, sy + oy
                if px < -iso.TILE_W or px > assets.SW + iso.TILE_W:
                    continue
                if py < -iso.TILE_H or py > assets.SH + iso.TILE_H:
                    continue
                self._draw_tile(surf, px, py, self.tiles[ty][tx])

        # Depth-sorted sprites: props, entities, companions, player.
        drawables = [(iso.depth(wx, wy), "tree", (wx, wy)) for (wx, wy, _k) in self.props]
        for lm in self.landmarks:
            drawables.append((iso.depth(lm["wx"], lm["wy"]), "landmark", lm))
        drawables.append((iso.depth(self.landing["wx"], self.landing["wy"]), "landing", self.landing))
        for a in self.wildlife:
            drawables.append((iso.depth(a["wx"], a["wy"]), "animal", a))
        for comp in self.walking_companions():
            drawables.append((iso.depth(comp["wx"], comp["wy"]), "companion", comp))
        drawables.append((iso.depth(self.px, self.py), "player", None))
        drawables.sort(key=lambda d: d[0])

        for _d, kind, payload in drawables:
            if kind == "player":
                self._draw_figure(surf, self.px, self.py, ox, oy, (58, 78, 120), self.facing, self._moving, scale=1.0)
            elif kind == "companion":
                self._draw_figure(surf, payload["wx"], payload["wy"], ox, oy, payload["col"], payload["facing"], True, scale=0.9)
            elif kind == "tree":
                wx, wy = payload
                sx, sy = iso.world_to_screen(wx, wy)
                self._draw_tree(surf, sx + ox, sy + oy)
            elif kind == "animal":
                self._draw_animal(surf, payload, ox, oy)
            elif kind == "landmark":
                self._draw_landmark(surf, payload, ox, oy)
            elif kind == "landing":
                self._draw_landing(surf, payload, ox, oy)

        self._draw_night(surf)
        self._draw_prompt(surf, ox, oy)
        self._draw_hud(surf)

    def _draw_tile(self, surf, cx, cy, tid):
        top = _TILE_TOP.get(tid, self._grass)
        hw, hh = iso.TILE_W / 2, iso.TILE_H / 2
        pts = [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]
        pygame.draw.polygon(surf, top, pts)
        pygame.draw.polygon(surf, darken(top, 0.72), pts, 1)
        if tid == WATER and (self.frame // 20 + int(cx + cy)) % 7 == 0:
            pygame.draw.line(surf, lighten(top, 1.4), (cx - 6, cy), (cx + 6, cy), 1)

    def _draw_tree(self, surf, cx, cy):
        pygame.draw.ellipse(surf, (24, 30, 22), (cx - 10, cy - 4, 20, 8))
        pygame.draw.rect(surf, (86, 60, 34), (cx - 3, cy - 22, 6, 20))
        pygame.draw.circle(surf, (46, 84, 44), (int(cx), int(cy - 30)), 15)
        pygame.draw.circle(surf, (60, 104, 56), (int(cx - 5), int(cy - 34)), 8)
        pygame.draw.circle(surf, darken((46, 84, 44), 0.7), (int(cx), int(cy - 30)), 15, 1)

    def _draw_figure(self, surf, wx, wy, ox, oy, coat, facing, moving, scale=1.0):
        sx, sy = iso.world_to_screen(wx, wy)
        cx, cy = int(sx + ox), int(sy + oy)
        fdir = {
            "N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0),
            "NE": (1, -1), "NW": (-1, -1), "SE": (1, 1), "SW": (-1, 1),
        }.get(facing, (0, 1))
        fx, fy = fdir
        facing_away = fy < 0
        s = scale
        coat_hi, coat_lo = lighten(coat, 1.25), darken(coat, 0.6)
        boot, skin, hat = (44, 32, 22), (226, 196, 152), (52, 38, 24)

        sh = pygame.Surface((int(30 * s), int(13 * s)), pygame.SRCALPHA)
        pygame.draw.ellipse(sh, (0, 0, 0, 95), (0, 0, int(30 * s), int(13 * s)))
        surf.blit(sh, (cx - int(15 * s), cy - int(5 * s)))

        bob = -1 if (moving and (self.frame // 6) % 2 == 0) else 0
        stride = int(3 * s) if moving and (self.frame // 6) % 2 == 0 else 0
        pygame.draw.rect(surf, boot, (cx - int(5 * s) - stride, cy - int(8 * s), int(4 * s), int(8 * s)))
        pygame.draw.rect(surf, boot, (cx + int(1 * s) + stride, cy - int(8 * s), int(4 * s), int(8 * s)))
        body = pygame.Rect(cx - int(7 * s), cy - int(26 * s) + bob, int(14 * s), int(20 * s))
        pygame.draw.rect(surf, coat, body, border_radius=3)
        lit_left = fx <= 0
        pygame.draw.rect(surf, coat_hi if lit_left else coat_lo, (body.x, body.y, int(3 * s), body.h), border_radius=2)
        pygame.draw.rect(surf, coat_lo if lit_left else coat_hi, (body.right - int(3 * s), body.y, int(3 * s), body.h), border_radius=2)
        pygame.draw.rect(surf, darken(coat, 0.45), body, 1, border_radius=3)
        pygame.draw.rect(surf, (150, 120, 60), (body.x, body.centery + 2, body.w, max(1, int(2 * s))))
        hx, hy = cx, cy - int(30 * s) + bob
        hr = max(4, int(6 * s))
        if not facing_away:
            pygame.draw.circle(surf, skin, (hx, hy), hr)
            pygame.draw.circle(surf, darken(skin, 0.7), (hx, hy), hr, 1)
            ex = hx + (2 if fx > 0 else -2 if fx < 0 else 0)
            pygame.draw.circle(surf, (30, 22, 16), (ex - 2, hy - 1), 1)
            pygame.draw.circle(surf, (30, 22, 16), (ex + 2, hy - 1), 1)
        else:
            pygame.draw.circle(surf, darken(skin, 0.85), (hx, hy), hr)
        pygame.draw.ellipse(surf, hat, (hx - int(8 * s), hy - int(6 * s), int(16 * s), int(6 * s)))
        pygame.draw.polygon(surf, darken(hat, 0.8), [(hx - int(6 * s), hy - int(4 * s)), (hx, hy - int(11 * s)), (hx + int(6 * s), hy - int(4 * s))])

    def _draw_animal(self, surf, a, ox, oy):
        sx, sy = iso.world_to_screen(a["wx"], a["wy"])
        cx, cy = int(sx + ox), int(sy + oy)
        body = (120, 84, 48) if a["species"] == "elk" else (70, 54, 40)
        sh = pygame.Surface((26, 10), pygame.SRCALPHA)
        pygame.draw.ellipse(sh, (0, 0, 0, 80), (0, 0, 26, 10))
        surf.blit(sh, (cx - 13, cy - 3))
        pygame.draw.ellipse(surf, body, (cx - 12, cy - 16, 24, 14))
        pygame.draw.ellipse(surf, darken(body, 0.7), (cx - 12, cy - 16, 24, 14), 1)
        pygame.draw.rect(surf, body, (cx + 6, cy - 22, 5, 9))  # head/neck
        for lx in (-8, -3, 3, 8):
            pygame.draw.rect(surf, darken(body, 0.7), (cx + lx, cy - 5, 2, 6))
        if a["species"] == "elk":
            pygame.draw.line(surf, (90, 70, 40), (cx + 8, cy - 22), (cx + 12, cy - 28), 1)
            pygame.draw.line(surf, (90, 70, 40), (cx + 9, cy - 22), (cx + 6, cy - 28), 1)

    def _draw_landmark(self, surf, lm, ox, oy):
        sx, sy = iso.world_to_screen(lm["wx"], lm["wy"])
        cx, cy = int(sx + ox), int(sy + oy)
        visited = self._visited(lm)
        flag = darken(assets.GOLD, 0.55) if visited else assets.GOLD
        if not visited:
            pulse = 3 + int(2 * math.sin(self.frame * 0.15))
            ring = pygame.Surface((60, 30), pygame.SRCALPHA)
            pygame.draw.ellipse(ring, (244, 198, 68, 70), (0, 0, 60, 30), 3 + pulse // 2)
            surf.blit(ring, (cx - 30, cy - 15))
        pygame.draw.line(surf, (90, 70, 40), (cx, cy - 4), (cx, cy - 40), 2)
        pts = [(cx, cy - 40), (cx + 18, cy - 34), (cx, cy - 28)]
        pygame.draw.polygon(surf, flag, pts)
        pygame.draw.polygon(surf, darken(flag, 0.6), pts, 1)

    def _draw_landing(self, surf, landing, ox, oy):
        """A beached dugout and a post: where the Corps sets out on a Leg."""
        sx, sy = iso.world_to_screen(landing["wx"], landing["wy"])
        cx, cy = int(sx + ox), int(sy + oy)
        pulse = 3 + int(2 * math.sin(self.frame * 0.12))
        ring = pygame.Surface((70, 34), pygame.SRCALPHA)
        pygame.draw.ellipse(ring, (140, 200, 230, 70), (0, 0, 70, 34), 3 + pulse // 2)
        surf.blit(ring, (cx - 35, cy - 17))
        hull = [(cx - 26, cy - 6), (cx + 22, cy - 14), (cx + 28, cy - 10), (cx - 20, cy)]
        pygame.draw.polygon(surf, (98, 68, 40), hull)
        pygame.draw.polygon(surf, (60, 40, 22), hull, 1)
        pygame.draw.line(surf, (90, 70, 40), (cx + 10, cy - 12), (cx + 10, cy - 44), 3)
        pygame.draw.rect(surf, (230, 226, 210), (cx + 11, cy - 44, 16, 10))

    def _draw_night(self, surf):
        """Darken the field between dusk and dawn."""
        hour = self.state.minute_of_day / 60
        if 7 <= hour < 18:
            return
        if 18 <= hour < 21:
            k = (hour - 18) / 3
        elif 5 <= hour < 7:
            k = 1 - (hour - 5) / 2
        else:
            k = 1.0
        shade = getattr(self, "_night_surf", None)
        if shade is None or shade.get_size() != (assets.SW, assets.SH):
            shade = self._night_surf = pygame.Surface((assets.SW, assets.SH), pygame.SRCALPHA)
        shade.fill((10, 16, 44, int(150 * k)))
        surf.blit(shade, (0, 0))

    def _draw_prompt(self, surf, ox, oy):
        if not self._nearby:
            return
        kind, data, wx, wy = self._nearby
        label = {
            "landmark": f"Visit {data.get('name', 'landmark')}",
            "depart": "Depart upriver",
            "hunt": f"Hunt the {data.get('species', 'game')}",
        }.get(kind, "Interact")
        sx, sy = iso.world_to_screen(wx, wy)
        cx, cy = int(sx + ox), int(sy + oy)
        txt = f"{self.inp.hint(Action.INTERACT)} — {label}"
        ts = assets.F["small"].render(txt, True, assets.CREAM)
        pad = 6
        bw, bh = ts.get_width() + pad * 2, ts.get_height() + pad
        bx, by = cx - bw // 2, cy - 60
        bg = pygame.Surface((bw, bh), pygame.SRCALPHA)
        bg.fill((0, 0, 0, 160))
        pygame.draw.rect(bg, (*assets.GOLD, 220), bg.get_rect(), 1)
        surf.blit(bg, (bx, by))
        surf.blit(ts, (bx + pad, by + pad // 2))

    def _draw_hud(self, surf):
        s = self.state
        pad = 10
        line = assets.F["small"].get_linesize()
        draw_text(surf, self.world.name, assets.F["subhead"], assets.CREAM, (pad + 4, pad + 2))
        y = pad + 6 + assets.F["subhead"].get_linesize()
        draw_text(surf, f"{s.full_date_str}  ·  {s.clock_str}  ·  {s.season}",
                  assets.F["small"], assets.PARCH_LT, (pad + 4, y))
        y += line
        draw_text(surf, f"Food {s.food}   Morale {s.morale}   Corps {s.corps_strength} men (health {s.health})",
                  assets.F["small"], assets.PARCH_LT, (pad + 4, y))
        y += line
        nxt = self.next_landmark()
        goal = f"Next: {nxt['name']}" if nxt else "All landmarks visited — make for the landing upriver"
        draw_text(surf, goal, assets.F["small"], assets.GOLD, (pad + 4, y))
        self._draw_party(surf)
        self._draw_toasts(surf)

    def _draw_party(self, surf):
        """Each Companion's health and Conditions, bottom-left."""
        s = self.state
        F = assets.F
        keys = [k for k in s.party if s.characters[k].get("active") or not s.party[k]["alive"]]
        row_h = F["small"].get_linesize() * 2 + 6
        w = 250
        h = row_h * len(keys) + 12
        x, y = 12, assets.SH - h - 12
        bg = pygame.Surface((w, h), pygame.SRCALPHA)
        bg.fill((0, 0, 0, 120))
        surf.blit(bg, (x, y))
        y += 6
        for key in keys:
            m = s.party[key]
            nm = corps.name(key)
            if not m["alive"]:
                draw_text(surf, f"{nm} — died", F["small_i"], (150, 140, 130), (x + 10, y))
                y += row_h
                continue
            draw_text(surf, nm, F["small"], assets.CREAM, (x + 10, y))
            bx, bw, bh = x + 100, w - 150, 7
            by = y + F["small"].get_linesize() // 2 - bh // 2
            hp = m["health"]
            col = (110, 170, 90) if hp > 60 else (214, 170, 72) if hp > 30 else (206, 80, 60)
            pygame.draw.rect(surf, (40, 34, 28), (bx, by, bw, bh))
            pygame.draw.rect(surf, col, (bx, by, int(bw * hp / 100), bh))
            draw_text(surf, str(hp), F["small"], assets.PARCH_LT, (x + w - 10, y), anchor="topright")
            conds = ", ".join(corps.condition(c["id"])["name"] for c in m["conditions"])
            if conds:
                draw_text(surf, conds, F["small_i"], (220, 150, 110), (x + 10, y + F["small"].get_linesize()))
            y += row_h

    def _draw_toasts(self, surf):
        """New journal lines, briefly, top-right."""
        F = assets.F["small"]
        y = 12
        for text, left in self.toasts:
            alpha = min(255, left * 6)
            ts = F.render(text, True, assets.CREAM)
            bg = pygame.Surface((ts.get_width() + 20, ts.get_height() + 8), pygame.SRCALPHA)
            bg.fill((0, 0, 0, min(150, alpha)))
            ts.set_alpha(alpha)
            x = assets.SW - bg.get_width() - 12
            surf.blit(bg, (x, y))
            surf.blit(ts, (x + 10, y + 4))
            y += bg.get_height() + 4
        h = self.inp.hint
        hint = (f"{h('move')} — walk      {h(Action.INTERACT)} — interact      "
                f"{h(Action.TOGGLE_MAP)} — map      {h(Action.MENU)} — menu")
        hs = assets.F["small"].render(hint, True, assets.PARCH_LT)
        bg = pygame.Surface((hs.get_width() + 20, hs.get_height() + 10), pygame.SRCALPHA)
        bg.fill((0, 0, 0, 110))
        surf.blit(bg, (assets.SW // 2 - bg.get_width() // 2, assets.SH - bg.get_height() - 12))
        surf.blit(hs, (assets.SW // 2 - hs.get_width() // 2, assets.SH - hs.get_height() - 17))

    def on_resize(self):
        self._snap_camera()
