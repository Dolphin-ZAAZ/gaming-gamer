class_name VoxelChunk
extends RefCounted

# Chunk coordinates and properties
var position: Vector3i  # Position in chunk-space
var size: int  # Size in voxels (cubic chunk)
var voxel_size: float  # Size of each voxel in world units
var world_position: Vector3:
	get: return Vector3(position * (size * voxel_size))

# Voxel data storage
var density_values: PackedFloat32Array
var is_dirty: bool = true
var has_surface: bool = false
var is_active: bool = false

# Mesh data 
var mesh_data: MeshData = null
var lod_level: int = 0

# Cached data for quick lookups
var corners_cache: Dictionary = {}
var edge_vertices_cache: Dictionary = {}

# Neighboring chunks for seamless meshing
var neighbors: Dictionary = {}

func _init(chunk_position: Vector3i, chunk_size: int, voxel_unit_size: float):
	position = chunk_position
	size = chunk_size
	voxel_size = voxel_unit_size
	
	# Initialize density values to -1.0 (outside surface)
	density_values = PackedFloat32Array()
	density_values.resize(size * size * size)
	density_values.fill(-1.0)
	
	mesh_data = MeshData.new()

# Gets index into the density array from local x,y,z coordinates
func get_voxel_index(x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or z < 0 or x >= size or y >= size or z >= size:
		return -1
	return x + y * size + z * size * size

# Get density value at the specified local coordinates
func get_density(x: int, y: int, z: int) -> float:
	var idx = get_voxel_index(x, y, z)
	if idx >= 0:
		return density_values[idx]
	
	# If outside chunk bounds, check neighbor chunks
	var nx = position.x
	var ny = position.y
	var nz = position.z
	
	if x < 0:
		nx -= 1
		x += size
	elif x >= size:
		nx += 1
		x -= size
	
	if y < 0:
		ny -= 1
		y += size
	elif y >= size:
		ny += 1
		y -= size
	
	if z < 0:
		nz -= 1
		z += size
	elif z >= size:
		nz += 1
		z -= size
	
	var neighbor_key = Vector3i(nx, ny, nz)
	if neighbor_key in neighbors:
		return neighbors[neighbor_key].get_density(x, y, z)
	
	return -1.0  # Default to outside if no neighbor

# Set density value at the specified local coordinates
func set_density(x: int, y: int, z: int, value: float) -> void:
	var idx = get_voxel_index(x, y, z)
	if idx >= 0:
		if density_values[idx] != value:
			density_values[idx] = value
			is_dirty = true
	else:
		# If outside chunk bounds, delegate to appropriate neighbor
		var nx = position.x
		var ny = position.y
		var nz = position.z
		
		if x < 0:
			nx -= 1
			x += size
		elif x >= size:
			nx += 1
			x -= size
		
		if y < 0:
			ny -= 1
			y += size
		elif y >= size:
			ny += 1
			y -= size
		
		if z < 0:
			nz -= 1
			z += size
		elif z >= size:
			nz += 1
			z -= size
		
		var neighbor_key = Vector3i(nx, ny, nz)
		if neighbor_key in neighbors:
			neighbors[neighbor_key].set_density(x, y, z, value)

# Get local position from voxel coordinates
func get_voxel_position(x: int, y: int, z: int) -> Vector3:
	return Vector3(x, y, z) * voxel_size + world_position

# Get voxel coordinates from world position
func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local_pos = world_pos - world_position
	return Vector3i(
		floor(local_pos.x / voxel_size),
		floor(local_pos.y / voxel_size),
		floor(local_pos.z / voxel_size)
	)

# Check if this chunk contains or is near the surface
func update_surface_status(iso_level: float = 0.0) -> void:
	has_surface = false
	
	# Quick check: sample a few points to see if we're likely to have a surface
	for x in range(0, size, max(1, size/4)):
		for y in range(0, size, max(1, size/4)):
			for z in range(0, size, max(1, size/4)):
				var idx = get_voxel_index(x, y, z)
				if idx >= 0:
					if (x > 0 and x < size-1 and y > 0 and y < size-1 and z > 0 and z < size-1):
						# Interior voxel - check neighbors
						var idx_nx = get_voxel_index(x-1, y, z)
						var idx_px = get_voxel_index(x+1, y, z)
						
						if (density_values[idx] > iso_level and density_values[idx_nx] < iso_level) or \
						   (density_values[idx] < iso_level and density_values[idx_nx] > iso_level) or \
						   (density_values[idx] > iso_level and density_values[idx_px] < iso_level) or \
						   (density_values[idx] < iso_level and density_values[idx_px] > iso_level):
							has_surface = true
							return
	
	# If not found with quick check, do a more thorough check at chunk boundaries
	# For boundary checking with neighbors

# Calculate which edges of this chunk share the same density sign
func calculate_border_mask(iso_level: float = 0.0) -> int:
	var mask = 0
	
	# Check six faces (top, bottom, left, right, front, back)
	# Check if any face needs seamless connection with neighbors
	
	# Bottom face (y = 0)
	var all_same = true
	var last_sign = density_values[get_voxel_index(0, 0, 0)] > iso_level
	
	for z in range(size):
		for x in range(size):
			var sign = density_values[get_voxel_index(x, 0, z)] > iso_level
			if sign != last_sign:
				all_same = false
				break
		if not all_same:
			break
	
	if all_same:
		mask |= 1  # Set bit 0 for bottom face
	
	# Similarly check other faces...
	
	return mask

# Clear mesh data to prepare for regeneration
func clear_mesh_data() -> void:
	mesh_data.clear()
	corners_cache.clear()
	edge_vertices_cache.clear()
