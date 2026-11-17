class_name CharacterModel
extends Node3D
## Stylised procedural humanoid (faces -Z, feet at y=0 standing, ~1.75 m at scale 1).
## configure(look) builds the body; play(anim) drives code-based animation.
## Anims: idle, walk, run, sit (hips at origin), think, cheer, sad, talk, play_card (one-shot).

const Geo := preload("res://scripts/world/geo.gd")
const Mats := preload("res://scripts/world/mats.gd")

const HIP_Y := 0.92
const UPPER := ["think", "cheer", "sad", "talk"]

var look := {}
var anim := "idle"
var _posture := "stand"
var _t := 0.0
var _phase := 0.0
var _oneshot := ""
var _oneshot_t := 0.0
var _snap := true
var _j := {}
var _rig: Node3D
var _seed := 0.0


func _ready() -> void:
	if _rig == null:
		configure(look)


func configure(l: Dictionary) -> void:
	look = l
	if _rig:
		_rig.queue_free()
		remove_child(_rig)
	_j.clear()
	_seed = randf() * 10.0
	_rig = Node3D.new()
	_rig.name = "Rig"
	var s := float(l.get("scale", 1.0))
	_rig.scale = Vector3(s, s, s)
	add_child(_rig)
	_build(l)
	_snap = true


func play(a: String) -> void:
	if a == "play_card":
		_oneshot = a
		_oneshot_t = 0.0
		return
	if a == "sit":
		if _posture != "sit":
			_snap = _snap or anim == ""
		_posture = "sit"
	elif a in ["idle", "walk", "run"]:
		_posture = "stand"
	anim = a


# --- construction -------------------------------------------------------------

func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	_j[name] = n
	return n


func _attach(node: Node3D, g: Geo) -> void:
	if g.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(Mats.get_mat("char"))
	node.add_child(mi)


