extends Node3D
## Builds Moonwake Harbor procedurally: environment, terrain, sea, quay, plaza, buildings,
## docks, boats, lighthouse, props, lights, particles, villagers and interactables.
## Static geometry is merged per material and per 30 m chunk.

const Geo := preload("res://scripts/world/geo.gd")
const Mats := preload("res://scripts/world/mats.gd")
const CharModel := preload("res://scripts/world/character_model.gd")
const Inter := preload("res://scripts/world/interactable.gd")
const Fx := preload("res://scripts/world/fx.gd")
const Npc := preload("res://scripts/world/npc_walker.gd")
const SKY := preload("res://shaders/world/night_sky.gdshader")
const WATER := preload("res://shaders/world/water.gdshader")
const BEAM := preload("res://shaders/world/beam.gdshader")

const SEA := -1.4
const SPAWN := Vector3(2.0, 0.05, 4.0)
const SHOP := Vector3(19.0, 0.0, -7.0)

const WOOD := Color(0.36, 0.24, 0.15)
const WOOD_DARK := Color(0.2, 0.13, 0.08)
const STONE := Color(0.5, 0.48, 0.45)
const WARM := Color(1.0, 0.62, 0.3)

var rng := RandomNumberGenerator.new()
var _batches := {}
var _body: StaticBody3D
var _shadow_lights := 0
var _font: SystemFont


func _ready() -> void:
	rng.seed = 20261118
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino", "Georgia", "Times New Roman", "serif"])
	_font.font_weight = 700
	_body = StaticBody3D.new()
	_body.name = "Collision"
	add_child(_body)
	_environment()
	_terrain()
	_water()
	_quay_and_streets()
	_fountain()
	_buildings()
	_docks()
	_boats()
	_lighthouse()
	_lamps()
	_string_lights()
	_props()
	_trees()
	_particles()
	_people()
	_bounds()
	_flush()
	var player := get_node_or_null("../Player")
	if player and not player.get("restored"):
		player.global_position = SPAWN
		player.face(SHOP + Vector3(0, 0, 2))
	var hud := get_node_or_null("../HubHUD")
	if player and hud:
		player.hud = hud


# --- batching / helpers ---------------------------------------------------------

func G(mat: String, at: Vector3) -> Geo:
	var key := "%s|%d|%d" % [mat, floori(at.x / 30.0), floori(at.z / 30.0)]
	if not _batches.has(key):
		var g := Geo.new()
		g.long_u = mat == "wood"
		_batches[key] = g
	var gg: Geo = _batches[key]
	gg.seed_a = rng.randf()
	return gg


func _flush() -> void:
	for key in _batches:
		var g: Geo = _batches[key]
		if g.is_empty():
			continue
		var mi := MeshInstance3D.new()
		var mat := String(key).get_slice("|", 0)
		mi.mesh = g.to_mesh(Mats.get_mat(mat))
		if mat == "glow" or mat == "window":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_batches.clear()


func col_box(c: Vector3, s: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = s
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), c)
	_body.add_child(cs)


func light(pos: Vector3, col: Color, energy: float, rng_: float, shadow := false, flicker := 0.0) -> OmniLight3D:
	var holder := Node3D.new()
	holder.position = pos
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 1.2
	if shadow and _shadow_lights < 6:
		_shadow_lights += 1
		l.shadow_enabled = true
		l.shadow_blur = 1.5
	holder.add_child(l)
	if flicker > 0.0:
		holder.set_script(Fx)
		holder.set("mode", "flicker")
		holder.set("amount", flicker)
	add_child(holder)
	return l


func label(text: String, pos: Vector3, yaw: float, size := 96, col := Color(1.0, 0.86, 0.55)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 18
	l.modulate = col
	l.outline_modulate = Color(0.12, 0.06, 0.02)
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	add_child(l)
	return l


func interactable(pos: Vector3, action: String, prompt: String, data := {}, marker_h := 2.4) -> void:
	var a := Inter.new()
	a.action = action
	a.prompt = prompt
	a.data = data
	a.marker_height = marker_h
	a.position = pos
	a.name = "Interact_" + action
	add_child(a)


static func xf(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _radial() -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	return gt


# --- environment ----------------------------------------------------------------

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(2, 1.0)
	env.set_glow_level(4, 0.7)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.1, 0.14, 0.25)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.3
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.9)
	env.volumetric_fog_emission = Color(0.01, 0.015, 0.03)
	env.volumetric_fog_length = 60.0
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.light_angular_distance = 0.8
	moon.shadow_enabled = true
	moon.shadow_blur = 1.2
	moon.directional_shadow_max_distance = 70.0
	moon.light_volumetric_fog_energy = 0.4
	add_child(moon)
	var moon_dir := Vector3(0.5, 0.36, -0.78).normalized()
	moon.look_at_from_position(moon_dir * 10.0, Vector3.ZERO, Vector3.UP)


# --- terrain ----------------------------------------------------------------------

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func height(x: float, z: float) -> float:
	var h := 0.0
	if z < -16.0:
		h = lerpf(0.0, -4.5, clampf((-16.0 - z) / 1.5, 0.0, 1.0))
	var w := smoothstep(-24.0, -30.0, x)
	var beach := clampf(remap(z, -12.0, -44.0, -0.02, -4.2), -4.2, -0.02)
	beach += sin(x * 0.21) * 0.25 * smoothstep(-14.0, -24.0, z)
	h = lerpf(h, beach, w)
	var d := _seg_dist(Vector2(x, z), Vector2(34, -21), Vector2(44, -47))
	var n := sin(x * 0.7) * sin(z * 0.53) * 0.6 + sin(x * 1.9 + z * 1.3) * 0.25
	var k := smoothstep(13.0, 6.0, d)
	h = maxf(h, lerpf(-4.5, 3.4 + n, k))
	var hill := 0.0
	hill += maxf(0.0, z - 34.0) * 0.16
	hill += maxf(0.0, x - 44.0) * 0.18 * smoothstep(-20.0, -8.0, z)
	hill += maxf(0.0, -44.0 - x) * 0.18 * smoothstep(-16.0, -6.0, z)
	if hill > 0.0:
		h += hill + n * minf(hill, 1.0) * 0.6
	return h


func _terrain() -> void:
	var g := Geo.new()
	var step := 2.0
	var n := 100
	var org := -100.0
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			hs[j * (n + 1) + i] = height(org + i * step, org + j * step)
	var ids := PackedInt32Array()
	ids.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var x := org + i * step
			var z := org + j * step
			var h := hs[j * (n + 1) + i]
			var hl := hs[j * (n + 1) + maxi(i - 1, 0)]
			var hr := hs[j * (n + 1) + mini(i + 1, n)]
			var hd := hs[maxi(j - 1, 0) * (n + 1) + i]
			var hu := hs[mini(j + 1, n) * (n + 1) + i]
			var nrm := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			var col: Color
			var beachw := smoothstep(-24.0, -30.0, x)
			if nrm.y < 0.8:
				col = Color(0.3, 0.29, 0.28)
			elif h < 0.35 and (beachw > 0.5 or h < -0.3):
				col = Color(0.52, 0.45, 0.33) if h > SEA - 0.4 else Color(0.3, 0.3, 0.26)
			elif h > 1.5 and _seg_dist(Vector2(x, z), Vector2(34, -21), Vector2(44, -47)) < 12.0:
				col = Color(0.32, 0.3, 0.28).lerp(Color(0.16, 0.2, 0.1), 0.4)
			else:
				col = Color(0.13, 0.18, 0.08).lerp(Color(0.2, 0.18, 0.1), 0.5 + 0.5 * sin(x * 0.13 + z * 0.21))
			ids[j * (n + 1) + i] = g.vert(Vector3(x, h, z), nrm, col, Vector2(x, z))
	for j in n:
		for i in n:
			g.quad(ids[j * (n + 1) + i], ids[j * (n + 1) + i + 1], ids[(j + 1) * (n + 1) + i + 1], ids[(j + 1) * (n + 1) + i])
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(Mats.get_mat("terrain"))
	mi.name = "Terrain"
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	_body.add_child(cs)
	# Rocks along the headland and beach.
	for k in 34:
		var p: Vector3
		if k < 22:
			var t := rng.randf()
			p = Vector3(lerpf(34, 44, t), 0, lerpf(-21, -47, t)) + Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-4, 4))
		else:
			p = Vector3(rng.randf_range(-58, -28), 0, rng.randf_range(-36, -22))
		p.y = height(p.x, p.z) - 0.3
		var r := rng.randf_range(0.6, 2.2)
		var g2 := G("rock", p)
		g2.push(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), p))
		g2.sphere(Vector3.ZERO, Vector3(r * rng.randf_range(0.8, 1.4), r * rng.randf_range(0.5, 0.9), r), Color(0.34, 0.33, 0.32), 9, 6)
		g2.sphere(Vector3(r * 0.5, r * 0.2, r * 0.3), Vector3(r * 0.6, r * 0.5, r * 0.6), Color(0.3, 0.3, 0.3), 7, 5)
		g2.pop()


func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(420, 420)
	pm.subdivide_width = 140
	pm.subdivide_depth = 140
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = WATER
	mi.material_override = m
	mi.position = Vector3(0, SEA, -40)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Ocean"
	add_child(mi)


# --- quay, streets, plaza ---------------------------------------------------------

func _quay_and_streets() -> void:
	# Sea wall
	var x := -27.0
	while x < 32.0:
		var g := G("stone", Vector3(x, 0, -16))
		g.box(Vector3(x + 1.0, -2.2, -16.5), Vector3(2.0, 4.6, 1.2), STONE.darkened(0.25 + rng.randf() * 0.1), 0.03)
		g.box(Vector3(x + 1.0, 0.04, -16.45), Vector3(1.96, 0.22, 1.4), STONE.lightened(0.05), 0.05)
		x += 2.0
	# Cobbled areas
	var areas := [Rect2(-27, -16, 58, 31), Rect2(-4.5, 15, 9, 50), Rect2(31, -3.5, 35, 7.5), Rect2(-66, -11, 39, 6.5)]
	for r: Rect2 in areas:
		var cx := r.position.x
		while cx < r.end.x:
			var cz := r.position.y
			while cz < r.end.y:
				var w := minf(10.0, r.end.x - cx)
				var d := minf(10.0, r.end.y - cz)
				var c := Vector3(cx + w * 0.5, -0.06, cz + d * 0.5)
				c.y = maxf(-0.06, height(c.x, c.z) - 0.06) if r.position.y > 10.0 else -0.06
				var g := G("cobble", c)
				if r.position.y > 10.0:
					var y0 := height(c.x, cz) - 0.06
					var y1 := height(c.x, cz + d) - 0.06
					g.push(Transform3D(Basis(Vector3.RIGHT, -atan2(y1 - y0, d)), Vector3(c.x, (y0 + y1) * 0.5, c.z)))
					g.box(Vector3.ZERO, Vector3(w, 0.2, d / cos(atan2(y1 - y0, d))), Color(0.42, 0.41, 0.4))
					g.pop()
				else:
					g.box(c, Vector3(w, 0.2, d), Color(0.42, 0.41, 0.4))
				cz += 10.0
			cx += 10.0
	# Bollards and mooring rings along the quay
	for bx in [-22.0, -16.0, -11.0, -5.0, 2.0, 8.0, 17.0, 23.0, 29.0]:
		var p := Vector3(bx, 0.1, -16.6)
		var g := G("metal", p)
		g.lathe(p, PackedVector2Array([Vector2(0.16, 0), Vector2(0.14, 0.35), Vector2(0.2, 0.45), Vector2(0.2, 0.52), Vector2(0.0, 0.56)]), 12, Color(0.12, 0.12, 0.13))
		col_box(p + Vector3(0, 0.3, 0), Vector3(0.4, 0.6, 0.4))


