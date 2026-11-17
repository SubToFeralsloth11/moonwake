extends Node
## Persistent player profile: currencies, collection, decks, campaign, ladder,
## quests, cosmetics. Saved to user://moonwake_save.json after every change.

signal changed
signal toast(text: String, color: Color)

const SAVE_PATH := "user://moonwake_save.json"
const RENOWN_PER_RANK := 6
const MAX_RANK := 50
const RANK_TITLES := ["Deckhand", "Bosun", "Navigator", "Captain", "Admiral", "Tidewright"]

const STARTER := ["ember_imp", "ember_pup", "ember_torch", "tide_crab", "tide_minnow", "tide_diver",
	"grove_mossling", "grove_beetle", "grove_stag", "gale_swallow", "gale_sprite", "wild_golem"]

const PACKS := {
	"harbor": {"name": "Harbor Pack", "price": 100, "court": "", "desc": "5 cards from any court. At least one Rare or better.", "guarantee": 1, "boost": 0.0},
	"ember": {"name": "Ember Pack", "price": 140, "court": "ember", "desc": "5 Ember Court cards. At least one Rare or better.", "guarantee": 1, "boost": 0.0},
	"tide": {"name": "Tide Pack", "price": 140, "court": "tide", "desc": "5 Tide Court cards. At least one Rare or better.", "guarantee": 1, "boost": 0.0},
	"grove": {"name": "Grove Pack", "price": 140, "court": "grove", "desc": "5 Grove Court cards. At least one Rare or better.", "guarantee": 1, "boost": 0.0},
	"gale": {"name": "Gale Pack", "price": 140, "court": "gale", "desc": "5 Gale Court cards. At least one Rare or better.", "guarantee": 1, "boost": 0.0},
	"moonlit": {"name": "Moonlit Pack", "price": 450, "court": "", "desc": "5 cards. Two Epic or better, high Mythic chance.", "guarantee": 2, "boost": 0.12},
}

const CARD_BACKS := {
	"classic": {"name": "Harbor Classic", "price": 0, "a": Color("1d2b4a"), "b": Color("d9b46a")},
	"ember": {"name": "Forge Flame", "price": 250, "a": Color("4a120a"), "b": Color("ff8a3d")},
	"tide": {"name": "Deep Current", "price": 250, "a": Color("082a4a"), "b": Color("5fd0ff")},
	"grove": {"name": "Mossy Bark", "price": 250, "a": Color("1a3a16"), "b": Color("9be070")},
	"gale": {"name": "Cloudsail", "price": 250, "a": Color("2a2650"), "b": Color("e6dcff")},
	"starry": {"name": "Starry Night", "price": 600, "a": Color("0a0a20"), "b": Color("ffffff")},
	"royal": {"name": "Royal Eclipse", "price": 1200, "a": Color("2a0a2a"), "b": Color("ffd166")},
}

const QUEST_TEMPLATES := [
	{"id": "win2", "text": "Win 2 duels", "goal": 2, "reward": 60},
	{"id": "play20", "text": "Play 20 cards", "goal": 20, "reward": 50},
	{"id": "play_ember", "text": "Play 8 Ember cards", "goal": 8, "reward": 50, "court": "ember"},
	{"id": "play_tide", "text": "Play 8 Tide cards", "goal": 8, "reward": 50, "court": "tide"},
	{"id": "play_grove", "text": "Play 8 Grove cards", "goal": 8, "reward": 50, "court": "grove"},
	{"id": "play_gale", "text": "Play 8 Gale cards", "goal": 8, "reward": 50, "court": "gale"},
	{"id": "bell", "text": "Win a duel after the Moon Bell rang", "goal": 1, "reward": 70},
	{"id": "sweep", "text": "Win all 3 shrines in one duel", "goal": 1, "reward": 90},
	{"id": "destroy3", "text": "Destroy 3 enemy cards", "goal": 3, "reward": 50},
	{"id": "pack", "text": "Open a pack", "goal": 1, "reward": 40},
	{"id": "ladder3", "text": "Play 3 Tavern Ladder duels", "goal": 3, "reward": 60},
]

var data: Dictionary = {}


func _ready() -> void:
	load_game()
	refresh_quests()


func _default() -> Dictionary:
	var col := {}
	for id in STARTER:
		col[id] = col.get(id, 0) + 1
	return {
		"version": 1, "shells": 300, "glimmer": 0, "renown": 0, "best_rank": 0, "claimed_ranks": [],
		"collection": col, "decks": [{"name": "Starter Tides", "cards": STARTER.duplicate()}],
		"active_deck": 0, "campaign": {}, "card_backs": ["classic"], "card_back": "classic",
		"quests": {"date": "", "list": []}, "milestones": 0, "seen_intro": false,
		"stats": {"duels": 0, "wins": 0, "cards_played": 0, "packs": 0, "best_stake": 1},
		"settings": {"volume": 0.8, "sensitivity": 1.0},
	}


func load_game() -> void:
	data = _default()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]
		# JSON numbers come back as floats.
		for id in data.collection:
			data.collection[id] = int(data.collection[id])
		for k in ["shells", "glimmer", "renown", "best_rank", "active_deck", "milestones"]:
			data[k] = int(data[k])


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	changed.emit()


