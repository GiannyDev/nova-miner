shader_type canvas_item;

/** Circle position in [0, 1]² — use (0.5, 0.5) for screen center */
uniform vec2 _CirclePosition = vec2(0.5, 0.5);
/** Progress of the transition */
uniform float _Progress : hint_range(0.0, 1.0, 0.01) = 0.5;
/** Edge smoothness of the circle (not visible at the end) */
uniform float _Smoothness : hint_range(0.0, 0.1, 0.01) = 0.03;
/** Background color of the transition */
uniform vec3 _Background : source_color;

void fragment()
{
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 position = _CirclePosition * vec2(aspect, 1.0);
	vec2 uv = SCREEN_UV * vec2(aspect, 1.0);

	vec2 top_left = vec2(0.0, 0.0);
	vec2 top_right = vec2(aspect, 0.0);
	vec2 bottom_left = vec2(0.0, 1.0);
	vec2 bottom_right = vec2(aspect, 1.0);

	float r_max = max(
		max(distance(position, top_left), distance(position, top_right)),
		max(distance(position, bottom_left), distance(position, bottom_right))
	);

	float reveal_radius = r_max * (1.0 - _Progress);
	float edge_outer = mix(reveal_radius, reveal_radius + _Smoothness, reveal_radius);
	float mask = smoothstep(reveal_radius, edge_outer, distance(uv, position));

	COLOR = vec4(_Background, mask);
}
