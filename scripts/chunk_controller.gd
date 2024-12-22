extends Node3D

const CHUNK_SIZE = 16
const RENDER_DISTANCE = 3

var chunks: Dictionary = {}
var player: Node3D

func _ready():
	player = $"../Player"
	_update_chunks()

func _process(delta):
	pass
	#_update_chunks()

func _update_chunks():
	var player_chunk_position = Vector3(
		int(player.global_transform.origin.x / CHUNK_SIZE),
		0,
		int(player.global_transform.origin.z / CHUNK_SIZE)
	)

	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			var chunk_position = Vector3(player_chunk_position.x + x, 0, player_chunk_position.z + z)
			if !chunks.has(chunk_position):
				_load_chunk(chunk_position)

	_unload_distant_chunks(player_chunk_position)

func _load_chunk(position: Vector3):
	var chunk = VoxelChunk.new()
	chunk.position = position * CHUNK_SIZE
	chunk.generate_terrain()
	add_child(chunk)
	chunks[position] = chunk

func _unload_distant_chunks(player_chunk_position: Vector3):
	var keys = chunks.keys()
	for key in keys:
		if abs(player_chunk_position.x - key.x) > RENDER_DISTANCE or abs(player_chunk_position.z - key.z) > RENDER_DISTANCE:
			var chunk = chunks[key]
			remove_child(chunk)
			chunks.erase(key)