func reset_save() -> void:
	data = _default()
	refresh_quests()
	save_game()


# ---------------------------------------------------------------- currency

func shells() -> int:
	return data.shells


func glimmer() -> int:
	return data.glimmer


func add_shells(n: int) -> void:
	data.shells += n
	save_game()


func spend_shells(n: int) -> bool:
	if data.shells < n:
		return false
	data.shells -= n
	save_game()
	return true


# ---------------------------------------------------------------- collection

func owned(id: String) -> int:
	return int(data.collection.get(id, 0))


func unique_owned() -> int:
	var n := 0
	for id in data.collection:
		if data.collection[id] > 0 and not CardDB.get_card(id).is_empty():
			n += 1
	return n


## Adds a card. Copies beyond the cap become Glimmer. Returns glimmer gained.
func add_card(id: String) -> int:
	var c := CardDB.get_card(id)
	if c.is_empty():
		return 0
	if owned(id) >= CardDB.MAX_COPIES[c.rarity]:
		var g: int = CardDB.DUST_VALUE[c.rarity]
		data.glimmer += g
		return g
	data.collection[id] = owned(id) + 1
	_check_milestones()
	return 0


func _check_milestones() -> void:
	var reached := unique_owned() / 10
	while data.milestones < reached:
		data.milestones += 1
		var reward: int = 100 + data.milestones * 25
		data.shells += reward
		data.glimmer += 30 * data.milestones
		toast.emit("Collector milestone %d: %d unique cards!  +%d Shells" % [data.milestones, data.milestones * 10, reward], Color("ffd166"))


func craft(id: String) -> bool:
	var c := CardDB.get_card(id)
	if c.is_empty() or owned(id) >= CardDB.MAX_COPIES[c.rarity]:
		return false
	var cost: int = CardDB.CRAFT_COST[c.rarity]
	if data.glimmer < cost:
		return false
	data.glimmer -= cost
	data.collection[id] = owned(id) + 1
	_check_milestones()
	save_game()
	return true


## Breaks one copy into Glimmer, removing it from decks that can no longer hold it.
func disenchant(id: String) -> bool:
	var c := CardDB.get_card(id)
	if owned(id) <= 0:
		return false
	data.collection[id] = owned(id) - 1
	data.glimmer += CardDB.DUST_VALUE[c.rarity]
	for deck in data.decks:
		while deck.cards.count(id) > owned(id):
			deck.cards.erase(id)
	save_game()
	return true


func roll_rarity(rng: RandomNumberGenerator, boost: float, min_rarity: int) -> int:
	var r := rng.randf()
	var rarity := CardDB.Rarity.COMMON
	if r < 0.015 + boost * 0.6:
		rarity = CardDB.Rarity.MYTHIC
	elif r < 0.09 + boost * 1.6:
		rarity = CardDB.Rarity.EPIC
	elif r < 0.33 + boost:
		rarity = CardDB.Rarity.RARE
	return maxi(rarity, min_rarity)


## Buys and opens a pack. Returns [{id, new: bool, glimmer: int}] or [] if unaffordable.
func open_pack(pack_id: String) -> Array:
	var p: Dictionary = PACKS[pack_id]
	if not spend_shells(p.price):
		return []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out: Array = []
	for i in 5:
		var min_r := CardDB.Rarity.COMMON
		if i >= 5 - p.guarantee:
			min_r = CardDB.Rarity.RARE if p.guarantee == 1 else CardDB.Rarity.EPIC
		var rarity := roll_rarity(rng, p.boost, min_r)
		var pool := CardDB.ids_by(p.court, rarity)
		if pool.is_empty():
			pool = CardDB.ids_by(p.court)
		var id: String = pool[rng.randi() % pool.size()]
		var was_new := owned(id) == 0
		var g := add_card(id)
		out.append({"id": id, "new": was_new, "glimmer": g})
	data.stats.packs += 1
	quest_event("pack", 1)
	save_game()
	return out


# ---------------------------------------------------------------- decks

func decks() -> Array:
	return data.decks


func active_deck() -> Array:
	var i: int = clampi(data.active_deck, 0, data.decks.size() - 1)
	return data.decks[i].cards


func deck_valid(cards: Array) -> bool:
	if cards.size() != CardDB.DECK_SIZE:
		return false
	for id in cards:
		if cards.count(id) > owned(id):
			return false
	return true


# ---------------------------------------------------------------- campaign

func campaign_wins(opp_id: String) -> int:
	return int(data.campaign.get(opp_id, 0))


func region_unlocked(region_index: int) -> bool:
	if region_index == 0:
		return true
	var prev: String = OpponentDB.REGIONS[region_index - 1].id
	for id in OpponentDB.in_region(prev):
		if campaign_wins(id) == 0:
			return false
	return true