func _build(l: Dictionary) -> void:
	var skin: Color = l.get("skin", Color(0.93, 0.74, 0.6))
	var coat: Color = l.get("coat", Color(0.25, 0.3, 0.45))
	var accent: Color = l.get("accent", Color(0.85, 0.65, 0.25))
	var hair: Color = l.get("hair", Color(0.25, 0.16, 0.1))
	var hat := String(l.get("hat", "none"))
	var body := String(l.get("body", "normal"))
	var wide := 0.88 if body == "slim" else (1.22 if body == "stout" else 1.0)
	var trouser := coat.darkened(0.55).lerp(Color(0.18, 0.15, 0.13), 0.5)
	var boot := Color(0.16, 0.1, 0.07)
	var shirt := Color(0.9, 0.86, 0.76)
	var leather := Color(0.3, 0.18, 0.1)

	var hips := _joint("hips", _rig, Vector3(0, HIP_Y, 0))
	var g := Geo.new()
	g.sphere(Vector3(0, 0.0, 0), Vector3(0.16 * wide, 0.12, 0.11 * wide), trouser, 12, 6)
	# back coat tails
	var tails := _joint("tails", hips, Vector3(0, 0.02, 0.0))
	var gt := Geo.new()
	gt.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.165 * wide, 0), Vector2(0.2 * wide, -0.25), Vector2(0.25 * wide, -0.52)]), 10, coat.darkened(0.08), 1.0, 0.85, false, false, PI * 1.1, -0.05 * PI)
	gt.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.15 * wide, 0), Vector2(0.185 * wide, -0.25), Vector2(0.235 * wide, -0.51)]), 10, coat.darkened(0.4), 1.0, 0.85, false, false, PI * 1.1, -0.05 * PI, true)
	gt.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.25 * wide, -0.52), Vector2(0.255 * wide, -0.55)]), 10, accent, 1.0, 0.85, false, false, PI * 1.1, -0.05 * PI)
	_attach(tails, gt)
	_attach(hips, g)

	# spine / chest
	var spine := _joint("spine", hips, Vector3(0, 0.08, 0))
	g = Geo.new()
	var tor := PackedVector2Array([Vector2(0.15, -0.1), Vector2(0.16, 0.05), Vector2(0.175, 0.2), Vector2(0.2, 0.34), Vector2(0.17, 0.42), Vector2(0.06, 0.46)])
	g.lathe(Vector3.ZERO, tor, 14, coat, wide, 0.68 * wide, true, true)
	if body == "stout":
		g.sphere(Vector3(0, 0.08, -0.05), Vector3(0.19, 0.17, 0.16), coat, 12, 8)
	# shirt V + lapels + buttons
	g.sphere(Vector3(0, 0.3, -0.1 * wide), Vector3(0.06, 0.12, 0.03), shirt, 8, 6)
	for sx in [-1.0, 1.0]:
		g.push(Transform3D(Basis(Vector3.FORWARD, sx * 0.35), Vector3(sx * 0.07, 0.27, -0.112 * wide)))
		g.box(Vector3.ZERO, Vector3(0.035, 0.2, 0.02), accent.darkened(0.25), 0.008)
		g.pop()
	for k in 4:
		g.sphere(Vector3(0.0, 0.17 - k * 0.07, -0.118 * wide - (0.01 if body == "stout" else 0.0) - (0.05 if body == "stout" and k > 1 else 0.0)), Vector3(0.012, 0.012, 0.008), accent, 6, 4)
	# belt
	g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.158, -0.02), Vector2(0.165, -0.02), Vector2(0.165, 0.04), Vector2(0.158, 0.04)]), 14, leather, wide * (1.17 if body == "stout" else 1.0), 0.7 * wide * (1.4 if body == "stout" else 1.0))
	g.box(Vector3(0, 0.01, -0.112 * wide * (1.4 if body == "stout" else 1.0)), Vector3(0.05, 0.05, 0.015), accent, 0.006)
	_attach(spine, g)

	var neck := _joint("neck", spine, Vector3(0, 0.42, 0))
	g = Geo.new()
	g.cyl(Vector3(0, -0.02, 0), Vector3(0, 0.08, 0), 0.05, 0.048, skin, 10, false)
	g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.075, -0.01), Vector2(0.07, 0.05)]), 12, shirt, 1.0, 1.0)
	_attach(neck, g)

	var head := _joint("head", neck, Vector3(0, 0.06, 0))
	g = Geo.new()
	_build_head(g, skin, hair, accent, coat, hat, bool(l.get("beard", false)))
	_attach(head, g)

	for side in [-1.0, 1.0]:
		var nm := "r" if side > 0 else "l"
		var sh := _joint("shoulder_" + nm, spine, Vector3(side * 0.2 * wide, 0.36, 0))
		g = Geo.new()
		g.sphere(Vector3(0, -0.01, 0), Vector3(0.065, 0.06, 0.065), coat, 10, 6)
		g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.056, 0.0), Vector2(0.05, -0.15), Vector2(0.046, -0.28)]), 10, coat)
		_attach(sh, g)
		var el := _joint("elbow_" + nm, sh, Vector3(0, -0.28, 0))
		g = Geo.new()
		g.sphere(Vector3.ZERO, Vector3(0.046, 0.046, 0.046), coat, 8, 5)
		g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.046, 0.0), Vector2(0.042, -0.18), Vector2(0.054, -0.2), Vector2(0.056, -0.25), Vector2(0.03, -0.25)]), 10, coat, 1.0, 1.0, false, false, TAU, 0.0, false, PackedColorArray([coat, coat, accent, accent, accent]))
		_attach(el, g)
		var hd := _joint("hand_" + nm, el, Vector3(0, -0.25, 0))
		g = Geo.new()
		g.sphere(Vector3(0, -0.05, -0.005), Vector3(0.036, 0.055, 0.022), skin, 8, 6)
		g.sphere(Vector3(side * -0.03, -0.035, -0.02), Vector3(0.013, 0.03, 0.013), skin, 6, 4)
		_attach(hd, g)

		var th := _joint("thigh_" + nm, hips, Vector3(side * 0.09 * wide, -0.04, 0))
		g = Geo.new()
		g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.078, 0.04), Vector2(0.072, -0.2), Vector2(0.058, -0.42)]), 10, trouser)
		# front coat flap rides with the thigh
		g.lathe(Vector3(side * -0.01, 0.06, 0), PackedVector2Array([Vector2(0.1, 0), Vector2(0.11, -0.22), Vector2(0.125, -0.46)]), 6, coat.darkened(0.05), 1.0, 1.0, false, false, PI * 0.75, -PI * 0.5 - PI * 0.375 + side * 0.25)
		g.lathe(Vector3(side * -0.01, 0.06, 0), PackedVector2Array([Vector2(0.125, -0.46), Vector2(0.127, -0.49)]), 6, accent, 1.0, 1.0, false, false, PI * 0.75, -PI * 0.5 - PI * 0.375 + side * 0.25)
		_attach(th, g)
		var kn := _joint("knee_" + nm, th, Vector3(0, -0.42, 0))
		g = Geo.new()
		g.lathe(Vector3.ZERO, PackedVector2Array([Vector2(0.056, 0.02), Vector2(0.05, -0.15), Vector2(0.06, -0.16), Vector2(0.068, -0.2), Vector2(0.06, -0.22), Vector2(0.052, -0.3), Vector2(0.05, -0.39)]), 10, boot, 1.0, 1.0, false, false, TAU, 0.0, false, PackedColorArray([trouser, trouser, boot, boot.lightened(0.1), boot, boot, boot]))
		_attach(kn, g)
		var an := _joint("ankle_" + nm, kn, Vector3(0, -0.39, 0))
		g = Geo.new()
		g.sphere(Vector3(0, -0.02, -0.04), Vector3(0.055, 0.045, 0.11), boot, 10, 6, -0.3, 1.0)
		g.box(Vector3(0, -0.055, -0.04), Vector3(0.1, 0.02, 0.22), boot.darkened(0.4), 0.008)
		_attach(an, g)


