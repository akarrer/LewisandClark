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
			var wait := str(n.get("wait", ""))
			if wait != "":
				t.check(wait.split(":")[0] in Scenario.WAITS, "%s.%s: unknown wait %s" % [id, nid, wait])
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
		for k in s.def.get("when", {}).get("requires", {}):
			t.check(k in Scenario.CONDITIONS, "%s: unknown requirement %s" % [id, k])
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


func test_every_wait_at_a_place_names_one():
	for id in Scenario.all_ids():
		var s := Scenario.load_scenario(id)
		var region := str(s.def.get("when", {}).get("region", ""))
		if region == "":
			continue
		var terrain := Terrain.new(Region.load_region(region))
		terrain.define_points()
		for nid in s.def["nodes"]:
			var wait := str(s.def["nodes"][nid].get("wait", ""))
			if wait.begins_with("at:"):
				t.check(terrain.points.has(wait.substr(3)), "%s.%s waits at %s, no place in %s" % [id, nid, wait, region])
		terrain.free()


func _birthday(w: Dictionary, hunt_roll: float, fruit: bool) -> Scenario:
	var s := Scenario.load_scenario("clark_birthday")
	s.begin(w)
	_pick(s, w, "Send the hunters", hunt_roll)
	_pick(s, w, "Send Pryor" if fruit else ("That is dinner" if s.node_id == "good_hunt" else "Leave it"))
	_pick(s, w, "Go down to the fire")
	return s


func test_the_birthday_dinner_is_what_the_day_brought():
	var w := _world()
	w["state"].current_day = 1
	var meat := float(w["stores"].find("fresh_meat")["qty"])
	var s := _birthday(w, 0.0, true)
	t.check(float(w["stores"].find("fresh_meat")["qty"]) > meat + 400.0, "the hunters bring in the dinner")
	var open := s.choices(w)
	t.eq(open.size(), 1, "one table is laid")
	t.check(str(open[0]["label"]).begins_with("A saddle of fat venison"), "and it is Clark's own")
	var w2 := _world()
	w2["state"].current_day = 1
	var s2 := _birthday(w2, 0.99, false)
	t.check(str(s2.choices(w2)[0]["label"]).begins_with("Salt pork, as any"), "a thin hunt and no fruit is pork")


func test_the_hunt_odds_read_who_is_in_camp():
	var w := _world()
	w["state"].current_day = 1
	var s := Scenario.load_scenario("clark_birthday")
	s.begin(w)
	var full := float(s.choices(w)[0]["chance"])
	w["corps"].man("drouillard")["status"] = "away"
	t.check(float(s.choices(w)[0]["chance"]) < full, "without Drouillard the chance falls")


func test_the_sick_call_comes_only_while_floyd_is_sick():
	var w := _world()
	w["state"].minute_of_day = 10 * 60
	var s := Scenario.load_scenario("floyd_sick_call")
	t.check(s.due(w["state"], "council_bluff", w), "Floyd is sick on the second, so the sergeant's colic is due")
	w["corps"].man("floyd")["conditions"] = []
	t.check(not s.due(w["state"], "council_bluff", w), "a well Floyd gets no sick call")


func test_physic_for_floyd_comes_out_of_the_chest():
	var w := _world()
	w["state"].minute_of_day = 10 * 60
	var s := Scenario.load_scenario("floyd_sick_call")
	var pills := float(w["stores"].find("rush_pills")["qty"])
	s.begin(w)
	_pick(s, w, "Dose him")
	t.check(float(w["stores"].find("rush_pills")["qty"]) < pills, "the pills are taken from the chest")
	t.check(s.done, "and the sick call is over")
	var w2 := _world()
	var s2 := Scenario.load_scenario("floyd_sick_call")
	s2.begin(w2)
	_pick(s2, w2, "Excuse him")
	t.check(w2["corps"].excused.has("floyd"), "an excused sergeant is off duty today")


func test_a_scenario_waiting_past_its_day_lapses():
	var w := _world()
	w["state"].current_day = 1
	var s := Scenario.load_scenario("clark_birthday")
	s.begin(w)
	_pick(s, w, "No time")
	t.check(not s.lapsed(w["state"]), "the dinner waits on the evening")
	w["state"].current_day = 2
	t.check(s.lapsed(w["state"]), "but not into the next day")


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


func _council_world() -> Dictionary:
	var w := _world()
	w["state"].current_day = 3
	w["state"].minute_of_day = 9 * 60
	return w


func test_the_council_opens_where_the_evening_left_it():
	var w := _council_world()
	w["state"].standing["oto_missouria"] = 10
	var s := Scenario.load_scenario("council_bluff_1804")
	t.check(s.due(w["state"], "council_bluff", w), "due on the morning of the third")
	s.begin(w)
	t.eq(s.council.standing, 10, "the council starts at last night's standing")
	t.check(s.council.interpreter_present, "with Drouillard to interpret")


