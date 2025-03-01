extends Node3D

class_name OLDVoxelChunk

const CHUNK_SIZE = 16
const NOISE_SCALE = 0.1

var voxel_data: Array = []
var noise: FastNoiseLite

func _init():
	noise = FastNoiseLite.new()
	var unique_id = OS.get_unique_id()
	noise.seed = unique_id.hash()
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
	noise.frequency = NOISE_SCALE

	voxel_data.resize(CHUNK_SIZE)
	for x in range(CHUNK_SIZE):
		voxel_data[x] = []
		for y in range(CHUNK_SIZE):
			voxel_data[x].append([])
			for z in range(CHUNK_SIZE):
				voxel_data[x][y].append(Voxel.new(Voxel.VoxelType.EMPTY, Vector3(x, y, z)))

func _ready() -> void:
	# Generate and add voxel mesh
	var mesh = VoxelMesh.new().generate_mesh(self)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	
	# Generate and add voxel collider
	var collider = VoxelCollider.new().generate_collider(self)
	add_child(collider)
	
func generate_terrain():
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var height = int((noise.get_noise_2d(x + position.x, z + position.z) + 1) * 0.5 * CHUNK_SIZE)
			for y in range(height):
				if y < height - 4:
					voxel_data[x][y][z].type = Voxel.VoxelType.STONE
				elif y < height - 1:
					voxel_data[x][y][z].type = Voxel.VoxelType.DIRT
				else:
					voxel_data[x][y][z].type = Voxel.VoxelType.GRASS

# Function to get a voxel at specified coordinates
func get_voxel(x: int, y: int, z: int) -> Voxel:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return Voxel.new(Voxel.VoxelType.EMPTY, Vector3(x, y, z))
	return voxel_data[x][y][z]

# Function to set a voxel at specified coordinates
func set_voxel(x: int, y: int, z: int, voxel: Voxel):
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	voxel_data[x][y][z] = voxel
