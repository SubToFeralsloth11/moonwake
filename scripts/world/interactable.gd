class_name Interactable
extends Area3D
## Hub interaction point. The hub player picks the nearest one within `radius` and,
## on the interact action, calls Game.interact(action, data).

@export var action: String = ""
@export var prompt: String = ""
@export var data: Dictionary = {}
@export var radius: float = 2.5
## Height of the floating marker above this node.
@export var marker_height: float = 2.4


func _ready() -> void:
	add_to_group("interactable")
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	if get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = radius
		cs.shape = sh
		add_child(cs)
