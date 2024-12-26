class_name AdaptiveMarchingCubes
extends Node3D

var cube_tables: MarchingCubesTables
var vertex_map: Dictionary = {}

class OctreeCache:
	var octree: Octree
	var vertex_map: Dictionary

	func _init(octree: Octree, vertex_map: Dictionary):
		self.octree = octree
		self.vertex_map = vertex_map

	func modify_density(position: Vector3, value: float, radius: float):
		modify_octree_recursive(octree, position, value, radius)

	func modify_octree_recursive(node: Octree, position: Vector3, value: float, radius: float):
		var distance = node.center.distance_to(position)
		if distance > radius + node.size * 0.866:  # sqrt(3)/2
			return
		
		var t = 1.0 - clamp(distance / radius, 0.0, 1.0)
		node.modification += value * t
		
		if not node.children.is_empty():
			for child in node.children:
				modify_octree_recursive(child, position, value, radius)

class Octree:
	var center: Vector3
	var size: float
	var value: float
	var modification: float
	var children: Array[Octree]
	
	func _init(center: Vector3, size: float):
		self.center = center
		self.size = size
		self.value = 0.0
		self.modification = 0.0
		self.children = []
	
	func subdivide():
		if not children.is_empty():
			return
		
		var half_size = size / 2.0
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					var offset = Vector3(x, y, z) * half_size * 0.5
					var child_center = center + offset
					children.append(Octree.new(child_center, half_size))

var octree_cache: OctreeCache
var root_octree: Octree
@export var chunk_type: String = "ground"
@export var collision_enabled: bool = true
@export var iso_level: float = 0.5
@export var grid_size: float = 10000.0
@export var max_depth: int = 6
@export var noise_scale: float = 0.1
@export var noise_frequency: float = 0.1
@export var noise_octaves: int = 4
@export var smoothing_factor: float = 0.05

@export var cave_noise_scale: float = 0.01
@export var cave_threshold: float = 0.5
@export var cave_sharpness: float = 5.0
@export var solid_threshold: float = 0.5

var noise: FastNoiseLite

func _ready():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = noise_frequency
	
	cube_tables = MarchingCubesTables.new()
	
	root_octree = Octree.new(Vector3.ZERO, grid_size)
	generate_adaptive_volume()
	generate_mesh_and_collider(collision_enabled)

func generate_adaptive_volume():
	subdivide_octree(root_octree, 0)
	smooth_octree_transitions(root_octree)

func smooth_octree_transitions(node: Octree):
	if node.children.is_empty():
		return
	
	var avg_value = 0.0
	for child in node.children:
		avg_value += child.value
	avg_value /= 8.0
	
	for child in node.children:
		child.value = lerp(child.value, avg_value, smoothing_factor)
		smooth_octree_transitions(child)

func subdivide_octree(node: Octree, depth: int):
	if depth >= max_depth:
		return
	
	node.value = density_function(chunk_type, node.center)
	
	if should_subdivide(node):
		node.subdivide()
		for child in node.children:
			subdivide_octree(child, depth + 1)

func should_subdivide(node: Octree) -> bool:
	return abs(node.value - iso_level) < node.size * 0.1


func rectangular_prism_density_function(point: Vector3) -> float:
	# Calculate distances from the center for each axis
	var distance_x = abs(point.x) / (grid_size * 0.5)
	var distance_y = abs(point.y) / (grid_size * 0.25)  # Make it shorter in Y-axis
	var distance_z = abs(point.z) / (grid_size * 0.5)
	
	# Create smooth falloff towards the edges for each axis
	var edge_falloff_x = smoothstep(0.7, 1.0, distance_x)
	var edge_falloff_y = smoothstep(0.7, 1.0, distance_y)
	var edge_falloff_z = smoothstep(0.7, 1.0, distance_z)
	
	# Combine falloffs
	var edge_falloff = max(edge_falloff_x, max(edge_falloff_y, edge_falloff_z))
	
	# Create solid interior
	var solid_interior = 1.0 if edge_falloff < 0.5 else -1.0
	
	# Cave noise
	var cave_noise = noise.get_noise_3dv(point * cave_noise_scale) * 0.5 + 0.5
	
	# Create caves, but make them less frequent
	var cave_value = smoothstep(cave_threshold + 0.2, cave_threshold + 0.3, cave_noise) * cave_sharpness * 0.7
	
	# Combine solid interior with cave structures
	var combined_density = solid_interior - cave_value
	
	# Apply edge falloff
	combined_density = lerp(combined_density, -1.0, edge_falloff)
	
	return combined_density

func boulder_density_function(point: Vector3) -> float:
	# Calculate distance from the center of the grid
	var distance_from_center = point.length()
	var max_distance = grid_size * 0.5
	
	# Create a smooth falloff towards the edges
	var edge_falloff = smoothstep(0, max_distance, distance_from_center)
	edge_falloff = 1.0 - edge_falloff  # Invert the falloff
	
	# Create solid interior
	var solid_interior = 1.0 if edge_falloff > solid_threshold else -1.0
	
	# Cave noise
	var cave_noise = noise.get_noise_3dv(point * cave_noise_scale) * 0.5 + 0.5
	
	# Create caves
	var cave_value = smoothstep(cave_threshold, cave_threshold + 0.1, cave_noise) * cave_sharpness
	
	# Combine solid interior with cave structures
	var combined_density = solid_interior - cave_value
	
	# Apply edge falloff
	combined_density = lerp(combined_density, -1.0, 1.0 - edge_falloff)
	
	return combined_density


