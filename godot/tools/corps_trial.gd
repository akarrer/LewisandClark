extends SceneTree
## Runs the Corps through a stretch of days under one standing order and prints
## how they hold up, a line a day, for tuning data/corps.json by eye:
##   godot --headless --path godot -s tools/corps_trial.gd -- --plan=camp|travel|hunt|mixed [--days=30] [--rain=0.3]
## camp   every Mess rests, every day
## travel every day on the boats upriver
## hunt   every Mess out hunting
## mixed  travel, with a day laid by each week to hunt, dry and make moccasins


func _init() -> void:
	var plan := "mixed"
	var days := 30
	var rain := 0.3
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=")
		if kv.size() == 2:
			match kv[0]:
				"plan": plan = kv[1]
				"days": days = int(kv[1])
				"rain": rain = float(kv[1])
	var c := Corps.load_corps()
	var st := Stores.load_manifest()
	var weather := RandomNumberGenerator.new()
	weather.seed = 7
	print("plan=%s  day  fit/present  morale  sick  lame  fatigue  boots  keel  wet  provisions  hides" % plan)
	for d in days:
		var travel := plan == "travel" or (plan == "mixed" and d % 7 != 6)
		if plan == "hunt":
			for ms in ["floyd", "ordway", "pryor"]:
				c.set_duty(ms, "hunt")
		elif plan == "mixed" and not travel:
			c.set_duty("floyd", "hunt")
			c.set_duty("ordway", "dry")
			c.set_duty("pryor", "mend")
		var month := 8 + (d / 31)
		var date := "1804-%02d-%02d" % [month, d % 31 + 1]
		var storm := weather.randf() if weather.randf() < rain else 0.0
		var lines := c.pass_day({"ended": date, "travel": travel, "storm": storm, "hot_f": weather.randf_range(78, 96)}, st)
		var sick := 0
		var lame := 0
		var fatigue := 0.0
		var boots := 0.0
		for m in c.present():
			if not m["conditions"].is_empty():
				sick += 1
			if c.has_condition(m, "lame"):
				lame += 1
			fatigue += float(m["fatigue"])
			boots += float(m["footwear"])
		var n := maxf(1.0, c.eating())
		print("%s %s  %2d/%2d  %5.1f  %3d  %3d  %6.1f  %5.1f  %4.0f  %3d  %4d  %4.0f   %s" % [date, "T" if travel else "c",
				c.fit_count(), c.eating(), c.mean_morale(), sick, lame, fatigue / n, boots / n, c.boats["keelboat"],
				c.wet.size(), st.days_of_provisions(c.eating()), c.hides, " | ".join(lines)])
	print("ending: '%s'" % c.ending())
	quit()