func _build_head(g: Geo, skin: Color, hair: Color, accent: Color, coat: Color, hat: String, beard: bool) -> void:
	var c := Vector3(0, 0.12, 0)
	g.sphere(c, Vector3(0.112, 0.13, 0.118), skin, 16, 10)
	g.sphere(c + Vector3(0, -0.06, -0.03), Vector3(0.085, 0.07, 0.085), skin, 12, 6)
	# ears
	for sx in [-1.0, 1.0]:
		g.sphere(c + Vector3(sx * 0.11, 0.0, 0.01), Vector3(0.018, 0.032, 0.022), skin.darkened(0.06), 6, 4)
		# eyes
		g.sphere(c + Vector3(sx * 0.042, 0.012, -0.098), Vector3(0.022, 0.024, 0.014), Color(0.97, 0.96, 0.93), 8, 6)
		g.sphere(c + Vector3(sx * 0.042, 0.01, -0.11), Vector3(0.012, 0.014, 0.006), Color(0.08, 0.06, 0.05), 8, 5)
		g.sphere(c + Vector3(sx * 0.038, 0.016, -0.116), Vector3(0.004, 0.004, 0.002), Color(1, 1, 1), 4, 3)
		g.push(Transform3D(Basis(Vector3.FORWARD, sx * -0.18), c + Vector3(sx * 0.045, 0.05, -0.105)))
		g.box(Vector3.ZERO, Vector3(0.042, 0.011, 0.014), hair.darkened(0.2), 0.004)
		g.pop()
		g.sphere(c + Vector3(sx * 0.06, -0.035, -0.09), Vector3(0.022, 0.016, 0.01), skin.lerp(Color(0.95, 0.45, 0.4), 0.35), 6, 4)
	g.sphere(c + Vector3(0, -0.018, -0.118), Vector3(0.018, 0.03, 0.022), skin.darkened(0.04), 8, 5)
	g.sphere(c + Vector3(0, -0.066, -0.104), Vector3(0.026, 0.007, 0.008), Color(0.45, 0.18, 0.16), 8, 4)
	# hair cap + fringe
	if hat != "hood" and hat != "bandana":
		g.sphere(c + Vector3(0, 0.035, 0.014), Vector3(0.122, 0.118, 0.126), hair, 16, 10, -0.15, 1.0)
		for k in 5:
			var a := -0.6 + k * 0.3
			g.sphere(c + Vector3(sin(a) * 0.08, 0.075 - absf(a) * 0.02, -0.085 + absf(a) * 0.02), Vector3(0.035, 0.03, 0.03), hair, 6, 4)
		g.sphere(c + Vector3(0, -0.02, 0.07), Vector3(0.11, 0.1, 0.07), hair, 10, 6)
	if beard:
		g.sphere(c + Vector3(0, -0.085, -0.07), Vector3(0.085, 0.075, 0.06), hair, 10, 6)
		g.sphere(c + Vector3(0, -0.045, -0.108), Vector3(0.045, 0.012, 0.012), hair, 8, 4)
	var dark := Color(0.07, 0.07, 0.09)
	var top := c + Vector3(0, 0.1, 0)
	match hat:
		"captain":
			g.sphere(top + Vector3(0, 0.0, 0), Vector3(0.125, 0.05, 0.13), dark, 12, 6, 0.0, 1.0)
			g.sphere(top + Vector3(0, 0.04, 0), Vector3(0.22, 0.1, 0.06), dark, 16, 8, -0.2, 1.0)
			var arc := PackedVector3Array()
			for k in 17:
				var a := PI * float(k) / 16.0
				arc.append(top + Vector3(cos(a) * 0.222, 0.04 + sin(a) * 0.1 - 0.02, 0))
			g.tube(arc, 0.012, accent, 6)
			g.sphere(top + Vector3(0, 0.07, -0.058), Vector3(0.03, 0.03, 0.01), accent, 8, 4)
		"tricorn":
			g.sphere(top, Vector3(0.12, 0.085, 0.125), dark, 12, 6, 0.0, 1.0)
			_brim(g, top + Vector3(0, -0.005, 0), 0.105, 0.2, dark, accent, 3, 0.08)
		"wizard":
			_brim(g, top + Vector3(0, -0.01, 0), 0.1, 0.24, coat.darkened(0.3), coat.darkened(0.3), 0, 0.0)
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for k in 9:
				var t := float(k) / 8.0
				pts.append(top + Vector3(0, t * 0.42, t * t * 0.14))
				rad.append(lerpf(0.11, 0.008, t))
			g.tube(pts, 0.1, coat.darkened(0.3), 12, rad)
			g.lathe(top, PackedVector2Array([Vector2(0.113, 0.0), Vector2(0.11, 0.04)]), 12, accent)
		"crown":
			var gold := Color(0.95, 0.75, 0.25)
			g.lathe(top + Vector3(0, -0.04, 0), PackedVector2Array([Vector2(0.105, 0), Vector2(0.11, 0.05), Vector2(0.1, 0.05), Vector2(0.095, 0.0)]), 16, gold)
			for k in 6:
				var a := TAU * k / 6.0
				var p := top + Vector3(cos(a) * 0.105, 0.01, sin(a) * 0.105)
				g.cyl(p, p + Vector3(0, 0.06, 0), 0.022, 0.0, gold, 6, false)
				g.sphere(p + Vector3(cos(a) * 0.004, -0.015, sin(a) * 0.004), Vector3(0.011, 0.011, 0.011), Color(0.8, 0.1, 0.2) if k % 2 == 0 else Color(0.2, 0.4, 0.9), 6, 4)
		"bandana":
			g.sphere(c + Vector3(0, 0.03, 0.01), Vector3(0.125, 0.125, 0.13), accent, 14, 8, -0.1, 1.0)
			g.sphere(c + Vector3(0, 0.02, 0.135), Vector3(0.03, 0.03, 0.025), accent.darkened(0.15), 6, 4)
			g.cyl(c + Vector3(0, 0.02, 0.14), c + Vector3(0.03, -0.12, 0.18), 0.025, 0.012, accent.darkened(0.15), 6)
		"hood":
			var hp := PackedVector2Array([Vector2(0.0, 0.175), Vector2(0.09, 0.16), Vector2(0.14, 0.09), Vector2(0.15, 0.0), Vector2(0.15, -0.09), Vector2(0.17, -0.15), Vector2(0.28, -0.24)])
			g.lathe(c + Vector3(0, 0.0, 0.01), hp, 18, coat.darkened(0.2), 1.0, 1.05, false, false, TAU - 1.7, -PI * 0.5 + 0.85)
			g.lathe(c + Vector3(0, 0.0, 0.01), hp, 18, coat.darkened(0.6), 0.96, 1.0, false, false, TAU - 1.7, -PI * 0.5 + 0.85, true)
		"flower":
			var fc := c + Vector3(0.09, 0.07, -0.04)
			for k in 5:
				var a := TAU * k / 5.0
				g.sphere(fc + Vector3(0.0, cos(a) * 0.022, sin(a) * 0.022), Vector3(0.012, 0.018, 0.018), accent, 6, 4)
			g.sphere(fc + Vector3(0.006, 0, 0), Vector3(0.012, 0.012, 0.012), Color(1.0, 0.85, 0.3), 6, 4)


