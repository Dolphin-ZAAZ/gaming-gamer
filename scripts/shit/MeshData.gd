class_name MeshData
extends RefCounted

# Packed arrays for efficient mesh data storage
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var indices: PackedInt32Array = PackedInt32Array()
var colors: PackedColorArray = PackedColorArray()

# For tracking unique vertices to merge duplicates
var vertex_map: Dictionary = {}
var next_index: int = 0

func _init():
	clear()

# Clear all mesh data
func clear():
	vertices.clear()
	normals.clear()
	indices.clear()
	colors.clear()
	vertex_map.clear()
	next_index = 0

# Add a vertex with deduplication
func add_vertex(position: Vector3, normal: Vector3, color: Color = Color.WHITE) -> int:
	# Round vertex positions slightly to increase chance of merging
	var rounded_pos = Vector3(
		snapped(position.x, 0.001),
		snapped(position.y, 0.001),
		snapped(position.z, 0.001)
	)
	
	# Check if vertex already exists
	var key = str(rounded_pos)
	if key in vertex_map:
		# Average the normals for better smoothing
		var existing_idx = vertex_map[key]
		normals[existing_idx] = (normals[existing_idx] + normal).normalized()
		return existing_idx
	
	# Add new vertex
	vertices.append(position)
	normals.append(normal)
	colors.append(color)
	
	vertex_map[key] = next_index
	next_index += 1
	return next_index - 1

# Add a triangle by vertex indices
func add_triangle(a: int, b: int, c: int):
	indices.append(a)
	indices.append(b)
	indices.append(c)

# Add a triangle by positions and normals
func add_triangle_by_vertices(a_pos: Vector3, a_normal: Vector3, 
							 b_pos: Vector3, b_normal: Vector3,
							 c_pos: Vector3, c_normal: Vector3,
							 color: Color = Color.WHITE):
	var a_idx = add_vertex(a_pos, a_normal, color)
	var b_idx = add_vertex(b_pos, b_normal, color)
	var c_idx = add_vertex(c_pos, c_normal, color)
	add_triangle(a_idx, b_idx, c_idx)

# Calculate a normal from three positions
func calculate_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()

# Add all mesh data from another MeshData instance
func append_mesh(other: MeshData):
	if other.vertices.size() == 0:
		return
		
	var base_index = vertices.size()
	
	# Add vertices, normals, colors
	for i in range(other.vertices.size()):
		vertices.append(other.vertices[i])
		normals.append(other.normals[i])
		if i < other.colors.size():
			colors.append(other.colors[i])
		else:
			colors.append(Color.WHITE)
	
	# Add indices with offset
	for i in range(other.indices.size()):
		indices.append(other.indices[i] + base_index)

# Create a mesh instance from this mesh data
func create_mesh() -> Mesh:
	var mesh = ArrayMesh.new()
	
	if vertices.size() == 0:
		return mesh
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if colors.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Create a collision shape from this mesh data
func create_collision_shape() -> Shape3D:
	if vertices.size() == 0 or indices.size() == 0:
		return null
		
	var shape = ConcavePolygonShape3D.new()
	
	# Convert indices to triangle faces
	var faces = PackedVector3Array()
	for i in range(0, indices.size(), 3):
		if i+2 < indices.size():
			faces.append(vertices[indices[i]])
			faces.append(vertices[indices[i+1]])
			faces.append(vertices[indices[i+2]])
	
	shape.set_faces(faces)
	return shape
