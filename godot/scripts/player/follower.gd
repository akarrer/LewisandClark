class_name Follower
extends CorpsFigure
## A member of the Corps walking the Leader's trail, a few metres apart.

var leader: Leader
var place := 1  # position in the line
const SPACING := 2.6


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	var target := _trail_point(place * SPACING)
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
	var move := Vector3.ZERO
	if dist > 0.6:
		var speed := clampf(dist * 1.6, 0.0, Leader.SPRINT * 1.05)
		move = to.normalized() * speed
	apply_locomotion(move, delta)


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
