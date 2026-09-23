class_name ExpeditionState
extends RefCounted
## Shared expedition state — thin port of lewis_clark/state.py for the spike:
## the Calendar, the Day Clock, Landmarks, Discoveries, supplies, and the Journal.

const MONTHS := ["", "January", "February", "March", "April", "May", "June", "July",
		"August", "September", "October", "November", "December"]

var current_year := 1804
var current_month := 8
var current_day := 1
var minute_of_day := 7 * 60
var current_region := "sioux_country"
## The party at Council Bluff: the permanent Corps and the engages who took the
## keelboat back from the Mandan. They all eat.
var men := 45
## Corps Strength, as the Corps last counted it (scripts/rules/corps.gd).
var fit := 45
var food := 80
var morale := 80
var landmarks_visited: Array[String] = []
## What has happened that later content may ask about ("scenario:<id>", ...).
var flags := {}
## Each Nation's regard for the Corps, carried from one meeting to the next.
var standing := {}
var discoveries: Array[String] = []
var journal: Array[String] = []

signal journal_added(text: String)
## One per midnight crossed, so the Stores can be drawn on a day at a time.
signal day_passed(day: int)


static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


func advance_date(days: int) -> void:
	## Move the Calendar forward by whole days (month and year roll over).
	current_day += days
	while current_day > days_in_month(current_year, current_month):
		current_day -= days_in_month(current_year, current_month)
		current_month += 1
		if current_month > 12:
			current_month = 1
			current_year += 1


func advance_minutes(minutes: int) -> int:
	## Run the Day Clock forward; returns how many midnights were crossed.
	var total := minute_of_day + minutes
	var days := total / (24 * 60)
	minute_of_day = total % (24 * 60)
	if days > 0:
		for d in days:
			advance_date(1)
			day_passed.emit(current_day)
	return days


func full_date_str() -> String:
	return "%s %d, %d" % [MONTHS[current_month], current_day, current_year]


func clock_str() -> String:
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]


func season() -> String:
	if current_month in [12, 1, 2]:
		return "Winter"
	if current_month in [3, 4, 5]:
		return "Spring"
	if current_month in [6, 7, 8]:
		return "Summer"
	return "Autumn"


func hour() -> float:
	return minute_of_day / 60.0


func add_journal(text: String) -> void:
	journal.append("[%s] %s" % [full_date_str(), text])
	journal_added.emit(text)


func visit_landmark(id: String, text: String) -> bool:
	if id in landmarks_visited:
		return false
	landmarks_visited.append(id)
	add_journal(text)
	return true


func add_discovery(id: String, text: String) -> bool:
	if id in discoveries:
		return false
	discoveries.append(id)
	add_journal(text)
	return true
