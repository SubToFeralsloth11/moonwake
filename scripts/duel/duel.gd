extends Node3D
## 3D duel at the tavern table. Drives DuelState + DuelAI and animates events.

const SHRINE_X := [-1.15, 0.0, 1.15]
const BOARD_SCALE := 0.55
const HAND_SCALE := 0.78
const ROOM_SCENE := "res://scenes/duel/duel_room.tscn"

var state := DuelState.new()
var ai: DuelAI
var opp: Dictionary
var cam: Camera3D
var cam_base := Vector3(0, 2.6, 2.5)
var card_nodes: Dictionary = {}   # uid -> Card3D
var selected_uid := -1
var hovered: Card3D = null
var busy := true
var over := false
var opponent_model: Node3D
var shrine_nodes: Array = []      # {root, name, sky, p0, p1, light, orb, ring}
var ai_rang_this_round := false
var player_rang_this_round := false

# HUD
var hud: CanvasLayer
var round_label: Label
var glow_label: Label
var stake_label: Label
var end_btn: Button
var bell_btn: Button
var retreat_btn: Button
var detail_holder: Control
var bubble: Label
var bubble_panel: PanelContainer
var log_label: Label
var hint_label: Label


func _ready() -> void:
	randomize()
	var opp_id: String = Game.pending_opponent if Game.pending_opponent != "" else "pip"
	opp = OpponentDB.get_opponent(opp_id)
	ai = DuelAI.new(1, opp.skill, randi())
	_build_world()
	_build_hud()
	var deck: Array = Profile.active_deck()
	if not Profile.deck_valid(deck):
		deck = Profile.STARTER.duplicate()
	state.setup(deck, opp.deck, randi())
	_build_shrines()
	_say(opp.intro, 4.0)
	await get_tree().create_timer(1.2).timeout
	_start_round()


# ------------------------------------------------------------------ world

func _build_world() -> void:
	var spot: Node3D = null
	if ResourceLoader.exists(ROOM_SCENE):
		var room: Node = load(ROOM_SCENE).instantiate()
		add_child(room)
		spot = room.find_child("OpponentSpot", true, false) as Node3D
	else:
		_fallback_room()
	cam = Camera3D.new()
	cam.fov = 52
	add_child(cam)
	cam.position = cam_base
	cam.look_at(Vector3(0, 0, -0.15))
	cam.current = true

	opponent_model = CharacterModel.new()
	if spot:
		spot.add_child(opponent_model)
	else:
		add_child(opponent_model)
		opponent_model.position = Vector3(0, -0.35, -1.95)
		opponent_model.rotation.y = PI
	opponent_model.configure(opp.look)
	opponent_model.play("sit")

	# Drop zones on the player's side of each shrine.
	for s in 3:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.95, 0.02, 0.85)
		cs.shape = box
		sb.add_child(cs)
		sb.position = Vector3(SHRINE_X[s], 0.0, 0.55)
		sb.set_meta("zone", s)
		add_child(sb)


func _fallback_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0b0a10")
	env.environment.ambient_light_color = Color("403020")
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var table := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.9, 0.1, 2.9)
	table.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2a4a30")
	table.material_override = m
	table.position.y = -0.05
	add_child(table)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.2, 0)
	l.omni_range = 6
	l.light_energy = 2.0
	l.light_color = Color("ffd8a0")
	l.shadow_enabled = true
	add_child(l)


