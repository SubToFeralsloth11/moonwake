extends RefCounted
## Procedural mesh accumulator used by every world builder.
## Primitives are smooth-shaded, carry vertex colour, and get UVs in metres.
## COLOR.a holds a per-prop random seed (`seed_a`) that the world shaders use for variation.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var idx := PackedInt32Array()

var xf := Transform3D.IDENTITY
var _nb := Basis.IDENTITY
var _stack: Array[Transform3D] = []
## Per-prop variation seed written to COLOR.a.
var seed_a := 0.5
## Box faces: when true, U runs along the longer side of each face (wood grain);
## otherwise U is horizontal and V vertical (bricks, plaster).
var long_u := false


func set_xf(t: Transform3D) -> void:
	xf = t
	_nb = t.basis.inverse().transposed()


func push(t: Transform3D) -> void:
	_stack.append(xf)
	set_xf(xf * t)


func pop() -> void:
	set_xf(_stack.pop_back())


func reseed(rng: RandomNumberGenerator) -> void:
	seed_a = rng.randf()


func is_empty() -> bool:
	return verts.is_empty()


func vert(p: Vector3, nrm: Vector3, col: Color, t: Vector2) -> int:
	verts.append(xf * p)
	norms.append((_nb * nrm).normalized())
	col.a = seed_a
	cols.append(col)
	uvs.append(t)
	return verts.size() - 1


## Triangle whose winding is chosen from the vertex normals (front = side the normals point to).
func tri(a: int, b: int, c: int) -> void:
	var face := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.dot(norms[a] + norms[b] + norms[c]) > 0.0:
		idx.append(a)
		idx.append(c)
		idx.append(b)
	else:
		idx.append(a)
		idx.append(b)
		idx.append(c)


func quad(a: int, b: int, c: int, d: int) -> void:
	tri(a, b, c)
	tri(a, c, d)


## Flat quad from four corners (in order around the edge).
func quad_p(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3, col: Color, uv_scale := Vector2.ONE, uv01 := false) -> void:
	var u := (p1 - p0).length() * uv_scale.x
	var v := (p3 - p0).length() * uv_scale.y
	if uv01:
		u = 1.0
		v = 1.0
	quad(vert(p0, nrm, col, Vector2(0, 0)), vert(p1, nrm, col, Vector2(u, 0)), vert(p2, nrm, col, Vector2(u, v)), vert(p3, nrm, col, Vector2(0, v)))


func _face_uv(p: Vector3, axis: int, s: Vector3) -> Vector2:
	var uv: Vector2
	var swap := false
	match axis:
		0:
			uv = Vector2(p.z, -p.y)
			swap = s.y > s.z
		1:
			uv = Vector2(p.x, p.z)
			swap = s.z > s.x
		_:
			uv = Vector2(p.x, -p.y)
			swap = s.y > s.x
	if long_u and swap:
		return Vector2(uv.y, uv.x)
	return uv


