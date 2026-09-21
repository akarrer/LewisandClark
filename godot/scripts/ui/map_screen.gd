class_name MapScreen
extends CanvasLayer
## The map, as Clark kept it: a sketch in ink of the ground the Corps has
## actually covered, filled in as they go. Clark was the expedition's mapmaker
## and drew the river a day's reach at a time, so what is not yet walked is
## blank paper.
##
## Opened and closed with the map key (M / Tab, View on a pad). North is up.

const SHEET := 800.0          # the map's size on screen, in pixels
const BASE_RES := 256         # pixels of drawn map across the kilometre
const SEEN_RES := 128         # cells of "known ground" across it
const SIGHT := 150.0          # metres around the Leader that go onto the map
const STEP := 6.0             # metres between points of the route line

const PAPER := Color(0.93, 0.88, 0.76)
const INK := Color(0.16, 0.12, 0.08)
const ROUTE := Color(0.55, 0.16, 0.10)

## What the named places are called on the sheet, in Clark's manner.
const NAMES := {
	"council_bluff": "Council Bluff",
	"start": "Landing",
	"camp": "Camp",
	"prairie_dog_town": "Barking squirrels",
	"smoke_ridge": "Smoke seen",
}

var terrain: Terrain
var watch: Leader
var open := false

var _seen: Image
var _seen_tex: ImageTexture
var _map: TextureRect
var _route: Line2D
var _marker: Polygon2D
var _labels := {}
var _last := Vector3.INF
var _date: Label


func build(p_terrain: Terrain, p_watch: Leader) -> void:
	name = "Map"
	terrain = p_terrain
	watch = p_watch
	layer = 2
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.02, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var sheet := Control.new()
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.offset_left = -SHEET / 2.0 - 30.0
	sheet.offset_right = SHEET / 2.0 + 30.0
	sheet.offset_top = -SHEET / 2.0 - 70.0
	sheet.offset_bottom = SHEET / 2.0 + 40.0
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(paper)

	var title := _label(sheet, 26, INK)
	title.text = "A Sketch of the Missouri at the Council Bluff"
	title.position = Vector2(30, 14)
	_date = _label(sheet, 16, INK.lightened(0.25))
	_date.position = Vector2(32, 46)

	_map = TextureRect.new()
	_map.texture = ImageTexture.create_from_image(_draw_base())
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_map.position = Vector2(30, 70)
	_map.size = Vector2(SHEET, SHEET)
	_seen = Image.create(SEEN_RES, SEEN_RES, false, Image.FORMAT_R8)
	_seen_tex = ImageTexture.create_from_image(_seen)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ui/map.gdshader")
	mat.set_shader_parameter("seen_tex", _seen_tex)
	mat.set_shader_parameter("paper", PAPER)
	_map.material = mat
	sheet.add_child(_map)

	# The way the Corps has come, in red ink, which is how Clark marked a route.
	_route = Line2D.new()
	_route.width = 2.2
	_route.default_color = ROUTE
	_route.joint_mode = Line2D.LINE_JOINT_ROUND
	_map.add_child(_route)

	for key in NAMES:
		if not terrain.points.has(key):
			continue
		var l := _label(_map, 15, INK)
		l.text = NAMES[key]
		var p := _to_map(terrain.points[key])
		# The landing and the camp are a few yards apart; set their names
		# either side of the point so they do not print over one another.
		l.position = p + (Vector2(7, 2) if key == "camp" else Vector2(7, -20) if key == "start" else Vector2(7, -9))
		l.visible = false
		var dot := ColorRect.new()
		dot.color = INK
		dot.size = Vector2(5, 5)
		dot.position = p - Vector2(2.5, 2.5)
		dot.visible = false
		_map.add_child(dot)
		_labels[key] = [l, dot]

	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(0, -11), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)])
	_marker.color = ROUTE.darkened(0.2)
	_map.add_child(_marker)

	# A north point and a scale, as every sheet of his has.
	var north := Polygon2D.new()
	north.polygon = PackedVector2Array([Vector2(0, -22), Vector2(8, 6), Vector2(0, 0), Vector2(-8, 6)])
	north.color = INK
	north.position = Vector2(SHEET - 34, 44)
	_map.add_child(north)
	var n := _label(_map, 16, INK)
	n.text = "N"
	n.position = Vector2(SHEET - 40, 52)
	var quarter_mile := 402.0 / Terrain.SIZE * SHEET
	var bar := Line2D.new()
	bar.points = PackedVector2Array([Vector2(24, SHEET - 26), Vector2(24 + quarter_mile, SHEET - 26)])
	bar.width = 3.0
	bar.default_color = INK
	_map.add_child(bar)
	var sl := _label(_map, 14, INK)
	sl.text = "¼ mile"
	sl.position = Vector2(24, SHEET - 50)

	note(terrain.points.get("start", Vector3(Terrain.SIZE / 2.0, 0, Terrain.SIZE / 2.0)))


