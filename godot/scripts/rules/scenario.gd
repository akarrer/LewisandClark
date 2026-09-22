class_name Scenario
extends RefCounted
## A Scenario: a branching, choice-driven story moment, authored as a JSON node
## graph (ADR-0005) in data/scenarios/<id>.json. This is only the logic -- what
## is due, which choices stand open, the odds of a Skill Check and why, and what
## each outcome does to the Corps, the Stores and the Expedition. Staging it in
## the world is scripts/world/scenario_stage.gd; the prompt is
## scripts/ui/scenario_prompt.gd. See docs/design/scenarios.md.
##
## ``world`` everywhere below is {"state": ExpeditionState, "corps": Corps,
## "stores": Stores}.

const DIR := "res://data/scenarios/"

## What a choice's ``when``, or a Skill Check modifier's, may ask.
const CONDITIONS := ["present", "absent", "status", "sick_with", "flag", "not_flag", "all_flags", "no_flags",
		"item", "fit_at_least", "standing_at_least"]
## What an outcome may do.
const EFFECTS := ["journal", "standing", "hearten", "flag", "status", "take", "give", "hides", "fatigue", "cue",
		"physic", "excuse", "health", "council_close"]
## What a node may wait on before it plays: "arrival" (the cast is in and the
## Leader has gone to them), "hour:<h>" (the Day Clock), "at:<place>" (the
## Leader has walked there).
const WAITS := ["arrival", "hour", "at"]

var def := {}
var id := ""
var node_id := ""
var done := false
## Stage cues raised by effects since the stage last looked ("salute", ...).
var cues: Array[String] = []
## A Scenario that holds a council (``"council": "<id>"``) plays its steps
## through the Council rules, which keep the odds, the presents and standing.
var council: Council


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	return ids


static func load_scenario(scenario_id: String) -> Scenario:
	var s := Scenario.new()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + scenario_id + ".json"))
	assert(parsed is Dictionary, "no Scenario at " + DIR + scenario_id)
	s.def = parsed
	s.id = str(parsed.get("id", scenario_id))
	return s


static func date_key(state: ExpeditionState) -> String:
	return "%d-%02d-%02d" % [state.current_year, state.current_month, state.current_day]


func due(state: ExpeditionState, region_id: String, world: Dictionary = {}) -> bool:
	## Its day and hour have come, in its Region, it has not been played, and
	## whatever it ``requires`` of the Corps holds (Floyd still sick, say).
	var w: Dictionary = def.get("when", {})
	if w.has("requires") and not world.is_empty() and not met(w["requires"], world):
		return false
	if state.flags.has("scenario:" + id):
		return false
	if w.has("region") and str(w["region"]) != region_id:
		return false
	if w.has("date") and str(w["date"]) != date_key(state):
		return false
	return state.hour() >= float(w.get("after_hour", 0.0))


func lapsed(state: ExpeditionState) -> bool:
	## Its day is over. A dinner nobody came down to is not held the next
	## morning, and it must not stand in the way of the next day's Scenarios.
	var w: Dictionary = def.get("when", {})
	return w.has("date") and str(w["date"]) != date_key(state)


func begin(world: Dictionary) -> void:
	world["state"].flags["scenario:" + id] = true
	if def.has("council"):
		council = Council.open(str(def["council"]), world["stores"])
		# What the evening before left them thinking.
		council.standing = int(world["state"].standing.get(str(def.get("nation", "")), 0))
		council.interpreter_present = world["corps"].man(council.interpreter.to_lower()).get("status", "") == "present"
	_enter(str(def["start"]), world)


func node() -> Dictionary:
	return def["nodes"].get(node_id, {})


func lines() -> Array:
	return node().get("lines", [])


func waits_for() -> String:
	## A node may hold until something happens in the world ("arrival": the cast
	## has come in and the Leader has gone to meet them). The stage says when.
	return str(node().get("wait", ""))


func choices(world: Dictionary) -> Array[Dictionary]:
	## The choices open at this node, each with whether it can be paid for and
	## the odds of its Skill Check, if it has one, with the reasons shown.
	var out: Array[Dictionary] = []
	var all: Array = node().get("choices", [])
	for i in all.size():
		var c: Dictionary = all[i]
		if c.has("when") and not met(c["when"], world):
			continue
		var why_not := _unpaid(c, world)
		var entry := {"index": i, "label": str(c["label"]), "note": str(c.get("note", "")),
				"available": why_not == "", "why_not": why_not, "chance": -1.0, "reasons": []}
		if c.has("council"):
			_council_entry(c["council"], entry)
		elif c.has("check"):
			var o := odds(c["check"], world)
			entry["chance"] = o["chance"]
			entry["reasons"] = o["reasons"]
		out.append(entry)
	return out


func odds(check: Dictionary, world: Dictionary) -> Dictionary:
	## A Skill Check's chance, shown before it is rolled, and what moved it.
	var chance := float(check.get("base", 0.5))
	var reasons: Array = []
	for m in check.get("mods", []):
		if met(m["when"], world):
			chance += float(m["add"])
			reasons.append([str(m.get("why", "")), float(m["add"])])
	return {"chance": clampf(chance, 0.05, 0.95), "reasons": reasons}


