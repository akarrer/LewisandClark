class_name ScenarioPrompt
extends CanvasLayer
## A Scenario's words and choices, over a world that keeps running. Lines play
## as subtitles; choices come up low on the screen with their odds shown and the
## reasons for them, and the Leader stands while the captain decides.
## Nothing is decided here (scripts/rules/scenario.gd).

const PARCHMENT := Color(0.94, 0.90, 0.80)
const DIM := Color(0.78, 0.74, 0.64)
const GOLD := Color(0.90, 0.80, 0.55)

signal chosen(index: int)

var hud: Hud
## The autopilot takes the first open choice itself, so a run can be watched.
var auto_choose := false
var choosing := false

var _box: VBoxContainer
var _queue: Array = []
var _then: Callable
var _line_left := 0.0
var _auto_left := 0.0


func build(p_hud: Hud) -> void:
	name = "ScenarioPrompt"
	layer = 2
	hud = p_hud
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -430
	panel.offset_right = 430
	panel.offset_top = -330
	panel.offset_bottom = -150
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.82)
	style.border_color = Color(0.48, 0.38, 0.25, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	panel.visible = false


func play(lines: Array, then: Callable) -> void:
	## Speak each line in turn, then call ``then``.
	_queue = lines.duplicate()
	_then = then
	_line_left = 0.0


func show_choices(entries: Array[Dictionary]) -> void:
	for c in _box.get_children():
		c.queue_free()
	var first: Button = null
	for e in entries:
		var b := Button.new()
		var text := str(e["label"])
		if float(e["chance"]) >= 0.0:
			text += "   —  %d%%" % roundi(float(e["chance"]) * 100.0)
		if not e["available"]:
			text += "   (%s)" % e["why_not"]
		b.text = text
		b.disabled = not e["available"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		var index := int(e["index"])
		b.pressed.connect(func(): _pick(index))
		_box.add_child(b)
		if first == null and e["available"]:
			first = b
		var small: Array[String] = []
		if str(e["note"]) != "":
			small.append(str(e["note"]))
		for r in e["reasons"]:
			small.append("%+d%%  %s" % [roundi(float(r[1]) * 100.0), r[0]])
		if not small.is_empty():
			var l := Label.new()
			l.text = "      " + "   ·   ".join(small)
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_box.add_child(l)
	(_box.get_parent() as Control).visible = true
	choosing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first != null:
		first.grab_focus.call_deferred()
	_auto_left = 2.0


func _pick(index: int) -> void:
	if not choosing:
		return
	choosing = false
	(_box.get_parent() as Control).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(index)


func _process(delta: float) -> void:
	if choosing and auto_choose:
		_auto_left -= delta
		if _auto_left <= 0.0:
			for c in _box.get_children():
				if c is Button and not c.disabled:
					c.emit_signal("pressed")
					break
	if _then.is_null():
		return
	_line_left -= delta
	if _line_left > 0.0:
		return
	if _queue.is_empty():
		var then := _then
		_then = Callable()
		then.call()
		return
	var line: Dictionary = _queue.pop_front()
	var text := str(line["text"])
	# Long enough to read, at about fifteen characters a second.
	_line_left = clampf(1.5 + text.length() / 15.0, 2.5, 8.0)
	hud.say(str(line["speaker"]), text, _line_left)
