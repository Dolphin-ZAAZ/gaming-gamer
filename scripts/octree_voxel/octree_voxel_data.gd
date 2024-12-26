extends Resource
class_name OctreeVoxelData

var root_node: OctreeNode
var size: int

class OctreeNode:
	var children: Array[OctreeNode]
	var density: float
	var is_leaf: bool
	var size: int
	var position: Vector3i

	func _init(pos: Vector3i, s: int):
		position = pos
		size = s
		is_leaf = true
		density = 1.0  # Default to solid
		children = []

	func subdivide():
		if not is_leaf:
			return
		is_leaf = false
		var half_size = size / 2
		for x in range(2):
			for y in range(2):
				for z in range(2):
					var child_pos = position + Vector3i(x, y, z) * half_size
					children.append(OctreeNode.new(child_pos, half_size))

func _init(s: int = 16):
	size = s
	root_node = OctreeNode.new(Vector3i.ZERO, size)
	_generate_cube()
	
func _generate_cube():
	_recursive_generate(root_node)

func _recursive_generate(node: OctreeNode):
	if node.size == 1:
		# Set density based on position
		node.density = _calculate_density(node.position)
		return

	var has_different_densities = false
	var corner_densities = []

	# Check corners of the current node
	for x in [0, 1]:
		for y in [0, 1]:
			for z in [0, 1]:
				var corner_pos = node.position + Vector3i(x, y, z) * (node.size - 1)
				var density = _calculate_density(corner_pos)
				corner_densities.append(density)
				if density != corner_densities[0]:
					has_different_densities = true

	if has_different_densities:
		# If there are different densities, subdivide
		node.subdivide()
		for child in node.children:
			_recursive_generate(child)
	else:
		# If all densities are the same, set the node's density
		node.density = corner_densities[0]

func _calculate_density(pos: Vector3i) -> float:
	# Create a solid cube with only the outermost layer being air
	if pos.x == 0 or pos.x == size - 1 or \
	pos.y == 0 or pos.y == size - 1 or \
	pos.z == 0 or pos.z == size - 1:
		return -0.1  # Air (slightly negative for better marching cubes results)
	else:
		return 1.0  # Solid

func _is_on_border(node: OctreeNode) -> bool:
	return (
		node.position.x == 0 or node.position.x + node.size == size or
		node.position.y == 0 or node.position.y + node.size == size or
		node.position.z == 0 or node.position.z + node.size == size
	)

func get_density(x: int, y: int, z: int) -> float:
	return _recursive_get_density(root_node, Vector3i(x, y, z))

func _recursive_get_density(node: OctreeNode, pos: Vector3i) -> float:
	if node.is_leaf:
		return node.density

	var half_size = node.size / 2
	var child_index = (
		(1 if pos.x >= node.position.x + half_size else 0) |
		(2 if pos.y >= node.position.y + half_size else 0) |
		(4 if pos.z >= node.position.z + half_size else 0)
	)
	return _recursive_get_density(node.children[child_index], pos)

func set_density(x: int, y: int, z: int, density: float):
	_recursive_set_density(root_node, Vector3i(x, y, z), density)

func _recursive_set_density(node: OctreeNode, pos: Vector3i, density: float):
	if node.is_leaf:
		if node.size == 1:
			node.density = density
		else:
			node.subdivide()
			_recursive_set_density(node, pos, density)
		return

	var half_size = node.size / 2
	var child_index = (
		(1 if pos.x >= node.position.x + half_size else 0) |
		(2 if pos.y >= node.position.y + half_size else 0) |
		(4 if pos.z >= node.position.z + half_size else 0)
	)
	_recursive_set_density(node.children[child_index], pos, density)
