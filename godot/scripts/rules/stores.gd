class_name Stores
## The Corps' Stores: everything they carry, where it is stowed, what it weighs,
## what gets eaten, what spoils, and what is given away at a council.
##
## Engine-agnostic and saveable: the manifest is data (data/stores.json), this is
## only the arithmetic. See docs/design/stores.md.

const MANIFEST := "res://data/stores.json"

## Where things are stowed, largest first. Keys match the manifest's "where".
const HOLDS := ["keelboat", "red_pirogue", "white_pirogue", "packs"]

## A day's ration for one man, in the order it is drawn on: what the Corps ate
## when no game was killed. Lewis issued pork or meal, with a gill of whiskey.
const RATION := [
	{"id": "salt_pork", "per_man_per_day": 0.0139},   # a keg of 72 lb feeds 33 men a day and a half
	{"id": "corn_hominy", "per_man_per_day": 0.0107},
	{"id": "flour", "per_man_per_day": 0.0041},
	{"id": "biscuit", "per_man_per_day": 0.0035},
	{"id": "portable_soup", "per_man_per_day": 0.08},  # the last resort, and hated
]

var items: Array[Dictionary] = []
var capacity := {}


static func load_manifest(path: String = MANIFEST) -> Stores:
	var s := Stores.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Stores: no manifest at %s" % path)
		return s
	var data: Dictionary = JSON.parse_string(text)
	s.capacity = data.get("capacity", {})
	for raw in data.get("items", []):
		var it: Dictionary = raw.duplicate()
		it["qty"] = float(it.get("qty", 0))
		s.items.append(it)
	return s


func find(id: String) -> Dictionary:
	for it in items:
		if it.get("id", "") == id:
			return it
	return {}


func count(id: String) -> int:
	return int(floor(float(find(id).get("qty", 0.0))))


func categories() -> Array:
	var out: Array = []
	for it in items:
		var c: String = it.get("category", "")
		if not out.has(c):
			out.append(c)
	return out


func in_category(category: String) -> Array:
	return items.filter(func(it): return it.get("category", "") == category)


func in_hold(hold: String) -> Array:
	return items.filter(func(it): return it.get("where", "") == hold and float(it["qty"]) > 0.0)


func weight(hold: String) -> float:
	var w := 0.0
	for it in in_hold(hold):
		w += float(it["qty"]) * float(it.get("lb", 0.0))
	return w


func total_weight() -> float:
	var w := 0.0
	for h in HOLDS:
		w += weight(h)
	return w


func load_of(hold: String) -> float:
	## How full a boat is, 0 to 1 (over 1 means she is overloaded and will handle badly).
	var cap := float(capacity.get(hold, 0.0))
	return 0.0 if cap <= 0.0 else weight(hold) / cap


func overloaded() -> Array:
	return HOLDS.filter(func(h): return load_of(h) > 1.0)


func take(id: String, amount: float) -> float:
	## Remove up to ``amount``; returns what was actually taken.
	var it := find(id)
	if it.is_empty():
		return 0.0
	var got: float = minf(amount, float(it["qty"]))
	it["qty"] = float(it["qty"]) - got
	return got


func ration(men: int, days: int) -> Dictionary:
	## Feed the Corps from the stores, drawing on each ration food in turn until
	## the day's need is met. Returns what was eaten, by id.
	var eaten := {}
	for day in days:
		for r in RATION:
			var need: float = float(r["per_man_per_day"]) * float(men)
			var got := take(str(r["id"]), need)
			if got > 0.0:
				eaten[r["id"]] = float(eaten.get(r["id"], 0.0)) + got
	return eaten


func spoil(severity: float) -> Dictionary:
	## Damp, a swamped pirogue, a night of rain in an open boat: whatever is
	## marked as spoiling loses a share of itself. Returns what was lost.
	var lost := {}
	for it in items:
		if not it.get("spoils", false) or float(it["qty"]) <= 0.0:
			continue
		var gone := float(it["qty"]) * clampf(severity, 0.0, 1.0) * 0.25
		if gone > 0.0:
			it["qty"] = float(it["qty"]) - gone
			lost[it["id"]] = gone
	return lost


func regard_of(id: String) -> int:
	## What a Nation is likely to think of this present, as the captains judged it.
	return int(find(id).get("regard", 0))


func give(id: String, amount: int) -> int:
	## Hand over presents at a council; returns how many were actually given.
	return int(take(id, float(amount)))


func gift_regard() -> int:
	## The standing of everything still in the presents, for a council's odds.
	var total := 0
	for it in items:
		if it.get("regard", 0) > 0:
			total += int(it["regard"]) * int(floor(float(it["qty"])))
	return total


func save_state() -> Dictionary:
	var out := {}
	for it in items:
		out[it["id"]] = float(it["qty"])
	return out


func load_state(saved: Dictionary) -> void:
	for it in items:
		if saved.has(it["id"]):
			it["qty"] = float(saved[it["id"]])
