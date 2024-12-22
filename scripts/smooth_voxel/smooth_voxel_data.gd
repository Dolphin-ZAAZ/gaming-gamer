extends Resource

class_name SmoothVoxelData

var CHUNK_SIZE: int = 16
var densities: Array = []
var NOISE_SCALE: float = 0.1

func _init(chunk_position: Vector3):
	_generate_cube(chunk_position)

func _generate_cube(chunk_position: Vector3):
	densities.resize((CHUNK_SIZE + 1) * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1))
	
	for x in range(CHUNK_SIZE + 1):
		for y in range(CHUNK_SIZE + 1):
			for z in range(CHUNK_SIZE + 1):
				var density: float
				
				if x == 0 or y == 0 or z == 0 or x == CHUNK_SIZE-1 or y == CHUNK_SIZE-1 or z == CHUNK_SIZE-1:
					# Outer layer: set to non-solid (negative density)
					density = -1.0
				else:
					# Interior: set to solid (positive density)
					density = 1.0
				
				set_density(x, y, z, density)

func get_density(x: int, y: int, z: int) -> float:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	return densities[index]

func set_density(x: int, y: int, z: int, density: float) -> void:
	var index = x + y * (CHUNK_SIZE + 1) + z * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	densities[index] = density
