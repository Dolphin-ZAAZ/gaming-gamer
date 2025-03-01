# Chunked Voxel Terrain System

A high-performance voxel terrain system for Godot 4, using marching cubes for smooth terrain and a chunked grid system for efficient memory usage and real-time editing.

## Features

- Chunked grid system for efficient memory management
- Optimized marching cubes implementation using `PackedArrays`
- Real-time terrain editing (add/remove)
- Level of Detail (LOD) system for distant chunks
- Multithreaded terrain operations
- Spatial hashing for quick chunk lookups
- Vertex merging and cache optimization
- Mesh data using direct PackedVector3Array for better performance
- Dirty flag system for minimal recomputation
- Complete editor UI for terrain manipulation
- First-person controller for interactive editing

## Getting Started

1. Add either the TerrainEditorScene.tscn (third-person editor) or FirstPersonEditorScene.tscn (first-person editor) to your project
2. Run the scene to enter the terrain editor
3. Use the controls to navigate and modify the terrain
4. Customize the terrain parameters in the Inspector

## Editor Options

The system includes two different editors:

### Third-Person Editor (TerrainEditorScene.tscn)
- Orbit-style camera controls
- UI sliders for precise control
- Good for designing terrain from a distance

### First-Person Editor (FirstPersonEditorScene.tscn)
- WASD movement with flying capability
- FPS-style mouse look
- Direct terrain modification with left/right mouse buttons
- Great for detailed work and testing player experience

## Usage in Your Game

### Basic Setup

```gdscript
# Create a VoxelManager
var voxel_manager = VoxelManager.new()
add_child(voxel_manager)

# Access the terrain generator
var marching_cubes = voxel_manager.marching_cubes

# Configure parameters
marching_cubes.chunk_size = 16
marching_cubes.voxel_size = 1.0
marching_cubes.world_size = 512.0
```

### Terrain Modification

```gdscript
# Remove terrain
voxel_manager.mine(position, radius, strength)

# Add terrain
voxel_manager.add(position, radius, strength)
```

### Performance Optimization

- Adjust `chunk_size` based on your needs (8-16 is recommended for real-time editing)
- Set `max_chunks_per_frame` to limit processing per frame
- Enable `multithreaded` mode for better performance
- Use `use_lod` for large terrains

## First-Person Editor Controls

- **WASD**: Move horizontally
- **Space/Ctrl**: Move up/down (in fly mode)
- **Mouse**: Look around
- **Left Mouse Button**: Remove terrain
- **Right Mouse Button**: Add terrain
- **F**: Toggle fly mode
- **+/-**: Adjust edit radius
- **[/]**: Adjust edit strength
- **Escape**: Free mouse cursor

## System Architecture

The system is composed of several key components:

1. **VoxelManager**: Central manager that handles terrain modification requests
2. **ChunkedMarchingCubes**: Core terrain generation system
3. **VoxelChunk**: Individual chunk of voxel data
4. **MeshData**: Efficient mesh data storage using packed arrays
5. **LODSystem**: Handles level of detail for distant chunks
6. **TerrainEditor/FirstPersonController**: UI and controls for terrain editing

## Performance Considerations

- The system uses a hybrid approach combining the benefits of grid-based and marching cubes systems
- Chunks are only processed when modified or when LOD changes
- Mesh generation is optimized with vertex caching and efficient data structures
- Multithreading ensures UI responsiveness during heavy edits
- Performance statistics are displayed in the first-person editor

## Customization

You can customize the terrain generation by modifying the density function in ChunkedMarchingCubes.gd:

```gdscript
func terrain_density_function(point: Vector3) -> float:
    # Your custom terrain function here
    # Return values > 0 for solid, < 0 for air
    return your_calculation
```

## Using the System with a Character Controller

To integrate the voxel system with your own character controller:

1. Add the VoxelManager to your scene
2. Set up the ChunkedMarchingCubes as a child of VoxelManager
3. Connect your character controller to the VoxelManager using:

```gdscript
# In your character controller script
@onready var voxel_manager = $Path/To/VoxelManager

func _on_mine_action():
    var hit_position = your_raycast.get_collision_point()
    voxel_manager.mine(hit_position, radius, strength)
    
func _on_add_action():
    var hit_position = your_raycast.get_collision_point()
    voxel_manager.add(hit_position, radius, strength)
```