func _brim(g: Geo, c: Vector3, r0: float, r1: float, col: Color, trim: Color, lobes: int, lift: float) -> void:
	var segs := 30
	var inner: Array[int] = []
	var outer: Array[int] = []
	var inner_b: Array[int] = []
	var outer_b: Array[int] = []
	var rim := PackedVector3Array()
	for k in segs + 1:
		var a := TAU * k / segs
		var up := 0.0
		if lobes > 0:
			up = lift * pow(0.5 + 0.5 * cos(float(lobes) * (a + PI * 0.5) + PI), 0.7)
		var d := Vector3(cos(a), 0, sin(a))
		var pi_ := c + d * r0
		var po := c + d * r1 + Vector3(0, up, 0)
		var n := (Vector3.UP - d * up * 2.0).normalized()
		inner.append(g.vert(pi_, n, col, Vector2.ZERO))
		outer.append(g.vert(po, n, col, Vector2.ZERO))
		inner_b.append(g.vert(pi_ + Vector3(0, -0.006, 0), -n, col.darkened(0.3), Vector2.ZERO))
		outer_b.append(g.vert(po + Vector3(0, -0.006, 0), -n, col.darkened(0.3), Vector2.ZERO))
		rim.append(po)
	for k in segs:
		g.quad(inner[k], inner[k + 1], outer[k + 1], outer[k])
		g.quad(inner_b[k], inner_b[k + 1], outer_b[k + 1], outer_b[k])
	if lobes > 0:
		g.tube(rim, 0.007, trim, 5)


