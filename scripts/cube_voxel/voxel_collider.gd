extends Resource

class_name VoxelCollider

func generate_collider(voxel_data: VoxelChunk) -> StaticBody3D:
	# Create a StaticBody3D to hold the CollisionShape3D
	var static_body = StaticBody3D.new()

	# Create a new ConcavePolygonShape3D
	var shape = ConcavePolygonShape3D.new()
	var shape_data = []

	for x in range(voxel_data.CHUNK_SIZE):
		for y in range(voxel_data.CHUNK_SIZE):
			for z in range(voxel_data.CHUNK_SIZE):
				var voxel = voxel_data.get_voxel(x, y, z)
				if voxel.type != Voxel.VoxelType.EMPTY:
					var voxel_shape = create_voxel_shape(voxel.position)
					shape_data.append_array(voxel_shape)

	# Assign the collected shape data to the shape
	shape.data = shape_data

	# Create a new CollisionShape3D and set its shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	return static_body

func create_voxel_shape(position: Vector3) -> PackedVector3Array:
	var size = 0.5
	var vertices = PackedVector3Array()

	vertices.append(Vector3(position.x - size, position.y - size, position.z - size))
	vertices.append(Vector3(position.x + size, position.y - size, position.z - size))
	vertices.append(Vector3(position.x + size, position.y + size, position.z - size))
	vertices.append(Vector3(position.x - size, position.y + size, position.z - size))

	vertices.append(Vector3(position.x - size, position.y - size, position.z + size))
	vertices.append(Vector3(position.x + size, position.y - size, position.z + size))
	vertices.append(Vector3(position.x + size, position.y + size, position.z + size))
	vertices.append(Vector3(position.x - size, position.y + size, position.z + size))

	var indices = PackedInt32Array([
		0, 1, 2, 0, 2, 3,  # Front face
		4, 5, 6, 4, 6, 7,  # Back face
		0, 1, 5, 0, 5, 4,  # Bottom face
		2, 3, 7, 2, 7, 6,  # Top face
		0, 3, 7, 0, 7, 4,  # Left face
		1, 2, 6, 1, 6, 5   # Right face
	])

	var result = PackedVector3Array()

	for i in range(indices.size()):
		result.append(vertices[indices[i]])

	return result
