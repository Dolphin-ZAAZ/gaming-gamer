extends Node3D


class_name SmoothVoxelChunk
var voxel_data
var mesh
var mesh_instance
var collider
var is_modified = false
var chunk_size = 16

func _init(size) -> void:
	chunk_size = size
	voxel_data = SmoothVoxelData.new(size)
	mesh = SmoothVoxelMesh.new()

func get_voxel_data():
	return voxel_data
	
func update_mesh_and_collider(extended_voxel_data):
	var new_mesh
	var new_collision_shape

	if is_modified:
		var marching_cubes_data = mesh.generate_marching_cubes_data(extended_voxel_data)
		new_mesh = mesh.generate_mesh(marching_cubes_data)
		new_collision_shape = mesh.generate_collider(marching_cubes_data)
	else:
		new_mesh = mesh.generate_simple_cube_mesh(chunk_size)
		new_collision_shape = mesh.generate_simple_cube_collider(chunk_size)

	call_deferred("_apply_mesh_and_collider", new_mesh, new_collision_shape)

func _apply_mesh_and_collider(new_mesh, new_collision_shape):
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	if not collider:
		collider = StaticBody3D.new()
		add_child(collider)

	mesh_instance.mesh = new_mesh
	
	# Disable shadows for simple cubes
	if not is_modified:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	for child in collider.get_children():
		collider.remove_child(child)
		child.queue_free()
	
	if new_collision_shape:
		collider.add_child(new_collision_shape)