func _build_shrines() -> void:
	for s in 3:
		var sd := state.shrine_def(s)
		var root := Node3D.new()
		root.position = Vector3(SHRINE_X[s], 0, 0)
		add_child(root)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.98, 0.03, 0.3)
		slab.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2a2520")
		mat.roughness = 0.4
		mat.metallic = 0.4
		slab.material_override = mat
		slab.position.y = 0.015
		root.add_child(slab)
		var ring := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.0, 0.025, 0.32)
		ring.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = sd.color
		rmat.emission_enabled = true
		rmat.emission = sd.color
		rmat.emission_energy_multiplier = 0.6
		ring.material_override = rmat
		ring.position.y = 0.01
		root.add_child(ring)
		var name_l := _flat_label(sd.name, 46, Vector3(0, 0.032, -0.06), sd.color.lightened(0.3))
		root.add_child(name_l)
		var text_l := _flat_label(sd.text, 22, Vector3(0, 0.032, 0.03), Color("d8ccb0"))
		text_l.width = 900
		text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(text_l)
		var p0 := _flat_label("0", 90, Vector3(0, 0.035, 0.115), Color.WHITE)
		root.add_child(p0)
		var p1 := _flat_label("0", 90, Vector3(0, 0.035, -0.135), Color.WHITE)
		root.add_child(p1)
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		orb.mesh = sm
		var omat := StandardMaterial3D.new()
		omat.emission_enabled = true
		omat.emission_energy_multiplier = 3.0
		orb.material_override = omat
		orb.position = Vector3(0, 0.42, 0)
		root.add_child(orb)
		var sky_l := Label3D.new()
		sky_l.font_size = 64
		sky_l.pixel_size = 0.002
		sky_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sky_l.position = Vector3(0, 0.6, 0)
		sky_l.outline_size = 10
		root.add_child(sky_l)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0.5, 0)
		light.omni_range = 1.1
		light.light_energy = 0.8
		root.add_child(light)
		shrine_nodes.append({"root": root, "p0": p0, "p1": p1, "orb": orb, "orb_mat": omat,
			"sky": sky_l, "light": light, "ring_mat": rmat})
	_sync_shrines()


func _flat_label(t: String, size: int, pos: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = size
	l.pixel_size = 0.001
	l.outline_size = 10
	l.modulate = color
	l.rotation.x = -PI / 2
	l.position = pos
	return l


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.08, 0.75)))
	top.position = Vector2(20, 16)
	hud.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	tv.add_child(_label("%s" % opp.name, 26, Color("ffe7b0")))
	tv.add_child(_label(opp.title + ("" if opp.ladder else "  ·  " + _region_name(opp.region)), 15, Color("b0a890")))
	round_label = _label("", 22, Color.WHITE)
	tv.add_child(round_label)
	stake_label = _label("", 18, Color("ffd166"))
	tv.add_child(stake_label)

	bubble_panel = PanelContainer.new()
	bubble_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.96, 0.92, 0.82, 0.95), Color("6a5030")))
	bubble_panel.anchor_left = 0.5
	bubble_panel.anchor_right = 0.5
	bubble_panel.position = Vector2(-260, 18)
	bubble_panel.custom_minimum_size = Vector2(520, 0)
	hud.add_child(bubble_panel)
	bubble = _label("", 19, Color("2a1a0a"))
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.remove_theme_color_override("font_outline_color")
	bubble.add_theme_constant_override("outline_size", 0)
	bubble_panel.add_child(bubble)
	bubble_panel.modulate.a = 0

	var right := VBoxContainer.new()
	right.anchor_left = 1
	right.anchor_right = 1
	right.anchor_top = 1
	right.anchor_bottom = 1
	right.position = Vector2(-250, -250)
	right.custom_minimum_size = Vector2(230, 0)
	right.add_theme_constant_override("separation", 8)
	hud.add_child(right)
	glow_label = _label("", 28, Color("9fe8ff"))
	glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(glow_label)
	end_btn = _button("End Turn", Color("2f6f4f"))
	end_btn.custom_minimum_size.y = 64
	end_btn.pressed.connect(_on_end_turn)
	right.add_child(end_btn)
	bell_btn = _button("Ring the Moon Bell", Color("6a5020"))
	bell_btn.pressed.connect(_on_bell)
	bell_btn.tooltip_text = "Doubles the stakes from next round. Win = more Shells (and Renown on the Ladder)."
	right.add_child(bell_btn)
	retreat_btn = _button("Retreat", Color("5a2a2a"))
	retreat_btn.pressed.connect(_on_retreat)
	retreat_btn.tooltip_text = "Concede now and lose only the current stake."
	right.add_child(retreat_btn)

	detail_holder = Control.new()
	detail_holder.anchor_left = 1
	detail_holder.anchor_right = 1
	detail_holder.position = Vector2(-270, 120)
	detail_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(detail_holder)

	log_label = _label("", 20, Color("fff0c0"))
	log_label.anchor_left = 0.5
	log_label.anchor_right = 0.5
	log_label.anchor_top = 0.5
	log_label.anchor_bottom = 0.5
	log_label.position = Vector2(-400, -40)
	log_label.custom_minimum_size = Vector2(800, 0)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 38)
	log_label.modulate.a = 0
	hud.add_child(log_label)

	hint_label = _label("Click a card in your hand, then click a shrine on your side to play it. Click a played card to take it back.", 16, Color("d8d0c0"))
	hint_label.anchor_top = 1
	hint_label.anchor_bottom = 1
	hint_label.position = Vector2(20, -40)
	hud.add_child(hint_label)


