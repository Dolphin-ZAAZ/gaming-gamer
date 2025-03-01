class_name LODSystem
extends RefCounted

# LOD configuration
var max_lod_levels: int = 4
var lod_distance_thresholds: Array[float] = [32.0, 64.0, 128.0, 256.0]
var simplification_ratios: Array[float] = [1.0, 0.5, 0.25, 0.125]

# Initialize with configuration
func _init(levels: int = 4):
	max_lod_levels = levels
	lod_distance_thresholds.resize(levels)
	simplification_ratios.resize(levels)
	
	# Set default values
	for i in range(levels):
		lod_distance_thresholds[i] = 32.0 * pow(2, i)
		simplification_ratios[i] = 1.0 / pow(2, i)

# Simplified mesh LOD implementation
# Uses vertex skipping rather than full mesh decimation for real-time performance
func create_simplified_mesh(mesh_data: MeshData, lod_level: int) -> MeshData:
	if lod_level <= 0 or mesh_data.vertices.size() == 0:
		return mesh_data
	
	var ratio = get_simplification_ratio(lod_level)
	if ratio >= 1.0:
		return mesh_data
	
	var simplified = MeshData.new()
	var grid_size = pow(2, lod_level)
	
	# Calculate bounding box for spatial grid
	var min_bounds = Vector3(INF, INF, INF)
	var max_bounds = Vector3(-INF, -INF, -INF)
	
	for i in range(mesh_data.vertices.size()):
		var v = mesh_data.vertices[i]
		min_bounds.x = min(min_bounds.x, v.x)
		min_bounds.y = min(min_bounds.y, v.y)
		min_bounds.z = min(min_bounds.z, v.z)
		max_bounds.x = max(max_bounds.x, v.x)
		max_bounds.y = max(max_bounds.y, v.y)
		max_bounds.z = max(max_bounds.z, v.z)
	
	# Cell size for spatial grid
	var cell_size = (max_bounds - min_bounds) / grid_size
	
	# Map from cell to representative vertex
	var cell_vertices = {}
	var vertex_mapping = {}
	
	# First pass: assign vertices to cells
	for i in range(mesh_data.vertices.size()):
		var v = mesh_data.vertices[i]
		var cell_x = int((v.x - min_bounds.x) / cell_size.x)
		var cell_y = int((v.y - min_bounds.y) / cell_size.y)
		var cell_z = int((v.z - min_bounds.z) / cell_size.z)
		
		var cell_key = Vector3i(cell_x, cell_y, cell_z)
		
		if not cell_key in cell_vertices:
			# First vertex in this cell becomes the representative
			cell_vertices[cell_key] = {
				"index": simplified.vertices.size(),
				"position": v,
				"normal": mesh_data.normals[i],
				"count": 1
			}
			
			# Add to simplified mesh
			simplified.vertices.append(v)
			simplified.normals.append(mesh_data.normals[i])
			
			if i < mesh_data.colors.size():
				simplified.colors.append(mesh_data.colors[i])
			else:
				simplified.colors.append(Color.WHITE)
		else:
			# Average normals for better quality
			var cell = cell_vertices[cell_key]
			cell.normal = (cell.normal * cell.count + mesh_data.normals[i]) / (cell.count + 1)
			cell.count += 1
			
			# Update the normal in the simplified mesh
			simplified.normals[cell.index] = cell.normal
		
		# Map original vertex to cell representative
		vertex_mapping[i] = cell_vertices[cell_key].index
	
	# Second pass: rebuild indices
	for i in range(0, mesh_data.indices.size(), 3):
		if i + 2 < mesh_data.indices.size():
			var i1 = mesh_data.indices[i]
			var i2 = mesh_data.indices[i+1]
			var i3 = mesh_data.indices[i+2]
			
			# Get mapped indices
			var m1 = vertex_mapping[i1]
			var m2 = vertex_mapping[i2]
			var m3 = vertex_mapping[i3]
			
			# Skip degenerate triangles
			if m1 != m2 and m2 != m3 and m3 != m1:
				simplified.indices.append(m1)
				simplified.indices.append(m2)
				simplified.indices.append(m3)
	
	return simplified

# Get appropriate LOD level based on distance
func get_lod_level(distance: float) -> int:
	for i in range(lod_distance_thresholds.size()):
		if distance <= lod_distance_thresholds[i]:
			return i
	return lod_distance_thresholds.size() - 1

# Calculate simplification ratio for a given LOD level
func get_simplification_ratio(lod_level: int) -> float:
	if lod_level < 0 or lod_level >= simplification_ratios.size():
		return 1.0
	return simplification_ratios[lod_level]
