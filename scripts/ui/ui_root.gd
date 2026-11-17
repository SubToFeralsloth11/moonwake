extends CanvasLayer
## Persistent overlay owned by the Game autoload: currency bar, toasts, fades,
## and the menu screens (shop, deck builder/collection, campaign, pause, results).

const GOLD := Color("ffd166")
const INK := Color("f0e6d0")

var fade_rect: ColorRect
var top_bar: PanelContainer
var top_label: Label
var toast_box: VBoxContainer
var screen: Control = null
var current := ""

# deck builder state
var edit_index := 0
var edit_cards: Array = []
var filter_court := ""
var deck_list_box: VBoxContainer
var deck_title: LineEdit
var deck_count: Label
var grid: GridContainer
var glimmer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.09, 0.78)))
	top_bar.anchor_left = 1
	top_bar.anchor_right = 1
	top_bar.position = Vector2(-560, 14)
	top_bar.custom_minimum_size = Vector2(540, 0)
	add_child(top_bar)
	top_label = _label("", 18, INK)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(top_label)
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.position = Vector2(-300, 90)
	toast_box.custom_minimum_size = Vector2(600, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	Profile.changed.connect(_refresh_top)
	Profile.toast.connect(show_toast)
	_refresh_top()
	if not Profile.data.seen_intro:
		await get_tree().create_timer(0.8).timeout
		Game.open_screen("intro")


func _process(_d: float) -> void:
	top_bar.visible = get_tree().current_scene != null and get_tree().current_scene.scene_file_path.contains("hub") or screen != null


func _refresh_top() -> void:
	var cp := Profile.campaign_progress()
	top_label.text = "🐚 %d Shells   ✦ %d Glimmer   ⚓ %s   📜 %d/%d   🃏 %d/%d" % [
		Profile.shells(), Profile.glimmer(), Profile.rank_title(), cp.x, cp.y,
		Profile.unique_owned(), CardDB.all_ids().size()]


# ------------------------------------------------------------------ helpers

func _style(bg: Color, border := Color(1, 0.85, 0.5, 0.35), radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


func _label(t: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(t: String, color := Color("2f5a6f"), cb := Callable()) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _style(color, Color(1, 0.85, 0.5, 0.5), 8)
		sb.set_content_margin_all(8)
		match st:
			"hover": sb.bg_color = color.lightened(0.18)
			"pressed": sb.bg_color = color.darkened(0.3)
			"disabled": sb.bg_color = Color(0.22, 0.22, 0.24)
			"focus": sb.draw_center = false
		b.add_theme_stylebox_override(st, sb)
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.play("click")
			cb.call())
	return b


func show_toast(text: String, color := GOLD) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.08, 0.9), color))
	var l := _label(text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.35)
	await tw.finished


func fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.5)


# ------------------------------------------------------------------ screens

func open(name: String, data: Dictionary = {}) -> void:
	close_all(false)
	current = name
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	move_child(screen, 1)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	match name:
		"shop": _build_shop()
		"deck", "collection": _build_deck()
		"campaign": _build_campaign()
		"menu": _build_menu()
		"result": _build_result(data)
		"intro": _build_intro()
		"pack": _build_pack(data)
		_: _build_menu()


func close_all(notify := true) -> void:
	if screen:
		screen.queue_free()
		screen = null
	current = ""
	if notify:
		Game.close_screen()


func _unhandled_input(event: InputEvent) -> void:
	if screen and event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close_all()


func _window(title: String, subtitle := "", size := Vector2(1400, 780)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.07, 0.1, 0.97), Color(1, 0.82, 0.45, 0.6), 14))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = size
	panel.position = -size / 2
	screen.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	tv.add_child(_label(title, 32, GOLD))
	if subtitle != "":
		tv.add_child(_label(subtitle, 15, Color("b8ae98")))
	head.add_child(_button("✕ Close (Esc)", Color("5a2a2a"), close_all.bind(true)))
	return vb


# ---------------------------------------------------------------- intro / menu

