extends SceneTree
func _init() -> void:
	_run()
func _run() -> void:
	await process_frame
	root.get_node("Profile").data.seen_intro = true
	root.get_node("Game").pending_opponent = "rosa"
	var d: Node = load("res://scenes/duel/duel.tscn").instantiate()
	root.add_child(d)
	current_scene = d
	await create_timer(2.5).timeout
	var helper := DuelAI.new(0, 0.7, 5)
	for r in 3:
		while d.busy:
			await process_frame
		for p in helper.plan(d.state):
			d.state.stage(0, p[0], p[1])
		d._sync()
		if r < 2:
			await d._on_end_turn()
	await create_timer(1.5).timeout
	var hand: Array = d.state.hands[0]
	if hand.size() > 0:
		d._select(hand[0])
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/moonwake_shots/duel_mine.png")
	quit()
