extends Node3D
## Ambient villager: walks a closed loop of points, pausing now and then to chat or look around.

const CharModel := preload("res://scripts/world/character_model.gd")

var points: PackedVector3Array = PackedVector3Array()
var speed := 1.3
var model: CharModel
var _i := 0
var _wait := 0.0


func setup(look: Dictionary, pts: PackedVector3Array, spd := 1.3) -> void:
	points = pts
	speed = spd
	model = CharModel.new()
	add_child(model)
	model.configure(look)
	model.play("walk")
	if points.size() > 0:
		position = points[0]
		_i = 1 % points.size()


func _process(delta: float) -> void:
	if points.size() < 2 or model == null:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			model.play("walk")
		return
	var target := points[_i]
	var d := target - position
	d.y = 0.0
	if d.length() < 0.15:
		_i = (_i + 1) % points.size()
		if randf() < 0.3:
			_wait = randf_range(2.0, 5.0)
			model.play("talk" if randf() < 0.5 else "idle")
		return
	var step := d.normalized() * speed * delta
	position += step
	position.y = lerpf(position.y, target.y, delta * 2.0)
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-6.0 * delta))
