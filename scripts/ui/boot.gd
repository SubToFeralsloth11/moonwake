extends Control
## First scene: shows a loading screen while the harbor is built (it takes a few
## seconds, longer on the very first launch while shaders compile).

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("070912")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-300, -80)
	vb.custom_minimum_size = Vector2(600, 0)
	add_child(vb)
	for t in [["☾  MOONWAKE", 64, Color("ffd166")], ["The Tide Card Game", 22, Color("b8c8ff")],
			["Building the harbor...", 18, Color("c8bea8")],
			["(the first launch compiles shaders and can take up to a minute)", 14, Color("807868")]]:
		var l := Label.new()
		l.text = t[0]
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_color", t[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	# Let the loading screen actually draw before the heavy build blocks the main thread.
	for i in 3:
		await get_tree().process_frame
	get_tree().change_scene_to_file(Game.HUB_SCENE)
