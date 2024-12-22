extends Node3D

class_name SmoothVoxelChunkManager

var chunks = {}
var chunk_size = 4
var render_distance = 5

func _ready():
	generate_chunks_around(Vector3.ZERO)

func generate_chunks_around(center_position: Vector3):
	var center_chunk = world_to_chunk_position(center_position)
	for x in range(center_chunk.x - render_distance, center_chunk.x + render_distance + 1):
		for y in range(center_chunk.y - render_distance, center_chunk.y + render_distance + 1):
			for z in range(center_chunk.z - render_distance, center_chunk.z + render_distance + 1):
				var chunk_pos = Vector3(x, y, z)
				if not chunks.has(chunk_pos):
					create_chunk(chunk_pos)

func create_chunk(chunk_position: Vector3):
	var chunk = SmoothVoxelChunk.new()
	chunk.position = chunk_position * chunk_size
	chunks[chunk_position] = chunk	
	add_child(chunk)
	update_chunk_and_neighbors(chunk_position)

func update_chunk_and_neighbors(chunk_position: Vector3):
	var directions = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]
	
	for direction in directions:
		var neighbor_pos = chunk_position + direction
		if chunks.has(neighbor_pos):
			update_chunk(neighbor_pos)
	
	update_chunk(chunk_position)

func update_chunk(chunk_position: Vector3):
	var chunk = chunks[chunk_position]
	var extended_voxel_data = get_extended_voxel_data(chunk_position)
	chunk.update_mesh_and_collider(extended_voxel_data)

func get_extended_voxel_data(chunk_position: Vector3):
	var extended_data = SmoothVoxelData.new(chunk_position, chunk_size + 2)
	
	for x in range(-1, chunk_size + 1):
		for y in range(-1, chunk_size + 1):
			for z in range(-1, chunk_size + 1):
				var world_pos = chunk_position * chunk_size + Vector3(x, y, z)
				var density = get_voxel_density(world_pos)
				extended_data.set_density(x + 1, y + 1, z + 1, density)
	
	return extended_data

func get_voxel_density(world_position: Vector3):
	var chunk_pos = world_to_chunk_position(world_position)
	var local_pos = world_position - (chunk_pos * chunk_size)
	
	if chunks.has(chunk_pos):
		return chunks[chunk_pos].get_voxel_data().get_density(local_pos.x, local_pos.y, local_pos.z)
	else:
		# Return a default density for non-existent chunks
		return -1.0

func world_to_chunk_position(world_position: Vector3):
	return Vector3(
		floor(world_position.x / chunk_size),
		floor(world_position.y / chunk_size),
		floor(world_position.z / chunk_size)
	)

func modify_voxel_density(hit_point: Vector3, radius: float, strength: float):
	var affected_chunks = {}
	var radius_squared = radius * radius
	
	var min_chunk = world_to_chunk_position(hit_point - Vector3.ONE * radius)
	var max_chunk = world_to_chunk_position(hit_point + Vector3.ONE * radius)
	
	for cx in range(min_chunk.x, max_chunk.x + 1):
		for cy in range(min_chunk.y, max_chunk.y + 1):
			for cz in range(min_chunk.z, max_chunk.z + 1):
				var chunk_pos = Vector3(cx, cy, cz)
				if chunks.has(chunk_pos):
					var chunk = chunks[chunk_pos]
					var chunk_origin = chunk_pos * chunk_size
					var local_min = (hit_point - chunk_origin - Vector3.ONE * radius).ceil()
					var local_max = (hit_point - chunk_origin + Vector3.ONE * radius).floor()
					
					for x in range(max(0, local_min.x), min(chunk_size, local_max.x + 1)):
						for y in range(max(0, local_min.y), min(chunk_size, local_max.y + 1)):
							for z in range(max(0, local_min.z), min(chunk_size, local_max.z + 1)):
								var voxel_pos = chunk_origin + Vector3(x, y, z)
								var distance_squared = hit_point.distance_squared_to(voxel_pos)
								if distance_squared <= radius_squared:
									var current_density = chunk.get_voxel_data().get_density(x, y, z)
									var new_density = current_density - strength
									chunk.get_voxel_data().set_density(x, y, z, new_density)
									affected_chunks[chunk_pos] = true
	
	for chunk_pos in affected_chunks:
		update_chunk_and_neighbors(chunk_pos)
