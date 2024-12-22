#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer DensityBuffer {
    float densities[];
} density_buffer;

layout(set = 0, binding = 1, std140) uniform Params {
    vec3 hit_point;
    float radius;
    float radius_squared;
    float strength;
    vec3 chunk_start;
    float chunk_size;
} params;

void main() {
    uvec3 id = gl_GlobalInvocationID;
    uint index = id.x + id.y * uint(params.chunk_size) + id.z * uint(params.chunk_size * params.chunk_size);
    
    vec3 voxel_pos = params.chunk_start + vec3(id);
    float distance_squared = dot(voxel_pos - params.hit_point, voxel_pos - params.hit_point);
    
    float current_density = density_buffer.densities[index];
    
    if (distance_squared <= params.radius_squared) {
        float factor = 1.0 - (distance_squared / params.radius_squared);
        float density_change = params.strength * factor;
        float new_density = max(0.0, min(1.0, current_density - density_change));
        density_buffer.densities[index] = new_density;
    }
}