class_name Clothes
extends RefCounted
## Dresses the mannequin in cloth rather than paint. The mannequin is a
## sculpted, muscled figure, and painting a coat on it gave every man a
## superhero's bodysuit: pectorals, abdominals and thigh muscles showing
## through the wool. Here the mesh itself is changed, in its rest pose, so the
## same skeleton and animations still drive it:
##
## - where clothing covers the body the surface is smoothed (Taubin, which
##   does not shrink it) and let out a little, so it hangs as cloth;
## - a skirt is added from the waist to the thigh (a hunting frock, or a coat's
##   open-fronted skirts), skinned between the hips and the thighs so it swings
##   with the walk without splitting into trouser legs;
## - every vertex carries its rest position in CUSTOM0 (w = 1 on the skirt),
##   so outfit.gdshader can paint a face, a hairline and the skirt in body
##   space whatever pose the skeleton is in.
##
## One dressed mesh per cut, shared by everyone who wears it.

## Bones (Universal Animation Library skeleton; see the indices in
## outfit.gdshader) and how much each is covered, and let out.
const HIPS := 1
const THIGH_L := 45
const THIGH_R := 49
const COVER := {
	1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.45,       # hips, spine, neck (the collar)
	7: 1.0, 8: 1.0, 9: 0.8, 26: 1.0, 27: 1.0, 28: 0.8,  # shoulders, upper arms, forearms
	45: 1.0, 49: 1.0,                               # thighs: breeches
	46: 0.6, 50: 0.6,                               # shins: leggings, closer fitting
}
const LET_OUT := {1: 0.016, 2: 0.018, 3: 0.018, 4: 0.014, 5: 0.004, 7: 0.004, 8: 0.006, 9: 0.006,
	26: 0.004, 27: 0.006, 28: 0.006, 45: 0.012, 49: 0.012, 46: 0.006, 50: 0.006}

## Cuts: how far the skirt hangs (y in the rest pose; the knee is at 0.53) and
## whether it is open down the front.
const CUTS := {
	"frock": {"hem": 0.62, "open": 0.0},     # a hunting shirt, belted, to mid-thigh
	"coat": {"hem": 0.56, "open": 0.42},     # an officer's coat, skirts open in front
	"shirt": {"hem": 0.80, "open": 0.0},     # a shirt worn out over the breeches
}

static var _dressed := {}


static func dress(src: ArrayMesh, cut: String) -> ArrayMesh:
	var key := "%d|%s" % [src.get_instance_id(), cut]
	if not _dressed.has(key):
		_dressed[key] = _build(src, CUTS.get(cut, CUTS["frock"]))
	return _dressed[key]


static func _build(src: ArrayMesh, spec: Dictionary) -> ArrayMesh:
	var surfaces: Array = []
	for s in src.get_surface_count():
		surfaces.append(src.surface_get_arrays(s))
	# Weld the surfaces into one set of points: the mesh is split along its UV
	# seams and into two surfaces, and smoothing each piece apart opens gaps.
	var weld := {}
	var pos: Array[Vector3] = []
	var cover: Array[float] = []
	var out_by: Array[float] = []
	var ids: Array = []
	for a in surfaces:
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var sid := PackedInt32Array()
		sid.resize(V.size())
		for i in V.size():
			var k := Vector3i((V[i] * 10000.0).round())
			if not weld.has(k):
				weld[k] = pos.size()
				pos.append(V[i])
				var c := 0.0
				var o := 0.0
				for j in 4:
					var b := B[i * 4 + j]
					var w := W[i * 4 + j]
					c += w * float(COVER.get(b, 0.0))
					o += w * float(LET_OUT.get(b, 0.0))
				cover.append(c)
				out_by.append(o)
			sid[i] = weld[k]
		ids.append(sid)
	var n := pos.size()
	var nbrs: Array = []
	nbrs.resize(n)
	for i in n:
		nbrs[i] = {}
	for si in surfaces.size():
		var I: PackedInt32Array = surfaces[si][Mesh.ARRAY_INDEX]
		var sid: PackedInt32Array = ids[si]
		for t in range(0, I.size(), 3):
			var a := sid[I[t]]
			var b := sid[I[t + 1]]
			var c := sid[I[t + 2]]
			nbrs[a][b] = true; nbrs[a][c] = true
			nbrs[b][a] = true; nbrs[b][c] = true
			nbrs[c][a] = true; nbrs[c][b] = true
	# Taubin smoothing: a shrinking step and an inflating one, alternately, so
	# the muscles go and the volume stays.
	for it in 16:
		var lam := 0.5 if it % 2 == 0 else -0.53
		var nxt := pos.duplicate()
		for i in n:
			if cover[i] <= 0.0 or nbrs[i].is_empty():
				continue
			var avg := Vector3.ZERO
			for j in nbrs[i]:
				avg += pos[j]
			avg /= float(nbrs[i].size())
			nxt[i] = pos[i] + (avg - pos[i]) * lam * cover[i]
		pos = nxt
	# Normals of the smoothed surface, then let the cloth out along them.
	var nrm: Array[Vector3] = []
	nrm.resize(n)
	nrm.fill(Vector3.ZERO)
	for si in surfaces.size():
		var I: PackedInt32Array = surfaces[si][Mesh.ARRAY_INDEX]
		var sid: PackedInt32Array = ids[si]
		for t in range(0, I.size(), 3):
			var a := sid[I[t]]
			var b := sid[I[t + 1]]
			var c := sid[I[t + 2]]
			var f := (pos[b] - pos[a]).cross(pos[c] - pos[a])
			nrm[a] += f; nrm[b] += f; nrm[c] += f
	for i in n:
		nrm[i] = nrm[i].normalized() if nrm[i].length() > 1e-9 else Vector3.UP
		pos[i] += nrm[i] * out_by[i]

	var out := ArrayMesh.new()
	var fmt_custom := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for si in surfaces.size():
		var a: Array = surfaces[si].duplicate()
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var sid: PackedInt32Array = ids[si]
		var rest := PackedFloat32Array()
		rest.resize(V.size() * 4)
		for i in V.size():
			rest[i * 4] = V[i].x
			rest[i * 4 + 1] = V[i].y
			rest[i * 4 + 2] = V[i].z
			rest[i * 4 + 3] = 0.0
			var c := cover[sid[i]]
			if c > 0.0:
				V[i] = pos[sid[i]]
				N[i] = N[i].lerp(nrm[sid[i]], minf(c, 1.0)).normalized()
		a[Mesh.ARRAY_VERTEX] = V
		a[Mesh.ARRAY_NORMAL] = N
		a[Mesh.ARRAY_TANGENT] = null
		a[Mesh.ARRAY_CUSTOM0] = rest
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, fmt_custom)
	_add_skirt(out, spec, fmt_custom)
	return out


