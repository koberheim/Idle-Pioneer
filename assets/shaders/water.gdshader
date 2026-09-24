shader_type canvas_item;

// Animated glints on water pixels only. Glints snap to the map's own pixel
// grid so they read as pixel art rather than a smooth overlay.
uniform sampler2D water_mask : filter_nearest;
uniform vec2 map_pixels = vec2(360.0, 720.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(water_mask, UV).r;
	if (m > 0.5) {
		vec2 p = floor(UV * map_pixels);
		float w = sin(p.x * 0.31 + p.y * 0.83 + TIME * 1.4) * sin(p.y * 0.21 - TIME * 0.7 + p.x * 0.05);
		float glint = step(0.94, w);
		float swell = 0.5 + 0.5 * sin(TIME * 0.6 + p.y * 0.045 + p.x * 0.02);
		c.rgb *= 0.965 + 0.05 * swell;
		c.rgb = mix(c.rgb, vec3(0.86, 0.94, 0.96), glint * 0.35);
	}
	COLOR = c;
}
