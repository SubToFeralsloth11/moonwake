extends SceneTree
## Headless: load the duel, auto-play the player side with the AI, until the result screen.
func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	root.get_node("Game").pending_opponent = "harbormaster"
	var d: Node = load("res://scenes/duel/duel.tscn").instantiate()
	root.add_child(d)
	current_scene = d
	var helper := DuelAI.new(0, 0.7, 5)
	var t := 0
	while not d.over and t < 400000:
		await process_frame
		t += 1
		if not d.busy and not d.over:
			for p in helper.plan(d.state):
				d.state.stage(0, p[0], p[1])
			d._sync()
			if d.state.round == 3:
				d._on_bell()
			d._on_end_turn()
	print("ROUND ", d.state.round, " OVER ", d.over, " RESULT ", d.state.result())
	await create_timer(2.0).timeout
	print("SHELLS ", root.get_node("Profile").shells(), " DUELS ", root.get_node("Profile").data.stats.duels)
	quit()