static func _add_skirt(out: ArrayMesh, spec: Dictionary, fmt: int) -> void:
	## A skirt from the waist to the hem: a flared ring, its top on the hips and
	## its lower rows shared between the hips and whichever thigh they hang
	## over, so it swings with the stride but stays one piece of cloth.
	var seg := 28
	var rows := 5
	var top := 0.98
	var hem := float(spec["hem"])
	var open := float(spec["open"])   # radians each side of the front left open
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var rest := PackedFloat32Array()
	var idx := PackedInt32Array()
	for r in rows + 1:
		var t := float(r) / rows
		var y := lerpf(top, hem, t)
		# The waist is narrow and the skirt flares over the seat and thighs.
		var rx := lerpf(0.165, 0.215, t)
		var rz := lerpf(0.135, 0.17, t)
		for k in seg + 1:
			var ang := TAU * float(k) / seg      # 0 at the front (+Z)
			var p := Vector3(sin(ang) * rx, y, cos(ang) * rz - 0.02)
			verts.append(p)
			norms.append(Vector3(sin(ang) / rx, 0.0, cos(ang) / rz).normalized())
			uvs.append(Vector2(float(k) / seg * 3.0, t))
			var side := smoothstep(-0.06, 0.06, p.x)   # 1 over the left thigh
			# The front rides on the thigh more than the back: a stride lifts the
			# knee into the cloth, and with too little of the thigh's swing the
			# leg came through it.
			var hang := t * lerpf(0.55, 0.92, smoothstep(-0.3, 0.8, cos(ang)))
			bones.append_array(PackedInt32Array([HIPS, THIGH_L, THIGH_R, 0]))
			weights.append_array(PackedFloat32Array([1.0 - hang, hang * side, hang * (1.0 - side), 0.0]))
			rest.append_array(PackedFloat32Array([p.x, p.y, p.z, 1.0]))
	for r in rows:
		for k in seg:
			var mid := TAU * (float(k) + 0.5) / seg
			var from_front := absf(wrapf(mid, -PI, PI))
			if from_front < open:
				continue
			var a := r * (seg + 1) + k
			var b := a + 1
			var c := a + seg + 1
			var d := c + 1
			idx.append_array(PackedInt32Array([a, c, b, b, c, d]))
	# Both faces: the inside of a skirt shows when it swings, and at the open front.
	var inner := idx.size()
	var base := verts.size()
	for i in base:
		verts.append(verts[i])
		norms.append(-norms[i])
		uvs.append(uvs[i])
		rest.append_array(rest.slice(i * 4, i * 4 + 4))
	bones.append_array(bones.duplicate())
	weights.append_array(weights.duplicate())
	for i in range(0, inner, 3):
		idx.append_array(PackedInt32Array([idx[i] + base, idx[i + 2] + base, idx[i + 1] + base]))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_BONES] = bones
	a[Mesh.ARRAY_WEIGHTS] = weights
	a[Mesh.ARRAY_CUSTOM0] = rest
	a[Mesh.ARRAY_INDEX] = idx
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, fmt)
