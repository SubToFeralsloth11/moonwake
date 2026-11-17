extends Node3D
## Cosy tavern interior around the duel table. Table-top surface is y=0 at the origin;
## x in [-1.7, 1.7], z in [-1.2, 1.2] stays clear for cards. Opponent sits at -z (OpponentSpot).

const Geo := preload("res://scripts/world/geo.gd")
const Mats := preload("res://scripts/world/mats.gd")
const Fx := preload("res://scripts/world/fx.gd")

const FLOOR := -0.78
const CEIL := 3.2
const WOOD := Color(0.36, 0.24, 0.15)
const WOOD_DARK := Color(0.2, 0.13, 0.08)
const STONE := Color(0.5, 0.47, 0.44)
const WARM := Color(1.0, 0.62, 0.3)

var rng := RandomNumberGenerator.new()
var _g := {}


func G(mat: String) -> Geo:
	if not _g.has(mat):
		var g := Geo.new()
		g.long_u = mat == "wood"
		_g[mat] = g
	var gg: Geo = _g[mat]
	gg.seed_a = rng.randf()
	return gg


func _ready() -> void:
	rng.seed = 77
	_env()
	_room()
	_table()
	_fireplace()
	_bar()
	_windows()
	_clutter()
	for mat in _g:
		var mi := MeshInstance3D.new()
		mi.mesh = (_g[mat] as Geo).to_mesh(Mats.get_mat(mat))
		if mat == "glow" or mat == "window":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func light(pos: Vector3, col: Color, energy: float, r: float, shadow := false, flicker := 0.0) -> OmniLight3D:
	var h := Node3D.new()
	h.position = pos
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = r
	l.shadow_enabled = shadow
	l.shadow_blur = 1.5
	h.add_child(l)
	if flicker > 0.0:
		h.set_script(Fx)
		h.set("mode", "flicker")
		h.set("amount", flicker)
	add_child(h)
	return l


func _env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.25, 0.2)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	env.volumetric_fog_length = 14.0
	we.environment = env
	add_child(we)


func _room() -> void:
	var w := G("wood")
	# floor boards
	var z := -6.0
	while z < 5.0:
		var x := -6.0
		var row_off := rng.randf() * 1.5
		while x < 6.0:
			var l := rng.randf_range(1.6, 2.6)
			var x0 := maxf(-6.0, x - row_off)
			w.box(Vector3(x0 + l * 0.5, FLOOR - 0.04, z + 0.11), Vector3(l - 0.01, 0.08, 0.215), WOOD.darkened(rng.randf() * 0.3), 0.008)
			x = x0 + l
			row_off = 0.0
		z += 0.22
	var pl := G("plaster")
	var st := G("stone")
	# walls: back (z=-5.5), left (x=-5.5), right (x=5.5)
	pl.box(Vector3(0, (FLOOR + CEIL) * 0.5, -5.6), Vector3(11.4, CEIL - FLOOR, 0.2), Color(0.72, 0.6, 0.45))
	pl.box(Vector3(-5.6, (FLOOR + CEIL) * 0.5, 0), Vector3(0.2, CEIL - FLOOR, 11.4), Color(0.7, 0.58, 0.44))
	pl.box(Vector3(5.6, (FLOOR + CEIL) * 0.5, 0), Vector3(0.2, CEIL - FLOOR, 11.4), Color(0.7, 0.58, 0.44))
	pl.box(Vector3(0, CEIL + 0.1, 0), Vector3(11.4, 0.2, 11.4), Color(0.3, 0.22, 0.16))
	# wainscot
	for k in 3:
		var nrm: Vector3 = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][k]
		var c: Vector3 = [Vector3(0, FLOOR + 0.55, -5.45), Vector3(-5.45, FLOOR + 0.55, 0), Vector3(5.45, FLOOR + 0.55, 0)][k]
		var s := Vector3(11.0, 1.1, 0.1) if k == 0 else Vector3(0.1, 1.1, 11.0)
		w.box(c, s, WOOD_DARK.lightened(0.05), 0.02)
		w.box(c + Vector3(0, 0.58, 0) + nrm * 0.03, s + Vector3(0, -1.02, 0) + nrm.abs() * 0.08, WOOD, 0.02)
	# posts + ceiling beams
	for x in [-5.3, -2.0, 2.0, 5.3]:
		w.box(Vector3(x, (FLOOR + CEIL) * 0.5, -5.35), Vector3(0.3, CEIL - FLOOR, 0.3), WOOD_DARK, 0.04)
	for z2 in [-4.5, -1.5, 1.5, 4.5]:
		w.box(Vector3(-5.35, (FLOOR + CEIL) * 0.5, z2), Vector3(0.3, CEIL - FLOOR, 0.3), WOOD_DARK, 0.04)
		w.box(Vector3(5.35, (FLOOR + CEIL) * 0.5, z2), Vector3(0.3, CEIL - FLOOR, 0.3), WOOD_DARK, 0.04)
		w.box(Vector3(0, CEIL - 0.2, z2), Vector3(11.0, 0.35, 0.3), WOOD_DARK, 0.04)
	w.box(Vector3(0, CEIL - 0.45, 0), Vector3(0.35, 0.3, 11.0), WOOD_DARK, 0.04)
	# rug
	var cl := G("cloth")
	cl.box(Vector3(0, FLOOR + 0.005, 0), Vector3(5.8, 0.01, 4.4), Color(0.45, 0.12, 0.1))
	cl.box(Vector3(0, FLOOR + 0.01, 0), Vector3(5.2, 0.01, 3.8), Color(0.6, 0.45, 0.2))
	cl.box(Vector3(0, FLOOR + 0.015, 0), Vector3(4.9, 0.01, 3.5), Color(0.35, 0.1, 0.12))


