extends RefCounted
## Scenarios are JSON node graphs (ADR-0005). These hold every file to the
## schema the engine reads, and play the Oto arrival of 2 August 1804 through.

var t


func _world() -> Dictionary:
	var state := ExpeditionState.new()
	state.current_month = 8
	state.current_day = 2
	state.minute_of_day = 19 * 60
	return {"state": state, "corps": Corps.load_corps(), "stores": Stores.load_manifest()}


func _pick(s: Scenario, w: Dictionary, label_start: String, roll := 0.0) -> Dictionary:
	for c in s.choices(w):
		if str(c["label"]).begins_with(label_start):
			return s.choose(int(c["index"]), w, roll)
	t.check(false, "no open choice '%s' at %s" % [label_start, s.node_id])
	return {}


func test_every_scenario_is_a_sound_graph():
	var stores := Stores.load_manifest()
	for id in Scenario.all_ids():
		var s := Scenario.load_scenario(id)
		var nodes: Dictionary = s.def["nodes"]
		t.check(nodes.has(str(s.def["start"])), "%s: no start node" % id)
		var ends := 0
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			if n.get("end", false):
				ends += 1
			elif n.get("choices", []).is_empty():
				t.check(false, "%s.%s: a node that is not an end needs choices" % [id, nid])
			_check_effects(id, nid, n.get("effects", []))
			for c in n.get("choices", []):
				var targets: Array = [c["pass"], c["fail"]] if c.has("check") else [c.get("next", "")]
				for target in targets:
					t.check(nodes.has(str(target)), "%s.%s: '%s' leads to no node %s" % [id, nid, c["label"], target])
				_check_effects(id, nid, c.get("effects", []))
				for k in c.get("when", {}):
					t.check(k in Scenario.CONDITIONS, "%s.%s: unknown condition %s" % [id, nid, k])
				for m in c.get("check", {}).get("mods", []):
					for k in m["when"]:
						t.check(k in Scenario.CONDITIONS, "%s.%s: unknown check condition %s" % [id, nid, k])
				for cost in c.get("cost", []):
					t.check(not stores.find(str(cost[0])).is_empty(), "%s.%s: costs unknown item %s" % [id, nid, cost[0]])
		t.check(ends > 0, "%s never ends" % id)


func _check_effects(id: String, nid: String, effects: Array) -> void:
	for e in effects:
		for k in e:
			t.check(k in Scenario.EFFECTS, "%s.%s: unknown effect %s" % [id, nid, k])


func test_every_scenario_is_staged_at_named_places():
	for id in Scenario.all_ids():
		var s := Scenario.load_scenario(id)
		var region := str(s.def.get("when", {}).get("region", ""))
		if region == "" or not s.def.has("stage"):
			continue
		var terrain := Terrain.new(Region.load_region(region))
		terrain.define_points()
		for key in ["from", "to"]:
			t.check(terrain.points.has(str(s.def["stage"][key])), "%s: stage %s is no place in %s" % [id, key, region])
		# The cast must be able to walk in, and the Leader to walk out to them,
		# without going the long way round a bluff: a bank too steep to climb
		# once put the meeting place a quarter mile's walk from a camp 45 m off.
		var meet: Vector3 = terrain.points[str(s.def["stage"]["to"])]
		for key in [str(s.def["stage"]["from"]), "start"]:
			var from: Vector3 = terrain.points[key]
			var route := terrain.find_route(from, meet)
			var length := 0.0
			for i in range(1, route.size()):
				length += route[i].distance_to(route[i - 1])
			t.check(not route.is_empty() and length < from.distance_to(meet) * 2.0 + 10.0,
					"%s: from %s to the meeting is %d m on foot" % [id, key, length])
		terrain.free()


func test_the_oto_come_at_sundown_on_the_second():
	var s := Scenario.load_scenario("oto_arrival")
	var w := _world()
	t.check(s.due(w["state"], "council_bluff"), "due on 2 August toward sunset")
	w["state"].minute_of_day = 12 * 60
	t.check(not s.due(w["state"], "council_bluff"), "not at noon")
	w["state"].minute_of_day = 18 * 60
	t.check(not s.due(w["state"], "practice_bar"), "and only at Council Bluff")
	s.begin(w)
	t.check(not s.due(w["state"], "council_bluff"), "and only once")
	t.check("their_guns" in s.cues, "it opens on their guns")


func test_the_historical_evening():
	var s := Scenario.load_scenario("oto_arrival")
	var w := _world()
	var pork := float(w["stores"].find("salt_pork")["qty"])
	s.begin(w)
	_pick(s, w, "Answer them")
	t.check("salute" in s.cues, "the swivel gun answers")
	t.eq(s.waits_for(), "arrival", "then the Corps waits for them to come in")
	_pick(s, w, "Ask after La Liberté")
	t.eq(w["corps"].man("la_liberte")["status"], "missing", "La Liberté is not with them")
	var result := _pick(s, w, "Pork, flour", 0.0)
	t.check(result["passed"], "a roll of nought passes")
	t.eq(s.node_id, "melons", "and they send watermelons")
	t.check(float(w["stores"].find("salt_pork")["qty"]) < pork, "the pork leaves the Stores")
	_pick(s, w, "Set the guard")
	_pick(s, w, "Double the guard")
	t.check(s.done, "the evening ends")
	t.check(int(w["state"].standing["oto_missouria"]) > 0, "and the Oto think the better of the Corps")


func test_the_odds_show_their_reasons():
	var s := Scenario.load_scenario("oto_arrival")
	var w := _world()
	s.begin(w)
	_pick(s, w, "Stand every man")
	_pick(s, w, "Tell them")
	var open := s.choices(w)
	var feast: Dictionary = open[0]
	var reasons: Array = feast["reasons"]
	t.check(reasons.any(func(r): return str(r[0]).contains("Drouillard")), "Drouillard's hands count")
	t.check(reasons.any(func(r): return float(r[1]) < 0.0), "and standing to arms counts against")
	t.check(float(feast["chance"]) < 0.75, "the chance shows it: %s" % feast["chance"])


func test_a_choice_the_stores_cannot_pay_for_is_shown_closed():
	var s := Scenario.load_scenario("oto_arrival")
	var w := _world()
	w["stores"].take("salt_pork", 9999.0)
	s.begin(w)
	_pick(s, w, "Answer them")
	_pick(s, w, "Tell them")
	var feast: Dictionary = s.choices(w)[0]
	t.check(not feast["available"], "no pork, no feast")
	t.check(str(feast["why_not"]).contains("salt pork"), "and it says why")


func test_la_liberte_is_asked_after_only_while_away():
	var s := Scenario.load_scenario("oto_arrival")
	var w := _world()
	w["corps"].man("la_liberte")["status"] = "present"
	s.begin(w)
	_pick(s, w, "Answer them")
	t.check(not s.choices(w).any(func(c): return str(c["label"]).contains("La Liberté")), "he's back, so nobody asks")


func test_the_council_remembers_the_evening():
	var w := _world()
	var s := Scenario.load_scenario("oto_arrival")
	s.begin(w)
	_pick(s, w, "Stand every man")
	_pick(s, w, "Tell them")
	_pick(s, w, "Nothing tonight")
	t.check(int(w["state"].standing["oto_missouria"]) < 0, "a cold evening leaves a cold standing for the council")
