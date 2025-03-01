class_name ChunkedMarchingCubes
extends Node3D

# Configuration
@export_category("Chunking")
@export var chunk_size: int = 16  # Voxels per chunk axis
@export var voxel_size: float = 1.0  # Size of each voxel
@export var world_size: float = 512.0  # Total world size
@export var chunk_generate_distance: int = 4  # How many chunks to generate from center

@export_category("Mesh Generation")
@export var iso_level: float = 0.0  # Surface threshold
@export var collision_enabled: bool = true
@export var use_lod: bool = true
@export var max_lod_levels: int = 4

@export_category("Performance")
@export var max_chunks_per_frame: int = 1  # Max chunks to process per frame
@export var multithreaded: bool = false  # Use threading for mesh generation

# Noise for terrain generation
@export_category("Terrain")
@export var noise_scale: float = 0.1
@export var noise_frequency: float = 0.1
@export var noise_octaves: int = 4
@export var cave_noise_scale: float = 0.01
@export var cave_threshold: float = 0.5
@export var cave_sharpness: float = 5.0
@export var solid_threshold: float = 0.5

# Internal variables
var chunks: Dictionary = {}  # Maps Vector3i to VoxelChunk
var active_chunks: Array[Vector3i] = []
var chunks_to_update: Array[Vector3i] = []
var modified_regions: Dictionary = {}  # Spatial hash for changed regions
var noise: FastNoiseLite
var _thread: Thread

# Core functionality
func _ready():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = noise_frequency
	
	initialize_world()

func _process(delta):
	update_chunks()

# World management
func initialize_world():
	var center_chunk = Vector3i.ZERO
	generate_chunks_around(center_chunk)
	
func generate_chunks_around(center: Vector3i):
	for x in range(center.x - chunk_generate_distance, center.x + chunk_generate_distance + 1):
		for y in range(center.y - chunk_generate_distance, center.y + chunk_generate_distance + 1):
			for z in range(center.z - chunk_generate_distance, center.z + chunk_generate_distance + 1):
				var chunk_pos = Vector3i(x, y, z)
				
				# Skip if chunk already exists
				if chunk_pos in chunks:
					continue
					
				# Create new chunk
				var chunk = VoxelChunk.new(chunk_pos, chunk_size, voxel_size)
				chunks[chunk_pos] = chunk
				
				# Connect to neighbors
				add_chunk_neighbors(chunk)
				
				# Generate terrain
				generate_terrain_for_chunk(chunk)
				
				# Mark for mesh update
				chunks_to_update.append(chunk_pos)
				active_chunks.append(chunk_pos)

func add_chunk_neighbors(chunk: VoxelChunk):
	# Find and connect neighbors in all 6 directions
	var directions = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for dir in directions:
		var neighbor_pos = chunk.position + dir
		if neighbor_pos in chunks:
			# Connect both ways
			chunk.neighbors[neighbor_pos] = chunks[neighbor_pos]
			chunks[neighbor_pos].neighbors[chunk.position] = chunk

# Update system
func update_chunks():
	var updated = 0
	
	while chunks_to_update.size() > 0 and updated < max_chunks_per_frame:
		var chunk_pos = chunks_to_update.pop_front()
		if chunk_pos in chunks:
			var chunk = chunks[chunk_pos]
			if chunk.is_dirty:
				generate_mesh_for_chunk(chunk)
				chunk.is_dirty = false
				updated += 1

# Terrain generation
func generate_terrain_for_chunk(chunk: VoxelChunk):
	for x in range(chunk_size):
		for y in range(chunk_size):
			for z in range(chunk_size):
				var world_pos = chunk.get_voxel_position(x, y, z)
				var density = terrain_density_function(world_pos)
				chunk.set_density(x, y, z, density)
	
	chunk.update_surface_status(iso_level)

