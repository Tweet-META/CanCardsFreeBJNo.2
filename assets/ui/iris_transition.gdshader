shader_type canvas_item;
render_mode unshaded;

uniform float aperture : hint_range(0.0, 1.0) = 1.0;
uniform float screen_aspect = 1.777778;
uniform float feather : hint_range(0.001, 0.05) = 0.012;

void fragment() {
	vec2 scale = vec2(screen_aspect, 1.0);
	vec2 position = (UV - vec2(0.5)) * scale;
	float maximum_radius = length(scale * 0.5);
	float radius = mix(-2.0 * feather, maximum_radius + 2.0 * feather, aperture);
	float coverage = smoothstep(radius - feather, radius + feather, length(position));
	COLOR = vec4(0.0, 0.0, 0.0, coverage);
}
