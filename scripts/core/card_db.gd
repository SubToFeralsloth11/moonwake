class_name CardDB
extends RefCounted
## The Moonwake deck: 100 collectible Tidecards + tokens.
## Every card has a Sun value and a Moon value; the shrine's sky decides which one counts.
## Effects DSL: "when:type:args" joined by ";".
##   when r = on reveal, o = ongoing, d = at dusk (end of round), m = whenever moved.

enum Rarity { COMMON, RARE, EPIC, MYTHIC }

const COURTS := ["ember", "tide", "grove", "gale", "wild"]
const COURT_NAMES := {
	"ember": "Ember Court", "tide": "Tide Court", "grove": "Grove Court",
	"gale": "Gale Court", "wild": "Wildlings",
}
const COURT_COLORS := {
	"ember": Color("ff6a3d"), "tide": Color("3da5ff"), "grove": Color("5cd16a"),
	"gale": Color("c9b6ff"), "wild": Color("ffd166"),
}
const COURT_BLURB := {
	"ember": "Blazing under the Sun. Burns enemy cards down.",
	"tide": "Strong under the Moon. Turns the skies.",
	"grove": "Starts small, grows every dusk, crowds the shrine.",
	"gale": "Restless. Moves between shrines and pushes foes away.",
	"wild": "Strange wanderers that bend the rules.",
}
const RARITY_NAMES := ["Common", "Rare", "Epic", "Mythic"]
const RARITY_COLORS := [Color("c8c3b8"), Color("4fb3ff"), Color("c06cff"), Color("ffb347")]
const CRAFT_COST := [20, 60, 200, 800]
const DUST_VALUE := [5, 15, 50, 200]
const MAX_COPIES := [2, 2, 2, 1]
const DECK_SIZE := 12