func _build_intro() -> void:
	var vb := _window("Welcome to Moonwake Harbor", "A card game of turning skies", Vector2(860, 600))
	var t := _label("""Every Tidecard has two numbers: ☀ Sun and ☾ Moon.
Three shrines sit on the table. Each shows the Sun or the Moon, and the
shrine's sky decides which of your numbers count there.

• Each round you get Glow equal to the round number (1 to 6). Spend it to play cards to shrines.
• Both sides play at once, then cards reveal and their abilities trigger.
• At Dusk every sky turns, Sun ↔ Moon. Plan for the sky that will be there at the end!
• After round 6, win 2 of the 3 shrines to win the duel.
• Ring the Moon Bell to double the stakes. Your foe may fold, and so may you.

Earn Shells by winning duels and finishing daily quests. Spend them on packs at
the Gilded Gull, build decks at the Deck Desk, and challenge the 30 masters on
the Notice Board. When you're ready, climb the Tavern Ladder to Tidewright.""", 18)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	vb.add_child(_button("Let's play  (you start with 300 Shells: go buy packs!)", Color("2f6f4f"), func():
		Profile.data.seen_intro = true
		Profile.save_game()
		close_all()))


func _build_menu() -> void:
	var vb := _window("Paused", "Moonwake Harbor", Vector2(620, 620))
	var st: Dictionary = Profile.data.stats
	vb.add_child(_label("Duels: %d   Wins: %d   Cards played: %d   Packs: %d   Best stake: ×%d" % [st.duels, st.wins, st.cards_played, st.packs, st.best_stake], 15))
	vb.add_child(_label("Daily quests (reset each day):", 20, GOLD))
	for q in Profile.data.quests.list:
		var done: bool = q.done
		vb.add_child(_label(("✔ " if done else "• ") + "%s  (%d/%d)  +%d Shells" % [q.text, q.progress, q.goal, q.reward], 17, Color("8fe08f") if done else INK))
	vb.add_child(_label("Volume", 16))
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 1
	vol.step = 0.05
	vol.value = Profile.data.settings.volume
	vol.value_changed.connect(func(v):
		Profile.data.settings.volume = v
		Profile.save_game())
	vb.add_child(vol)
	vb.add_child(_button("How to play", Color("2f5a6f"), open.bind("intro", {})))
	vb.add_child(_button("Resume", Color("2f6f4f"), close_all.bind(true)))
	vb.add_child(_button("Quit game", Color("5a2a2a"), func(): get_tree().quit()))


# ---------------------------------------------------------------- shop

