class_name LeafArt
extends RefCounted
## Leaf cards for the tree crowns, painted here. The kit's card is ten big,
## flat-green blobs; on a full-grown tree each came out a quarter metre across
## and the crowns read as heaps of green pebbles. These hold four times as many
## smaller leaves, on twigs, each shaded from stalk to tip with a paler midrib,
## and some turned to show their undersides -- in the leaf shape of the tree:
## a cottonwood's spade, a bur oak's deep lobes.

const SIZE := 512

const CROWNS := {
	"cottonwood": {"shape": "spade", "len": [46.0, 60.0], "half": [20.0, 27.0], "count": 58, "seed": 31,
		"light": Color(0.46, 0.56, 0.17), "dark": Color(0.27, 0.40, 0.09), "under": Color(0.58, 0.64, 0.42), "under_share": 0.14},
	"oak": {"shape": "lobed", "len": [54.0, 70.0], "half": [15.0, 19.0], "count": 50, "seed": 57,
		"light": Color(0.36, 0.48, 0.13), "dark": Color(0.19, 0.31, 0.07), "under": Color(0.50, 0.56, 0.38), "under_share": 0.12},
}

static var _cache := {}


static func crown(kind: String) -> Texture2D:
	if not _cache.has(kind):
		_cache[kind] = _paint(CROWNS[kind])
	return _cache[kind]


static func _half(shape: String, u: float, half: float) -> float:
	## Half the leaf's width ``u`` of the way from stalk (0) to tip (1).
	if shape == "lobed":
		# Oblong, widening toward the tip, cut into rounded lobes by deep sinuses.
		var outline := half * minf(u * 4.0, 1.0) * (1.0 - pow(u, 3.0)) * lerpf(0.75, 1.1, u)
		var lobes := 0.62 + 0.38 * absf(sin(u * PI * 4.5))
		return outline * lobes
	# Spade: broad and flat across the base, coming to a drawn-out point.
	return half * minf(u * 4.5, 1.0) * pow(1.0 - u, 0.85)


static func _paint(spec: Dictionary) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var light: Color = spec["light"]
	# Transparent, but leaf-coloured: the mip levels average the clear pixels
	# in too, and black ones would ring every leaf with a dark fringe.
	img.fill(Color(light.r, light.g, light.b, 0.0))
	var lr := RandomNumberGenerator.new()
	lr.seed = int(spec["seed"])
	var c := Vector2(SIZE, SIZE) * 0.5
	var twig := Color(0.30, 0.24, 0.16, 1.0)
	# Twigs from the middle of the cluster outward, leaves along and at the ends.
	var leaves: Array = []
	var twigs := 7
	for ti in twigs:
		var ang := TAU * (float(ti) + lr.randf_range(-0.3, 0.3)) / twigs
		var dir := Vector2(cos(ang), sin(ang))
		var length := lr.randf_range(0.26, 0.40) * SIZE
		var steps := int(length)
		for s in steps:
			var p := c + dir * s
			for o in [-1, 0, 1]:
				var q: Vector2 = (p + Vector2(-dir.y, dir.x) * float(o) * 0.6).round()
				img.set_pixelv(Vector2i(q), twig)
		var per := int(spec["count"]) / twigs
		for li in per:
			var t := lr.randf_range(0.25, 1.0)
			var side := -1.0 if li % 2 == 0 else 1.0
			var spread := deg_to_rad(lr.randf_range(25.0, 70.0)) * side
			var ldir := dir.rotated(spread * (1.0 - t * 0.5))
			leaves.append([c + dir * length * t, ldir])
	# The leaves, back to front, so later ones lie over the earlier.
	var shape := str(spec["shape"])
	for leaf in leaves:
		var base: Vector2 = leaf[0]
		var dir: Vector2 = leaf[1]
		var across_dir := Vector2(-dir.y, dir.x)
		var length := lr.randf_range(float(spec["len"][0]), float(spec["len"][1]))
		var half := lr.randf_range(float(spec["half"][0]), float(spec["half"][1]))
		var col: Color = spec["under"] if lr.randf() < float(spec["under_share"]) \
				else light.lerp(spec["dark"], pow(lr.randf(), 0.8))
		# Only the box the leaf can reach.
		var lo := (base - Vector2.ONE * (length + 2.0)).floor()
		var hi := (base + Vector2.ONE * (length + 2.0)).ceil()
		for y in range(maxi(int(lo.y), 0), mini(int(hi.y), SIZE)):
			for x in range(maxi(int(lo.x), 0), mini(int(hi.x), SIZE)):
				var d := Vector2(x + 0.5, y + 0.5) - base
				var along := d.dot(dir)
				if along < 0.0 or along > length:
					continue
				var u := along / length
				var across := absf(d.dot(across_dir))
				var w := _half(shape, u, half)
				if across >= w:
					continue
				# Darker at the stalk, lighter toward the tip and the edge the
				# light catches; a pale midrib down the middle.
				var shade := lerpf(0.82, 1.08, u) * (0.94 + 0.12 * (across / maxf(w, 0.01)))
				var rib := 1.0 - smoothstep(0.6, 1.4, across)
				var px := col * shade
				px = px.lerp(col.lightened(0.25), rib * 0.5 * (1.0 - u))
				img.set_pixel(x, y, Color(px.r, px.g, px.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