# id, name, court, rarity(C/R/E/M), cost, sun, moon, effects, flavour
const RAW := [
	# ---------------- EMBER ----------------
	["ember_imp", "Cinder Imp", "ember", "C", 1, 3, 0, "", "Born in a chimney, raised by sparks."],
	["ember_pup", "Kindle Pup", "ember", "C", 1, 2, 1, "r:burn:1", "Its bark leaves scorch marks."],
	["ember_torch", "Torchbearer", "ember", "C", 2, 4, 1, "o:sky:sun:1", "Walks ahead so others may see."],
	["ember_flint", "Flint Brawler", "ember", "C", 2, 3, 1, "r:burn:2", "Strike once, strike hard."],
	["ember_moth", "Ashwing Moth", "ember", "C", 2, 2, 2, "r:summon:spark:1", "Drawn to flame, it brings flame along."],
	["ember_forgehand", "Forgehand", "ember", "C", 3, 5, 2, "r:boost:1", "Every blade on the harbor bears her mark."],
	["ember_brazier", "Brazier Golem", "ember", "C", 3, 6, 1, "", "Glows red at noon, sulks at night."],
	["ember_hound", "Scorch Hound", "ember", "C", 3, 4, 2, "r:burn:3", "Follows the smell of fear and smoke."],
	["ember_witch", "Cinder Witch", "ember", "C", 4, 6, 2, "r:burnall:1", "Her broom was oak. Was."],
	["ember_tortoise", "Magma Tortoise", "ember", "C", 5, 9, 4, "d:fade:1", "Slowly cooling for ten thousand years."],
	["ember_dancer", "Pyre Dancer", "ember", "R", 2, 3, 1, "r:skyup:sun:3", "She dances only when the sun is watching."],
	["ember_salamander", "Salamander", "ember", "R", 3, 4, 2, "d:burn:1", "Leaves a little fire wherever it naps."],
	["ember_kilnlord", "Kiln Lord", "ember", "R", 5, 4, 3, "o:aura:2", "His furnace warms every ally at the table."],
	["ember_flarecaller", "Flarecaller", "ember", "R", 4, 5, 2, "r:burnwide:2", "Three flares, three targets."],
	["ember_knight", "Sunforged Knight", "ember", "R", 5, 9, 3, "o:sky:sun:2", "Her armour was hammered at high noon."],
	["ember_priest", "Ash Priest", "ember", "R", 3, 3, 3, "r:devour", "All offerings feed the flame."],
	["ember_monkey", "Powder Monkey", "ember", "R", 1, 1, 1, "r:summon:spark:2", "Do not hand him matches."],
	["ember_phoenix", "Ember Phoenix", "ember", "E", 5, 7, 4, "r:burnall:2;d:grow:1", "Burns brighter every dusk."],
	["ember_warlord", "Blazing Warlord", "ember", "E", 6, 10, 5, "r:slay", "Kneel, or kindle."],
	["ember_furnace", "Heart of the Furnace", "ember", "E", 4, 4, 4, "o:courtaura:1", "The beating heart of the Ember Court."],
	["ember_volcano", "Wakened Volcano", "ember", "E", 6, 12, 2, "r:burnwide:3", "The whole harbor shook when it woke."],
	["ember_solara", "Solara, the Noon Sun", "ember", "M", 6, 11, 5, "r:dawn", "When she rises, night is forgotten everywhere."],
	# ---------------- TIDE ----------------
	["tide_crab", "Shell Crab", "tide", "C", 1, 0, 3, "", "Comes out only after dark."],
	["tide_minnow", "Moon Minnow", "tide", "C", 1, 1, 2, "r:flip", "A flick of its tail turns the sky."],
	["tide_kelp", "Kelp Weaver", "tide", "C", 2, 1, 4, "o:sky:moon:1", "Knits nets from moonlight."],
	["tide_diver", "Pearl Diver", "tide", "C", 2, 2, 3, "r:draw:1", "Always comes up with something."],
	["tide_eel", "Glass Eel", "tide", "C", 2, 1, 3, "r:summon:foam:1", "You can see right through its plans."],
	["tide_turtle", "Reef Turtle", "tide", "C", 3, 2, 6, "", "The reef grew on its back."],
	["tide_siren", "Shoal Siren", "tide", "C", 3, 2, 5, "r:flip", "Her song pulls the moon over the shrine."],
	["tide_jelly", "Lantern Jelly", "tide", "C", 3, 3, 4, "d:tidal:1", "Glows brighter with each turning tide."],
	["tide_squid", "Ink Squid", "tide", "C", 4, 2, 6, "r:swap", "In the ink, day and night trade places."],
	["tide_whale", "Calf Whale", "tide", "C", 5, 4, 9, "", "Small, for a whale."],
	["tide_caller", "Tidecaller", "tide", "R", 3, 2, 4, "r:flipother", "She points, and the far shrines turn."],
	["tide_otter", "Mischief Otter", "tide", "R", 2, 2, 2, "r:glow:1", "Steals shiny things. Returns them later."],
	["tide_merrow", "Merrow Duelist", "tide", "R", 4, 3, 6, "r:leech:2", "Her rapier drinks strength."],
	["tide_keeper", "Lighthouse Keeper", "tide", "R", 4, 4, 5, "r:still", "Nothing changes on her watch."],
	["tide_coral", "Coral Matron", "tide", "R", 4, 2, 6, "o:courtaura:1", "Mother to every reef creature."],
	["tide_pirate", "Drowned Pirate", "tide", "R", 3, 2, 4, "d:tidal:2", "Rises with every tide, angrier each time."],
	["tide_ray", "Moonray", "tide", "R", 5, 3, 8, "r:skyup:moon:3", "Glides through moonbeams like water."],
	["tide_kraken", "Little Kraken", "tide", "E", 5, 4, 8, "r:burnall:1;r:flip", "Little is relative."],
	["tide_maelstrom", "Maelstrom Witch", "tide", "E", 6, 5, 9, "r:flipother;o:sky:moon:1", "Stirs the sea with a silver ladle."],
	["tide_oracle", "Tide Oracle", "tide", "E", 3, 2, 4, "r:draw:2", "She reads the foam like a book."],
	["tide_leviathan", "Leviathan Pup", "tide", "E", 6, 6, 12, "d:fade:1", "Mother is somewhere below. Somewhere very large."],
	["tide_luna", "Luna, the Drowned Moon", "tide", "M", 6, 5, 11, "r:night", "She pulls the whole sky beneath the waves."],
	# ---------------- GROVE ----------------
	["grove_mossling", "Mossling", "grove", "C", 1, 1, 1, "d:grow:1", "Give it time."],
	["grove_glowcap", "Glow Cap", "grove", "C", 1, 1, 1, "r:summon:sprout:1", "Where one grows, more follow."],
	["grove_hedgehog", "Hedge Hog", "grove", "C", 2, 2, 2, "o:crowd:1", "Prickly alone, cosy in a crowd."],
	["grove_fern", "Fern Sprite", "grove", "C", 2, 2, 1, "d:grow:1", "Unfurls a little more each night."],
	["grove_beetle", "Bark Beetle", "grove", "C", 2, 3, 3, "", "Sturdy as an old trunk."],
	["grove_stag", "Lantern Stag", "grove", "C", 3, 3, 3, "r:boost:1", "Its antlers hold tiny glowing lanterns."],
	["grove_bear", "Honey Bear", "grove", "C", 4, 5, 5, "", "Sleeps through every argument."],
	["grove_gardener", "Old Gardener", "grove", "C", 3, 2, 2, "r:summon:sprout:2", "Plants seeds wherever she sits."],
	["grove_owl", "Barn Owl", "grove", "C", 3, 3, 4, "r:draw:1", "Who? You. Draw."],
	["grove_toad", "Toadstool Toad", "grove", "C", 2, 1, 3, "d:growsky:1", "Gets fatter under whatever sky it likes."],
	["grove_druid", "Briar Druid", "grove", "R", 4, 3, 3, "d:rouse:1", "Every dusk, her friends grow taller."],
	["grove_treant", "Young Treant", "grove", "R", 5, 5, 5, "d:grow:1", "Barely a hundred years old."],
	["grove_queen", "Bee Queen", "grove", "R", 4, 2, 2, "r:summon:sprout:3", "The hive answers instantly."],
	["grove_badger", "Thorn Badger", "grove", "R", 3, 3, 3, "r:burn:2", "Don't poke it."],
	["grove_wolf", "Moss Wolf", "grove", "R", 3, 3, 3, "o:crowd:1", "Hunts with the pack, grows with the pack."],
	["grove_willow", "Weeping Willow", "grove", "R", 4, 2, 5, "o:aura:1", "Shades all who rest beneath her."],
	["grove_harvest", "Harvest Spirit", "grove", "R", 2, 1, 1, "r:hand:1", "Ripens everything you're holding."],
	["grove_oak", "Ancient Oak", "grove", "E", 6, 7, 7, "o:aura:1;d:grow:1", "It remembers when the harbor was a forest."],
	["grove_bloom", "Bloomcaller", "grove", "E", 5, 3, 3, "r:rally:2", "One whistle, and the whole court blossoms."],
	["grove_vine", "Strangling Vine", "grove", "E", 4, 2, 4, "d:burn:1;d:grow:1", "It grows by squeezing."],
	["grove_mother", "Mother of Thorns", "grove", "E", 5, 4, 4, "o:crowd:2", "Her children are many and sharp."],
	["grove_yggra", "Yggra, the World Root", "grove", "M", 6, 6, 6, "d:rouse:1;d:grow:2", "All roots lead back to her."],
	# ---------------- GALE ----------------
	["gale_wisp", "Feather Wisp", "gale", "C", 1, 2, 1, "d:drift", "Never stays anywhere for long."],
	["gale_kite", "Kite Runner", "gale", "C", 1, 1, 2, "m:2", "Faster with every gust."],
	["gale_swallow", "Storm Swallow", "gale", "C", 2, 3, 2, "o:lone:2", "Flies alone, fights alone."],
	["gale_sprite", "Gust Sprite", "gale", "C", 2, 2, 2, "r:push", "Whoosh. Off you go."],
	["gale_scout", "Sky Scout", "gale", "C", 2, 2, 2, "d:drift;m:1", "Reports from every shrine."],
	["gale_goat", "Cliff Goat", "gale", "C", 3, 4, 3, "o:lone:2", "Stands on peaks nobody else wants."],
	["gale_monk", "Wind Monk", "gale", "C", 3, 3, 3, "r:summon:breeze:1", "Breathes in, and a breeze appears."],
	["gale_vane", "Weathervane", "gale", "C", 2, 2, 2, "r:glow:1", "Points to where the luck is."],
	["gale_peregrine", "Peregrine", "gale", "C", 3, 4, 2, "d:drift;m:2", "Strikes from wherever it lands."],
	["gale_cloudwhale", "Cloud Whale", "gale", "C", 5, 6, 6, "", "Drifts above the harbor, humming."],
	["gale_harpy", "Howling Harpy", "gale", "R", 4, 4, 4, "r:push;r:burn:1", "Her shriek sends foes flying."],
	["gale_dervish", "Dust Dervish", "gale", "R", 3, 2, 2, "d:drift;m:3", "Spins faster the further it goes."],
	["gale_seer", "Wind Seer", "gale", "R", 3, 2, 3, "r:conjure:gale_wisp", "Whispers to the wind; the wind sends help."],
	["gale_balloonist", "Balloonist", "gale", "R", 2, 1, 3, "r:glow:1;o:lone:1", "A lonely sky, a lovely view."],
	["gale_herald", "Storm Herald", "gale", "R", 4, 4, 3, "o:lone:3", "Announces itself to an empty shrine."],
	["gale_fox", "Zephyr Fox", "gale", "R", 3, 3, 3, "r:push;m:2", "Shoves, then darts away."],
	["gale_lancer", "Tempest Lancer", "gale", "R", 5, 6, 5, "r:burnwide:1", "One lance, three lightning bolts."],
	["gale_roc", "Thunder Roc", "gale", "E", 6, 8, 8, "r:push;d:drift;m:2", "Its wingbeat is the thunder."],
	["gale_cyclone", "Cyclone", "gale", "E", 5, 3, 3, "r:scatter", "Clears the shrine of everyone but friends."],
	["gale_hermit", "Mountain Hermit", "gale", "E", 4, 3, 3, "o:lone:5", "Please. Leave."],
	["gale_captain", "Skyship Captain", "gale", "E", 5, 5, 5, "r:rally:1;d:drift", "All hands, full sail!"],
	["gale_aeolus", "Aeolus, Breath of the World", "gale", "M", 6, 7, 7, "o:courtaura:2", "Every wind is his voice."],
	# ---------------- WILD ----------------
	["wild_lantern", "Paper Lantern", "wild", "C", 1, 1, 1, "r:glow:1", "Light it, and fortune finds you."],
	["wild_merchant", "Wandering Merchant", "wild", "C", 2, 2, 2, "r:draw:1", "Everything's for sale. Even this card."],
	["wild_golem", "Clay Golem", "wild", "C", 4, 5, 5, "", "Shaped by a child, animated by moonlight."],
	["wild_cat", "Harbor Cat", "wild", "C", 2, 2, 2, "r:conjure:wild_cat", "There is always another cat."],
	["wild_twins", "Twilight Twins", "wild", "R", 3, 3, 3, "o:high", "One for the day, one for the night."],
	["wild_jester", "Moon Jester", "wild", "R", 3, 2, 2, "r:swap;r:flip", "Turns everything upside down. Twice."],
	["wild_bellringer", "Bell Ringer", "wild", "R", 4, 4, 4, "r:boost:2", "When the bell rings, everyone stands taller."],
	["wild_mirror", "Mirror Eel", "wild", "R", 3, 0, 0, "r:mirror", "Becomes whatever it sees."],
	["wild_sage", "Clockwork Sage", "wild", "E", 5, 5, 5, "r:glow:2;r:draw:1", "Tick. Tock. Think."],
	["wild_eclipse", "Eclipse Knight", "wild", "E", 5, 6, 6, "o:anchor", "While he stands, the sky stands still."],
	["wild_starweaver", "Starweaver", "wild", "M", 6, 7, 7, "r:hand:2", "Stitches starlight into every card you hold."],
	["wild_moonwake", "The Moonwake", "wild", "M", 6, 8, 8, "o:high;o:aura:1", "The light the moon leaves on the sea."],
]

