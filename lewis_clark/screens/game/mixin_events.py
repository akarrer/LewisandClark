"""Random events, event UI, and resource popups."""

from __future__ import annotations

import random

from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.ui.button import Button


class EventsMixin:
    def _build_event_ui(self, event):
        self.mode = "event"
        self.action_btns = []
        chars = {k: v["active"] for k, v in self.state.characters.items()}
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_EVENT

        TYPE_COLS = {
            "wildlife": assets.GREEN2,
            "weather": assets.BLUE2,
            "diplomacy": assets.TEAL2,
            "hardship": assets.AMBER,
            "illness": assets.RED2,
            "discovery": assets.GOLD2,
        }
        acc = TYPE_COLS.get(event.get("type", ""), assets.GOLD)

        lines = [
            (event["title"], assets.F["header"], acc),
            (event.get("type", "event").upper(), assets.F["tiny_b"], darken(acc, 0.7)),
            ("", assets.F["tiny"], assets.DIM),
            (event["intro"], assets.F["body"], assets.PARCH_DARK),
            ("", assets.F["tiny"], assets.DIM),
            ("— Choose your response —", assets.F["small_i"], assets.DIM2),
        ]
        self.scroll_panel.set_lines(lines)

        for i, choice in enumerate(event["choices"]):
            req = choice.get("requires_char")
            has = chars.get(req, True) if req else True
            eff = choice.get("effect", {})
            effs = "  ".join(
                f"{'+' if v > 0 else ''}{v} {k}"
                for k, v in eff.items()
                if isinstance(v, (int, float)) and v
            )
            net = sum(v for v in eff.values() if isinstance(v, (int, float)))
            if req and not has:
                fc = darken(assets.UI_CARD, 0.7)
                tc = assets.DIM
                dis = True
                lbl = f"[{assets.SPECIAL_CHARACTERS[req]['name']} required]  {choice['label']}"
            elif req and has:
                fc = darken(assets.AMBER, 0.5)
                tc = assets.PARCH
                dis = False
                lbl = choice["label"]
            else:
                ec2 = (
                    darken(assets.GREEN2, 0.5)
                    if net > 5
                    else darken(assets.RED2, 0.5)
                    if net < -15
                    else darken(assets.GOLD, 0.5)
                )
                fc = ec2
                tc = assets.PARCH
                dis = False
                lbl = choice["label"]
            btn = Button(
                (PX, by + i * 48, BW, 40), lbl, fill=fc, text_col=tc, sub=effs or None
            )
            btn.disabled = dis
            btn._choice = i
            self.action_btns.append(btn)

    def _show_resource_popup(self, content, col, row):
        self.mode = "event"
        self.action_btns = []
        eff = content.get("effect", {})

        lines = [
            (content["name"], assets.F["header"], assets.GOLD2),
            ("", assets.F["tiny"], assets.DIM),
            (content["desc"], assets.F["body"], assets.PARCH_DARK),
            ("", assets.F["tiny"], assets.DIM),
        ]
        if eff:
            eff_str = "  ·  ".join(
                f"{k.capitalize()} {v:+d}" for k, v in eff.items() if isinstance(v, int)
            )
            if eff_str:
                lines.append((eff_str, assets.F["small"], assets.GREEN2))
        self.scroll_panel.set_lines(lines)

        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_EVENT
        b_take = Button(
            (PX, by, BW, 42),
            "▶  Gather & Continue",
            fill=darken(assets.GREEN2, 0.5),
            fill_h=assets.GREEN2,
            text_col=assets.PARCH,
        )
        b_take._resource_take = (col, row, content)
        self.action_btns.append(b_take)
        b_pass = Button(
            (PX, by + 50, BW, 34), "Pass By", fill=assets.UI_PANEL, text_col=assets.DIM2
        )
        b_pass._action = "pass_resource"
        self.action_btns.append(b_pass)

    def _pick_event(self):
        s = self.state
        season = s.season
        eligible = [
            e
            for e in assets.EVENTS
            if e["id"] not in s.events_seen or random.random() < 0.25
        ]
        pool = [e for e in eligible if not e.get("season") or season in e["season"]]
        if not pool:
            pool = assets.EVENTS
        e2 = random.choice(pool)
        if e2["id"] not in s.events_seen:
            s.events_seen.append(e2["id"])
        return e2

    def _resolve_event(self, choice_idx):
        ev = self.pending_event
        if not ev:
            return
        choice = ev["choices"][choice_idx]
        s = self.state
        chars = {k: v["active"] for k, v in s.characters.items()}
        s.apply_effect(choice.get("effect", {}), chars)
        rb = choice.get("relation_bonus", 0) or ev.get("relation_bonus", 0)
        if rb:
            tk_key = assets.TRIBE_AT_WAYPOINT.get(s.current_wp)
            if tk_key:
                s.tribe_relations[tk_key] = min(
                    100, s.tribe_relations.get(tk_key, 50) + rb
                )
        if choice.get("discovery") or ev.get("type") == "discovery":
            s.discoveries += 1
        for item, qty in choice.get("inventory_gain", {}).items():
            s.inventory[item] = s.inventory.get(item, 0) + qty
        s.add_journal(f"{ev['title']}: {choice['text']}")
        self.pending_event = None
        s.clamp()
        if s.food <= 0:
            s.add_journal("The corps has starved.")
            self._start_end_game()
            return
        if s.health <= 0:
            s.add_journal("Too many men lost.")
            self._start_end_game()
            return
        self._check_objectives()
        self._update_journal()
        self._build_travel_ui()
