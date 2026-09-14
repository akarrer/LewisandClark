"""The Ending: how the expedition concluded, and what it cost."""

from __future__ import annotations

import pygame
from lewis_clark import assets, corps
from lewis_clark.drawing import darken, draw_text
from lewis_clark.input import Action

ENDINGS = {
    corps.REACHED_PACIFIC: (
        "Ocean in View!",
        "The Corps of Discovery has crossed the continent and reached the Pacific. "
        "The journey home is a story still to be written.",
    ),
    corps.LEADER_DIED: (
        "Captain Lewis Is Dead",
        "Without its captain the Corps turns for home. Clark leads the survivors back down the river, "
        "and the West keeps its secrets a while longer.",
    ),
    corps.CORPS_COLLAPSED: (
        "The Corps Is Broken",
        "Too few men remain to haul the boats and hold the trail. The expedition turns back.",
    ),
    corps.MUTINY: (
        "Mutiny",
        "Hunger and hopelessness end in open refusal. The men will go no farther west.",
    ),
    corps.LOST_SEASON: (
        "A Lost Season",
        "Caught by winter with nothing left to eat, the Corps cannot last until spring on the trail. "
        "The expedition is abandoned.",
    ),
}


class EndingScreen:
    def __init__(self, state, on_done):
        self.state = state
        self.on_done = on_done

    def handle_action(self, action):
        if action in (Action.CONFIRM, Action.MENU, Action.BACK):
            self.on_done()

    def on_resize(self):
        pass

    def draw(self, surf):
        s = self.state
        F = assets.F
        W, H = assets.SW, assets.SH
        surf.fill((22, 17, 12))
        title, text = ENDINGS.get(s.ending, ("The Expedition Ends", ""))
        good = s.ending == corps.REACHED_PACIFIC
        col = assets.GOLD if good else (206, 110, 80)
        w = min(900, W - 80)
        x = W // 2 - w // 2
        y = int(H * 0.16)
        y = draw_text(surf, title, F["huge"], col, (W // 2, y), anchor="midtop") + 18
        pygame.draw.line(surf, darken(col, 0.6), (x, y), (x + w, y), 1)
        y += 18
        y = draw_text(surf, text, F["narr"], assets.CREAM, (x, y), max_w=w) + 24

        region = assets.REGIONS[s.current_region]["name"]
        visited = len(s.landmarks_visited)
        total = sum(len(r["landmarks"]) for r in assets.REGIONS.values())
        lines = [
            f"{s.full_date_str}  ·  {region}",
            f"{s.corps_strength} men of the Corps remain  ·  {visited} of {total} Landmarks visited",
        ]
        fates = []
        for key, m in s.party.items():
            if not m["alive"]:
                fates.append(f"{corps.name(key)} died")
            elif s.characters[key].get("active"):
                fates.append(f"{corps.name(key)} survived")
        lines.append("  ·  ".join(fates))
        for line in lines:
            y = draw_text(surf, line, F["body"], assets.PARCH_LT, (W // 2, y), anchor="midtop") + 8

        draw_text(surf, "Press Enter or A to return to the title", F["small_i"], darken(assets.PARCH_LT, 0.8),
                  (W // 2, H - 60), anchor="midtop")
