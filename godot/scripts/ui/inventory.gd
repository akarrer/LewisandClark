class_name InventoryScreen
extends CanvasLayer
## The Stores, laid out the way a quartermaster would want them: each boat and
## the packs with what she carries and how deep she sits, the goods grouped by
## kind, and for the things the record actually names, what the record says.

const HOLD_NAMES := {
	"keelboat": "Keelboat",
	"red_pirogue": "Red pirogue",
	"white_pirogue": "White pirogue",
	"packs": "Packs ashore",
}
const PARCHMENT := Color(0.94, 0.90, 0.80)
const INK := Color(0.10, 0.09, 0.08)

var stores: Stores
var open := false

var _hold := "keelboat"
var _rows: VBoxContainer
var _hold_box: VBoxContainer
var _title: Label
var _summary: Label
var _note: Label


func build(p_stores: Stores) -> void:
	name = "Inventory"
	stores = p_stores
	layer = 2
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.02, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -640
	panel.offset_right = 640
	panel.offset_top = -380
	panel.offset_bottom = 380
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.10, 0.96)
	style.border_color = Color(0.45, 0.36, 0.24)
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	shade.add_child(panel)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	panel.add_child(cols)

	# Left: the holds, each with how deep she is loaded.
	_hold_box = VBoxContainer.new()
	_hold_box.custom_minimum_size = Vector2(330, 0)
	_hold_box.add_theme_constant_override("separation", 10)
	cols.add_child(_hold_box)

	# Right: the goods in the chosen hold.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)

	_title = _label(right, 26, PARCHMENT)
	_summary = _label(right, 16, Color(0.80, 0.76, 0.66))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 560)
	right.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_rows)

	_note = _label(right, 15, Color(0.74, 0.70, 0.60))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 46)

	_build_holds()
	_fill()


func toggle() -> void:
	open = not open
	visible = open
	if open:
		_build_holds()
		_fill()


func _build_holds() -> void:
	for c in _hold_box.get_children():
		c.queue_free()
	var heading := _label(_hold_box, 26, PARCHMENT)
	heading.text = "Stores of the Corps"
	for hold in Stores.HOLDS:
		var button := Button.new()
		button.text = "%s\n%s lb  of  %s" % [HOLD_NAMES.get(hold, hold),
				_commas(stores.weight(hold)), _commas(float(stores.capacity.get(hold, 0.0)))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 62)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", PARCHMENT if hold == _hold else Color(0.72, 0.68, 0.58))
		button.pressed.connect(func(): _hold = hold; _build_holds(); _fill())
		_hold_box.add_child(button)

		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = clampf(stores.load_of(hold), 0.0, 1.0)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.78, 0.36, 0.22) if stores.load_of(hold) > 1.0 else Color(0.55, 0.62, 0.36)
		bar.add_theme_stylebox_override("fill", fill)
		_hold_box.add_child(bar)

	var totals := _label(_hold_box, 16, Color(0.84, 0.80, 0.70))
	totals.text = "\nAll told  %s lb\nWhat the presents would stand for\nin the regard of a Nation:  %d" % [
			_commas(stores.total_weight()), stores.gift_regard()]


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_title.text = HOLD_NAMES.get(_hold, _hold)
	var carried := stores.in_hold(_hold)
	_summary.text = "%d kinds of goods  ·  %s lb  ·  %d%% of her burden" % [
			carried.size(), _commas(stores.weight(_hold)), roundi(stores.load_of(_hold) * 100.0)]
	for category in stores.categories():
		var of_kind := carried.filter(func(it): return it.get("category", "") == category)
		if of_kind.is_empty():
			continue
		var head := _label(_rows, 18, Color(0.90, 0.80, 0.55))
		head.text = "\n" + category
		for it in of_kind:
			_rows.add_child(_row(it))


func _row(it: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var qty := int(floor(float(it["qty"])))
	var name_label := _label(line, 16, PARCHMENT)
	name_label.text = "%s" % it.get("name", it["id"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := _label(line, 16, Color(0.86, 0.84, 0.76))
	count.text = "%d %s" % [qty, _plural(str(it.get("unit", "")), qty)]
	count.custom_minimum_size = Vector2(190, 0)
	var weighs := _label(line, 16, Color(0.76, 0.74, 0.66))
	weighs.text = "%s lb" % _commas(float(it["qty"]) * float(it.get("lb", 0.0)))
	weighs.custom_minimum_size = Vector2(110, 0)
	weighs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if it.get("regard", 0) > 0:
		var regard := _label(line, 15, Color(0.78, 0.70, 0.86))
		regard.text = "regard %d" % int(it["regard"])
		regard.custom_minimum_size = Vector2(110, 0)
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 26)
	button.mouse_entered.connect(func(): _show_note(it))
	button.pressed.connect(func(): _show_note(it))
	button.add_child(line)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	return button


func _show_note(it: Dictionary) -> void:
	var note := str(it.get("note", ""))
	if note.is_empty():
		note = "Carried against the want of it."
	_note.text = ("Recorded in the purchases.  " if it.get("recorded", false) else "") + note


static func _plural(unit: String, n: int) -> String:
	if unit.is_empty() or n == 1:
		return unit
	if unit.ends_with("s") or unit.ends_with("x"):
		return unit + "es"
	return unit + "s"


static func _commas(v: float) -> String:
	var whole := str(roundi(v))
	var out := ""
	var count := 0
	for i in range(whole.length() - 1, -1, -1):
		out = whole[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