func _fountain() -> void:
	var c := Vector3(0, 0, -2)
	var g := G("stone", c)
	g.lathe(c, PackedVector2Array([Vector2(3.0, 0), Vector2(3.1, 0.5), Vector2(3.0, 0.62), Vector2(2.7, 0.62), Vector2(2.7, 0.3), Vector2(0.0, 0.3)]), 40, STONE.lightened(0.1))
	g.lathe(c, PackedVector2Array([Vector2(0.55, 0.3), Vector2(0.4, 1.4), Vector2(0.7, 1.55), Vector2(1.2, 1.6), Vector2(1.2, 1.75), Vector2(0.0, 1.75)]), 24, STONE)
	g.lathe(c, PackedVector2Array([Vector2(0.3, 1.75), Vector2(0.22, 2.6), Vector2(0.35, 2.75), Vector2(0.0, 2.8)]), 16, STONE.lightened(0.1))
	# crescent moon sculpture
	var arc := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 25:
		var a := lerpf(-2.4, 2.4, k / 24.0)
		arc.append(c + Vector3(sin(a) * 0.75, 3.6 + cos(a) * 0.75, 0))
		radii.append(0.02 + 0.2 * cos(a * 0.62) * cos(a * 0.62))
	var gm := G("glow", c)
	gm.tube(arc, 0.1, Color(0.6, 0.7, 1.0), 10, radii)
	var gw := G("plain", c)
	gw.lathe(c, PackedVector2Array([Vector2(0.0, 0.52), Vector2(2.72, 0.52)]), 40, Color(0.05, 0.15, 0.2))
	light(c + Vector3(0, 3.5, 0.5), Color(0.6, 0.72, 1.0), 1.6, 9.0)
	col_box(c + Vector3(0, 0.5, 0), Vector3(5.6, 1.2, 5.6))
	for k in 4:
		var a := TAU * k / 4.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 4.4
		_bench(p, a + PI * 0.5)


# --- buildings ------------------------------------------------------------------------

func _buildings() -> void:
	var specs := [
		# pos, yaw, w, d, floors, plaster, roof, kind, name
		[SHOP, -PI * 0.5, 10.0, 7.5, 2, Color(0.82, 0.74, 0.58), Color(0.2, 0.25, 0.36), "shop", "The Gilded Gull"],
		[Vector3(-20, 0, -5), PI * 0.5, 12.0, 9.0, 2, Color(0.72, 0.62, 0.48), Color(0.45, 0.2, 0.13), "tavern", "The Drowned Lantern"],
		[Vector3(-9, 0, 18.5), PI, 7.0, 5.5, 1, Color(0.6, 0.66, 0.7), Color(0.3, 0.3, 0.26), "stall", "Cartographer's Desk"],
		[Vector3(19, 0, 8), -PI * 0.5, 8.0, 7.0, 2, Color(0.66, 0.72, 0.78), Color(0.45, 0.2, 0.13), "house", ""],
		[Vector3(-20, 0, 10), PI * 0.5, 8.0, 7.0, 2, Color(0.8, 0.7, 0.55), Color(0.24, 0.28, 0.33), "house", ""],
		[Vector3(9, 0, 20), PI, 9.0, 7.0, 2, Color(0.85, 0.8, 0.7), Color(0.38, 0.22, 0.16), "house", ""],
		[Vector3(10, 0, 33), -PI * 0.5, 8.0, 7.0, 2, Color(0.75, 0.62, 0.5), Color(0.24, 0.28, 0.33), "house", ""],
		[Vector3(-11, 0, 32), PI * 0.5, 9.0, 7.0, 2, Color(0.62, 0.68, 0.6), Color(0.45, 0.2, 0.13), "house", ""],
		[Vector3(38, 0, -10), 0.0, 9.0, 7.0, 2, Color(0.8, 0.76, 0.66), Color(0.38, 0.22, 0.16), "house", ""],
		[Vector3(38, 0, 11), PI, 10.0, 7.5, 1, Color(0.55, 0.45, 0.35), Color(0.3, 0.3, 0.26), "house", ""],
		[Vector3(-36, 0, 2), 0.0, 10.0, 7.0, 2, Color(0.78, 0.7, 0.62), Color(0.24, 0.28, 0.33), "house", ""],
	]
	for s in specs:
		_building(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8])


func _building(pos: Vector3, yaw: float, w: float, d: float, floors: int, plaster: Color, roof_col: Color, kind: String, title: String) -> void:
	var t := xf(pos, yaw)
	var stone := G("stone", pos)
	var wood := G("wood", pos)
	var pl := G("plaster", pos)
	var rf := G("roof", pos)
	var win := G("window", pos)
	var glow := G("glow", pos)
	for g: Geo in [stone, wood, pl, rf, win, glow]:
		g.push(t)
	var gh := 3.2
	var open_front := kind == "shop" or kind == "stall"
	var sc := STONE.lerp(plaster, 0.25).darkened(rng.randf() * 0.15)
	var th := 0.35
	# ground floor walls (front at +z)
	stone.box(Vector3(0, gh * 0.5, -d * 0.5 + th * 0.5), Vector3(w, gh, th), sc, 0.04)
	stone.box(Vector3(-w * 0.5 + th * 0.5, gh * 0.5, 0), Vector3(th, gh, d), sc, 0.04)
	stone.box(Vector3(w * 0.5 - th * 0.5, gh * 0.5, 0), Vector3(th, gh, d), sc, 0.04)
	stone.box(Vector3(0, 0.1, 0), Vector3(w - 0.2, 0.2, d - 0.2), Color(0.35, 0.3, 0.26))
	if open_front:
		var post := 0.6
		stone.box(Vector3(-w * 0.5 + post * 0.5, gh * 0.5, d * 0.5 - th * 0.5), Vector3(post, gh, th), sc, 0.04)
		stone.box(Vector3(w * 0.5 - post * 0.5, gh * 0.5, d * 0.5 - th * 0.5), Vector3(post, gh, th), sc, 0.04)
		wood.box(Vector3(0, gh - 0.25, d * 0.5 - th * 0.5), Vector3(w, 0.5, th + 0.1), WOOD_DARK, 0.04)
		wood.box(Vector3(0, 1.0, d * 0.5 - 0.6), Vector3(w - 1.4, 0.1, 0.9), WOOD.lightened(0.1), 0.03)
		wood.box(Vector3(0, 0.5, d * 0.5 - 0.45), Vector3(w - 1.4, 0.9, 0.12), WOOD, 0.02)
		for k in int((w - 1.4) / 0.5):
			wood.box(Vector3(-w * 0.5 + 0.95 + k * 0.5, 0.5, d * 0.5 - 0.37), Vector3(0.06, 0.8, 0.04), WOOD_DARK, 0.01)
		wood.box(Vector3(0, gh * 0.5, -d * 0.5 + th + 0.03), Vector3(w - 2 * th, gh, 0.06), WOOD_DARK)
		# awning
		var aw := G("cloth", pos)
		aw.push(t)
		var n := int(w / 0.8)
		for k in n:
			var x0 := -w * 0.5 + w * k / n
			var c := Color(0.55, 0.12, 0.1) if k % 2 == 0 else Color(0.85, 0.78, 0.6)
			if kind == "stall":
				c = Color(0.12, 0.3, 0.42) if k % 2 == 0 else Color(0.85, 0.78, 0.6)
			aw.quad_p(Vector3(x0, gh + 0.3, d * 0.5), Vector3(x0 + w / n, gh + 0.3, d * 0.5), Vector3(x0 + w / n, gh - 0.4, d * 0.5 + 1.6), Vector3(x0, gh - 0.4, d * 0.5 + 1.6), Vector3(0, 0.9, 0.4).normalized(), c)
			aw.quad_p(Vector3(x0, gh + 0.3, d * 0.5), Vector3(x0 + w / n, gh + 0.3, d * 0.5), Vector3(x0 + w / n, gh - 0.4, d * 0.5 + 1.6), Vector3(x0, gh - 0.4, d * 0.5 + 1.6), Vector3(0, -0.9, -0.4).normalized(), c.darkened(0.4))
			# scalloped valance
			aw.quad_p(Vector3(x0, gh - 0.4, d * 0.5 + 1.6), Vector3(x0 + w / n, gh - 0.4, d * 0.5 + 1.6), Vector3(x0 + w / n * 0.5, gh - 0.75, d * 0.5 + 1.62), Vector3(x0 + w / n * 0.5, gh - 0.75, d * 0.5 + 1.62), Vector3(0, 0, 1), c)
			aw.quad_p(Vector3(x0, gh - 0.4, d * 0.5 + 1.6), Vector3(x0 + w / n, gh - 0.4, d * 0.5 + 1.6), Vector3(x0 + w / n * 0.5, gh - 0.75, d * 0.5 + 1.62), Vector3(x0 + w / n * 0.5, gh - 0.75, d * 0.5 + 1.62), Vector3(0, 0, -1), c.darkened(0.4))
		aw.pop()
		wood.cyl(Vector3(-w * 0.5 + 0.1, 0, d * 0.5 + 1.6), Vector3(-w * 0.5 + 0.1, gh - 0.4, d * 0.5 + 1.6), 0.07, 0.06, WOOD_DARK, 8)
		wood.cyl(Vector3(w * 0.5 - 0.1, 0, d * 0.5 + 1.6), Vector3(w * 0.5 - 0.1, gh - 0.4, d * 0.5 + 1.6), 0.07, 0.06, WOOD_DARK, 8)
	else:
		stone.box(Vector3(0, gh * 0.5, d * 0.5 - th * 0.5), Vector3(w, gh, th), sc, 0.04)
		# door
		var dx := -w * 0.25 if kind != "tavern" else 0.0
		wood.box(Vector3(dx, 1.15, d * 0.5 + 0.02), Vector3(1.3, 2.3, 0.08), WOOD_DARK.darkened(0.2), 0.02)
		for k in 4:
			wood.box(Vector3(dx - 0.42 + k * 0.28, 1.05, d * 0.5 + 0.07), Vector3(0.24, 2.0, 0.05), WOOD.darkened(0.1 + 0.05 * k), 0.015)
		wood.box(Vector3(dx, 0.5, d * 0.5 + 0.1), Vector3(1.1, 0.06, 0.03), Color(0.1, 0.1, 0.1))
		wood.box(Vector3(dx, 1.6, d * 0.5 + 0.1), Vector3(1.1, 0.06, 0.03), Color(0.1, 0.1, 0.1))
		stone.box(Vector3(dx, 0.08, d * 0.5 + 0.35), Vector3(1.8, 0.16, 0.6), STONE, 0.03)
		stone.box(Vector3(dx, 2.42, d * 0.5 + 0.06), Vector3(1.7, 0.25, 0.2), sc.darkened(0.2), 0.03)
		glow.sphere(Vector3(dx + 0.95, 2.1, d * 0.5 + 0.3), Vector3(0.09, 0.12, 0.09), WARM, 8, 6)
		wood.box(Vector3(dx + 0.95, 2.3, d * 0.5 + 0.15), Vector3(0.05, 0.05, 0.3), Color(0.1, 0.1, 0.1))
		for sx in [-1.0, 1.0]:
			var wx: float = sx * w * 0.3 if kind == "tavern" else (w * 0.2 if sx > 0 else -100.0)
			if wx > -50.0:
				_window(win, wood, glow, Vector3(wx, 1.6, d * 0.5), 1.2, 1.3, plaster, true)
	# back + side windows on ground floor
	_window(win, wood, glow, Vector3(0, 1.6, -d * 0.5), 1.0, 1.2, plaster, false, PI)
	# upper floors (timber frame + plaster, overhanging)
	var y0 := gh
	var fh := 2.7
	for f in floors - 1:
		var oh := 0.25
		var uw := w + oh * 2.0
		var ud := d + oh * 2.0
		wood.box(Vector3(0, y0 + 0.12, 0), Vector3(uw + 0.1, 0.24, ud + 0.1), WOOD_DARK, 0.03)
		pl.box(Vector3(0, y0 + fh * 0.5, 0), Vector3(uw, fh, ud), plaster, 0.02)
		# timber framing on front/back
		for side in [1.0, -1.0]:
			var z: float = side * (ud * 0.5 + 0.03)
			wood.box(Vector3(0, y0 + fh - 0.1, z), Vector3(uw, 0.18, 0.08), WOOD_DARK, 0.02)
			var nposts := int(uw / 1.5) + 1
			for k in nposts:
				var px := -uw * 0.5 + 0.09 + (uw - 0.18) * k / float(nposts - 1)
				wood.box(Vector3(px, y0 + fh * 0.5, z), Vector3(0.16, fh, 0.08), WOOD_DARK, 0.02)
				if k < nposts - 1:
					var nx := -uw * 0.5 + 0.09 + (uw - 0.18) * (k + 1) / float(nposts - 1)
					var mid := (px + nx) * 0.5
					if k % 2 == 0:
						_window(win, wood, glow, Vector3(mid, y0 + 1.35, z - side * 0.03), 0.9, 1.1, plaster, rng.randf() < 0.5, 0.0 if side > 0 else PI)
					else:
						var a := Vector3(px, y0 + 0.1, z)
						var b := Vector3(nx, y0 + fh - 0.15, z)
						wood.push(Transform3D(Basis(Vector3.BACK, atan2(b.y - a.y, b.x - a.x) - PI * 0.5), (a + b) * 0.5))
						wood.box(Vector3.ZERO, Vector3(0.13, a.distance_to(b), 0.07), WOOD_DARK, 0.02)
						wood.pop()
		for side in [1.0, -1.0]:
			var x: float = side * (uw * 0.5 + 0.03)
			for k in 3:
				wood.box(Vector3(x, y0 + fh * 0.5, -ud * 0.5 + 0.1 + (ud - 0.2) * k / 2.0), Vector3(0.08, fh, 0.16), WOOD_DARK, 0.02)
			_window(win, wood, glow, Vector3(x - side * 0.03, y0 + 1.35, -ud * 0.25), 0.8, 1.0, plaster, false, side * PI * 0.5)
		y0 += fh
	# roof
	var ow := w + (0.5 if floors > 1 else 0.0) + 0.8
	var od := d + (0.5 if floors > 1 else 0.0) + 1.0
	var rh := od * 0.42
	_roof(rf, wood, pl, ow, od, y0, rh, roof_col, plaster)
	# chimney
	var cx := w * 0.32
	var top := y0 + rh * 0.9 + 1.0
	stone.box(Vector3(cx, (y0 + top) * 0.5, -d * 0.12), Vector3(0.8, top - y0, 0.8), STONE.darkened(0.1), 0.04)
	stone.box(Vector3(cx, top + 0.08, -d * 0.12), Vector3(1.0, 0.16, 1.0), STONE.darkened(0.2), 0.04)
	stone.cyl(Vector3(cx, top + 0.1, -d * 0.12), Vector3(cx, top + 0.45, -d * 0.12), 0.16, 0.14, Color(0.4, 0.3, 0.25), 8)
	_smoke(t * Vector3(cx, top + 0.5, -d * 0.12))
	for g: Geo in [stone, wood, pl, rf, win, glow]:
		g.pop()
	col_box(t * Vector3(0, 2.5, 0 if not open_front else -0.6), Vector3(w, 5.0, d - (1.2 if open_front else 0.0)), yaw)
	if kind == "stall" or kind == "shop":
		col_box(t * Vector3(0, 0.6, d * 0.5 - 0.5), Vector3(w, 1.2, 0.6), yaw)
	if title != "":
		_signboard(t, Vector3(0, gh + 0.15 + (0.9 if kind != "stall" else 0.0), d * 0.5 + (0.45 if kind == "tavern" else 0.3)), title, kind)
	match kind:
		"shop":
			_shop_interior(t, w, d, gh)
		"stall":
			_stall_interior(t, w, d, gh)
		"tavern":
			_tavern_front(t, w, d)
		_:
			_flower_box(t, Vector3(w * 0.2, 0.9, d * 0.5 + 0.25), 1.4)


