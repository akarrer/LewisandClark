extends RefCounted
## A council with a Nation: what is offered, what the odds are, what it costs.

var t


func _council() -> Council:
	return Council.open("council_bluff_1804", Stores.load_manifest())


func test_the_council_at_council_bluff_is_the_real_one() -> void:
	var c := _council()
	t.eq(c.nation, "Otoe and Missouria", "the Nation")
	t.check(c.seats.size() >= 5, "six chiefs were made that day")
	t.check(not c.seat_named("Little Thief").get("present", true), "the great chief is away on the hunt")
	t.check(c.step("the_ask").get("wants", {}).has("powder"), "they ask for powder")


func test_odds_are_shown_before_they_are_rolled() -> void:
	var c := _council()
	var bare := c.odds("speech")
	t.check(bare > 0.0 and bare < 1.0, "a chance, not a certainty: %f" % bare)
	c.interpreter_present = false
	t.check(c.odds("speech") < bare, "without an interpreter the words go crooked")


func test_offering_presents_lifts_the_odds() -> void:
	var c := _council()
	var bare := c.odds("medals")
	c.offer("medals", 5)
	c.offer("flags", 1)
	t.check(c.odds("medals") > bare + 0.1, "what is laid out is what they judge")
	t.check(c.odds("medals") <= 0.95, "never a certainty")


func test_what_is_given_leaves_the_stores() -> void:
	var c := _council()
	var had := c.stores.count("medals")
	c.offer("medals", 5)
	c.offer("flags", 1)
	var outcome := c.resolve("medals", 0.0)  # a roll of 0 always passes
	t.check(outcome["passed"], "with the medals laid out it goes well")
	t.eq(c.stores.count("medals"), had - 5, "the medals are given")
	t.check(c.standing > 0, "and they think the better of the Corps")


func test_refusing_their_ask_is_remembered() -> void:
	var c := _council()
	var outcome := c.refuse("the_ask")
	t.check(not outcome["passed"], "refusing is not a pass")
	t.check(c.standing < 0, "it costs standing")
	t.check(str(outcome["text"]).length() > 0, "and it is written down")


func test_a_council_cannot_be_held_twice() -> void:
	var c := _council()
	c.offer("medals", 5)
	c.resolve("medals", 0.0)
	t.check(c.done("medals"), "that step is done")
	var second := c.resolve("medals", 0.0)
	t.check(not second.get("passed", false), "and cannot be held again")


func test_what_is_laid_out_stays_out_until_it_is_asked_for() -> void:
	var c := _council()
	c.offer("medals", 5)
	c.resolve("speech", 0.0)  # the speech asks for nothing
	t.eq(int(c.offered.get("medals", 0)), 5, "the medals are still on the ground")
	c.resolve("medals", 0.0)
	t.eq(int(c.offered.get("medals", 0)), 0, "and then they are given")
