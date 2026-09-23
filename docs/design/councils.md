# Councils

Draft, 2026-09-19; staged in the world 2026-09-21. Data in `godot/data/councils.json`,
rules in `godot/scripts/rules/council.gd`, played as the Scenario
`godot/data/scenarios/council_bluff_1804.json` (see [scenarios.md](scenarios.md)). The
panel it began as is gone.
Built on [ADR-0005](../adr/0005-scenarios-as-json-graphs.md) (Scenarios are data)
and [ADR-0004](../adr/0004-no-combat-against-people.md) (no combat against people).

## The shape of it

A council is a handful of **steps**, each a Skill Check whose odds are shown before
it is rolled. What raises the odds is what the captains **lay out on the ground**
from the Stores: the goods the chiefs asked for count most, anything else counts a
little, and the council's own momentum carries into the steps that follow.

Each step can be taken or passed by. Passing by what was asked for is remembered
and costs standing. At the end, `verdict()` says how the Nation parts from the
Corps, and that goes in the Journal.

The rules are pure — `resolve(step, roll)` takes the roll from the caller — so the
whole thing is testable without a scene. A Scenario plays the steps: each is a
choice in the world, giving what the step asks for or passing it by, with the odds
and `breakdown()`'s reasons shown beside it.

## The first council: 3 August 1804, Council Bluff

This is the real one, on the ground the Vertical Slice opens on, and it sets the
pattern:

- **Six chiefs were made under the American government** that day, with medals in
  three grades: first for the great chief, second for the two second chiefs, third
  for the rest, with commissions, a flag and clothing.
- **The great chief, Little Thief, was away on the buffalo hunt.** His medal and a
  copy of the speech had to be sent after him. Passing that by is a slight the
  game remembers.
- **Lewis fired the air gun**, as he did at every gathering; the journals say it
  astonished them.
- **Every chief closed by asking for "a little Powder & a Drop of Milk"** — powder
  and whiskey. Giving it wins the day and costs the Corps what they must live on;
  refusing is remembered. That is the whole tension of the expedition's diplomacy in
  one choice, and it is not invented.

## What it does to the rest of the game

- Presents leave the Stores through `give()`, so the hold really empties. Spend the
  medals here and there are fewer for the Teton Sioux.
- Standing raises morale on a good council and lowers it on a bad one.
- `gift_regard()` on the Stores is what is left to bargain with later.

## Still to do

- ~~Standing should persist per Nation~~ — done: `state.standing[nation]`, set by the
  evening before (`oto_arrival`) and carried out of the council. Still to do: word of
  it travelling upriver ahead of the Corps.
- The **Teton Sioux stand-off** is the same machinery with the stakes reversed: they
  hold the river, and what is left in the hold decides how the meeting goes. It is
  **staged in the world** at Bad River, not in a panel — the Corps at the bank, the
  Teton on it, Black Buffalo and the Partisan present, the swivel gun manned or not —
  and it can end the Slice badly (turned back, or a crippling toll) without ever
  becoming combat (ADR-0004).
- Speech quality should depend on who is present (Drouillard interpreting, York,
  the captains' own Corps Skills), not only on whether an interpreter is there.
- ~~The chiefs should be in the world~~ — done: the men who came in on the evening of
  2 August walk up from their fire to the sail awning at the camp, where the council
  really sat (not on the bluff), and stand in a half-ring for it.
- The seats now carry the names Clark gave on 3 August: Big Horse (Shingotongo) and
  Hospitality made second chiefs; Wau-pe-ur, Au-ho-ning-ga, Ba-za-con-ja and
  Au-ho-ne-ga given third-grade medals; Little Thief away on the hunt.

## Sources

- [Journals of the Lewis and Clark Expedition, 3 August 1804](https://lewisandclarkjournals.unl.edu/item/lc.jrn.1804-08-03) (the council, the medals in three grades, "a little Powder & a Drop of Milk")
- [Discovering Lewis & Clark — The Otoes and Missourias](https://lewis-clark.org/native-nations/siouan-peoples/otoes-and-missourias/)
- [The Otoe-Missouria Tribe — Lewis & Clark](https://www.omtribe.org/who-we-are/history/lewis-clark/) (Šóge thą́ka, "Big Horse"; Little Thief absent, met later on 18 August)
- [Ronda, *Lewis & Clark among the Indians*](https://lewisandclarkjournals.unl.edu/item/lc.sup.ronda.01.01)
