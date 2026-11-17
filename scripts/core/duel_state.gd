class_name DuelState
extends RefCounted
## Pure rules engine for a Moonwake duel. No nodes; the duel scene animates the
## events each step returns and re-syncs visuals from this state.
##
## Flow per round: start_round() -> both sides stage() cards -> begin_reveal() ->
## reveal_next() until it returns null -> (rounds 1-5) dusk() -> next round.
## After round ROUNDS reveals, result() decides the duel.

const SUN := 0
const MOON := 1
const ROUNDS := 6
const START_HAND := 4
const MAX_HAND := 8
const DEFAULT_CAP := 4
const MAX_STAKE := 8

var round := 0
var shrines: Array = []          # {id, sky, still}
var cards: Dictionary = {}       # uid -> {uid, id, side, sun, moon, shrine, revealed, order}
var hands: Array = [[], []]      # side -> Array[int uid]
var decks: Array = [[], []]      # side -> Array[String card id]; draw from back
var board: Array = []            # side -> shrine -> Array[int uid]
var glow: Array = [0, 0]
var glow_bonus: Array = [0, 0]
var staged: Array = [[], []]     # side -> Array[int uid] in staging order
var reveal_queue: Array = []
var stake := 1
var stake_pending := 1
var bell_rung: Array = [false, false]
var retreated := -1
var rng := RandomNumberGenerator.new()
var _uid := 1
var _order := 0
# Stats the meta layer reads for quests.
var stats := {"cards_played": [0, 0], "court_played": [{}, {}], "destroyed": [0, 0]}


func setup(deck0: Array, deck1: Array, seed_value: int, shrine_ids: Array = []) -> void:
	rng.seed = seed_value
	board = [[[], [], []], [[], [], []]]
	var ids: Array = shrine_ids if shrine_ids.size() == 3 else ShrineDB.random_set(rng)
	for i in 3:
		var def := ShrineDB.get_shrine(ids[i])
		shrines.append({"id": ids[i], "sky": rng.randi() % 2, "still": def.get("still", false)})
	# Never start with all three skies the same.
	if shrines[0].sky == shrines[1].sky and shrines[1].sky == shrines[2].sky:
		shrines[1].sky = 1 - shrines[1].sky
	for side in 2:
		var d: Array = (deck0 if side == 0 else deck1).duplicate()
		_shuffle(d)
		decks[side] = d
		for i in START_HAND:
			draw(side)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func clone() -> DuelState:
	var s := DuelState.new()
	s.round = round
	s.shrines = shrines.duplicate(true)
	s.cards = cards.duplicate(true)
	s.hands = hands.duplicate(true)
	s.decks = decks.duplicate(true)
	s.board = board.duplicate(true)
	s.glow = glow.duplicate()
	s.glow_bonus = glow_bonus.duplicate()
	s.staged = staged.duplicate(true)
	s.reveal_queue = reveal_queue.duplicate()
	s.stake = stake
	s.stake_pending = stake_pending
	s.rng.seed = rng.randi()
	s._uid = _uid
	s._order = _order
	return s


# ---------------------------------------------------------------- basics

func card_def(uid: int) -> Dictionary:
	return CardDB.get_card(cards[uid].id)


func new_card(id: String, side: int) -> int:
	var uid := _uid
	_uid += 1
	var d := CardDB.get_card(id)
	cards[uid] = {"uid": uid, "id": id, "side": side, "sun": d.sun, "moon": d.moon,
		"shrine": -1, "revealed": false, "order": 0}
	return uid


func draw(side: int) -> int:
	if decks[side].is_empty() or hands[side].size() >= MAX_HAND:
		return -1
	var uid := new_card(decks[side].pop_back(), side)
	hands[side].append(uid)
	return uid


func shrine_def(s: int) -> Dictionary:
	return ShrineDB.get_shrine(shrines[s].id)


func capacity(s: int) -> int:
	return shrine_def(s).get("cap", DEFAULT_CAP)


func free_slots(side: int, s: int) -> int:
	return capacity(s) - board[side][s].size()


func cost_of(uid: int, s: int) -> int:
	return maxi(0, card_def(uid).cost - shrine_def(s).get("discount", 0))


func can_stage(side: int, uid: int, s: int) -> bool:
	return uid in hands[side] and free_slots(side, s) > 0 and cost_of(uid, s) <= glow[side]


func revealed_at(side: int, s: int) -> Array:
	var out: Array = []
	for uid in board[side][s]:
		if cards[uid].revealed:
			out.append(uid)
	return out


