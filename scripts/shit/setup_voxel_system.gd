@tool
extends EditorScript

# This script helps set up the voxel system in your project
# Run it from the Godot Editor (Script > Run)

func _run():
	print("Setting up Voxel Terrain System...")
	
	# Check if required files exist
	var files_to_check = [
		"VoxelChunk.gd",
		"MeshData.gd",
		"ChunkedMarchingCubes.gd",
		"VoxelManager.gd",
		"LODSystem.gd",
		"TerrainEditor.gd",
		"TerrainEditorScene.tscn"
	]
	
	var missing_files = []
	var script_dir = get_script().resource_path.get_base_dir()
	
	for file in files_to_check:
		var file_path = script_dir.path_join(file)
		if not FileAccess.file_exists(file_path):
			missing_files.append(file)
	
	if missing_files.size() > 0:
		push_error("Missing required files: " + str(missing_files))
		return
	
	print("All required files found!")
	
	# Create a test scene if user wants
	var dialog = ConfirmationDialog.new()
	dialog.title = "Voxel System Setup"
	dialog.dialog_text = "Do you want to create a test scene with the voxel terrain system?"
	dialog.get_ok_button().text = "Yes"
	dialog.get_cancel_button().text = "No"
	
	var editor_interface = get_editor_interface()
	editor_interface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	
	dialog.connect("confirmed", func():
		create_test_scene(script_dir)
		dialog.queue_free()
	)
	
	dialog.connect("canceled", func():
		print("Setup completed without creating a test scene.")
		print("You can add the TerrainEditorScene.tscn to your project manually.")
		dialog.queue_free()
	)

func create_test_scene(script_dir: String):
	print("Creating test scene...")
	
	# Load the terrain editor scene
	var terrain_scene_path = script_dir.path_join("TerrainEditorScene.tscn")
	var terrain_scene = load(terrain_scene_path)
	
	if not terrain_scene:
		push_error("Failed to load TerrainEditorScene.tscn")
		return
	
	# Create a new scene with the terrain editor
	var new_scene = Node3D.new()
	new_scene.name = "VoxelTerrainTest"
	
	var terrain_instance = terrain_scene.instantiate()
	new_scene.add_child(terrain_instance)
	terrain_instance.owner = new_scene
	
	# Save the scene
	var new_scene_path = "res://VoxelTerrainTest.tscn"
	var packed_scene = PackedScene.new()
	packed_scene.pack(new_scene)
	
	var result = ResourceSaver.save(packed_scene, new_scene_path)
	if result != OK:
		push_error("Failed to save test scene: " + str(result))
		return
	
	print("Test scene created at: " + new_scene_path)
	print("Open and run this scene to test the voxel terrain system.")
	
	# Attempt to open the scene in the editor
	var editor_interface = get_editor_interface()
	editor_interface.open_scene_from_path(new_scene_path)
	
	# Clean up
	new_scene.free()
