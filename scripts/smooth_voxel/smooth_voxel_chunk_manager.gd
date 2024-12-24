extends Node3D

class_name SmoothVoxelChunkManager

var modification_thread: Thread
var modification_mutex: Mutex
var modification_queue: Array = []
var should_exit_thread: bool = false

var chunks = {}
var chunk_size = 16
var render_distance = 4

var total_data_generation_time = 0.0
var total_mesh_update_time = 0.0
var last_log_time = 0.0
var update_count = 0

var update_queue = []
var update_thread: Thread
var is_updating = false

var chunks_to_generate = []

func _ready():
	modification_mutex = Mutex.new()
	queue_chunks_around(Vector3.ZERO)

func _process(delta):
	if Time.get_ticks_msec() - last_log_time > 3000:  # Log every 3 seconds
		log_progress()

	if not is_updating and not update_queue.is_empty():
		_start_next_update()
	elif not is_updating and not chunks_to_generate.is_empty():
		generate_next_chunk()


func log_progress():
	print("Progress: Data generation time: %.2f s, Mesh update time: %.2f s" % 
		[total_data_generation_time, total_mesh_update_time])
	last_log_time = Time.get_ticks_msec()

func queue_chunks_around(center_position: Vector3):
	var center_chunk = world_to_chunk_position(center_position)
	var max_radius = render_distance * render_distance

	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			for y in range(0, -render_distance - 1, -1):
				var chunk_pos = center_chunk + Vector3(x, y, z)
				var distance_squared = x * x + y * y + z * z
				if distance_squared <= max_radius:
					if not chunks.has(chunk_pos) and not chunks_to_generate.has(chunk_pos):
						chunks_to_generate.append(chunk_pos)

	chunks_to_generate.sort_custom(func(a, b):
		var a_dist = center_chunk.distance_squared_to(a)
		var b_dist = center_chunk.distance_squared_to(b)
		if abs(a_dist - b_dist) < 0.001:  # If distances are very close
			return a.y > b.y  # Prioritize higher y values
		return a_dist < b_dist  # Otherwise, sort by distance
	)

func generate_next_chunk():
	if chunks_to_generate.is_empty():
		return

	var chunk_pos = chunks_to_generate.pop_front()
	create_chunk(chunk_pos)

func create_chunk(chunk_position: Vector3):
	var chunk = SmoothVoxelChunk.new(chunk_size)
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
		if chunks.has(neighbor_pos) and not update_queue.has(neighbor_pos):
			update_queue.append(neighbor_pos)
	
	if not update_queue.has(chunk_position):
		update_queue.append(chunk_position)
	

func _start_next_update():
	if update_queue.is_empty():
		return

	var chunk_position = update_queue.pop_front()
	var chunk = chunks[chunk_position]
	
	var start_time = Time.get_ticks_msec()
	var extended_voxel_data = get_extended_voxel_data(chunk_position)
	var data_generation_time = (Time.get_ticks_msec() - start_time) / 1000.0
	total_data_generation_time += data_generation_time

	is_updating = true
	update_thread = Thread.new()
	update_thread.start(Callable(self, "_thread_update_chunk").bind(chunk, extended_voxel_data))

func _thread_update_chunk(chunk, extended_voxel_data):
	var start_time = Time.get_ticks_msec()
	chunk.update_mesh_and_collider(extended_voxel_data)
	var mesh_update_time = (Time.get_ticks_msec() - start_time) / 1000.0
	call_deferred("_finish_chunk_update", mesh_update_time)

func _finish_chunk_update(mesh_update_time):
	total_mesh_update_time += mesh_update_time
	update_count += 1
	
	if update_count % 10 == 0:  # Log every 10 updates
		log_progress()
	
	is_updating = false
	update_thread.wait_to_finish()
	
func get_extended_voxel_data(chunk_position: Vector3):
	var extended_data = SmoothVoxelData.new(chunk_size + 2)
	
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
	modification_mutex.lock()
	modification_queue.append([hit_point, radius, strength])
	modification_mutex.unlock()
	
	if not modification_thread:
		modification_thread = Thread.new()
		modification_thread.start(Callable(self, "_modification_thread_function"))

func _modification_thread_function():
	while true:
		modification_mutex.lock()
		var queue = modification_queue.duplicate()
		modification_queue.clear()
		var should_exit = should_exit_thread
		modification_mutex.unlock()
		
		if should_exit and queue.is_empty():
			break
		
		for task in queue:
			_perform_modification(task[0], task[1], task[2])
		
		# Add a small delay to prevent the thread from hogging CPU
		OS.delay_msec(10)
	
	call_deferred("_finalize_modification_thread")

func _perform_modification(hit_point: Vector3, radius: float, strength: float):
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
		call_deferred("update_chunk_and_neighbors", chunk_pos)

func _finalize_modification_thread():
	if modification_thread:
		modification_thread.wait_to_finish()
		modification_thread = null

func _exit_tree():
	if modification_thread:
		modification_mutex.lock()
		should_exit_thread = true
		modification_mutex.unlock()
		# Wait for the thread to finish
		modification_thread.wait_to_finish()
	
