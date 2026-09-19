---
status: superseded by ADR-0007
---

# Stay on Pygame until the Vertical Slice passes; decide engine and art together then

An isometric open-world RPG for Steam (gamepad, Steam Deck, lighting, packaging) is a more natural fit for Godot than Pygame, but a rewrite now would throw away working rules, data, and tests before we know the open-world loop is fun. We build the Vertical Slice in Pygame, keep game rules and content in engine-agnostic JSON and plain Python state, and revisit the engine — and the shipped art direction (procedural vs commissioned vs asset packs) — as one decision at the Slice gate.

The gate passes when 5–10 uncoached outside playtesters mostly finish the 45–75 minute Slice and mostly say they'd keep playing.
