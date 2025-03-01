# OctreeChunk.gd

extends Node3D
class_name OctreeChunk

var parent_octree: AdaptiveMarchingCubes
var chunk_key: String
var chunk_origin: Vector3

const CHUNK_SIZE = 16

# Mesh and collider references
var mesh_instance: MeshInstance3D
var collider: StaticBody3D

# Packed arrays for mesh data
var vertices = PackedVector3Array()
var normals = PackedVector3Array()

# Initialize
func _init(parent, key, origin):
	parent_octree = parent
	chunk_key = key
	chunk_origin = origin

# Function to generate adaptive volume (placeholder)
func generate_adaptive_volume():
	# Implement your adaptive volume generation here
	# This could involve setting densities, subdividing the octree within the chunk, etc.
	pass

# Function to generate mesh and collider for this chunk
func update_mesh_and_collider():
	# Clear previous mesh data
	vertices.clear()
	normals.clear()
	
	# Generate mesh data using marching cubes
	var marching_cubes_data = parent_octree.generate_marching_cubes_data_for_chunk(self)
	vertices.append_array(marching_cubes_data[0])
	normals.append_array(marching_cubes_data[1])
	
	# Create the mesh
	var mesh = parent_octree.generate_mesh_from_data(vertices, normals)
	
	# Apply the mesh to the MeshInstance
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	mesh_instance.mesh = mesh
	
	# Handle shadows based on modification status
	if parent_octree.is_modified:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Create or update the collider
	if not collider:
		collider = StaticBody3D.new()
		add_child(collider)
	
	# Remove existing collision shapes
	for child in collider.get_children():
		collider.remove_child(child)
		child.queue_free()
	
	# Generate new collider
	var collision_shape = parent_octree.generate_collider_from_data(marching_cubes_data[0])
	collider.add_child(collision_shape)
