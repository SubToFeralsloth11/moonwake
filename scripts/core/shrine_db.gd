class_name ShrineDB
extends RefCounted
## The three shrines on the table are drawn from this pool every duel.

const SHRINES := {
	"quiet": {"name": "Quiet Shrine", "text": "No blessing. Just the sky.", "color": Color("b8b0a0")},
	"sunwell": {"name": "Sunwell", "text": "Cards here get +2 under the Sun.", "skybonus": [0, 2], "color": Color("ffcf5a")},
	"moonpool": {"name": "Moonpool", "text": "Cards here get +2 under the Moon.", "skybonus": [1, 2], "color": Color("8fb6ff")},
	"still": {"name": "Still Waters", "text": "This shrine's sky never turns.", "still": true, "color": Color("7fd6c9")},
	"whirlpool": {"name": "Whirlpool", "text": "Dusk: each side's weakest card here is destroyed.", "whirlpool": true, "color": Color("4a7bd1")},
	"ember_altar": {"name": "Ember Altar", "text": "Ember cards here get +2.", "court": "ember", "color": Color("ff6a3d")},
	"coral_gate": {"name": "Coral Gate", "text": "Tide cards here get +2.", "court": "tide", "color": Color("3da5ff")},
	"elder_root": {"name": "Elder Root", "text": "Grove cards here get +2.", "court": "grove", "color": Color("5cd16a")},
	"windspire": {"name": "Windspire", "text": "Gale cards here get +2.", "court": "gale", "color": Color("c9b6ff")},
	"narrow": {"name": "Narrow Pass", "text": "Only 2 cards per side fit here.", "cap": 2, "color": Color("a08060")},
	"peak": {"name": "Lonely Peak", "text": "Only 1 card per side fits here.", "cap": 1, "color": Color("d0d8e8")},
	"market": {"name": "Lantern Market", "text": "Cards played here cost 1 less.", "discount": 1, "color": Color("ffb347")},
	"restless": {"name": "Restless Tide", "text": "Turns its sky whenever a card is revealed here.", "restless": true, "color": Color("5fc4ff")},
	"bonfire": {"name": "Bonfire", "text": "Dusk: every card here gets +1.", "bonfire": true, "color": Color("ff8f4a")},
	"mirror": {"name": "Mirror Lake", "text": "Cards here always use their higher value.", "high": true, "color": Color("e0f0ff")},
}


static func get_shrine(id: String) -> Dictionary:
	return SHRINES.get(id, SHRINES.quiet)


static func random_set(rng: RandomNumberGenerator, count := 3) -> Array[String]:
	var pool: Array = SHRINES.keys()
	var out: Array[String] = []
	while out.size() < count:
		var id: String = pool[rng.randi() % pool.size()]
		if id in out:
			continue
		# Keep the board interesting: at most one capacity-limited shrine.
		if (id == "narrow" or id == "peak") and ("narrow" in out or "peak" in out):
			continue
		out.append(id)
	return out
