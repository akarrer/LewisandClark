# The Godot spike has passed; Godot becomes `main`

Supersedes ADR-0006. The spike's two tests from ADR-0007 are met — walking Council Bluff is entertaining on scenery and Trail Moments alone, and iterating in Godot works well for AI-assisted development — and every design decision since assumes Godot. `feat/godot-spike` merges into `main` as the playable line and the Pygame hex game is tagged where it stands. Keeping a stale Pygame `main` as "the showable build" no longer protected anything; it only hid the real one from anyone looking at the repository.
