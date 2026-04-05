"""Random events, event UI, and resource popups."""

from __future__ import annotations

import random

from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.ui.button import Button


class EventsMixin:
    def _build_event_ui(self, event, _resize_only=False):
        self._sync_layout()
        self.mode = "event"
        self.action_btns = []
        s = self.state
        chars = {k: v["active"] for k, v in s.characters.items()}

        TYPE_COLS = {
            "wildlife": assets.GREEN2,
            "weather": assets.BLUE2,
            "diplomacy": assets.TEAL2,
            "hardship": assets.AMBER,
            "illness": assets.RED2,
            "discovery": assets.GOLD2,
        }
        acc = TYPE_COLS.get(event.get("type", ""), assets.GOLD)

        art_key = event.get("art_id") or event.get("id")
        imgs = getattr(assets, "IMG_ANIMALS", None) or {}
        self._event_art_surf = imgs.get(art_key) or imgs.get("generic")

        choices_overlay = []
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
            choices_overlay.append(
                {
                    "label": lbl,
                    "sub": effs or None,
                    "fill": fc,
                    "text_col": tc,
                    "disabled": dis,
                    "index": i,
                }
            )

        if not _resize_only:
            s.add_journal(f"{event['title']}: {event['intro']}")
            self._update_journal()

        self._narrative_overlay = {
            "title": event["title"],
            "body": event["intro"],
            "subtitle": event.get("type", "event").upper(),
            "accent": acc,
            "art": self._event_art_surf,
            "choices": choices_overlay,
        }
        self.scroll_panel.set_lines([])
        self.action_btns = []

    def _show_resource_popup(self, content, col, row, _resize_only=False):
        self._sync_layout()
        self.mode = "event"
        self._resource_popup_coords = (col, row, content)
        self._event_art_surf = None
        self.action_btns = []
        s = self.state
        eff = content.get("effect", {})

        body = content["desc"]
        if eff:
            eff_str = "  ·  ".join(
                f"{k.capitalize()} {v:+d}" for k, v in eff.items() if isinstance(v, int)
            )
            if eff_str:
                body = f"{body}\n\n{eff_str}"
        if not _resize_only:
            s.add_journal(f"{content['name']}: {content['desc']}")
            self._update_journal()
            self._narrative_overlay = {
                "title": content["name"],
                "body": body,
                "subtitle": "RESOURCE",
                "accent": assets.GOLD2,
                "art": None,
            }
        self.scroll_panel.set_lines([])

        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_EVENT
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz2(n: float) -> int:
            return max(1, int(round(n * us)))

        h1 = sz2(42)
        h2 = sz2(34)
        b_take = Button(
            (PX, by, BW, h1),
            "▶  Gather & Continue",
            fill=darken(assets.GREEN2, 0.5),
            fill_h=assets.GREEN2,
            text_col=assets.PARCH,
        )
        b_take._resource_take = (col, row, content)
        self.action_btns.append(b_take)
        b_pass = Button(
            (PX, by + h1 + sz2(8), BW, h2),
            "Pass By",
            fill=assets.UI_PANEL,
            text_col=assets.DIM2,
        )
        b_pass._action = "pass_resource"
        self.action_btns.append(b_pass)

    def _clear_resource_popup_state(self):
        self._resource_popup_coords = None

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
        self._narrative_overlay = None
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
            if chars.get("lewis"):
                s.discoveries += 1
        for item, qty in choice.get("inventory_gain", {}).items():
            s.inventory[item] = s.inventory.get(item, 0) + qty
        s.add_journal(f"Outcome: {choice['text']}")
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
