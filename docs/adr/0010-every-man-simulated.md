# Every man of the Corps is simulated

All forty-five men are tracked individually — name, health, Conditions, fatigue, footwear, morale — and the physical state of the expedition is simulated alongside them: food, dry powder, clothing and footwear, the boats, and horses from the crossing onward. We chose this broad simulation knowing it is the most expensive option for a single developer building with AI assistance, and accepted slower development for it, because the expedition's real decisions were decisions about exactly these things: whether to lay a day over drying goods, stop to make moccasins, or rest the sick.

## Considered Options

- **Named Companions only, the rest a distribution** — cheaper, but the men who were flogged, fell sick or went missing are the history.
- **A single Corps Strength number** (the original model) — rejected with the above.

## Consequences

- Corps Strength is now counted from the men fit for duty rather than stored.
- A simulated state must surface as a decision or it is not worth simulating. It reaches the player mostly in the world and through the sergeants' Morning Report, not through a management screen; command runs through the three Messes, with a few calls on individual men.
- Ammunition stays pooled. Per-man ammunition was considered and dropped: it is bookkeeping with no decision in it.
