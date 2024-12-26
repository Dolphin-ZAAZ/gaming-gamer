shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform bool is_simple = true;
uniform float transition_smoothness : hint_range(0.0, 1.0) = 0.1;

varying vec3 vertex_pos;

void vertex() {
    vertex_pos = VERTEX;
}

void fragment() {
    vec3 normal = normalize(NORMAL);
    
    if (is_simple) {
        // For simple cubes, only render the outer faces
        float edge_factor = max(max(abs(normal.x), abs(normal.y)), abs(normal.z));
        float alpha = smoothstep(1.0 - transition_smoothness, 1.0, edge_factor);
        ALPHA = alpha;
    } else {
        // For modified cubes, render all faces
        ALPHA = 1.0;
    }
    
    ALBEDO = albedo.rgb;
}