# --- animation ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _j.is_empty():
		return
	_t += delta
	var pose := _pose()
	if _oneshot != "":
		_oneshot_t += delta
		var k := clampf(_oneshot_t / 1.0, 0.0, 1.0)
		var w := sin(k * PI)
		w = smoothstep(0.0, 1.0, w)
		_blend_into(pose, {"shoulder_r": Vector3(1.35, 0, -0.1), "elbow_r": Vector3(0.25, 0, 0), "spine": Vector3(-0.15, -0.2, 0), "head": Vector3(0.1, 0, 0), "hand_r": Vector3(-0.3, 0, 0)}, w)
		if k >= 1.0:
			_oneshot = ""
	var f := 1.0 if _snap else 1.0 - exp(-12.0 * delta)
	_snap = false
	for name in _j:
		var n: Node3D = _j[name]
		var target: Vector3 = pose.get(name, Vector3.ZERO)
		n.rotation = n.rotation.lerp(target, f)
	var hy: float = pose.get("_hip_y", HIP_Y)
	var hz: float = pose.get("_hip_z", 0.0)
	var hn: Node3D = _j["hips"]
	hn.position = hn.position.lerp(Vector3(0, hy, hz), f)


func _blend_into(pose: Dictionary, over: Dictionary, w: float) -> void:
	for k in over:
		pose[k] = (pose.get(k, Vector3.ZERO) as Vector3).lerp(over[k], w)