func opponent_unlocked(opp_id: String) -> bool:
	var o := OpponentDB.get_opponent(opp_id)
	var ri := 0
	for i in OpponentDB.REGIONS.size():
		if OpponentDB.REGIONS[i].id == o.region:
			ri = i
	if not region_unlocked(ri):
		return false
	var ids := OpponentDB.in_region(o.region)
	var idx := ids.find(opp_id)
	return idx == 0 or campaign_wins(ids[idx - 1]) > 0


func campaign_progress() -> Vector2i:
	var done := 0
	for id in OpponentDB.campaign_order():
		if campaign_wins(id) > 0:
			done += 1
	return Vector2i(done, OpponentDB.campaign_order().size())


# ---------------------------------------------------------------- ladder

func rank() -> int:
	return clampi(data.renown / RENOWN_PER_RANK, 0, MAX_RANK)


func rank_title(r: int = -1) -> String:
	if r < 0:
		r = rank()
	if r >= MAX_RANK:
		return "Tidewright"
	return "%s %s" % [RANK_TITLES[r / 10], ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][r % 10]]


func rank_reward(r: int) -> Dictionary:
	if r <= 0 or r % 5 != 0:
		return {}
	if r % 10 == 0:
		return {"shells": 150 + r * 10, "pack": "moonlit" if r >= 30 else "harbor"}
	return {"shells": 100 + r * 6}


# ---------------------------------------------------------------- duel results

## Applies a finished duel. Returns a summary dict for the result screen.
func apply_duel(opp: Dictionary, res: Dictionary, duel_stats: Dictionary) -> Dictionary:
	var won: bool = res.winner == 0
	var stake: int = res.stake
	var summary := {"won": won, "draw": res.winner == -1, "stake": stake, "shells": 0,
		"glimmer": 0, "cards": [], "first_win": false, "renown": 0, "rank_up": [],
		"opponent_id": opp.id, "retreat": res.get("retreat", -1)}
	data.stats.duels += 1
	data.stats.cards_played += duel_stats.cards_played[0]
	for court in duel_stats.court_played[0]:
		quest_event("play_" + court, duel_stats.court_played[0][court])
	quest_event("play20", duel_stats.cards_played[0])
	quest_event("destroy3", duel_stats.destroyed[1])
	if opp.ladder:
		quest_event("ladder3", 1)
	if won:
		data.stats.wins += 1
		data.stats.best_stake = maxi(int(data.stats.best_stake), stake)
		quest_event("win2", 1)
		if stake >= 2:
			quest_event("bell", 1)
		if res.shrines.count(0) == 3:
			quest_event("sweep", 1)
		summary.shells = opp.shells * stake if not opp.ladder else opp.shells * stake
		if not opp.ladder:
			if campaign_wins(opp.id) == 0:
				summary.first_win = true
				summary.shells += opp.shells
				if opp.reward_card != "":
					var g := add_card(opp.reward_card)
					summary.cards.append(opp.reward_card)
					summary.glimmer += g
			else:
				summary.shells = int(summary.shells * 0.5)
			data.campaign[opp.id] = campaign_wins(opp.id) + 1
	elif res.winner == 1:
		summary.shells = 10
	else:
		summary.shells = 20
	if opp.ladder and res.winner != -1:
		var before := rank()
		var delta: int = stake * 2 if won else -stake
		data.renown = maxi(0, data.renown + delta)
		summary.renown = delta
		var after := rank()
		for r in range(before + 1, after + 1):
			if r > data.best_rank and not (r in data.claimed_ranks):
				data.claimed_ranks.append(r)
				var rw := rank_reward(r)
				summary.rank_up.append(r)
				if rw.has("shells"):
					summary.shells += rw.shells
				if rw.has("pack"):
					summary["bonus_pack"] = rw.pack
		data.best_rank = maxi(data.best_rank, after)
	data.shells += summary.shells
	data.glimmer += summary.glimmer
	save_game()
	return summary


# ---------------------------------------------------------------- quests

func refresh_quests() -> void:
	var today := Time.get_date_string_from_system()
	if data.quests.get("date", "") == today and not data.quests.list.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool := QUEST_TEMPLATES.duplicate()
	var list: Array = []
	while list.size() < 3 and not pool.is_empty():
		var q: Dictionary = pool.pop_at(rng.randi() % pool.size())
		list.append({"id": q.id, "text": q.text, "goal": q.goal, "reward": q.reward, "progress": 0, "done": false})
	data.quests = {"date": today, "list": list}
	save_game()


func quest_event(id: String, amount: int) -> void:
	for q in data.quests.list:
		if q.id == id and not q.done:
			q.progress = mini(int(q.progress) + amount, int(q.goal))
			if q.progress >= q.goal:
				q.done = true
				data.shells += int(q.reward)
				toast.emit("Quest complete: %s  +%d Shells" % [q.text, q.reward], Color("8fe08f"))


# ---------------------------------------------------------------- cosmetics

func buy_card_back(id: String) -> bool:
	if id in data.card_backs:
		return false
	if not spend_shells(CARD_BACKS[id].price):
		return false
	data.card_backs.append(id)
	data.card_back = id
	save_game()
	return true


func set_card_back(id: String) -> void:
	if id in data.card_backs:
		data.card_back = id
		save_game()
