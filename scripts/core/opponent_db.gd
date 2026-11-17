class_name OpponentDB
extends RefCounted
## Campaign: 6 regions x 5 challengers. Plus generated Tavern Ladder rivals.

const REGIONS := [
	{"id": "harbor", "name": "The Harbor Steps", "blurb": "Dockhands and dreamers who play for pocket change.", "color": Color("ffd166")},
	{"id": "ember", "name": "Emberreach Forge", "blurb": "Smiths who play hot and fast under the noon sun.", "color": Color("ff6a3d")},
	{"id": "tide", "name": "Tidehollow Grotto", "blurb": "Sea folk who drag every shrine into the night.", "color": Color("3da5ff")},
	{"id": "grove", "name": "The Grovewild", "blurb": "Patient gardeners. Their decks grow while you wait.", "color": Color("5cd16a")},
	{"id": "gale", "name": "Galespire Heights", "blurb": "Sky sailors who never leave a card where you left it.", "color": Color("c9b6ff")},
	{"id": "eclipse", "name": "The Eclipse Court", "blurb": "Masters of every court. The final tide.", "color": Color("e0e0ff")},
]

# id, name, title, region, courts, level 0-5, skill, look, signature cards, shells, reward card, intro, taunt-on-win, line-on-loss
const RAW := [
	["pip", "Pip Barnacle", "Dock Runner", "harbor", ["wild", "grove"], 0, 0.15,
		{"coat": Color("6b4f3a"), "accent": Color("e0c080"), "hat": "bandana", "hair": Color("c86a3a"), "body": "slim", "scale": 0.85},
		[], 40, "wild_lantern", "First time at the table? Don't worry, I'll go easy. Probably.", "Ha! Beginner's luck is MINE.", "Aw, barnacles..."],
	["mabel", "Mabel Quill", "Ferry Clerk", "harbor", ["tide", "wild"], 0, 0.22,
		{"coat": Color("3a5a7a"), "accent": Color("f0e0c0"), "hat": "none", "hair": Color("402818"), "body": "normal"},
		[], 50, "tide_diver", "Tickets, please. Or cards. Cards are fine.", "Stamped and filed: a win for me.", "Well, I'll file that under 'loss'."],
	["gus", "Old Gus", "Net Mender", "harbor", ["grove", "tide"], 1, 0.28,
		{"coat": Color("5a6a4a"), "accent": Color("b0a080"), "hat": "flower", "hair": Color("d8d8d8"), "beard": true, "body": "stout"},
		[], 60, "grove_owl", "Sixty years mending nets. Patience wins, lad.", "Slow and steady.", "Ho! You've got the tide in you."],
	["rosa", "Rosa Vell", "Lamplighter", "harbor", ["ember", "wild"], 1, 0.32,
		{"coat": Color("8a3a2a"), "accent": Color("ffc060"), "hat": "tricorn", "hair": Color("201010"), "body": "slim"},
		[], 70, "ember_torch", "I light every lantern on this harbor. I'll light you up too.", "Lights out.", "You burn brighter than I thought."],
	["harbormaster", "Harbormaster Brine", "Keeper of the Steps", "harbor", ["tide", "ember", "wild"], 2, 0.4,
		{"coat": Color("1f3550"), "accent": Color("ffd166"), "hat": "captain", "hair": Color("707070"), "beard": true, "body": "stout", "scale": 1.08},
		["wild_twins", "tide_keeper"], 150, "wild_twins", "Nobody leaves this harbor without beating me first.", "Back to the docks with you.", "Very well. The world beyond the harbor is yours."],
	["cinder", "Cinder Sal", "Bellows Girl", "ember", ["ember"], 1, 0.35,
		{"coat": Color("a04020"), "accent": Color("ffa040"), "hat": "bandana", "hair": Color("ff7030"), "body": "slim", "scale": 0.92},
		[], 80, "ember_moth", "Pump, pump, pump! Feel the heat?", "Toasty!", "You put my fire out..."],
	["anvil", "Brakk Anvilhand", "Journeyman Smith", "ember", ["ember", "wild"], 2, 0.42,
		{"coat": Color("4a3020"), "accent": Color("d08040"), "hat": "none", "hair": Color("201008"), "beard": true, "body": "stout"},
		[], 90, "ember_forgehand", "Hammer meets anvil. You're the anvil.", "Forged.", "Hmph. Good steel, you."],
	["sola", "Sister Sola", "Noonsinger", "ember", ["ember", "grove"], 2, 0.48,
		{"coat": Color("f0e0b0"), "accent": Color("ff9020"), "hat": "hood", "hair": Color("f0c060"), "body": "slim"},
		["ember_dancer"], 100, "ember_dancer", "The noon sun blesses only the faithful.", "Praise the noon.", "The sun sets on me today."],
	["vulk", "Vulkara", "Flame Duelist", "ember", ["ember", "gale"], 3, 0.55,
		{"coat": Color("301010"), "accent": Color("ff4020"), "hat": "tricorn", "hair": Color("ff3010"), "body": "normal"},
		["ember_flarecaller", "ember_hound"], 120, "ember_flarecaller", "Every card I play is a spark. Every spark, a fire.", "Ashes.", "Impressive. Truly."],
	["forgemother", "The Forgemother", "Queen of Emberreach", "ember", ["ember"], 4, 0.65,
		{"coat": Color("5a1a0a"), "accent": Color("ffb030"), "hat": "crown", "hair": Color("e8e8e8"), "body": "stout", "scale": 1.12},
		["ember_solara", "ember_warlord", "ember_furnace"], 300, "ember_solara", "Kneel before the furnace, child. Or melt.", "Back to the slag heap.", "The forge... bows to you."],
	["shelly", "Shelly Finn", "Pearl Hunter", "tide", ["tide"], 2, 0.45,
		{"coat": Color("2a6a8a"), "accent": Color("f0f0f0"), "hat": "flower", "hair": Color("3a2010"), "body": "slim"},
		[], 100, "tide_eel", "Hold your breath, we're going deep.", "Found a pearl: your loss!", "Glub."],
	["morrow", "Captain Morrow", "Drowned Sailor", "tide", ["tide", "ember"], 2, 0.5,
		{"coat": Color("2a3a3a"), "accent": Color("80c0b0"), "hat": "tricorn", "hair": Color("304040"), "beard": true, "body": "normal"},
		["tide_pirate"], 110, "tide_pirate", "My ship sank. My luck didn't.", "Davy Jones sends his regards.", "Back to the depths for me..."],
	["nerissa", "Nerissa", "Siren of the Grotto", "tide", ["tide", "wild"], 3, 0.55,
		{"coat": Color("1a4a6a"), "accent": Color("a0e0ff"), "hat": "none", "hair": Color("40a0c0"), "body": "slim"},
		["tide_siren", "tide_merrow"], 130, "tide_merrow", "Listen to my song... and turn the sky.", "Lost at sea, darling.", "Such a strong will."],
	["oracle", "Old Mother Foam", "Tide Oracle", "tide", ["tide", "grove"], 3, 0.62,
		{"coat": Color("506a80"), "accent": Color("e0f0ff"), "hat": "hood", "hair": Color("e0e0e0"), "body": "stout"},
		["tide_oracle", "tide_maelstrom"], 150, "tide_oracle", "I've already read how this ends.", "As foretold.", "The foam lied to me!"],
	["leviathan", "Admiral Leviathan", "Lord of Tidehollow", "tide", ["tide"], 4, 0.7,
		{"coat": Color("0a1a3a"), "accent": Color("40e0ff"), "hat": "captain", "hair": Color("102030"), "beard": true, "body": "stout", "scale": 1.15},
		["tide_luna", "tide_leviathan", "tide_kraken"], 320, "tide_luna", "The moon answers to ME.", "Sink.", "The tide... has turned."],
	["fennel", "Fennel", "Mushroom Picker", "grove", ["grove"], 3, 0.5,
		{"coat": Color("6a8a3a"), "accent": Color("f0d080"), "hat": "flower", "hair": Color("a06030"), "body": "slim", "scale": 0.9},
		[], 120, "grove_glowcap", "Shh, the mushrooms are listening.", "The mushrooms approve.", "The mushrooms are... disappointed."],
	["bramble", "Bramble Thorne", "Hedge Warden", "grove", ["grove", "ember"], 3, 0.56,
		{"coat": Color("3a4a20"), "accent": Color("c04040"), "hat": "hood", "hair": Color("402010"), "beard": true, "body": "normal"},
		["grove_badger", "grove_vine"], 130, "grove_badger", "Mind the thorns.", "Pricked you.", "Fine. You may pass the hedge."],
	["willa", "Willa Weep", "Willow Keeper", "grove", ["grove", "tide"], 4, 0.6,
		{"coat": Color("4a6a5a"), "accent": Color("d0f0d0"), "hat": "none", "hair": Color("90c090"), "body": "slim"},
		["grove_willow", "grove_druid"], 150, "grove_willow", "Sit beneath my branches a while. A long while.", "Rest now.", "*sniff* well played."],
	["hive", "The Hive Twins", "Beekeepers", "grove", ["grove", "wild"], 4, 0.66,
		{"coat": Color("d0a020"), "accent": Color("302010"), "hat": "wizard", "hair": Color("f0d060"), "body": "normal"},
		["grove_queen", "grove_mother"], 170, "grove_queen", "Bzzz. We are many. You are one.", "Swarmed!", "The hive... retreats."],
	["yggra", "Elder Rootheart", "Voice of the Grovewild", "grove", ["grove"], 5, 0.74,
		{"coat": Color("2a3a1a"), "accent": Color("80ff80"), "hat": "crown", "hair": Color("5a7a3a"), "beard": true, "body": "stout", "scale": 1.15},
		["grove_yggra", "grove_oak", "grove_bloom"], 340, "grove_yggra", "Roots older than your harbor. Let us see you grow.", "Return to the soil.", "A new sapling rises."],
	["kit", "Kit Skylark", "Kite Flyer", "gale", ["gale"], 3, 0.55,
		{"coat": Color("a0b0e0"), "accent": Color("ffffff"), "hat": "bandana", "hair": Color("f0e0a0"), "body": "slim", "scale": 0.88},
		[], 140, "gale_kite", "Catch me if you can!", "Whoooosh!", "You caught the wind!"],
	["vane", "Mistress Vane", "Weather Reader", "gale", ["gale", "tide"], 4, 0.62,
		{"coat": Color("5a5a8a"), "accent": Color("e0d0ff"), "hat": "wizard", "hair": Color("303050"), "body": "slim"},
		["gale_vane", "gale_seer"], 160, "gale_seer", "Wind from the west. Defeat from the east. Yours.", "As the wind said.", "The weather... changed."],
	["hermit", "The Hermit of the Spire", "Mountain Sage", "gale", ["gale", "wild"], 4, 0.66,
		{"coat": Color("8a8070"), "accent": Color("c0b0ff"), "hat": "hood", "hair": Color("f0f0f0"), "beard": true, "body": "slim"},
		["gale_hermit", "gale_herald"], 180, "gale_hermit", "...Leave me alone. Or play. Then leave.", "Now leave.", "Hm. Stay a while, then."],
	["roc", "Captain Gallowind", "Skyship Raider", "gale", ["gale", "ember"], 5, 0.7,
		{"coat": Color("3a2a4a"), "accent": Color("ffd166"), "hat": "captain", "hair": Color("201020"), "body": "normal"},
		["gale_captain", "gale_roc"], 200, "gale_captain", "All hands! Board the table!", "Plundered!", "Abandon ship!"],
	["aeolus", "Zephyrine", "Empress of Galespire", "gale", ["gale"], 5, 0.78,
		{"coat": Color("e0e0ff"), "accent": Color("9080ff"), "hat": "crown", "hair": Color("ffffff"), "body": "slim", "scale": 1.1},
		["gale_aeolus", "gale_cyclone", "gale_roc"], 360, "gale_aeolus", "The wind bows to me. So shall you.", "Blown away.", "The winds... choose you."],
	["umbra", "Umbra", "Herald of Eclipse", "eclipse", ["wild", "tide", "ember"], 5, 0.75,
		{"coat": Color("101020"), "accent": Color("8080ff"), "hat": "hood", "hair": Color("000000"), "body": "slim"},
		["wild_eclipse", "wild_jester"], 220, "wild_eclipse", "Day, night... I decide.", "Eclipsed.", "The shadow fades."],
	["clock", "The Clockwork Duke", "Keeper of Hours", "eclipse", ["wild", "gale", "grove"], 5, 0.78,
		{"coat": Color("6a5030"), "accent": Color("ffd080"), "hat": "tricorn", "hair": Color("a0a0a0"), "body": "stout"},
		["wild_sage", "wild_mirror"], 240, "wild_sage", "Every move calculated. Tick, tock.", "Precisely as calculated.", "An... error in my gears."],
	["twins", "Dusk & Dawn", "The Twin Sovereigns", "eclipse", ["ember", "tide"], 5, 0.82,
		{"coat": Color("402040"), "accent": Color("ffa0a0"), "hat": "crown", "hair": Color("ffd0a0"), "body": "normal"},
		["ember_solara", "tide_luna", "wild_twins"], 260, "wild_starweaver", "One of us rules the day. The other, the night.", "Both skies are ours.", "Day and night... both fall."],
	["weaver", "The Starweaver", "Seamstress of the Sky", "eclipse", ["wild", "grove", "gale"], 5, 0.86,
		{"coat": Color("20204a"), "accent": Color("f0f0ff"), "hat": "wizard", "hair": Color("c0c0ff"), "body": "slim"},
		["wild_starweaver", "grove_yggra", "gale_aeolus"], 280, "wild_moonwake", "I stitched these stars. I'll stitch your defeat too.", "A perfect seam.", "My thread... snapped."],
	["moonwake", "The Moonwake", "Spirit of the Harbor", "eclipse", ["wild", "ember", "tide", "grove", "gale"], 5, 0.95,
		{"coat": Color("d0e0ff"), "accent": Color("ffffff"), "hat": "crown", "hair": Color("e0f0ff"), "body": "slim", "scale": 1.2},
		["wild_moonwake", "ember_solara", "tide_luna", "grove_yggra", "gale_aeolus", "wild_starweaver"], 1000, "wild_moonwake", "So. You've beaten them all. Now, the last tide.", "The sea keeps its secrets.", "The harbor... is yours, Tidewright."],
]