func is_anchored(s: int) -> bool:
	if shrines[s].still:
		return true
	for side in 2:
		for uid in revealed_at(side, s):
			if CardDB.has_fx(card_def(uid), "o", "anchor"):
				return true
	return false


# ---------------------------------------------------------------- power

## Effective power of a card on the board. sky_override >= 0 evaluates as if the
## shrine had that sky (used by the AI to look ahead).
func power(uid: int, sky_override := -1) -> int:
	var c: Dictionary = cards[uid]
	var s: int = c.shrine
	if s < 0:
		return c.sun if (sky_override if sky_override >= 0 else SUN) == SUN else c.moon
	var sd := shrine_def(s)
	var sky: int = sky_override if sky_override >= 0 else shrines[s].sky
	var def := card_def(uid)
	var high: bool = sd.get("high", false) or CardDB.has_fx(def, "o", "high")
	var v: int = maxi(c.sun, c.moon) if high else (c.sun if sky == SUN else c.moon)
	if sd.has("skybonus") and sd.skybonus[0] == sky:
		v += sd.skybonus[1]
	if sd.get("court", "") == def.court:
		v += 2
	var allies := revealed_at(c.side, s)
	for e in def.fx:
		if e.when != "o":
			continue
		match e.type:
			"sky":
				if e.sky == sky:
					v += e.n
			"lone":
				if allies.size() == 1:
					v += e.n
			"crowd":
				v += (allies.size() - 1) * e.n
	for a in allies:
		if a == uid:
			continue
		for e in card_def(a).fx:
			if e.when == "o" and e.type == "aura":
				v += e.n
	for sh in 3:
		for a in revealed_at(c.side, sh):
			if a == uid:
				continue
			var ad := card_def(a)
			if ad.court != def.court:
				continue
			for e in ad.fx:
				if e.when == "o" and e.type == "courtaura":
					v += e.n
	return v


func shrine_power(side: int, s: int, sky_override := -1) -> int:
	var t := 0
	for uid in revealed_at(side, s):
		t += power(uid, sky_override)
	return t


## 0 = player leads, 1 = AI leads, -1 = tied.
func shrine_leader(s: int) -> int:
	var a := shrine_power(0, s)
	var b := shrine_power(1, s)
	if a == b:
		return -1
	return 0 if a > b else 1


# ---------------------------------------------------------------- round flow

func start_round() -> Array:
	var ev: Array = []
	round += 1
	stake = stake_pending
	bell_rung = [false, false]
	for side in 2:
		glow[side] = round + glow_bonus[side]
		glow_bonus[side] = 0
		staged[side] = []
		var uid := draw(side)
		if uid >= 0:
			ev.append({"t": "draw", "side": side, "uid": uid})
	return ev


func stage(side: int, uid: int, s: int) -> bool:
	if not can_stage(side, uid, s):
		return false
	glow[side] -= cost_of(uid, s)
	hands[side].erase(uid)
	cards[uid].shrine = s
	board[side][s].append(uid)
	staged[side].append(uid)
	return true


func unstage(side: int, uid: int) -> bool:
	if not uid in staged[side]:
		return false
	var s: int = cards[uid].shrine
	glow[side] += cost_of(uid, s)
	board[side][s].erase(uid)
	staged[side].erase(uid)
	cards[uid].shrine = -1
	hands[side].append(uid)
	return true


func ring_bell(side: int) -> bool:
	if bell_rung[side] or bell_rung[1 - side] or stake_pending >= MAX_STAKE or stake_pending != stake:
		return false
	bell_rung[side] = true
	stake_pending = mini(stake * 2, MAX_STAKE)
	return true


## Side that reveals first: whoever is winning more shrines; ties are random.
func first_revealer() -> int:
	var lead := [0, 0]
	for s in 3:
		var l := shrine_leader(s)
		if l >= 0:
			lead[l] += 1
	if lead[0] == lead[1]:
		return rng.randi() % 2
	return 0 if lead[0] > lead[1] else 1


func begin_reveal() -> int:
	var first := first_revealer()
	reveal_queue = staged[first].duplicate() + staged[1 - first].duplicate()
	return first


## Reveals one staged card. Returns its events, or null when the queue is empty.
func reveal_next() -> Variant:
	if reveal_queue.is_empty():
		return null
	var uid: int = reveal_queue.pop_front()
	return reveal_card(uid)


