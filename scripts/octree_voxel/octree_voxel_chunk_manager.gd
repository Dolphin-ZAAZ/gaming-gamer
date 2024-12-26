extends Node3D

class_name OctreeVoxelTester

@export var chunk_size: int = 1024
@export var update_mesh: bool = false:
	set(value):
		update_mesh = value
		if value:
			_update_mesh()

var chunk: OctreeVoxelChunk

func _ready():
	_create_chunk()
	_update_mesh()

func _create_chunk():
	if chunk:
		remove_child(chunk)
		chunk.queue_free()
	
	chunk = OctreeVoxelChunk.new(chunk_size)
	add_child(chunk)

func _update_mesh():
	if chunk:
		chunk.update_mesh_and_collider()
		print("Mesh updated")

# Optional: Add a method to modify voxels for testing
func modify_voxel(x: int, y: int, z: int, new_density: float):
	if chunk:
		var voxel_data = chunk.get_voxel_data()
		voxel_data.set_density(x, y, z, new_density)
		_update_mesh()
		print("Voxel modified at (%d, %d, %d)" % [x, y, z])

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Modify a random voxel when spacebar is pressed
			var x = randi() % chunk_size
			var y = randi() % chunk_size
			var z = randi() % chunk_size
			var new_density = randf() * 2.0 - 1.0  # Random value between -1 and 1
			modify_voxel(x, y, z, new_density)
		elif event.keycode == KEY_R:
			# Regenerate the chunk when 'R' is pressed
			_create_chunk()
			_update_mesh()