## Box centred at `c`, optionally with chamfered (smooth-shaded) edges.
func box(c: Vector3, s: Vector3, col: Color, bevel := 0.0) -> void:
	var h := s * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var i := h - Vector3(b, b, b)
	for axis in 3:
		var ua := (axis + 1) % 3
		var va := (axis + 2) % 3
		for sg in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sg
			var ids: Array[int] = []
			for k in 4:
				var p := Vector3.ZERO
				p[axis] = sg * h[axis]
				p[ua] = (-1.0 if (k == 0 or k == 3) else 1.0) * i[ua]
				p[va] = (-1.0 if k < 2 else 1.0) * i[va]
				ids.append(vert(c + p, nrm, col, _face_uv(c + p, axis, s)))
			quad(ids[0], ids[1], ids[2], ids[3])
	if b <= 0.0:
		return
	# Edge strips between neighbouring faces.
	for a1 in 3:
		for a2 in range(a1 + 1, 3):
			var a3 := 3 - a1 - a2
			for s1 in [-1.0, 1.0]:
				for s2 in [-1.0, 1.0]:
					var n1 := Vector3.ZERO
					n1[a1] = s1
					var n2 := Vector3.ZERO
					n2[a2] = s2
					var ids: Array[int] = []
					for e in [[n1, true, -1.0], [n1, true, 1.0], [n2, false, 1.0], [n2, false, -1.0]]:
						var p := Vector3.ZERO
						p[a1] = s1 * (h[a1] if e[1] else i[a1])
						p[a2] = s2 * (i[a2] if e[1] else h[a2])
						p[a3] = e[2] * i[a3]
						ids.append(vert(c + p, e[0], col, _face_uv(c + p, a1 if e[1] else a2, s)))
					quad(ids[0], ids[1], ids[2], ids[3])
	# Corner triangles.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var sv := Vector3(sx, sy, sz)
				var ids: Array[int] = []
				for axis in 3:
					var p := sv * i
					p[axis] = sv[axis] * h[axis]
					var nrm := Vector3.ZERO
					nrm[axis] = sv[axis]
					ids.append(vert(c + p, nrm, col, _face_uv(c + p, axis, s)))
				tri(ids[0], ids[1], ids[2])


## Surface of revolution around local +Y. `prof` holds (radius, y) points from bottom to top.
## Repeat a point to get a hard crease. `sx`/`sz` squash the cross-section.
func lathe(c: Vector3, prof: PackedVector2Array, segs: int, col: Color, sx := 1.0, sz := 1.0, cap_bottom := false, cap_top := false, arc := TAU, arc0 := 0.0, invert := false, ring_cols := PackedColorArray()) -> void:
	var n := prof.size()
	if n < 2:
		return
	var rmax := 0.0
	for p in prof:
		rmax = maxf(rmax, p.x)
	var full := is_equal_approx(arc, TAU)
	var rings: Array = []
	var sgn := -1.0 if invert else 1.0
	for k in n:
		var t: Vector2
		var prev_same := k > 0 and prof[k - 1].is_equal_approx(prof[k])
		var next_same := k < n - 1 and prof[k + 1].is_equal_approx(prof[k])
		if k == 0 or prev_same:
			t = prof[mini(k + 1 + (1 if next_same else 0), n - 1)] - prof[k]
		elif k == n - 1 or next_same:
			t = prof[k] - prof[k - 1]
		else:
			t = prof[k + 1] - prof[k - 1]
		var nn := Vector2(t.y, -t.x).normalized() * sgn
		var rc := ring_cols[k] if k < ring_cols.size() else col
		var ring: Array[int] = []
		for j in segs + 1:
			var ang := arc0 + arc * float(j) / float(segs)
			var ca := cos(ang)
			var sa := sin(ang)
			var p := c + Vector3(prof[k].x * ca * sx, prof[k].y, prof[k].x * sa * sz)
			var nrm := Vector3(nn.x * ca / sx, nn.y, nn.x * sa / sz)
			if nrm.length_squared() < 1e-8:
				nrm = Vector3(0, signf(nn.y) if nn.y != 0.0 else 1.0, 0)
			ring.append(vert(p, nrm, rc, Vector2((ang - arc0) * rmax, prof[k].y)))
		rings.append(ring)
	for k in n - 1:
		if prof[k].is_equal_approx(prof[k + 1]):
			continue
		if prof[k].x < 1e-5 and prof[k + 1].x < 1e-5:
			continue
		var r0: Array[int] = rings[k]
		var r1: Array[int] = rings[k + 1]
		for j in segs:
			if prof[k].x < 1e-5:
				tri(r0[j], r1[j], r1[j + 1])
			elif prof[k + 1].x < 1e-5:
				tri(r0[j], r1[j], r0[j + 1])
			else:
				quad(r0[j], r0[j + 1], r1[j + 1], r1[j])
	if full:
		if cap_bottom and prof[0].x > 1e-5:
			_cap(c, prof[0], segs, col, -1.0 * sgn, sx, sz)
		if cap_top and prof[n - 1].x > 1e-5:
			_cap(c, prof[n - 1], segs, col, 1.0 * sgn, sx, sz)


