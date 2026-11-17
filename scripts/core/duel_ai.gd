class_name DuelAI
extends RefCounted
## Greedy look-ahead AI. skill 0..1: higher = less noise, smarter bell use.

var side := 1
var skill := 0.5
var rng := RandomNumberGenerator.new()


func _init(p_side := 1, p_skill := 0.5, seed_value := 0) -> void:
	side = p_side
	skill = p_skill
	rng.seed = seed_value


## Returns staged plays as [[uid, shrine], ...] for this round. Must be called
## before the human stages anything (the AI never peeks at hidden cards).
func plan(state: DuelState) -> Array:
	var sim := _hide_enemy(state)
	var plays: Array = []
	var noise := (1.0 - skill) * 1.6
	for _i in 8:
		var base := evaluate(sim)
		var best: Array = []
		var best_score := -0.05
		for uid in sim.hands[side]:
			for s in 3:
				if not sim.can_stage(side, uid, s):
					continue
				var trial := sim.clone()
				trial.stage(side, uid, s)
				trial.reveal_card(uid)
				var sc := evaluate(trial) - base
				sc += sim.cost_of(uid, s) * 0.04 + rng.randf_range(-noise, noise) * 0.5
				if sc > best_score:
					best_score = sc
					best = [uid, s]
		if best.is_empty():
			break
		sim.stage(side, best[0], best[1])
		sim.reveal_card(best[0])
		plays.append(best)
	return plays


func _hide_enemy(state: DuelState) -> DuelState:
	var sim := state.clone()
	var foe := 1 - side
	for uid in sim.staged[foe].duplicate():
		sim.unstage(foe, uid)
	return sim


## Positive = good for this AI side.
func evaluate(state: DuelState) -> float:
	var dusks_left := DuelState.ROUNDS - state.round
	var score := 0.0
	for s in 3:
		var sky: int = state.shrines[s].sky
		if not state.is_anchored(s) and dusks_left % 2 == 1:
			sky = 1 - sky
		var mine := _projected(state, side, s, sky, dusks_left)
		var theirs := _projected(state, 1 - side, s, sky, dusks_left)
		score += tanh((mine - theirs) / 5.0) * 3.0
	score += state.hands[side].size() * 0.08
	return score


func _projected(state: DuelState, sd: int, s: int, sky: int, dusks_left: int) -> float:
	var t := 0.0
	for uid in state.revealed_at(sd, s):
		t += state.power(uid, sky)
		for e in state.card_def(uid).fx:
			if e.when == "d":
				match e.type:
					"grow", "tidal", "growsky":
						t += e.n * dusks_left * 0.8
					"rouse":
						t += e.n * dusks_left * 0.6 * (state.revealed_at(sd, s).size() - 1)
					"fade":
						t -= e.n * dusks_left
	return t


## Should the AI ring the Moon Bell this round (after planning)?
func wants_bell(state: DuelState) -> bool:
	if state.round < 2:
		return false
	var e := evaluate(_hide_enemy(state))
	return e > 3.2 - skill * 1.2 and rng.randf() < 0.35 + skill * 0.4


## After a round resolves where the human rang the bell: fold?
func wants_retreat(state: DuelState) -> bool:
	if state.round < 2 or state.stake_pending <= 1:
		return false
	return evaluate(state) < -4.5 + (1.0 - skill) * -1.5
