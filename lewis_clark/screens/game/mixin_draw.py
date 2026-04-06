"""Gameplay screen rendering."""

from __future__ import annotations

import pygame
from lewis_clark import assets
from lewis_clark.drawing import (
    alpha_surf,
    darken,
    draw_corner_brackets,
    draw_panel,
    draw_separator,
    draw_text,
    draw_wax_seal,
    lighten,
    stat_bar,
)
from lewis_clark.hex_grid import next_waypoint_goal_caption
from lewis_clark.screens.game import layout as game_layout
from lewis_clark.ui.button import _truncate_to_width


def _word_wrap_lines(text: str, font: pygame.font.Font, max_w: int) -> list[str]:
    """Split *text* into lines that fit *max_w* when rendered with *font*."""
    if max_w <= 0:
        return []
    lines: list[str] = []
    for para in (text or "").split("\n"):
        words = para.split()
        line = ""
        for w in words:
            test = (line + " " + w).strip()
            if font.size(test)[0] <= max_w:
                line = test
            else:
                if line:
                    lines.append(line)
                line = w
        if line:
            lines.append(line)
    return lines


def _narrative_choice_row_height(
    label: str,
    sub: str | None,
    max_tw: int,
    us: float,
) -> int:
    """Minimum pixel height for one event choice row (padding + wrapped label + optional sub)."""
    f_btn = assets.F["btn"]
    f_sub = assets.F["small"]
    ip = max(6, int(8 * us))
    gap_mid = max(2, int(5 * us))
    label_lines = _word_wrap_lines(label, f_btn, max_tw)
    if not label_lines:
        label_lines = [""]
    lh = len(label_lines) * f_btn.get_linesize()
    sub_stripped = (sub or "").strip()
    sub_lines = _word_wrap_lines(sub_stripped, f_sub, max_tw) if sub_stripped else []
    sh = len(sub_lines) * f_sub.get_linesize() if sub_lines else 0
    mid = (gap_mid + sh) if sub_lines else 0
    h = ip + lh + mid + ip
    return max(h, max(44, int(40 * us)))


