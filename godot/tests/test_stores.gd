extends RefCounted
## The Corps' Stores: what they carry, what it weighs, what it costs to keep.

var t


func _stores() -> Stores:
	return Stores.load_manifest()


func test_the_manifest_loads_with_the_recorded_stores() -> void:
	var s := _stores()
	t.check(s.count("portable_soup") == 193, "193 lb of portable soup")
	t.check(s.count("whiskey") == 120, "120 gallons of whiskey")
	t.check(s.count("medals") == 89, "89 peace medals")
	t.check(s.categories().has("Presents"), "presents are their own category")


func test_weight_is_carried_by_boat() -> void:
	var s := _stores()
	t.check(s.weight("keelboat") > 3000.0, "the keelboat carries the bulk of it")
	t.check(s.weight("packs") < s.weight("keelboat"), "the packs carry least")
	t.check(absf(s.total_weight() - (s.weight("keelboat") + s.weight("red_pirogue")
			+ s.weight("white_pirogue") + s.weight("packs"))) < 0.01, "the parts make the whole")
	t.check(s.load_of("keelboat") > 0.0 and s.load_of("keelboat") < 1.0, "within her capacity")


func test_rations_are_eaten_and_run_out() -> void:
	var s := _stores()
	var pork := s.count("salt_pork")
	var eaten := s.ration(33, 1)  # a day's ration for the Corps
	t.check(eaten.size() > 0, "something was eaten")
	t.check(s.count("salt_pork") <= pork, "the pork goes down")
	var empty := Stores.new()
	t.check(empty.ration(33, 1).is_empty(), "nothing to eat is not a crash")


func test_presents_are_spent_and_their_regard_counted() -> void:
	var s := _stores()
	t.check(s.regard_of("medals") > s.regard_of("rings"), "a medal outweighs a ring")
	var before := s.count("blue_beads")
	t.check(s.give("blue_beads", 5) == 5, "five pounds of blue beads given")
	t.eq(s.count("blue_beads"), before - 5, "and they are gone")
	t.eq(s.give("blue_beads", 99999), before - 5, "cannot give what is not there")
	t.check(s.gift_regard() > 0, "the presents still have standing")


func test_damp_spoils_what_it_can_reach() -> void:
	var s := _stores()
	var flour := s.count("flour")
	var chronometers := s.count("chronometer")
	s.spoil(0.5)
	t.check(s.count("flour") < flour, "wet flour is lost")
	t.eq(s.count("chronometer"), chronometers, "a chronometer does not spoil")
