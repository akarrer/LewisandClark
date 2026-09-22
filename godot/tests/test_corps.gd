extends RefCounted
## Every man simulated (ADR-0010), history's deaths fixed (ADR-0012), and the
## Morning Report that surfaces it (see scripts/rules/corps.gd).

var t


func _day(c: Corps, st: Stores, date: String, extra := {}) -> Array[String]:
	var ctx := {"ended": date, "travel": false, "storm": 0.0, "hot_f": 84.0}
	ctx.merge(extra, true)
	return c.pass_day(ctx, st)


func _august(d: int) -> String:
	return "1804-08-%02d" % d


func test_the_roll_at_council_bluff():
	var c := Corps.load_corps()
	t.eq(c.men.size(), 46, "the Detachment Order's men, with La Liberté")
	t.eq(c.eating(), 45, "La Liberté is away at the Oto towns")
	t.eq(c.man("la_liberte")["status"], "away", "and not yet back")
	t.check(c.has_condition(c.man("floyd"), "colic"), "Floyd is sick when they reach the bluff")
	t.check(c.fit_count() < 45, "so Corps Strength is short of the whole")
	var commanded := 0
	for ms in c.messes:
		if ms.get("commanded", false):
			commanded += 1
	t.eq(commanded, 3, "command runs through three Messes")


func test_strength_is_counted_from_the_men():
	var c := Corps.load_corps()
	var fit := c.fit_count()
	c.add_condition(c.man("colter"), "dysentery")
	t.eq(c.fit_count(), fit - 1, "one man down is one fewer fit")


func test_rest_eases_and_the_towline_wears():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var hall := c.man("hall")
	hall["fatigue"] = 50.0
	c.set_duty("ordway", "rest")
	_day(c, st, _august(1))
	t.check(float(hall["fatigue"]) < 20.0, "a day's rest takes the fatigue off: %s" % hall["fatigue"])
	var boots := float(hall["footwear"])
	_day(c, st, _august(2), {"travel": true})
	t.check(float(hall["fatigue"]) > 10.0, "a day on the towline puts it back")
	t.check(float(hall["footwear"]) < boots, "and wears through the moccasins")


func test_moccasins_take_hides():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var gibson := c.man("gibson")
	gibson["footwear"] = 10.0
	c.hides = 0.0
	c.set_duty("pryor", "mend")
	_day(c, st, _august(1))
	t.check(float(gibson["footwear"]) < 12.0, "no hides, no moccasins")
	c.hides = 20.0
	_day(c, st, _august(2))
	t.check(float(gibson["footwear"]) > 35.0, "with hides the Mess shoes itself")
	t.check(c.hides < 20.0, "and the hides are used up")


func test_rain_wets_the_pirogues_and_drying_saves_it():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	_day(c, st, _august(1), {"storm": 1.0})
	t.check(c.wet.has("corn_hominy"), "the corn in the white pirogue got wet")
	t.check(not c.wet.has("salt_pork"), "the keelboat's hold stayed dry")
	var corn := float(st.find("corn_hominy")["qty"])
	c.set_duty("floyd", "dry")
	c.set_duty("ordway", "dry")
	_day(c, st, _august(2))
	t.check(not c.wet.has("corn_hominy"), "two Messes at it dry it all")
	t.check(float(st.find("corn_hominy")["qty"]) > corn - 3.0, "before much of it is lost")


func test_wet_stores_left_alone_spoil():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	_day(c, st, _august(1), {"storm": 1.0})
	var corn := float(st.find("corn_hominy")["qty"])
	for d in range(2, 6):
		_day(c, st, _august(d))
	t.check(float(st.find("corn_hominy")["qty"]) < corn - 1.0, "left wet, it spoils")


func test_a_mess_out_hunting_brings_in_meat():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var hides := c.hides
	c.set_duty("floyd", "hunt")
	c.set_duty("ordway", "hunt")
	c.set_duty("pryor", "hunt")
	_day(c, st, _august(1))
	var k: Dictionary = c.yesterday["kills"]
	t.check(int(k["deer"]) + int(k["elk"]) >= 3, "three Messes hunting kill game: %s" % k)
	t.check(c.hides > hides, "and bring the hides")


