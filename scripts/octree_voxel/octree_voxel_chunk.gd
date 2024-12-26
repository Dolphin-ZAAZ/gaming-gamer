extends Node3D
class_name OctreeVoxelChunk

var voxel_data: OctreeVoxelData
var mesh: OctreeVoxelMesh
var mesh_instance: MeshInstance3D
var collider: StaticBody3D

func _init(size: int) -> void:
	voxel_data = OctreeVoxelData.new(size)
	mesh = OctreeVoxelMesh.new()

func get_voxel_data() -> OctreeVoxelData:
	return voxel_data

func update_mesh_and_collider():
	var marching_cubes_data = mesh.generate_marching_cubes_data(voxel_data)
	var new_mesh = mesh.generate_mesh(marching_cubes_data)
	var new_collision_shape = mesh.generate_collider(marching_cubes_data)
	
	call_deferred("_apply_mesh_and_collider", new_mesh, new_collision_shape)

func _apply_mesh_and_collider(new_mesh: Mesh, new_collision_shape: StaticBody3D):
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
