extends Resource

class_name Voxel

enum VoxelType {
	EMPTY,
	GRASS,
	DIRT,
	STONE
}


var type: VoxelType = VoxelType.EMPTY
var position: Vector3 = Vector3.ZERO

func _init(_type: VoxelType, _position: Vector3):
	type = _type
	position = _position
