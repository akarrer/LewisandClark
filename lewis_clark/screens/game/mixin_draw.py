"""Gameplay screen rendering."""

from __future__ import annotations

import pygame
from lewis_clark import assets
from lewis_clark.drawing import (
    darken,
    draw_panel,
    draw_separator,
    draw_text,
    draw_wax_seal,
    lighten,
    stat_bar,
)


class DrawMixin:
    def draw(self, surf):
        s = self.state
        season = s.season
        sbg = assets.SEASON_BG.get(season, assets.UI_BG)
        sc = assets.SEASON_COL.get(season, assets.DIM)

        panel_r = pygame.Rect(self.PANEL_X, 0, self.PANEL_W, assets.SH)
        pygame.draw.rect(surf, sbg, panel_r)
        _side_grain = tuple(max(0, c + 4) for c in sbg)
        for i in range(0, self.PANEL_W + assets.SH, 18):
            pygame.draw.line(
                surf,
                _side_grain,
                (self.PANEL_X + i, 0),
                (self.PANEL_X + max(0, i - assets.SH), assets.SH),
                1,
            )
        rail_x = self.PANEL_X
        pygame.draw.rect(surf, assets.UI_GROOVE, (rail_x, 0, 4, assets.SH))
        pygame.draw.rect(surf, assets.UI_BORDER, (rail_x + 4, 0, 1, assets.SH))
        for ry in range(40, assets.SH, 80):
            pygame.draw.circle(surf, assets.UI_BORD_HI, (rail_x + 2, ry), 3)
            pygame.draw.circle(surf, assets.GOLD_DIM, (rail_x + 2, ry), 3, 1)

        hdr_r = pygame.Rect(0, 0, assets.SW, self.HEADER_H)
        pygame.draw.rect(surf, assets.UI_BG, hdr_r)
        _hdr_grain = tuple(max(0, v + 3) for v in assets.UI_BG)
        for i in range(0, assets.SW + assets.SH, 20):
            pygame.draw.line(
                surf, _hdr_grain, (i, 0), (max(0, i - self.HEADER_H), self.HEADER_H)
            )
        pygame.draw.line(surf, assets.GOLD, (0, 1), (assets.SW, 1), 2)
        pygame.draw.line(
            surf,
            assets.GOLD_DIM,
            (0, self.HEADER_H - 2),
            (assets.SW, self.HEADER_H - 2),
            1,
        )
        pygame.draw.line(
            surf, assets.GOLD, (0, self.HEADER_H - 1), (assets.SW, self.HEADER_H - 1), 2
        )
        title_txt = "LEWIS & CLARK EXPEDITION  ·  CORPS OF DISCOVERY"
        ts_sh = assets.F["title"].render(title_txt, True, (0, 0, 0))
        surf.blit(
            ts_sh,
            ts_sh.get_rect(centerx=assets.SW // 2 + 2, centery=self.HEADER_H // 2 + 1),
        )
        ts = assets.F["title"].render(title_txt, True, assets.GOLD)
        surf.blit(ts, ts.get_rect(centerx=assets.SW // 2, centery=self.HEADER_H // 2))
        for ox in [80, assets.SW - 80]:
            draw_text(
                surf,
                "⚑",
                assets.F["title"],
                assets.GOLD_DIM,
                (ox, self.HEADER_H // 2),
                anchor="center",
            )
        draw_text(
            surf,
            f"{s.season}  ·  {s.date_str}",
            assets.F["small_i"],
            sc,
            (assets.SW - 10, 8),
            anchor="topright",
        )
        draw_text(
            surf,
            f"Waypoint {s.current_wp + 1} of {len(assets.WAYPOINTS)}",
            assets.F["tiny"],
            assets.DIM2,
            (assets.SW - 10, 24),
            anchor="topright",
        )

        self.map_view.draw(surf, s)

        PX = self.PANEL_X + 8
        PW = self.PANEL_W - 16

        stats_r = pygame.Rect(self.PANEL_X + 4, self.HEADER_H + 4, self.PANEL_W - 8, 56)
        draw_panel(
            surf,
            stats_r,
            fill=assets.UI_CARD,
            border=assets.UI_BORDER,
            title="EXPEDITION STATUS",
            accent=sc,
            corners=True,
        )
        bw = (PW - 6) // 3
        stat_bar(
            surf, PX, self.HEADER_H + 26, bw, 14, s.food, assets.GOLD, "FOOD", "⬡ "
        )
        stat_bar(
            surf,
            PX + bw + 3,
            self.HEADER_H + 26,
            bw,
            14,
            s.health,
            assets.GREEN2,
            "HEALTH",
            "✦ ",
        )
        stat_bar(
            surf,
            PX + bw * 2 + 6,
            self.HEADER_H + 26,
            bw,
            14,
            s.morale,
            assets.BLUE2,
            "MORALE",
            "◈ ",
        )

        char_y = self.HEADER_H + 68
        char_h = 72
        CHAR_ACCENTS = {
            "york": assets.AMBER,
            "drouillard": assets.GREEN2,
            "sacagawea": assets.TEAL2,
        }
        CHAR_ICONS = {"york": "◆", "drouillard": "⬟", "sacagawea": "★"}
        CHAR_COLS = {
            "york": (186, 126, 52),
            "drouillard": (162, 114, 60),
            "sacagawea": (186, 150, 96),
        }
        cw = (PW - 4) // 3
        for ci, (key, cdata) in enumerate(s.characters.items()):
            cx2 = PX + ci * (cw + 2)
            active = cdata["active"]
            base = assets.SPECIAL_CHARACTERS[key]
            acc2 = CHAR_ACCENTS[key]
            icon = CHAR_ICONS[key]
            skin = CHAR_COLS[key]
            card_r = pygame.Rect(cx2, char_y, cw, char_h)
            cf = assets.UI_CARD if active else assets.UI_PANEL
            draw_panel(
                surf,
                card_r,
                fill=cf,
                border=acc2 if active else assets.UI_BORDER,
                corners=active,
            )
            port_r = pygame.Rect(cx2 + 3, char_y + 3, 28, char_h - 6)
            pygame.draw.rect(surf, darken(cf, 0.7), port_r, border_radius=2)
            if active:
                pygame.draw.circle(surf, skin, (cx2 + 17, char_y + 18), 9)
                pygame.draw.rect(
                    surf, darken(skin, 0.7), (cx2 + 10, char_y + 28, 14, 16)
                )
                pygame.draw.rect(
                    surf,
                    darken(acc2, 0.5),
                    (cx2 + 8, char_y + char_h - 18, 20, 12),
                    border_radius=2,
                )
                ts_ic = assets.F["tiny_b"].render(icon, True, acc2)
                surf.blit(
                    ts_ic, ts_ic.get_rect(center=(cx2 + 18, char_y + char_h - 12))
                )
            else:
                pygame.draw.circle(surf, assets.DIM, (cx2 + 17, char_y + 18), 8)
                pygame.draw.rect(surf, assets.DIM, (cx2 + 10, char_y + 28, 14, 14))
                ts_q = assets.F["tiny_b"].render("?", True, assets.DIM2)
                surf.blit(ts_q, ts_q.get_rect(center=(cx2 + 17, char_y + 48)))
            tx = cx2 + 34
            nc2 = assets.CREAM if active else assets.DIM2
            draw_text(surf, base["name"], assets.F["subhead"], nc2, (tx, char_y + 5))
            draw_text(
                surf,
                base["title"][:16],
                assets.F["tiny"],
                assets.DIM2,
                (tx, char_y + 20),
                max_w=cw - 36,
            )
            if active:
                pygame.draw.line(
                    surf,
                    darken(acc2, 0.5),
                    (tx, char_y + 34),
                    (cx2 + cw - 4, char_y + 34),
                    1,
                )
                abl = list(base["abilities"].items())[0]
                draw_text(
                    surf,
                    f"▸ {abl[1][:22]}",
                    assets.F["tiny"],
                    lighten(acc2, 0.8),
                    (tx, char_y + 38),
                    max_w=cw - 36,
                )
                draw_text(surf, "● Active", assets.F["tiny_b"], acc2, (tx, char_y + 53))
            else:
                draw_text(
                    surf,
                    f"Joins wp {base['joined_at']}",
                    assets.F["tiny"],
                    assets.DIM,
                    (tx, char_y + 38),
                )

        jy = char_y + char_h + 8
        draw_separator(surf, PX, jy + 6, PW, assets.DIM2)
        draw_text(
            surf,
            "EXPEDITION JOURNAL",
            assets.F["tiny_b"],
            assets.GOLD_DIM,
            (PX, jy - 1),
        )
        self.journal_panel.rect.y = jy + 14
        self.journal_panel.rect.x = PX
        self.journal_panel.rect.w = PW
        self.journal_panel.rect.h = 180
        self.journal_panel.draw(surf)

        mode_y = jy + 14 + 180 + 6
        MODE_LABELS = {
            "travel": ("TRAVEL OPTIONS", assets.GOLD),
            "event": ("EVENT — CHOOSE", assets.AMBER),
            "trade": ("TRADE COUNCIL", assets.TEAL2),
            "inventory": ("INVENTORY", assets.PARCH_DARK),
            "end": ("EXPEDITION COMPLETE", assets.GOLD2),
        }
        ml, mc = MODE_LABELS.get(self.mode, ("ACTIONS", assets.GOLD))
        draw_separator(surf, PX, mode_y + 6, PW, darken(mc, 0.5))
        draw_text(surf, ml, assets.F["subhead"], mc, (PX, mode_y))

        if self.mode == "travel" and getattr(self, "_next_wp_hint", ""):
            draw_text(
                surf,
                self._next_wp_hint,
                assets.F["tiny"],
                assets.GOLD_DIM,
                (PX, mode_y + 16),
            )

        if self.mode in ("event", "trade"):
            sp_y = mode_y + 18
            self.scroll_panel.rect = pygame.Rect(PX, sp_y, PW, 110)
            self.scroll_panel.draw(surf)

        if self.mode == "end":
            self._draw_end_summary(surf, mode_y + 18)

        for btn in self.action_btns:
            btn.draw(surf)

        self._draw_objectives(surf)

    def _draw_end_summary(self, surf, y):
        s = self.state
        PX = self.PANEL_X + 8
        PW = self.PANEL_W - 16
        score = len(s.completed_objectives)
        QUOTES = {
            6: '"The object of your mission is accomplished." — Lewis',
            5: '"Ocean in view! O! The joy!" — Clark',
            3: '"We have lived through extraordinary difficulties." — Lewis',
            0: '"The Missouri is a treacherous river." — Clark',
        }
        q = QUOTES.get(max(k for k in QUOTES if k <= score), "")
        rc, rlbl = next(
            (c, n)
            for threshold, c, n in [
                (6, assets.GOLD2, "LEGENDARY"),
                (5, assets.GOLD, "TRIUMPHANT"),
                (3, assets.PARCH_DARK, "PARTIAL SUCCESS"),
                (0, assets.DIM, "PYRRHIC"),
            ]
            if score >= threshold
        )
        draw_text(
            surf, rlbl, assets.F["cine"], rc, (PX + PW // 2, y + 4), anchor="midtop"
        )
        draw_wax_seal(surf, PX + PW - 14, y + 12, 12, rc, rlbl[0])
        y += 36
        iv = sum(
            assets.TRADE_GOOD_VALUES.get(k, 1) * v
            for k, v in s.inventory.items()
            if v > 0
        )
        for lbl3, val, vc in [
            ("OBJECTIVES", f"{score}/6", rc),
            ("WAYPOINTS", f"{s.current_wp}/9", assets.GOLD),
            ("DISCOVERIES", str(s.discoveries), assets.GOLD2),
            ("TRADE VALUE", str(iv), assets.AMBER),
        ]:
            stat_r = pygame.Rect(PX, y, PW // 2 - 2, 26)
            draw_panel(
                surf, stat_r, fill=assets.UI_CARD, border=darken(vc, 0.5), corners=False
            )
            draw_text(
                surf, lbl3, assets.F["tiny"], assets.DIM2, (stat_r.x + 4, stat_r.y + 3)
            )
            draw_text(
                surf,
                val,
                assets.F["header"],
                vc,
                (stat_r.right - 4, stat_r.centery),
                anchor="midright",
            )
            y += 30
        if q:
            draw_text(
                surf, q, assets.F["small_i"], assets.PARCH_EDGE, (PX, y + 4), max_w=PW
            )

    def _draw_objectives(self, surf):
        s = self.state
        PX = self.PANEL_X + 8
        PW = self.PANEL_W - 16
        obj_r = pygame.Rect(PX, assets.SH - 130, PW, 122)
        draw_panel(
            surf,
            obj_r,
            fill=assets.UI_PANEL,
            border=assets.UI_BORDER,
            title="OBJECTIVES",
            accent=assets.GOLD_DIM,
            corners=True,
        )
        objs = [
            ("Fort Mandan", 0, assets.GOLD),
            ("Cross the Divide", 1, assets.AMBER),
            ("Reach Fort Clatsop", 2, assets.TEAL2),
            (f"3 Tribes ({s.peaceful_tribes}/3)", 3, assets.GREEN2),
            ("Healthy Arrival", 4, assets.GREEN2),
            (f"5 Discoveries ({s.discoveries}/5)", 5, assets.GOLD2),
        ]
        ox = PX + 6
        oy = assets.SH - 108
        col_w = (PW - 6) // 2
        for i, (txt, idx, col_o) in enumerate(objs):
            done = idx in s.completed_objectives
            cx3 = ox + (i % 2) * col_w
            cy3 = oy + (i // 2) * 24
            if done:
                draw_wax_seal(surf, cx3 + 8, cy3 + 8, 7, col_o, "✓")
                draw_text(
                    surf,
                    txt,
                    assets.F["tiny"],
                    lighten(col_o, 0.9),
                    (cx3 + 20, cy3 + 2),
                )
            else:
                pygame.draw.circle(surf, assets.UI_CARD3, (cx3 + 8, cy3 + 8), 7)
                pygame.draw.circle(surf, assets.DIM, (cx3 + 8, cy3 + 8), 7, 1)
                draw_text(surf, txt, assets.F["tiny"], assets.DIM2, (cx3 + 20, cy3 + 2))