func test_floyd_dies_on_the_twentieth_whatever_is_done():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var floyd := c.man("floyd")
	var said: Array[String] = []
	for d in range(1, 20):
		floyd["health"] = 100.0  # the best care in the world
		said.append_array(_day(c, st, _august(d)))
		t.eq(floyd["status"], "present", "Floyd lives on the %d" % d)
	t.check(c.has_condition(floyd, "bilious_colic"), "and is taken very bad on the 19th")
	c.treat("floyd", st)
	said.append_array(_day(c, st, _august(20)))
	t.eq(floyd["status"], "dead", "but he dies on the 20th")
	t.check(said.any(func(l): return l.contains("Floyd died")), "and the Journal says so")


func test_physic_shortens_a_flux_and_costs_the_man():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var shields := c.man("shields")
	shields["health"] = 90.0
	c.add_condition(shields, "dysentery")
	shields["conditions"][0]["days"] = 5
	var pills := float(st.find("rush_pills")["qty"])
	t.check(c.treat("shields", st).contains("Rush's pills"), "Lewis doses him")
	t.eq(int(shields["conditions"][0]["days"]), 4, "the flux runs a day shorter")
	t.check(float(shields["health"]) < 90.0, "and the purge weakens him")
	t.check(float(st.find("rush_pills")["qty"]) < pills, "from the medicine chest")
	t.eq(c.treat("shields", st), "", "a second dose does nothing more")
	t.eq(c.treat("colter", st), "", "nor does physic for a well man")


func test_the_morning_report():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var r := c.morning_report(st)
	var speakers := {}
	for ms in r["messes"]:
		speakers[ms["id"]] = ms["speaker"]
	t.eq(speakers["ordway"], "Sergeant Ordway", "each sergeant reports for his Mess")
	var all_lines := []
	for ms in r["messes"]:
		all_lines.append_array(ms["lines"])
	t.check(all_lines.any(func(l): return l.contains("Floyd is very sick")), "who is sick")
	t.check(all_lines.any(func(l): return l.contains("La Liberté is not yet come back")), "who is away")
	t.check(r["stores"].any(func(l): return l.begins_with("Provisions for")), "what is short")
	t.check(r["calls"].any(func(x): return x["man"] == "floyd" and x["can_treat"]), "and the calls the captain may make")


func test_a_mess_without_its_sergeant():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	for d in range(1, 21):
		_day(c, st, _august(d))
	var r := c.morning_report(st)
	for ms in r["messes"]:
		if ms["id"] == "floyd":
			t.check(ms["lines"][0].contains("died yesterday"), "the Mess reports its loss")
			t.check(not ms["speaker"].begins_with("Sergeant"), "and has no sergeant to report it")
	c.appoint("floyd", "gass")
	for ms in c.morning_report(st)["messes"]:
		if ms["id"] == "floyd":
			t.eq(ms["speaker"], "Sergeant Gass", "until one is appointed")


func test_repair_mends_a_snagged_boat():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	c.boats["keelboat"] = 40.0
	c.set_duty("floyd", "repair")
	_day(c, st, _august(1))
	t.check(float(c.boats["keelboat"]) > 55.0, "Gass and the Mess patch her: %s" % c.boats["keelboat"])


func test_hunger_tells_on_the_men():
	var c := Corps.load_corps()
	var st := Stores.new()  # nothing to eat
	var m0 := c.mean_morale()
	for d in range(1, 4):
		_day(c, st, _august(d))
	t.check(c.has_condition(c.man("colter"), "starving"), "no ration, and the men starve")
	t.check(c.mean_morale() < m0 - 5.0, "and their spirits go with it")


func test_the_corps_saves_and_loads():
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	for d in range(1, 6):
		_day(c, st, _august(d), {"storm": 0.5})
	var saved := c.save_state()
	var back := Corps.load_corps()
	back.load_state(JSON.parse_string(JSON.stringify(saved)))
	t.eq(back.fit_count(), c.fit_count(), "the same men fit")
	t.eq(snappedf(back.mean_morale(), 0.01), snappedf(c.mean_morale(), 0.01), "in the same spirits")
	t.eq(back.wet.keys().size(), c.wet.keys().size(), "with the same stores wet")
