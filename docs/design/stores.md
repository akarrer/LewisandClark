# The Stores

Draft, 2026-09-19. What the Corps carry, where it is stowed, what it weighs, and
what it is for. Data lives in `godot/data/stores.json`, arithmetic in
`godot/scripts/rules/stores.gd`, the screen in `godot/scripts/ui/inventory.gd`.

## Why an inventory at all

Three reasons, all of them the expedition's own:

1. **Weight is the enemy.** Everything upriver is a fight against a loaded boat and
   a current. When portages come, what you carry is the whole problem.
2. **Presents are diplomacy.** Jefferson's instructions and Lewis's shopping list
   both treat trade goods as the main instrument of the mission. Running out of
   blue beads before the Teton Sioux is a story, not a spreadsheet.
3. **Provisions run down.** Pork, flour and whiskey are a clock; hunting resets it.

## What SCUM gets right that we want

- Every item has real **weight**, and the weight is always visible against a
  capacity, so loading is a decision.
- **Containers** matter: what is in which boat, what is on your back.
- Item detail is **specific** rather than generic ("193 lb of portable soup", not
  "food ×193"), which is what makes rummaging enjoyable.

## What we do differently

- **Not a grid.** Tetris-packing thirty barrels of flour is busywork. Our holds are
  weighed, not shaped. (If a grid ever earns its place, it will be the packs at a
  portage, not the keelboat.)
- **No looting.** The Corps outfit once, in Philadelphia, and then live off what
  they have and what they kill or are given.
- **Presents carry `regard`** — what a Nation is likely to think of the gift — so a
  council can read the hold rather than a single "reputation" number.

## The holds

| Hold | Burden | Carries |
|---|---|---|
| Keelboat | 24,000 lb (about twelve tons) | The bulk: flour, pork, powder, lead, most presents |
| Red pirogue | 9,000 lb | Medicine chest, wine, the presents kept ready for councils |
| White pirogue | 8,000 lb | Corn, salt, biscuit, tools, the spare beads |
| Packs ashore | 900 lb | Arms, instruments, knapsacks: what the men carry |

## The model

`Stores` loads the manifest and does the arithmetic: `weight(hold)`, `load_of(hold)`
(0–1, over 1 is overloaded), `ration(men, days)` drawing pork, then hominy, flour,
biscuit, and portable soup last because the men hated it; `spoil(severity)` for
damp, which reaches provisions and not chronometers; `give(id, n)` and
`gift_regard()` for councils. It saves as a flat id → quantity dictionary.

## Wired to the Day Clock

Each midnight the Day Clock crosses, the Corps eat: fresh meat first because it
will not keep, then salt pork, hominy, flour, biscuit, and portable soup last.
Each figure in `RATION` is what that food alone would take to feed a man for a
day — the Corps were soldiers doing the work of draft animals, and the journals
put them at nine pounds of meat a man on a good day, with a pound and a half of
pork or meal issued when there was no game.

A hunt puts meat in the hold as well as heart in the men. Rain in an open boat
gets into the flour, and meat turns in a day in an August on the Missouri. When
the ration will not stretch to the whole party they go hungry and the Journal
says so, and when a staple is broached to the last of it the Journal says that too.

At the start that is about 183 days of provisions for 45 men: enough to reach the
Mandan and winter there, if the hunting holds. The HUD carries the count.

## Still to do
- **Councils spend presents** through `give()`, with `regard` feeding the Skill Check
  odds, and the Teton Sioux stand-off reading what is left.
- **Portage** compares `packs` weight against what the Corps can carry.
- **Moving goods between holds** in the screen (drag, or select-and-send).
- A **spoilage event** when a pirogue swamps — which is what nearly happened to the
  white pirogue in May 1805, papers and instruments and all.

## Sources for the manifest

Quantities marked `recorded` in the JSON come from these; the rest are reasoned
from the same record and marked by omission.

- [Discovering Lewis & Clark — Outfitting the Expedition](https://lewis-clark.org/the-trail/eastern-beginnings/lewis-in-philadelphia/outfitting-the-expedition/) (Israel Whelan's purchases for Lewis, Philadelphia 1803: portable soup, powder in lead canisters, kettles, beads, brooches, looking glasses, calico shirts, jew's harps, chronometer)
- [National Archives — List of purchases made by Meriwether Lewis](https://www.archives.gov/historical-docs/list-of-purchases-made-by-meriwether-lewis)
- [Discovering Lewis & Clark — Trade Beads](https://lewis-clark.org/fur-trade/trade-beads/) ("the blue is usually prefered to the white"; beads as the currency of the river)
- [Discovering Lewis & Clark — Portable Soup](https://lewis-clark.org/tools-and-techniques/cooking/portable-soup/) (193 lb at $1.50 the pound)
- [NPS — Alcohol and the Lewis and Clark Expedition](https://www.nps.gov/articles/alcohol-and-the-lewis-and-clark-expedition.htm) (120 gallons of whiskey, a gill a man a day)
- [Ronda, *Lewis & Clark among the Indians*](https://lewisandclarkjournals.unl.edu/item/lc.sup.ronda.01.01) (what Lewis expected to be asked for: blue beads first, then brass buttons, awls, kettles, tomahawks)
