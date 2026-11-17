extends CharacterBody3D
## Third-person hub player: WASD relative to camera, sprint, jump, mouse look,
## nearest-interactable prompt and the floating target marker.

const CharModel := preload("res://scripts/world/character_model.gd")

const WALK := 3.6
const RUN := 6.8
const JUMP := 4.6
const GRAVITY := 13.0
const MOUSE_SENS := 0.0028

var model: CharModel
var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.32
var _target: Node = null
var _marker: Node3D
var _menu_block := 0.0
var hud: Node = null
var restored := false


func _ready() -> void:
	add_to_group("hub_player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)

	model = CharModel.new()
	model.name = "Model"
	add_child(model)
	model.configure({"coat": Color(0.06, 0.32, 0.34), "accent": Color(0.95, 0.74, 0.28), "hat": "captain", "hair": Color(0.32, 0.2, 0.12), "skin": Color(0.9, 0.7, 0.55)})
	model.play("idle")

	_pivot = Node3D.new()
	_pivot.name = "CamPivot"
	_pivot.top_level = true
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = 4.4
	_arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 600.0
	_cam.current = true
	_arm.add_child(_cam)
	_build_marker()

	if Game.has_return_transform:
		global_transform = Game.hub_return_transform
		Game.has_return_transform = false
		restored = true
	_yaw = rotation.y
	model.rotation.y = 0.0
	_pivot.global_position = global_position + Vector3(0, 1.55, 0)
	_apply_cam()
	Game.screen_closed.connect(_on_screen_closed)
	if not Game.ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Faces the player (and camera) toward a world point; used by the hub to set spawn.
func face(point: Vector3) -> void:
	var d := point - global_position
	_yaw = atan2(-d.x, -d.z)
	rotation.y = _yaw
	_apply_cam()


func _on_screen_closed() -> void:
	_menu_block = 0.25
	if is_inside_tree() and not Game.ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Game.ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("menu") and _menu_block <= 0.0:
		get_viewport().set_input_as_handled()
		Game.open_screen("menu")
	elif event.is_action_pressed("interact") and _target:
		get_viewport().set_input_as_handled()
		Game.interact(String(_target.action), _target.data)


func _apply_cam() -> void:
	_pivot.rotation = Vector3(0, _yaw, 0)
	_arm.rotation = Vector3(_pitch, 0, 0)


func _physics_process(delta: float) -> void:
	_menu_block = maxf(0.0, _menu_block - delta)
	var input := Vector2.ZERO
	var sprint := false
	if not Game.ui_open:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint = Input.is_action_pressed("sprint")
	var basis_y := Basis(Vector3.UP, _yaw)
	var dir := basis_y * Vector3(input.x, 0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := RUN if sprint else WALK
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 14.0 if is_on_floor() else 4.0
	hv = hv.lerp(dir * speed, 1.0 - exp(-accel * delta))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		if not Game.ui_open and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if dir.length() > 0.05:
		var want := atan2(-dir.x, -dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, want - rotation.y, 1.0 - exp(-12.0 * delta))
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 4.8:
		model.play("run")
	elif flat > 0.4:
		model.play("walk")
	else:
		model.play("idle")


func _process(delta: float) -> void:
	_apply_cam()
	var want := global_position + Vector3(0, 1.55, 0)
	_pivot.global_position = _pivot.global_position.lerp(want, 1.0 - exp(-14.0 * delta))
	_update_target(delta)


func _update_target(delta: float) -> void:
	var best: Node = null
	var best_d := INF
	if not Game.ui_open:
		for n in get_tree().get_nodes_in_group("interactable"):
			var a := n as Node3D
			var d := Vector2(a.global_position.x - global_position.x, a.global_position.z - global_position.z).length()
			if d <= float(n.radius) and d < best_d:
				best = n
				best_d = d
	_target = best
	if hud and hud.has_method("set_prompt"):
		hud.set_prompt(String(best.prompt) if best else "")
	_marker.visible = best != null
	if best:
		var tp: Vector3 = (best as Node3D).global_position + Vector3(0, float(best.marker_height) + sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
		_marker.global_position = _marker.global_position.lerp(tp, 1.0 - exp(-10.0 * delta)) if _marker.visible else tp
		_marker.rotate_y(delta * 1.8)


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)
	var gem := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.28, 0.36, 0.28)
	gem.mesh = pm
	gem.rotation.x = PI
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.4, 1.8, 0.6)
	gem.material_override = m
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(gem)
	var halo := Sprite3D.new()
	halo.texture = _radial_tex()
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.pixel_size = 0.012
	halo.modulate = Color(1.0, 0.8, 0.4, 0.7)
	halo.shaded = false
	halo.transparent = true
	halo.no_depth_test = false
	_marker.add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 0.8
	l.omni_range = 3.0
	_marker.add_child(l)


static func _radial_tex() -> Texture2D:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.35))
	gt.gradient = gr
	return gt