static var _opps: Dictionary = {}
static var _order: Array[String] = []


static func _ensure() -> void:
	if not _opps.is_empty():
		return
	for row in RAW:
		var o := {
			"id": row[0], "name": row[1], "title": row[2], "region": row[3], "courts": row[4],
			"level": row[5], "skill": row[6], "look": row[7], "signature": row[8],
			"shells": row[9], "reward_card": row[10], "intro": row[11], "win_line": row[12],
			"lose_line": row[13], "ladder": false,
		}
		o["deck"] = build_deck(o.courts, o.level, o.signature, hash(o.id))
		_opps[o.id] = o
		_order.append(o.id)


static func get_opponent(id: String) -> Dictionary:
	_ensure()
	if id.begins_with("ladder:"):
		return ladder_opponent(int(id.split(":")[1]), int(id.split(":")[2]))
	return _opps.get(id, {})


static func campaign_order() -> Array[String]:
	_ensure()
	return _order


static func in_region(region: String) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for id in _order:
		if _opps[id].region == region:
			out.append(id)
	return out


## Builds a 12-card deck from the given courts. Level 0..5 controls how many
## rares/epics/mythics are allowed. Deterministic per seed.
static func build_deck(courts: Array, level: int, signature: Array, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck: Array = signature.duplicate()
	var max_rarity := clampi(int(level / 2.0 + 0.5), 0, 2)
	var pool: Array = []
	for court in courts:
		for id in CardDB.ids_by(court):
			var c := CardDB.get_card(id)
			if c.rarity <= max_rarity:
				pool.append(id)
	# Favour higher rarity at higher levels by weighting.
	var guard := 0
	while deck.size() < CardDB.DECK_SIZE and guard < 500:
		guard += 1
		var id: String = pool[rng.randi() % pool.size()]
		var c := CardDB.get_card(id)
		if deck.count(id) >= CardDB.MAX_COPIES[c.rarity]:
			continue
		if c.rarity < max_rarity and rng.randf() < 0.35:
			continue
		# Keep the curve sane: not too many 5-6 cost cards.
		if c.cost >= 5 and _count_cost(deck, 5) >= 3:
			continue
		deck.append(id)
	return deck


static func _count_cost(deck: Array, min_cost: int) -> int:
	var n := 0
	for id in deck:
		if CardDB.get_card(id).cost >= min_cost:
			n += 1
	return n


const LADDER_FIRST := ["Ada", "Bram", "Corin", "Delia", "Ezra", "Fable", "Gwen", "Hollis", "Iris", "Jory", "Kestrel", "Lio", "Maren", "Nell", "Odo", "Perrin", "Quill", "Rhea", "Sable", "Tam", "Ulla", "Vesper", "Wren", "Yara", "Zev"]
const LADDER_LAST := ["Saltwhistle", "Copperkettle", "Moonmoth", "Driftwood", "Lanternjaw", "Brinebottle", "Gullfeather", "Tidewell", "Ashgrove", "Foxglove", "Stormcask", "Pebbleford"]
const HATS := ["none", "tricorn", "hood", "wizard", "bandana", "captain", "flower"]


## A Tavern Ladder rival scaled to the player's rank. seed picks the face/deck.
static func ladder_opponent(rank: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var courts: Array = []
	var all := ["ember", "tide", "grove", "gale", "wild"]
	courts.append(all[rng.randi() % all.size()])
	var second: String = all[rng.randi() % all.size()]
	if second != courts[0]:
		courts.append(second)
	var level := clampi(rank / 5, 0, 5)
	var name := "%s %s" % [LADDER_FIRST[rng.randi() % LADDER_FIRST.size()], LADDER_LAST[rng.randi() % LADDER_LAST.size()]]
	var signature: Array = []
	if rank >= 20:
		var mythics := CardDB.ids_by(courts[0], CardDB.Rarity.MYTHIC)
		if not mythics.is_empty():
			signature.append(mythics[0])
	var look := {
		"coat": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.25, 0.6)),
		"accent": Color.from_hsv(rng.randf(), 0.5, 0.95),
		"hair": Color.from_hsv(rng.randf_range(0.0, 0.12), rng.randf_range(0.3, 0.8), rng.randf_range(0.1, 0.9)),
		"hat": HATS[rng.randi() % HATS.size()],
		"beard": rng.randf() < 0.3,
		"body": ["slim", "normal", "stout"][rng.randi() % 3],
	}
	return {
		"id": "ladder:%d:%d" % [rank, seed_value], "name": name, "title": "Tavern Rival",
		"region": "ladder", "courts": courts, "level": level, "skill": clampf(0.25 + rank * 0.022, 0.25, 0.92),
		"look": look, "signature": signature, "shells": 25 + rank * 2, "reward_card": "",
		"intro": "Fancy a hand? Loser buys the next round.", "win_line": "Drinks are on you!",
		"lose_line": "Well played, friend.", "ladder": true,
		"deck": build_deck(courts, level, signature, seed_value),
	}
