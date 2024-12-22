extends Node3D

# References to the classes
var voxel_data: VoxelData = VoxelData.new()
var voxel_mesh: VoxelMesh = VoxelMesh.new()
var voxel_collider: VoxelCollider = VoxelCollider.new()

func _ready():
	# Generate and add voxel mesh
	var mesh = voxel_mesh.generate_mesh(voxel_data)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	
	# Generate and add voxel collider
	var collider = voxel_collider.generate_collider(voxel_data)
	add_child(collider)