func toggle() -> void:
	open = not open
	visible = open
	if open:
		_refresh()


func set_date(text: String) -> void:
	_date.text = text


func note(pos: Vector3) -> void:
	## Put the ground around ``pos`` onto the map, and extend the route to it.
	if _last != Vector3.INF and Vector2(pos.x - _last.x, pos.z - _last.z).length() < STEP:
		return
	_last = pos
	_route.add_point(_to_map(pos))
	var cell := Terrain.SIZE / SEEN_RES
	var cx := int(pos.x / cell)
	var cz := int(pos.z / cell)
	# From high ground you see a great deal more of the country, which is why
	# the captains climbed every bluff they could: up to three and a half times
	# as far from the top of the Council Bluff as from the bottomland.
	var above := pos.y - float(terrain.meta.get("floodplain_y", 0.0))
	var sight := SIGHT * (1.0 + clampf(above / 12.0, 0.0, 2.5))
	var r := int(ceil(sight / cell))
	for j in range(maxi(cz - r, 0), mini(cz + r + 1, SEEN_RES)):
		for i in range(maxi(cx - r, 0), mini(cx + r + 1, SEEN_RES)):
			var d := Vector2((i + 0.5) * cell - pos.x, (j + 0.5) * cell - pos.z).length()
			if d > sight:
				continue
			var v := 1.0 - smoothstep(sight * 0.6, sight, d)
			var had := _seen.get_pixel(i, j).r
			if v > had:
				_seen.set_pixel(i, j, Color(v, 0, 0))
	if open:
		_refresh()


func _process(_delta: float) -> void:
	if not open or watch == null:
		return
	_marker.position = _to_map(watch.global_position)
	var f := watch.camera_forward()
	_marker.rotation = atan2(f.x, -f.z)


func _refresh() -> void:
	_seen_tex.update(_seen)
	var cell := Terrain.SIZE / SEEN_RES
	for key in _labels:
		var p: Vector3 = terrain.points[key]
		var i := clampi(int(p.x / cell), 0, SEEN_RES - 1)
		var j := clampi(int(p.z / cell), 0, SEEN_RES - 1)
		var known := _seen.get_pixel(i, j).r > 0.5
		for c in _labels[key]:
			(c as CanvasItem).visible = known


func _to_map(p: Vector3) -> Vector2:
	# North is up: the game's -z is north, so z runs down the sheet as it is.
	return Vector2(p.x, p.z) / Terrain.SIZE * SHEET


func _draw_base() -> Image:
	## The ground in ink: shaded from the north-west the way an engraver lights
	## relief, a line every six metres of rise for the lie of the land, the
	## river in a wash, and the bars left pale.
	var img := Image.create(BASE_RES, BASE_RES, false, Image.FORMAT_RGB8)
	var light := Vector3(-1.0, 1.4, -1.0).normalized()
	var half := terrain.river_half_width()
	var water_y := Terrain.WATER_Y - 0.35
	for j in BASE_RES:
		for i in BASE_RES:
			var x := (i + 0.5) / BASE_RES * Terrain.SIZE
			var z := (j + 0.5) / BASE_RES * Terrain.SIZE
			var h := terrain.height_at(x, z)
			var n := terrain.normal_at(x, z)
			var shade := clampf(n.dot(light), 0.0, 1.0)
			var c := PAPER * lerpf(0.6, 1.06, shade)
			# Hachures: the steeper the ground, the more ink, which is how the
			# bluffs stand up off a sheet of the period.
			c = c.lerp(INK, clampf((1.0 - n.y) * 2.4, 0.0, 0.55))
			# Form lines every four metres of rise, where the ground rises at all.
			var band := absf(fposmod(h, 4.0) - 2.0)
			if band > 1.72 and h > water_y + 1.5:
				c = c.lerp(INK, 0.4)
			var in_channel := terrain.river_distance(x, z) < half + 6.0
			if h < water_y and in_channel:
				# The river: a brown-grey wash, darker toward the thread of it.
				var deep := clampf((water_y - h) / 2.5, 0.0, 1.0)
				c = Color(0.62, 0.60, 0.53).lerp(Color(0.40, 0.40, 0.36), deep)
			elif h < water_y + 0.8 and in_channel:
				c = PAPER.lightened(0.06)  # the bars, left blank as sand
			img.set_pixel(i, j, c)
	return img


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
