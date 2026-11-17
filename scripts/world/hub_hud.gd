extends CanvasLayer
## Hub HUD: interaction prompt + fading controls hint. Hidden while Game.ui_open.

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _hint: Label
var _hint_t := 0.0
var _shown := ""


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_prompt_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	sb.border_color = Color(0.95, 0.76, 0.35, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(1.0, 0.7, 0.3, 0.25)
	sb.shadow_size = 12
	_prompt_panel.add_theme_stylebox_override("panel", sb)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.offset_bottom = -110
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_prompt_panel.add_child(row)
	var key := Label.new()
	key.text = "E"
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2(40, 40)
	key.add_theme_font_size_override("font_size", 24)
	key.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.98, 0.82, 0.42)
	ks.set_corner_radius_all(8)
	ks.border_color = Color(1, 0.95, 0.8)
	ks.border_width_bottom = 4
	key.add_theme_stylebox_override("normal", ks)
	row.add_child(key)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 26)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_label)
	_prompt_panel.modulate.a = 0.0

	_hint = Label.new()
	_hint.text = "WASD  move     Shift  sprint     Space  jump\nMouse  look     E  interact     Esc  menu"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 28
	_hint.offset_top = -86
	_hint.offset_bottom = -24
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_hint)


func set_prompt(text: String) -> void:
	if text != "":
		_shown = text
		_prompt_label.text = text


func _process(delta: float) -> void:
	visible = not Game.ui_open
	_hint_t += delta
	_hint.modulate.a = clampf(1.0 - (_hint_t - 8.0) / 1.5, 0.0, 1.0)
	var player := get_tree().get_first_node_in_group("hub_player")
	var has := player != null and player.get("_target") != null
	_prompt_panel.modulate.a = move_toward(_prompt_panel.modulate.a, 1.0 if has else 0.0, delta * 6.0)
