extends Node3D
## Tiny animation helper for world props: spin, bob or light flicker.

@export_enum("spin", "bob", "flicker") var mode := "spin"
@export var speed := 1.0
@export var amount := 1.0

var _t := 0.0
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _base_energy := 1.0


func _ready() -> void:
	_t = randf() * 10.0
	_base_pos = position
	_base_rot = rotation
	var l := get_child(0) as Light3D if get_child_count() > 0 else null
	if l:
		_base_energy = l.light_energy


func _process(delta: float) -> void:
	_t += delta
	match mode:
		"spin":
			rotate_y(delta * speed)
		"bob":
			position.y = _base_pos.y + sin(_t * speed) * 0.06 * amount
			rotation.x = _base_rot.x + sin(_t * speed * 0.8 + 1.0) * 0.03 * amount
			rotation.z = _base_rot.z + sin(_t * speed * 0.6) * 0.04 * amount
		"flicker":
			var l := get_child(0) as Light3D if get_child_count() > 0 else null
			if l:
				var f := 0.82 + 0.1 * sin(_t * 9.0 * speed) + 0.06 * sin(_t * 23.0 * speed + 1.3) + 0.05 * sin(_t * 3.1)
				l.light_energy = _base_energy * lerpf(1.0, f, amount)