func terrain_density_function(point: Vector3) -> float:
	# Calculate distance from center
	var distance_from_center = point.length()
	var max_distance = world_size * 0.5
	
	# Create smooth falloff towards edges
	var edge_falloff = smoothstep(0, max_distance, distance_from_center)
	edge_falloff = 1.0 - edge_falloff  # Invert the falloff
	
	# Create solid interior
	var solid_interior = 1.0 if edge_falloff > solid_threshold else -1.0
	
	# Cave noise
	var cave_noise = noise.get_noise_3dv(point * cave_noise_scale) * 0.5 + 0.5
	
	# Create caves
	var cave_value = smoothstep(cave_threshold, cave_threshold + 0.1, cave_noise) * cave_sharpness
	
	# Combine solid interior with cave structures
	var combined_density = solid_interior - cave_value
	
	# Apply edge falloff
	combined_density = lerp(combined_density, -1.0, 1.0 - edge_falloff)
	
	# Check for any modifications in modified_regions
	for region_center in modified_regions:
		var region_data = modified_regions[region_center]
		var distance = point.distance_to(region_center)
		if distance <= region_data.radius:
			# Apply modification based on type
			if region_data.type == "remove":
				combined_density -= region_data.strength * (1.0 - distance / region_data.radius)
			elif region_data.type == "add":
				combined_density += region_data.strength * (1.0 - distance / region_data.radius)

	return combined_density

# Mesh generation
func generate_mesh_for_chunk(chunk: VoxelChunk):
	# Clear any previous mesh
	remove_chunk_mesh(chunk.position)
	chunk.clear_mesh_data()
	
	if not chunk.has_surface:
		return  # Skip mesh generation if no surface detected
	
	# Generate the marching cubes mesh
	for x in range(chunk_size - 1):
		for y in range(chunk_size - 1):
			for z in range(chunk_size - 1):
				generate_cell_mesh(chunk, x, y, z)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = chunk.mesh_data.create_mesh()
	mesh_instance.name = "Chunk_" + str(chunk.position)
	mesh_instance.position = chunk.world_position
	
	# Material setup
	var material = StandardMaterial3D.new()
	material.cull_mode = StandardMaterial3D.CULL_DISABLED
	mesh_instance.mesh.surface_set_material(0, material)
	
	add_child(mesh_instance)
	
	# Collision if enabled
	if collision_enabled:
		var body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		collision_shape.shape = chunk.mesh_data.create_collision_shape()
		body.add_child(collision_shape)
		body.name = "Collision_" + str(chunk.position)
		body.position = chunk.world_position
		add_child(body)

func remove_chunk_mesh(chunk_pos: Vector3i):
	# Remove any existing mesh for this chunk
	var mesh_name = "Chunk_" + str(chunk_pos)
	var collision_name = "Collision_" + str(chunk_pos)
	
	var mesh_node = get_node_or_null(mesh_name)
	if mesh_node:
		mesh_node.queue_free()
		
	var collision_node = get_node_or_null(collision_name)
	if collision_node:
		collision_node.queue_free()

func generate_cell_mesh(chunk: VoxelChunk, x: int, y: int, z: int):
	# Get the 8 corner values
	var corner_values = []
	var corner_positions = []
	
	for i in range(8):
		var corner_offset = MarchingCubesTables.EDGE_VERTEXT_OFFSETS[i]
		var cx = x + int(corner_offset.x)
		var cy = y + int(corner_offset.y)
		var cz = z + int(corner_offset.z)
		
		corner_values.append(chunk.get_density(cx, cy, cz))
		corner_positions.append(chunk.get_voxel_position(cx, cy, cz))
	
	# Determine cube index
	var cube_index = 0
	for i in range(8):
		if corner_values[i] < iso_level:
			cube_index |= 1 << i
	
	# Early exit if cube is entirely inside or outside the surface
	if cube_index == 0 or cube_index == 255:
		return
	
	# Get edge mask from table
	var edge_mask = MarchingCubesTables.EDGE_TABLE[cube_index]
	
	# Get triangulation
	var triangles = MarchingCubesTables.TRIANGLE_TABLE[cube_index]
	
	# Generate triangles
	for i in range(0, triangles.size(), 3):
		if triangles[i] == -1:
			break
		
		var a = get_interpolated_vertex(
			chunk, 
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i] * 2]], 
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i] * 2 + 1]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i] * 2]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i] * 2 + 1]]
		)
		
		var b = get_interpolated_vertex(
			chunk,
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+1] * 2]], 
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+1] * 2 + 1]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+1] * 2]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+1] * 2 + 1]]
		)
		
		var c = get_interpolated_vertex(
			chunk,
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+2] * 2]], 
			corner_positions[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+2] * 2 + 1]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+2] * 2]],
			corner_values[MarchingCubesTables.EDGE_CONNECTIONS[triangles[i+2] * 2 + 1]]
		)
		
		# Calculate normal
		var normal = chunk.mesh_data.calculate_normal(a, b, c)
		
		# Add triangle (relative to chunk position for proper world placement)
		chunk.mesh_data.add_triangle_by_vertices(
			a - chunk.world_position, normal,
			b - chunk.world_position, normal,
			c - chunk.world_position, normal
		)