func _table() -> void:
	var w := G("wood")
	var cl := G("cloth")
	# felt inlay: top at y=0
	cl.box(Vector3(0, -0.02, 0), Vector3(3.56, 0.04, 2.56), Color(0.09, 0.28, 0.2))
	# carved rim
	var rim := Color(0.32, 0.18, 0.1)
	for sz in [-1.0, 1.0]:
		w.box(Vector3(0, -0.01, sz * 1.36), Vector3(3.9, 0.08, 0.2), rim, 0.035)
		w.box(Vector3(0, -0.07, sz * 1.42), Vector3(3.98, 0.06, 0.1), rim.darkened(0.25), 0.02)
	for sx in [-1.0, 1.0]:
		w.box(Vector3(sx * 1.86, -0.01, 0), Vector3(0.2, 0.08, 2.52), rim, 0.035)
		w.box(Vector3(sx * 1.92, -0.07, 0), Vector3(0.1, 0.06, 2.9), rim.darkened(0.25), 0.02)
	# gold inlay line
	var m := G("metal")
	for sz in [-1.0, 1.0]:
		m.box(Vector3(0, 0.031, sz * 1.36), Vector3(3.6, 0.004, 0.02), Color(0.85, 0.65, 0.25))
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * 1.86, 0.031, 0), Vector3(0.02, 0.004, 2.7), Color(0.85, 0.65, 0.25))
	# apron + turned legs
	w.box(Vector3(0, -0.2, 0), Vector3(3.6, 0.2, 2.6), WOOD_DARK, 0.03)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			w.lathe(Vector3(sx * 1.7, FLOOR, sz * 1.2), PackedVector2Array([Vector2(0.1, 0), Vector2(0.09, 0.08), Vector2(0.06, 0.15), Vector2(0.11, 0.3), Vector2(0.06, 0.45), Vector2(0.07, 0.55), Vector2(0.09, 0.62), Vector2(0.09, 0.68), Vector2(0.0, 0.68)]), 12, WOOD_DARK)
	# candles on corners (outside the clear zone)
	var plain := G("plain")
	var glow := G("glow")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * 1.85, 0.03, sz * 1.36)
			m.lathe(p, PackedVector2Array([Vector2(0.07, 0), Vector2(0.07, 0.015), Vector2(0.02, 0.03), Vector2(0.015, 0.08), Vector2(0.035, 0.09), Vector2(0.035, 0.1), Vector2(0.0, 0.1)]), 12, Color(0.8, 0.6, 0.25))
			var h := 0.12 + rng.randf() * 0.08
			plain.cyl(p + Vector3(0, 0.1, 0), p + Vector3(0, 0.1 + h, 0), 0.026, 0.024, Color(0.95, 0.9, 0.78), 10)
			plain.sphere(p + Vector3(0.02, 0.1 + h - 0.02, 0), Vector3(0.012, 0.03, 0.012), Color(0.95, 0.9, 0.8), 5, 4)
			glow.sphere(p + Vector3(0, 0.1 + h + 0.04, 0), Vector3(0.012, 0.03, 0.012), Color(1.0, 0.75, 0.35) * 2.5, 6, 4)
			light(p + Vector3(0, 0.1 + h + 0.12, 0), Color(1.0, 0.65, 0.3), 0.35, 2.2, false, 0.8)
	# chairs
	_chair(w, Vector3(0, FLOOR, -2.05), 0.0)
	_chair(w, Vector3(0, FLOOR, 2.1), PI)
	# hanging lantern above the table
	var lp := Vector3(0, 2.05, 0)
	m.cyl(lp + Vector3(0, 0.35, 0), Vector3(0, CEIL, 0), 0.012, 0.012, Color(0.1, 0.1, 0.1), 4)
	m.lathe(lp, PackedVector2Array([Vector2(0.0, -0.08), Vector2(0.14, -0.04), Vector2(0.15, 0.0), Vector2(0.12, 0.0)]), 8, Color(0.15, 0.12, 0.1))
	m.lathe(lp, PackedVector2Array([Vector2(0.15, 0.28), Vector2(0.22, 0.3), Vector2(0.06, 0.42), Vector2(0.0, 0.45)]), 8, Color(0.15, 0.12, 0.1))
	for k in 6:
		var a := TAU * k / 6.0
		m.cyl(lp + Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14), lp + Vector3(cos(a) * 0.15, 0.29, sin(a) * 0.15), 0.012, 0.012, Color(0.15, 0.12, 0.1), 4)
	glow.lathe(lp, PackedVector2Array([Vector2(0.06, 0.02), Vector2(0.11, 0.15), Vector2(0.06, 0.27), Vector2(0.0, 0.27)]), 8, Color(1.0, 0.65, 0.3) * 1.6)
	var l := light(lp + Vector3(0, -0.1, 0), Color(1.0, 0.72, 0.42), 2.2, 7.0, true, 0.15)
	l.shadow_blur = 2.0
	light(Vector3(0, 1.3, 1.5), Color(1.0, 0.75, 0.5), 0.6, 4.0)