const TOKENS := [
	["spark", "Spark", "ember", "C", 0, 2, 0, "", "A stray ember."],
	["foam", "Sea Foam", "tide", "C", 0, 0, 2, "", "Fizzes under the moon."],
	["sprout", "Sprout", "grove", "C", 0, 1, 1, "d:grow:1", "Tiny, but trying."],
	["breeze", "Breeze", "gale", "C", 0, 1, 1, "d:drift;m:1", "Just passing through."],
]

static var _cards: Dictionary = {}
static var _order: Array[String] = []


static func _ensure() -> void:
	if not _cards.is_empty():
		return
	var rmap := {"C": Rarity.COMMON, "R": Rarity.RARE, "E": Rarity.EPIC, "M": Rarity.MYTHIC}
	for group in [RAW, TOKENS]:
		for row in group:
			var c := {
				"id": row[0], "name": row[1], "court": row[2], "rarity": rmap[row[3]],
				"cost": row[4], "sun": row[5], "moon": row[6], "fx": _parse(row[7]),
				"flavor": row[8], "token": group == TOKENS,
			}
			c["text"] = ""
			_cards[c.id] = c
			if not c.token:
				_order.append(c.id)
	for id in _cards:
		_cards[id]["text"] = describe(_cards[id])


static func _parse(s: String) -> Array:
	var out: Array = []
	if s.is_empty():
		return out
	for part in s.split(";"):
		var bits := part.split(":")
		var e := {"when": bits[0], "type": bits[1] if bits.size() > 1 else ""}
		if bits[0] == "m":
			e = {"when": "m", "type": "moved", "n": int(bits[1])}
		else:
			var args := bits.slice(2)
			match e.type:
				"sky", "skyup":
					e["sky"] = 0 if args[0] == "sun" else 1
					e["n"] = int(args[1])
				"summon":
					e["token"] = args[0]
					e["n"] = int(args[1])
				"conjure":
					e["card"] = args[0]
				_:
					e["n"] = int(args[0]) if args.size() > 0 else 0
		out.append(e)
	return out


