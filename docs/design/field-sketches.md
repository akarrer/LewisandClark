# Field Sketches — a Pokémon Snap loop inside the Journal

Draft, 2026-09-19. Not decided, not an ADR yet. Species list and dates:
[species-of-the-expedition.md](../research/species-of-the-expedition.md).

## The idea in one line

Lewis's field book is the camera: you creep up on a living animal, frame it, and
draw it; the quality of the plate is scored the way Pokémon Snap scores a photo,
and good plates become Discoveries in the Journal.

## Why it fits this game rather than being bolted on

- **Discovery already exists** and already grants a lasting benefit, but the act of
  making one is a timer: stand near the prairie dogs long enough. Sketching gives that
  act a skill, a risk and a reason to look closely at scenery we have been building.
- **It is what the expedition actually did.** Jefferson's orders were to observe and
  record. The Corps' cargo home was pressed plants, skins, bones, and four live magpies.
- It uses the world we have: wary animals that flush at ~45 m, a day clock, weather,
  the keelboat that sails home in spring 1805 with everything you collected.
- It is entirely non-violent, which keeps it clear of
  [ADR-0004 (no combat against people)](../adr/0004-no-combat-against-people.md) and sits
  beside hunting rather than replacing it.

## The loop

1. **Spot.** Something moves in the grass. Lewis's Survey ability highlights subjects
   worth drawing; Drouillard's Scout Ahead reveals which are nearby today.
2. **Stalk.** Wind direction and your speed decide how close you get. Walking is quiet,
   jogging flushes. Tall grass hides you; crossing bare sand does not.
3. **Sketch.** Raise the spyglass (`2`) and hold on the subject: the glass is the
   sketching tool, and the rifle (`1`) is the hunting one. Time does not stop.
   Release to draw. Drawing takes a few seconds in which the animal may move — that is
   the tension, and it is honest: a sketch is not a snapshot.
4. **Score the plate** (below), then it lands in the Journal with Lewis's own words
   where we have them ("Brarow … this animale burrows in the ground").
5. **Ship it.** Plates and specimens fill the keelboat's hold; at Fort Mandan in spring
   1805 the barge carries them to Jefferson and the game scores the shipment. In the
   Slice, the tally lands at the end of the leg instead.

## Scoring a plate

Snap's four axes, renamed to the period, all shown as a short critique in the Journal:

| Axis | What it rewards |
|---|---|
| **Subject** | How large and how centred in the frame; a head-on portrait beats a distant speck. |
| **Bearing** | What the animal is doing: grazing, alert, calling, in flight, fighting, with young. Rare behaviours are worth the most. |
| **Ground** | Whether the setting says something: a prairie dog town, terns on a bar, a badger at its sett, the herd against the bluffs. |
| **Nerve** | How close you were, and whether it stayed. Flushing the subject caps the plate at "Rough". |

Grades: **Rough / Fair / Good / Fine plate**. Only Good or better makes a Discovery;
Fine plates are what a completionist re-stalks for, and are the trailer shots.

## Specimens, the other half

A sketch is evidence; a specimen is proof. Some species also allow a **Specimen**:
press a plant between sheets, skin a bird, or take one alive (the Corps flooded a
prairie dog out of its burrow to do exactly that). Specimens need a Skill Check, cost
time or powder, and can spoil — but they are worth double at the shipment, and some
Discoveries (the badger, the prairie dog) are only complete with one.

Glossary note: `CONTEXT.md` currently lists "specimen" under _avoid_ for **Discovery**.
If we build this, Specimen needs to become its own term, and Discovery stays the
Journal entry rather than the physical thing.

## Easter eggs — embedding the real record

The rule: **a species appears where and when it really did.** That turns the research
list into level design, and it rewards a player who reads.

- **The badger at Council Bluff, 30 July.** Its sett is on the bluff slope from the
  first hour of the Slice. Sketch it and the Journal notes it was Lewis's first
  specimen of the whole expedition. Miss it and it is gone in a few days.
- **Least terns on the bars, 5 August**, and the pelican flock of "several hundred"
  on 8 August — a Trail Moment where the river goes white.
- **The prairie dog town** we already have becomes the 7 September "barking squirrels",
  with the flooding-out as an optional group effort involving the whole Corps.
- **Bison do not exist before 23 August.** A player who knows the journals will notice,
  and the first herd should be a horizon-wide Trail Moment when it comes.
- **Seasonal and hourly gates:** poorwills at dusk, fireflies over the bottomland after
  dark (already in), pelicans riding a thermal after a storm clears, elk bugling as
  September wears on.
- **Behaviour rarities**, not fake albinos: a badger and a coyote hunting the same
  town together (real, documented), a magpie robbing the camp kettle, a bull pronghorn
  outrunning the keelboat along the bank.
- **Named finds:** reaching *Lewisia* and *Clarkia* in later regions gives the two
  plates that carry the men's own names — a long-game reward for the Slice player.

## What it would take

- `data/species.json`: id, names (including recorded Native names), scientific name,
  first-record date and place, `new_to_science: true|false|contested`, habitat
  predicate (bar, bottomland, upland, draw, water), hours, weather, behaviours, the
  journal quotation, and the lasting benefit a Discovery grants.
- A **Sketch** mode on the Leader: framed camera, stillness check, draw timer.
- Scoring from what the game already knows: subject screen size and centre, behaviour
  state, habitat under the subject, distance, and whether it fled.
- Journal UI: plates with their critique, sorted by date, blanks for what you missed.
- Wildlife needs behaviour states worth drawing (we have graze / alert / flee; add
  call, drink, spar, nurse) and a few set-piece flocks.

## Decided (direction session, September 2026)

1. **Scope in the Slice:** the species actually recorded in August and September 1804,
   not a hand-picked few.
2. **The sketch does not pause play.** The Corps keep walking and the moment can be lost.
3. **No numbers.** The grade word (Rough / Fair / Good / Fine) and a period critique in
   the Journal are the whole of the score.
4. **Two tools, two keys.** The spyglass sketches and the rifle hunts, so studying an
   animal and shooting it for the pot are separate choices made with the hand. A kill
   can still yield a specimen.