func _cap(c: Vector3, p: Vector2, segs: int, col: Color, ny: float, sx: float, sz: float) -> void:
	var nrm := Vector3(0, ny, 0)
	var center := vert(c + Vector3(0, p.y, 0), nrm, col, Vector2.ZERO)
	var first := -1
	var prev := -1
	for j in segs:
		var ang := TAU * float(j) / float(segs)
		var q := Vector3(p.x * cos(ang) * sx, p.y, p.x * sin(ang) * sz)
		var cur := vert(c + q, nrm, col, Vector2(q.x, q.z))
		if prev >= 0:
			tri(center, prev, cur)
		else:
			first = cur
		prev = cur
	tri(center, prev, first)


## Ellipsoid with radii `r`.
func sphere(c: Vector3, r: Vector3, col: Color, segs := 12, rings := 8, y_from := -1.0, y_to := 1.0) -> void:
	var prof := PackedVector2Array()
	var a0 := asin(clampf(y_from, -1.0, 1.0))
	var a1 := asin(clampf(y_to, -1.0, 1.0))
	for k in rings + 1:
		var a := lerpf(a0, a1, float(k) / float(rings))
		prof.append(Vector2(cos(a), sin(a) * r.y))
	if prof[0].x < 1e-4:
		prof[0].x = 0.0
	if prof[rings].x < 1e-4:
		prof[rings].x = 0.0
	lathe(c, prof, segs, col, r.x, r.z, false, false)


## Basis whose +Y points along `dir`.
static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Tapered cylinder between two points.
func cyl(a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs := 8, caps := true) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-5:
		return
	push(Transform3D(basis_y(d), a))
	var prof := PackedVector2Array([Vector2(r0, 0), Vector2(r1, l)])
	lathe(Vector3.ZERO, prof, segs, col, 1.0, 1.0, caps, caps)
	pop()


## Tube along a polyline (ropes, wires, branches). `radii` optional per point.
func tube(pts: PackedVector3Array, r: float, col: Color, segs := 6, radii := PackedFloat32Array()) -> void:
	var n := pts.size()
	if n < 2:
		return
	var prev_ring: Array[int] = []
	var nrm_ref := Vector3.ZERO
	var dist := 0.0
	for k in n:
		var t: Vector3
		if k == 0:
			t = pts[1] - pts[0]
		elif k == n - 1:
			t = pts[k] - pts[k - 1]
		else:
			t = pts[k + 1] - pts[k - 1]
		t = t.normalized()
		if k == 0:
			var ref := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			nrm_ref = ref.cross(t).normalized()
		else:
			dist += pts[k].distance_to(pts[k - 1])
			nrm_ref = (nrm_ref - t * nrm_ref.dot(t)).normalized()
		var bin := t.cross(nrm_ref)
		var rr := radii[k] if k < radii.size() else r
		var ring: Array[int] = []
		for j in segs + 1:
			var ang := TAU * float(j) / float(segs)
			var dirv := nrm_ref * cos(ang) + bin * sin(ang)
			ring.append(vert(pts[k] + dirv * rr, dirv, col, Vector2(ang * r, dist)))
		if k > 0:
			for j in segs:
				quad(prev_ring[j], prev_ring[j + 1], ring[j + 1], ring[j])
		prev_ring = ring


## Hanging catenary-ish curve between two points.
static func sag(a: Vector3, b: Vector3, drop: float, n := 12) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n + 1:
		var t := float(k) / float(n)
		out.append(a.lerp(b, t) + Vector3.DOWN * drop * 4.0 * t * (1.0 - t))
	return out


func to_mesh(mat: Material, into: ArrayMesh = null) -> ArrayMesh:
	var am := into if into else ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


func clear() -> void:
	verts.clear()
	norms.clear()
	cols.clear()
	uvs.clear()
	idx.clear()
