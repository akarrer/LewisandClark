class_name Weather
## What the air is doing, in the terms the Corps would have used. Lewis carried
## thermometers and recorded the temperature morning and afternoon, in Fahrenheit,
## so that is what the Journal and the HUD show.
##
## Engine-agnostic and pure: the sky drives it, it draws nothing.

## Mean daily high and low (Fahrenheit) at this latitude, by month, taken from
## modern normals for the Council Bluffs reach and shaded a couple of degrees
## cooler: 1804 sat in the tail of the Little Ice Age.
const CLIMATE := [
	[33.0, 14.0], [39.0, 19.0], [52.0, 29.0], [64.0, 40.0], [74.0, 51.0], [84.0, 61.0],
	[88.0, 66.0], [86.0, 64.0], [78.0, 54.0], [65.0, 41.0], [49.0, 28.0], [36.0, 17.0],
]
const LITTLE_ICE_AGE := -2.0

## How often a thunderstorm breaks over the plains in the afternoon, by month.
const STORM_CHANCE := [0.02, 0.03, 0.10, 0.18, 0.28, 0.30, 0.28, 0.26, 0.16, 0.10, 0.05, 0.03]

## Coldest just before dawn, warmest in the middle of the afternoon.
const COLDEST_HOUR := 5.5
const WARMEST_HOUR := 15.5


static func temperature_f(month: int, day: int, hour: float, cloud: float, storm: float) -> float:
	var m: Array = CLIMATE[clampi(month - 1, 0, 11)]
	var high: float = m[0] + LITTLE_ICE_AGE
	var low: float = m[1] + LITTLE_ICE_AGE
	# Cloud holds the night's warmth in and keeps the day's heat off.
	high -= 9.0 * cloud
	low += 5.0 * cloud
	# A day of its own: some are warmer than the month, some cooler.
	var swing := (_hash01(month * 41 + day * 7) - 0.5) * 12.0
	high += swing
	low += swing * 0.7
	# Through the day: a cosine from the cold hour to the warm one and back.
	var t := fposmod(hour - COLDEST_HOUR, 24.0) / 24.0
	var span := (WARMEST_HOUR - COLDEST_HOUR) / 24.0
	var warmth: float
	if t <= span:
		warmth = 0.5 - 0.5 * cos(PI * t / span)
	else:
		warmth = 0.5 + 0.5 * cos(PI * (t - span) / (1.0 - span))
	return lerpf(low, high, warmth) - 8.0 * storm


static func describe(cloud: float, storm: float, hour: float, haze: float) -> String:
	## The word a journal would use for the sky.
	if storm > 0.55:
		return "Thunderstorm"
	if storm > 0.2:
		return "Rain"
	if haze > 0.6 and cloud < 0.6 and hour < 9.0:
		return "Misty"
	if cloud > 0.85:
		return "Overcast"
	if cloud > 0.62:
		return "Cloudy"
	if cloud > 0.34:
		return "Partly cloudy"
	if cloud > 0.12:
		return "Fair"
	return "Clear"


static func describe_night(cloud: float, storm: float) -> String:
	## At night "sunny" makes no sense; the sky is clear or it is not.
	if storm > 0.55:
		return "Thunderstorm"
	if storm > 0.2:
		return "Rain"
	if cloud > 0.85:
		return "Overcast"
	if cloud > 0.62:
		return "Cloudy"
	if cloud > 0.34:
		return "Broken cloud"
	return "Clear"


static func _hash01(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)



static func day_pattern(month: int, day: int) -> Dictionary:
	## The weather this day was given, the same every time it is asked. Cloud runs
	## from a clear day to an overcast one; storms break in the afternoon and are
	## a summer thing on the plains, where the heat builds all day and then goes.
	var roll := _hash01(month * 131 + day * 17)
	var roll2 := _hash01(month * 57 + day * 91 + 7)
	var roll3 := _hash01(month * 23 + day * 13 + 3)
	# Winter skies are duller, summer skies clearer between the storms.
	var winter := 1.0 - absf(float(month) - 7.0) / 6.0
	var cover: float = clampf(0.12 + roll * 0.7 + (1.0 - winter) * 0.18, 0.0, 1.0)
	var storms: bool = roll2 < STORM_CHANCE[clampi(month - 1, 0, 11)] * (0.5 + cover)
	return {
		"cover": cover,
		"storm": storms,
		"storm_hour": 13.0 + roll3 * 6.0,
		"storm_seconds": 25.0 + roll * 45.0,
	}
