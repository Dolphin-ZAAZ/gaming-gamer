extends Resource

class_name VoxelData

# Settings for the terrain generation
const TERRAIN_WIDTH = 64
const TERRAIN_HEIGHT = 8
const TERRAIN_DEPTH = 64
const NOISE_SCALE = 0.1

# FastNoiseLite instance
var noise: FastNoiseLite = null

# 3D array to hold voxel data
var voxel_grid: Array = []

func _init():
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
				voxel_grid[x][y].append(Voxel.new(Voxel.VoxelType.EMPTY, Vector3(x, y, z)))

	# Generate terrain
	generate_terrain()

func generate_terrain():
	for x in range(TERRAIN_WIDTH):
		for z in range(TERRAIN_DEPTH):
			# Get height from noise
			var height = int((noise.get_noise_2d(x, z) + 1) * 0.5 * TERRAIN_HEIGHT)
			for y in range(height):
				if y < height - 4:
					voxel_grid[x][y][z].type = Voxel.VoxelType.STONE
				elif y < height - 1:
					voxel_grid[x][y][z].type = Voxel.VoxelType.DIRT
				else:
					voxel_grid[x][y][z].type = Voxel.VoxelType.GRASS

# Function to get a voxel at specified coordinates
func get_voxel(x: int, y: int, z: int) -> Voxel:
	if x < 0 or x >= TERRAIN_WIDTH or y < 0 or y >= TERRAIN_HEIGHT or z < 0 or z >= TERRAIN_DEPTH:
		return Voxel.new(Voxel.VoxelType.EMPTY, Vector3(x, y, z))
	return voxel_grid[x][y][z]

# Function to set a voxel at specified coordinates
func set_voxel(x: int, y: int, z: int, voxel: Voxel):
	if x < 0 or x >= TERRAIN_WIDTH or y < 0 or y >= TERRAIN_HEIGHT or z < 0 or z >= TERRAIN_DEPTH:
		return
	voxel_grid[x][y][z] = voxel
