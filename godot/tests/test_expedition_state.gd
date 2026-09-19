extends RefCounted
## Ported from tests/test_state.py (Calendar and Day Clock).

var t


func test_advance_date_rolls_year() -> void:
	var s := ExpeditionState.new()
	s.current_year = 1804; s.current_month = 12; s.current_day = 20
	s.advance_date(14)
	t.eq([s.current_year, s.current_month, s.current_day], [1805, 1, 3])


func test_real_month_lengths() -> void:
	var s := ExpeditionState.new()
	s.current_year = 1805; s.current_month = 2; s.current_day = 28
	s.advance_date(1)
	t.eq([s.current_month, s.current_day], [3, 1], "1805 not a leap year")
	s.current_year = 1804; s.current_month = 5; s.current_day = 14
	s.advance_date(36)
	t.eq([s.current_month, s.current_day], [6, 19])


func test_day_clock_rolls_into_calendar() -> void:
	var s := ExpeditionState.new()
	s.current_month = 8; s.current_day = 31; s.minute_of_day = 23 * 60
	t.eq(s.advance_minutes(90), 1, "midnights crossed")
	t.eq([s.current_month, s.current_day, s.clock_str()], [9, 1, "00:30"])


func test_landmark_and_discovery_only_once() -> void:
	var s := ExpeditionState.new()
	t.check(s.visit_landmark("council_bluff", "Council Bluff."))
	t.check(not s.visit_landmark("council_bluff", "again"))
	t.check(s.add_discovery("prairie_dog", "Prairie dog."))
	t.check(not s.add_discovery("prairie_dog", "again"))
	t.eq(s.journal.size(), 2)
	t.check(s.journal[0].begins_with("[August 1, 1804] "))
