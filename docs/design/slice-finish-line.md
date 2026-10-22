# Council Bluff — the finish line

ADR-0014 says the showcase Region is done when (1) every system it needs is
present, (2) its scenery meets a written standard, and (3) one uncoached
twenty-minute playthrough by someone other than the developer holds up. This
page is that written test. Tick a line only when it is true on `main`.

## 1. Systems present

- [x] Data-defined Region (`data/regions/council_bluff.json`), named places, foliage, wildlife
- [x] 45-man Corps simulation + Morning Report (R / RB)
- [x] Stores rationed by the Day Clock; Inventory (I / Y)
- [x] Weather, sky, moon, day length from the almanac
- [x] Staged Scenarios with visible-odds checks: clark_birthday, floyd_sick_call, oto_arrival, council_bluff_1804, la_liberte
- [x] Council of 3 August drives the Council rules; per-Nation standing
- [x] Discoveries from Region data (badger)
- [ ] Title screen (ADR-0008: live night camp) — not built
- [ ] Opening (ADR-0008: ~85 s in-engine, Lewis VO) — script approved, not built
- [ ] A way the Slice *ends*: after the last beat the player is told the demo is over and what happened (verdict, Corps state)
- [ ] Save at camp / autosave on Region entry
- [ ] Rifle stalk (1 / X) and spyglass sketching (2 / LB) — check each does something a tester can finish

## 2. Scenery standard

Judged from the autopilot scenery tour (`--autopilot --scenery --corps`) at
1080p, plus a free walk. Each line must hold from the Leader's own camera, not
only from the chosen views.

- **No artefacts at a glance.** No straight seams, ruled lines, glowing blobs, floating or buried plants, stair-stepped shadows, flicker or popping inside 100 m.
- **The river reads as the Missouri.** Muddy caramel, moving, with seams, boils and eddies; shore and water are told apart at a glance from bank, bar and bluff top; reflections at dawn and dusk.
- **Every near plant is a plant of that place.** Cottonwoods, bur oaks, willows, dogwood, buckbrush, big bluestem; no kit-blob bushes or out-of-region flowers within 60 m.
- **The far country matches the near.** Distant hills share the prairie's straw; far groves sit in hollows; haze is warm grey by day.
- **Every hour is worth looking at.** Dawn, noon, storm, sunset, dusk, moonlit night each pass a still from the tour that you would put on the Steam page.
- **People look dressed and alive.** Cloth not bodysuits, hats, kit; own gait; camp life at the fire; no limbs through cloth at walking pace.
- **Performance floor (ADR-0015).** ≥ 60 fps 1% low at 1080p on a GTX 1660-class card in a `--march` walk. *(Measured only on the RTX 5060 Ti so far — needs a 1660-class run.)*

## 3. Playtest-ready

What an uncoached tester needs before the session counts:

- [ ] An exported Windows build (no `export_presets.cfg` yet) handed over as a zip
- [ ] Controls shown on first need (move, look, interact, map, report), keyboard or pad
- [x] The HUD names the place from the Region file (was hard-coded "Sioux Country")
- [ ] The Oto and Missouria cast look like themselves: today they are dark mannequins carrying the Corps' rifles and kit (ADR-0013; needs the cultural review)
- [ ] Choices say why they're being asked: the 1 Aug prompt reads "Send the hunters out for his dinner" with no sign it is Clark's birthday
- [ ] The `--slice` autopilot finishes every time: 3 of 4 runs on 2026-10-21 shot all 7 beats; the one where Trail Moments (floyd_pain, thunderstorm) fired on 1 Aug stalled before the dinner and never finished. Moments are unseeded, so it is random — find what holds it, then seed the director for repeatable runs
- [ ] The first five minutes point the player at something to do (hunters, Clark's birthday) without a coach
- [ ] Nothing debug on screen (fps counter off by default)
- [ ] A short feedback form: where were you lost, what did you want to do and couldn't, what did you remember

## 4. The playtest

One person who has not seen the game plays ~20 minutes, uncoached, while the
developer watches silently and takes notes. It holds up if they finish the
three days without asking how, and they would keep playing. Record the
result here with the date and build commit.