func _pose() -> Dictionary:
	var t := _t + _seed
	var p := {}
	var breath := sin(t * 1.7)
	# lower body / base
	match anim:
		"walk", "run":
			var run := anim == "run"
			var freq := 2.6 if run else 1.75
			_phase += get_process_delta_time() * freq * TAU
			var ph := _phase
			var amp := 0.85 if run else 0.5
			var s := sin(ph)
			p["thigh_l"] = Vector3(amp * s, 0, 0)
			p["thigh_r"] = Vector3(-amp * s, 0, 0)
			p["knee_l"] = Vector3(-(0.1 + (1.3 if run else 0.75) * maxf(0.0, cos(ph))), 0, 0)
			p["knee_r"] = Vector3(-(0.1 + (1.3 if run else 0.75) * maxf(0.0, -cos(ph))), 0, 0)
			p["ankle_l"] = Vector3(0.2 * maxf(0.0, -s), 0, 0)
			p["ankle_r"] = Vector3(0.2 * maxf(0.0, s), 0, 0)
			p["shoulder_l"] = Vector3(-amp * 0.8 * s, 0, -0.08)
			p["shoulder_r"] = Vector3(amp * 0.8 * s, 0, 0.08)
			p["elbow_l"] = Vector3(0.35 + (0.9 if run else 0.2) + 0.2 * s, 0, 0)
			p["elbow_r"] = Vector3(0.35 + (0.9 if run else 0.2) - 0.2 * s, 0, 0)
			p["spine"] = Vector3(-0.25 if run else -0.04, 0.12 * s, 0)
			p["head"] = Vector3(0.12 if run else 0.03, -0.1 * s, 0)
			p["tails"] = Vector3(0.35 if run else 0.12, 0, 0.05 * s)
			p["_hip_y"] = HIP_Y - (0.05 if run else 0.02) + (0.05 if run else 0.025) * cos(2.0 * ph)
		_:
			if _posture == "sit":
				p["_hip_y"] = 0.0
				p["thigh_l"] = Vector3(1.5, 0, -0.06)
				p["thigh_r"] = Vector3(1.5, 0, 0.06)
				p["knee_l"] = Vector3(-1.45, 0, 0)
				p["knee_r"] = Vector3(-1.45, 0, 0)
				p["tails"] = Vector3(1.2, 0, 0)
				p["shoulder_l"] = Vector3(0.75, 0, 0.12)
				p["shoulder_r"] = Vector3(0.75, 0, -0.12)
				p["elbow_l"] = Vector3(0.75, 0, 0)
				p["elbow_r"] = Vector3(0.75, 0, 0)
				p["spine"] = Vector3(-0.06 + breath * 0.012, 0, 0)
			else:
				p["_hip_y"] = HIP_Y + breath * 0.003
				p["thigh_l"] = Vector3(0, 0, -0.04)
				p["thigh_r"] = Vector3(0, 0, 0.04 + 0.03 * sin(t * 0.3))
				p["shoulder_l"] = Vector3(0.05, 0, -0.09 - breath * 0.015)
				p["shoulder_r"] = Vector3(0.05, 0, 0.09 + breath * 0.015)
				p["elbow_l"] = Vector3(0.18, 0, 0)
				p["elbow_r"] = Vector3(0.18, 0, 0)
				p["spine"] = Vector3(-0.02 + breath * 0.015, 0.04 * sin(t * 0.4), 0.02 * sin(t * 0.31))
			p["head"] = Vector3(0.04 * sin(t * 0.5), 0.25 * sin(t * 0.33) * sin(t * 0.11), 0)
	# upper-body overlays
	match anim:
		"think":
			p["shoulder_r"] = Vector3(0.95, 0, -0.35)
			p["elbow_r"] = Vector3(2.15, 0, 0)
			p["hand_r"] = Vector3(-0.3, 0, 0)
			p["shoulder_l"] = Vector3(0.45, 0, 0.3)
			p["elbow_l"] = Vector3(1.6, 0, 0)
			p["head"] = Vector3(-0.12, 0.15 + 0.08 * sin(t * 0.8), 0.12)
			p["spine"] = Vector3(-0.08, 0, 0)
		"cheer":
			var b := absf(sin(t * 6.0))
			p["shoulder_l"] = Vector3(2.7 + 0.2 * sin(t * 6.0), 0, -0.35)
			p["shoulder_r"] = Vector3(2.7 + 0.2 * sin(t * 6.0 + 1.0), 0, 0.35)
			p["elbow_l"] = Vector3(0.3, 0, 0)
			p["elbow_r"] = Vector3(0.3, 0, 0)
			p["head"] = Vector3(0.25, 0, 0)
			p["spine"] = Vector3(0.1, 0, 0)
			if _posture == "stand":
				p["_hip_y"] = HIP_Y + b * 0.06
		"sad":
			p["head"] = Vector3(-0.45, 0.1 * sin(t * 0.4), 0)
			p["spine"] = Vector3(-0.22, 0, 0)
			p["neck"] = Vector3(-0.15, 0, 0)
			if _posture == "stand":
				p["shoulder_l"] = Vector3(0.15, 0, -0.03)
				p["shoulder_r"] = Vector3(0.15, 0, 0.03)
				p["elbow_l"] = Vector3(0.1, 0, 0)
				p["elbow_r"] = Vector3(0.1, 0, 0)
		"talk":
			p["shoulder_r"] = Vector3(0.55 + 0.2 * sin(t * 2.3), 0, 0.15)
			p["elbow_r"] = Vector3(1.2 + 0.35 * sin(t * 3.1), 0, 0)
			p["hand_r"] = Vector3(0, 0.5 * sin(t * 2.7), 0)
			p["shoulder_l"] = Vector3(0.3 + 0.15 * sin(t * 1.7 + 2.0), 0, -0.15)
			p["elbow_l"] = Vector3(0.8 + 0.3 * sin(t * 2.2), 0, 0)
			p["head"] = Vector3(0.06 * sin(t * 4.0), 0.15 * sin(t * 0.9), 0.05 * sin(t * 1.3))
	return p
