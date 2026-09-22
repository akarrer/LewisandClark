# Scenarios, staged in the world

A Scenario is a branching, choice-driven story moment (CONTEXT.md), authored as a JSON node graph (ADR-0005) in `godot/data/scenarios/<id>.json` and staged in the world rather than in a panel: the people involved walk in and stand where it happened, lines play as subtitles, and choices come up low on the screen while the world keeps running.

## The pieces

- `scripts/rules/scenario.gd` — the logic only: whether a Scenario is due, which choices stand open, a Skill Check's odds and the reasons for them, and what each outcome does to the Corps, the Stores and the Expedition.
- `scripts/world/scenario_stage.gd` — the cast walking in from one named place to another, and cues (guns fired, a salute returned).
- `scripts/ui/scenario_prompt.gd` — subtitles and the choice list, with odds shown as a percentage and each reason beside it.
- `main.gd` — starts whatever is due, holds a node that waits on the world (`"wait": "arrival"`: the cast is in and the Leader has walked out to them), and slows the Day Clock to a tenth while a Scenario plays out around the Leader, so a few minutes of talk are half an hour of evening, not five hours.

## A Scenario file

- `when`: `region`, `date`, `after_hour`. Plays once (`state.flags["scenario:<id>"]`).
- `cast` and `stage` (`from`, `to` as the Region's named places). A test holds that the cast can walk in and the Leader walk out without going round a bluff.
- `nodes`: each has `lines`, `effects` on entry, `choices`, and optionally `wait` or `end`.
- A choice has `label`, `note`, `when` (it is hidden unless met), `cost` (it is shown closed, with why, unless the Stores can pay), `effects`, `reply` lines, and either `next` or a `check` with `pass` / `fail`.
- A check is `base` plus `mods`, each `{"when", "add", "why"}`; the player sees the chance and the reasons before choosing.

Conditions: `present`, `absent`, `status`, `flag`, `not_flag`, `item`, `fit_at_least`, `standing_at_least`. Effects: `journal`, `standing`, `hearten`, `flag`, `status`, `take`, `fatigue`, `cue`. Tests reject anything else.

## Standing carries between meetings

`state.standing[nation]` is each Nation's regard for the Corps. The Oto arrival sets it the evening before the council; the council opens at it and writes back what it ends at. This is the first half of the councils doc's "standing should persist per Nation".

## Built so far

- **`oto_arrival`** — 2 August 1804, toward sunset: the Oto and Missouria come in up the bottom firing guns, with Fairfong. Answer with the swivel gun or stand to arms; ask after La Liberté (he becomes missing); send pork, flour and meal, or tobacco, or nothing, as a Skill Check that watermelons come back; set the guard. Oto and Missouria presence, speech and dress are placeholders pending the cultural review (ADR-0004, ADR-0013).

Verify with `-- --autopilot --scenario=oto_arrival --shots=<dir>`: it jumps to the date and hour, chooses for itself, walks out to meet the cast, and photographs the evening.
