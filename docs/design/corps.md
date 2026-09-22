# The Corps simulation and the Morning Report

ADR-0010 commits the game to simulating every man. This is how, as built. The roster and every number live in `godot/data/corps.json`; the arithmetic is `godot/scripts/rules/corps.gd`; the screen is `godot/scripts/ui/morning_report.gd`.

## The roll

Forty-six men, from the captains' Detachment Order of 26 May 1804 ([journals](https://lewisandclarkjournals.unl.edu/item/lc.jrn.1804-05-26)): the captains with York and Drouillard; the three Messes of Sergeants Floyd, Ordway and Pryor, who crew the keelboat; Corporal Warfington's soldiers on the white pirogue; and the engagés under their patroon Deschamps on the red pirogue. La Liberté starts away at the Oto towns, so forty-five eat at Council Bluff. Floyd starts sick: he wrote on 31 July that he had been "verry Sick" for some time.

Each man carries health, Conditions, fatigue, footwear, clothes and morale, and a status (present, away, missing, deserted, dead). Corps Strength is counted from them: present, above the fit threshold, and without a Condition that stops work.

## Command

Only the three sergeants' Messes take orders. Each morning the captain sets each of them one duty for the day in camp: rest, hunt, dry the stores, make moccasins, or work on the boats. On a Leg day every man not with the captains works the boats. The captains' party, Warfington's soldiers and the engagés are reported on but not commanded. Drouillard hunts every day he is able.

Two calls on single men: excuse him from duty (he rests and mends faster; his Mess is a man short), or give him physic from the medicine chest. Physic is 1804 physic: Rush's pills shorten a flux by a day and weaken the man; Peruvian bark genuinely shortens a fever. Nothing touches Floyd's bilious colic.

## A day

Resolved at the midnight that ends it:

1. **Hunting.** Each hunter rolls for a deer or an elk; hunters by trade do better. Meat goes to the Stores, hides to the moccasin pile.
2. **Boats.** Travel wears the hulls and may snag the keelboat. Men on repair patch the worst hull; carpenters and blacksmiths count double. Under half, the keelboat leaks into her own hold.
3. **Wet stores.** Rain wets the spoiling goods in the open pirogues; a leaking keelboat wets hers. Wet goods lose a share a day until a Mess dries them (six men dry everything in a day). Powder is sealed in lead canisters and never gets wet.
4. **Ration and gill.** Rations come from the Stores in their existing order; a short ration makes every man Starving. Fresh meat left over loses half a day.
5. **Each man.** He sleeps off a share of his fatigue (less if he is unwell) and his duty puts its own load back on, so fatigue settles rather than climbing without end. Footwear wears on the towline and the hunt, and is remade from hides. Conditions run their course. New sickness is rolled against his duty, fatigue, the heat and his rations; worn-through moccasins on shore make him lame; fatigue over 85 exhausts him.
6. **History's dates.** Fixed events apply whatever has been done (ADR-0012): Floyd is taken with bilious colic on 19 August and dies on the 20th.
7. **Morale.** Drifts toward a target set by the gill, the ration, rest, the fiddle, and fatigue. A death strikes everyone.

## The Morning Report

At first light the HUD says the sergeants have reported (R, or RB on a gamepad). Each Mess is spoken for by its sergeant: who is sick, lame, near barefoot or away, and how many are fit. A Mess without its sergeant is spoken for by a private until one is appointed. Ordway, the orderly sergeant, speaks for the stores: days of provisions, days of whiskey, the hunters' kill, what is wet, which boat is leaking or wants caulking, and hides in hand.

## Tuning

`godot/tools/corps_trial.gd` runs the Corps for N days under one standing plan and prints a line a day:

```
godot --headless --path godot -s tools/corps_trial.gd -- --plan=mixed --days=30
```

As tuned, with pressing on every day, footwear gives out within a fortnight and nearly half the Corps is lame or sick by the end of the month. Laying by one day a week to hunt, dry and make moccasins keeps thirty-odd men fit. That gap is the decision ADR-0010 is for.

## Not yet

- Legs do not exist in the Godot build, so travel days are exercised only by the trial tool and tests.
- The collapse and mutiny endings are computed (`Corps.ending()`) but no ending screen reads them yet.
- Desertions (Reed on 4 August, La Liberté) are left to Scenarios: soft history fixes only deaths.
- The two horses Drouillard and Shields hunt on are counted, not simulated, until the crossing.
