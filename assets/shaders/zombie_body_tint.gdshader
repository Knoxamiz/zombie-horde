shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 body_tint : source_color = vec4(0.42, 1.0, 0.28, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.72;
uniform float supporter_emission_energy : hint_range(0.0, 4.0) = 0.0;
uniform vec4 supporter_emission : source_color = vec4(1.0, 0.18, 0.12, 1.0);
uniform float bits_glow_energy : hint_range(0.0, 6.0) = 0.0;
uniform vec4 bits_glow_color : source_color = vec4(0.78, 0.22, 1.0, 1.0);
uniform float bits_rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float material_roughness : hint_range(0.0, 1.0) = 1.0;
uniform float material_metallic : hint_range(0.0, 1.0) = 0.0;


float body_region_mask(vec3 color) {
	float max_channel = max(color.r, max(color.g, color.b));
	float min_channel = min(color.r, min(color.g, color.b));
	float saturation = max_channel - min_channel;

	float neutral = smoothstep(0.02, 0.12, 0.16 - saturation);
	float dark_neutral = smoothstep(0.2, 0.08, max_channel);

	float blue_clothes = smoothstep(0.05, 0.14, color.b - max(color.r, color.g));
	float teal_clothes = smoothstep(0.18, 0.32, color.g + color.b - color.r * 1.8);
	float orange_clothes = smoothstep(0.28, 0.42, color.r - color.b) * smoothstep(0.18, 0.3, color.g) * step(0.42, color.r);
	float red_clothes = smoothstep(0.22, 0.36, color.r - color.g) * step(0.45, color.r) * step(color.b, color.g * 0.85);
	float clothing = clamp(blue_clothes + teal_clothes + orange_clothes + red_clothes, 0.0, 1.0);

	float zombie_green = smoothstep(0.12, 0.24, color.g - color.r) * smoothstep(0.08, 0.18, color.g - color.b);
	float skin_tone = smoothstep(0.04, 0.14, color.r - color.b) * smoothstep(0.0, 0.12, color.g - color.b * 0.9);
	float brown_skin = smoothstep(0.08, 0.2, color.r - color.g) * step(color.b, color.r * 0.8);
	float body = clamp(zombie_green + skin_tone + brown_skin, 0.0, 1.0);

	float keep_original = clamp(neutral + dark_neutral + clothing, 0.0, 1.0);
	return clamp(body - keep_original * 0.92, 0.0, 1.0);
}


void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 base = tex.rgb;
	float mask = body_region_mask(base);

	vec3 tinted = mix(base, base * body_tint.rgb, tint_strength * mask);
	ALBEDO = tinted;
	ROUGHNESS = material_roughness;
	METALLIC = material_metallic;

	vec3 emission = vec3(0.0);
	if (supporter_emission_energy > 0.001) {
		emission += supporter_emission.rgb * supporter_emission_energy * mask;
	}
	if (bits_glow_energy > 0.001) {
		vec3 body_glow = mix(body_tint.rgb, bits_glow_color.rgb, 0.52);
		emission += body_glow * bits_glow_energy * mask;
		emission += body_tint.rgb * bits_glow_energy * mask * 0.28;

		float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
		emission += bits_glow_color.rgb * bits_glow_energy * fresnel * bits_rim_strength;
	}
	EMISSION = emission;
}
