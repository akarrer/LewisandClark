# Scenarios, staged in the world

A Scenario is a branching, choice-driven story moment (CONTEXT.md), authored as a JSON node graph (ADR-0005) in `godot/data/scenarios/<id>.json` and staged in the world rather than in a panel: the people involved walk in and stand where it happened, lines play as subtitles, and choices come up low on the screen while the world keeps running.

## The pieces

- `scripts/rules/scenario.gd` — the logic only: whether a Scenario is due, which choices stand open, a Skill Check's odds and the reasons for them, and what each outcome does to the Corps, the Stores and the Expedition.
- `scripts/world/scenario_stage.gd` — the cast walking in from one named place to another, and cues (guns fired, a salute returned).
- `scripts/ui/scenario_prompt.gd` — subtitles and the choice list, with odds shown as a percentage and each reason beside it.
- `main.gd` — starts whatever is due, holds a node that waits on the world (`"wait": "arrival"`: the cast is in and the Leader has walked out to them), and slows the Day Clock to a tenth while a Scenario plays out around the Leader, so a few minutes of talk are half an hour of evening, not five hours.

## A Scenario file

- `when`: `region`, `date`, `after_hour`, and optionally `requires` (conditions on the Corps, such as Floyd still being sick). Plays once (`state.flags["scenario:<id>"]`). A Scenario still waiting when its day is over lapses, so an evening nobody came down to never blocks the next day.
- `cast` and `stage` (`from`, `to` as the Region's named places). A test holds that the cast can walk in and the Leader walk out without going round a bluff.
- `nodes`: each has `lines`, `effects` on entry, `choices`, and optionally `end`, or a `wait` with a `hint` toast: `arrival` (the cast is in and the Leader has walked out to them), `hour:<h>`, or `at:<place>`. Only an arrival slows the clock; the day goes on as usual while a Scenario waits on the evening, and Trail Moments keep playing.
- A choice has `label`, `note`, `when` (it is hidden unless met), `cost` (it is shown closed, with why, unless the Stores can pay), `effects`, `reply` lines (plus `reply_pass` / `reply_fail`, so what is said after follows the roll), and either `next` or a `check` with `pass` / `fail`.
- A Scenario may hold a council (`"council": "<id>"`): a choice with `"council": {"step", "offer": "asked" | "refuse": true}` plays that step through the Council rules, which keep the odds, the presents and standing; the `council_close` effect writes standing back to the Nation and puts the verdict in the Journal.
- `stage.reuse` walks a staged cast that is still in the world on to the new place instead of bringing on new people.
- A check is `base` plus `mods`, each `{"when", "add", "why"}`; the player sees the chance and the reasons before choosing.

Conditions: `present`, `absent`, `status`, `sick_with`, `flag`, `not_flag`, `all_flags`, `no_flags`, `item`, `fit_at_least`, `standing_at_least`. Effects: `journal`, `standing`, `hearten`, `flag`, `status`, `take`, `give`, `hides`, `fatigue`, `cue`, `physic` (Lewis's physic from the medicine chest), `excuse`, `health`. Tests reject anything else.

## Standing carries between meetings

`state.standing[nation]` is each Nation's regard for the Corps. The Oto arrival sets it the evening before the council; the council opens at it and writes back what it ends at. This is the first half of the councils doc's "standing should persist per Nation".

## Built so far

- **`la_liberte`** — 3 August, after the council, while the engagé sent to the Oto towns is still not come up. Send Drouillard and Reubin Field (they leave camp, and Drouillard off the hunt), or ask the Oto to look as they go home (open only if they think well enough of the Corps), or let him go. The party is out until dark: the node waits, and its effects hold until it does. He may be brought in or not — only deaths are fixed (ADR-0003).
- **`clark_birthday`** — 1 August 1804, the morning the game opens: Clark's thirty-fourth birthday. Send the hunters (a Skill Check that reads who is in camp: Drouillard's traps, Joseph Field, Gibson, Shields), send Pryor's mess for fruit, or neither. At the fire that evening the table is what the day brought, up to Clark's own: a saddle of venison, an elk fleece, a beaver tail, and a dessert of cherries, plums, raspberries, currants and grapes. An extra gill for his health costs a gallon and a half of whiskey.
- **`floyd_sick_call`** — 2 August, morning, only while Floyd is still sick with his colic ("I am verry Sick and has been for Somtime", 31 July). Rush's pills, the lancet, rest in the boat, or his word that he is mending. None of it changes 20 August (ADR-0012).
- **`council_bluff_1804`** — 3 August, morning: parade the Corps or not; the chiefs walk up from last night's fire to the mainsail awning at the camp; the speech, the medals (six, in three grades), the air gun, their ask for powder and "a drop of milk", Little Thief's medal sent after him. Odds and presents are the Council rules; the Corps sets out at three.
- **`oto_arrival`** — 2 August 1804, toward sunset: the Oto and Missouria come in up the bottom firing guns, with Fairfong. Answer with the swivel gun or stand to arms; ask after La Liberté (he becomes missing); send pork, flour and meal, or tobacco, or nothing, as a Skill Check that watermelons come back; set the guard. Oto and Missouria presence, speech and dress are placeholders pending the cultural review (ADR-0004, ADR-0013).

Verify any of them with `-- --autopilot --scenario=<id> --shots=<dir>`: it jumps to the date and hour, chooses for itself, winds the clock to any hour a node waits for, walks to any place one waits at (or out to meet a cast), and photographs each step.

## Discoveries

A Region's `features.discoveries` list puts a specimen in the world — a skin on a willow frame by the fire — which goes into the Journal and the Discovery count when the Leader looks it over. Council Bluff has the badger Joseph Field killed on 30 July, the first zoological specimen Lewis preserved.

## The Region end to end

`-- --autopilot --slice --shots=<dir>` plays 1 to 3 August with the prompt choosing for itself: the hunters and the birthday dinner, Floyd's sick call, the Oto coming in at dusk, the council under the sail, the search for La Liberté, and the badger written up. Seven screenshots, and the Day Clock is wound through two midnights so the Corps lives the days.
