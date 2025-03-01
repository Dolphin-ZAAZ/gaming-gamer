extends Control

# Track UI references
@onready var info_label = $InfoLabel
@onready var edit_info = $EditInfo
@onready var fps_counter = $FPSCounter

# Player reference
var player: FirstPersonController
var voxel_manager: VoxelManager

# Performance tracking
var fps_history: Array[float] = []

func _ready():
	# Find the FirstPersonController in the scene
	player = find_first_person_controller()
	voxel_manager = find_voxel_manager()
	
	# Connect to timer for periodic updates
	var timer = Timer.new()
	timer.wait_time = 0.2  # Update 5 times per second
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", _on_update_timer)

func _process(delta):
	# Update FPS counter every frame
	var current_fps = 1.0 / delta
	fps_history.append(current_fps)
	
	# Keep history to last 30 frames
	if fps_history.size() > 30:
		fps_history.pop_front()
	
	# Calculate average FPS
	var avg_fps = 0.0
	for fps in fps_history:
		avg_fps += fps
	avg_fps /= fps_history.size()
	
	# Update counter
	if fps_counter:
		fps_counter.text = "FPS: %.1f" % avg_fps
		
		# Add chunks info if available
		if voxel_manager and voxel_manager.marching_cubes:
			var chunks_count = voxel_manager.marching_cubes.chunks.size()
			var active_chunks = voxel_manager.marching_cubes.active_chunks.size()
			var dirty_chunks = voxel_manager.marching_cubes.chunks_to_update.size()
			
			fps_counter.text += "\nChunks: %d\nActive: %d\nDirty: %d" % [
				chunks_count,
				active_chunks,
				dirty_chunks
			]

func _on_update_timer():
	if player:
		update_edit_info()

func update_edit_info():
	var mode_text = "Remove (Left click)" if player.mine_on_left_click else "Add (Right click)"
	var fly_text = "Enabled" if player.fly_mode else "Disabled"
	
	edit_info.text = "Edit Radius: %.1f\nEdit Strength: %.2f\nMode: %s\nFly Mode: %s" % [
		player.edit_radius,
		player.edit_strength,
		mode_text,
		fly_text
	]

func find_first_person_controller() -> FirstPersonController:
	# Try to find in scene
	var nodes = get_tree().get_nodes_in_group("player")
	for node in nodes:
		if node is FirstPersonController:
			return node
	
	# If not in group, search through all nodes
	var root = get_tree().root
	return find_controller_in_children(root)

func find_controller_in_children(node: Node) -> FirstPersonController:
	if node is FirstPersonController:
		return node
		
	for child in node.get_children():
		var result = find_controller_in_children(child)
		if result:
			return result
			
	return null
	
func find_voxel_manager() -> VoxelManager:
	# Try to find in scene
	var nodes = get_tree().get_nodes_in_group("voxel_manager")
	for node in nodes:
		if node is VoxelManager:
			return node
	
	# Check direct children of root
	for child in get_tree().root.get_children():
		if child is VoxelManager:
			return child
		
		# Check one level down
		for grandchild in child.get_children():
			if grandchild is VoxelManager:
				return grandchild
				
	return null
