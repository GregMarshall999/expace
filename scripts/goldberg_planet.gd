@tool
class_name GoldbergPlanet
extends Node3D

## Geodesic subdivision frequency of the underlying icosahedron.
## Tile count = 10 * subdivisions^2 + 2 (12 of those are pentagons, the
## rest hexagons) -- this is the "planet size" control, in tiles, not scale.
@export_range(1, 24, 1) var subdivisions: int = 6:
	set(value):
		subdivisions = maxi(1, value)
		_generate()

@onready var mesh_instance: MeshInstance3D = $Mesh

func _ready() -> void:
	_generate()

func _notification(what: int) -> void:
	# The mesh is fully derived from `subdivisions`, so there's no reason to
	# let the editor bake its (potentially large) vertex/index data into the
	# .tscn file. Strip it right before a save and rebuild right after, so
	# the saved scene stays tiny but the editor preview never goes blank.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		mesh_instance.mesh = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_generate()

func _generate() -> void:
	if not is_node_ready():
		return
	var geodesic := _build_geodesic_sphere(subdivisions)
	var tiles := _build_dual_tiles(geodesic.vertices, geodesic.triangles)
	mesh_instance.mesh = _build_mesh(tiles)

# ---------------------------------------------------------------------------
# Step 1: icosahedron base, geodesically subdivided into a triangle mesh.
# ---------------------------------------------------------------------------

func _icosahedron() -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var vertices := PackedVector3Array()
	for v in raw:
		vertices.append(v.normalized())
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	return {"vertices": vertices, "faces": faces}

func _get_or_add_vertex(point: Vector3, vertices: PackedVector3Array, lookup: Dictionary) -> int:
	var key := "%.6f,%.6f,%.6f" % [point.x, point.y, point.z]
	if lookup.has(key):
		return lookup[key]
	var index := vertices.size()
	vertices.append(point)
	lookup[key] = index
	return index

func _build_geodesic_sphere(n: int) -> Dictionary:
	var base := _icosahedron()
	var base_vertices: PackedVector3Array = base.vertices
	var base_faces: Array = base.faces

	var vertices := PackedVector3Array()
	var vertex_lookup := {}
	var triangles := []

	for face in base_faces:
		var v0: Vector3 = base_vertices[face[0]]
		var v1: Vector3 = base_vertices[face[1]]
		var v2: Vector3 = base_vertices[face[2]]

		# Triangular grid over the face via barycentric coords (a,b,c), a+b+c=n.
		var grid := []
		grid.resize(n + 1)
		for i in range(n + 1):
			var row := PackedInt32Array()
			row.resize(n - i + 1)
			for j in range(n - i + 1):
				var a := float(n - i - j)
				var b := float(j)
				var c := float(i)
				var point := (v0 * a + v1 * b + v2 * c) / float(n)
				row[j] = _get_or_add_vertex(point, vertices, vertex_lookup)
			grid[i] = row

		for i in range(n):
			for j in range(n - i):
				var p00: int = grid[i][j]
				var p10: int = grid[i + 1][j]
				var p01: int = grid[i][j + 1]
				triangles.append(PackedInt32Array([p00, p10, p01]))
				if j < n - i - 1:
					var p11: int = grid[i + 1][j + 1]
					triangles.append(PackedInt32Array([p10, p11, p01]))

	for i in range(vertices.size()):
		vertices[i] = vertices[i].normalized()

	return {"vertices": vertices, "triangles": triangles}

# ---------------------------------------------------------------------------
# Step 2: dual of the geodesic sphere -- one tile per original vertex, made
# from the centroids of the triangular faces around it. Original icosahedron
# vertices keep 5 neighbors (pentagons); every subdivision vertex gets 6
# (hexagons).
# ---------------------------------------------------------------------------

func _build_dual_tiles(vertices: PackedVector3Array, triangles: Array) -> Array:
	var vertex_faces := {}
	for f in range(triangles.size()):
		var tri: PackedInt32Array = triangles[f]
		for k in range(3):
			var vi: int = tri[k]
			if not vertex_faces.has(vi):
				vertex_faces[vi] = []
			vertex_faces[vi].append(f)

	var centroids := PackedVector3Array()
	centroids.resize(triangles.size())
	for f in range(triangles.size()):
		var tri: PackedInt32Array = triangles[f]
		centroids[f] = (vertices[tri[0]] + vertices[tri[1]] + vertices[tri[2]]) / 3.0

	var tiles := []
	for vi in vertex_faces.keys():
		var face_list: Array = vertex_faces[vi]
		var vpos: Vector3 = vertices[vi]
		var normal := vpos.normalized()
		var tangent := normal.cross(Vector3.UP)
		if tangent.length_squared() < 0.0001:
			tangent = normal.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		var bitangent := normal.cross(tangent)

		var entries := []
		for f in face_list:
			var c: Vector3 = centroids[f]
			var d: Vector3 = c - vpos
			entries.append({"angle": atan2(d.dot(bitangent), d.dot(tangent)), "point": c})
		entries.sort_custom(func(a, b): return a["angle"] < b["angle"])

		var corners := PackedVector3Array()
		for e in entries:
			corners.append(e["point"])

		tiles.append({"outward": vpos, "corners": corners})

	return tiles

# ---------------------------------------------------------------------------
# Step 3: fan-triangulate each flat tile (5 or 6 corners) for rendering,
# with a flat per-tile normal so the tiling reads clearly under lighting.
# ---------------------------------------------------------------------------

func _build_mesh(tiles: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tile in tiles:
		var corners: PackedVector3Array = tile["corners"]
		var count := corners.size()
		if count < 3:
			continue
		var center := Vector3.ZERO
		for c in corners:
			center += c
		center /= float(count)
		var outward: Vector3 = tile["outward"]

		for k in range(count):
			var a := corners[k]
			var b := corners[(k + 1) % count]
			var n := (a - center).cross(b - center)
			if n.dot(outward) > 0.0:
				var tmp := a
				a = b
				b = tmp
				n = -n
			n = n.normalized()
			st.set_normal(n)
			st.add_vertex(center)
			st.set_normal(n)
			st.add_vertex(a)
			st.set_normal(n)
			st.add_vertex(b)

	st.index()
	return st.commit()
