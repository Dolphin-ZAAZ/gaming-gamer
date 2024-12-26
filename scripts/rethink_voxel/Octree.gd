class_name AdaptiveMarchingCubes
extends Node3D

var cube_tables: MarchingCubesTables

class Octree:
	var center: Vector3
	var size: float
	var value: float
	var children: Array[Octree]
	
	func _init(center: Vector3, size: float):
		self.center = center
		self.size = size
		self.value = 0.0
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

var root_octree: Octree
@export var iso_level: float = 0.0
@export var grid_size: float = 20.0
@export var max_depth: int = 5
@export var noise_scale: float = 0.1
@export var noise_octaves: int = 3

var noise: FastNoiseLite

func _ready():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	
	cube_tables = MarchingCubesTables.new()
	
	root_octree = Octree.new(Vector3.ZERO, grid_size)
	generate_adaptive_volume()
	generate_mesh()

func generate_adaptive_volume():
	subdivide_octree(root_octree, 0)

func subdivide_octree(node: Octree, depth: int):
	if depth >= max_depth:
		return
	
	node.value = sample_density_function(node.center)
	
	if should_subdivide(node):
		node.subdivide()
		for child in node.children:
			subdivide_octree(child, depth + 1)

func should_subdivide(node: Octree) -> bool:
	return abs(node.value - iso_level) < node.size * 0.1

func sample_density_function(point: Vector3) -> float:
	var base_density = point.length() / grid_size
	var noise_value = noise.get_noise_3dv(point * noise_scale) * grid_size * 0.2
	return base_density + noise_value

func generate_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	process_octree(root_octree, st)
	
	st.generate_normals()
	st.index()  # Add this line to optimize the mesh
	var mesh = st.commit()
	var mesh_instance = MeshInstance3D.new()
	mesh.surface_set_material(0, create_double_sided_material())
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	print("Vertex Count: ", mesh.get_surface_count())
	add_child(mesh_instance)

	# Position the mesh at the center of the scene
	mesh_instance.position = -Vector3(grid_size, grid_size, grid_size) * 0.5

func create_double_sided_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.cull_mode = StandardMaterial3D.CULL_DISABLED
	return material

func process_octree(node: Octree, st: SurfaceTool):
	if node.children.is_empty():
		generate_cube_mesh(node, st)
	else:
		for child in node.children:
			process_octree(child, st)

func generate_cube_mesh(node: Octree, st: SurfaceTool):
	var corners = get_cube_corners(node)
	var corner_values = []
	for corner in corners:
		corner_values.append(sample_density_function(corner))
	
	print("Corner values: ", corner_values)
	
	var cube_index = 0
	for i in range(8):
		if corner_values[i] < iso_level:
			cube_index |= 1 << i
	
	print("Cube index: ", cube_index)
	
	if cube_index == 0 or cube_index == 255:
		print("Skipping cube - all inside or all outside")
		return
	
	var edge_mask = cube_tables.EDGE_TABLE[cube_index]
	var triangles = cube_tables.TRIANGLE_TABLE[cube_index]
	print("Triangles: ", triangles)
	
	for i in range(0, triangles.size(), 3):
		if triangles[i] == -1:
			break
		
		var a = interpolate_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i] * 2 + 1])
		var b = interpolate_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i+1] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i+1] * 2 + 1])
		var c = interpolate_vertex(corners, corner_values, cube_tables.EDGE_CONNECTIONS[triangles[i+2] * 2], cube_tables.EDGE_CONNECTIONS[triangles[i+2] * 2 + 1])

		var normal = (b - a).cross(c - a).normalized()

		print("Normal: ", normal)
		print("Vertices: ", a, b, c)

		st.set_normal(normal)
		st.add_vertex(a)
		st.set_normal(normal)
		st.add_vertex(b)
		st.set_normal(normal)
		st.add_vertex(c)

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
		if event.keycode == KEY_SPACE:
			regenerate_mesh()

func regenerate_mesh():
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	
	noise.seed = randi()
	root_octree = Octree.new(Vector3.ZERO, grid_size)
	generate_adaptive_volume()
	generate_mesh()
