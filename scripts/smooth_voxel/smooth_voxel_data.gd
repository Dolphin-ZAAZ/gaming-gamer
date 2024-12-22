extends Resource

class_name SmoothVoxelData

var CHUNK_SIZE: int = 8
var densities: Array = []
var NOISE_SCALE: float = 0.1

func _init(chunk_position: Vector3, size: int = 16):
	CHUNK_SIZE = size
	_generate_cube(chunk_position)

func _generate_cube(chunk_position: Vector3):
	densities.resize((CHUNK_SIZE + 1) * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1))
	
	for x in range(CHUNK_SIZE + 1):
		for y in range(CHUNK_SIZE + 1):
			for z in range(CHUNK_SIZE + 1):
				var density: float
				density = 1.0
				
				set_density(x, y, z, density)

func get_density(x: int, y: int, z: int) -> float:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	return densities[index]

func set_density(x: int, y: int, z: int, density: float) -> void:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	densities[index] = density
