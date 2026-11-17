extends SceneTree
func _init() -> void:
	var wins := [0, 0, 0]
	for g in 40:
		var o0 := OpponentDB.get_opponent(OpponentDB.campaign_order()[g % 30])
		var o1 := OpponentDB.get_opponent(OpponentDB.campaign_order()[(g * 7) % 30])
		var st := DuelState.new()
		st.setup(o0.deck, o1.deck, g)
		var ais := [DuelAI.new(0, 0.6, g), DuelAI.new(1, 0.6, g + 99)]
		for r in DuelState.ROUNDS:
			st.start_round()
			for s in 2:
				for p in ais[s].plan(st):
					st.stage(s, p[0], p[1])
			st.begin_reveal()
			while st.reveal_next() != null:
				pass
			if not st.is_last_round():
				st.dusk()
		var res := st.result()
		wins[res.winner + 1] += 1
	print("draw/p0/p1: ", wins)
	print("cards: ", CardDB.all_ids().size(), " opps: ", OpponentDB.campaign_order().size())
	print(CardDB.get_card("grove_queen").text)
	quit()
