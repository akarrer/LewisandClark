class_name Council
## A council with a Nation: the captains speak, present medals, fire the air gun,
## and answer what is asked of them. What is laid out of the Stores is what the
## chiefs judge, and the odds of each step are shown before they are rolled
## (ADR-0005: Scenarios are data; Skill Checks show their chances).
##
## Engine-agnostic and pure. The screen draws it; this decides it.

const COUNCILS := "res://data/councils.json"

## An offer can only carry a step so far: a council is never a certainty.
const CEILING := 0.95
const FLOOR := 0.05

var id := ""
var nation := ""
var place := ""
var date := ""
var opening := ""
var interpreter := ""
var interpreter_present := true
var seats: Array = []
var steps: Array = []
var stores: Stores

## Their opinion of the Corps by the end, and what has already been done.
var standing := 0
var offered := {}
var _done: Array[String] = []
var _log: Array[String] = []


static func open(council_id: String, p_stores: Stores, path: String = COUNCILS) -> Council:
	var c := Council.new()
	c.stores = p_stores if p_stores else Stores.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Council: no data at %s" % path)
		return c
	var data: Dictionary = JSON.parse_string(text)
	for raw in data.get("councils", []):
		if raw.get("id", "") != council_id:
			continue
		c.id = council_id
		c.nation = str(raw.get("nation", ""))
		c.place = str(raw.get("place", ""))
		c.date = str(raw.get("date", ""))
		c.opening = str(raw.get("opening", ""))
		c.interpreter = str(raw.get("interpreter", ""))
		c.seats = raw.get("seats", [])
		c.steps = raw.get("steps", [])
	return c


func step(step_id: String) -> Dictionary:
	for s in steps:
		if s.get("id", "") == step_id:
			return s
	return {}


func seat_named(name: String) -> Dictionary:
	for s in seats:
		if s.get("name", "") == name:
			return s
	return {}


func chiefs_present() -> int:
	return seats.filter(func(s): return s.get("present", false)).size()


func done(step_id: String) -> bool:
	return _done.has(step_id)


func remaining() -> Array:
	return steps.filter(func(s): return not done(str(s.get("id", ""))))


func offer(item_id: String, amount: int) -> int:
	## Lay goods out on the ground for this council. Cannot offer what is not carried.
	var have := stores.count(item_id)
	var already := int(offered.get(item_id, 0))
	var can := clampi(amount, 0, have - already)
	if can > 0:
		offered[item_id] = already + can
	return can


func clear_offer() -> void:
	offered = {}


func offered_regard() -> int:
	## What is laid out, in the terms the captains judged presents by.
	var total := 0
	for item_id in offered:
		total += stores.regard_of(item_id) * int(offered[item_id])
	return total


func odds(step_id: String) -> float:
	## The chance this step goes well, shown to the player before it is rolled.
	var s := step(step_id)
	if s.is_empty() or done(step_id):
		return 0.0
	var chance := float(s.get("base", 0.5))
	for part in breakdown(step_id):
		chance += float(part[1])
	return clampf(chance, FLOOR, CEILING)


func breakdown(step_id: String) -> Array:
	## What moves a step's chance off its base, as [why, amount], for showing
	## beside the choice. ``odds`` is the base plus these.
	var s := step(step_id)
	var parts: Array = []
	if s.get("needs_interpreter", false) and not interpreter_present:
		parts.append(["no interpreter", -0.3])
	# What they have asked for, laid out in front of them.
	var wants: Dictionary = s.get("wants", {})
	if not wants.is_empty():
		var met := 0.0
		for item_id in wants:
			var need := float(wants[item_id])
			met += clampf(float(offered.get(item_id, 0)) / maxf(need, 1.0), 0.0, 1.0)
		if met > 0.0:
			parts.append(["what they asked for is laid out", 0.4 * (met / float(wants.size()))])
	# Anything else laid out still counts for something, with diminishing return.
	var extra := clampf(float(offered_regard()) / 400.0, 0.0, 0.15)
	if extra > 0.0:
		parts.append(["the presents on the ground", extra])
	# How the council has gone so far carries into what follows.
	var mood := clampf(float(standing) / 200.0, -0.2, 0.2)
	if absf(mood) > 0.005:
		parts.append(["how they think of the Corps" if mood > 0.0 else "how coldly they think of the Corps", mood])
	return parts


func offer_asked(step_id: String) -> String:
	## Lay out exactly what this step asks for. Returns "" or why it cannot be.
	var wants: Dictionary = step(step_id).get("wants", {})
	for item_id in wants:
		if stores.count(item_id) < int(wants[item_id]):
			return "not enough %s" % str(stores.find(item_id).get("name", item_id)).to_lower()
	for item_id in wants:
		offer(item_id, int(wants[item_id]))
	return ""


func resolve(step_id: String, roll: float) -> Dictionary:
	## Take the step. ``roll`` is 0..1 from the caller, so the rules stay pure.
	var s := step(step_id)
	if s.is_empty() or done(step_id):
		return {"passed": false, "text": "", "standing": 0}
	var chance := odds(step_id)
	_done.append(step_id)
	var passed := roll <= chance
	# What was asked for is given whether or not the step goes well: it is spent.
	# What was not asked for stays laid out for the rest of the council.
	var given := {}
	for item_id in s.get("wants", {}):
		var n := int(offered.get(item_id, 0))
		if n > 0:
			given[item_id] = stores.give(item_id, n)
			offered.erase(item_id)
	var gained := int(s.get("standing", 0)) if passed else -int(float(s.get("standing", 0)) * 0.25)
	standing += gained
	var text := str(s.get("on_pass", "")) if passed else str(s.get("on_fail", ""))
	_log.append(text)
	return {"passed": passed, "text": text, "standing": gained, "given": given}


func refuse(step_id: String) -> Dictionary:
	## Decline a step altogether. Refusing what was asked for is remembered.
	var s := step(step_id)
	if s.is_empty() or done(step_id):
		return {"passed": false, "text": "", "standing": 0}
	_done.append(step_id)
	var cost := int(s.get("refuse_standing", -4))
	standing += cost
	var text := str(s.get("on_fail", "It is passed over."))
	_log.append(text)
	return {"passed": false, "text": text, "standing": cost, "given": {}}


func verdict() -> String:
	## How the Nation parts from the Corps, for the Journal.
	if standing >= 45:
		return "They part well satisfied, and say the road is open."
	if standing >= 20:
		return "They are content enough, and will carry word of it to their villages."
	if standing >= 0:
		return "They hear the captains out, and make no promises."
	return "They go away slighted, and what is said of the Corps upriver will not be kind."


func log_lines() -> Array[String]:
	return _log
