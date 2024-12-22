extends Resource

class_name SmoothVoxelData

var CHUNK_SIZE: int = 4
var densities: PackedFloat32Array = PackedFloat32Array()
var NOISE_SCALE: float = 0.1

func _init(chunk_position: Vector3, size: int = 16):
	CHUNK_SIZE = size
	_generate_cube(chunk_position)

func _generate_cube(chunk_position: Vector3):
	var total_size = (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	densities.resize(total_size)
	
	# Pre-calculate the density value
	var density: float = 1.0
	
	# Use direct array access for faster writing
	for i in range(total_size):
		densities[i] = density

func get_density(x: int, y: int, z: int) -> float:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	return densities[index]

func set_density(x: int, y: int, z: int, density: float) -> void:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	densities[index] = density

# Add these new methods
func get_density_data() -> PackedFloat32Array:
	return densities

func set_density_data(new_densities: PackedFloat32Array) -> void:
	for i in range(new_densities.size()):
		if new_densities[i] < 1:
			print("Density ", i, ": ", new_densities[i])
	densities = new_densities
