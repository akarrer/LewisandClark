class_name Hats
extends RefCounted
## Felt hats of the period, built as a lathe: a crown a little domed on top
## with a band round its foot, and a brim whose tilt varies round the hat --
## slouched down front and back, cocked up at the sides, or turned up hard
## before and behind into an officer's cocked hat. Each man's is his own
## (crown height, brim width, how it has been worn into shape).
##
## Built in the head bone's space: +Y up, +Z the way the face looks.

const SEG := 32
const FELT := Color(0.12, 0.10, 0.09)
const BAND := Color(0.06, 0.05, 0.05)

static var _built := {}


static func style_for(key: String, cocked: bool) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key) + 77
	if cocked:
		return {"crown": 0.10, "top": 0.088, "brim": 0.11, "tilt": 0.55, "curl": -0.45, "slouch": 0.0, "dent": 0.0}
	return {
		"crown": r.randf_range(0.10, 0.145),     # height of the crown
		"top": r.randf_range(0.084, 0.102),      # radius across its top
		"brim": r.randf_range(0.055, 0.085),     # width of the brim
		"tilt": r.randf_range(-0.12, 0.05),      # the brim's lie overall (+ up)
		"curl": r.randf_range(-0.05, 0.35),      # sides up (+) as against front and back
		"slouch": r.randf_range(0.0, 0.3),       # the front pulled down over the eyes
		"dent": r.randf_range(0.0, 0.012),       # a crease down the top of the crown
	}


static func build(style: Dictionary) -> ArrayMesh:
	var key := str(style)
	if _built.has(key):
		return _built[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_y := 0.19            # where the hat sits on the head, above the head bone
	var rx := 0.104               # the opening: the head is narrower side to side
	var rz := 0.122
	var crown := float(style["crown"])
	var top := float(style["top"])
	# Crown rings, foot to top: the band, the sides, the rounded shoulder, the top.
	var rings := [[1.0, 0.0, BAND], [1.0, 0.022, BAND], [0.99, 0.024, FELT], [lerpf(1.0, top / rx, 0.8), crown * 0.85, FELT],
			[top / rx * 0.92, crown * 0.98, FELT], [top / rx * 0.55, crown, FELT], [0.0, crown, FELT]]
	var pts: Array = []
	for ring in rings:
		var row: Array = []
		for k in SEG + 1:
			var a := TAU * k / SEG
			var s: float = ring[0]
			var y: float = base_y + float(ring[1])
			# The crease: the top pushed in along the front-to-back line.
			if ring[1] > crown * 0.9:
				y -= float(style["dent"]) * pow(absf(cos(a)), 4.0) * (1.0 - s)
			row.append([Vector3(sin(a) * rx * s, y, cos(a) * rz * s), ring[2]])
		pts.append(row)
	for i in pts.size() - 1:
		for k in SEG:
			_quad(st, pts[i][k], pts[i + 1][k], pts[i + 1][k + 1], pts[i][k + 1])
	# The brim: out from the foot of the crown, tilted by angle round the hat.
	var brim := float(style["brim"])
	var outer: Array = []
	var inner: Array = []
	for k in SEG + 1:
		var a := TAU * k / SEG                 # 0 at the front
		var dir := Vector3(sin(a), 0.0, cos(a))
		var foot := Vector3(sin(a) * rx, base_y, cos(a) * rz)
		var tilt := float(style["tilt"]) + float(style["curl"]) * -cos(2.0 * a) - float(style["slouch"]) * maxf(cos(a), 0.0)
		# A cocked hat's brim stands nearly upright fore and aft.
		var up := clampf(tilt, -0.6, 1.35)
		var w := brim * (1.0 + 0.25 * absf(cos(a)))   # longer fore and aft than at the sides
		var edge := foot + (dir * cos(up) + Vector3.UP * sin(up)) * w
		inner.append([foot, FELT])
		outer.append([edge, FELT])
	for k in SEG:
		_quad(st, inner[k], outer[k], outer[k + 1], inner[k + 1])
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true   # or the black felt comes out a pale grey
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # the brim is one sheet, seen from both sides
	mesh.surface_set_material(0, m)
	_built[key] = mesh
	return mesh


static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(v[1])
		st.add_vertex(v[0])