static func describe(card: Dictionary) -> String:
	var lines: PackedStringArray = []
	var court_word: String = String(card.court).capitalize()
	for e in card.fx:
		var n: int = e.get("n", 0)
		var t := ""
		match e.type:
			"burn": t = "Reveal: Your foe's strongest card here gets -%d." % n
			"burnall": t = "Reveal: All enemy cards here get -%d." % n
			"burnwide": t = "Reveal: The strongest enemy at every shrine gets -%d." % n
			"boost": t = "Reveal: Your other cards here get +%d." % n
			"rally": t = "Reveal: Your other %s cards everywhere get +%d." % [court_word, n]
			"skyup": t = "Reveal: If this shrine is under the %s, gain +%d." % [_sky_word(e.sky), n]
			"draw": t = "Reveal: Draw %d card%s." % [n, "" if n == 1 else "s"]
			"glow": t = "Reveal: +%d Glow next round." % n
			"summon": t = "Reveal: Add %d %s%s here." % [n, get_card(e.token).name if _cards.has(e.token) else e.token, "" if n == 1 else "s"]
			"slay": t = "Reveal: Destroy your foe's weakest card here."
			"push": t = "Reveal: Blow your foe's strongest card here to another shrine."
			"scatter": t = "Reveal: Blow every enemy card here to other shrines."
			"swap": t = "Reveal: Swap the Sun and Moon values of every card here."
			"leech": t = "Reveal: Steal %d power from your foe's strongest card here." % n
			"hand": t = "Reveal: Cards in your hand get +%d." % n
			"still": t = "Reveal: This shrine's sky never turns again."
			"devour": t = "Reveal: Destroy your weakest other card here and absorb its values."
			"conjure": t = "Reveal: Add a %s to your hand." % (get_card(e.card).name if _cards.has(e.card) else e.card)
			"mirror": t = "Reveal: Copy the values of your foe's strongest card here."
			"flip": t = "Reveal: Turn this shrine's sky."
			"flipother": t = "Reveal: Turn the sky of the other shrines."
			"dawn": t = "Reveal: Every shrine turns to the Sun."
			"night": t = "Reveal: Every shrine turns to the Moon."
			"aura": t = "Ongoing: Your other cards here get +%d." % n
			"courtaura": t = "Ongoing: Your other %s cards everywhere get +%d." % [court_word, n]
			"sky": t = "Ongoing: +%d while this shrine is under the %s." % [n, _sky_word(e.sky)]
			"lone": t = "Ongoing: +%d if it's your only card here." % n
			"crowd": t = "Ongoing: +%d for each other card you have here." % n
			"high": t = "Ongoing: Always uses its higher value."
			"anchor": t = "Ongoing: This shrine's sky can't turn."
			"grow": t = "Dusk: Gain +%d." % n
			"growsky": t = "Dusk: Gain +%d to the value of the current sky." % n
			"drift": t = "Dusk: Drift to another shrine."
			"tidal": t = "Dusk: When this shrine's sky turns, gain +%d." % n
			"rouse": t = "Dusk: Your other cards here get +%d." % n
			"fade": t = "Dusk: Lose %d." % n
			"moved": t = "When moved: Gain +%d." % n
		if e.when == "d" and e.type == "burn":
			t = "Dusk: A random enemy card here gets -%d." % n
		lines.append(t)
	return "\n".join(lines)


static func _sky_word(sky: int) -> String:
	return "Sun" if sky == 0 else "Moon"


static func get_card(id: String) -> Dictionary:
	_ensure()
	return _cards.get(id, {})


static func all_ids() -> Array[String]:
	_ensure()
	return _order


static func ids_by(court: String = "", rarity: int = -1) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for id in _order:
		var c: Dictionary = _cards[id]
		if (court == "" or c.court == court) and (rarity < 0 or c.rarity == rarity):
			out.append(id)
	return out


static func has_fx(card: Dictionary, when: String, type: String) -> bool:
	for e in card.fx:
		if e.when == when and e.type == type:
			return true
	return false
