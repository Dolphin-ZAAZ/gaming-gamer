extends Node3D

class_name SmoothVoxelChunk
var voxel_data
var mesh
var mesh_instance
var collider 

func _init() -> void:
	voxel_data = SmoothVoxelData.new(position)
	mesh = SmoothVoxelMesh.new()

func get_voxel_data():
	return voxel_data
	
func update_mesh_and_collider(voxel_data):
	# Remove and free the existing mesh instance if it exists
	if mesh_instance:
		remove_child(mesh_instance)
		mesh_instance.queue_free()
		mesh_instance = null
	# Remove and free the existing collider if it exists
	if collider:
		remove_child(collider)
		collider.queue_free()
		collider = null

	var meshVoxel = mesh.generate_mesh(voxel_data)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = meshVoxel
	add_child(mesh_instance)
	
	collider = SmoothVoxelCollider.new().generate_collider(voxel_data)
	add_child(collider)
	return mesh
