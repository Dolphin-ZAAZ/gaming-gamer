extends Node3D

# Define voxel types
enum VoxelType {
	EMPTY,
	GRASS,
	DIRT,
	STONE
}

# Settings for the terrain generation
const TERRAIN_WIDTH = 64
const TERRAIN_HEIGHT = 8
const TERRAIN_DEPTH = 64
const NOISE_SCALE = 0.1

# FastNoiseLite instance
var noise: FastNoiseLite = null

# 3D array to hold voxel data
var voxel_grid: Array = []

# Mesh and collider
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

func _ready():
	# Initialize noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
	noise.frequency = NOISE_SCALE

	# Initialize voxel grid
	voxel_grid.resize(TERRAIN_WIDTH)
	for x in range(TERRAIN_WIDTH):
		voxel_grid[x] = []
		for y in range(TERRAIN_HEIGHT):
			voxel_grid[x].append([])
			for z in range(TERRAIN_DEPTH):
				voxel_grid[x][y].append(VoxelType.EMPTY)

	# Generate terrain
	generate_terrain()
	# Generate collider
	generate_collider()
	# Generate mesh
	generate_mesh()

func generate_terrain():
	for x in range(TERRAIN_WIDTH):
		for z in range(TERRAIN_DEPTH):
			# Get height from noise
			var height = int((noise.get_noise_2d(x, z) + 1) * 0.5 * TERRAIN_HEIGHT)
			for y in range(height):
				if y < height - 4:
					voxel_grid[x][y][z] = VoxelType.STONE
				elif y < height - 1:
					voxel_grid[x][y][z] = VoxelType.DIRT
				else:
					voxel_grid[x][y][z] = VoxelType.GRASS

# Function to get a voxel at specified coordinates
func get_voxel(x: int, y: int, z: int) -> int:
	if x < 0 or x >= TERRAIN_WIDTH or y < 0 or y >= TERRAIN_HEIGHT or z < 0 or z >= TERRAIN_DEPTH:
		return VoxelType.EMPTY
	return voxel_grid[x][y][z]

# Function to set a voxel at specified coordinates
func set_voxel(x: int, y: int, z: int, voxel_type: int):
	if x < 0 or x >= TERRAIN_WIDTH or y < 0 or y >= TERRAIN_HEIGHT or z < 0 or z >= TERRAIN_DEPTH:
		return
	voxel_grid[x][y][z] = voxel_type

func generate_mesh():
	var mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(TERRAIN_WIDTH):
		for y in range(TERRAIN_HEIGHT):
			for z in range(TERRAIN_DEPTH):
				var voxel = get_voxel(x, y, z)
				if voxel != VoxelType.EMPTY:
					var voxel_color = Color(1, 1, 1)
					if voxel == VoxelType.GRASS:
						voxel_color = Color(0, 1, 0)
					elif voxel == VoxelType.DIRT:
						voxel_color = Color(0.5, 0.25, 0)
					elif voxel == VoxelType.STONE:
						voxel_color = Color(0.5, 0.5, 0.5)
					
					add_voxel_to_mesh(surface_tool, x, y, z, voxel_color)

	surface_tool.index()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

func add_voxel_to_mesh(st: SurfaceTool, x: int, y: int, z: int, color: Color):
	var size = 0.5

	# Define the six faces of the cube with vertices in clockwise order
	var faces = [
		[[Vector3(-size, -size, -size), Vector3(size, -size, -size), Vector3(size, size, -size), Vector3(-size, size, -size)], Vector3(0, 0, -1)],
		[[Vector3(-size, -size, size), Vector3(size, -size, size), Vector3(size, size, size), Vector3(-size, size, size)], Vector3(0, 0, 1)],
		[[Vector3(-size, -size, -size), Vector3(-size, -size, size), Vector3(-size, size, size), Vector3(-size, size, -size)], Vector3(-1, 0, 0)],
		[[Vector3(size, -size, -size), Vector3(size, -size, size), Vector3(size, size, size), Vector3(size, size, -size)], Vector3(1, 0, 0)],
		[[Vector3(-size, -size, -size), Vector3(size, -size, -size), Vector3(size, -size, size), Vector3(-size, -size, size)], Vector3(0, -1, 0)],
		[[Vector3(-size, size, -size), Vector3(size, size, -size), Vector3(size, size, size), Vector3(-size, size, size)], Vector3(0, 1, 0)]
	]

	for face in faces:
		var vertices = face[0]
		var normal = face[1]

		# Define the two triangles for each face in clockwise order

		# First triangle
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[0] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[1] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[2] + Vector3(x, y, z))

		# Second triangle
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[2] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[3] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[0] + Vector3(x, y, z))
		
		# First triangle (opposite face)
		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[0] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[3] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[2] + Vector3(x, y, z))

		# Second triangle (opposite face)
		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[2] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[1] + Vector3(x, y, z))

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[0] + Vector3(x, y, z))

func generate_collider():
	# Create a StaticBody3D to hold the CollisionShape3D
	var static_body = StaticBody3D.new()
	add_child(static_body)

	# Create a new ConcavePolygonShape3D
	var shape = ConcavePolygonShape3D.new()
	var shape_data = []

	for x in range(TERRAIN_WIDTH):
		for y in range(TERRAIN_HEIGHT):
			for z in range(TERRAIN_DEPTH):
				var voxel = get_voxel(x, y, z)
				if voxel != VoxelType.EMPTY:
					var voxel_shape = create_voxel_shape(x, y, z)
					shape_data.append_array(voxel_shape)

	# Assign the collected shape data to the shape
	shape.data = shape_data

	# Create a new CollisionShape3D and set its shape
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	static_body.add_child(collision_shape)

func create_voxel_shape(x: int, y: int, z: int) -> PackedVector3Array:
	var size = 0.5
	var vertices = PackedVector3Array()

	vertices.append(Vector3(x - size, y - size, z - size))
	vertices.append(Vector3(x + size, y - size, z - size))
	vertices.append(Vector3(x + size, y + size, z - size))
	vertices.append(Vector3(x - size, y + size, z - size))

	vertices.append(Vector3(x - size, y - size, z + size))
	vertices.append(Vector3(x + size, y - size, z + size))
	vertices.append(Vector3(x + size, y + size, z + size))
	vertices.append(Vector3(x - size, y + size, z + size))

	var indices = PackedInt32Array([
		0, 1, 2, 0, 2, 3,  # Front face
		4, 5, 6, 4, 6, 7,  # Back face
		0, 1, 5, 0, 5, 4,  # Bottom face
		2, 3, 7, 2, 7, 6,  # Top face
		0, 3, 7, 0, 7, 4,  # Left face
		1, 2, 6, 1, 6, 5   # Right face
	])

	var result = PackedVector3Array()

	for i in range(indices.size()):
		result.append(vertices[indices[i]])

	return result
