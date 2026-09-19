# A live title scene and an ~85-second in-engine Opening

The Godot build gets a title screen that is itself a live scene, a night camp on the Missouri on 29 July 1804, which flows without a cut into an Opening of about 85 seconds rendered in-engine and ending with the player in control at Council Bluff. The Pygame build's seven-panel slideshow (typewriter narration, "Did you know" facts, Next/Back) is not ported: it spends minutes on reading before any play, and it ends in May 1804, three months before the Vertical Slice begins.

The Opening's jobs, in priority order, are to hook a Steam or itch player who knows little of the history, then to orient them and give only the history needed to understand why they are here. Being clippable into the Steam trailer is a rule for every shot (clean 16:9, no UI), not a segment of its own. Fuller history moves to an optional painted Prologue and to the Journal.

## Shape

- **Title:** firelight, the moored keelboat, stars, and a Corps fiddler playing Soldier's Joy, with the music coming from the scene itself. Menu: Continue / New Expedition / Prologue / Settings / Quit. The wordmark is a placeholder until the game's name is decided. "New Expedition" fades the menu, the camera tilts into the stars, and the fiddle fades to black, which is the Opening's first beat.
- **Beats:** (1) black, the river and oars; Lewis's voice: *"July the 30th, 1804…"* (2) sunrise over the keelboat, which lurches on a snag and is poled free (3) the aerial terrain dissolves into the 1804 map from the same angle, an ink line traces St. Louis to here, then it dissolves back (4) the camera comes down as the Corps comes ashore below the bluff, with handwritten name cards for Clark, York and Drouillard (5) smoke on a far ridge and an interpreter's muttered line about the Sioux upriver. Control arrives while the voiceover finishes. The Teton threat is only hinted at, so the Stand-off lands harder.
- **Date:** 30 July 1804, the real arrival at Council Bluff (the council was 3 August).
- **Voice:** Lewis in the first person, as journal entries, voiced by the project owner. Formal and reflective, with no attempt at an accent. The script paraphrases real journal lines lightly (ADR-0003). There are no text-to-speech placeholders: subtitles only until a rough take exists.
- **Text:** handwritten-ink date, place and name cards drawn on with a write-on animation (IM Fell family, OFL), with no boxes or letterbox bars. Subtitles are on by default.
- **Skipping:** hold-to-skip is always available, including on the first run. Both the Opening and the Prologue can be replayed, and Continue leads the menu after the first run.

## Considered Options

- **Pre-rendered or AI-generated video:** rejected. A second pipeline, a video file to ship, and a look that drifts from gameplay. AI content would also need Steam disclosure and risks player backlash. Real-time footage that looks exactly like play makes the Steam promise believable.
- **Painted opening panels:** these become the optional Prologue instead (four paintings: Jefferson's secret message, the Purchase, Lewis and Clark, leaving Camp Dubois), made after the Slice.
- **A flash-forward to the Teton Stand-off as the hook:** strong for promotion, but it spends the Slice's biggest reveal.
- **Editor-authored AnimationPlayer timelines:** rejected in favour of a data-driven shot list (next section).

## Consequences

- Cutscenes are a JSON shot list (camera keys, voiceover and subtitle cues, name cards, music cues) run by a director script, in the same spirit as ADR-0005. It is built alongside the Scenario engine so Scenario cutscenes, starting with the Teton Stand-off, reuse it. The Opening's shots, boats and title scene are polished last, just before playtests, and verified with autopilot `--shots` runs.
- A low-poly keelboat and two pirogues are built procedurally now and replaced by commissioned models later. Shots are framed at mid-distance and in silhouette until the commissioned Companion models exist.
- The title scene is part of Council Bluff and stays fixed for the Slice. Reflecting save progress on the title comes after Early Access.
- Music is a CC0 period fiddle placeholder, with a commissioned theme considered around Early Access.
- Success at the Slice gate: a first-run skip rate under 30%, and most testers can say who they are and where they are headed, with some mentioning the Sioux.
