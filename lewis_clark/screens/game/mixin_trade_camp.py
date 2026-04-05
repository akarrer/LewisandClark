"""Trade council UI, hunt/camp actions, end-game panel."""

from __future__ import annotations

import random

from lewis_clark import assets
from lewis_clark.drawing import darken
from lewis_clark.screens.game import layout as game_layout
from lewis_clark.ui.button import Button


class TradeCampMixin:
    def _build_trade_ui(self, tribe_key, _resize_only=False):
        self._sync_layout()
        self.mode = "trade"
        self._event_art_surf = None
        self.action_btns = []
        self._trade_tribe = tribe_key
        s = self.state
        tribe = assets.TRIBES[tribe_key]
        rel = s.tribe_relations.get(tribe_key, 50)
        chars = {k: v["active"] for k, v in s.characters.items()}
        er = min(
            100,
            rel
            + (20 if chars.get("sacagawea") else 0)
            + (10 if chars.get("york") else 0),
        )
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        by = self.BTN_Y_TRADE
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        h_sac = sz(38)
        h_row = sz(36)
        gap_after_sac = sz(44)
        gap_rows = sz(42)

        rt = "Friendly" if er >= 60 else "Neutral" if er >= 40 else "Tense"
        wants_str = "  ·  ".join(
            f"{g}: {s.inventory.get(g, 0)}" for g in tribe["wants"]
        )
        offers_str = "  ·  ".join(tribe["offers"])

        body = (
            f"Relations: {rt} ({er}/100).\n\n"
            f"They desire: {wants_str}\n\nThey offer: {offers_str}"
        )
        if not _resize_only:
            s.add_journal(
                f"{tribe['name']} Nation — Council. Relations {rt} ({er}/100)."
            )
            self._update_journal()
            self._narrative_overlay = {
                "title": f"{tribe['name']} Nation",
                "body": body,
                "subtitle": "TRADE COUNCIL",
                "accent": assets.TEAL2,
                "art": None,
            }
        self.scroll_panel.set_lines([])

        trade_actions = [
            (
                "Offer Gifts (Tobacco / Beads)",
                "gifts",
                s.inventory.get("Tobacco", 0) + s.inventory.get("Trade Beads", 0) < 3,
            ),
            ("Trade for their goods", "goods", False),
            (
                "Present a Jefferson Peace Medal",
                "medal",
                s.inventory.get("Jefferson Medals", 0) < 1,
            ),
            ("Share maps and route knowledge", "maps", False),
            ("Continue without trading", "leave", False),
        ]
        if chars.get("sacagawea"):
            btn_s = Button(
                (PX, by, BW, h_sac),
                "Sacagawea negotiates in their tongue",
                fill=darken(assets.AMBER, 0.5),
                text_col=assets.PARCH,
                sub="Best possible outcome — full trust",
            )
            btn_s._trade_action = "sacagawea_speak"
            self.action_btns.append(btn_s)
            by += gap_after_sac

        for lbl, act, dis in trade_actions:
            btn = Button(
                (PX, by, BW, h_row),
                lbl,
                fill=darken(assets.TEAL2, 0.5),
                text_col=assets.PARCH,
            )
            btn.disabled = dis
            btn._trade_action = act
            self.action_btns.append(btn)
            by += gap_rows

    def _start_end_game(self):
        self.mode = "end"
        self.action_btns = []
        s = self.state
        s.game_over = True
        score = len(s.completed_objectives)
        if score >= 6:
            rating = "LEGENDARY"
        elif score >= 5:
            rating = "TRIUMPHANT"
        elif score >= 3:
            rating = "PARTIAL SUCCESS"
        else:
            rating = "PYRRHIC"
        s.add_journal(f"EXPEDITION COMPLETE — {score}/6 objectives. Rating: {rating}.")
        self._update_journal()
        self._rebuild_end_buttons()

    def _rebuild_end_buttons(self):
        self._sync_layout()
        self.action_btns = []
        PX = self.PANEL_X + 8
        BW = self.PANEL_W - 16
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        ft = game_layout.right_panel_footer_top(assets.SH, us)
        gap = sz(8)
        save_h, new_h = sz(36), sz(40)
        y_save = ft - gap - save_h
        y_new = y_save - gap - new_h
        b_new = Button(
            (PX, y_new, BW, new_h),
            "⚑  New Expedition",
            fill=assets.GOLD,
            fill_h=assets.GOLD2,
            text_col=assets.INK,
            text_h=assets.INK,
            font=assets.F["btn_lg"],
        )
        b_new._action = "new"
        self.action_btns.append(b_new)
        b_save = Button(
            (PX, y_save, BW, save_h),
            "Save Record",
            fill=assets.UI_CARD2,
            text_col=assets.DIM2,
        )
        b_save._action = "save"
        self.action_btns.append(b_save)

    def _do_hunt(self):
        s = self.state
        has_d = s.characters.get("drouillard", {}).get("active", False)
        roll = random.random()
        s.advance_date(1)
        if roll < 0.15:
            dmg = random.randint(8, 18)
            s.health = max(0, s.health - dmg)
            s.add_journal(f"Hunting accident — lost {dmg} health.")
        elif roll < 0.45:
            gain = random.randint(5, 12) + (8 if has_d else 0)
            s.food = min(100, s.food + gain)
            s.add_journal(f"Modest hunt: +{gain} food.")
        elif roll < 0.80:
            gain = random.randint(12, 22) + (12 if has_d else 0)
            s.food = min(100, s.food + gain)
            s.morale = min(100, s.morale + 6)
            s.add_journal(f"Good hunt: +{gain} food.")
        else:
            gain = random.randint(22, 38) + (15 if has_d else 0)
            s.food = min(100, s.food + gain)
            s.morale = min(100, s.morale + 14)
            s.add_journal(f"Exceptional hunt: +{gain} food!")
        s.clamp()
        self._update_journal()
        self._build_travel_ui()

    def _do_camp(self):
        s = self.state
        s.health = min(100, s.health + 10)
        s.morale = min(100, s.morale + 8)
        s.food = max(0, s.food - 10)
        s.advance_date(3)
        camp_events = [
            ("Wolves at the Perimeter", "Wolves circled camp all night.", 0, -4, -8),
            (
                "Seaman's Heroics",
                "Seaman barked an alarm, saving the corps from a buffalo stampede.",
                5,
                5,
                12,
            ),
            (
                "Cruzatte's Fiddle",
                "Cruzatte played until midnight. The men danced under the stars.",
                0,
                3,
                18,
            ),
            ("Illness in Camp", "Several men awoke with fever.", -5, -12, -8),
            (
                "Meteor Shower",
                "A display of shooting stars lasted for hours.",
                0,
                2,
                15,
            ),
            (
                "Native Visitors",
                "A small band of curious natives visited camp. Friendly exchange.",
                8,
                0,
                10,
            ),
        ]
        s.add_journal("Made camp for three days — rested and restored spirits.")
        if random.random() < 0.4:
            ev2 = random.choice(camp_events)
            s.food = max(0, min(100, s.food + ev2[2]))
            s.health = max(0, min(100, s.health + ev2[3]))
            s.morale = max(0, min(100, s.morale + ev2[4]))
            s.add_journal(f"Camp event — {ev2[0]}: {ev2[1]}")
        s.clamp()
        self._update_journal()
        self._build_travel_ui()

    def _resolve_trade(self, action, tribe_key):
        s = self.state
        tribe = assets.TRIBES[tribe_key]
        {k: v["active"] for k, v in s.characters.items()}
        rel = s.tribe_relations.get(tribe_key, 50)
        if action == "sacagawea_speak":
            s.tribe_relations[tribe_key] = min(100, rel + 30)
            for g in tribe["offers"]:
                s.inventory[g] = s.inventory.get(g, 0) + 2
            s.add_journal(
                f"Sacagawea negotiated with {tribe['name']} — excellent outcome."
            )
            s.morale = min(100, s.morale + 16)
        elif action == "gifts":
            s.inventory["Tobacco"] = max(0, s.inventory.get("Tobacco", 0) - 2)
            s.inventory["Trade Beads"] = max(0, s.inventory.get("Trade Beads", 0) - 3)
            s.tribe_relations[tribe_key] = min(100, rel + 15)
            s.add_journal(f"Offered gifts to {tribe['name']}. Good will established.")
        elif action == "goods":
            for g in tribe["wants"]:
                if s.inventory.get(g, 0) > 0:
                    s.inventory[g] = max(0, s.inventory[g] - 2)
            for g in tribe["offers"]:
                s.inventory[g] = s.inventory.get(g, 0) + 1
            s.tribe_relations[tribe_key] = min(100, rel + 12)
            s.add_journal(f"Traded with {tribe['name']}.")
        elif action == "medal":
            s.inventory["Jefferson Medals"] = max(
                0, s.inventory.get("Jefferson Medals", 0) - 1
            )
            s.tribe_relations[tribe_key] = min(100, rel + 20)
            s.add_journal(f"Presented Jefferson Medal to {tribe['name']} chief.")
        elif action == "maps":
            s.tribe_relations[tribe_key] = min(100, rel + 8)
            s.add_journal(f"Shared route knowledge with {tribe['name']}.")
        if (
            s.tribe_relations.get(tribe_key, 50) >= 60
            and tribe_key not in s.traded_tribes
        ):
            s.traded_tribes.append(tribe_key)
            s.peaceful_tribes = len(
                [t for t in s.traded_tribes if s.tribe_relations.get(t, 50) >= 60]
            )
        s.clamp()
        self._check_objectives()
        self._update_journal()
        self._build_travel_ui()