func _chair(w: Geo, p: Vector3, yaw: float) -> void:
	w.push(Transform3D(Basis(Vector3.UP, yaw), p))
	w.box(Vector3(0, 0.47, 0), Vector3(0.56, 0.06, 0.52), WOOD, 0.02)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			w.cyl(Vector3(sx * 0.23, 0, sz * 0.21), Vector3(sx * 0.23, 0.46, sz * 0.21), 0.035, 0.028, WOOD_DARK, 8)
		w.cyl(Vector3(sx * 0.23, 0.47, -0.22), Vector3(sx * 0.24, 1.15, -0.28), 0.035, 0.028, WOOD_DARK, 8)
	w.box(Vector3(0, 1.08, -0.27), Vector3(0.56, 0.16, 0.05), WOOD, 0.02)
	for k in 3:
		w.box(Vector3(-0.13 + k * 0.13, 0.8, -0.25), Vector3(0.05, 0.4, 0.03), WOOD, 0.01)
	w.pop()


func _fireplace() -> void:
	var st := G("stone")
	var c := Vector3(0, FLOOR, -5.2)
	st.box(c + Vector3(-1.05, 0.7, 0.2), Vector3(0.6, 1.4, 0.8), STONE, 0.05)
	st.box(c + Vector3(1.05, 0.7, 0.2), Vector3(0.6, 1.4, 0.8), STONE, 0.05)
	st.box(c + Vector3(0, 1.6, 0.2), Vector3(2.9, 0.45, 0.85), STONE, 0.05)
	st.box(c + Vector3(0, 0.05, 0.45), Vector3(3.2, 0.1, 1.3), STONE.darkened(0.2), 0.03)
	st.box(c + Vector3(0, 2.6, 0.0), Vector3(2.2, 2.2, 0.5), STONE.darkened(0.08), 0.05)
	st.box(c + Vector3(0, 0.7, -0.15), Vector3(1.6, 1.4, 0.1), Color(0.08, 0.06, 0.05))
	var w := G("wood")
	w.box(c + Vector3(0, 1.88, 0.35), Vector3(3.3, 0.12, 0.55), WOOD_DARK, 0.03)
	# logs + andirons
	w.cyl(c + Vector3(-0.5, 0.18, 0.15), c + Vector3(0.5, 0.18, 0.25), 0.1, 0.09, Color(0.2, 0.12, 0.07), 8)
	w.cyl(c + Vector3(-0.4, 0.3, 0.3), c + Vector3(0.45, 0.3, 0.05), 0.09, 0.08, Color(0.18, 0.1, 0.06), 8)
	G("glow").sphere(c + Vector3(0, 0.15, 0.2), Vector3(0.45, 0.06, 0.2), Color(1.5, 0.45, 0.1), 10, 4)
	# mantle props
	var p := G("plain")
	for k in 5:
		var x := -1.3 + k * 0.6
		p.lathe(c + Vector3(x, 1.94, 0.35), PackedVector2Array([Vector2(0.06, 0), Vector2(0.07, 0.12), Vector2(0.03, 0.2), Vector2(0.025, 0.26), Vector2(0.0, 0.26)]), 10, [Color(0.25, 0.35, 0.3), Color(0.5, 0.3, 0.15), Color(0.7, 0.65, 0.55)][k % 3])
	_fire(c + Vector3(0, 0.25, 0.2))
	light(c + Vector3(0, 0.7, 0.9), Color(1.0, 0.5, 0.2), 3.0, 7.0, true, 1.0)