class DrawMixin:
    def draw(self, surf):
        self._sync_layout()
        s = self.state
        season = s.season
        sbg = assets.SEASON_BG.get(season, assets.UI_BG)
        sc = assets.SEASON_COL.get(season, assets.DIM)
        us = getattr(assets, "UI_SCALE", 1.0)
        sw, sh = assets.SW, assets.SH

        panel_r = pygame.Rect(self.PANEL_X, 0, self.PANEL_W, sh)
        pygame.draw.rect(surf, sbg, panel_r)
        # Subtle horizontal grain only — diagonal hatch caused visible vertical banding (Moiré).
        _g_hi = lighten(sbg, 1.045)
        _g_lo = darken(sbg, 0.96)
        for y in range(0, sh, 5):
            gc = _g_hi if (y // 5) % 2 == 0 else _g_lo
            pygame.draw.line(
                surf,
                gc,
                (self.PANEL_X, y),
                (self.PANEL_X + self.PANEL_W, y),
                1,
            )
        # Layout leaves a few pixels before the window edge; fill with sbg so no stray strip.
        right_edge = self.PANEL_X + self.PANEL_W
        if right_edge < sw:
            pygame.draw.rect(surf, sbg, (right_edge, 0, sw - right_edge, sh))

        rail_x = self.PANEL_X
        rail_dark = darken(sbg, 0.5)
        rail_edge = darken(sbg, 0.38)
        rail_hi = lighten(sbg, 1.12)
        rail_lo = darken(sbg, 0.62)
        pygame.draw.rect(surf, rail_dark, (rail_x, 0, 4, sh))
        pygame.draw.rect(surf, rail_edge, (rail_x + 4, 0, 1, sh))
        for ry in range(40, sh, 80):
            pygame.draw.circle(surf, rail_hi, (rail_x + 2, ry), 3)
            pygame.draw.circle(surf, rail_lo, (rail_x + 2, ry), 3, 1)

        hdr_r = pygame.Rect(0, 0, sw, self.HEADER_H)
        pygame.draw.rect(surf, assets.UI_BG, hdr_r)
        _hh = self.HEADER_H
        _hdr_hi = lighten(assets.UI_BG, 1.04)
        _hdr_lo = darken(assets.UI_BG, 0.96)
        for y in range(0, _hh, 4):
            hc = _hdr_hi if (y // 4) % 2 == 0 else _hdr_lo
            pygame.draw.line(surf, hc, (0, y), (sw, y), 1)

        pygame.draw.line(surf, assets.GOLD, (0, 1), (sw, 1), 2)
        pygame.draw.line(
            surf,
            darken(assets.GOLD, 0.4),
            (0, 3),
            (sw, 3),
            1,
        )

        tooling_y = self.HEADER_H - 6
        for tx in range(0, sw, 16):
            pygame.draw.polygon(
                surf,
                assets.GOLD_DIM,
                [
                    (tx + 4, tooling_y),
                    (tx + 8, tooling_y - 3),
                    (tx + 12, tooling_y),
                    (tx + 8, tooling_y + 3),
                ],
            )
        pygame.draw.line(
            surf,
            assets.GOLD_DIM,
            (0, self.HEADER_H - 3),
            (sw, self.HEADER_H - 3),
            1,
        )
        pygame.draw.line(
            surf,
            assets.GOLD,
            (0, self.HEADER_H - 1),
            (sw, self.HEADER_H - 1),
            2,
        )
        title_txt = "LEWIS & CLARK EXPEDITION  ·  CORPS OF DISCOVERY"
        ts_sh = assets.F["title"].render(title_txt, True, (0, 0, 0))
        surf.blit(
            ts_sh,
            ts_sh.get_rect(centerx=sw // 2 + 2, centery=self.HEADER_H // 2 + 1),
        )
        ts = assets.F["title"].render(title_txt, True, assets.GOLD)
        surf.blit(ts, ts.get_rect(centerx=sw // 2, centery=self.HEADER_H // 2))
        for ox in [80, sw - 80]:
            draw_text(
                surf,
                "⚑",
                assets.F["title"],
                assets.GOLD_DIM,
                (ox, self.HEADER_H // 2),
                anchor="center",
            )

        self.map_view.draw(surf, s)

        self.weather.update(s.season, self.map_view.MAP_RECT)
        self.weather.draw(surf, self.map_view.MAP_RECT)

        self._draw_bottom_strip(surf, us)

        PX = self.PANEL_X + 8
        PW = self.PANEL_W - 16

        stats_r = pygame.Rect(
            self.PANEL_X + 4,
            self.HEADER_H + 4,
            self.PANEL_W - 8,
            self._stats_card_h,
        )
        draw_panel(
            surf,
            stats_r,
            fill=assets.UI_CARD,
            border=assets.UI_BORDER,
            title="EXPEDITION STATUS",
            accent=sc,
            corners=True,
        )
        # Flush columns — gaps between bars exposed UI_CARD and looked like pale vertical seams.
        bw0 = PW // 3
        rem = PW % 3
        w0 = bw0 + (1 if rem > 0 else 0)
        w1 = bw0 + (1 if rem > 1 else 0)
        w2 = PW - w0 - w1
        # Below draw_panel title strip (20px): label row, gap, then bar — not HEADER_H+22*us
        # (that put the bar under the title band and let the bar paint over tall subhead digits).
        stats_body_top = self.HEADER_H + 4 + 20
        label_h = max(
            assets.F["small"].get_height(),
            assets.F["header"].get_height(),
        )
        pad_top = max(2, int(3 * us))
        gap_lbl_bar = max(2, int(3 * us))
        bar_h = max(10, int(14 * us))
        sy = stats_body_top + pad_top + label_h + gap_lbl_bar
        x0 = PX
        x1 = PX + w0
        x2 = PX + w0 + w1
        stat_bar(surf, x0, sy, w0, bar_h, s.food, assets.GOLD, "FOOD", "⬡ ")
        stat_bar(surf, x1, sy, w1, bar_h, s.health, assets.GREEN2, "HEALTH", "✦ ")
        stat_bar(surf, x2, sy, w2, bar_h, s.morale, assets.BLUE2, "MORALE", "◈ ")

        self._draw_objectives(surf, us)

        mode_y = game_layout.mode_header_y(us, self._stats_card_h)
        MODE_LABELS = {
            "travel": ("TRAVEL OPTIONS", assets.GOLD),
            "trade": ("TRADE COUNCIL", assets.TEAL2),
            "inventory": ("INVENTORY", assets.PARCH_DARK),
            "end": ("EXPEDITION COMPLETE", assets.GOLD2),
        }
        ml, mc = MODE_LABELS.get(self.mode, ("ACTIONS", assets.GOLD))
        ft = game_layout.right_panel_footer_top(sh, us)

        if self.mode == "travel":
            travel_h = max(0, ft - mode_y - 8)
            panel_r = pygame.Rect(self.PANEL_X + 8, mode_y, self.PANEL_W - 16, travel_h)
            draw_panel(
                surf,
                panel_r,
                fill=assets.UI_PANEL,
                border=assets.UI_BORDER,
                title="TRAVEL OPTIONS",
                accent=assets.GOLD,
                corners=True,
                title_font=assets.F["header"],
            )
        elif self.mode == "inventory":
            travel_h = max(0, ft - mode_y - 8)
            panel_r = pygame.Rect(self.PANEL_X + 8, mode_y, self.PANEL_W - 16, travel_h)
            draw_panel(
                surf,
                panel_r,
                fill=assets.UI_PANEL,
                border=assets.UI_BORDER,
                title="INVENTORY",
                accent=assets.PARCH_DARK,
                corners=True,
            )
            self.scroll_panel.draw(surf)
        elif self.mode == "event":
            pass
        else:
            draw_text(surf, ml, assets.F["subhead"], mc, (PX, mode_y))
            sep_y = mode_y + assets.F["subhead"].get_linesize() + max(6, int(8 * us))
            draw_separator(surf, PX, sep_y, PW, darken(mc, 0.5))

        if self.mode == "end":
            self._draw_end_summary(surf, self.BTN_Y_TRAVEL)

        self._draw_narrative_overlay(surf)

        for btn in self.action_btns:
            btn.draw(surf)

        self._draw_right_panel_footer(surf, us)

    def _draw_right_panel_footer(self, surf, us: float):
        """Calendar and waypoint — bottom of the right panel only."""
        s = self.state
        sh = assets.SH
        ft = game_layout.right_panel_footer_top(sh, us)
        PX = self.PANEL_X + 4
        PW = self.PANEL_W - 8
        footer_r = pygame.Rect(PX, ft, PW, sh - ft)
        sc = assets.SEASON_COL.get(s.season, assets.DIM)
        draw_panel(
            surf,
            footer_r,
            fill=assets.UI_CARD,
            border=assets.UI_BORDER,
            title="JOURNEY STATUS",
            accent=sc,
            corners=True,
        )
        pad = 8
        tx = PX + pad
        ty = footer_r.y + 22
        draw_text(
            surf,
            f"{s.season}  ·  {s.date_str}",
            assets.F["body_i"],
            sc,
            (tx, ty),
        )
        ty += assets.F["body_i"].get_linesize() + 4
        nwp = len(assets.WAYPOINTS)
        wp_i = min(max(0, s.current_wp), nwp - 1)
        wp_name = assets.WAYPOINTS[wp_i]["name"] if nwp else "—"
        draw_text(
            surf,
            f"Waypoint {s.current_wp + 1} of {nwp} — {wp_name}",
            assets.F["small"],
            assets.GOLD,
            (tx, ty),
            max_w=PW - 2 * pad,
        )

    def _draw_bottom_strip(self, surf, us: float):
        """Map-column bottom: party (left third) + journal (right two-thirds)."""
        sw, sh = assets.SW, assets.SH
        top = self._bottom_strip_top
        mc = game_layout.main_col_w(sw)
        bb = self._bottom_bar_h
        if bb <= 0 or top >= sh:
            return
        base = pygame.Rect(0, top, mc, sh - top)
        pygame.draw.rect(surf, darken(assets.UI_BG, 0.25), base)
        pygame.draw.line(
            surf,
            assets.UI_BORDER,
            (0, top),
            (mc, top),
            2,
        )

        pw = game_layout.party_strip_w(sw)
        log_x = pw
        pygame.draw.line(
            surf,
            assets.DIM2,
            (log_x, top + 4),
            (log_x, sh - 4),
            1,
        )

        party_x = 6
        party_w = pw - 12
        char_y = top + 6
        party_avail_h = max(0, sh - char_y - 8)
        self._draw_party_strip(surf, party_x, char_y, party_w, party_avail_h, us)

        jy = top + 6
        lh = game_layout.JOURNAL_LABEL_H
        draw_text(
            surf,
            "EXPEDITION JOURNAL",
            assets.F["tiny_b"],
            assets.GOLD,
            (log_x + 6, jy - 1),
        )
        self.journal_panel.rect.x = log_x + 4
        self.journal_panel.rect.y = jy + lh
        self.journal_panel.rect.w = game_layout.log_strip_w(sw) - 8
        self.journal_panel.rect.h = max(40, sh - self.journal_panel.rect.y - 6)
        self.journal_panel.draw(surf)

    def _draw_party_strip(
        self, surf, px: int, top_y: int, pw: int, avail_h: int, us: float
    ):
        """Stack party members vertically: portrait left, text right (full column width)."""
        s = self.state
        CHAR_ACCENTS = {
            "lewis": assets.GOLD2,
            "clark": assets.BLUE2,
            "york": assets.AMBER,
            "drouillard": assets.GREEN2,
            "sacagawea": assets.TEAL2,
        }
        CHAR_ICONS = {
            "lewis": "⬡",
            "clark": "◈",
            "york": "◆",
            "drouillard": "⬟",
            "sacagawea": "★",
        }
        CHAR_COLS = {
            "lewis": (200, 175, 120),
            "clark": (140, 155, 185),
            "york": (186, 126, 52),
            "drouillard": (162, 114, 60),
            "sacagawea": (186, 150, 96),
        }
        chars = [(k, v) for k, v in s.characters.items() if v["active"]]
        n = len(chars)
        if n == 0 or avail_h < 24:
            return

        gap = max(3, int(4 * us))
        row_h = max(38, (avail_h - gap * max(0, n - 1)) // n)
        port_w = max(28, min(52, int(row_h * 0.48)))
        portraits = getattr(assets, "IMG_PORTRAITS", None) or {}
        text_w = max(40, pw - port_w - 18)
        name_font = assets.F["subhead"] if row_h >= 40 else assets.F["body"]
        detail_font = assets.F["small"]
        abil_font = assets.F["small"]

        for ci, (key, _) in enumerate(chars):
            cy = top_y + ci * (row_h + gap)
            cx2 = px
            base = assets.SPECIAL_CHARACTERS[key]
            acc2 = CHAR_ACCENTS[key]
            icon = CHAR_ICONS[key]
            skin = CHAR_COLS[key]
            card_r = pygame.Rect(cx2, cy, pw, row_h)
            cf = assets.UI_CARD
            draw_panel(
                surf,
                card_r,
                fill=cf,
                border=acc2,
                corners=True,
            )
            port_r = pygame.Rect(cx2 + 3, cy + 3, port_w, row_h - 6)
            pygame.draw.rect(surf, darken(cf, 0.7), port_r, border_radius=2)
            port_im = portraits.get(key) or portraits.get("inactive")
            ic_cx = port_r.centerx
            if port_im:
                iw, ih = port_im.get_size()
                if iw > 0 and ih > 0:
                    fit_scale = min(port_r.w / iw, port_r.h / ih)
                    nw = max(1, int(iw * fit_scale))
                    nh = max(1, int(ih * fit_scale))
                    scaled = pygame.transform.smoothscale(port_im, (nw, nh))
                    sx = port_r.x + (port_r.w - nw) // 2
                    sy = port_r.y + (port_r.h - nh) // 2
                    surf.blit(scaled, (sx, sy))
                frame_c = darken(acc2, 0.35)
                pygame.draw.rect(surf, frame_c, port_r, 1, border_radius=2)
                if row_h >= 44:
                    ib_h = max(7, min(12, row_h // 5))
                    pygame.draw.rect(
                        surf,
                        darken(acc2, 0.5),
                        (
                            port_r.x + 2,
                            port_r.bottom - ib_h - 2,
                            max(18, port_r.w - 4),
                            ib_h,
                        ),
                        border_radius=2,
                    )
                    ts_ic = assets.F["tiny_b"].render(icon, True, acc2)
                    surf.blit(
                        ts_ic,
                        ts_ic.get_rect(center=(ic_cx, port_r.bottom - ib_h // 2 - 2)),
                    )
            else:
                pr = max(5, min(port_r.w, port_r.h) // 4)
                pcx, pcy_head = ic_cx, port_r.y + port_r.h // 3
                pygame.draw.circle(surf, skin, (pcx, pcy_head), pr)
                pygame.draw.circle(surf, darken(skin, 0.6), (pcx, pcy_head), pr, 1)
                if row_h >= 44:
                    ib_h = max(7, min(12, row_h // 5))
                    pygame.draw.rect(
                        surf,
                        darken(acc2, 0.5),
                        (
                            port_r.x + 2,
                            port_r.bottom - ib_h - 2,
                            max(18, port_r.w - 4),
                            ib_h,
                        ),
                        border_radius=2,
                    )
                    ts_ic = assets.F["tiny_b"].render(icon, True, acc2)
                    surf.blit(
                        ts_ic,
                        ts_ic.get_rect(center=(ic_cx, port_r.bottom - ib_h // 2 - 2)),
                    )

            tx = cx2 + port_w + 10
            nc2 = assets.CREAM
            text_block_h = (
                name_font.get_height()
                + detail_font.get_height()
                + abil_font.get_height()
                + 4
            )
            ty = cy + max(2, (row_h - text_block_h) // 2)
            draw_text(surf, base["name"], name_font, nc2, (tx, ty), max_w=text_w)
            ty += name_font.get_height() + 2
            draw_text(
                surf,
                base["title"][:22],
                detail_font,
                assets.DIM2,
                (tx, ty),
                max_w=text_w,
            )
            ty += detail_font.get_height() + 2
            abl = list(base["abilities"].items())[0]
            draw_text(
                surf,
                f"▸ {abl[1][:28]}",
                abil_font,
                lighten(acc2, 0.85),
                (tx, ty),
                max_w=text_w,
            )

    def _draw_narrative_overlay_choice_row(
        self,
        surf,
        rect: pygame.Rect,
        label: str,
        sub: str | None,
        fill,
        text_col,
        *,
        disabled: bool,
        hover: bool,
    ):
        f_btn = assets.F["btn"]
        f_sub = assets.F["small"]
        if disabled:
            face = darken(fill, 0.55)
            tc = assets.DIM
            border = assets.UI_GROOVE
        elif hover:
            face = lighten(fill, 1.08)
            tc = text_col
            border = assets.GOLD2
        else:
            face = fill
            tc = text_col
            border = assets.UI_BORDER
        pygame.draw.rect(surf, face, rect, border_radius=4)
        pygame.draw.rect(surf, border, rect, 1, border_radius=4)
        if hover and not disabled:
            draw_corner_brackets(surf, rect, assets.GOLD2, size=5, width=1)
        ip = max(6, min(12, rect.w // 40 + 2))
        max_tw = max(0, rect.w - 2 * ip)
        label_lines = _word_wrap_lines(label, f_btn, max_tw) or [""]
        sub_s = (sub or "").strip()
        sub_lines = _word_wrap_lines(sub_s, f_sub, max_tw) if sub_s else []
        gap_mid = max(2, int(5 * getattr(assets, "UI_SCALE", 1.0)))
        ty = rect.y + ip
        for ln in label_lines:
            srf = f_btn.render(ln, True, tc)
            surf.blit(srf, srf.get_rect(midtop=(rect.centerx, ty)))
            ty += f_btn.get_linesize()
        if sub_lines:
            ty += gap_mid
            stc = lighten(tc, 0.82) if not disabled else assets.DIM
            for ln in sub_lines:
                srf = f_sub.render(ln, True, stc)
                surf.blit(srf, srf.get_rect(midtop=(rect.centerx, ty)))
                ty += f_sub.get_linesize()

    def _draw_narrative_overlay(self, surf):
        o = getattr(self, "_narrative_overlay", None)
        if not o:
            self._narrative_continue_rect = pygame.Rect(0, 0, 0, 0)
            self._narrative_choice_hitboxes = []
            return
        self._narrative_choice_hitboxes = []
        R = self.map_view.MAP_RECT
        dim = alpha_surf(R.w, R.h, (0, 0, 0), 140)
        surf.blit(dim, R.topleft)

        title = o.get("title", "")
        body = o.get("body", "")
        sub = o.get("subtitle") or ""
        acc = o.get("accent", assets.GOLD)
        pad = 16
        max_w = min(R.w - 16, 620)
        tw = max_w - 2 * pad
        choices = o.get("choices") or []
        us = getattr(assets, "UI_SCALE", 1.0)

        def wrap(txt, font, width):
            lines = []
            for para in txt.split("\n"):
                words = para.split()
                line = ""
                for w in words:
                    test = (line + " " + w).strip()
                    if font.size(test)[0] <= width:
                        line = test
                    else:
                        if line:
                            lines.append(line)
                        line = w
                if line:
                    lines.append(line)
            return lines

        body_lines = wrap(body, assets.F["body"], tw)
        f_header = assets.F["header"]
        f_body = assets.F["body"]
        f_tiny = assets.F["tiny_b"]
        header_h = f_header.get_linesize()
        body_line_h = f_body.get_linesize()
        sub_h = (f_tiny.get_linesize() + 6) if sub else 0
        gap_above_btn = 8
        btn_h = 36
        inner_top = pad + header_h + 4 + sub_h
        ch_gap = max(6, int(8 * us))
        row_heights: list[int] = []
        if choices:
            for ch in choices:
                row_heights.append(
                    _narrative_choice_row_height(
                        ch["label"],
                        ch.get("sub"),
                        tw,
                        us,
                    )
                )
            n_ch = len(choices)
            choice_stack_h = (
                gap_above_btn + sum(row_heights) + max(0, n_ch - 1) * ch_gap
            )
        else:
            row_heights = []
            choice_stack_h = gap_above_btn + btn_h
        footer_h = choice_stack_h + pad
        natural_h = inner_top + len(body_lines) * body_line_h + footer_h
        max_box_h = min(R.h - 16, natural_h)
        box = pygame.Rect(0, 0, max_w, max_box_h)
        box.center = R.center
        box.clamp_ip(R.inflate(-4, -4))

        body_y0 = box.y + inner_top
        body_limit = box.bottom - pad - choice_stack_h
        max_body_lines = max(0, (body_limit - body_y0) // max(1, body_line_h))
        if max_body_lines < len(body_lines):
            shown = body_lines[:max_body_lines]
            if shown:
                shown[-1] = _truncate_to_width(f_body, shown[-1] + " …", tw)
            body_lines = shown
        draw_panel(
            surf,
            box,
            fill=assets.UI_CARD,
            border=acc,
            title=None,
            corners=True,
        )
        y = box.y + pad
        draw_text(surf, title, f_header, acc, (box.centerx, y), anchor="midtop")
        y += header_h + 4
        if sub:
            draw_text(
                surf,
                sub,
                f_tiny,
                darken(acc, 0.5),
                (box.centerx, y),
                anchor="midtop",
            )
            y += f_tiny.get_linesize() + 6
        for line in body_lines:
            draw_text(surf, line, f_body, assets.PARCH_DARK, (box.x + pad, y))
            y += body_line_h

        if choices:
            y_ch = body_y0 + len(body_lines) * body_line_h + gap_above_btn
            for i, ch in enumerate(choices):
                rh = row_heights[i]
                cr = pygame.Rect(box.x + pad, y_ch, box.w - 2 * pad, rh)
                self._draw_narrative_overlay_choice_row(
                    surf,
                    cr,
                    ch["label"],
                    ch.get("sub"),
                    ch["fill"],
                    ch["text_col"],
                    disabled=ch["disabled"],
                    hover=(i == getattr(self, "_narrative_choice_hover", -1)),
                )
                self._narrative_choice_hitboxes.append(
                    {
                        "rect": cr,
                        "index": ch["index"],
                        "disabled": ch["disabled"],
                    }
                )
                y_ch += rh + ch_gap
            self._narrative_continue_rect = pygame.Rect(0, 0, 0, 0)
        else:
            cr = pygame.Rect(box.centerx - 90, box.bottom - pad - btn_h, 180, btn_h)
            pygame.draw.rect(surf, darken(acc, 0.4), cr, border_radius=4)
            draw_text(
                surf,
                "Continue",
                assets.F["btn"],
                assets.PARCH,
                cr.center,
                anchor="center",
            )
            self._narrative_continue_rect = cr

        art = o.get("art")
        if art is not None:
            aw = min(56, box.h // 3)
            asc = pygame.transform.scale(art, (aw, aw))
            surf.blit(asc, (box.right - aw - pad, box.y + pad))

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

    def _draw_objectives(self, surf, us: float):
        s = self.state
        PX = self.PANEL_X + 8
        PW = self.PANEL_W - 16
        oy0 = game_layout.objectives_top_y(us, self._stats_card_h)
        oh = game_layout.objectives_block_h(us)
        obj_r = pygame.Rect(PX, oy0, PW, oh)
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
        goal_txt = next_waypoint_goal_caption(s.current_wp, s.hex_col, s.hex_row)
        rows = []
        if goal_txt:
            rows.append((goal_txt, None, assets.GOLD))
        rows.extend(objs)

        ox = PX + 8
        row_gap = max(24, int(30 * us))
        oy = obj_r.y + int(24 * us)
        text_x = ox + 18
        for i, (txt, idx, col_o) in enumerate(rows):
            cy3 = oy + i * row_gap
            if idx is None:
                pygame.draw.circle(surf, assets.GOLD_DIM, (ox + 8, cy3 + 8), 6)
                pygame.draw.circle(surf, assets.GOLD2, (ox + 8, cy3 + 8), 6, 1)
                draw_text(
                    surf,
                    txt,
                    assets.F["body"],
                    lighten(col_o, 0.95),
                    (text_x, cy3 + 2),
                    max_w=PW - 28,
                )
                continue
            done = idx in s.completed_objectives
            if done:
                draw_wax_seal(surf, ox + 8, cy3 + 4, 8, col_o, "✓")
                draw_text(
                    surf,
                    txt,
                    assets.F["body"],
                    lighten(col_o, 0.92),
                    (text_x, cy3 + 2),
                    max_w=PW - 28,
                )
            else:
                pygame.draw.circle(surf, assets.UI_CARD3, (ox + 8, cy3 + 8), 8)
                pygame.draw.circle(surf, assets.DIM, (ox + 8, cy3 + 8), 8, 1)
                draw_text(
                    surf,
                    txt,
                    assets.F["body"],
                    assets.DIM2,
                    (text_x, cy3 + 2),
                    max_w=PW - 28,
                )
