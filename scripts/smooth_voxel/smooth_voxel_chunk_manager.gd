extends Node3D

class_name SmoothVoxelChunkManager

var chunks = {}
var chunk_size = 4
var render_distance = 3

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
	print("Modifying voxel density:")
	print("  Hit point: ", hit_point)
	print("  Radius: ", radius)
	print("  Strength: ", strength)
	var radius_squared = radius * radius
	var chunk_radius = ceil(radius / chunk_size)
	var center_chunk = world_to_chunk_position(hit_point)
	
	var affected_chunks = {}
	for cx in range(-chunk_radius, chunk_radius + 1):
		for cy in range(-chunk_radius, chunk_radius + 1):
			for cz in range(-chunk_radius, chunk_radius + 1):
				var chunk_pos = center_chunk + Vector3(cx, cy, cz)
				if chunks.has(chunk_pos):
					affected_chunks[chunk_pos] = chunks[chunk_pos]
	
	var rd = RenderingServer.create_local_rendering_device()
	var shader_file = load("res://shaders/modify_voxel_density.glsl")
	var shader_spiral = rd.shader_create_from_spirv(shader_file.get_spirv())

	for chunk_pos in affected_chunks:
		var chunk = affected_chunks[chunk_pos]
		var chunk_start = chunk_pos * chunk_size
		
		var density_data = chunk.get_voxel_data().get_density_data()
		var byte_array = density_data.to_byte_array()
		var density_buffer = rd.storage_buffer_create(byte_array.size(), byte_array)

		var uniform_data = PackedFloat32Array([
			hit_point.x, hit_point.y, hit_point.z,
			radius, radius * radius, strength,
			chunk_start.x, chunk_start.y, chunk_start.z,
			float(chunk_size),
			0.0, 0.0  # Add padding to match shader uniform size
		])
		var uniform_byte_array = uniform_data.to_byte_array()
		var uniform_buffer = rd.uniform_buffer_create(uniform_byte_array.size(), uniform_byte_array)

		var pipeline = rd.compute_pipeline_create(shader_spiral)
		
		var density_uniform = RDUniform.new()
		density_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		density_uniform.binding = 0
		density_uniform.add_id(density_buffer)
		
		var uniform_buffer_uniform = RDUniform.new()
		uniform_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		uniform_buffer_uniform.binding = 1
		uniform_buffer_uniform.add_id(uniform_buffer)
		
		var uniform_set = rd.uniform_set_create([density_uniform, uniform_buffer_uniform], shader_spiral, 0)
		
		var compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		
		var work_group_size = 8
		var num_work_groups = int(ceil(float(chunk_size) / float(work_group_size)))
		
		rd.compute_list_dispatch(compute_list, num_work_groups, num_work_groups, num_work_groups)
		rd.compute_list_end()
		
		rd.submit()
		rd.sync()
		
		var output = rd.buffer_get_data(density_buffer)
		var float_output = output.to_float32_array()
		chunk.get_voxel_data().set_density_data(float_output)
		
		rd.free_rid(density_buffer)
		rd.free_rid(uniform_buffer)
	
	rd.free_rid(shader_spiral)
	
	for chunk_pos in affected_chunks:
		update_chunk_and_neighbors(chunk_pos)
