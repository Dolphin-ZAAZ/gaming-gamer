class_name TerrainEditor
extends Node3D

# References
@onready var voxel_manager: VoxelManager = $VoxelManager
@onready var camera: Camera3D = $Camera
@onready var raycast: RayCast3D = $RayCast3D
@onready var edit_cursor: MeshInstance3D = $EditCursor
@onready var ui: Control = $UI

# Editor state
@export_category("Editor")
@export var edit_radius: float = 3.0
@export var edit_strength: float = 1.0
@export var camera_speed: float = 10.0
@export var camera_rotation_speed: float = 0.2
@export var edit_mode: String = "remove" # "remove" or "add"

# UI elements
@export_category("UI")
@export var radius_slider_path: NodePath
@export var strength_slider_path: NodePath
@export var mode_button_path: NodePath
@export var stats_label_path: NodePath

# State
var editing: bool = false
var camera_rotating: bool = false
var last_mouse_position: Vector2
var last_edit_position: Vector3
var edit_cooldown: float = 0.1
var time_since_last_edit: float = 0.0
var show_wireframe: bool = false

# Stats
var chunks_count: int = 0
var active_chunks: int = 0
var fps_history: Array[float] = []

func _ready():
	# Setup UI connections
	var radius_slider = get_node_or_null(radius_slider_path)
	var strength_slider = get_node_or_null(strength_slider_path)
	var mode_button = get_node_or_null(mode_button_path)
	
	if radius_slider:
		radius_slider.value = edit_radius
		radius_slider.connect("value_changed", _on_radius_changed)
	
	if strength_slider:
		strength_slider.value = edit_strength
		strength_slider.connect("value_changed", _on_strength_changed)
	
	if mode_button:
		mode_button.connect("pressed", _on_mode_toggled)
		mode_button.text = "Mode: " + edit_mode.capitalize()
	
	# Setup edit cursor
	update_cursor_mesh()
	
	# Set raycast target
	raycast.target_position = Vector3(0, 0, -100)
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	time_since_last_edit += delta
	update_camera(delta)
	update_raycast()
	update_editing(delta)
	update_stats(delta)

func _input(event):
	if event is InputEventMouseMotion:
		if camera_rotating:
			rotate_camera(event.relative)
		last_mouse_position = event.position
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			editing = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			camera_rotating = event.pressed
			
			if camera_rotating:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.keycode == KEY_TAB:
			show_wireframe = !show_wireframe
			toggle_wireframe(show_wireframe)
		elif event.keycode == KEY_SPACE:
			_on_mode_toggled()

func update_camera(delta):
	var input_dir = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1
	
	if input_dir.length_squared() > 0:
		input_dir = input_dir.normalized()
		
		# Movement is relative to camera orientation
		var cam_basis = camera.global_transform.basis
		var movement = cam_basis * (input_dir * camera_speed * delta)
		
		camera.global_position += movement
		# Update cursor position too
		edit_cursor.global_position = raycast.get_collision_point() if raycast.is_colliding() else camera.global_position + camera.global_transform.basis.z * -10

func rotate_camera(mouse_motion: Vector2):
	var motion = mouse_motion * camera_rotation_speed * 0.01
	camera.rotate_y(-motion.x)
	
	# Clamp vertical rotation to avoid flipping
	var current_rotation = camera.rotation_degrees.x
	var new_rotation = clamp(current_rotation + motion.y, -89, 89)
	camera.rotation_degrees.x = new_rotation

func update_raycast():
	raycast.global_position = camera.global_position
	raycast.global_rotation = camera.global_rotation
	
	if raycast.is_colliding():
		var point = raycast.get_collision_point()
		edit_cursor.global_position = point
		edit_cursor.visible = true
	else:
		# Position cursor at a fixed distance in front of camera
		edit_cursor.global_position = camera.global_position + camera.global_transform.basis.z * -10
		edit_cursor.visible = true

func update_editing(delta):
	if editing and time_since_last_edit >= edit_cooldown:
		if raycast.is_colliding():
			var edit_position = raycast.get_collision_point()
			
			# Don't edit the same position repeatedly
			if edit_position.distance_to(last_edit_position) > 0.1:
				if edit_mode == "remove":
					voxel_manager.mine(edit_position, edit_radius, edit_strength)
				else:
					voxel_manager.add(edit_position, edit_radius, edit_strength)
					
				last_edit_position = edit_position
				time_since_last_edit = 0.0

func update_cursor_mesh():
	# Create a sphere mesh for the cursor
	var sphere = SphereMesh.new()
	sphere.radius = edit_radius
	sphere.height = edit_radius * 2
	edit_cursor.mesh = sphere
	
	# Create semi-transparent material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.3, 0.3) if edit_mode == "remove" else Color(0.3, 1.0, 0.3, 0.3)
	material.flags_transparent = true
	edit_cursor.material_override = material

func update_stats(delta):
	fps_history.append(1.0/delta)
	if fps_history.size() > 60:
		fps_history.pop_front()
	
	var avg_fps = 0.0
	for fps in fps_history:
		avg_fps += fps
	avg_fps /= fps_history.size()
	
	chunks_count = voxel_manager.marching_cubes.chunks.size() if voxel_manager else 0
	active_chunks = voxel_manager.marching_cubes.active_chunks.size() if voxel_manager else 0
	
	var stats_label = get_node_or_null(stats_label_path)
	if stats_label:
		stats_label.text = "FPS: %.1f\nChunks: %d\nActive: %d\nRadius: %.1f\nStrength: %.1f\nMode: %s" % [
			avg_fps, chunks_count, active_chunks, edit_radius, edit_strength, edit_mode
		]

func toggle_wireframe(enabled: bool):
	var chunks = get_tree().get_nodes_in_group("voxel_chunks")
	for chunk in chunks:
		if chunk is MeshInstance3D:
			for i in range(chunk.get_surface_override_material_count()):
				var material = chunk.get_surface_override_material(i)
				if material:
					material.wireframe = enabled

# UI Signal handlers
func _on_radius_changed(value: float):
	edit_radius = value
	update_cursor_mesh()

func _on_strength_changed(value: float):
	edit_strength = value

func _on_mode_toggled():
	edit_mode = "add" if edit_mode == "remove" else "remove"
	update_cursor_mesh()
	
	var mode_button = get_node_or_null(mode_button_path)
	if mode_button:
		mode_button.text = "Mode: " + edit_mode.capitalize()
