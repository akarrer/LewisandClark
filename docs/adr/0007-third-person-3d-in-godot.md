# Third-person 3D in Godot 4, decided before the Vertical Slice

Supersedes ADR-0002. We brought the engine and art decision forward: the game is a third-person 3D exploration RPG with a behind-the-shoulder orbit camera, built in Godot 4 (GDScript), in a stylized low-poly look. Camera choice reshapes everything still to be built — how Scenarios are staged, how hunting's stalk plays, how Regions are laid out — so building the remaining Slice systems in 2D and porting later would redo that work.

The move starts with a 1–2 week spike in `godot/` on `feat/godot-spike`: Lewis walking ~1 km² of Council Bluff terrain with Companions following, a Landmark, a Day Clock lighting cycle, six Trail Moments, and a thin port of the rules. The spike passes when five minutes of walking is entertaining through scenery and Trail Moments, and when iterating in Godot works well for AI-assisted development. If it fails, fall back to a high 3D chase camera.

## Considered Options

- **Panda3D / Ursina** — keeps the Python rules and tests as-is, but weaker 3D tooling and editor for open-world terrain and animation.
- **Unity** — mature, but licensing churn. **Unreal** — heavy for this team.
- **Stay 2D with better sprites** — rejected: the draw of the West is seeing it open up ahead.

## Consequences

- The Pygame build is frozen as a playable reference; the Python rules (`state`, `corps`, `legs`, `region`, `input`) and their tests are the specification for the GDScript port, then retire. JSON content carries over unchanged.
- Target hardware is mid-range PCs: 1080p/60 on a GTX 1660 Super / RTX 2060 class (held to ~3× headroom on the dev machine as a proxy). Steam Deck is a stretch goal for Early Access.
- Region terrain comes from USGS elevation data, compressed to walkable scale and hand-touched at Landmarks.
- World art comes from CC0/paid asset packs customized for one look; the Companions and historical Native figures are commissioned later and go through the cultural review (ADR-0004).