func _window(win: Geo, wood: Geo, glow: Geo, c: Vector3, ww: float, wh: float, wall: Color, shutters: bool, yaw := 0.0) -> void:
	win.push(xf(c, yaw))
	wood.push(xf(c, yaw))
	var lit := rng.randf() < 0.72
	var gc := Color(1.0, 0.62, 0.3) * rng.randf_range(0.7, 1.2) if lit else Color(0.02, 0.025, 0.04)
	win.seed_a = rng.randf()
	win.quad_p(Vector3(-ww * 0.5, -wh * 0.5, 0.02), Vector3(ww * 0.5, -wh * 0.5, 0.02), Vector3(ww * 0.5, wh * 0.5, 0.02), Vector3(-ww * 0.5, wh * 0.5, 0.02), Vector3.BACK, gc, Vector2.ONE, true)
	var fc := WOOD_DARK.lerp(wall, 0.2)
	wood.box(Vector3(0, wh * 0.5 + 0.06, 0.05), Vector3(ww + 0.24, 0.12, 0.12), fc, 0.02)
	wood.box(Vector3(0, -wh * 0.5 - 0.07, 0.08), Vector3(ww + 0.34, 0.1, 0.2), fc, 0.02)
	wood.box(Vector3(-ww * 0.5 - 0.06, 0, 0.05), Vector3(0.1, wh + 0.2, 0.1), fc, 0.02)
	wood.box(Vector3(ww * 0.5 + 0.06, 0, 0.05), Vector3(0.1, wh + 0.2, 0.1), fc, 0.02)
	if shutters:
		var sc: Color = [Color(0.15, 0.3, 0.35), Color(0.35, 0.15, 0.12), Color(0.2, 0.3, 0.18), Color(0.3, 0.32, 0.38)][rng.randi() % 4]
		for sx in [-1.0, 1.0]:
			wood.box(Vector3(sx * (ww * 0.5 + 0.38), 0, 0.06), Vector3(ww * 0.5, wh + 0.1, 0.05), sc, 0.015)
			for k in 4:
				wood.box(Vector3(sx * (ww * 0.5 + 0.38), -wh * 0.36 + k * wh * 0.24, 0.09), Vector3(ww * 0.46, 0.05, 0.03), sc.darkened(0.25), 0.01)
	if lit and rng.randf() < 0.4:
		_flower_box_local(wood, Vector3(0, -wh * 0.5 - 0.2, 0.22), ww + 0.1)
	wood.pop()
	win.pop()


func _flower_box_local(wood: Geo, c: Vector3, l: float) -> void:
	wood.box(c, Vector3(l, 0.22, 0.25), WOOD.darkened(0.2), 0.02)
	var cols := [Color(0.9, 0.3, 0.35), Color(0.95, 0.8, 0.3), Color(0.7, 0.45, 0.9), Color(0.95, 0.95, 0.9), Color(0.95, 0.5, 0.25)]
	var n := int(l / 0.13)
	for k in n:
		var p := c + Vector3(-l * 0.5 + 0.08 + k * (l - 0.16) / maxf(1.0, n - 1), 0.14 + rng.randf() * 0.06, rng.randf_range(-0.06, 0.06))
		wood.sphere(p + Vector3(0, -0.03, 0), Vector3(0.07, 0.06, 0.07), Color(0.12, 0.25, 0.1), 6, 4)
		wood.sphere(p + Vector3(0, 0.03, 0), Vector3(0.04, 0.03, 0.04), cols[rng.randi() % cols.size()], 6, 3)


func _flower_box(t: Transform3D, c: Vector3, l: float) -> void:
	var g := G("plain", t.origin)
	g.push(t)
	_flower_box_local(g, c, l)
	g.pop()


func _roof(rf: Geo, wood: Geo, pl: Geo, w: float, d: float, base: float, h: float, col: Color, plaster: Color) -> void:
	var rows := int(ceil((d * 0.5) / 0.3))
	for side in [1.0, -1.0]:
		for k in rows:
			var t0 := float(k) / rows
			var t1 := float(k + 1) / rows
			var z0: float = side * (d * 0.5) * (1.0 - t0)
			var z1: float = side * (d * 0.5) * (1.0 - t1)
			var y0 := base + h * pow(t0, 1.35) + (0.12 if k == 0 else 0.0)
			var y1 := base + h * pow(t1, 1.35)
			var slope := Vector3(0, y1 - y0, z1 - z0).normalized()
			var nrm := Vector3(0, absf(z1 - z0), side * (y1 - y0)).normalized()
			var lift := nrm * 0.07
			var p0 := Vector3(-w * 0.5, y0, z0) + lift
			var p1 := Vector3(w * 0.5, y0, z0) + lift
			var p2 := Vector3(w * 0.5, y1, z1)
			var p3 := Vector3(-w * 0.5, y1, z1)
			var c := col.lightened(rng.randf() * 0.05)
			var a := rf.vert(p0, nrm, c, Vector2(-w * 0.5, k * 0.3))
			var b := rf.vert(p1, nrm, c, Vector2(w * 0.5, k * 0.3))
			var cc := rf.vert(p2, nrm, c, Vector2(w * 0.5, k * 0.3 + 0.299))
			var dd := rf.vert(p3, nrm, c, Vector2(-w * 0.5, k * 0.3 + 0.299))
			rf.quad(a, b, cc, dd)
			# underside
			var un := -nrm
			rf.quad(rf.vert(p0 - lift, un, c.darkened(0.5), Vector2.ZERO), rf.vert(p1 - lift, un, c.darkened(0.5), Vector2.ZERO), rf.vert(p2 - lift * 0.0 - nrm * 0.02, un, c.darkened(0.5), Vector2.ZERO), rf.vert(p3 - nrm * 0.02, un, c.darkened(0.5), Vector2.ZERO))
			# lip of the row
			var fn := (slope * -1.0)
			rf.quad(rf.vert(p0, fn, c.darkened(0.3), Vector2(-w * 0.5, k * 0.3)), rf.vert(p1, fn, c.darkened(0.3), Vector2(w * 0.5, k * 0.3)), rf.vert(p1 - lift * 1.3, fn, c.darkened(0.3), Vector2(w * 0.5, k * 0.3 + 0.05)), rf.vert(p0 - lift * 1.3, fn, c.darkened(0.3), Vector2(-w * 0.5, k * 0.3 + 0.05)))
		# barge boards along the rake
		for sx in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for k in rows + 1:
				var tt := float(k) / rows
				pts.append(Vector3(sx * (w * 0.5 + 0.05), base + h * pow(tt, 1.35) + 0.06, side * (d * 0.5) * (1.0 - tt)))
			wood.tube(pts, 0.09, WOOD_DARK, 4)
	# ridge
	rf.cyl(Vector3(-w * 0.5 - 0.1, base + h + 0.05, 0), Vector3(w * 0.5 + 0.1, base + h + 0.05, 0), 0.14, 0.14, col.darkened(0.3), 10)
	# gable walls
	var inset := 0.45
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w * 0.5 - inset)
		var nrm := Vector3(sx, 0, 0)
		var ids: Array[int] = []
		var steps := 10
		var center := pl.vert(Vector3(x, base + h * 0.3, 0), nrm, plaster, Vector2(0, -(base + h * 0.3)))
		for k in steps + 1:
			var tt := float(k) / steps
			var z := (d * 0.5 - 0.5) * (1.0 - 2.0 * tt)
			var a := absf(z) / (d * 0.5)
			var y := base + h * pow(1.0 - a, 1.35) - 0.05
			ids.append(pl.vert(Vector3(x, y, z), nrm, plaster, Vector2(z, -y)))
		var bl := pl.vert(Vector3(x, base, -(d * 0.5 - 0.5)), nrm, plaster, Vector2(-(d * 0.5 - 0.5), -base))
		var br := pl.vert(Vector3(x, base, d * 0.5 - 0.5), nrm, plaster, Vector2(d * 0.5 - 0.5, -base))
		for k in steps:
			pl.tri(center, ids[k], ids[k + 1])
		pl.tri(center, ids[0], br)
		pl.tri(center, br, bl)
		pl.tri(center, bl, ids[steps])
		wood.box(Vector3(x + sx * 0.04, base + 0.1, 0), Vector3(0.08, 0.2, d - 1.0), WOOD_DARK, 0.02)
		wood.box(Vector3(x + sx * 0.04, base + h * 0.5, 0), Vector3(0.08, h, 0.16), WOOD_DARK, 0.02)


