class_name Follower
extends CorpsFigure
## A member of the Corps walking the Leader's trail, a few metres apart.

var leader: Leader
var place := 1  # position in the line
const SPACING := 2.6

# Pace personality, drawn from gait_rng (seeded per person in CorpsFigure):
# how far back they like to be, how much that drifts, how far they stray off
# the trail, how quickly they respond, and how hard they accelerate.
var _gap := 0.0
var _gap_drift := 0.0
var _wander := 0.0
var _gain := 1.6
var _accel := 4.0
var _slack := 0.6
var _seed := 0.0
var _velocity := Vector3.ZERO


func _ready() -> void:
	super._ready()
	_gap = gait_rng.randf_range(-0.7, 1.3)
	_gap_drift = gait_rng.randf_range(0.6, 1.8)
	_wander = gait_rng.randf_range(0.2, 1.1)
	_gain = gait_rng.randf_range(1.1, 2.1)
	_accel = gait_rng.randf_range(2.5, 6.0)
	_slack = gait_rng.randf_range(0.4, 1.1)
	_seed = gait_rng.randf() * 100.0


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# The line stretches and bunches: each keeps a gap of their own that drifts.
	var gap := place * SPACING + _gap + sin(t * 0.11 + _seed) * _gap_drift + sin(t * 0.37 + _seed * 2.0) * 0.3 * _gap_drift
	var target := _trail_point(maxf(gap, 1.2))
	# And they don't all tread exactly in the Leader's footprints.
	var ahead := _trail_point(maxf(gap - 1.0, 0.2)) - target
	ahead.y = 0.0
	if ahead.length() > 0.05:
		target += ahead.normalized().cross(Vector3.UP) * sin(t * 0.07 + _seed * 3.0) * _wander
	# When the Leader stands still, the Corps spreads out to either side of the
	# trail instead of queueing up between the Leader and the camera.
	if leader.ground_speed() < 0.3:
		var back := (target - leader.global_position)
		back.y = 0.0
		if back.length() > 0.1:
			var side := back.normalized().cross(Vector3.UP) * (1.0 if place % 2 else -1.0)
			target = leader.global_position + side * (1.6 + 1.2 * ceili(place / 2.0)) + back.normalized() * 0.8
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var desired := Vector3.ZERO
	if dist > _slack:
		desired = to.normalized() * clampf(dist * _gain, 0.0, Leader.SPRINT * 1.05)
	# Ease into and out of pace rather than matching the Leader instantly.
	_velocity = _velocity.move_toward(desired, _accel * delta)
	apply_locomotion(_velocity, delta)


func _trail_point(back: float) -> Vector3:
	## The point ``back`` metres behind the Leader along their trail.
	var trail := leader.trail
	var remaining := back
	var prev := leader.global_position
	for i in range(trail.size() - 1, -1, -1):
		var seg := prev.distance_to(trail[i])
		if seg >= remaining:
			return prev.lerp(trail[i], remaining / max(seg, 0.001))
		remaining -= seg
		prev = trail[i]
	return prev
