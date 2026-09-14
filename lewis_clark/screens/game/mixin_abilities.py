"""
Active character abilities (P1), event trigger chains (P2),
calendar hard deadlines (P3), and tribal reputation web (P4).
"""

from __future__ import annotations

import random

from lewis_clark import assets


class AbilitiesMixin:

    # ------------------------------------------------------------------ P1

    def _use_ability(self, char_key: str):
        s = self.state
        base = assets.SPECIAL_CHARACTERS.get(char_key, {})
        ab = base.get("active_ability")
        if not ab:
            return
        chars_active = {k: v["active"] for k, v in s.characters.items()}
        s.apply_effect(ab.get("effect", {}), chars_active)
        if ab.get("days", 0):
            s.advance_date(ab["days"])
        if ab.get("discoveries", 0):
            s.discoveries += ab["discoveries"]
        if ab.get("route_buffer", 0):
            s.clark_route_buffer = ab["route_buffer"]
        if ab.get("scout_preview"):
            ev = self._pick_event()
            if ev:
                s.scout_preview = True
                s.add_journal(
                    f"[SCOUT] Drouillard returns: '{ev['title']}' lies ahead — {ev['intro'][:80]}…"
                )
        if ab.get("tribe_bridge"):
            content = assets.HEX_CONTENTS.get((s.hex_col, s.hex_row))
            if content and content.get("type") == "tribe":
                tk = content["tribe_key"]
                s.tribe_relations[tk] = max(s.tribe_relations.get(tk, 50), 70)
                s.add_journal(
                    f"Sacagawea bridges the cultural divide — {assets.TRIBES[tk]['name']} now Friendly."
                )
            else:
                s.morale = min(100, s.morale + 5)
        s.char_cooldowns[char_key] = ab.get("cooldown", 4)
        s.clamp()
        s.add_journal(f"{base['name']}: {ab['name']} — {ab['desc']}")
        self._update_journal()
        self._check_objectives()
        self._build_travel_ui()

    def _decrement_char_cooldowns(self):
        s = self.state
        for key in list(s.char_cooldowns):
            if s.char_cooldowns[key] > 0:
                s.char_cooldowns[key] -= 1
        if s.clark_route_buffer > 0:
            s.clark_route_buffer -= 1

    # ------------------------------------------------------------------ P2

    def _check_pending_triggers(self):
        """Tick event chain triggers; fire any that have reached zero."""
        s = self.state
        still_pending = []
        fired = False
        for trig in s.pending_triggers:
            trig["hexes_remaining"] -= 1
            if trig["hexes_remaining"] <= 0 and not fired:
                ev_id = trig["event_id"]
                ev = next((e for e in assets.EVENTS if e["id"] == ev_id), None)
                if ev:
                    self.pending_event = ev
                    self._build_event_ui(ev)
                    fired = True
            else:
                still_pending.append(trig)
        s.pending_triggers = still_pending

    def _plant_triggers(self, event: dict, choice_idx: int):
        """After resolving an event choice, plant any follow-up trigger chains."""
        s = self.state
        choice = event["choices"][choice_idx]
        for src in (event, choice):
            for trig in src.get("triggers", []):
                already = any(t["event_id"] == trig["event_id"] for t in s.pending_triggers)
                if not already:
                    s.pending_triggers.append(
                        {"event_id": trig["event_id"], "hexes_remaining": trig["after_hexes"]}
                    )

    # ------------------------------------------------------------------ P3

    def _check_calendar_gates(self):
        """Fire warnings and winter-lock if the corps hasn't cleared the Rockies by November."""
        s = self.state
        if s.winter_locked or s.game_over:
            return
        # Bitterroot crossing is waypoint 5 (index 5). Mountain passes close in November (11).
        if s.current_month >= 11 and s.current_wp < 5:
            s.winter_locked = True
            s.add_journal(
                "★ WINTER GATE — November in the Rockies. The passes are closed. "
                "The corps must winter here until March. Health drains each month."
            )
            self._apply_winter_penalty()
            self._update_journal()

    def _apply_winter_penalty(self):
        """Monthly health drain while winter-locked; lifts in March."""
        s = self.state
        if not s.winter_locked:
            return
        months_to_march = (3 - s.current_month) % 12 or 12
        penalty = min(months_to_march * 6, 40)
        s.health = max(5, s.health - penalty)
        s.food = max(0, s.food - months_to_march * 4)
        s.morale = max(0, s.morale - months_to_march * 3)
        # The lock only fires in Nov/Dec (see _check_calendar_gates), so the
        # thaw is always the following March — advance the year by one.
        s.current_year += 1
        s.current_month = 3
        s.winter_locked = False
        s.add_journal(
            f"Spring thaw — the corps resumes. The mountain winter cost {penalty} health."
        )
        s.clamp()

    # ------------------------------------------------------------------ P4

    def _propagate_tribal_reputation(self, acting_tribe_key: str, delta: int):
        """When relations with one tribe change significantly, word travels to same-region tribes."""
        s = self.state
        if abs(delta) < 8:
            return
        acting_tribe = assets.TRIBES.get(acting_tribe_key, {})
        region = acting_tribe.get("region")
        if not region:
            return
        ripple = max(1, abs(delta) // 4) * (1 if delta > 0 else -1)
        for key, tribe in assets.TRIBES.items():
            if key != acting_tribe_key and tribe.get("region") == region:
                old = s.tribe_relations.get(key, 50)
                s.tribe_relations[key] = max(0, min(100, old + ripple))
        s.tribal_reputation = max(0, min(100, s.tribal_reputation + ripple))