func choose(index: int, world: Dictionary, roll: float) -> Dictionary:
	## Take a choice: pay for it, roll its Skill Check if it has one, apply what
	## follows, and move on. Returns {"passed", "reply", "next"}.
	var c: Dictionary = node()["choices"][index]
	assert(_unpaid(c, world) == "", "choice %s cannot be paid for" % c["label"])
	for cost in c.get("cost", []):
		world["stores"].take(str(cost[0]), float(cost[1]))
	var passed := true
	var next := str(c.get("next", ""))
	if c.has("council"):
		passed = _council_step(c["council"], world, roll)
	elif c.has("check"):
		passed = roll < float(odds(c["check"], world)["chance"])
		next = str(c["pass"] if passed else c["fail"])
	apply(c.get("effects", []), world)
	# What is said after depends on how it went: a speech that came out crooked
	# is not answered with thanks.
	var reply: Array = c.get("reply", []).duplicate()
	reply.append_array(c.get("reply_pass" if passed else "reply_fail", []))
	_enter(next, world)
	return {"passed": passed, "reply": reply, "next": next}


func _council_entry(spec: Dictionary, entry: Dictionary) -> void:
	## A council step's chance, with what the chiefs asked for laid out if this
	## choice gives it. Refusing a step has no chance to show.
	if bool(spec.get("refuse", false)):
		return
	var step_id := str(spec["step"])
	council.clear_offer()
	if str(spec.get("offer", "")) == "asked":
		var why := council.offer_asked(step_id)
		if why != "":
			entry["available"] = false
			entry["why_not"] = why
	entry["chance"] = council.odds(step_id)
	entry["reasons"] = council.breakdown(step_id)
	council.clear_offer()


func _council_step(spec: Dictionary, world: Dictionary, roll: float) -> bool:
	var step_id := str(spec["step"])
	var result: Dictionary
	if bool(spec.get("refuse", false)):
		result = council.refuse(step_id)
	else:
		council.clear_offer()
		if str(spec.get("offer", "")) == "asked":
			council.offer_asked(step_id)
		result = council.resolve(step_id, roll)
	if str(result.get("text", "")) != "":
		world["state"].add_journal(str(result["text"]))
	return bool(result.get("passed", false))


func _enter(next: String, world: Dictionary) -> void:
	node_id = next
	var n := node()
	apply(n.get("effects", []), world)
	if bool(n.get("end", false)):
		done = true


func _unpaid(c: Dictionary, world: Dictionary) -> String:
	for cost in c.get("cost", []):
		var have := float(world["stores"].find(str(cost[0])).get("qty", 0.0))
		if have < float(cost[1]):
			return "not enough %s" % str(world["stores"].find(str(cost[0])).get("name", cost[0])).to_lower()
	return ""


func met(when: Dictionary, world: Dictionary) -> bool:
	## Every condition in ``when`` must hold.
	var corps: Corps = world["corps"]
	var state: ExpeditionState = world["state"]
	for k in when:
		var v = when[k]
		match k:
			"present":
				if corps.man(str(v)).get("status", "") != "present":
					return false
			"absent":
				if corps.man(str(v)).get("status", "") == "present":
					return false
			"status":
				if corps.man(str(v[0])).get("status", "") != str(v[1]):
					return false
			"sick_with":
				if not corps.has_condition(corps.man(str(v[0])), str(v[1])):
					return false
			"flag":
				if not state.flags.has(str(v)):
					return false
			"not_flag":
				if state.flags.has(str(v)):
					return false
			"all_flags":
				for f in v:
					if not state.flags.has(str(f)):
						return false
			"no_flags":
				for f in v:
					if state.flags.has(str(f)):
						return false
			"item":
				if float(world["stores"].find(str(v[0])).get("qty", 0.0)) < float(v[1]):
					return false
			"fit_at_least":
				if corps.fit_count() < int(v):
					return false
			"standing_at_least":
				if int(state.standing.get(str(v[0]), 0)) < int(v[1]):
					return false
			_:
				push_error("Scenario %s: unknown condition %s" % [id, k])
				return false
	return true


func apply(effects: Array, world: Dictionary) -> void:
	var corps: Corps = world["corps"]
	var state: ExpeditionState = world["state"]
	for e in effects:
		for k in e:
			var v = e[k]
			match k:
				"journal":
					state.add_journal(str(v))
				"standing":
					state.standing[str(v[0])] = int(state.standing.get(str(v[0]), 0)) + int(v[1])
				"hearten":
					corps.hearten(float(v))
				"flag":
					state.flags[str(v)] = true
				"status":
					corps.man(str(v[0]))["status"] = str(v[1])
				"take":
					world["stores"].take(str(v[0]), float(v[1]))
				"give":
					world["stores"].add(str(v[0]), float(v[1]))
				"hides":
					corps.hides += float(v)
				"fatigue":
					corps.tire(str(v[0]), float(v[1]))
				"cue":
					cues.append(str(v))
				"physic":
					# Lewis's own physic, out of the medicine chest (Corps.treat).
					var said := corps.treat(str(v), world["stores"])
					if said != "":
						state.add_journal(said)
				"excuse":
					corps.excuse(str(v))
				"health":
					var m := corps.man(str(v[0]))
					m["health"] = clampf(float(m["health"]) + float(v[1]), 0.0, 100.0)
				"council_close":
					# How the Nation parts from the Corps: carried on to the next
					# meeting, felt in camp, and set down in the Journal.
					state.standing[str(def.get("nation", ""))] = council.standing
					corps.hearten(council.standing / 4.0)
					state.add_journal("Council with the %s: %s" % [council.nation, council.verdict()])
				_:
					push_error("Scenario %s: unknown effect %s" % [id, k])