func _signboard(t: Transform3D, local: Vector3, title: String, kind: String) -> void:
	var p := t * local
	var yaw := t.basis.get_euler().y
	var wood := G("wood", p)
	wood.push(Transform3D(t.basis, p))
	var bw := 0.42 * title.length() * 0.62 + 0.8
	wood.box(Vector3(0, 0, 0), Vector3(bw, 0.95, 0.12), Color(0.24, 0.15, 0.09), 0.05)
	wood.box(Vector3(0, 0, 0.02), Vector3(bw + 0.15, 1.08, 0.1), Color(0.5, 0.36, 0.14), 0.04)
	wood.pop()
	var l := label(title, t * (local + Vector3(0, 0.02, 0.1)), yaw, 110)
	l.pixel_size = 0.0045
	var lamp_at := t * (local + Vector3(0, 0.8, 0.6))
	var g := G("metal", lamp_at)
	g.cyl(t * (local + Vector3(0, 0.62, 0.05)), lamp_at + Vector3(0, 0.12, 0), 0.02, 0.02, Color(0.1, 0.1, 0.1), 5)
	G("glow", lamp_at).sphere(lamp_at, Vector3(0.08, 0.06, 0.08), WARM * 1.5, 8, 5)
	light(t * (local + Vector3(0, 0.5, 1.2)), WARM, 1.2, 4.0)


func _shop_interior(t: Transform3D, w: float, d: float, gh: float) -> void:
	var wood := G("wood", t.origin)
	var glow := G("glow", t.origin)
	wood.push(t)
	glow.push(t)
	var courts := [Color(1.0, 0.42, 0.24), Color(0.24, 0.65, 1.0), Color(0.36, 0.82, 0.42), Color(0.79, 0.71, 1.0), Color(1.0, 0.82, 0.4)]
	# back shelves with glowing card displays
	for row in 3:
		var y := 0.9 + row * 0.62
		wood.box(Vector3(0, y, -d * 0.5 + 0.6), Vector3(w - 1.4, 0.06, 0.45), WOOD.lightened(0.05), 0.015)
		for k in 9:
			var x := -w * 0.5 + 1.2 + k * (w - 2.4) / 8.0
			var c: Color = courts[(k + row) % 5]
			glow.seed_a = rng.randf()
			wood.push(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(x, y + 0.24, -d * 0.5 + 0.55)))
			wood.box(Vector3.ZERO, Vector3(0.36, 0.46, 0.03), Color(0.9, 0.82, 0.6), 0.01)
			wood.pop()
			glow.push(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(x, y + 0.24, -d * 0.5 + 0.57)))
			glow.box(Vector3.ZERO, Vector3(0.28, 0.36, 0.01), c * 1.4)
			glow.pop()
	for sx in [-1.0, 1.0]:
		wood.box(Vector3(sx * (w * 0.5 - 0.8), 1.5, -d * 0.5 + 0.6), Vector3(0.1, 2.6, 0.5), WOOD_DARK, 0.02)
	# counter display: card fan, chest, jars
	for k in 5:
		var c: Color = courts[k]
		glow.push(Transform3D(Basis(Vector3.UP, -0.5 + k * 0.25).rotated(Vector3.RIGHT, -1.3), Vector3(-1.8 + k * 0.22, 1.08, d * 0.5 - 0.6)))
		glow.box(Vector3.ZERO, Vector3(0.24, 0.32, 0.01), c * 1.2)
		glow.pop()
	wood.box(Vector3(1.5, 1.25, d * 0.5 - 0.6), Vector3(0.7, 0.4, 0.45), Color(0.35, 0.18, 0.1), 0.03)
	wood.box(Vector3(1.5, 1.47, d * 0.5 - 0.6), Vector3(0.72, 0.06, 0.47), Color(0.8, 0.6, 0.2), 0.02)
	glow.box(Vector3(1.5, 1.52, d * 0.5 - 0.6), Vector3(0.5, 0.02, 0.3), Color(1.0, 0.8, 0.35) * 1.2)
	wood.pop()
	glow.pop()
	var l := light(t * Vector3(0, 2.6, 0.5), Color(1.0, 0.7, 0.4), 3.0, 7.5, true)
	l.shadow_blur = 2.0
	light(t * Vector3(0, 1.5, d * 0.5 + 1.0), Color(1.0, 0.75, 0.45), 1.2, 6.0)
	var keeper := CharModel.new()
	keeper.name = "Shopkeeper"
	add_child(keeper)
	keeper.global_transform = Transform3D(t.basis, t * Vector3(0.5, 0.2, d * 0.5 - 1.6))
	keeper.configure({"coat": Color(0.45, 0.16, 0.2), "accent": Color(0.95, 0.8, 0.4), "hat": "tricorn", "beard": true, "hair": Color(0.6, 0.6, 0.62), "body": "stout", "skin": Color(0.85, 0.65, 0.5)})
	keeper.play("talk")
	interactable(t * Vector3(0, 0, d * 0.5 + 1.4), "shop", "Browse the Gilded Gull", {}, 2.8)


func _stall_interior(t: Transform3D, w: float, d: float, gh: float) -> void:
	var wood := G("wood", t.origin)
	var plain := G("plain", t.origin)
	var glow := G("glow", t.origin)
	for g: Geo in [wood, plain, glow]:
		g.push(t)
	# desk
	var dz := 0.2
	wood.box(Vector3(0, 0.82, dz), Vector3(2.4, 0.08, 1.1), WOOD.lightened(0.1), 0.03)
	for sx in [-1.0, 1.0]:
		wood.box(Vector3(sx * 1.05, 0.4, dz), Vector3(0.3, 0.8, 1.0), WOOD_DARK, 0.03)
	# maps and card piles
	plain.push(Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.4, 0.87, dz)))
	plain.box(Vector3.ZERO, Vector3(1.0, 0.01, 0.7), Color(0.85, 0.76, 0.55))
	plain.cyl(Vector3(-0.2, 0.01, 0.1), Vector3(0.1, 0.01, -0.15), 0.006, 0.006, Color(0.6, 0.2, 0.15), 4)
	plain.pop()
	var courts := [Color(1.0, 0.42, 0.24), Color(0.24, 0.65, 1.0), Color(0.36, 0.82, 0.42), Color(0.79, 0.71, 1.0), Color(1.0, 0.82, 0.4)]
	for k in 4:
		for j in 6:
			plain.push(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), Vector3(0.45 + k * 0.17, 0.87 + j * 0.008, dz + 0.25 - k * 0.1)))
			plain.box(Vector3.ZERO, Vector3(0.12, 0.007, 0.17), (courts[k] as Color).darkened(0.3) if j < 5 else Color(0.18, 0.15, 0.3))
			plain.pop()
	plain.cyl(Vector3(0.9, 0.86, dz - 0.3), Vector3(0.9, 0.98, dz - 0.3), 0.04, 0.035, Color(0.1, 0.1, 0.12), 8)
	plain.cyl(Vector3(0.88, 0.95, dz - 0.3), Vector3(0.7, 1.15, dz - 0.4), 0.004, 0.002, Color(0.9, 0.9, 0.9), 4)
	# candle
	var cp := Vector3(-0.95, 0.86, dz - 0.3)
	plain.lathe(cp, PackedVector2Array([Vector2(0.09, 0), Vector2(0.09, 0.02), Vector2(0.02, 0.03), Vector2(0.02, 0.06), Vector2(0.0, 0.06)]), 10, Color(0.75, 0.55, 0.2))
	plain.cyl(cp + Vector3(0, 0.06, 0), cp + Vector3(0, 0.22, 0), 0.025, 0.025, Color(0.95, 0.9, 0.8), 8)
	glow.sphere(cp + Vector3(0, 0.26, 0), Vector3(0.015, 0.035, 0.015), Color(1.0, 0.75, 0.35) * 2.0, 6, 4)
	# globe
	plain.lathe(Vector3(-1.2, 0, -1.5), PackedVector2Array([Vector2(0.25, 0), Vector2(0.05, 0.1), Vector2(0.05, 0.9), Vector2(0.0, 0.9)]), 10, Color(0.5, 0.35, 0.15))
	plain.sphere(Vector3(-1.2, 1.2, -1.5), Vector3(0.3, 0.3, 0.3), Color(0.2, 0.4, 0.5), 14, 10)
	# wall maps
	for k in 3:
		plain.box(Vector3(-1.6 + k * 1.6, 1.9, -d * 0.5 + 0.4), Vector3(1.2, 0.85, 0.02), Color(0.82, 0.72, 0.52))
		plain.box(Vector3(-1.6 + k * 1.6, 1.9, -d * 0.5 + 0.39), Vector3(1.3, 0.95, 0.02), WOOD_DARK)
	# chair
	_chair(wood, Vector3(0, 0, dz - 1.0), 0.0)
	for g: Geo in [wood, plain, glow]:
		g.pop()
	light(t * (cp + Vector3(0, 0.4, 0)), Color(1.0, 0.68, 0.35), 1.6, 5.0, true, 0.6)
	light(t * Vector3(0, 2.6, 0.5), Color(1.0, 0.7, 0.4), 1.2, 6.0)
	interactable(t * Vector3(0, 0, d * 0.5 + 1.2), "deck", "Build your deck at the Cartographer's Desk", {}, 2.4)


func _chair(g: Geo, p: Vector3, yaw: float) -> void:
	g.push(xf(p, yaw))
	g.box(Vector3(0, 0.46, 0), Vector3(0.5, 0.06, 0.5), WOOD, 0.02)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g.cyl(Vector3(sx * 0.21, 0, sz * 0.21), Vector3(sx * 0.21, 0.45, sz * 0.21), 0.03, 0.025, WOOD_DARK, 6)
		g.cyl(Vector3(sx * 0.21, 0.46, 0.22), Vector3(sx * 0.21, 1.0, 0.25), 0.03, 0.025, WOOD_DARK, 6)
	g.box(Vector3(0, 0.9, 0.24), Vector3(0.48, 0.14, 0.04), WOOD, 0.02)
	g.box(Vector3(0, 0.68, 0.23), Vector3(0.1, 0.32, 0.03), WOOD, 0.01)
	g.pop()


