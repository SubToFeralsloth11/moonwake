extends RefCounted
## Shared world materials (cached).

const SURFACE := preload("res://shaders/world/surface.gdshader")
const PATTERNS := {"plain": 0, "wood": 1, "stone": 2, "cobble": 3, "roof": 4, "plaster": 5, "terrain": 6, "metal": 7, "rock": 8, "cloth": 9, "foliage": 0}

static var _cache := {}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material
	match name:
		"glow":
			var s := StandardMaterial3D.new()
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.vertex_color_use_as_albedo = true
			s.albedo_color = Color(4.0, 2.6, 1.2)
			m = s
		"window":
			var s := ShaderMaterial.new()
			s.shader = preload("res://shaders/world/window.gdshader")
			m = s
		"glass":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.albedo_color = Color(1, 1, 1, 0.55)
			s.roughness = 0.08
			s.metallic_specular = 0.9
			m = s
		"char":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.72
			s.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			s.rim_enabled = true
			s.rim = 0.25
			s.rim_tint = 0.6
			m = s
		_:
			var sm := ShaderMaterial.new()
			sm.shader = SURFACE
			sm.set_shader_parameter("pattern", PATTERNS.get(name, 0))
			match name:
				"metal":
					sm.set_shader_parameter("metallic_base", 0.75)
					sm.set_shader_parameter("roughness_base", 0.38)
				"cobble", "rock":
					sm.set_shader_parameter("bump_strength", 2.5)
				"stone":
					sm.set_shader_parameter("bump_strength", 2.0)
				"wood":
					sm.set_shader_parameter("roughness_base", 0.72)
				"roof":
					sm.set_shader_parameter("bump_strength", 1.6)
				"foliage":
					sm.set_shader_parameter("roughness_base", 0.9)
					sm.set_shader_parameter("bump_strength", 3.0)
			m = sm
	_cache[name] = m
	return m
