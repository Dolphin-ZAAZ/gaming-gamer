extends Resource

class_name VoxelMesh

func generate_mesh(voxel_data: VoxelChunk) -> Mesh:
	var mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(voxel_data.CHUNK_SIZE):
		for y in range(voxel_data.CHUNK_SIZE):
			for z in range(voxel_data.CHUNK_SIZE):
				var voxel = voxel_data.get_voxel(x, y, z)
				if voxel.type != Voxel.VoxelType.EMPTY:
					var voxel_color = Color(1, 1, 1)
					if voxel.type == Voxel.VoxelType.GRASS:
						voxel_color = Color(0, 1, 0)
					elif voxel.type == Voxel.VoxelType.DIRT:
						voxel_color = Color(0.5, 0.25, 0)
					elif voxel.type == Voxel.VoxelType.STONE:
						voxel_color = Color(0.5, 0.5, 0.5)
					
					add_voxel_to_mesh(surface_tool, voxel.position, voxel_color)
					
	surface_tool.index()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())
	return mesh

func add_voxel_to_mesh(st: SurfaceTool, position: Vector3, color: Color):
	var size = 0.5

	# Define the six faces of the cube with vertices in clockwise order
	var faces = [
		[[Vector3(-size, -size, -size), Vector3(size, -size, -size), Vector3(size, size, -size), Vector3(-size, size, -size)], Vector3(0, 0, -1)],
		[[Vector3(-size, -size, size), Vector3(size, -size, size), Vector3(size, size, size), Vector3(-size, size, size)], Vector3(0, 0, 1)],
		[[Vector3(-size, -size, -size), Vector3(-size, -size, size), Vector3(-size, size, size), Vector3(-size, size, -size)], Vector3(-1, 0, 0)],
		[[Vector3(size, -size, -size), Vector3(size, -size, size), Vector3(size, size, size), Vector3(size, size, -size)], Vector3(1, 0, 0)],
		[[Vector3(-size, -size, -size), Vector3(size, -size, -size), Vector3(size, -size, size), Vector3(-size, -size, size)], Vector3(0, -1, 0)],
		[[Vector3(-size, size, -size), Vector3(size, size, -size), Vector3(size, size, size), Vector3(-size, size, size)], Vector3(0, 1, 0)]
	]

	for face in faces:
		var vertices = face[0]
		var normal = face[1]

		# Define the two triangles for each face in clockwise order
		# First triangle
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[0] + position)

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[1] + position)

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[2] + position)

		# Second triangle
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[2] + position)

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[3] + position)

		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertices[0] + position)
		
		# First triangle (opposite face)
		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[0] + position)

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[3] + position)

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[2] + position)

		# Second triangle (opposite face)
		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[2] + position)

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[1] + position)

		st.set_color(color)
		st.set_normal(-normal)
		st.add_vertex(vertices[0] + position)
