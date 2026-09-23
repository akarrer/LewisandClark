class_name Walker
extends CorpsFigure
## Someone who is not of the Corps, walking a route to a place and standing there
## facing the way he is told -- the cast of a staged Scenario.

var route: Array[Vector3] = []
var pace := 1.5
## Where to look once there.
var face_toward := Vector3.INF
var _velocity := Vector3.ZERO


func arrived() -> bool:
	return route.is_empty()


func _physics_process(delta: float) -> void:
	var desired := Vector3.ZERO
	while not route.is_empty():
		var to := route[0] - global_position
		to.y = 0.0
		if to.length() > 0.8:
			desired = to.normalized() * pace
			break
		route.pop_front()
	_velocity = _velocity.move_toward(desired, 4.0 * delta)
	apply_locomotion(_velocity, delta)
	if route.is_empty() and face_toward != Vector3.INF and ground_speed() < 0.2:
		var look := face_toward - global_position
		look.y = 0.0
		if look.length() > 0.1:
			_face_dir = _face_dir.slerp(look.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
			model.look_at(model.global_position - _face_dir, Vector3.UP)
