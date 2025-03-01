class_name FirstPersonController
extends CharacterBody3D

# Movement parameters
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_strength: float = 5.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.2
@export var fly_mode: bool = true
@export var fly_speed: float = 10.0
@export var fly_acceleration: float = 5.0

# Camera control
@export var camera_path: NodePath
@export var head_path: NodePath

# Terrain editor functionality
@export var mine_on_left_click: bool = true
@export var add_on_right_click: bool = true
@export var edit_radius: float = 3.0
@export var edit_strength: float = 1.0

# References
@onready var camera: Camera3D = get_node(camera_path) if camera_path else $Camera3D
@onready var head: Node3D = get_node(head_path) if head_path else $Head
@onready var raycast: RayCast3D = $Head/RayCast3D if has_node("Head/RayCast3D") else null
@onready var edit_cursor: MeshInstance3D = $EditCursor

# State tracking
var camera_rotation: Vector2 = Vector2.ZERO
var gravity_vector: Vector3 = Vector3.DOWN
var movement_vector: Vector3 = Vector3.ZERO
var is_sprinting: bool = false
var voxel_manager: VoxelManager = null

func _ready():
	# Find the VoxelManager in the scene
	voxel_manager = find_voxel_manager()
	
	# Setup edit cursor
	if edit_cursor:
		update_cursor_mesh()
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion = event.relative * mouse_sensitivity * 0.001
		camera_rotation.x -= mouse_motion.y
		camera_rotation.y -= mouse_motion.x
		
		# Clamp vertical rotation to avoid flipping
		camera_rotation.x = clamp(camera_rotation.x, -1.5, 1.5)
		
		# Apply rotation
		head.rotation.x = camera_rotation.x
		rotation.y = camera_rotation.y
	
	# Mouse button actions
	if event is InputEventMouseButton and event.pressed:
		if raycast and raycast.is_colliding() and voxel_manager:
			var hit_position = raycast.get_collision_point()
			
			# Left click - mine/remove
			if event.button_index == MOUSE_BUTTON_LEFT and mine_on_left_click:
				voxel_manager.mine(hit_position, edit_radius, edit_strength)
			
			# Right click - add
			elif event.button_index == MOUSE_BUTTON_RIGHT and add_on_right_click:
				voxel_manager.add(hit_position, edit_radius, edit_strength)
	
	# Toggle mouse mode
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Toggle fly mode
		elif event.keycode == KEY_F:
			fly_mode = !fly_mode
			
		# Adjust edit radius
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			edit_radius += 0.5
			update_cursor_mesh()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			edit_radius = max(0.5, edit_radius - 0.5)
			update_cursor_mesh()
			
		# Adjust edit strength
		elif event.keycode == KEY_BRACKETRIGHT:
			edit_strength += 0.25
		elif event.keycode == KEY_BRACKETLEFT:
			edit_strength = max(0.25, edit_strength - 0.25)

func _physics_process(delta):
	# Handle movement
	if fly_mode:
		process_fly_movement(delta)
	else:
		process_walk_movement(delta)
	
	# Update raycast and edit cursor
	if raycast:
		update_raycast()

func process_walk_movement(delta):
	# Get movement input
	var input_dir = get_movement_input()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_strength
	
	# Determine speed
	is_sprinting = Input.is_action_pressed("ui_cancel")  # Using ESC as sprint for now
	var speed = sprint_speed if is_sprinting else walk_speed
	
	# Apply horizontal movement
	var horizontal_velocity = input_dir * speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	move_and_slide()

func process_fly_movement(delta):
	# Get movement input
	var input_dir = get_movement_input()
	
	# Add vertical movement in fly mode
	if Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_CTRL):
		input_dir.y -= 1
	
	# Normalize if necessary
	if input_dir.length_squared() > 1:
		input_dir = input_dir.normalized()
	
	# Determine speed
	is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	var target_speed = sprint_speed if is_sprinting else fly_speed
	
	# Convert input to global space
	var global_dir = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	global_dir.y = input_dir.y
	
	# Smoothly interpolate to target velocity
	var target_velocity = global_dir * target_speed
	velocity = velocity.lerp(target_velocity, fly_acceleration * delta)
	
	move_and_slide()

func get_movement_input() -> Vector3:
	var input_dir = Vector3.ZERO
	
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	return input_dir.normalized() if input_dir.length_squared() > 0 else input_dir

func update_raycast():
	if not raycast:
		return
		
	if raycast.is_colliding():
		var hit_position = raycast.get_collision_point()
		if edit_cursor:
			edit_cursor.global_position = hit_position
			edit_cursor.visible = true
	else:
		# Position cursor at a fixed distance in front of camera if no collision
		if edit_cursor:
			edit_cursor.global_position = camera.global_position + (-camera.global_transform.basis.z * 5)
			edit_cursor.visible = true

func find_voxel_manager() -> VoxelManager:
	# Try to find in parent hierarchy first
	var current_node = get_parent()
	while current_node:
		if current_node is VoxelManager:
			return current_node
			
		# Check if any direct children of this node are VoxelManager
		for child in current_node.get_children():
			if child is VoxelManager:
				return child
				
		current_node = current_node.get_parent()
	
	# If not found in parent hierarchy, search the entire scene
	var root = get_tree().root
	return find_voxel_manager_in_children(root)

func find_voxel_manager_in_children(node: Node) -> VoxelManager:
	if node is VoxelManager:
		return node
		
	for child in node.get_children():
		var result = find_voxel_manager_in_children(child)
		if result:
			return result
			
	return null

func update_cursor_mesh():
	if not edit_cursor:
		return
		
	# Create a sphere mesh for the cursor
	var sphere = SphereMesh.new()
	sphere.radius = edit_radius
	sphere.height = edit_radius * 2
	edit_cursor.mesh = sphere
	
	# Create semi-transparent material
	var material = StandardMaterial3D.new()
	
	# Red for mining, green for adding
	if mine_on_left_click:
		material.albedo_color = Color(1.0, 0.3, 0.3, 0.3)
	else:
		material.albedo_color = Color(0.3, 1.0, 0.3, 0.3)
		
	material.flags_transparent = true
	edit_cursor.material_override = material
