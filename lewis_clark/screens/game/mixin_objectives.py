"""Waypoint / expedition objectives checks."""

from __future__ import annotations


class ObjectivesMixin:
    def _check_objectives(self):
        s = self.state
        if s.current_wp >= 4 and 0 not in s.completed_objectives:
            s.completed_objectives.append(0)
            s.add_journal("OBJECTIVE COMPLETE: Wintered at Fort Mandan.")
            s.characters["sacagawea"]["active"] = True
            s.add_journal("Sacagawea joins the corps at Fort Mandan.")
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