func _region_name(id: String) -> String:
	for r in OpponentDB.REGIONS:
		if r.id == id:
			return r.name
	return ""


func _panel_style(bg: Color, border := Color(1, 0.85, 0.5, 0.35)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	return sb


func _label(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _button(t: String, color: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := _panel_style(color if st != "hover" else color.lightened(0.2))
		if st == "pressed":
			sb.bg_color = color.darkened(0.3)
		if st == "disabled":
			sb.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		b.add_theme_stylebox_override(st, sb)
	return b


func _say(text: String, dur := 3.0) -> void:
	bubble.text = "%s: \"%s\"" % [opp.name, text]
	var tw := create_tween()
	tw.tween_property(bubble_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(dur)
	tw.tween_property(bubble_panel, "modulate:a", 0.0, 0.4)


func _announce(text: String, color := Color("fff0c0")) -> void:
	log_label.text = text
	log_label.add_theme_color_override("font_color", color)
	var tw := create_tween()
	log_label.modulate.a = 0
	tw.tween_property(log_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.0)
	tw.tween_property(log_label, "modulate:a", 0.0, 0.4)


func _update_hud() -> void:
	round_label.text = "Round %d / %d" % [state.round, DuelState.ROUNDS]
	var stake_txt := "Stake ×%d" % state.stake
	if state.stake_pending != state.stake:
		stake_txt += "  →  ×%d next round" % state.stake_pending
	stake_label.text = stake_txt
	glow_label.text = "Glow  %s  %d" % ["●".repeat(state.glow[0]) if state.glow[0] <= 10 else "●×%d" % state.glow[0], state.glow[0]]
	end_btn.disabled = busy or over
	bell_btn.disabled = busy or over or not _can_ring()
	retreat_btn.disabled = busy or over


func _can_ring() -> bool:
	return not state.bell_rung[0] and not state.bell_rung[1] and state.stake_pending == state.stake and state.stake_pending < DuelState.MAX_STAKE


# ------------------------------------------------------------------ flow

func _start_round() -> void:
	busy = true
	player_rang_this_round = false
	ai_rang_this_round = false
	state.start_round()
	_announce("Round %d" % state.round + ("  —  Final Tide!" if state.is_last_round() else ""))
	for p in ai.plan(state):
		state.stage(1, p[0], p[1])
	if ai.wants_bell(state) and state.ring_bell(1):
		ai_rang_this_round = true
		_say("I ring the Moon Bell! Stakes double.", 2.5)
		_bell_sound_visual()
	_sync()
	busy = false
	_update_hud()


func _on_end_turn() -> void:
	if busy or over:
		return
	busy = true
	_select(-1)
	_update_hud()
	var first := state.begin_reveal()
	_announce("%s reveals first" % ("You" if first == 0 else opp.name))
	await _wait(0.8)
	while true:
		var ev = state.reveal_next()
		if ev == null:
			break
		await _play_events(ev)
	if state.is_last_round():
		await _finish()
		return
	await _wait(0.5)
	_announce("Dusk falls. The skies turn.", Color("b8c8ff"))
	await _wait(0.6)
	await _play_events(state.dusk())
	await _wait(0.6)
	if player_rang_this_round and ai.wants_retreat(state):
		_say("Too rich for me. I fold!", 3)
		state.retreated = 1
		await _wait(1.5)
		await _finish()
		return
	_start_round()


func _on_bell() -> void:
	if busy or over or not state.ring_bell(0):
		return
	player_rang_this_round = true
	_bell_sound_visual()
	_announce("You ring the Moon Bell! Stakes ×%d next round" % state.stake_pending, Color("ffd166"))
	_update_hud()


func _bell_sound_visual() -> void:
	Sfx.play("bell")
	var tw := create_tween()
	tw.tween_property(cam, "position", cam_base + Vector3(0, 0.05, 0), 0.08)
	tw.tween_property(cam, "position", cam_base, 0.2)


func _on_retreat() -> void:
	if busy or over:
		return
	state.retreated = 0
	busy = true
	await _finish()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _play_events(ev: Array) -> void:
	for e in ev:
		match e.t:
			"reveal":
				Sfx.play("flip")
				_sync()
				var n: Card3D = card_nodes.get(e.uid)
				if n:
					n.set_highlight(true, CardDB.COURT_COLORS[CardDB.get_card(n.card_id).court])
					if state.cards[e.uid].side == 1:
						opponent_model.play("play_card")
				await _wait(0.55)
				if n:
					n.set_highlight(false)
			"buff":
				_float_text(e.uid, ("+%d" % e.n) if e.n > 0 else str(e.n), Color("8fff8f") if e.n > 0 else Color("ff6a6a"))
				_sync()
				await _wait(0.18)
			"flip":
				Sfx.play("whoosh")
				_sync()
				var sn: Dictionary = shrine_nodes[e.shrine]
				var tw := create_tween()
				tw.tween_property(sn.orb, "scale", Vector3.ONE * 1.8, 0.15)
				tw.tween_property(sn.orb, "scale", Vector3.ONE, 0.25)
				await _wait(0.3)
			"flip_blocked", "still":
				_float_shrine(e.shrine, "Still", Color("7fd6c9"))
				_sync()
				await _wait(0.2)
			"destroy":
				Sfx.play("burn")
				var n: Card3D = card_nodes.get(e.uid)
				card_nodes.erase(e.uid)
				if n:
					var tw := create_tween()
					tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
					tw.tween_callback(n.queue_free)
				_sync()
				await _wait(0.35)
			"move", "summon", "draw", "swap":
				_sync()
				await _wait(0.25)
			"glow":
				_float_text(e.uid, "+%d Glow" % e.n, Color("9fe8ff"))
				await _wait(0.2)
	_sync()


func _finish() -> void:
	over = true
	busy = true
	_update_hud()
	var res := state.result()
	var summary := Profile.apply_duel(opp, res, state.stats)
	if summary.has("bonus_pack"):
		pass
	var title := "VICTORY" if summary.won else ("DRAW" if summary.draw else "DEFEAT")
	var color := Color("ffd166") if summary.won else (Color("c0c0c0") if summary.draw else Color("ff7a6a"))
	if summary.won:
		opponent_model.play("sad")
		_say(opp.lose_line, 4)
		Sfx.play("win")
	elif not summary.draw:
		opponent_model.play("cheer")
		_say(opp.win_line, 4)
		Sfx.play("lose")
	for s in 3:
		var l := state.shrine_leader(s) if res.retreat < 0 else -1
		var mat: StandardMaterial3D = shrine_nodes[s].ring_mat
		if l == 0:
			mat.emission = Color("ffd166")
			mat.emission_energy_multiplier = 3.0
		elif l == 1:
			mat.emission = Color("ff4040")
			mat.emission_energy_multiplier = 2.0
	await _wait(1.4)
	_show_result(title, color, summary, res)


func _show_result(title: String, color: Color, summary: Dictionary, res: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.07, 0.1, 0.96), color))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.position = Vector2(-260, -200)
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var t := _label(title, 56, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var lines: PackedStringArray = []
	if res.retreat == 0:
		lines.append("You retreated.")
	elif res.retreat == 1:
		lines.append("%s folded!" % opp.name)
	else:
		lines.append("Shrines won: %d  ·  Total power %d vs %d" % [res.shrines.count(0), res.totals[0], res.totals[1]])
	lines.append("Stake ×%d" % summary.stake)
	lines.append("+%d Shells" % summary.shells)
	if summary.renown != 0:
		lines.append("%+d Renown  ·  %s" % [summary.renown, Profile.rank_title()])
	for r in summary.rank_up:
		lines.append("Rank up! %s" % Profile.rank_title(r))
	if summary.first_win:
		lines.append("First victory over %s!" % opp.name)
	for id in summary.cards:
		lines.append("New card: %s" % CardDB.get_card(id).name)
	if summary.glimmer > 0:
		lines.append("+%d Glimmer" % summary.glimmer)
	var body := _label("\n".join(lines), 20, Color("f0e6d0"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var again := _button("Rematch", Color("2a4a6a"))
	again.pressed.connect(func():
		var id: String = opp.id
		if opp.ladder:
			id = "ladder:%d:%d" % [Profile.rank(), randi()]
		Game.pending_opponent = id
		get_tree().reload_current_scene())
	hb.add_child(again)
	var back := _button("Back to the Harbor", Color("2f6f4f"))
	back.pressed.connect(func(): Game.end_duel(summary))
	hb.add_child(back)


# ------------------------------------------------------------------ sync visuals

func _sync() -> void:
	var back: String = Profile.data.card_back
	for uid in state.cards:
		var c: Dictionary = state.cards[uid]
		var n: Card3D = card_nodes.get(uid)
		if n == null:
			n = Card3D.new()
			add_child(n)
			n.setup(uid, c.id, back if c.side == 0 else "classic")
			card_nodes[uid] = n
			n.position = Vector3(0, 0.6, 1.6) if c.side == 0 else Vector3(0, 0.3, -1.7)
			if c.shrine >= 0:
				n.position = _slot_pos(c.side, c.shrine, state.board[c.side][c.shrine].find(uid)) + Vector3(0, 0.3, 0)
	for uid in card_nodes.keys():
		if not state.cards.has(uid):
			var n: Card3D = card_nodes[uid]
			card_nodes.erase(uid)
			n.queue_free()
	# Hands
	for side in 2:
		var hand: Array = state.hands[side]
		for i in hand.size():
			var n: Card3D = card_nodes[hand[i]]
			var c: Dictionary = state.cards[hand[i]]
			var count := hand.size()
			var x := (i - (count - 1) / 2.0) * (0.36 if side == 0 else 0.16)
			if side == 0:
				n.target_pos = Vector3(x, 0.55 + absf(x) * -0.04, 1.32 + absf(x) * 0.03)
				n.target_basis = Basis(Vector3.RIGHT, 0.62).rotated(Vector3.UP, -x * 0.12).scaled(Vector3.ONE * HAND_SCALE)
				n.set_face_up(true)
				n.set_values(c.sun, c.moon, -1)
				n.selected = hand[i] == selected_uid
			else:
				n.target_pos = Vector3(x, 0.05 + i * 0.002, -1.32)
				n.target_basis = Basis.IDENTITY.scaled(Vector3.ONE * 0.45)
				n.set_face_up(false)
	# Board
	for side in 2:
		for s in 3:
			var list: Array = state.board[side][s]
			for i in list.size():
				var uid: int = list[i]
				var n: Card3D = card_nodes[uid]
				var c: Dictionary = state.cards[uid]
				n.target_pos = _slot_pos(side, s, i)
				n.target_basis = Basis.IDENTITY.scaled(Vector3.ONE * BOARD_SCALE)
				n.selected = false
				n.set_face_up(c.revealed or side == 0)
				if c.revealed:
					n.set_values(c.sun, c.moon, state.shrines[s].sky, state.power(uid))
				else:
					n.set_values(c.sun, c.moon, state.shrines[s].sky)
				if side == 0 and not c.revealed:
					n.set_highlight(true, Color(0.5, 0.9, 1.0))
				elif not busy:
					n.set_highlight(false)
	_sync_shrines()
	_update_hud()


func _slot_pos(side: int, s: int, i: int) -> Vector3:
	var col := i % 2
	var row := i / 2
	var x: float = SHRINE_X[s] + (-0.13 if col == 0 else 0.13)
	var z := 0.36 + row * 0.38
	if side == 1:
		z = -z
	return Vector3(x, 0.03 + row * 0.004, z)


func _sync_shrines() -> void:
	for s in 3:
		var sn: Dictionary = shrine_nodes[s]
		var sky: int = state.shrines[s].sky
		var a := state.shrine_power(0, s)
		var b := state.shrine_power(1, s)
		sn.p0.text = str(a)
		sn.p1.text = str(b)
		sn.p0.modulate = Color("ffd166") if a > b else Color(0.85, 0.85, 0.85)
		sn.p1.modulate = Color("ff7a6a") if b > a else Color(0.85, 0.85, 0.85)
		var sun := sky == DuelState.SUN
		sn.sky.text = ("☀ Sun" if sun else "☾ Moon") + ("  (still)" if state.is_anchored(s) else "")
		sn.sky.modulate = Color("ffd166") if sun else Color("a9c8ff")
		sn.orb_mat.albedo_color = Color("ffcf5a") if sun else Color("c8d8ff")
		sn.orb_mat.emission = Color("ffb030") if sun else Color("6080ff")
		sn.light.light_color = Color("ffd090") if sun else Color("90a8ff")


func _float_text(uid: int, text: String, color: Color) -> void:
	var n: Card3D = card_nodes.get(uid)
	if n == null:
		return
	_float_at(n.global_position + Vector3(0, 0.15, 0), text, color)


func _float_shrine(s: int, text: String, color: Color) -> void:
	_float_at(Vector3(SHRINE_X[s], 0.3, 0), text, color)


func _float_at(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.0015
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 12
	l.no_depth_test = true
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "global_position", pos + Vector3(0, 0.35, 0), 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ input

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if cam and not over:
		cam.position = cam.position.lerp(cam_base + Vector3(sin(t * 0.3) * 0.03, sin(t * 0.5) * 0.02, 0), delta * 2.0)
	for sn in shrine_nodes:
		sn.orb.position.y = 0.42 + sin(t * 1.5 + sn.root.position.x) * 0.03


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_select(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)
	elif event.is_action_pressed("menu"):
		_select(-1)


func _pick(screen: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.collider
	if col.has_meta("card3d"):
		return {"card": col.get_meta("card3d")}
	if col.has_meta("zone"):
		return {"zone": col.get_meta("zone")}
	return {}


func _update_hover(screen: Vector2) -> void:
	var p := _pick(screen)
	var n: Card3D = p.get("card")
	if n != hovered:
		if hovered and is_instance_valid(hovered):
			hovered.hover = false
		hovered = n
		for c in detail_holder.get_children():
			c.queue_free()
		if n:
			var c: Dictionary = state.cards.get(n.uid, {})
			var visible: bool = not c.is_empty() and (c.side == 0 or c.revealed)
			n.hover = c.get("side", 1) == 0 and n.uid in state.hands[0]
			if visible:
				var v := CardView.make(n.card_id, 1.2)
				v.mouse_filter = Control.MOUSE_FILTER_IGNORE
				detail_holder.add_child(v)


func _click(screen: Vector2) -> void:
	if busy or over:
		return
	var p := _pick(screen)
	if p.has("card"):
		var n: Card3D = p.card
		if n.uid in state.hands[0]:
			_select(n.uid if selected_uid != n.uid else -1)
			return
		if n.uid in state.staged[0]:
			state.unstage(0, n.uid)
			Sfx.play("place")
			_sync()
			return
		if selected_uid >= 0 and state.cards.has(n.uid):
			_try_stage(state.cards[n.uid].shrine)
			return
	if p.has("zone") and selected_uid >= 0:
		_try_stage(p.zone)


func _try_stage(s: int) -> void:
	if s < 0:
		return
	if state.stage(0, selected_uid, s):
		Sfx.play("place")
		selected_uid = -1
		_sync()
	else:
		var why := "Not enough Glow" if state.cost_of(selected_uid, s) > state.glow[0] else "That shrine is full"
		_announce(why, Color("ff8a7a"))


func _select(uid: int) -> void:
	selected_uid = uid
	_sync()
