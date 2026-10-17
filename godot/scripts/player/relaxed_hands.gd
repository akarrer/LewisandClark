class_name RelaxedHands
extends SkeletonModifier3D
## The animation library holds every hand clenched in a fist, walking or
## standing, so the whole Corps marched with balled fists like boxers. After
## the animation has posed the skeleton, each finger and thumb bone is eased
## back toward its rest pose (the hand flat), leaving a loose half-curl.

## How far back toward the open hand: 0 keeps the fist, 1 opens it flat.
@export var open := 0.6

var _fingers: PackedInt32Array = []
var _rest: Array[Quaternion] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("DEF-f_") or n.begins_with("DEF-thumb"):
			_fingers.append(i)
			_rest.append(sk.get_bone_rest(i).basis.get_rotation_quaternion())


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for k in _fingers.size():
		var i := _fingers[k]
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(_rest[k], open))
