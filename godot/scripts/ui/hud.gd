class_name Hud
extends CanvasLayer
## Region and time, the interaction prompt, spoken lines, journal toasts, FPS.

var place: Label
var when: Label
var supplies: Label
var weather: Label
var prompt: Label
var subtitle: Label
var toasts: VBoxContainer
var fps: Label
var _subtitle_left := 0.0


var glass: ColorRect


func show_spyglass(amount: float) -> void:
	## 0 with the glass down, 1 with it up. Nothing is drawn at 0.
	if glass == null:
		return
	glass.visible = amount > 0.001
	if not glass.visible:
		return
	var m: ShaderMaterial = glass.material
	m.set_shader_parameter("amount", amount)
	var size := glass.size
	m.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The spyglass field, under everything else so the Journal still reads.
	glass = ColorRect.new()
	glass.name = "Spyglass"
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://scripts/ui/spyglass.gdshader")
	glass.material = gm
	root.add_child(glass)

	place = _label(root, 30, Color(0.98, 0.94, 0.84))
	place.position = Vector2(28, 22)
	when = _label(root, 20, Color(0.93, 0.88, 0.76))
	when.position = Vector2(30, 64)
	supplies = _label(root, 18, Color(0.88, 0.82, 0.70))
	supplies.position = Vector2(30, 92)

	weather = _label(root, 18, Color(0.86, 0.88, 0.82))
	weather.position = Vector2(30, 116)

	prompt = _label(root, 24, Color(1.0, 0.86, 0.5))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(prompt, 0.5, 1.0, -450, -270, 450, -230)

	subtitle = _label(root, 26, Color(1, 1, 1))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor(subtitle, 0.5, 1.0, -620, -200, 620, -90)

	toasts = VBoxContainer.new()
	root.add_child(toasts)
	_anchor(toasts, 1.0, 0.0, -660, 24, -28, 340)

	fps = _label(root, 14, Color(0.8, 0.8, 0.8, 0.8))
	_anchor(fps, 0.0, 1.0, 20, -40, 200, -16)


func _anchor(c: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", max(4, size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func say(speaker: String, text: String, seconds: float) -> void:
	subtitle.text = "%s:  %s" % [speaker, text]
	subtitle.modulate.a = 1.0
	_subtitle_left = seconds


func toast(text: String) -> void:
	var l := _label(toasts, 18, Color(0.96, 0.92, 0.82))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.text = text
	l.set_meta("left", 9.0)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()


func update(state: ExpeditionState, delta: float, prompt_text: String, sky: SkyAndWeather = null,
		stores: Stores = null) -> void:
	place.text = "Sioux Country"
	when.text = "%s  ·  %s  ·  %s" % [state.full_date_str(), state.clock_str(), state.season()]
	supplies.text = "Fit %d of %d   Morale %d   Discoveries %d" % [state.fit, state.men, state.morale, state.discoveries.size()]
	if stores:
		var days := stores.days_of_provisions(state.men)
		supplies.text += "   Provisions %s" % ("%d days" % days if days > 0 else "none")
	if sky:
		var hour := state.hour()
		var degrees := Weather.temperature_f(state.current_month, state.current_day, hour, sky.cloud_cover, sky.storm)
		var sky_says := Weather.describe_night(sky.cloud_cover, sky.storm) if sky.night_amount > 0.6 				else Weather.describe(sky.cloud_cover, sky.storm, hour, sky.haze)
		weather.text = "%d °F   ·   %s" % [roundi(degrees), sky_says]
	prompt.text = prompt_text
	_subtitle_left -= delta
	subtitle.modulate.a = clampf(_subtitle_left / 0.6, 0.0, 1.0)
	for c in toasts.get_children():
		var left: float = c.get_meta("left") - delta
		c.set_meta("left", left)
		c.modulate.a = clampf(left / 1.0, 0.0, 1.0)
		if left <= 0.0:
			c.queue_free()
	fps.text = "%d fps" % Engine.get_frames_per_second()
