class_name Corps
extends RefCounted
## Every man of the Corps, simulated (ADR-0010): health, Conditions, fatigue,
## footwear, clothes and morale for each of them, with the boats, the hides for
## moccasins, and whatever in the Stores has got wet.
##
## Command runs through the three Messes: each morning the captain sets each of
## them a duty for the day, and may make a call on a single man -- excuse him
## from duty, or dose him from the medicine chest. The sergeants answer with the
## Morning Report. Engine-agnostic and saveable, like Stores: the roster and every
## number are data (data/corps.json); this is only the arithmetic.
## See docs/design/corps.md.

const DATA := "res://data/corps.json"

## Duties the captain may set a Mess on a day in camp. Travel days are "crew".
const CAMP_DUTIES := ["rest", "hunt", "dry", "mend", "repair"]

var men: Array[Dictionary] = []
var messes: Array = []
var conditions := {}
var duty_defs := {}
var rules := {}
var history: Array = []
var boats := {}
var hides := 0.0
var horses := 0
## Item id -> how much of it is wet and will spoil unless it is dried.
var wet := {}
## Mess id -> the duty set for it this morning.
var duties := {}
var excused := {}
var low_morale_days := 0
var rng := RandomNumberGenerator.new()
## What happened in the day just past, for the Morning Report to tell.
var yesterday := {}


static func load_corps(path: String = DATA) -> Corps:
	var c := Corps.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "no Corps data at " + path)
	c.messes = data["messes"]
	c.conditions = data["conditions"]
	c.duty_defs = data["duties"]
	c.rules = data["rules"]
	c.history = data.get("history", [])
	c.boats = (data.get("boats", {}) as Dictionary).duplicate()
	c.hides = float(data.get("hides", 0))
	c.horses = int(data.get("horses", 0))
	c.rng.seed = int(data.get("seed", 1804))
	for raw in data["men"]:
		var m: Dictionary = (raw as Dictionary).duplicate(true)
		m["status"] = str(m.get("status", "present"))
		m["health"] = float(m.get("health", c.rng.randf_range(88.0, 100.0)))
		# They came up to the bluff on the towline; nobody is fresh.
		m["fatigue"] = float(m.get("fatigue", c.rng.randf_range(20.0, 45.0)))
		m["footwear"] = float(m.get("footwear", c.rng.randf_range(35.0, 85.0)))
		m["clothes"] = float(m.get("clothes", c.rng.randf_range(55.0, 85.0)))
		m["morale"] = float(m.get("morale", c.rng.randf_range(62.0, 78.0)))
		m["conditions"] = m.get("conditions", [])
		c.men.append(m)
	for mess in c.messes:
		if bool(mess.get("commanded", false)):
			c.duties[mess["id"]] = "rest"
	return c


# ------------------------------------------------------------------ the roll


func man(id: String) -> Dictionary:
	for m in men:
		if m["id"] == id:
			return m
	return {}


func mess(id: String) -> Dictionary:
	for ms in messes:
		if ms["id"] == id:
			return ms
	return {}


func present() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in men:
		if m["status"] == "present":
			out.append(m)
	return out


func eating() -> int:
	## Mouths at the fire tonight.
	return present().size()


func on_the_roll() -> int:
	## Alive and still of the Corps, here or away.
	var n := 0
	for m in men:
		if m["status"] in ["present", "away", "missing"]:
			n += 1
	return n


func is_fit(m: Dictionary) -> bool:
	if m["status"] != "present" or float(m["health"]) < float(rules["fit_health"]):
		return false
	for c in m["conditions"]:
		if bool(conditions[c["id"]].get("blocks_work", false)):
			return false
	return true


func fit_count() -> int:
	## Corps Strength: counted from the men, never stored (CONTEXT.md).
	var n := 0
	for m in present():
		if is_fit(m):
			n += 1
	return n


func mean_morale() -> float:
	var p := present()
	if p.is_empty():
		return 0.0
	var total := 0.0
	for m in p:
		total += float(m["morale"])
	return total / p.size()


