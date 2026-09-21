---
status: superseded by ADR-0009
---

# `main` stays the playable hex game until the Slice gate

Open-world work lives on `feat/explore`; `main` keeps the working hex-map game (with the four gameplay systems) until the Vertical Slice passes its playtest gate. Only then does `feat/explore` merge and the hex map become the Expedition Map. This keeps a showable build at all times and means a failed Slice costs nothing on `main`.
