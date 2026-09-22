class_name MorningReportScreen
extends CanvasLayer
## The sergeants' Morning Report, drawn: each Mess spoken for by its sergeant,
## Ordway on the stores, and the day's orders -- a duty for each of the three
## Messes, and the calls the captain may make on a sick man. Nothing is decided
## here; Corps does that (scripts/rules/corps.gd).

const PARCHMENT := Color(0.94, 0.90, 0.80)
const DIM := Color(0.78, 0.74, 0.64)
const GOLD := Color(0.90, 0.80, 0.55)
const SICK := Color(0.92, 0.66, 0.52)

## Journal lines from the calls made (a man dosed, a man excused).
signal closed(lines: Array)

var corps: Corps
var stores: Stores
var date := ""
var open := false

var _title: Label
var _strength: Label
var _messes_box: VBoxContainer
var _stores_box: VBoxContainer
var _lines: Array = []


func build() -> void:
	name = "MorningReport"
	layer = 3
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.02, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -700
	panel.offset_right = 700
	panel.offset_top = -420
	panel.offset_bottom = 420
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
	_title = _label(rows, 26, PARCHMENT)
	_strength = _label(rows, 18, GOLD)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(cols)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(880, 640)
	cols.add_child(left)
	_messes_box = VBoxContainer.new()
	_messes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messes_box.add_theme_constant_override("separation", 6)
	left.add_child(_messes_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_label(right, 19, GOLD).text = "Sergeant Ordway, on the stores"
	_stores_box = VBoxContainer.new()
	_stores_box.add_theme_constant_override("separation", 4)
	right.add_child(_stores_box)

	var dismiss := Button.new()
	dismiss.text = "Dismiss the sergeants"
	dismiss.add_theme_font_size_override("font_size", 19)
	dismiss.pressed.connect(close)
	rows.add_child(dismiss)


func begin(p_corps: Corps, p_stores: Stores, p_date: String) -> void:
	corps = p_corps
	stores = p_stores
	date = p_date
	_lines = []
	open = true
	visible = true
	_refresh()


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	closed.emit(_lines)


func _refresh() -> void:
	var r := corps.morning_report(stores)
	_title.text = "Morning Report  ·  %s" % date
	_strength.text = "%d fit for duty of %d in camp, %d on the roll" % [r["fit"], r["present"], r["on_roll"]]
	for c in _messes_box.get_children():
		c.queue_free()
	for ms in r["messes"]:
		var head := _label(_messes_box, 19, GOLD)
		head.text = "%s  —  %s" % [ms["name"], ms["speaker"]]
		for line in ms["lines"]:
			var l := _label(_messes_box, 16, DIM)
			l.text = "    " + str(line)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if ms["commanded"]:
			_duty_row(str(ms["id"]), str(ms["duty"]))
		for call in r["calls"]:
			if call["mess"] == ms["id"]:
				_call_row(call)
		_messes_box.add_child(HSeparator.new())
	for c in _stores_box.get_children():
		c.queue_free()
	for line in r["stores"]:
		var l := _label(_stores_box, 16, PARCHMENT)
		l.text = str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)


func _duty_row(mess_id: String, current: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_messes_box.add_child(row)
	var lead := _label(row, 16, PARCHMENT)
	lead.text = "    Today:"
	for duty in Corps.CAMP_DUTIES:
		var b := Button.new()
		b.text = str(corps.duty_defs[duty]["name"])
		b.tooltip_text = str(corps.duty_defs[duty]["hint"])
		b.toggle_mode = true
		b.button_pressed = duty == current
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			corps.set_duty(mess_id, duty)
			_refresh())
		row.add_child(b)


func _call_row(call: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_messes_box.add_child(row)
	var who := _label(row, 15, SICK)
	who.text = "    %s:" % call["name"]
	var ex := Button.new()
	ex.text = "Excused from duty" if call["excused"] else "Excuse from duty"
	ex.toggle_mode = true
	ex.button_pressed = call["excused"]
	ex.add_theme_font_size_override("font_size", 14)
	ex.pressed.connect(func():
		corps.excuse(str(call["man"]), not corps.excused.has(call["man"]))
		_refresh())
	row.add_child(ex)
	if call["treat"] != "":
		var doc := Button.new()
		doc.text = "Physic (%s)" % str(stores.find(str(call["treat_item"])).get("name", call["treat_item"]))
		doc.disabled = not call["can_treat"]
		doc.add_theme_font_size_override("font_size", 14)
		doc.pressed.connect(func():
			var said := corps.treat(str(call["man"]), stores)
			if said != "":
				_lines.append(said)
			_refresh())
		row.add_child(doc)


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
