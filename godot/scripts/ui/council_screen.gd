class_name CouncilScreen
extends CanvasLayer
## The council, drawn: who is sitting, what the captains may do and the chance of
## each, and what is laid out on the ground from the Stores. Nothing is decided
## here — Council does that (scripts/rules/council.gd).

const PARCHMENT := Color(0.94, 0.90, 0.80)
const DIM := Color(0.78, 0.74, 0.64)
const GOLD := Color(0.90, 0.80, 0.55)

signal closed(standing: int, verdict: String, lines: Array)

var council: Council
var open := false

var _steps_box: VBoxContainer
var _offer_box: VBoxContainer
var _seats_box: VBoxContainer
var _standing: Label
var _last: Label
var _rng := RandomNumberGenerator.new()


func build() -> void:
	name = "CouncilScreen"
	layer = 3
	visible = false
	_rng.randomize()

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.02, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -700
	panel.offset_right = 700
	panel.offset_top = -400
	panel.offset_bottom = 400
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.09, 0.97)
	style.border_color = Color(0.48, 0.38, 0.25)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	shade.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	_last = _label(rows, 24, PARCHMENT)
	_last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(cols)

	_seats_box = VBoxContainer.new()
	_seats_box.custom_minimum_size = Vector2(300, 0)
	cols.add_child(_seats_box)

	var mid := ScrollContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size = Vector2(640, 520)
	cols.add_child(mid)
	_steps_box = VBoxContainer.new()
	_steps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_box.add_theme_constant_override("separation", 14)
	mid.add_child(_steps_box)

	var right := ScrollContainer.new()
	right.custom_minimum_size = Vector2(330, 520)
	cols.add_child(right)
	_offer_box = VBoxContainer.new()
	_offer_box.add_theme_constant_override("separation", 4)
	right.add_child(_offer_box)

	_standing = _label(rows, 17, GOLD)


func begin(p_council: Council) -> void:
	council = p_council
	open = true
	visible = true
	_last.text = council.opening
	_refresh()


func _refresh() -> void:
	_fill_seats()
	_fill_steps()
	_fill_offer()
	var left := council.remaining().size()
	_standing.text = "Their regard for the Corps: %d        %s" % [council.standing,
			council.verdict() if left == 0 else "%d matters still before the council" % left]


func _fill_seats() -> void:
	for c in _seats_box.get_children():
		c.queue_free()
	var head := _label(_seats_box, 22, PARCHMENT)
	head.text = "%s\n%s" % [council.nation, council.date]
	var sub := _label(_seats_box, 15, DIM)
	sub.text = "Interpreted by %s\n" % council.interpreter if council.interpreter_present \
			else "No interpreter at hand\n"
	for seat in council.seats:
		var l := _label(_seats_box, 16, PARCHMENT if seat.get("present", false) else Color(0.62, 0.58, 0.50))
		l.text = "%s — %s chief of the %s%s" % [seat.get("name", ""), seat.get("rank", ""),
				seat.get("people", ""), "" if seat.get("present", false) else "  (away)"]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(290, 0)


func _fill_steps() -> void:
	for c in _steps_box.get_children():
		c.queue_free()
	for s in council.steps:
		var step_id := str(s.get("id", ""))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		_steps_box.add_child(box)
		var title := _label(box, 19, GOLD if not council.done(step_id) else DIM)
		title.text = str(s.get("name", ""))
		var body := _label(box, 15, DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(600, 0)
		body.text = str(s.get("text", ""))
		if council.done(step_id):
			continue
		var wants: Dictionary = s.get("wants", {})
		if not wants.is_empty():
			var asked := PackedStringArray()
			for item_id in wants:
				var n := int(wants[item_id])
				var laid := int(council.offered.get(item_id, 0))
				asked.append("%d %s%s" % [n, _name_of(item_id),
						"" if laid < n else "  (laid out)"])
			var want_label := _label(box, 14, Color(0.80, 0.72, 0.86))
			want_label.text = "Looked for: " + ", ".join(asked)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 10)
		box.add_child(buttons)
		var take := Button.new()
		take.text = "Take it  (%d in a hundred)" % roundi(council.odds(step_id) * 100.0)
		take.pressed.connect(func(): _take(step_id))
		buttons.add_child(take)
		var pass_by := Button.new()
		pass_by.text = "Pass it by"
		pass_by.pressed.connect(func(): _pass(step_id))
		buttons.add_child(pass_by)


func _fill_offer() -> void:
	for c in _offer_box.get_children():
		c.queue_free()
	var head := _label(_offer_box, 18, PARCHMENT)
	head.text = "Laid out on the ground"
	var regard := _label(_offer_box, 15, Color(0.80, 0.72, 0.86))
	regard.text = "Worth %d in their regard\n" % council.offered_regard()
	# What is already laid out comes to the top, so the offer reads at a glance.
	var presents := council.stores.in_category("Presents").duplicate()
	presents.sort_custom(func(a, b):
		var offered_a := int(council.offered.get(str(a["id"]), 0))
		var offered_b := int(council.offered.get(str(b["id"]), 0))
		if offered_a != offered_b:
			return offered_a > offered_b
		return council.stores.regard_of(str(a["id"])) > council.stores.regard_of(str(b["id"])))
	for it in presents:
		var item_id := str(it["id"])
		if council.stores.count(item_id) <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_offer_box.add_child(row)
		var name_label := _label(row, 14, PARCHMENT)
		name_label.text = str(it.get("name", item_id))
		name_label.custom_minimum_size = Vector2(170, 0)
		var offered := int(council.offered.get(item_id, 0))
		var count := _label(row, 14, GOLD if offered > 0 else DIM)
		count.text = "%d / %d" % [offered, council.stores.count(item_id)]
		count.custom_minimum_size = Vector2(70, 0)
		var less := Button.new()
		less.text = "−"
		less.pressed.connect(func(): _offer(item_id, -1))
		row.add_child(less)
		var more := Button.new()
		more.text = "+"
		more.pressed.connect(func(): _offer(item_id, 1))
		row.add_child(more)


func _offer(item_id: String, delta: int) -> void:
	if delta > 0:
		council.offer(item_id, delta)
	else:
		var had := int(council.offered.get(item_id, 0))
		if had > 0:
			council.offered[item_id] = had - 1
			if council.offered[item_id] <= 0:
				council.offered.erase(item_id)
	_refresh()


func _take(step_id: String) -> void:
	var outcome := council.resolve(step_id, _rng.randf())
	_last.text = str(outcome["text"])
	_after()


func _pass(step_id: String) -> void:
	var outcome := council.refuse(step_id)
	_last.text = str(outcome["text"])
	_after()


func _after() -> void:
	_refresh()
	if council.remaining().is_empty():
		_last.text += "\n\n" + council.verdict()
		var close := Button.new()
		close.text = "Break up the council"
		close.pressed.connect(_close)
		_steps_box.add_child(close)


func _close() -> void:
	open = false
	visible = false
	closed.emit(council.standing, council.verdict(), council.log_lines())


func _name_of(item_id: String) -> String:
	## Proper names keep their capitals: Jefferson peace medals, United States flags.
	return str(council.stores.find(item_id).get("name", item_id))


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
