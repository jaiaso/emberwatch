shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 resolution = vec2(576.0, 360.0);
uniform float strength : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec2 uv = (floor(SCREEN_UV * resolution) + 0.5) / resolution;
	vec3 color = texture(screen_texture, uv).rgb;
	vec2 cell = mod(floor(uv * resolution), 2.0);
	float dither = (cell.x + cell.y * 2.0) / 4.0 - 0.375;
	vec3 quantized = floor(clamp(color + dither / 28.0, 0.0, 1.0) * 28.0) / 28.0;
	color = mix(color, quantized, strength);
	float vignette = 1.0 - dot(SCREEN_UV - 0.5, SCREEN_UV - 0.5) * 0.35;
	COLOR = vec4(color * vignette, 1.0);
}
