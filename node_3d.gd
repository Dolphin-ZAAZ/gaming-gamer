extends Node3D


func _ready():
	var chunk = SmoothVoxelChunk.new(Vector3(0, 0, 0))
	add_child(chunk)
	chunk.update_mesh_and_collider_sync()
	print("Scene setup complete")