func reveal_card(uid: int) -> Array:
	var ev: Array = []
	var c: Dictionary = cards[uid]
	if c.shrine < 0 or not cards.has(uid):
		return ev
	c.revealed = true
	_order += 1
	c.order = _order
	stats.cards_played[c.side] += 1
	var def := card_def(uid)
	var cp: Dictionary = stats.court_played[c.side]
	cp[def.court] = cp.get(def.court, 0) + 1
	ev.append({"t": "reveal", "uid": uid})
	for e in def.fx:
		if e.when == "r":
			_apply_reveal(uid, e, ev)
	if shrine_def(c.shrine).get("restless", false) and cards.has(uid):
		_flip(c.shrine, ev)
	return ev


func _apply_reveal(uid: int, e: Dictionary, ev: Array) -> void:
	if not cards.has(uid):
		return
	var c: Dictionary = cards[uid]
	var side: int = c.side
	var foe := 1 - side
	var s: int = c.shrine
	var n: int = e.get("n", 0)
	match e.type:
		"burn":
			var t := _strongest(foe, s)
			if t >= 0:
				_mod(t, -n, -n, ev)
		"burnall":
			for t in revealed_at(foe, s):
				_mod(t, -n, -n, ev)
		"burnwide":
			for sh in 3:
				var t := _strongest(foe, sh)
				if t >= 0:
					_mod(t, -n, -n, ev)
		"boost":
			for t in revealed_at(side, s):
				if t != uid:
					_mod(t, n, n, ev)
		"rally":
			var court: String = card_def(uid).court
			for sh in 3:
				for t in revealed_at(side, sh):
					if t != uid and card_def(t).court == court:
						_mod(t, n, n, ev)
		"skyup":
			if shrines[s].sky == e.sky:
				_mod(uid, n, n, ev)
		"draw":
			for i in n:
				var d := draw(side)
				if d >= 0:
					ev.append({"t": "draw", "side": side, "uid": d})
		"glow":
			glow_bonus[side] += n
			ev.append({"t": "glow", "side": side, "n": n, "uid": uid})
		"summon":
			for i in n:
				if free_slots(side, s) <= 0:
					break
				var t := new_card(e.token, side)
				cards[t].shrine = s
				cards[t].revealed = true
				_order += 1
				cards[t].order = _order
				board[side][s].append(t)
				ev.append({"t": "summon", "uid": t})
		"slay":
			var t := _weakest(foe, s)
			if t >= 0:
				_destroy(t, ev)
		"push":
			var t := _strongest(foe, s)
			if t >= 0:
				_push(t, ev)
		"scatter":
			for t in revealed_at(foe, s):
				_push(t, ev)
		"swap":
			for sd in 2:
				for t in revealed_at(sd, s):
					var cc: Dictionary = cards[t]
					var tmp: int = cc.sun
					cc.sun = cc.moon
					cc.moon = tmp
					ev.append({"t": "swap", "uid": t})
		"leech":
			var t := _strongest(foe, s)
			if t >= 0:
				_mod(t, -n, -n, ev)
				_mod(uid, n, n, ev)
		"hand":
			for t in hands[side]:
				_mod(t, n, n, ev)
		"still":
			shrines[s].still = true
			ev.append({"t": "still", "shrine": s})
		"devour":
			var best := -1
			var best_p := 9999
			for t in revealed_at(side, s):
				if t != uid and power(t) < best_p:
					best_p = power(t)
					best = t
			if best >= 0:
				var tc: Dictionary = cards[best]
				_destroy(best, ev)
				_mod(uid, maxi(tc.sun, 0), maxi(tc.moon, 0), ev)
		"conjure":
			if hands[side].size() < MAX_HAND:
				var t := new_card(e.card, side)
				hands[side].append(t)
				ev.append({"t": "draw", "side": side, "uid": t})
		"mirror":
			var t := _strongest(foe, s)
			if t >= 0:
				var tc: Dictionary = cards[t]
				var ds: int = tc.sun - c.sun
				var dm: int = tc.moon - c.moon
				_mod(uid, ds, dm, ev)
		"flip":
			_flip(s, ev)
		"flipother":
			for sh in 3:
				if sh != s:
					_flip(sh, ev)
		"dawn", "night":
			var target := SUN if e.type == "dawn" else MOON
			for sh in 3:
				if shrines[sh].sky != target:
					shrines[sh].sky = target
					ev.append({"t": "flip", "shrine": sh})
					_on_flipped(sh, ev)


func _mod(uid: int, ds: int, dm: int, ev: Array) -> void:
	if not cards.has(uid):
		return
	cards[uid].sun += ds
	cards[uid].moon += dm
	ev.append({"t": "buff", "uid": uid, "n": ds if ds != 0 else dm})