func get_interpolated_vertex(chunk: VoxelChunk, p1: Vector3, p2: Vector3, val1: float, val2: float) -> Vector3:
	# Check cache
	var edge_key = get_edge_key(p1, p2)
	
	if edge_key in chunk.edge_vertices_cache:
		return chunk.edge_vertices_cache[edge_key]
	
	# t value for interpolation
	var t = (iso_level - val1) / (val2 - val1)
	# Clamp to avoid NaN or infinite values
	t = clamp(t, 0.0, 1.0)
	
	# Interpolate vertex position
	var vertex = p1.lerp(p2, t)
	
	# Cache the result
	chunk.edge_vertices_cache[edge_key] = vertex
	
	return vertex

func get_edge_key(v1: Vector3, v2: Vector3) -> String:
	var rounded_v1 = Vector3(snapped(v1.x, 0.001), snapped(v1.y, 0.001), snapped(v1.z, 0.001))
	var rounded_v2 = Vector3(snapped(v2.x, 0.001), snapped(v2.y, 0.001), snapped(v2.z, 0.001))
	return "%s-%s" % [rounded_v1, rounded_v2] if rounded_v1 < rounded_v2 else "%s-%s" % [rounded_v2, rounded_v1]

# Public API for modification
func modify_terrain(position: Vector3, radius: float, type: String = "remove", strength: float = 1.0):
	# Add to modified regions
	modified_regions[position] = {
		"radius": radius,
		"type": type,
		"strength": strength
	}
	
	# Mark affected chunks as dirty
	var affected_chunks = get_chunks_in_radius(position, radius)
	for chunk_pos in affected_chunks:
		if chunk_pos in chunks:
			chunks[chunk_pos].is_dirty = true
			
			# Ensure the chunk is in the update queue
			if not chunk_pos in chunks_to_update:
				chunks_to_update.append(chunk_pos)

func get_chunks_in_radius(position: Vector3, radius: float) -> Array:
	var affected_chunks = []
	
	# Calculate chunk positions that could be affected
	var min_chunk = world_to_chunk(position - Vector3(radius, radius, radius))
	var max_chunk = world_to_chunk(position + Vector3(radius, radius, radius))
	
	for x in range(min_chunk.x, max_chunk.x + 1):
		for y in range(min_chunk.y, max_chunk.y + 1):
			for z in range(min_chunk.z, max_chunk.z + 1):
				var chunk_pos = Vector3i(x, y, z)
				if chunk_pos in chunks:
					affected_chunks.append(chunk_pos)
	
	return affected_chunks

func world_to_chunk(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floor(world_pos.x / (chunk_size * voxel_size)),
		floor(world_pos.y / (chunk_size * voxel_size)),
		floor(world_pos.z / (chunk_size * voxel_size))
	)

# LOD system
func update_chunk_lod(chunk: VoxelChunk, player_position: Vector3):
	if not use_lod:
		chunk.lod_level = 0
		return
		
	# Calculate distance to player
	var chunk_center = chunk.world_position + Vector3(chunk_size * voxel_size * 0.5, chunk_size * voxel_size * 0.5, chunk_size * voxel_size * 0.5)
	var distance = chunk_center.distance_to(player_position)
	
	# Calculate LOD level based on distance
	var new_lod_level = int(clamp(floor(distance / (chunk_size * voxel_size * 2)), 0, max_lod_levels - 1))
	
	# If LOD changed, mark for update
	if new_lod_level != chunk.lod_level:
		chunk.lod_level = new_lod_level
		chunk.is_dirty = true
		
		if not chunk.position in chunks_to_update:
			chunks_to_update.append(chunk.position)

# User input handlers
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_0:
			# Regenerate all chunks
			for chunk_pos in chunks:
				chunks[chunk_pos].is_dirty = true
				if not chunk_pos in chunks_to_update:
					chunks_to_update.append(chunk_pos)
		elif event.keycode == KEY_9:
			# Reset modifications
			modified_regions.clear()
			for chunk_pos in chunks:
				chunks[chunk_pos].is_dirty = true
				if not chunk_pos in chunks_to_update:
					chunks_to_update.append(chunk_pos)