func _tavern_front(t: Transform3D, w: float, d: float) -> void:
	var wood := G("wood", t.origin)
	var plain := G("plain", t.origin)
	wood.push(t)
	plain.push(t)
	# notice board
	var nb := Vector3(-3.6, 0, d * 0.5 + 1.6)
	wood.cyl(nb + Vector3(-0.9, 0, 0), nb + Vector3(-0.9, 2.4, 0), 0.07, 0.06, WOOD_DARK, 8)
	wood.cyl(nb + Vector3(0.9, 0, 0), nb + Vector3(0.9, 2.4, 0), 0.07, 0.06, WOOD_DARK, 8)
	wood.box(nb + Vector3(0, 1.55, 0), Vector3(1.9, 1.2, 0.08), WOOD.lightened(0.15), 0.02)
	wood.push(Transform3D(Basis.IDENTITY, nb + Vector3(0, 2.4, 0.05)))
	wood.box(Vector3(0, 0, 0), Vector3(2.2, 0.08, 0.5), Color(0.3, 0.2, 0.15), 0.02)
	wood.pop()
	var poster_cols := [Color(0.9, 0.82, 0.62), Color(0.85, 0.75, 0.55), Color(0.92, 0.88, 0.75), Color(0.8, 0.7, 0.5), Color(0.9, 0.8, 0.6)]
	for k in 6:
		var pp := nb + Vector3(-0.6 + (k % 3) * 0.6 + rng.randf_range(-0.05, 0.05), 1.82 - (k / 3) * 0.55, 0.05)
		plain.push(Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08)), pp))
		plain.box(Vector3.ZERO, Vector3(0.42, 0.48, 0.01), poster_cols[k % 5])
		plain.box(Vector3(0, 0.12, 0.007), Vector3(0.3, 0.05, 0.004), Color(0.25, 0.15, 0.1))
		plain.box(Vector3(0, -0.03, 0.007), Vector3(0.22, 0.16, 0.004), [Color(0.7, 0.3, 0.2), Color(0.2, 0.4, 0.6), Color(0.3, 0.5, 0.3)][k % 3])
		plain.sphere(Vector3(0, 0.21, 0.01), Vector3(0.02, 0.02, 0.01), Color(0.7, 0.15, 0.1), 5, 3)
		plain.pop()
	var nbw := t * nb
	label("Campaign Board", t * (nb + Vector3(0, 2.75, 0.1)), t.basis.get_euler().y, 64)
	light(t * (nb + Vector3(0, 2.3, 0.7)), WARM, 1.4, 4.5)
	col_box(t * (nb + Vector3(0, 1.0, 0)), Vector3(2.0, 2.0, 0.3), t.basis.get_euler().y)
	interactable(nbw + t.basis * Vector3(0, 0, 0.8), "campaign", "Read the Campaign Board", {}, 3.1)
	# outdoor card table with the challenger
	var tp := Vector3(3.6, 0, d * 0.5 + 2.4)
	wood.lathe(tp, PackedVector2Array([Vector2(0.4, 0), Vector2(0.1, 0.12), Vector2(0.08, 0.6), Vector2(0.12, 0.7), Vector2(0.0, 0.7)]), 12, WOOD_DARK)
	wood.lathe(tp, PackedVector2Array([Vector2(0.0, 0.7), Vector2(0.75, 0.7), Vector2(0.78, 0.74), Vector2(0.75, 0.78), Vector2(0.0, 0.78)]), 24, WOOD)
	plain.lathe(tp, PackedVector2Array([Vector2(0.0, 0.785), Vector2(0.62, 0.785)]), 24, Color(0.12, 0.3, 0.22))
	for k in 5:
		plain.push(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tp + Vector3(rng.randf_range(-0.3, 0.3), 0.79 + k * 0.003, rng.randf_range(-0.3, 0.3))))
		plain.box(Vector3.ZERO, Vector3(0.12, 0.004, 0.17), Color(0.9, 0.85, 0.7) if k % 2 == 0 else Color(0.2, 0.15, 0.35))
		plain.pop()
	plain.cyl(tp + Vector3(0.35, 0.78, -0.2), tp + Vector3(0.35, 0.93, -0.2), 0.05, 0.055, Color(0.4, 0.28, 0.15), 10)
	_chair(wood, tp + Vector3(0, 0, -1.0), 0.0)
	_chair(wood, tp + Vector3(0, 0, 1.0), PI)
	wood.pop()
	plain.pop()
	var lantern := t * (tp + Vector3(-0.3, 0.86, 0.2))
	G("glow", lantern).sphere(lantern + Vector3(0, 0.1, 0), Vector3(0.05, 0.08, 0.05), WARM * 1.6, 8, 5)
	G("metal", lantern).lathe(lantern, PackedVector2Array([Vector2(0.08, 0), Vector2(0.08, 0.03), Vector2(0.03, 0.04), Vector2(0.03, 0.22), Vector2(0.07, 0.24), Vector2(0.0, 0.3)]), 8, Color(0.15, 0.13, 0.1))
	light(lantern + Vector3(0, 0.4, 0), WARM, 1.8, 5.5, true, 0.5)
	var ch := CharModel.new()
	ch.name = "Challenger"
	add_child(ch)
	ch.global_transform = Transform3D(t.basis * Basis(Vector3.UP, PI), t * (tp + Vector3(0, 0.49, -0.95)))
	ch.configure({"coat": Color(0.3, 0.18, 0.4), "accent": Color(0.79, 0.71, 1.0), "hat": "wizard", "hair": Color(0.85, 0.85, 0.9), "beard": true, "body": "slim", "skin": Color(0.8, 0.62, 0.5)})
	ch.play("sit")
	ch.play("think")
	label("Challenger", t * (tp + Vector3(0, 2.35, -0.95)), t.basis.get_euler().y, 48, Color(0.85, 0.8, 1.0))
	interactable(t * (tp + Vector3(0, 0, 0.3)), "campaign", "Challenge the Old Tactician", {}, 2.7)
	col_box(t * (tp + Vector3(0, 0.5, 0)), Vector3(1.6, 1.0, 2.8), t.basis.get_euler().y)


# --- docks & boats -------------------------------------------------------------------

func _docks() -> void:
	_dock(Vector3(-8, 0, -17), 28.0, 3.2, true)
	_dock(Vector3(14, 0, -17), 20.0, 2.6, false)


func _dock(start: Vector3, length: float, width: float, tee: bool) -> void:
	var z := start.z
	var end_z := start.z - length
	while z > end_z:
		var g := G("wood", Vector3(start.x, 0, z))
		var plank_l := width
		var c := WOOD.darkened(rng.randf() * 0.25).lerp(Color(0.4, 0.38, 0.35), 0.25)
		g.box(Vector3(start.x + rng.randf_range(-0.03, 0.03), -0.02, z - 0.13), Vector3(plank_l + rng.randf_range(0, 0.1), 0.07, 0.24), c, 0.015)
		z -= 0.27
	var gw := G("wood", Vector3(start.x, 0, start.z - length * 0.5))
	var pz := start.z - 0.5
	while pz > end_z - 0.1:
		for sx in [-1.0, 1.0]:
			var px: float = start.x + sx * (width * 0.5 + 0.08)
			gw.cyl(Vector3(px, -4.0, pz), Vector3(px, 0.55, pz), 0.14, 0.13, WOOD_DARK, 8)
			gw.cyl(Vector3(px, 0.55, pz), Vector3(px, 0.62, pz), 0.13, 0.0, WOOD_DARK, 8, false)
		gw.box(Vector3(start.x, -0.12, pz), Vector3(width + 0.4, 0.14, 0.18), WOOD_DARK, 0.02)
		pz -= 2.6
	for sx in [-1.0, 1.0]:
		gw.box(Vector3(start.x + sx * (width * 0.5 - 0.05), -0.16, start.z - length * 0.5), Vector3(0.14, 0.18, length), WOOD_DARK, 0.02)
		# rope rail between posts
		var rp := start.z - 0.5
		while rp - 2.6 > end_z - 0.1:
			var px: float = start.x + sx * (width * 0.5 + 0.08)
			G("plain", Vector3(px, 0, rp)).tube(Geo.sag(Vector3(px, 0.45, rp), Vector3(px, 0.45, rp - 2.6), 0.25, 8), 0.025, Color(0.55, 0.45, 0.3), 5)
			rp -= 2.6
	col_box(Vector3(start.x, -0.25, start.z - length * 0.5), Vector3(width, 0.5, length))
	for sx in [-1.0, 1.0]:
		col_box(Vector3(start.x + sx * (width * 0.5 + 0.25), 1.0, start.z - length * 0.5), Vector3(0.4, 2.0, length))
	col_box(Vector3(start.x, 1.0, end_z - 0.2), Vector3(width + 0.8, 2.0, 0.4))
	if tee:
		var tz := end_z + 1.6
		for k in 16:
			var x := start.x - 6.0 + k * 0.75
			if absf(x - start.x) < width * 0.5:
				continue
			G("wood", Vector3(x, 0, tz)).box(Vector3(x, -0.02, tz), Vector3(0.7, 0.07, 3.0), WOOD.darkened(rng.randf() * 0.25).lerp(Color(0.4, 0.38, 0.35), 0.25), 0.015)
		for x in [-5.8, -3.0, 3.0, 5.8]:
			for zz in [-1.4, 1.4]:
				G("wood", Vector3(start.x + x, 0, tz)).cyl(Vector3(start.x + x, -4.0, tz + zz), Vector3(start.x + x, 0.5, tz + zz), 0.14, 0.13, WOOD_DARK, 8)
		col_box(Vector3(start.x, -0.25, tz), Vector3(12.0, 0.5, 3.0))
		col_box(Vector3(start.x - 6.2, 1.0, tz), Vector3(0.4, 2.0, 3.4))
		col_box(Vector3(start.x + 6.2, 1.0, tz), Vector3(0.4, 2.0, 3.4))
		col_box(Vector3(start.x, 1.0, tz - 1.7), Vector3(12.4, 2.0, 0.4))
		col_box(Vector3(start.x - 3.9, 1.0, tz + 1.7), Vector3(4.6, 2.0, 0.4))
		col_box(Vector3(start.x + 3.9, 1.0, tz + 1.7), Vector3(4.6, 2.0, 0.4))
		# lantern pole at the end
		_lamp(Vector3(start.x + 5.6, 0, tz - 1.2), true)


func _hull(g: Geo, length: float, beam: float, depth: float, col: Color, trim: Color) -> void:
	# Cross-sections along Z (bow at -Z); outer and inner skins plus gunwale.
	var ns := 16
	var nr := 9
	var outer := []
	var inner := []
	for i in ns + 1:
		var t := float(i) / ns
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var bow := pow(clampf((0.5 - t) / 0.5, 0.0, 1.0), 2.0)
		var widthf := sin(PI * clampf(t * 0.92 + 0.06, 0.0, 1.0)) * (1.0 - bow * 0.15)
		widthf = maxf(widthf, 0.05 if t > 0.5 else 0.0)
		var sheer := 0.18 * pow(absf(t - 0.55) * 2.0, 2.0)
		var keel := -depth * (0.85 + 0.15 * sin(PI * t))
		var ro: Array[int] = []
		var ri: Array[int] = []
		for j in nr + 1:
			var a := lerpf(-PI * 0.5, PI * 0.5, float(j) / nr)
			var sx := sin(a)
			var cy := -cos(a)
			var x := sx * beam * 0.5 * widthf * (0.65 + 0.35 * absf(sx))
			var y := sheer + (keel - sheer) * pow(maxf(0.0, -cy), 1.1) * 1.0 if cy < 0.0 else sheer
			y = lerpf(sheer, keel, pow(cos(a), 1.6))
			var nrm := Vector3(sx, -cos(a) * 1.2, 0).normalized()
			var c := col if y > -depth * 0.45 else col.darkened(0.45).lerp(Color(0.3, 0.12, 0.08), 0.5)
			ro.append(g.vert(Vector3(x, y, z), nrm, c, Vector2(z, y)))
			ri.append(g.vert(Vector3(x * 0.94, lerpf(y, sheer, 0.06) + 0.03, z), -nrm, col.darkened(0.35), Vector2(z, y)))
		outer.append(ro)
		inner.append(ri)
	for i in ns:
		var o0: Array[int] = outer[i]
		var o1: Array[int] = outer[i + 1]
		var i0: Array[int] = inner[i]
		var i1: Array[int] = inner[i + 1]
		for j in nr:
			g.quad(o0[j], o0[j + 1], o1[j + 1], o1[j])
			g.quad(i0[j], i0[j + 1], i1[j + 1], i1[j])
	# gunwale rails
	for j in [0, nr]:
		var pts := PackedVector3Array()
		for i in ns + 1:
			pts.append(g.xf.affine_inverse() * g.verts[(outer[i] as Array[int])[j]])
		g.tube(pts, 0.045, trim, 5)
	# transom
	var last: Array[int] = outer[ns]
	var c0 := g.verts[last[0]]
	var nrm_t := g.xf.basis * Vector3(0, 0, 1)
	var center := g.vert(g.xf.affine_inverse() * ((g.verts[last[0]] + g.verts[last[nr]]) * 0.5), Vector3.BACK, col.darkened(0.2), Vector2.ZERO)
	for j in nr:
		g.tri(center, g.vert(g.xf.affine_inverse() * g.verts[last[j]], Vector3.BACK, col.darkened(0.2), Vector2.ZERO), g.vert(g.xf.affine_inverse() * g.verts[last[j + 1]], Vector3.BACK, col.darkened(0.2), Vector2.ZERO))
	# thwarts
	for k in 3:
		var z := lerpf(-length * 0.25, length * 0.3, k / 2.0)
		g.box(Vector3(0, -depth * 0.25, z), Vector3(beam * 0.85, 0.05, 0.25), trim.darkened(0.2), 0.01)


