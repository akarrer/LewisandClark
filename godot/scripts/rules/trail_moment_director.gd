class_name TrailMomentDirector
extends RefCounted
## Decides when Trail Moments happen. Pure logic, no scene access, so it can be tested.
##
## - Random Moments come every ``cadence_min``–``cadence_max`` seconds of *walking*
##   (standing still doesn't count), with variety: none repeats within the Region,
##   and the same Companion never speaks two Moments in a row. About a third of
##   the random picks favour Moments that can escalate.
## - Placed Moments fire when the Leader comes within their radius of a spot,
##   and reset the random cadence so beats don't pile up.
## - Only one Moment plays at a time.

var defs: Array = []
var cadence_min := 60.0
var cadence_max := 90.0
var escalate_share := 1.0 / 3.0

var fired: Array[String] = []
var active_id := ""
var last_speaker := ""
var _walked := 0.0
var _next_at := 0.0
var _rng: RandomNumberGenerator


func _init(moment_defs: Array, rng: RandomNumberGenerator = null) -> void:
	defs = moment_defs
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_schedule()


static func load_defs(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	return data["moments"]


func _schedule() -> void:
	_walked = 0.0
	_next_at = _rng.randf_range(cadence_min, cadence_max)


func seconds_until_next() -> float:
	return max(0.0, _next_at - _walked)


func finish(id: String) -> void:
	if id == active_id:
		active_id = ""


func update(delta: float, walking: bool, context: Dictionary) -> String:
	## Advance by ``delta`` seconds; returns the id of a Moment to start, or "".
	## ``context``: {"position": Vector3, "points": {name: Vector3}, "companions": [ids], "hour": float}
	if active_id != "":
		return ""
	var placed := _placed_in_range(context)
	if placed != "":
		return _start(placed, true)
	if walking:
		_walked += delta
	if _walked < _next_at:
		return ""
	var pick := _pick_random(context)
	if pick == "":
		_schedule()
		return ""
	return _start(pick, true)


func _start(id: String, reschedule: bool) -> String:
	fired.append(id)
	active_id = id
	last_speaker = str(_def(id).get("speaker", ""))
	if reschedule:
		_schedule()
	return id


func _def(id: String) -> Dictionary:
	for d in defs:
		if d["id"] == id:
			return d
	return {}


func eligible(d: Dictionary, context: Dictionary) -> bool:
	if d["id"] in fired:
		return false
	var companions: Array = context.get("companions", [])
	for need in d.get("requires", []):
		if need not in companions:
			return false
	var hours: Array = d.get("hours", [])
	if hours.size() == 2:
		var h: float = context.get("hour", 12.0)
		if h < hours[0] or h >= hours[1]:
			return false
	return true


func _placed_in_range(context: Dictionary) -> String:
	var pos: Vector3 = context.get("position", Vector3.ZERO)
	var points: Dictionary = context.get("points", {})
	for d in defs:
		var trig: Dictionary = d.get("trigger", {})
		if trig.get("type", "") != "near" or not eligible(d, context):
			continue
		var p = points.get(trig["point"])
		if p == null:
			continue
		var flat := Vector2(pos.x - p.x, pos.z - p.z)
		if flat.length() <= float(trig.get("radius", 30.0)):
			return d["id"]
	return ""


func _pick_random(context: Dictionary) -> String:
	var pool: Array = []
	for d in defs:
		if d.get("trigger", {}).get("type", "") != "random" or not eligible(d, context):
			continue
		if last_speaker != "" and str(d.get("speaker", "")) == last_speaker:
			continue
		pool.append(d)
	if pool.is_empty():
		return ""
	var escalating := pool.filter(func(d): return d.get("escalates", false))
	var calm := pool.filter(func(d): return not d.get("escalates", false))
	var from := pool
	if not escalating.is_empty() and not calm.is_empty():
		from = escalating if _rng.randf() < escalate_share else calm
	return from[_rng.randi_range(0, from.size() - 1)]["id"]
