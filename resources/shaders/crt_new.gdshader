//---CRT Shader---
shader_type canvas_item;

uniform float wobble_speed: hint_range(0.0, 1.0) = 0.1;
uniform float wobble_frequency: hint_range(0.0, 1.0) = 0.5;
uniform float wobble_strength: hint_range(0.0, 1.0) = 0.5;
uniform float fisheye: hint_range(0.0, 1.0) = 0.5;
uniform float brighten: hint_range(0.0, 3.0) = 0.5;
uniform float scanline_count : hint_range(0, 1800) = 50.0;
uniform float scanline_movespeed : hint_range(0.0, 10.0) = 3.0;
uniform float horizontal_scanline_strength: hint_range(0.0, 1.0) = 0.4;
uniform float vertical_scanline_strength: hint_range(0.0, 1.0) = 0.4;
uniform float chromatic: hint_range(0.0, 10.0) = 2.0;
uniform float ghosting: hint_range(0.0, 0.3) = 0.05;
uniform float vignette: hint_range(0.0, 1.0) = 0.5;
uniform vec3 edge_color: source_color = vec3(1.0, 1.0, 1.0);

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest, repeat_disable;

uniform float bloomRadius = 1.0;
uniform float bloomThreshold = 1.0;
uniform float bloomIntensity = 1.0;

vec3 GetBloomPixel(sampler2D tex, vec2 uv, vec2 texPixelSize) {
	vec2 uv2 = floor(uv / texPixelSize) * texPixelSize;
	uv2 += texPixelSize * .001;
	vec3 tl = max(texture(tex, uv2).rgb - bloomThreshold, 0.0);
	vec3 tr = max(texture(tex, uv2 + vec2(texPixelSize.x, 0.0)).rgb - bloomThreshold, 0.0);
	vec3 bl = max(texture(tex, uv2 + vec2(0.0, texPixelSize.y)).rgb - bloomThreshold, 0.0);
	vec3 br = max(texture(tex, uv2 + vec2(texPixelSize.x, texPixelSize.y)).rgb - bloomThreshold, 0.0);
	vec2 f = fract( uv / texPixelSize );

	vec3 tA = mix( tl, tr, f.x );
	vec3 tB = mix( bl, br, f.x );

	return mix( tA, tB, f.y );
}

vec3 GetBloom(sampler2D tex, vec2 uv, vec2 texPixelSize) {
	vec3 bloom = vec3(0.0);
	vec2 off = vec2(1) * texPixelSize * bloomRadius;
	bloom += GetBloomPixel(tex, uv + off * vec2(-1, -1), texPixelSize * bloomRadius) * 0.292893;
	bloom += GetBloomPixel(tex, uv + off * vec2(-1, 0), texPixelSize * bloomRadius) * 0.5;
	bloom += GetBloomPixel(tex, uv + off * vec2(-1, 1), texPixelSize * bloomRadius) * 0.292893;
	bloom += GetBloomPixel(tex, uv + off * vec2(0, -1), texPixelSize * bloomRadius) * 0.5;
	bloom += GetBloomPixel(tex, uv + off * vec2(0, 0), texPixelSize * bloomRadius) * 1.0;
	bloom += GetBloomPixel(tex, uv + off * vec2(0, 1), texPixelSize * bloomRadius) * 0.5;
	bloom += GetBloomPixel(tex, uv + off * vec2(1, -1), texPixelSize * bloomRadius) * 0.292893;
	bloom += GetBloomPixel(tex, uv + off * vec2(1, 0), texPixelSize * bloomRadius) * 0.5;
	bloom += GetBloomPixel(tex, uv + off * vec2(1, 1), texPixelSize * bloomRadius) * 0.292893;
	bloom /= 4.171573f;
	return bloom;
}

vec2 uv_curve(vec2 uv)
{
	uv = (uv - 0.5) * 2.0;


	uv.x *= 1.0 + pow(abs(uv.y) * fisheye, 3.0);
	uv.y *= 1.0 + pow(abs(uv.x) * fisheye, 3.0);

	//The scale part (you can delete it when you want)
	//uv /= 1.04;

	uv = (uv/2.0) + 0.5;
	return uv;
}


void fragment()
{
	// Fisheye
	vec2 uv = uv_curve(SCREEN_UV);

	// Wobble effect
	float x = sin(wobble_speed*TIME+uv.y*wobble_frequency*14.0)*sin(wobble_speed*2.5*TIME+uv.y*wobble_frequency*20.0)*0.004*wobble_strength;

	// Chromatic aberration
	vec2 chromatic_uv = uv + vec2(x, 0);
	float r = texture(SCREEN_TEXTURE, chromatic_uv+SCREEN_PIXEL_SIZE.x*vec2(chromatic, chromatic), 0.0).r+0.05;
	float g = texture(SCREEN_TEXTURE, chromatic_uv+SCREEN_PIXEL_SIZE.x*vec2(chromatic, -chromatic), 0.0).g+0.05;
	float b = texture(SCREEN_TEXTURE, chromatic_uv+SCREEN_PIXEL_SIZE.x*vec2(-chromatic, -chromatic), 0.0).b+0.05;
	vec3 col = vec3(r, g, b);

	// Ghosting
	col.r += ghosting*texture(SCREEN_TEXTURE,vec2(x+uv.x-0.025, uv.y-0.025)).r;
	col.g += ghosting*texture(SCREEN_TEXTURE,vec2(x+uv.x-0.022, uv.y-0.02)).g;
	col.b += ghosting*texture(SCREEN_TEXTURE,vec2(x+uv.x-0.02, uv.y-0.018)).b;

	// Brighten
	col *= 1.0 + brighten;

	// Bloom
	vec3 bloom = GetBloom(SCREEN_TEXTURE, uv, SCREEN_PIXEL_SIZE);
	col.rgb += bloom * bloomIntensity;

	// Scanlines (horizontal lines)
	float s = sin(scanline_movespeed*TIME+uv.y * scanline_count * PI * 2.0);
	s = (s * 0.2 + 0.5) * 0.9 + 0.1;
	vec3 scan_line = vec3(pow(s, horizontal_scanline_strength*0.5));
	col *= scan_line;

	// Grid lines (vertical lines)
	float grid_uv = mod(SCREEN_UV.x / SCREEN_PIXEL_SIZE.x, 3.0);
	vec3 grid_color;
	grid_color.r = clamp(1.0 - grid_uv, 0.0, 1.0) + clamp(grid_uv - 2.0, 0.0, 1.0);
	grid_color.g = clamp(1.0 - abs(1.0 - grid_uv), 0.0, 1.0);
	grid_color.b = 1.0 - grid_color.r - grid_color.g;
	col *= clamp(normalize(clamp(grid_color, 0.5-vertical_scanline_strength, 1.0)), vec3(0.0), vec3(1.0));


	// Vignette
	float vig = (1.0*20.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y));
	col *= vec3(pow(vig,vignette));

	// Black border outside of fisheye
	if (uv.x < 0.0 || uv.x > 1.0)
		col = edge_color;
	if (uv.y < 0.0 || uv.y > 1.0)
		col = edge_color;

	COLOR = vec4(col, 1.0);
}
