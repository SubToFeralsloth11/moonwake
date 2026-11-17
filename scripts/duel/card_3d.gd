class_name Card3D
extends Node3D
## A physical Tidecard on the table. Lies flat in local XZ; face up is +Y.
## Size 0.42 x 0.6 m. Has a StaticBody3D for mouse picking (meta "card3d").

const W := 0.42
const H := 0.6
const ART_SHADER := preload("res://shaders/cards/card_art.gdshader")

var uid := -1
var card_id := ""
var face_up := true
var target_pos := Vector3.ZERO
var target_basis := Basis.IDENTITY
var hover := false
var selected := false

var _labels: Dictionary = {}
var _frame_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _glow: MeshInstance3D
var _face: Node3D
var _back: MeshInstance3D


func _init() -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, 0.008, H)
	body.mesh = bm
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.roughness = 0.45
	_frame_mat.metallic = 0.3
	body.material_override = _frame_mat
	add_child(body)

	_glow = MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(W + 0.06, H + 0.06)
	_glow.mesh = gm
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(1, 0.85, 0.4, 0.0)
	_glow.material_override = _glow_mat
	_glow.position.y = -0.006
	add_child(_glow)

	_face = Node3D.new()
	_face.position.y = 0.0045
	add_child(_face)

	_back = MeshInstance3D.new()
	var back_mesh := PlaneMesh.new()
	back_mesh.size = Vector2(W - 0.02, H - 0.02)
	_back.mesh = back_mesh
	_back.rotation.x = PI
	_back.position.y = -0.0045
	add_child(_back)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, 0.03, H)
	cs.shape = shape
	sb.add_child(cs)
	sb.set_meta("card3d", self)
	add_child(sb)


func setup(p_uid: int, p_id: String, back_id: String) -> void:
	uid = p_uid
	card_id = p_id
	var c := CardDB.get_card(p_id)
	var col: Color = CardDB.COURT_COLORS[c.court]
	var rcol: Color = CardDB.RARITY_COLORS[c.rarity]
	_frame_mat.albedo_color = col.darkened(0.55)

	var inner := _quad(Vector2(W - 0.03, H - 0.03), Color("1b1712"), 0.0)
	inner.position.y = 0.0001
	var art := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(W - 0.06, 0.25)
	art.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = ART_SHADER
	sm.set_shader_parameter("tint", col)
	sm.set_shader_parameter("seed", float(hash(p_id) % 1000) / 37.0)
	art.material_override = sm
	art.position = Vector3(0, 0.0004, -0.07)
	_face.add_child(art)
	var band := _quad(Vector2(W - 0.03, 0.006), rcol, 1.5)
	band.position = Vector3(0, 0.0005, 0.06)

	_labels.name = _label(c.name, 44, Vector3(0, 0.001, -0.245), Color("f4ead2"), W - 0.08)
	_labels.cost = _label(str(c.cost), 110, Vector3(-W / 2 + 0.05, 0.002, -H / 2 + 0.05), Color("9fe8ff"))
	_label("◆", 120, Vector3(-W / 2 + 0.05, 0.0012, -H / 2 + 0.05), Color("10304a"))
	_labels.sun = _label("", 72, Vector3(-0.12, 0.002, 0.235), Color("ffd166"))
	_labels.moon = _label("", 72, Vector3(0.12, 0.002, 0.235), Color("a9c8ff"))
	_label("☀", 30, Vector3(-0.12, 0.002, 0.18), Color("ffcf5a"))
	_label("☾", 34, Vector3(0.12, 0.002, 0.18), Color("a9c8ff"))
	var text := _label(c.text if c.text != "" else c.flavor, 17, Vector3(0, 0.001, 0.115), Color("e8dcc0"), W - 0.07)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if c.text == "":
		text.modulate = Color("b8a888")

	var back: Dictionary = Profile.CARD_BACKS.get(back_id, Profile.CARD_BACKS.classic)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = back.a
	bmat.emission_enabled = true
	bmat.emission = back.b * 0.15
	_back.material_override = bmat
	var emblem := Label3D.new()
	emblem.text = "☾"
	emblem.font_size = 260
	emblem.pixel_size = 0.001
	emblem.modulate = back.b
	emblem.rotation.x = PI / 2
	emblem.position.y = -0.006
	emblem.double_sided = false
	add_child(emblem)
	_back.set_meta("emblem", emblem)
	set_values(c.sun, c.moon, -1)


func _quad(size: Vector2, color: Color, emission: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	m.material_override = mat
	_face.add_child(m)
	return m


func _label(t: String, size: int, pos: Vector3, color: Color, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = size
	l.pixel_size = 0.0007
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = color
	l.rotation.x = -PI / 2
	l.position = pos
	l.double_sided = false
	if width > 0:
		l.width = width / l.pixel_size
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_face.add_child(l)
	return l


## active_sky: 0 sun, 1 moon, -1 neither (in hand). Highlights the counting value.
func set_values(sun: int, moon: int, active_sky: int, power := -999) -> void:
	_labels.sun.text = str(sun)
	_labels.moon.text = str(moon)
	_labels.sun.font_size = 150 if active_sky == 0 else 100
	_labels.moon.font_size = 150 if active_sky == 1 else 100
	_labels.sun.modulate.a = 0.45 if active_sky == 1 else 1.0
	_labels.moon.modulate.a = 0.45 if active_sky == 0 else 1.0
	if power != -999 and active_sky >= 0:
		var base := sun if active_sky == 0 else moon
		var l: Label3D = _labels.sun if active_sky == 0 else _labels.moon
		l.text = str(power)
		l.modulate = Color("8fff8f") if power > base else (Color("ff7a7a") if power < base else (Color("ffd166") if active_sky == 0 else Color("a9c8ff")))


func set_face_up(up: bool) -> void:
	face_up = up


func set_highlight(on: bool, color := Color(1, 0.85, 0.4)) -> void:
	_glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.75 if on else 0.0)


func _process(delta: float) -> void:
	var lift := 0.0
	if hover:
		lift += 0.03
	if selected:
		lift += 0.06
	var tb := target_basis
	if not face_up:
		tb = tb * Basis(Vector3.FORWARD, PI)
	var k := 1.0 - exp(-12.0 * delta)
	position = position.lerp(target_pos + Vector3(0, lift, 0), k)
	transform.basis = transform.basis.orthonormalized().slerp(tb.orthonormalized(), k).scaled(tb.get_scale())
