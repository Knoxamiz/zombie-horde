shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// A texture-free surface finish for the low-poly world. It uses a stable,
// low-frequency world-space pattern so large primitive meshes do not read as
// perfectly flat color, without allocating texture memory per map or prop.

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float detail_scale : hint_range(0.02, 3.0) = 0.45;
uniform float detail_strength : hint_range(0.0, 0.25) = 0.06;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;


float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 coarse_cell = floor(world_position.xz * detail_scale);
	vec2 fine_cell = floor(world_position.xz * detail_scale * 3.7);
	float coarse = hash21(coarse_cell);
	float fine = hash21(fine_cell);
	float variation = (mix(coarse, fine, 0.28) - 0.5) * detail_strength;

	ALBEDO = clamp(base_color.rgb * (1.0 + variation), vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = emission_color.rgb * emission_energy;
}
