extends Node3D

class_name SmoothVoxelChunk
var voxel_data
var mesh
var mesh_instance
var collider 

func _init() -> void:
	voxel_data = SmoothVoxelData.new()
	mesh = SmoothVoxelMesh.new()

func get_voxel_data():
	return voxel_data
	
func update_mesh_and_collider(extended_voxel_data):
	var marching_cubes_data = mesh.generate_marching_cubes_data(extended_voxel_data)
	var new_mesh = mesh.generate_mesh(marching_cubes_data)
	var new_collision_shape = mesh.generate_collider(marching_cubes_data)
	
	call_deferred("_apply_mesh_and_collider", new_mesh, new_collision_shape)

func _apply_mesh_and_collider(new_mesh, new_collision_shape):
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	if not collider:
		collider = StaticBody3D.new()
		add_child(collider)

	mesh_instance.mesh = new_mesh
	
	for child in collider.get_children():
		collider.remove_child(child)
		child.queue_free()
	
	if new_collision_shape:
		collider.add_child(new_collision_shape)