func _build_shop() -> void:
	var vb := _window("The Gilded Gull", "Packs and card backs. Duplicate cards past your limit turn into Glimmer.")
	var packs := HFlowContainer.new()
	packs.add_theme_constant_override("h_separation", 14)
	packs.add_theme_constant_override("v_separation", 14)
	vb.add_child(packs)
	for id in Profile.PACKS:
		var p: Dictionary = Profile.PACKS[id]
		var col: Color = CardDB.COURT_COLORS.get(p.court, GOLD) if p.court != "" else (Color("b090ff") if id == "moonlit" else GOLD)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _style(col.darkened(0.75), col, 12))
		box.custom_minimum_size = Vector2(205, 250)
		packs.add_child(box)
		var pv := VBoxContainer.new()
		box.add_child(pv)
		var icon := _label("🂠", 64, col)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(icon)
		pv.add_child(_label(p.name, 20, col.lightened(0.3)))
		var d := _label(p.desc, 13, Color("c8bea8"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pv.add_child(d)
		var b := _button("Buy  🐚 %d" % p.price, Color("2f6f4f"), func(): _buy_pack(id))
		b.disabled = Profile.shells() < p.price
		pv.add_child(b)
	vb.add_child(_label("Card backs", 22, GOLD))
	var backs := HFlowContainer.new()
	backs.add_theme_constant_override("h_separation", 10)
	vb.add_child(backs)
	for id in Profile.CARD_BACKS:
		var cb: Dictionary = Profile.CARD_BACKS[id]
		var owned: bool = id in Profile.data.card_backs
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _style(cb.a, cb.b, 10))
		box.custom_minimum_size = Vector2(170, 0)
		backs.add_child(box)
		var bv := VBoxContainer.new()
		box.add_child(bv)
		var em := _label("☾", 40, cb.b)
		em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(em)
		bv.add_child(_label(cb.name, 15, cb.b.lightened(0.3)))
		var label := "Equipped" if Profile.data.card_back == id else ("Equip" if owned else "Buy 🐚 %d" % cb.price)
		var btn := _button(label, Color("2f5a6f"), func():
			if owned:
				Profile.set_card_back(id)
			elif Profile.buy_card_back(id):
				Sfx.play("coin")
			open("shop"))
		btn.disabled = Profile.data.card_back == id or (not owned and Profile.shells() < cb.price)
		bv.add_child(btn)


func _buy_pack(id: String) -> void:
	var cards := Profile.open_pack(id)
	if cards.is_empty():
		show_toast("Not enough Shells", Color("ff8a7a"))
		return
	Sfx.play("coin")
	open("pack", {"cards": cards, "pack": id})


func _build_pack(data: Dictionary) -> void:
	var vb := _window(Profile.PACKS[data.pack].name + " opened!", "Click a card to flip it.", Vector2(1260, 560))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	vb.add_child(row)
	var i := 0
	for entry in data.cards:
		var holder := VBoxContainer.new()
		row.add_child(holder)
		var c := CardDB.get_card(entry.id)
		var back := _button("☾\n\n%s" % CardDB.RARITY_NAMES[c.rarity], Color(CardDB.RARITY_COLORS[c.rarity]).darkened(0.6))
		back.custom_minimum_size = Vector2(200, 290)
		back.add_theme_font_size_override("font_size", 26)
		holder.add_child(back)
		var tag := _label("", 15, GOLD)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(tag)
		back.pressed.connect(func():
			Sfx.play("flip")
			var view := CardView.make(entry.id, 1.0)
			holder.add_child(view)
			holder.move_child(view, 0)
			back.queue_free()
			tag.text = "NEW!" if entry.new else ("+%d Glimmer (extra copy)" % entry.glimmer if entry.glimmer > 0 else "Duplicate")
			if c.rarity >= CardDB.Rarity.EPIC:
				Sfx.play("win"))
		i += 1
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	hb.add_child(_button("Open another (🐚 %d)" % Profile.PACKS[data.pack].price, Color("2f6f4f"), func(): _buy_pack(data.pack)))
	hb.add_child(_button("Back to shop", Color("2f5a6f"), open.bind("shop", {})))


# ---------------------------------------------------------------- deck builder

func _build_deck() -> void:
	var vb := _window("Deck Desk", "Build a %d-card deck. Up to 2 copies (1 for Mythics). Click to add or remove. Craft missing cards with Glimmer." % CardDB.DECK_SIZE, Vector2(1500, 840))
	edit_index = clampi(Profile.data.active_deck, 0, Profile.data.decks.size() - 1)
	edit_cards = Profile.data.decks[edit_index].cards.duplicate()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	vb.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var filters := HBoxContainer.new()
	left.add_child(filters)
	for court in ["", "ember", "tide", "grove", "gale", "wild"]:
		var name: String = "All" if court == "" else CardDB.COURT_NAMES[court]
		filters.add_child(_button(name, CardDB.COURT_COLORS.get(court, Color("4a4a5a")).darkened(0.5), func():
			filter_court = court
			_fill_grid()))
	glimmer_label = _label("", 16, Color("c9b6ff"))
	filters.add_child(glimmer_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _style(Color(0.1, 0.09, 0.08, 1), Color(1, 0.85, 0.5, 0.3)))
	right.custom_minimum_size = Vector2(330, 0)
	body.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	var pick := OptionButton.new()
	for i in Profile.data.decks.size():
		pick.add_item(Profile.data.decks[i].name, i)
	pick.select(edit_index)
	pick.item_selected.connect(func(i):
		Profile.data.active_deck = i
		Profile.save_game()
		open("deck"))
	rv.add_child(pick)
	deck_title = LineEdit.new()
	deck_title.text = Profile.data.decks[edit_index].name
	rv.add_child(deck_title)
	deck_count = _label("", 18, GOLD)
	rv.add_child(deck_count)
	var ds := ScrollContainer.new()
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(ds)
	deck_list_box = VBoxContainer.new()
	deck_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(deck_list_box)
	rv.add_child(_button("Save & use this deck", Color("2f6f4f"), _save_deck))
	rv.add_child(_button("New deck", Color("2f5a6f"), func():
		Profile.data.decks.append({"name": "Deck %d" % (Profile.data.decks.size() + 1), "cards": []})
		Profile.data.active_deck = Profile.data.decks.size() - 1
		Profile.save_game()
		open("deck")))
	var del := _button("Delete deck", Color("5a2a2a"), func():
		Profile.data.decks.remove_at(edit_index)
		Profile.data.active_deck = 0
		Profile.save_game()
		open("deck"))
	del.disabled = Profile.data.decks.size() <= 1
	rv.add_child(del)
	_fill_grid()
	_fill_deck_list()


func _fill_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	glimmer_label.text = "   ✦ %d Glimmer" % Profile.glimmer()
	var ids := CardDB.ids_by(filter_court)
	ids.sort_custom(func(a, b):
		var ca := CardDB.get_card(a)
		var cb := CardDB.get_card(b)
		return ca.cost < cb.cost if ca.cost != cb.cost else ca.name < cb.name)
	for id in ids:
		var c := CardDB.get_card(id)
		var cell := VBoxContainer.new()
		grid.add_child(cell)
		var v := CardView.make(id, 0.8, Profile.owned(id))
		var in_deck := edit_cards.count(id)
		if in_deck > 0:
			v.set_count(Profile.owned(id), "  ·  %d in deck" % in_deck)
		v.pressed.connect(func(cid): _add_to_deck(cid))
		cell.add_child(v)
		var row := HBoxContainer.new()
		cell.add_child(row)
		var craft := _button("Craft ✦%d" % CardDB.CRAFT_COST[c.rarity], Color("3a2a5a"), func():
			if Profile.craft(id):
				Sfx.play("coin")
				_fill_grid())
		craft.add_theme_font_size_override("font_size", 12)
		craft.disabled = Profile.owned(id) >= CardDB.MAX_COPIES[c.rarity] or Profile.glimmer() < CardDB.CRAFT_COST[c.rarity]
		row.add_child(craft)
		var dust := _button("Break +%d" % CardDB.DUST_VALUE[c.rarity], Color("4a3020"), func():
			if Profile.disenchant(id):
				while edit_cards.count(id) > Profile.owned(id):
					edit_cards.erase(id)
				_fill_grid()
				_fill_deck_list())
		dust.add_theme_font_size_override("font_size", 12)
		dust.disabled = Profile.owned(id) <= 0
		row.add_child(dust)


func _add_to_deck(id: String) -> void:
	var c := CardDB.get_card(id)
	if edit_cards.size() >= CardDB.DECK_SIZE:
		show_toast("Deck is full (%d cards)" % CardDB.DECK_SIZE, Color("ff8a7a"))
		return
	if edit_cards.count(id) >= mini(Profile.owned(id), CardDB.MAX_COPIES[c.rarity]):
		show_toast("You don't own another copy of %s" % c.name, Color("ff8a7a"))
		return
	Sfx.play("place")
	edit_cards.append(id)
	_fill_deck_list()
	_fill_grid()


func _fill_deck_list() -> void:
	for c in deck_list_box.get_children():
		c.queue_free()
	deck_count.text = "%d / %d cards" % [edit_cards.size(), CardDB.DECK_SIZE]
	var sorted := edit_cards.duplicate()
	sorted.sort_custom(func(a, b): return CardDB.get_card(a).cost < CardDB.get_card(b).cost)
	var curve := [0, 0, 0, 0, 0, 0, 0]
	for id in sorted:
		var c := CardDB.get_card(id)
		curve[c.cost] += 1
		var b := _button("%d  %s   ☀%d ☾%d" % [c.cost, c.name, c.sun, c.moon], Color(CardDB.COURT_COLORS[c.court]).darkened(0.6), func():
			edit_cards.erase(id)
			_fill_deck_list()
			_fill_grid())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		deck_list_box.add_child(b)
	var bars := ""
	for cost in range(1, 7):
		bars += "%d:%s " % [cost, "▮".repeat(curve[cost])]
	deck_list_box.add_child(_label("Curve  " + bars, 13, Color("b8ae98")))


func _save_deck() -> void:
	var d: Dictionary = Profile.data.decks[edit_index]
	d.name = deck_title.text if deck_title.text.strip_edges() != "" else d.name
	d.cards = edit_cards.duplicate()
	Profile.data.active_deck = edit_index
	Profile.save_game()
	if Profile.deck_valid(edit_cards):
		show_toast("Deck saved and ready!", Color("8fe08f"))
	else:
		show_toast("Saved, but a deck needs exactly %d cards to play. The starter deck is used until then." % CardDB.DECK_SIZE, Color("ffb070"))
	open("deck")


# ---------------------------------------------------------------- campaign

func _build_campaign() -> void:
	var cp := Profile.campaign_progress()
	var vb := _window("Notice Board of the Drowned Lantern", "Campaign %d/%d defeated  ·  Tavern Ladder: %s (%d renown)" % [cp.x, cp.y, Profile.rank_title(), Profile.data.renown], Vector2(1480, 820))
	var deck_ok := Profile.deck_valid(Profile.active_deck())
	vb.add_child(_label("Active deck: %s%s" % [Profile.data.decks[clampi(Profile.data.active_deck, 0, Profile.data.decks.size() - 1)].name, "" if deck_ok else "  (incomplete: Starter deck will be used)"], 16, Color("8fe08f") if deck_ok else Color("ffb070")))
	var ladder := HBoxContainer.new()
	vb.add_child(ladder)
	var lb := _button("⚔  Tavern Ladder duel vs a random rival  (rank %d · %s)" % [Profile.rank(), Profile.rank_title()], Color("6a4a20"), func():
		Game.start_duel("ladder:%d:%d" % [Profile.rank(), randi()]))
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ladder.add_child(lb)
	var next_reward := ""
	for r in range(Profile.rank() + 1, Profile.MAX_RANK + 1):
		var rw := Profile.rank_reward(r)
		if not rw.is_empty():
			next_reward = "Next reward at %s: 🐚 %d%s" % [Profile.rank_title(r), rw.shells, " + free pack" if rw.has("pack") else ""]
			break
	ladder.add_child(_label("   " + next_reward, 15, Color("c8bea8")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for ri in OpponentDB.REGIONS.size():
		var reg: Dictionary = OpponentDB.REGIONS[ri]
		var unlocked := Profile.region_unlocked(ri)
		var rp := PanelContainer.new()
		rp.add_theme_stylebox_override("panel", _style(Color(reg.color).darkened(0.82), Color(reg.color).darkened(0.2) if unlocked else Color(0.3, 0.3, 0.3)))
		list.add_child(rp)
		var rv := VBoxContainer.new()
		rp.add_child(rv)
		rv.add_child(_label(("" if unlocked else "🔒 ") + reg.name + "  —  " + reg.blurb, 20, Color(reg.color).lightened(0.2) if unlocked else Color(0.55, 0.55, 0.55)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rv.add_child(row)
		for oid in OpponentDB.in_region(reg.id):
			var o := OpponentDB.get_opponent(oid)
			var wins := Profile.campaign_wins(oid)
			var open_ok := Profile.opponent_unlocked(oid)
			var courts := ""
			for c in o.courts:
				courts += String(c).capitalize() + " "
			var txt := "%s%s\n%s\n%s\n🐚 %d  ·  reward: %s" % ["✔ " if wins > 0 else "", o.name, o.title, courts,
				o.shells, CardDB.get_card(o.reward_card).get("name", "-")]
			var b := _button(txt, Color("2a4a5a") if wins == 0 else Color("2a5a3a"), func(): Game.start_duel(oid))
			b.add_theme_font_size_override("font_size", 14)
			b.custom_minimum_size = Vector2(270, 110)
			b.disabled = not open_ok
			b.tooltip_text = o.intro
			row.add_child(b)


# ---------------------------------------------------------------- duel result (back in hub)

func show_duel_result(summary: Dictionary) -> void:
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open("result", summary)


func _build_result(s: Dictionary) -> void:
	var vb := _window("Back in the harbor", "", Vector2(620, 420))
	var o := OpponentDB.get_opponent(s.opponent_id)
	vb.add_child(_label(("You defeated %s!" if s.won else "%s got the better of you.") % o.get("name", "your rival"), 24, GOLD if s.won else Color("ff9a8a")))
	vb.add_child(_label("+%d Shells" % s.shells, 20))
	if s.has("bonus_pack"):
		vb.add_child(_label("Rank reward: a free %s!" % Profile.PACKS[s.bonus_pack].name, 18, Color("c9b6ff")))
		vb.add_child(_button("Open it now", Color("3a2a5a"), func():
			Profile.data.shells += Profile.PACKS[s.bonus_pack].price
			_buy_pack(s.bonus_pack)))
	if s.won and o.get("region", "") == "eclipse" and s.opponent_id == "moonwake" and s.first_win:
		vb.add_child(_label("You have conquered the Moonwake. You are the Tidewright of the harbor!", 20, Color("e0f0ff")))
	vb.add_child(_button("Continue", Color("2f6f4f"), close_all.bind(true)))
