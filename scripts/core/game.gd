extends Node
## Global flow controller: input actions, UI overlay, hub <-> duel transitions.

signal screen_opened(screen: String)
signal screen_closed

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const DUEL_SCENE := "res://scenes/duel/duel.tscn"
const UI_ROOT_SCENE := "res://scenes/ui/ui_root.tscn"

## True while a menu overlay is open; the hub player must ignore movement/mouse-look.
var ui_open := false
## Player transform to restore when coming back to the hub from a duel.
var hub_return_transform := Transform3D.IDENTITY
var has_return_transform := false
## Opponent id of the duel being started (read by the duel scene).
var pending_opponent := ""
## Result of the last duel, shown by the UI after returning to the hub.
var last_result: Dictionary = {}

var ui: Node = null

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"menu": [KEY_ESCAPE],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if ResourceLoader.exists(UI_ROOT_SCENE):
		ui = load(UI_ROOT_SCENE).instantiate()
		add_child(ui)


## Called by hub interactables. action: "shop", "deck", "collection", "campaign",
## "duel" (data.opponent_id), "stats".
func interact(action: String, data: Dictionary = {}) -> void:
	if action == "duel":
		start_duel(String(data.get("opponent_id", "")))
		return
	open_screen(action, data)


func open_screen(screen: String, data: Dictionary = {}) -> void:
	if ui == null:
		return
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.open(screen, data)
	screen_opened.emit(screen)


func close_screen() -> void:
	ui_open = false
	screen_closed.emit()


func start_duel(opponent_id: String) -> void:
	if OpponentDB.get_opponent(opponent_id).is_empty():
		push_warning("Unknown opponent %s" % opponent_id)
		return
	var player := get_tree().get_first_node_in_group("hub_player") as Node3D
	if player:
		hub_return_transform = player.global_transform
		has_return_transform = true
	pending_opponent = opponent_id
	if ui:
		ui.close_all()
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_to(DUEL_SCENE)


## result: {won: bool, opponent_id, shells, glimmer, cards: Array[String], first_win: bool}
func end_duel(result: Dictionary) -> void:
	last_result = result
	_fade_to(HUB_SCENE)


func return_to_hub() -> void:
	last_result = {}
	_fade_to(HUB_SCENE)


func _fade_to(path: String) -> void:
	if ui and ui.has_method("fade_out"):
		await ui.fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if ui and ui.has_method("fade_in"):
		ui.fade_in()
	if path == HUB_SCENE and not last_result.is_empty() and ui:
		ui.show_duel_result(last_result)
		last_result = {}