func _strongest(side: int, s: int) -> int:
	var best := -1
	var bp := -9999
	for t in revealed_at(side, s):
		var p := power(t)
		if p > bp:
			bp = p
			best = t
	return best


func _weakest(side: int, s: int) -> int:
	var best := -1
	var bp := 9999
	for t in revealed_at(side, s):
		var p := power(t)
		if p < bp:
			bp = p
			best = t
	return best


func _destroy(uid: int, ev: Array) -> void:
	var c: Dictionary = cards[uid]
	board[c.side][c.shrine].erase(uid)
	reveal_queue.erase(uid)
	stats.destroyed[c.side] += 1
	ev.append({"t": "destroy", "uid": uid, "side": c.side, "shrine": c.shrine})
	cards.erase(uid)


## Moves a card to another shrine on its own side with room. Returns success.
func _push(uid: int, ev: Array) -> bool:
	var c: Dictionary = cards[uid]
	var options: Array = []
	for sh in 3:
		if sh != c.shrine and free_slots(c.side, sh) > 0:
			options.append(sh)
	if options.is_empty():
		return false
	var to: int = options[rng.randi() % options.size()]
	var from: int = c.shrine
	board[c.side][from].erase(uid)
	board[c.side][to].append(uid)
	c.shrine = to
	ev.append({"t": "move", "uid": uid, "from": from, "to": to})
	for e in card_def(uid).fx:
		if e.when == "m":
			_mod(uid, e.n, e.n, ev)
	return true


func _flip(s: int, ev: Array) -> void:
	if is_anchored(s):
		ev.append({"t": "flip_blocked", "shrine": s})
		return
	shrines[s].sky = 1 - shrines[s].sky
	ev.append({"t": "flip", "shrine": s})
	_on_flipped(s, ev)


func _on_flipped(s: int, ev: Array) -> void:
	for side in 2:
		for t in revealed_at(side, s):
			for e in card_def(t).fx:
				if e.when == "d" and e.type == "tidal":
					_mod(t, e.n, e.n, ev)


# ---------------------------------------------------------------- dusk

## End of rounds 1..ROUNDS-1: dusk abilities, shrine blessings, skies turn, drifting.
func dusk() -> Array:
	var ev: Array = []
	var drifters: Array = []
	for s in 3:
		var sd := shrine_def(s)
		for side in 2:
			for uid in revealed_at(side, s):
				if not cards.has(uid):
					continue
				for e in card_def(uid).fx:
					if e.when != "d":
						continue
					var n: int = e.get("n", 0)
					match e.type:
						"grow":
							_mod(uid, n, n, ev)
						"growsky":
							if shrines[s].sky == SUN:
								_mod(uid, n, 0, ev)
							else:
								_mod(uid, 0, n, ev)
						"fade":
							_mod(uid, -n, -n, ev)
						"rouse":
							for t in revealed_at(side, s):
								if t != uid:
									_mod(t, n, n, ev)
						"burn":
							var foes := revealed_at(1 - side, s)
							if not foes.is_empty():
								_mod(foes[rng.randi() % foes.size()], -n, -n, ev)
						"drift":
							drifters.append(uid)
			if sd.get("bonfire", false):
				for uid in revealed_at(side, s):
					_mod(uid, 1, 1, ev)
		if sd.get("whirlpool", false):
			for side in 2:
				var w := _weakest(side, s)
				if w >= 0:
					_destroy(w, ev)
	for s in 3:
		_flip(s, ev)
	for uid in drifters:
		if cards.has(uid):
			_push(uid, ev)
	return ev


func is_last_round() -> bool:
	return round >= ROUNDS


# ---------------------------------------------------------------- result

## {winner: 0/1/-1, shrines: [winner per shrine], totals: [p0, p1], stake}
func result() -> Dictionary:
	if retreated >= 0:
		return {"winner": 1 - retreated, "shrines": [-1, -1, -1], "totals": [0, 0],
			"stake": stake, "retreat": retreated}
	var won := [0, 0]
	var per: Array = []
	var totals := [0, 0]
	for s in 3:
		var l := shrine_leader(s)
		per.append(l)
		if l >= 0:
			won[l] += 1
		totals[0] += shrine_power(0, s)
		totals[1] += shrine_power(1, s)
	var winner := -1
	if won[0] != won[1]:
		winner = 0 if won[0] > won[1] else 1
	elif totals[0] != totals[1]:
		winner = 0 if totals[0] > totals[1] else 1
	return {"winner": winner, "shrines": per, "totals": totals, "stake": stake_pending, "retreat": -1}
