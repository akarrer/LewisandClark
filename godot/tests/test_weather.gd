extends RefCounted
## The air at Council Bluff (see scripts/rules/weather.gd).

var t


func test_august_afternoons_are_hot_and_dawns_are_not() -> void:
	var noonish := Weather.temperature_f(8, 3, 15.5, 0.3, 0.0)
	var dawn := Weather.temperature_f(8, 3, 5.5, 0.3, 0.0)
	t.check(noonish > 74.0 and noonish < 96.0, "August afternoon, got %.0f" % noonish)
	t.check(dawn > 52.0 and dawn < 72.0, "August dawn, got %.0f" % dawn)
	t.check(noonish - dawn > 10.0, "the day warms")


func test_winter_is_colder_than_summer() -> void:
	t.check(Weather.temperature_f(1, 15, 15.0, 0.3, 0.0) < Weather.temperature_f(7, 15, 15.0, 0.3, 0.0) - 30.0, "January vs July")


func test_storms_and_cloud_cool_the_afternoon() -> void:
	var clear := Weather.temperature_f(8, 3, 15.0, 0.1, 0.0)
	t.check(Weather.temperature_f(8, 3, 15.0, 0.1, 1.0) < clear - 5.0, "storm cools")
	t.check(Weather.temperature_f(8, 3, 15.0, 0.9, 0.0) < clear - 4.0, "cloud keeps the heat off")


func test_the_sky_is_described_in_plain_words() -> void:
	t.eq(Weather.describe(0.05, 0.0, 13.0, 0.0), "Clear", "clear")
	t.eq(Weather.describe(0.45, 0.0, 13.0, 0.0), "Partly cloudy", "partly cloudy")
	t.eq(Weather.describe(0.95, 0.0, 13.0, 0.0), "Overcast", "overcast")
	t.eq(Weather.describe(0.5, 0.35, 13.0, 0.0), "Rain", "rain")
	t.eq(Weather.describe(0.5, 0.9, 13.0, 0.0), "Thunderstorm", "thunderstorm")
	t.eq(Weather.describe(0.2, 0.0, 7.0, 0.9), "Misty", "river mist at dawn")
	t.eq(Weather.describe_night(0.05, 0.0), "Clear", "a clear night")


func test_each_day_has_a_weather_of_its_own() -> void:
	var first := Weather.day_pattern(8, 3)
	t.check(first["cover"] >= 0.0 and first["cover"] <= 1.0, "cloud within bounds")
	t.check(first["storm_hour"] >= 12.0 and first["storm_hour"] <= 20.0, "storms break in the afternoon")
	t.eq(Weather.day_pattern(8, 3)["cover"], first["cover"], "the same day is the same weather")
	t.check(Weather.day_pattern(8, 4)["cover"] != first["cover"], "the next day is not")


func test_the_plains_are_stormier_in_summer_than_in_winter() -> void:
	var summer := 0.0
	var winter := 0.0
	for day in range(1, 29):
		summer += 1.0 if Weather.day_pattern(7, day)["storm"] else 0.0
		winter += 1.0 if Weather.day_pattern(1, day)["storm"] else 0.0
	t.check(summer > winter, "July storms more than January: %d vs %d" % [summer, winter])
	t.check(summer < 28.0, "but not every day")
