extends RefCounted
## The Stores run down as the Day Clock turns (see main.gd _feed_the_corps).

var t


func test_the_clock_reports_each_midnight_it_crosses() -> void:
	var s := ExpeditionState.new()
	var days := []
	s.day_passed.connect(func(d): days.append(d))
	s.minute_of_day = 23 * 60
	t.eq(s.advance_minutes(120), 1, "one midnight crossed")
	t.eq(days.size(), 1, "and reported once")
	t.eq(s.advance_minutes(3 * 24 * 60), 3, "three more days")
	t.eq(days.size(), 4, "reported each of them")


func test_the_corps_eat_a_day_at_a_time() -> void:
	var st := Stores.load_manifest()
	var pork := st.count("salt_pork")
	var days := st.days_of_provisions(45)
	t.check(days > 20 and days < 400, "weeks of provisions, not hours: %d" % days)
	st.ration(45, 1)
	t.check(st.count("salt_pork") < pork, "the pork goes down")
	t.check(st.days_of_provisions(45) < days + 1, "and there is less left")


func test_fresh_meat_is_eaten_before_it_spoils() -> void:
	var st := Stores.load_manifest()
	var pork := st.count("salt_pork")
	st.add("fresh_meat", 400.0)
	st.ration(45, 1)
	t.eq(st.count("salt_pork"), pork, "the pork is spared while there is meat")
	t.check(st.count("fresh_meat") < 400, "the meat is eaten")


func test_meat_spoils_faster_than_salt_pork() -> void:
	var st := Stores.load_manifest()
	st.add("fresh_meat", 100.0)
	var pork := st.count("salt_pork")
	st.spoil(1.0)
	t.check(st.count("fresh_meat") < 40, "meat goes bad quickly in August")
	t.check(st.count("salt_pork") > pork * 0.5, "salted pork keeps rather better")


func test_short_rations_are_reported() -> void:
	var st := Stores.new()
	t.check(st.days_of_provisions(45) == 0, "nothing to eat is nought days")
	t.check(st.short_ration(45), "and that is a short ration")