func mess_men(mess_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in men:
		if m["mess"] == mess_id and m["status"] in ["present", "away", "missing"]:
			out.append(m)
	return out


func short_name(m: Dictionary) -> String:
	if m.has("short"):
		return str(m["short"])
	var parts := str(m["name"]).split(" ")
	return parts[parts.size() - 1]


func has_condition(m: Dictionary, cid: String) -> bool:
	for c in m["conditions"]:
		if c["id"] == cid:
			return true
	return false


func add_condition(m: Dictionary, cid: String) -> void:
	var span = conditions[cid]["days"]
	var days := -1 if span == null else rng.randi_range(int(span[0]), int(span[1]))
	for c in m["conditions"]:
		if c["id"] == cid:
			c["days"] = days
			return
	m["conditions"].append({"id": cid, "days": days})


# ------------------------------------------------------------------ orders


func set_duty(mess_id: String, duty: String) -> void:
	assert(duty in CAMP_DUTIES, "no such camp duty " + duty)
	if bool(mess(mess_id).get("commanded", false)):
		duties[mess_id] = duty


func excuse(id: String, on: bool = true) -> void:
	## A call on one man: off duty today, to ride in the boat and mend.
	if on:
		excused[id] = true
	else:
		excused.erase(id)


func treatment_for(m: Dictionary) -> Dictionary:
	## What the medicine chest has for what ails him, or nothing.
	for c in m["conditions"]:
		var t = conditions[c["id"]].get("treat", null)
		if t is Dictionary and not c.get("treated", false):
			var out: Dictionary = (t as Dictionary).duplicate()
			out["condition"] = c["id"]
			return out
	return {}


func treat(id: String, stores: Stores) -> String:
	## A call on one man: physic, as Lewis gave it. Returns the Journal line, or
	## "" if there is nothing to give or nothing to give it for. 1804 medicine:
	## the purge shortens a flux and weakens the man it is given to.
	var m := man(id)
	var t := treatment_for(m)
	if t.is_empty() or float(stores.find(str(t["item"])).get("qty", 0.0)) < float(t["qty"]):
		return ""
	stores.take(str(t["item"]), float(t["qty"]))
	for c in m["conditions"]:
		if c["id"] == t["condition"]:
			c["treated"] = true
			if int(c["days"]) > 0:
				c["days"] = maxi(1, int(c["days"]) - int(t["days_off"]))
	m["health"] = clampf(float(m["health"]) + float(t["health"]), 0.0, 100.0)
	return "%s %s." % [short_name(m), t["verb"]]


func hearten(amount: float) -> void:
	## Something the whole camp feels: a good council, a death, a dance.
	for m in present():
		m["morale"] = clampf(float(m["morale"]) + amount, 0.0, 100.0)


func tire(mess_id: String, amount: float) -> void:
	## A night's guard, a hard errand: fatigue on every present man of a Mess.
	for m in mess_men(mess_id):
		if m["status"] == "present":
			m["fatigue"] = clampf(float(m["fatigue"]) + amount, 0.0, 100.0)


func appoint(mess_id: String, id: String) -> void:
	## A new sergeant for a Mess, as Gass was after Floyd.
	for ms in messes:
		if ms["id"] == mess_id:
			ms["leader"] = id
	man(id)["rank"] = "sergeant"


func duty_of(m: Dictionary, travel: bool) -> String:
	## What this man does today. The sick and the excused do nothing.
	if m["status"] != "present":
		return ""
	if excused.has(m["id"]) or not is_fit(m):
		return "sick"
	if m.has("standing_duty"):
		return str(m["standing_duty"])
	if travel:
		return "rest" if m["mess"] == "captains" else "crew"
	return str(duties.get(m["mess"], "rest"))


# ------------------------------------------------------------------ a day


func pass_day(ctx: Dictionary, stores: Stores) -> Array[String]:
	## One day lived, resolved at the midnight that ends it. ``ctx``:
	##   ended   "1804-08-01", the date of the day just lived
	##   travel  true on a Leg day (the Corps works the boats upriver)
	##   storm   0..1, how much rain fell on the stores
	##   hot_f   the day's high, Fahrenheit
	## Returns the lines for the Journal.
	var lines: Array[String] = []
	yesterday = {"kills": {"deer": 0, "elk": 0}, "snag": "", "died": [], "fell_sick": [], "wet_new": {}, "spoiled": {}}
	var travel := bool(ctx.get("travel", false))
	var hot := float(ctx.get("hot_f", 80.0)) > float(rules["hot_above_f"])
	var work := {}
	for m in present():
		work[m["id"]] = duty_of(m, travel)

	_hunt(work, stores)
	_boats(work, travel, lines)
	_weather_the_stores(work, float(ctx.get("storm", 0.0)), stores, lines)

	# The day's ration and the gill. Fresh meat keeps a day, two at the most.
	var short := stores.short_ration(eating())
	stores.ration(eating(), 1)
	var gill := stores.take("whiskey", eating() * float(rules["gill_gallons"])) > 0.0
	var meat := float(stores.find("fresh_meat").get("qty", 0.0))
	stores.take("fresh_meat", meat * float(rules.get("meat_spoil_per_day", 0.5)))

	var fiddle := false
	for m in present():
		if "fiddler" in m.get("trades", []) and work[m["id"]] in ["rest", "sick"]:
			fiddle = true
	for m in present():
		_live_the_day(m, str(work[m["id"]]), hot, short, lines)
	_history(str(ctx.get("ended", "")), lines)
	for m in present():
		_morale(m, str(work.get(m["id"], "rest")), short, gill, fiddle)
	for m in men:
		if m["status"] == "away" and str(m.get("due", "")) == str(ctx.get("ended", "")):
			m["overdue"] = true

	low_morale_days = low_morale_days + 1 if mean_morale() < float(rules["mutiny_morale"]) else 0
	excused.clear()
	if short:
		lines.append("The ration will not stretch to the whole party; the men go hungry.")
	return lines


func _hunt(work: Dictionary, stores: Stores) -> void:
	for m in present():
		if work[m["id"]] != "hunt":
			continue
		var odds := float(rules["hunter_success"]) if "hunter" in m.get("trades", []) else float(rules["hunt_success"])
		if rng.randf() >= odds:
			continue
		var elk := rng.randf() < float(rules["elk_share"])
		stores.add("fresh_meat", float(rules["elk_lb"] if elk else rules["deer_lb"]))
		hides += 1.0
		yesterday["kills"]["elk" if elk else "deer"] += 1


func _boats(work: Dictionary, travel: bool, lines: Array[String]) -> void:
	if travel:
		for b in boats:
			boats[b] = maxf(0.0, float(boats[b]) - float(rules["hull_wear_per_day"]))
		if rng.randf() < float(rules["snag_chance"]):
			var dmg: Array = rules["snag_damage"]
			boats["keelboat"] = maxf(0.0, float(boats["keelboat"]) - rng.randf_range(float(dmg[0]), float(dmg[1])))
			yesterday["snag"] = "keelboat"
			lines.append("The boat ran on a snag and was near turning over; she is making water.")
	var mend := 0.0
	for m in present():
		if work[m["id"]] == "repair":
			var trade: bool = "carpenter" in m.get("trades", []) or "blacksmith" in m.get("trades", [])
			mend += float(rules["repair_per_man"]) * (float(rules["repair_trade_mult"]) if trade else 1.0)
	while mend > 0.01:
		var worst := ""
		for b in boats:
			if float(boats[b]) < 100.0 and (worst == "" or float(boats[b]) < float(boats[worst])):
				worst = b
		if worst == "":
			break
		var fix := minf(mend, 100.0 - float(boats[worst]))
		boats[worst] = float(boats[worst]) + fix
		mend -= fix


func _weather_the_stores(work: Dictionary, storm: float, stores: Stores, lines: Array[String]) -> void:
	## Rain gets into the open pirogues; a leaking keelboat wets her own hold.
	## What is wet spoils a share a day until a Mess is set to dry it. Powder is
	## sealed in lead canisters, which was the point of them.
	var leaking := float(boats.get("keelboat", 100.0)) < float(rules["leak_below_hull"])
	for it in stores.items:
		var id := str(it["id"])
		if not it.get("spoils", false) or id == "fresh_meat" or float(it["qty"]) <= 0.0:
			continue
		var share := 0.0
		if storm > 0.05 and it.get("where", "") != "keelboat":
			share = storm * float(rules["wet_share_per_storm"])
		elif leaking and it.get("where", "") == "keelboat":
			share = float(rules["wet_share_per_storm"]) * 0.5
		var dry_part := float(it["qty"]) - float(wet.get(id, 0.0))
		if share > 0.0 and dry_part > 0.0:
			wet[id] = float(wet.get(id, 0.0)) + dry_part * share
			yesterday["wet_new"][id] = true
	var drying := 0
	for m in present():
		if work[m["id"]] == "dry":
			drying += 1
	var dried := clampf(float(drying) / float(rules["dry_men_needed"]), 0.0, 1.0)
	for id in wet.keys():
		wet[id] = float(wet[id]) * (1.0 - dried)
		var lost := stores.take(id, float(wet[id]) * float(rules["wet_spoil_per_day"]))
		wet[id] = minf(float(wet[id]) - lost, float(stores.find(id).get("qty", 0.0)))
		if lost > 0.0:
			yesterday["spoiled"][id] = lost
		if float(wet[id]) < 0.01:
			wet.erase(id)
	if not yesterday["wet_new"].is_empty() and storm >= float(rules["wet_journal_storm"]):
		lines.append("Rain got into the stores in the pirogues.")


func _live_the_day(m: Dictionary, duty: String, hot: bool, short: bool, lines: Array[String]) -> void:
	var d: Dictionary = duty_defs.get("rest" if duty == "sick" else duty, duty_defs["rest"])
	# A night's sleep takes off a share of what he carries, less if he is unwell;
	# the day's work puts its own load back on. Fatigue settles where the two meet
	# rather than climbing without end.
	var slept := float(m["fatigue"]) * float(d.get("recovery", 0.3)) * (0.5 + 0.5 * float(m["health"]) / 100.0)
	var load := float(d["fatigue"]) + (float(rules["hot_fatigue"]) if hot and bool(d.get("ashore", false)) else 0.0)
	m["fatigue"] = clampf(float(m["fatigue"]) - slept + load, 0.0, 100.0)
	var boots := float(d["footwear"])
	if duty == "mend" and boots > 0.0:
		# Moccasins take leather. Without hides the men patch what they have.
		var need := float(rules["hides_per_mend"])
		var got := minf(hides, need)
		hides -= got
		boots *= got / need
	var trade := 2.0 if duty == "mend" and "tailor" in m.get("trades", []) else 1.0
	m["footwear"] = clampf(float(m["footwear"]) + boots, 0.0, 100.0)
	m["clothes"] = clampf(float(m["clothes"]) + float(d["clothes"]) * trade, 0.0, 100.0)

	# Conditions run their course.
	var change := 0.0
	var still: Array = []
	for c in m["conditions"]:
		change += float(conditions[c["id"]]["health_per_day"])
		if int(c["days"]) < 0:
			still.append(c)
			continue
		c["days"] = int(c["days"]) - 1
		if int(c["days"]) > 0:
			still.append(c)
	m["conditions"] = still
	if short and not has_condition(m, "starving"):
		add_condition(m, "starving")
	elif not short and has_condition(m, "starving"):
		m["conditions"] = m["conditions"].filter(func(c): return c["id"] != "starving")
	if change == 0.0 and not short:
		change = float(rules["regen_per_day"]) + float(d.get("health", 0.0))
		if duty == "sick":
			change += float(rules["excused_regen"])

	# New trouble.
	var ashore := bool(d.get("ashore", false))
	var odds := float(rules["sickness_per_day"]) * float(d.get("sickness", 1.0)) * (1.0 + float(m["fatigue"]) / 100.0)
	if hot:
		odds *= float(rules["hot_sickness"])
	if short:
		odds *= float(rules["short_ration_sickness"])
	if rng.randf() < odds:
		var cid := _pick_sickness(hot, ashore)
		if cid != "" and not has_condition(m, cid):
			add_condition(m, cid)
			yesterday["fell_sick"].append([m["id"], cid])
	if ashore and float(m["footwear"]) < float(rules["lame_below_footwear"]) and rng.randf() < float(rules["lame_chance"]) \
			and not has_condition(m, "lame"):
		add_condition(m, "lame")
		yesterday["fell_sick"].append([m["id"], "lame"])
	if float(m["fatigue"]) > float(rules["exhausted_above_fatigue"]) and not has_condition(m, "exhausted"):
		add_condition(m, "exhausted")
		yesterday["fell_sick"].append([m["id"], "exhausted"])

	m["health"] = clampf(float(m["health"]) + change, 0.0, 100.0)
	if float(m["health"]) <= 0.0:
		_dies(m, lines, "")


func _pick_sickness(hot: bool, ashore: bool) -> String:
	var total := 0.0
	var pool := []
	for cid in conditions:
		var c: Dictionary = conditions[cid]
		if float(c.get("weight", 0)) <= 0.0:
			continue
		if bool(c.get("hot_only", false)) and not hot:
			continue
		if bool(c.get("ashore_only", false)) and not ashore:
			continue
		pool.append([cid, float(c["weight"])])
		total += float(c["weight"])
	var roll := rng.randf() * total
	for p in pool:
		roll -= float(p[1])
		if roll <= 0.0:
			return str(p[0])
	return ""


func _dies(m: Dictionary, lines: Array[String], journal: String) -> void:
	if m["status"] == "dead":
		return
	m["status"] = "dead"
	m["conditions"] = []
	m["health"] = 0.0
	yesterday["died"].append(m["id"])
	lines.append(journal if journal != "" else "%s died." % m["name"])
	for other in present():
		other["morale"] = clampf(float(other["morale"]) + float(rules["morale_death"]), 0.0, 100.0)


func _history(date: String, lines: Array[String]) -> void:
	## History's own deaths are fixed (ADR-0012): whatever the player has done,
	## these happen on their day.
	for h in history:
		if str(h["date"]) != date:
			continue
		var m := man(str(h["man"]))
		if m.is_empty() or m["status"] == "dead":
			continue
		if h.has("condition"):
			add_condition(m, str(h["condition"]))
			yesterday["fell_sick"].append([m["id"], str(h["condition"])])
			lines.append(str(h.get("journal", "")))
		if bool(h.get("dies", false)):
			_dies(m, lines, str(h.get("journal", "")))


func _morale(m: Dictionary, duty: String, short: bool, gill: bool, fiddle: bool) -> void:
	var target := float(rules["morale_base"])
	if not gill:
		target += float(rules["morale_no_gill"])
	if short:
		target += float(rules["morale_short_ration"])
	if duty in ["rest", "sick"]:
		target += float(rules["morale_rest"])
	if fiddle:
		target += float(rules["morale_fiddle"])
	target += maxf(0.0, float(m["fatigue"]) - 50.0) * float(rules["morale_per_fatigue_over_50"])
	m["morale"] = clampf(lerpf(float(m["morale"]), target, float(rules["morale_drift"])), 0.0, 100.0)


# ------------------------------------------------------------------ report


func morning_report(stores: Stores) -> Dictionary:
	## The sergeants' account of the Corps at the start of the day: who is sick
	## or lame, what is short, what is wet (CONTEXT.md). Each Mess is spoken for
	## by its own sergeant; Ordway, the orderly sergeant, speaks for the stores.
	var out := {"fit": fit_count(), "present": eating(), "on_roll": on_the_roll(), "messes": [], "stores": [], "calls": []}
	for ms in messes:
		var ids := str(ms["id"])
		var lines: Array[String] = []
		var fit := 0
		for m in mess_men(ids):
			if m["status"] == "away":
				lines.append("%s is not yet come back%s." % [short_name(m), " and was looked for yesterday" if m.get("overdue", false) else ""])
				continue
			if is_fit(m):
				fit += 1
			for c in m["conditions"]:
				var why := str(conditions[c["id"]]["report"])
				lines.append("%s %s." % [short_name(m), why])
			if float(m["footwear"]) < float(rules["lame_below_footwear"]):
				lines.append("%s is near barefoot." % short_name(m))
			if not m["conditions"].is_empty():
				var t := treatment_for(m)
				out["calls"].append({"man": m["id"], "name": m["name"], "mess": ids,
						"treat": "" if t.is_empty() else str(t["verb"]), "treat_item": "" if t.is_empty() else str(t["item"]),
						"can_treat": not t.is_empty() and float(stores.find(str(t["item"])).get("qty", 0.0)) >= float(t["qty"]),
						"excused": excused.has(m["id"])})
		for id in yesterday.get("died", []):
			var dm := man(str(id))
			if dm["mess"] == ids:
				lines.push_front("%s died yesterday." % dm["name"])
		var count := 0
		for m in mess_men(ids):
			if m["status"] == "present":
				count += 1
		if lines.is_empty():
			lines.append("All fit for duty.")
		else:
			lines.append("%d fit for duty of %d." % [fit, count])
		out["messes"].append({"id": ids, "name": ms["name"], "speaker": _speaker(ms), "commanded": bool(ms.get("commanded", false)),
				"duty": str(duties.get(ids, "")), "fit": fit, "count": count, "lines": lines})

	var s: Array[String] = []
	var days := stores.days_of_provisions(eating())
	s.append("Provisions for %d days at the full ration." % days)
	var gallons := float(stores.find("whiskey").get("qty", 0.0))
	s.append("Whiskey for %d days at a gill a man." % int(gallons / maxf(0.001, eating() * float(rules["gill_gallons"]))))
	var k: Dictionary = yesterday.get("kills", {})
	if int(k.get("deer", 0)) + int(k.get("elk", 0)) > 0:
		s.append("The hunters brought in %s." % _kills(int(k.get("deer", 0)), int(k.get("elk", 0))))
	for id in wet:
		s.append("The %s is wet and will spoil unless it is dried." % str(stores.find(id).get("name", id)).to_lower())
	for id in yesterday.get("spoiled", {}):
		if float(yesterday["spoiled"][id]) >= 0.5:
			s.append("Some of the %s is spoiled." % str(stores.find(id).get("name", id)).to_lower())
	for b in boats:
		if float(boats[b]) < float(rules["leak_below_hull"]):
			s.append("The %s is making water." % str(b).replace("_", " ").replace("keelboat", "boat"))
		elif float(boats[b]) < 80.0:
			s.append("The %s wants caulking." % str(b).replace("_", " ").replace("keelboat", "boat"))
	s.append("%d hides in hand for moccasins." % int(hides))
	out["stores"] = s
	return out


func _speaker(ms: Dictionary) -> String:
	var lead := man(str(ms["leader"]))
	if not lead.is_empty() and lead["status"] == "present":
		var title: String = {"sergeant": "Sergeant", "corporal": "Corporal", "captain": "Captain", "patroon": "Patroon"}.get(lead["rank"], "")
		return ("%s %s" % [title, short_name(lead)]).strip_edges()
	for m in mess_men(str(ms["id"])):
		if m["status"] == "present":
			return short_name(m)
	return ""


static func _kills(deer: int, elk: int) -> String:
	var parts: Array[String] = []
	if deer > 0:
		parts.append("a deer" if deer == 1 else "%d deer" % deer)
	if elk > 0:
		parts.append("an elk" if elk == 1 else "%d elk" % elk)
	return " and ".join(parts)


# ------------------------------------------------------------------ endings


func ending() -> String:
	## "" while the expedition goes on. Leader death is checked by the game,
	## which knows who leads (Lewis only, in the Slice).
	if fit_count() < int(rules["collapse_below_fit"]):
		return "corps_collapsed"
	if low_morale_days >= int(rules["mutiny_days"]):
		return "mutiny"
	return ""


# ------------------------------------------------------------------ saving


func save_state() -> Dictionary:
	var roll := {}
	for m in men:
		roll[m["id"]] = {"status": m["status"], "health": m["health"], "fatigue": m["fatigue"], "footwear": m["footwear"],
				"clothes": m["clothes"], "morale": m["morale"], "conditions": m["conditions"].duplicate(true),
				"overdue": m.get("overdue", false)}
	var leaders := {}
	for ms in messes:
		leaders[ms["id"]] = ms["leader"]
	return {"men": roll, "leaders": leaders, "boats": boats.duplicate(), "hides": hides, "wet": wet.duplicate(),
			"duties": duties.duplicate(), "low_morale_days": low_morale_days, "rng": rng.state}


func load_state(saved: Dictionary) -> void:
	var roll: Dictionary = saved.get("men", {})
	for m in men:
		if roll.has(m["id"]):
			for k in roll[m["id"]]:
				m[k] = roll[m["id"]][k]
	for ms in messes:
		ms["leader"] = saved.get("leaders", {}).get(ms["id"], ms["leader"])
	boats = saved.get("boats", boats)
	hides = float(saved.get("hides", hides))
	wet = saved.get("wet", {})
	duties = saved.get("duties", duties)
	low_morale_days = int(saved.get("low_morale_days", 0))
	if saved.has("rng"):
		rng.state = int(saved["rng"])
