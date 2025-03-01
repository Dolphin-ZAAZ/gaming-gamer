class_name VoxelManager
extends Node3D

# References
@onready var marching_cubes: ChunkedMarchingCubes = $ChunkedMarchingCubes

# Configuration
@export var update_player_chunks: bool = true
@export var player_path: NodePath

# Player cache
var player: Node3D
var player_chunk: Vector3i = Vector3i.ZERO
var last_player_chunk: Vector3i = Vector3i.ZERO

# Queue for processing with thread safety
var modification_queue: Array = []
var worker_semaphore: Semaphore
var worker_mutex: Mutex
var worker_thread: Thread
var exit_thread: bool = false

func _ready():
	if player_path:
		player = get_node_or_null(player_path)
	
	# Initialize threading resources
	worker_semaphore = Semaphore.new()
	worker_mutex = Mutex.new()
	
	# Start worker thread for terrain modifications
	if marching_cubes.multithreaded:
		worker_thread = Thread.new()
		worker_thread.start(worker_function)

func _process(delta):
	if update_player_chunks and player:
		update_player_position()
	
	# Process modification queue in main thread if not multithreaded
	if not marching_cubes.multithreaded:
		process_modification_queue()

func _exit_tree():
	# Clean up threading resources
	if marching_cubes.multithreaded and worker_thread and worker_thread.is_active():
		exit_thread = true
		worker_semaphore.post()  # Wake up the thread
		worker_thread.wait_to_finish()

# Worker thread function
func worker_function():
	while true:
		worker_semaphore.wait()  # Wait until there's work to do
		
		if exit_thread:
			break
			
		process_modification_queue()

# Process modifications from queue
func process_modification_queue():
	worker_mutex.lock()
	var queue_copy = modification_queue.duplicate()
	modification_queue.clear()
	worker_mutex.unlock()
	
	for modification in queue_copy:
		apply_modification(modification)

# Apply a terrain modification
func apply_modification(modification: Dictionary):
	var position = modification.position
	var radius = modification.radius
	var type = modification.type
	var strength = modification.strength
	
	# Call to the ChunkedMarchingCubes system
	marching_cubes.modify_terrain(position, radius, type, strength)

# Queue a terrain modification to be processed
func queue_modification(position: Vector3, radius: float, type: String = "remove", strength: float = 1.0):
	var modification = {
		"position": position,
		"radius": radius,
		"type": type,
		"strength": strength
	}
	
	worker_mutex.lock()
	modification_queue.append(modification)
	worker_mutex.unlock()
	
	# Signal the worker thread
	if marching_cubes.multithreaded:
		worker_semaphore.post()

# Update player position and generate/update chunks around player
func update_player_position():
	if not player:
		return
		
	var new_player_chunk = marching_cubes.world_to_chunk(player.global_position)
	
	# Skip if player hasn't moved to a new chunk
	if new_player_chunk == player_chunk:
		return
		
	player_chunk = new_player_chunk
	
	# Generate new chunks if needed
	marching_cubes.generate_chunks_around(player_chunk)
	
	# Update LOD for all chunks based on player position
	for chunk_pos in marching_cubes.chunks:
		marching_cubes.update_chunk_lod(marching_cubes.chunks[chunk_pos], player.global_position)

# Public mining API
func mine(position: Vector3, radius: float, strength: float = 1.0):
	queue_modification(position, radius, "remove", strength)

# Public addition API
func add(position: Vector3, radius: float, strength: float = 1.0):
	queue_modification(position, radius, "add", strength)
