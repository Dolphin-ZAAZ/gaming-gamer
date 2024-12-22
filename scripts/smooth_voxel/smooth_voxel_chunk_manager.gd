extends Node3D

class_name SmoothVoxelChunkManager

var chunk_size: int = 36   # Size of each chunk
var grid_size: int = 1   # Number of chunks per dimension, creates grid_size x grid_size area
var chunks: Array = []

func _ready():
	initialize_chunks()

func initialize_chunks():
	for x in range(grid_size):
		for y in range(grid_size):
			for z in range(grid_size):
				var chunk_position = Vector3(x, y, z)  # World-space grid position
				var chunk = create_chunk(chunk_position)
				chunks.append(chunk)
				add_child(chunk)

func create_chunk(chunk_position: Vector3) -> SmoothVoxelChunk:
	var chunk = SmoothVoxelChunk.new()
	chunk.voxel_data = SmoothVoxelData.new(chunk_position * chunk_size)
	chunk.update_mesh_and_collider()
	chunk.position = chunk_position * chunk_size
	return chunk