func _fire(p: Vector3) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = 48
	ps.lifetime = 0.8
	ps.position = p
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.45, 0.05, 0.12)
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.8, 0)
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.1))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.set_color(0, Color(3.0, 1.6, 0.5, 1.0))
	gr.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
	gr.add_point(0.4, Color(2.4, 0.8, 0.15, 0.8))
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.5)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g2 := Gradient.new()
	g2.set_color(0, Color(1, 1, 1, 1))
	g2.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = g2
	m.albedo_texture = gt
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	ps.draw_pass_1 = q
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ps)


func _bar() -> void:
	# Bar shelves on the left wall with bottles and mugs.
	var w := G("wood")
	var gl := G("glass")
	var p := G("plain")
	var x := -5.3
	for k in 3:
		var y := FLOOR + 1.3 + k * 0.5
		w.box(Vector3(x + 0.15, y, -1.0), Vector3(0.3, 0.05, 5.0), WOOD, 0.015)
		for j in 14:
			var z := -3.3 + j * 0.34 + rng.randf_range(-0.05, 0.05)
			var col: Color = [Color(0.2, 0.5, 0.25), Color(0.5, 0.2, 0.12), Color(0.25, 0.3, 0.55), Color(0.6, 0.45, 0.15), Color(0.4, 0.15, 0.35)][rng.randi() % 5]
			var h := rng.randf_range(0.22, 0.34)
			if rng.randf() < 0.75:
				gl.lathe(Vector3(x + 0.15, y + 0.025, z), PackedVector2Array([Vector2(0.0, 0), Vector2(0.05, 0.0), Vector2(0.055, h * 0.6), Vector2(0.02, h * 0.8), Vector2(0.018, h), Vector2(0.0, h)]), 10, col)
				p.cyl(Vector3(x + 0.15, y + 0.025 + h, z), Vector3(x + 0.15, y + 0.06 + h, z), 0.017, 0.015, Color(0.5, 0.35, 0.2), 6)
			else:
				p.lathe(Vector3(x + 0.15, y + 0.025, z), PackedVector2Array([Vector2(0.0, 0), Vector2(0.05, 0.0), Vector2(0.05, 0.14), Vector2(0.045, 0.14), Vector2(0.045, 0.01), Vector2(0.0, 0.01)]), 10, Color(0.45, 0.32, 0.2))
	# bar counter along left side
	w.box(Vector3(-4.2, FLOOR + 0.55, -1.0), Vector3(0.6, 1.1, 4.0), WOOD_DARK, 0.03)
	w.box(Vector3(-4.15, FLOOR + 1.12, -1.0), Vector3(0.8, 0.07, 4.2), WOOD, 0.03)
	for k in 3:
		p.lathe(Vector3(-4.1, FLOOR + 1.155, -2.0 + k * 0.9), PackedVector2Array([Vector2(0.0, 0), Vector2(0.05, 0.0), Vector2(0.05, 0.15), Vector2(0.0, 0.15)]), 10, Color(0.5, 0.36, 0.2))
	# barrels behind the bar
	for k in 3:
		var bp := Vector3(-5.0, FLOOR, 1.8 + k * 0.85)
		var prof := PackedVector2Array()
		for i in 7:
			prof.append(Vector2(0.32 + 0.06 * sin(PI * i / 6.0), 0.9 * i / 6.0))
		w.lathe(bp, prof, 16, WOOD.lightened(0.1), 1.0, 1.0, true, true)
		var m := G("metal")
		for yy in [0.1, 0.8]:
			m.lathe(bp, PackedVector2Array([Vector2(0.34, yy - 0.025), Vector2(0.34, yy + 0.025)]), 16, Color(0.2, 0.18, 0.16))


