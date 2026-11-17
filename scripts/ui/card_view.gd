class_name CardView
extends PanelContainer
## 2D rendering of a Tidecard for menus, tooltips and pack openings.

signal pressed(card_id: String)

var card_id := ""
var _count_label: Label
var _art: ColorRect
const ART_SHADER := preload("res://shaders/cards/card_art_2d.gdshader")


static func make(id: String, scale_f := 1.0, count := -1) -> CardView:
	var v := CardView.new()
	v.build(id, scale_f, count)
	return v


func build(id: String, s := 1.0, count := -1) -> void:
	card_id = id
	var c := CardDB.get_card(id)
	var col: Color = CardDB.COURT_COLORS[c.court]
	custom_minimum_size = Vector2(200, 290) * s
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b1712")
	sb.border_color = col.darkened(0.2)
	sb.set_border_width_all(int(5 * s))
	sb.set_corner_radius_all(int(12 * s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = int(8 * s)
	sb.set_content_margin_all(8 * s)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(3 * s))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	top.add_child(_lbl(str(c.cost), 22 * s, Color("9fe8ff")))
	var name_l := _lbl(c.name, 15 * s, Color("f4ead2"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(name_l)

	_art = ColorRect.new()
	_art.custom_minimum_size = Vector2(0, 100 * s)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = ART_SHADER
	sm.set_shader_parameter("tint", col)
	sm.set_shader_parameter("seed", float(hash(id) % 1000) / 37.0)
	_art.material = sm
	vb.add_child(_art)

	var rar := _lbl("%s · %s" % [CardDB.RARITY_NAMES[c.rarity], String(c.court).capitalize()], 11 * s, CardDB.RARITY_COLORS[c.rarity])
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rar)
	var txt := _lbl(c.text if c.text != "" else "\"%s\"" % c.flavor, 12 * s, Color("e8dcc0") if c.text != "" else Color("b8a888"))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(txt)
	var vals := HBoxContainer.new()
	vals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vals.alignment = BoxContainer.ALIGNMENT_CENTER
	vals.add_theme_constant_override("separation", int(30 * s))
	vals.add_child(_lbl("☀ %d" % c.sun, 22 * s, Color("ffd166")))
	vals.add_child(_lbl("☾ %d" % c.moon, 22 * s, Color("a9c8ff")))
	vb.add_child(vals)
	if count >= 0:
		_count_label = _lbl("", 14 * s, Color.WHITE)
		_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(_count_label)
		set_count(count)
	gui_input.connect(_on_input)


func set_count(n: int, extra := "") -> void:
	if _count_label == null:
		return
	var c := CardDB.get_card(card_id)
	_count_label.text = "Owned %d/%d%s" % [n, CardDB.MAX_COPIES[c.rarity], extra]
	modulate = Color(1, 1, 1) if n > 0 else Color(0.45, 0.45, 0.5)


func _lbl(t: String, size: float, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", int(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(card_id)
