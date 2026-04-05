"""Waypoint / expedition objectives checks."""

from __future__ import annotations

from lewis_clark import assets


class ObjectivesMixin:
    def _notify_party_roster_change(self, char_key: str, *, joined: bool) -> None:
        """Append a journal line and show a dismissible map overlay when someone joins or leaves."""
        s = self.state
        base = assets.SPECIAL_CHARACTERS[char_key]
        name = base["name"]
        if joined:
            s.add_journal(f"{name} joins the expedition.")
            title = f"{name} has joined the corps"
            subtitle = "MEMBER JOINED"
            if char_key == "sacagawea":
                body = (
                    f"{base['title']}\n\n"
                    "She joins at Fort Mandan — interpreter, guide, and steady presence "
                    "as the corps pushes west."
                )
            else:
                body = (
                    f"{base['title']}\n\n{name} now appears on the party roster and "
                    "travels with the Corps of Discovery."
                )
            acc = assets.TEAL2
        else:
            s.add_journal(f"{name} has left the expedition.")
            title = f"{name} has departed"
            subtitle = "MEMBER LEFT"
            body = f"{name} is no longer listed on the active party roster."
            acc = assets.AMBER
        self._update_journal()
        art = (getattr(assets, "IMG_PORTRAITS", None) or {}).get(char_key)
        self._narrative_overlay = {
            "title": title,
            "body": body,
            "subtitle": subtitle,
            "accent": acc,
            "art": art,
        }

    def _check_objectives(self):
        s = self.state
        if s.current_wp >= 4 and 0 not in s.completed_objectives:
            s.completed_objectives.append(0)
            s.add_journal("OBJECTIVE COMPLETE: Wintered at Fort Mandan.")
            s.characters["sacagawea"]["active"] = True
            self._notify_party_roster_change("sacagawea", joined=True)
        if s.current_wp >= 7 and 1 not in s.completed_objectives:
            s.completed_objectives.append(1)
            s.add_journal("OBJECTIVE COMPLETE: Crossed the Continental Divide!")
        if s.current_wp >= 9 and 2 not in s.completed_objectives:
            s.completed_objectives.append(2)
            s.add_journal("OBJECTIVE COMPLETE: Reached the Pacific Ocean!")
            self._update_journal()
            self._start_end_game()
            return
        if s.peaceful_tribes >= 3 and 3 not in s.completed_objectives:
            s.completed_objectives.append(3)
            s.add_journal("OBJECTIVE COMPLETE: Peaceful relations with 3 tribes.")
        if s.discoveries >= 5 and 5 not in s.completed_objectives:
            s.completed_objectives.append(5)
            s.add_journal("OBJECTIVE COMPLETE: Five discoveries documented.")
        self._update_journal()