func density_function(type: String, point: Vector3) -> float:
	if type == "boulder":
		return boulder_density_function(point)
	elif type == "ground":
		return rectangular_prism_density_function(point)
	else:
		return rectangular_prism_density_function(point)


func generate_mesh_and_collider(collider_enabled: bool):
	vertex_map.clear()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var collision_points = []
	
	process_octree(root_octree, st, collision_points)
	
	st.generate_normals()
	st.index()
	var mesh = st.commit()
	var mesh_instance = MeshInstance3D.new()
	mesh.surface_set_material(0, create_double_sided_material())
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	print("Vertex Count: ", mesh.get_surface_count())
	add_child(mesh_instance)

	mesh_instance.position = -Vector3(grid_size, grid_size, grid_size) * 0.5

	if collider_enabled:
		# Generate collision shape
		var collision_shape = CollisionShape3D.new()
		var concave_polygon_shape = ConcavePolygonShape3D.new()
		concave_polygon_shape.set_faces(collision_points)
		collision_shape.shape = concave_polygon_shape

		var static_body = StaticBody3D.new()
		static_body.add_child(collision_shape)
		add_child(static_body)
		static_body.position = mesh_instance.position

func create_double_sided_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.cull_mode = StandardMaterial3D.CULL_DISABLED
	return material

func process_octree(node: Octree, st: SurfaceTool, collision_points: Array):
	if node.children.is_empty():
		generate_cube_mesh(node, st, collision_points)
	else:
		for child in node.children:
			process_octree(child, st, collision_points)


func generate_cube_mesh(node: Octree, st: SurfaceTool, collision_points: Array):
	var corners = get_cube_corners(node)
	var corner_values = []
	for corner in corners:
		corner_values.append(density_function(chunk_type, corner))
	
	var cube_index = 0
	for i in range(8):
		if corner_values[i] < iso_level:
			cube_index |= 1 << i
	if cube_index == 0 or cube_index == 255:
		return
	
	var edge_mask = cube_tables.EDGE_TABLE[cube_index]
	var triangles = cube_tables.TRIANGLE_TABLE[cube_index]
	
	for i in range(0, triangles.size(), 3):
		if triangles[i] == -1:
			break
		
		var a = get_interpolated_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i] * 2 + 1])
		var b = get_interpolated_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i+1] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i+1] * 2 + 1])
		var c = get_interpolated_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i+2] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i+2] * 2 + 1])

		var normal = (b - a).cross(c - a).normalized()

		st.set_normal(normal)
		st.add_vertex(a)
		st.set_normal(normal)
		st.add_vertex(b)
		st.set_normal(normal)
		st.add_vertex(c)

		# Add collision points for both sides of the triangle
		collision_points.append(a)
		collision_points.append(b)
		collision_points.append(c)
		collision_points.append(c)
		collision_points.append(b)
		collision_points.append(a)


func get_cube_corners(node: Octree) -> Array:
	var corners = []
	var half_size = node.size * 0.5
	for offset in cube_tables.EDGE_VERTEXT_OFFSETS:
		corners.append(node.center + (offset - Vector3(0.5, 0.5, 0.5)) * node.size)
	return corners

func interpolate_vertex(corners: Array, values: Array, index1: int, index2: int) -> Vector3:
	var t = (iso_level - values[index1]) / (values[index2] - values[index1])
	return corners[index1].lerp(corners[index2], t)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_0:
			regenerate_mesh()

func regenerate_mesh():
	for child in get_children():
		if child is MeshInstance3D or child is StaticBody3D:
			child.queue_free()
	
	noise.seed = randi()
	root_octree = Octree.new(Vector3.ZERO, grid_size)
	generate_adaptive_volume()
	generate_mesh_and_collider(collision_enabled)

func get_interpolated_vertex(corners: Array, values: Array, index1: int, index2: int) -> Vector3:
	var edge_key = get_edge_key(corners[index1], corners[index2])
	if edge_key in vertex_map:
		return vertex_map[edge_key]
	
	var t = (iso_level - values[index1]) / (values[index2] - values[index1])
	var vertex = corners[index1].lerp(corners[index2], t)
	vertex_map[edge_key] = vertex
	return vertex

func get_edge_key(v1: Vector3, v2: Vector3) -> String:
	var rounded_v1 = Vector3(snapped(v1.x, 0.001), snapped(v1.y, 0.001), snapped(v1.z, 0.001))
	var rounded_v2 = Vector3(snapped(v2.x, 0.001), snapped(v2.y, 0.001), snapped(v2.z, 0.001))
	return "%s-%s" % [rounded_v1, rounded_v2] if rounded_v1 < rounded_v2 else "%s-%s" % [rounded_v2, rounded_v1]


func smooth_vertex_position(vertex: Vector3) -> Vector3:
	var sample_offset = Vector3(0.1, 0.1, 0.1)
	var samples = [
		density_function(chunk_type, vertex + sample_offset),
		density_function(chunk_type, vertex - sample_offset),
		density_function(chunk_type, vertex + Vector3(sample_offset.x, -sample_offset.y, -sample_offset.z)),
		density_function(chunk_type, vertex + Vector3(-sample_offset.x, sample_offset.y, -sample_offset.z)),
		density_function(chunk_type, vertex + Vector3(-sample_offset.x, -sample_offset.y, sample_offset.z))
	]
	
	var avg_sample = 0.0
	for sample in samples:
		avg_sample += sample
	avg_sample /= samples.size()
	
	var smoothed_value = lerp(density_function(chunk_type, vertex), avg_sample, smoothing_factor)
	var t = (iso_level - density_function(chunk_type, vertex)) / (smoothed_value - density_function(chunk_type, vertex))
	return vertex.lerp(vertex + sample_offset, t)