func _boat(pos: Vector3, yaw: float, length: float, mast: bool, col: Color, trim: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.set_script(Fx)
	holder.set("mode", "bob")
	holder.set("speed", rng.randf_range(0.8, 1.2))
	add_child(holder)
	var g := Geo.new()
	g.seed_a = rng.randf()
	g.long_u = true
	_hull(g, length, length * 0.36, length * 0.17, col, trim)
	var gm := Geo.new()
	if mast:
		g.cyl(Vector3(0, -0.2, -length * 0.15), Vector3(0, length * 1.1, -length * 0.15), 0.07, 0.05, WOOD, 8)
		g.cyl(Vector3(0, 0.9, -length * 0.15), Vector3(0, 0.5, length * 0.4), 0.04, 0.035, WOOD, 6)
		# furled sail along the boom
		var pts := PackedVector3Array()
		for k in 9:
			pts.append(Vector3(0, 0.92 + 0.03 * sin(k), lerpf(-length * 0.15, length * 0.38, k / 8.0)).lerp(Vector3(0, 0.55, length * 0.4), 0.0))
		gm.tube(pts, 0.11, Color(0.75, 0.7, 0.6), 8, PackedFloat32Array([0.08, 0.12, 0.13, 0.12, 0.13, 0.11, 0.1, 0.08, 0.05]))
		gm.tube(PackedVector3Array([Vector3(0, length * 1.1, -length * 0.15), Vector3(0, 0.15, -length * 0.5)]), 0.012, Color(0.5, 0.42, 0.3), 4)
		gm.tube(PackedVector3Array([Vector3(0, length * 1.1, -length * 0.15), Vector3(0, 0.15, length * 0.5)]), 0.012, Color(0.5, 0.42, 0.3), 4)
		gm.sphere(Vector3(0, -0.05, length * 0.2), Vector3(0.18, 0.12, 0.18), Color(0.25, 0.2, 0.15), 8, 5)
	else:
		g.cyl(Vector3(-0.3, 0.05, 0.1), Vector3(-1.0, 0.25, 0.8), 0.025, 0.02, WOOD, 6)
		g.box(Vector3(-1.05, 0.26, 0.86), Vector3(0.06, 0.03, 0.4), WOOD, 0.01)
		gm.lathe(Vector3(0.2, -length * 0.08, 0.5), PackedVector2Array([Vector2(0.2, 0), Vector2(0.2, 0.05), Vector2(0.12, 0.05), Vector2(0.12, 0.0)]), 12, Color(0.6, 0.5, 0.35))
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(Mats.get_mat("wood"))
	holder.add_child(mi)
	if not gm.is_empty():
		var mi2 := MeshInstance3D.new()
		mi2.mesh = gm.to_mesh(Mats.get_mat("plain"))
		holder.add_child(mi2)


func _boats() -> void:
	_boat(Vector3(-11.6, SEA + 0.05, -26), 0.08, 6.5, true, Color(0.2, 0.32, 0.4), Color(0.75, 0.6, 0.3))
	_boat(Vector3(-4.4, SEA + 0.05, -31), -0.05, 4.0, false, Color(0.6, 0.2, 0.15), Color(0.8, 0.75, 0.6))
	_boat(Vector3(-15.0, SEA + 0.05, -48), 1.45, 7.5, true, Color(0.75, 0.72, 0.65), Color(0.2, 0.3, 0.45))
	_boat(Vector3(17.2, SEA + 0.05, -27), PI + 0.06, 4.2, false, Color(0.25, 0.42, 0.3), Color(0.85, 0.8, 0.6))
	_boat(Vector3(10.8, SEA + 0.05, -32), 0.1, 5.5, true, Color(0.55, 0.35, 0.18), Color(0.85, 0.75, 0.5))
	_boat(Vector3(-38, -1.2, -24), 0.6, 4.0, false, Color(0.3, 0.3, 0.45), Color(0.8, 0.75, 0.6))


# --- lighthouse ------------------------------------------------------------------------

func _lighthouse() -> void:
	var base := Vector3(43, height(43, -44) - 0.3, -44)
	var g := G("plaster", base)
	var prof := PackedVector2Array()
	var cols := PackedColorArray()
	var hgt := 20.0
	for k in 11:
		var y := hgt * k / 10.0
		var r := lerpf(3.0, 1.8, k / 10.0)
		prof.append(Vector2(r, y))
		cols.append(Color(0.9, 0.88, 0.84) if (k / 2) % 2 == 0 else Color(0.62, 0.16, 0.13))
		if k < 10:
			prof.append(Vector2(lerpf(3.0, 1.8, (k + 0.999) / 10.0), hgt * (k + 0.999) / 10.0))
			cols.append(cols[cols.size() - 1])
	g.lathe(base, prof, 28, Color.WHITE, 1.0, 1.0, false, false, TAU, 0.0, false, cols)
	var st := G("stone", base)
	st.lathe(base + Vector3(0, -1.0, 0), PackedVector2Array([Vector2(4.2, 0), Vector2(4.0, 1.6), Vector2(3.3, 1.8), Vector2(0, 1.8)]), 24, STONE.darkened(0.2))
	var top := base + Vector3(0, hgt, 0)
	var m := G("metal", top)
	m.lathe(top, PackedVector2Array([Vector2(1.6, -0.3), Vector2(2.6, 0.0), Vector2(2.6, 0.25), Vector2(0.0, 0.25)]), 24, Color(0.15, 0.15, 0.17))
	for k in 24:
		var a := TAU * k / 24.0
		m.cyl(top + Vector3(cos(a) * 2.5, 0.25, sin(a) * 2.5), top + Vector3(cos(a) * 2.5, 1.2, sin(a) * 2.5), 0.03, 0.03, Color(0.1, 0.1, 0.1), 4, false)
	m.tube(Geo.sag(top, top, 0, 1), 0.01, Color.BLACK, 3)
	var ring := PackedVector3Array()
	for k in 25:
		var a := TAU * k / 24.0
		ring.append(top + Vector3(cos(a) * 2.5, 1.2, sin(a) * 2.5))
	m.tube(ring, 0.05, Color(0.1, 0.1, 0.1), 5)
	for k in 8:
		var a := TAU * k / 8.0
		m.cyl(top + Vector3(cos(a) * 1.4, 0.25, sin(a) * 1.4), top + Vector3(cos(a) * 1.3, 2.6, sin(a) * 1.3), 0.06, 0.06, Color(0.12, 0.12, 0.12), 5)
	G("glow", top).lathe(top, PackedVector2Array([Vector2(1.3, 0.3), Vector2(1.25, 2.55)]), 16, Color(1.4, 1.1, 0.7))
	var rr := G("roof", top)
	rr.lathe(top, PackedVector2Array([Vector2(1.7, 2.55), Vector2(1.75, 2.7), Vector2(1.2, 3.4), Vector2(0.3, 3.9), Vector2(0.1, 4.3), Vector2(0.0, 4.3)]), 20, Color(0.55, 0.15, 0.12))
	# door + windows
	var gw := G("window", base)
	for k in 3:
		var y := 5.0 + k * 5.0
		var r := lerpf(3.0, 1.8, y / hgt) + 0.02
		gw.quad_p(base + Vector3(-0.35, y - 0.5, r), base + Vector3(0.35, y - 0.5, r), base + Vector3(0.35, y + 0.5, r), base + Vector3(-0.35, y + 0.5, r), Vector3.BACK, Color(1.0, 0.6, 0.3), Vector2.ONE, true)
	light(top + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.6), 6.0, 20.0)
	var spin := Node3D.new()
	spin.position = top + Vector3(0, 1.4, 0)
	spin.set_script(Fx)
	spin.set("mode", "spin")
	spin.set("speed", 0.55)
	add_child(spin)
	var bm := ShaderMaterial.new()
	bm.shader = BEAM
	bm.set_shader_parameter("color", Color(1.0, 0.9, 0.7))
	bm.set_shader_parameter("intensity", 0.22)
	for side in [1.0, -1.0]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 0.6
		cm.height = 70.0
		cm.cap_top = false
		cm.cap_bottom = false
		cm.radial_segments = 24
		cone.mesh = cm
		cone.material_override = bm
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation = Vector3(side * PI * 0.5 + side * 0.06, 0, 0)
		cone.position = Vector3(0, 0, side * 35.0).rotated(Vector3.RIGHT, side * 0.06 * 0.0)
		cone.position.y = -side * 35.0 * sin(0.06) * side
		spin.add_child(cone)
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.9, 0.7)
	sp.light_energy = 4.0
	sp.spot_range = 90.0
	sp.spot_angle = 6.0
	sp.rotation.x = -0.06
	spin.add_child(sp)


# --- lamps & lights ----------------------------------------------------------------------

func _lamp(p: Vector3, shadow: bool) -> void:
	var y := height(p.x, p.z) if p.z > -16.0 and absf(p.x) > 30.0 else p.y
	p.y = y
	var g := G("metal", p)
	var dark := Color(0.08, 0.08, 0.09)
	g.lathe(p, PackedVector2Array([Vector2(0.22, 0), Vector2(0.2, 0.3), Vector2(0.1, 0.4), Vector2(0.07, 0.5), Vector2(0.06, 3.2), Vector2(0.1, 3.3), Vector2(0.1, 3.35), Vector2(0, 3.35)]), 10, dark)
	g.cyl(p + Vector3(0, 3.25, 0), p + Vector3(0.55, 3.35, 0), 0.03, 0.03, dark, 5)
	var arc := PackedVector3Array()
	for k in 7:
		var a := PI * k / 6.0
		arc.append(p + Vector3(0.28 - cos(a) * 0.25, 2.95 + sin(a) * 0.3, 0))
	g.tube(arc, 0.02, dark, 4)
	var lp := p + Vector3(0.55, 2.95, 0)
	g.lathe(lp, PackedVector2Array([Vector2(0.06, -0.08), Vector2(0.14, 0.0), Vector2(0.14, 0.03), Vector2(0.12, 0.03), Vector2(0.15, 0.32), Vector2(0.22, 0.36), Vector2(0.05, 0.5), Vector2(0.0, 0.55)]), 6, dark)
	G("glow", lp).lathe(lp, PackedVector2Array([Vector2(0.08, 0.04), Vector2(0.12, 0.31), Vector2(0.0, 0.31)]), 6, Color(1.0, 0.6, 0.28) * 1.4)
	light(lp + Vector3(0, 0.15, 0), Color(1.0, 0.62, 0.32), 2.6, 11.0, shadow, 0.25)
	col_box(p + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3))


func _lamps() -> void:
	_lamp(Vector3(-7, 0, -14.5), true)
	_lamp(Vector3(10, 0, -14.5), true)
	_lamp(Vector3(-9, 0, 9), true)
	_lamp(Vector3(11, 0, 9), false)
	_lamp(Vector3(3.5, 0, 26), false)
	_lamp(Vector3(28, 0, 2), false)
	_lamp(Vector3(-26, 0, -9), false)
	_lamp(Vector3(-8 + 1.9, 0, -30), false)