func _windows() -> void:
	var win := G("window")
	var w := G("wood")
	for z in [-3.0, 0.0, 3.0]:
		var c := Vector3(5.48, 1.2, z)
		win.quad_p(c + Vector3(0, -0.6, 0.5), c + Vector3(0, -0.6, -0.5), c + Vector3(0, 0.6, -0.5), c + Vector3(0, 0.6, 0.5), Vector3.LEFT, Color(0.12, 0.2, 0.45), Vector2.ONE, true)
		w.box(c + Vector3(-0.05, 0.66, 0), Vector3(0.14, 0.12, 1.2), WOOD_DARK, 0.02)
		w.box(c + Vector3(-0.08, -0.66, 0), Vector3(0.2, 0.1, 1.3), WOOD_DARK, 0.02)
		w.box(c + Vector3(-0.05, 0, 0.56), Vector3(0.12, 1.3, 0.1), WOOD_DARK, 0.02)
		w.box(c + Vector3(-0.05, 0, -0.56), Vector3(0.12, 1.3, 0.1), WOOD_DARK, 0.02)
	var moon := light(Vector3(4.6, 1.3, 0), Color(0.5, 0.6, 1.0), 0.5, 4.0)
	moon.light_volumetric_fog_energy = 2.0


func _clutter() -> void:
	var w := G("wood")
	var p := G("plain")
	# background tables with stools and mugs
	for tp in [Vector3(3.6, FLOOR, -3.6), Vector3(-2.8, FLOOR, -3.9), Vector3(3.8, FLOOR, 2.8)]:
		w.lathe(tp, PackedVector2Array([Vector2(0.3, 0), Vector2(0.08, 0.1), Vector2(0.07, 0.7), Vector2(0.0, 0.7)]), 10, WOOD_DARK)
		w.lathe(tp, PackedVector2Array([Vector2(0.0, 0.7), Vector2(0.6, 0.7), Vector2(0.6, 0.76), Vector2(0.0, 0.76)]), 20, WOOD)
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var sp: Vector3 = tp + Vector3(cos(a) * 0.95, 0, sin(a) * 0.95)
			w.lathe(sp, PackedVector2Array([Vector2(0.2, 0), Vector2(0.06, 0.1), Vector2(0.05, 0.42), Vector2(0.0, 0.42)]), 8, WOOD_DARK)
			w.lathe(sp, PackedVector2Array([Vector2(0.0, 0.42), Vector2(0.2, 0.42), Vector2(0.2, 0.47), Vector2(0.0, 0.47)]), 12, WOOD)
		p.lathe(tp + Vector3(0.2, 0.76, 0.1), PackedVector2Array([Vector2(0.0, 0), Vector2(0.05, 0.0), Vector2(0.05, 0.14), Vector2(0.0, 0.14)]), 10, Color(0.5, 0.36, 0.2))
		var gl := G("glow")
		gl.sphere(tp + Vector3(-0.2, 0.86, -0.1), Vector3(0.012, 0.03, 0.012), Color(1.0, 0.7, 0.3) * 2.0, 5, 3)
		p.cyl(tp + Vector3(-0.2, 0.76, -0.1), tp + Vector3(-0.2, 0.84, -0.1), 0.03, 0.03, Color(0.95, 0.9, 0.8), 8)
		light(tp + Vector3(-0.2, 1.0, -0.1), Color(1.0, 0.6, 0.3), 0.6, 3.0, false, 0.6)
	# hanging herbs from beams
	for k in 8:
		var hp := Vector3(-3.5 + k * 1.0, CEIL - 0.4, -4.5)
		p.cyl(hp, hp + Vector3(0, -0.35, 0), 0.006, 0.006, Color(0.5, 0.4, 0.3), 3)
		p.sphere(hp + Vector3(0, -0.45, 0), Vector3(0.08, 0.14, 0.08), Color(0.25, 0.32, 0.15), 6, 4)
	# shield/plaques and a ship's wheel on the back wall
	var m := G("metal")
	var wc := Vector3(-2.9, 1.5, -5.42)
	var ring := PackedVector3Array()
	for k in 25:
		var a := TAU * k / 24.0
		ring.append(wc + Vector3(cos(a) * 0.45, sin(a) * 0.45, 0))
	w.tube(ring, 0.04, WOOD, 6)
	for k in 8:
		var a := TAU * k / 8.0
		w.cyl(wc, wc + Vector3(cos(a) * 0.62, sin(a) * 0.62, 0), 0.025, 0.035, WOOD, 6)
	m.sphere(wc, Vector3(0.08, 0.08, 0.05), Color(0.7, 0.55, 0.25), 8, 5)
	for x in [2.9]:
		w.box(Vector3(x, 1.4, -5.45), Vector3(1.0, 0.7, 0.04), WOOD_DARK, 0.02)
		p.box(Vector3(x, 1.4, -5.42), Vector3(0.86, 0.56, 0.02), Color(0.2, 0.3, 0.45))
		p.box(Vector3(x, 1.36, -5.41), Vector3(0.6, 0.2, 0.01), Color(0.75, 0.68, 0.5))