func test_the_historical_council():
	var w := _council_world()
	var medals: int = w["stores"].count("medals")
	var powder: int = w["stores"].count("powder")
	var s := Scenario.load_scenario("council_bluff_1804")
	s.begin(w)
	_pick(s, w, "Parade the Corps")
	_pick(s, w, "Begin")
	_pick(s, w, "Make the speech")
	var chiefs: Dictionary = s.choices(w)[0]
	t.check(chiefs["reasons"].any(func(r): return str(r[0]).contains("asked for is laid out")), "laying out what they asked counts, and shows")
	_pick(s, w, "Make the chiefs")
	t.eq(w["stores"].count("medals"), medals - 6, "six medals for six chiefs")
	_pick(s, w, "Fire the air gun")
	_pick(s, w, "A canister of powder")
	t.check(w["stores"].count("powder") < powder, "the powder they asked for is given")
	_pick(s, w, "Send his medal")
	t.check(int(w["state"].standing["oto_missouria"]) >= 45, "and they part well satisfied: %s" % w["state"].standing["oto_missouria"])
	_pick(s, w, "Strike the awning")
	t.check(s.done, "then the Corps sets out")


func test_refusing_their_ask_is_remembered_in_the_world():
	var w := _council_world()
	var s := Scenario.load_scenario("council_bluff_1804")
	s.begin(w)
	_pick(s, w, "Receive them")
	_pick(s, w, "Begin")
	_pick(s, w, "Make the speech", 0.99)
	_pick(s, w, "Keep the medals")
	_pick(s, w, "Leave it")
	_pick(s, w, "Tell them there is none")
	_pick(s, w, "Send nothing")
	t.check(int(w["state"].standing["oto_missouria"]) < 0, "a council that gives nothing leaves them slighted")


func test_medals_the_stores_do_not_hold_cannot_be_given():
	var w := _council_world()
	w["stores"].take("medals", float(w["stores"].count("medals") - 2))
	var s := Scenario.load_scenario("council_bluff_1804")
	s.begin(w)
	_pick(s, w, "Parade")
	_pick(s, w, "Begin")
	_pick(s, w, "Make the speech")
	var chiefs: Dictionary = s.choices(w)[0]
	t.check(not chiefs["available"], "two medals will not make six chiefs")
	t.check(str(chiefs["why_not"]).contains("medal"), "and it says so")


func test_what_is_said_after_follows_the_roll():
	var w := _council_world()
	var s := Scenario.load_scenario("council_bluff_1804")
	s.begin(w)
	_pick(s, w, "Parade")
	_pick(s, w, "Begin")
	var crooked := _pick(s, w, "Make the speech", 0.999)
	t.check(not crooked["passed"], "a roll at the top fails")
	t.check(not crooked["reply"].any(func(l): return str(l["text"]).contains("glad")), "and nobody gives thanks for it")


func _search(w: Dictionary, roll: float) -> Scenario:
	w["state"].current_day = 3
	w["state"].minute_of_day = 13 * 60
	w["corps"].man("la_liberte")["status"] = "missing"
	var s := Scenario.load_scenario("la_liberte")
	t.check(s.due(w["state"], "council_bluff", w), "a man still not come up is looked for")
	s.begin(w)
	_pick(s, w, "Send Drouillard", roll)
	return s


func test_a_search_party_is_gone_until_dark():
	var w := _world()
	var s := _search(w, 0.0)
	t.eq(w["corps"].man("drouillard")["status"], "away", "the searchers are out of camp")
	t.eq(w["corps"].man("la_liberte")["status"], "missing", "and nothing is known until they are back")
	t.eq(s.waits_for(), "hour:19", "they are due by dark")
	s.resume(w)
	t.eq(w["corps"].man("drouillard")["status"], "present", "then they come in")
	t.eq(w["corps"].man("la_liberte")["status"], "present", "with their man")


func test_a_search_may_find_nothing():
	var w := _world()
	var s := _search(w, 0.99)
	s.resume(w)
	t.eq(s.node_id, "no_sign", "the plains are wide")
	t.eq(w["corps"].man("la_liberte")["status"], "missing", "and he is still gone")
	t.eq(w["corps"].man("drouillard")["status"], "present", "though the searchers come back")


func test_the_oto_will_look_for_him_only_if_they_think_well_of_the_corps():
	var w := _world()
	w["state"].current_day = 3
	w["state"].minute_of_day = 13 * 60
	w["corps"].man("la_liberte")["status"] = "missing"
	var s := Scenario.load_scenario("la_liberte")
	s.begin(w)
	t.check(not s.choices(w).any(func(c): return str(c["label"]).begins_with("Ask the Oto")), "a cold council, and no favours")
	w["state"].standing["oto_missouria"] = 45
	t.check(s.choices(w).any(func(c): return str(c["label"]).begins_with("Ask the Oto")), "a warm one, and they will look")


func test_the_badger_is_a_discovery_of_this_region():
	var r := Region.load_region("council_bluff")
	var found: Array = r.data.get("features", {}).get("discoveries", [])
	t.check(found.any(func(d): return d["id"] == "badger"), "Joseph Field's badger is written up at Council Bluff")
	var terrain := Terrain.new(r)
	terrain.define_points()
	for d in found:
		t.check(terrain.points.has(str(d["at"])), "a discovery at no named place: %s" % d["id"])
		t.check(str(d.get("journal", "")).length() > 40, "%s has nothing for the Journal" % d["id"])
	terrain.free()