func _string_lights() -> void:
	var spans := [
		[Vector3(-14.5, 5.4, -8), Vector3(14.0, 5.6, -4)],
		[Vector3(-14.5, 5.4, -2), Vector3(14.0, 5.6, 4)],
		[Vector3(-14.5, 5.4, 6), Vector3(14.0, 5.6, 10)],
		[Vector3(-6, 3.8, 15), Vector3(3.0, 4.5, -14.0)],
	]
	var cols := [Color(1.0, 0.7, 0.35), Color(1.0, 0.85, 0.5), Color(1.0, 0.55, 0.3)]
	for s in spans:
		var pts := Geo.sag(s[0], s[1], 1.1, 24)
		G("plain", s[0]).tube(pts, 0.012, Color(0.05, 0.05, 0.05), 3)
		var n := int((s[0] as Vector3).distance_to(s[1]) / 1.1)
		for k in n:
			var t := (k + 0.5) / n
			var p := (s[0] as Vector3).lerp(s[1], t) + Vector3.DOWN * 1.1 * 4.0 * t * (1.0 - t)
			G("glow", p).sphere(p + Vector3(0, -0.07, 0), Vector3(0.055, 0.075, 0.055), (cols[k % 3] as Color) * 1.8, 6, 4)
	light(Vector3(0, 4.2, 1.5), Color(1.0, 0.72, 0.4), 1.2, 14.0)
	light(Vector3(-3, 3.5, 5), Color(1.0, 0.72, 0.4), 0.8, 10.0)
	# poles for span ends
	for p in [Vector3(-14.5, 0, -8), Vector3(-14.5, 0, -2), Vector3(-14.5, 0, 6), Vector3(14.0, 0, -4), Vector3(14.0, 0, 4), Vector3(14.0, 0, 10), Vector3(3.0, 0, -14.0)]:
		var top := 5.7 if p.x > 0 else 5.5
		if p.z == -14.0:
			top = 4.6
		G("wood", p).cyl(p, p + Vector3(0, top, 0), 0.1, 0.08, WOOD_DARK, 8)
		col_box(p + Vector3(0, 1.0, 0), Vector3(0.25, 2.0, 0.25))


# --- props -------------------------------------------------------------------------------

func _barrel(p: Vector3, upright := true) -> void:
	var g := G("wood", p)
	var m := G("metal", p)
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) if upright else Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, rng.randf() * TAU), p + (Vector3.ZERO if upright else Vector3(0, 0.33, 0)))
	g.push(t)
	m.push(t)
	var prof := PackedVector2Array()
	for k in 7:
		var y := 0.9 * k / 6.0 - (0.0 if upright else 0.45)
		prof.append(Vector2(0.3 + 0.06 * sin(PI * k / 6.0), y))
	g.lathe(Vector3.ZERO, prof, 16, WOOD.lightened(rng.randf() * 0.1), 1.0, 1.0, true, true)
	for y in [0.08, 0.3, 0.6, 0.82]:
		var yy: float = y - (0.0 if upright else 0.45)
		var r := 0.3 + 0.06 * sin(PI * y / 0.9) + 0.008
		m.lathe(Vector3.ZERO, PackedVector2Array([Vector2(r, yy - 0.025), Vector2(r, yy + 0.025)]), 16, Color(0.2, 0.18, 0.16))
	g.pop()
	m.pop()
	if upright:
		col_box(p + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7))


func _crate(p: Vector3, s := 0.8, yaw := 0.0) -> void:
	var g := G("wood", p)
	g.push(xf(p + Vector3(0, s * 0.5, 0), yaw))
	var c := WOOD.lightened(0.15).darkened(rng.randf() * 0.2)
	g.box(Vector3.ZERO, Vector3(s, s, s) * 0.96, c.darkened(0.15), 0.01)
	for ax in 3:
		for sg in [-1.0, 1.0]:
			for e in [-1.0, 1.0]:
				var pos := Vector3.ZERO
				pos[ax] = sg * s * 0.49
				var size := Vector3(s, s, s) * 0.12
				size[ax] = 0.04
				var o := (ax + 1) % 3
				pos[o] = e * s * 0.44
				size[(ax + 2) % 3] = s
				g.box(pos, size, c, 0.01)
	g.pop()
	col_box(p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), yaw)


func _rope_coil(p: Vector3) -> void:
	var pts := PackedVector3Array()
	for k in 60:
		var a := k * 0.55
		var r := 0.32 - (k / 60.0) * 0.14
		pts.append(p + Vector3(cos(a) * r, 0.04 + (k % 12) * 0.0 + (k / 12) * 0.035, sin(a) * r))
	G("plain", p).tube(pts, 0.035, Color(0.62, 0.5, 0.32), 5)


func _net_rack(p: Vector3, yaw: float) -> void:
	var g := G("wood", p)
	var n := G("plain", p)
	g.push(xf(p, yaw))
	n.push(xf(p, yaw))
	for sx in [-1.5, 1.5]:
		g.cyl(Vector3(sx, 0, 0), Vector3(sx, 2.1, 0), 0.06, 0.05, WOOD_DARK, 6)
	g.cyl(Vector3(-1.6, 2.0, 0), Vector3(1.6, 2.0, 0), 0.05, 0.05, WOOD_DARK, 6)
	var nc := Color(0.3, 0.33, 0.28)
	for k in 13:
		var x := -1.4 + k * 0.233
		var pts := PackedVector3Array()
		for j in 9:
			var y := 1.95 - j * 0.2
			pts.append(Vector3(x + sin(j * 0.7 + k) * 0.04, y, 0.03 + 0.08 * sin(j * 0.5) * sin(k * 0.4 + 1.0)))
		n.tube(pts, 0.008, nc, 3)
	for j in 9:
		var y := 1.95 - j * 0.2
		n.tube(Geo.sag(Vector3(-1.45, y, 0.03), Vector3(1.45, y, 0.03), 0.06, 12), 0.008, nc, 3)
	for k in 4:
		n.sphere(Vector3(-1.2 + k * 0.8, 1.05, 0.08), Vector3(0.08, 0.08, 0.08), Color(0.85, 0.65, 0.2), 6, 4)
	g.pop()
	n.pop()
	col_box(p + Vector3(0, 1.0, 0), Vector3(3.2, 2.0, 0.3), yaw)


func _bench(p: Vector3, yaw: float) -> void:
	var g := G("wood", p)
	g.push(xf(p, yaw))
	for k in 3:
		g.box(Vector3(0, 0.45, -0.15 + k * 0.15), Vector3(1.8, 0.05, 0.13), WOOD.lightened(0.05), 0.015)
	for k in 2:
		g.box(Vector3(0, 0.62 + k * 0.17, 0.24), Vector3(1.8, 0.12, 0.04), WOOD.lightened(0.05), 0.015)
	var m := G("metal", p)
	m.push(xf(p, yaw))
	for sx in [-0.75, 0.75]:
		m.box(Vector3(sx, 0.22, 0), Vector3(0.06, 0.44, 0.45), Color(0.1, 0.1, 0.1), 0.01)
		m.box(Vector3(sx, 0.68, 0.24), Vector3(0.05, 0.5, 0.05), Color(0.1, 0.1, 0.1), 0.01)
	m.pop()
	g.pop()
	col_box(p + Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.6), yaw)


func _props() -> void:
	# Quay clutter
	for p in [Vector3(-14, 0, -14.6), Vector3(-13.2, 0, -14.4), Vector3(-13.6, 0.9, -14.5), Vector3(6, 0, -14.8), Vector3(20.5, 0, -14.6), Vector3(26.5, 0, -12)]:
		_crate(p, rng.randf_range(0.7, 0.9), rng.randf_range(-0.3, 0.3))
	for p in [Vector3(-12, 0, -15), Vector3(-11.3, 0, -14.4), Vector3(4.5, 0, -15), Vector3(21.8, 0, -14.8), Vector3(-16, 0, -2.5), Vector3(-15.3, 0, -1.6), Vector3(14.6, 0, -12.5), Vector3(27, 0, -10.5)]:
		_barrel(p)
	_barrel(Vector3(5.2, 0, -14.4), false)
	for p in [Vector3(-9.8, 0.03, -15.0), Vector3(1.0, 0.03, -15.2), Vector3(-7.5, 0.03, -38.5), Vector3(13.2, 0.03, -33.0)]:
		_rope_coil(p)
	_net_rack(Vector3(-20, 0, -14), 0.0)
	_net_rack(Vector3(25, 0, -14.6), 0.0)
	# Lobster pots on the long dock
	for k in 3:
		var p := Vector3(-7.0, 0.03, -21 - k * 0.8)
		var g := G("wood", p)
		g.lathe(p, PackedVector2Array([Vector2(0.28, 0), Vector2(0.3, 0.2), Vector2(0.2, 0.4), Vector2(0.0, 0.42)]), 8, Color(0.42, 0.3, 0.18), 1.0, 0.7)
	# Benches and flower planters around the plaza
	_bench(Vector3(-6, 0, -13.2), PI)
	_bench(Vector3(7, 0, -13.2), PI)
	for p in [Vector3(-12, 0, 13), Vector3(13, 0, 13), Vector3(-12, 0, -11), Vector3(14, 0, 1)]:
		var g := G("stone", p)
		g.lathe(p, PackedVector2Array([Vector2(0.5, 0), Vector2(0.62, 0.55), Vector2(0.66, 0.6), Vector2(0.55, 0.6), Vector2(0.0, 0.5)]), 14, STONE.lightened(0.05))
		var f := G("foliage", p)
		for k in 7:
			var a := TAU * k / 7.0
			f.sphere(p + Vector3(cos(a) * 0.3, 0.75, sin(a) * 0.3), Vector3(0.28, 0.25, 0.28), Color(0.14, 0.26, 0.11), 8, 5)
		f.sphere(p + Vector3(0, 0.95, 0), Vector3(0.3, 0.3, 0.3), Color(0.16, 0.3, 0.12), 8, 5)
		var fl := G("plain", p)
		for k in 9:
			var a := rng.randf() * TAU
			fl.sphere(p + Vector3(cos(a) * 0.4, 0.95 + rng.randf() * 0.15, sin(a) * 0.4), Vector3(0.06, 0.05, 0.06), [Color(0.95, 0.35, 0.4), Color(1.0, 0.85, 0.35), Color(0.75, 0.5, 1.0)][k % 3], 6, 4)
		col_box(p + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.2))
	# Fences up the hill
	for k in 14:
		var x := -30.0 + k * 2.2
		if absf(x) < 5.0:
			continue
		var z := 44.0
		var y := height(x, z)
		var g := G("wood", Vector3(x, y, z))
		g.cyl(Vector3(x, y - 0.2, z), Vector3(x, y + 1.1, z), 0.06, 0.05, WOOD_DARK, 6)
		g.box(Vector3(x + 1.1, y + 0.85, z), Vector3(2.2, 0.08, 0.05), WOOD, 0.01)
		g.box(Vector3(x + 1.1, y + 0.45, z), Vector3(2.2, 0.08, 0.05), WOOD, 0.01)
	# Beach bonfire with logs
	var bf := Vector3(-42, height(-42, -20), -20)
	var gl := G("wood", bf)
	for k in 6:
		var a := TAU * k / 6.0
		gl.cyl(bf + Vector3(cos(a) * 0.6, 0.0, sin(a) * 0.6), bf + Vector3(cos(a) * 0.1, 0.55, sin(a) * 0.1), 0.07, 0.05, Color(0.2, 0.12, 0.07), 6)
	var rs := G("rock", bf)
	for k in 10:
		var a := TAU * k / 10.0
		rs.sphere(bf + Vector3(cos(a) * 0.9, 0.05, sin(a) * 0.9), Vector3(0.2, 0.14, 0.18), Color(0.3, 0.3, 0.3), 6, 4)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		gl.cyl(bf + Vector3(cos(a) * 2.2, 0.2, sin(a) * 2.2) + Vector3(sin(a), 0, -cos(a)) * 0.8, bf + Vector3(cos(a) * 2.2, 0.2, sin(a) * 2.2) - Vector3(sin(a), 0, -cos(a)) * 0.8, 0.2, 0.2, WOOD.darkened(0.2), 10)
	_fire(bf + Vector3(0, 0.15, 0), 1.0)
	light(bf + Vector3(0, 1.2, 0), Color(1.0, 0.5, 0.2), 4.0, 12.0, true, 1.0)
	col_box(bf + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 2.0))


# --- trees -----------------------------------------------------------------------------

func _tree(p: Vector3, s: float, pine: bool) -> void:
	p.y = height(p.x, p.z) - 0.1
	var g := G("wood", p)
	var f := G("foliage", p)
	var trunk_h := (3.0 if not pine else 2.0) * s
	g.cyl(p, p + Vector3(0.2 * s, trunk_h, 0.1 * s), 0.28 * s, 0.14 * s, Color(0.25, 0.17, 0.12), 8)
	for k in 3:
		var a := rng.randf() * TAU
		g.cyl(p + Vector3(0, 0.0, 0), p + Vector3(cos(a) * 0.6 * s, -0.05, sin(a) * 0.6 * s), 0.18 * s, 0.05 * s, Color(0.25, 0.17, 0.12), 5)
	if pine:
		for k in 5:
			var y := trunk_h * 0.6 + k * 1.2 * s
			var r := (2.4 - k * 0.42) * s
			f.lathe(p + Vector3(0.2 * s, y, 0.1 * s), PackedVector2Array([Vector2(r * 0.3, 0.0), Vector2(r, 0.15 * s), Vector2(r * 0.9, 0.35 * s), Vector2(0.0, 1.9 * s)]), 12, Color(0.08, 0.17, 0.12).lightened(k * 0.03))
	else:
		var top := p + Vector3(0.2 * s, trunk_h, 0.1 * s)
		var base_c: Color = [Color(0.12, 0.22, 0.09), Color(0.16, 0.24, 0.1), Color(0.1, 0.2, 0.12)][rng.randi() % 3]
		for k in 9:
			var a := TAU * k / 9.0 + rng.randf()
			var r := rng.randf_range(0.8, 1.5) * s
			var o := Vector3(cos(a) * 1.3 * s, rng.randf_range(-0.2, 1.4) * s, sin(a) * 1.3 * s)
			if k > 0:
				g.cyl(top - Vector3(0, 0.5 * s, 0), top + o * 0.8, 0.12 * s, 0.05 * s, Color(0.25, 0.17, 0.12), 5)
			f.sphere(top + o, Vector3(r, r * 0.8, r), base_c.lightened(o.y * 0.05), 10, 7)
		f.sphere(top + Vector3(0, 1.6 * s, 0), Vector3(1.4, 1.1, 1.4) * s, base_c.lightened(0.08), 10, 7)
	col_box(p + Vector3(0, 1.5, 0), Vector3(0.6 * s, 3.0, 0.6 * s))


func _trees() -> void:
	var spots := [
		[Vector3(-26, 0, 16), 1.0, false], [Vector3(26, 0, 16), 1.1, false], [Vector3(-16, 0, 24), 0.9, false],
		[Vector3(18, 0, 26), 1.0, false], [Vector3(-27, 0, -12), 0.9, false], [Vector3(28, 0, -14), 0.8, false],
		[Vector3(-20, 0, 46), 1.2, true], [Vector3(-8, 0, 50), 1.3, true], [Vector3(12, 0, 48), 1.1, true],
		[Vector3(24, 0, 50), 1.4, true], [Vector3(34, 0, 40), 1.2, true], [Vector3(-34, 0, 38), 1.3, true],
		[Vector3(46, 0, 20), 1.2, true], [Vector3(50, 0, -2), 1.3, true], [Vector3(-48, 0, 14), 1.2, true],
		[Vector3(-50, 0, -4), 1.0, false], [Vector3(-26, 0, 30), 1.0, false], [Vector3(26, 0, 34), 1.0, false],
		[Vector3(40, 0, -28), 0.8, true], [Vector3(30, 0, -26), 0.7, false], [Vector3(-40, 0, 52), 1.5, true],
		[Vector3(0, 0, 56), 1.4, true], [Vector3(54, 0, 38), 1.5, true], [Vector3(-56, 0, 30), 1.4, true],
	]
	for s in spots:
		_tree(s[0], s[1], s[2])
	# bushes + grass tufts via MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bush := Geo.new()
	bush.sphere(Vector3(0, 0.25, 0), Vector3(0.6, 0.45, 0.6), Color(0.13, 0.23, 0.1), 9, 6)
	bush.sphere(Vector3(0.35, 0.2, 0.2), Vector3(0.4, 0.35, 0.4), Color(0.15, 0.26, 0.1), 8, 5)
	bush.sphere(Vector3(-0.3, 0.18, -0.15), Vector3(0.38, 0.3, 0.38), Color(0.11, 0.21, 0.09), 8, 5)
	mm.mesh = bush.to_mesh(Mats.get_mat("foliage"))
	var xs: Array[Transform3D] = []
	while xs.size() < 90:
		var p := Vector3(rng.randf_range(-58, 58), 0, rng.randf_range(-12, 58))
		if p.x > -28 and p.x < 32 and p.z < 15:
			continue
		if absf(p.x) < 6.0 and p.z > 14.0:
			continue
		if p.x > 30 and absf(p.z) < 5:
			continue
		if p.x < -26 and p.z < -4:
			continue
		var near := false
		for b in [Vector3(-9, 0, 18.5), Vector3(19, 0, 8), Vector3(-20, 0, 10), Vector3(9, 0, 20), Vector3(10, 0, 33), Vector3(-11, 0, 32), Vector3(38, 0, -10), Vector3(38, 0, 11), Vector3(-36, 0, 2)]:
			if Vector2(p.x - b.x, p.z - b.z).length() < 7.0:
				near = true
		if near:
			continue
		p.y = height(p.x, p.z) - 0.05
		var s := rng.randf_range(0.6, 1.4)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), p))
	mm.instance_count = xs.size()
	for k in xs.size():
		mm.set_instance_transform(k, xs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


# --- particles --------------------------------------------------------------------------

func _smoke(p: Vector3) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = 14
	ps.lifetime = 7.0
	ps.preprocess = 7.0
	ps.position = p
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.25, 0.1, 0.05)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 2.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.set_color(0, Color(0.5, 0.52, 0.6, 0.0))
	gr.set_color(1, Color(0.5, 0.52, 0.6, 0.0))
	gr.add_point(0.15, Color(0.45, 0.47, 0.55, 0.1))
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _radial()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	ps.draw_pass_1 = q
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ps)


func _fire(p: Vector3, s: float) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = 40
	ps.lifetime = 0.9
	ps.position = p
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 * s
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.6 * s
	pm.initial_velocity_max = 1.4 * s
	pm.gravity = Vector3(0, 1.0, 0)
	pm.scale_min = 0.5 * s
	pm.scale_max = 0.9 * s
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
	q.size = Vector2(0.6, 0.8)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _radial()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	ps.draw_pass_1 = q
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ps)


func _particles() -> void:
	for area in [AABB(Vector3(-40, 0.3, 14), Vector3(80, 2.5, 40)), AABB(Vector3(-56, 0.3, -24), Vector3(26, 2.0, 30))]:
		var ps := GPUParticles3D.new()
		ps.amount = 70
		ps.lifetime = 8.0
		ps.preprocess = 8.0
		ps.position = area.get_center()
		ps.visibility_aabb = AABB(-area.size * 0.6, area.size * 1.2)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = area.size * 0.5
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.25
		pm.spread = 180.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
		var gr := Gradient.new()
		gr.set_color(0, Color(1.5, 2.0, 0.6, 0.0))
		gr.set_color(1, Color(1.5, 2.0, 0.6, 0.0))
		gr.add_point(0.3, Color(2.5, 3.0, 0.8, 1.0))
		gr.add_point(0.5, Color(0.6, 0.8, 0.2, 0.2))
		gr.add_point(0.7, Color(2.5, 3.0, 0.8, 1.0))
		var grt := GradientTexture1D.new()
		grt.gradient = gr
		pm.color_ramp = grt
		ps.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.12, 0.12)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _radial()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material = m
		ps.draw_pass_1 = q
		ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ps)


# --- villagers -----------------------------------------------------------------------------

func _people() -> void:
	var looks := [
		{"coat": Color(0.55, 0.3, 0.15), "accent": Color(0.9, 0.85, 0.7), "hat": "bandana", "body": "stout", "beard": true},
		{"coat": Color(0.2, 0.35, 0.25), "accent": Color(0.95, 0.5, 0.6), "hat": "flower", "body": "slim", "hair": Color(0.7, 0.4, 0.15), "skin": Color(0.75, 0.55, 0.42)},
		{"coat": Color(0.3, 0.3, 0.38), "accent": Color(0.7, 0.7, 0.75), "hat": "hood", "body": "normal"},
		{"coat": Color(0.6, 0.55, 0.4), "accent": Color(0.3, 0.45, 0.7), "hat": "none", "hair": Color(0.1, 0.08, 0.06), "skin": Color(0.55, 0.38, 0.28)},
		{"coat": Color(0.15, 0.2, 0.4), "accent": Color(1.0, 0.82, 0.4), "hat": "tricorn", "beard": true, "hair": Color(0.4, 0.3, 0.2)},
		{"coat": Color(0.5, 0.15, 0.25), "accent": Color(0.95, 0.9, 0.6), "hat": "crown", "body": "normal", "hair": Color(0.9, 0.8, 0.5)},
	]
	var paths := [
		[Vector3(-8, 0, -8), Vector3(8, 0, -9), Vector3(9, 0, 5), Vector3(-7, 0, 6)],
		[Vector3(-8, 0, -18), Vector3(-8, 0, -40), Vector3(-8, 0, -18), Vector3(-2, 0, -12)],
		[Vector3(0, 0, 14), Vector3(0, 0, 38), Vector3(2, 0, 38), Vector3(2, 0, 14)],
		[Vector3(22, 0, -12), Vector3(26, 0, 0), Vector3(45, 0, 0), Vector3(26, 0, 1)],
		[Vector3(-24, 0, -8), Vector3(-45, 0, -8), Vector3(-40, 0, -16), Vector3(-24, 0, -12)],
		[Vector3(6, 0, 10), Vector3(-5, 0, 11), Vector3(-6, 0, -12), Vector3(8, 0, -12)],
	]
	for k in looks.size():
		var npc := Node3D.new()
		npc.set_script(Npc)
		npc.name = "Villager%d" % k
		add_child(npc)
		var pts := PackedVector3Array()
		for p: Vector3 in paths[k]:
			pts.append(Vector3(p.x, maxf(0.0, height(p.x, p.z)) if p.z > -16.0 else 0.03, p.z))
		npc.setup(looks[k], pts, rng.randf_range(1.1, 1.5))
	# a fisher sitting on the dock edge
	var f := CharModel.new()
	add_child(f)
	f.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(13.0, 0.1, -30))
	f.configure({"coat": Color(0.75, 0.6, 0.2), "accent": Color(0.3, 0.3, 0.3), "hat": "bandana", "beard": true, "body": "stout"})
	f.play("sit")


func _bounds() -> void:
	var walls := [
		[Vector3(-60, 3, 0), Vector3(1, 12, 140)], [Vector3(60, 3, 0), Vector3(1, 12, 140)],
		[Vector3(0, 3, 60), Vector3(140, 12, 1)],
		[Vector3(-1.5, 2, -16.9), Vector3(10.0, 6, 0.6)],
		[Vector3(-16.75, 2, -16.9), Vector3(14.5, 6, 0.6)],
		[Vector3(24.65, 2, -16.9), Vector3(19.7, 6, 0.6)],
		[Vector3(41, 2, -16.9), Vector3(38, 6, 0.6)],
		[Vector3(-24.3, 2, -21), Vector3(0.6, 6, 9)],
		[Vector3(-42, 2, -26.5), Vector3(36, 6, 0.6)],
		[Vector3(-12.9, 2, -10), Vector3(0.4, 6, 3)],
	]
	for w in walls:
		col_box(w[0], w[1])
