shader_type canvas_item;

// Renders the world from a tiny per-tile data texture:
//   data  R = terrain id * 16, G = land (255/0), B = water depth, A = explored
//   relief R = land height
// Everything visible (coasts, biome borders, relief, water) is computed per
// "art pixel" (1/px_per_tile of a tile), so the map reads as fine pixel art
// at any zoom without any baked image.
uniform sampler2D data_n : filter_nearest;
uniform sampler2D data_l : filter_linear;
uniform sampler2D relief : filter_linear;
uniform vec2 grid = vec2(64.0, 96.0);
uniform float px_per_tile = 16.0;
// 0 = painted terrain, 1 = old parchment chart, 2 = engraved map (sepia land,
// ink hatching, teal sea with water-lining)
uniform int style = 0;

const vec3 PAL[12] = vec3[12](
	vec3(0.12, 0.25, 0.42), // ocean
	vec3(0.22, 0.45, 0.55), // lake
	vec3(0.58, 0.58, 0.47), // tundra
	vec3(0.29, 0.40, 0.25), // conifer
	vec3(0.33, 0.47, 0.23), // forest
	vec3(0.50, 0.58, 0.29), // plains
	vec3(0.41, 0.55, 0.26), // grassland
	vec3(0.68, 0.62, 0.36), // savannah
	vec3(0.35, 0.44, 0.30), // marsh
	vec3(0.28, 0.50, 0.26), // tropical
	vec3(0.55, 0.51, 0.33), // hills
	vec3(0.50, 0.48, 0.44)  // mountains
);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

const vec3 INK = vec3(0.24, 0.16, 0.10);

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.1) * 0.2;
}

vec2 uv_of(vec2 tile) {
	return tile / grid;
}

void fragment() {
	vec2 tile = UV * grid;
	// Snap to the art-pixel grid so everything shares one pixel size.
	vec2 q = (floor(tile * px_per_tile) + 0.5) / px_per_tile;
	vec2 warp = vec2(fbm(q * 0.9), fbm(q * 0.9 + 17.3)) - 0.5;
	vec2 tw = q + warp * 0.7;

	float land = texture(data_l, uv_of(tw)).g;
	land += (vnoise(q * 2.7) - 0.5) * 0.22;
	if (style == 2) {
		// Seen from afar, coasts are smoothed into flowing curves.
		vec2 cw2 = q + warp * 1.8;
		float sl2 = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785;
			sl2 += texture(data_l, uv_of(cw2 + vec2(cos(a), sin(a)) * 0.8)).g;
		}
		land = sl2 / 8.0 + (vnoise(q * 3.3) - 0.5) * 0.16;
	}
	float explored = texture(data_l, uv_of(q + warp * 1.4)).a;
	if (style == 2) {
		// The chart is seen from far away: soften the edge of the known world
		// into ragged, hand-drawn curves instead of tile steps.
		vec2 cw = q + (vec2(fbm(q * 0.35 + 3.1), fbm(q * 0.35 + 9.7)) - 0.5) * 3.0;
		explored = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785;
			explored += texture(data_l, uv_of(cw + vec2(cos(a), sin(a)) * 1.1)).a;
		}
		explored = explored / 8.0 + (fbm(q * 1.7) - 0.5) * 0.2;
	}
	float depth = texture(data_l, uv_of(tw)).b * 12.0;

	vec3 col;
	float grain = hash(floor(tile * px_per_tile));
	if (land > 0.5) {
		int id = int(texture(data_n, uv_of(tw)).r * 255.0 / 16.0 + 0.5);
		col = PAL[clamp(id, 0, 11)];
		col *= 0.86 + 0.26 * fbm(q * 1.3);
		col *= 0.96 + 0.08 * grain;
		// Relief: light from the upper left.
		float e = 0.12;
		float hx = texture(relief, uv_of(q + vec2(e, 0.0))).r - texture(relief, uv_of(q - vec2(e, 0.0))).r;
		float hy = texture(relief, uv_of(q + vec2(0.0, e))).r - texture(relief, uv_of(q - vec2(0.0, e))).r;
		col *= clamp(1.0 - (hx + hy) * 2.4, 0.72, 1.3);
		// Beaches and wet sand.
		if (land < 0.545) {
			col = mix(vec3(0.84, 0.76, 0.54), vec3(0.72, 0.62, 0.42), step(land, 0.515));
			col *= 0.95 + 0.08 * grain;
		}
		if (style == 1) {
			float lum = dot(col, vec3(0.3, 0.55, 0.15));
			col = mix(vec3(0.80, 0.70, 0.50), vec3(0.55, 0.45, 0.30), clamp((0.62 - lum) * 2.2, 0.0, 1.0));
			// Hatched relief like an engraved chart.
			float hatch = step(0.5, fract((tile.x + tile.y) * px_per_tile * 0.25));
			col *= 1.0 - hatch * clamp((hx + hy) * 6.0, 0.0, 0.18);
			if (land < 0.56) col = vec3(0.36, 0.26, 0.16);
		}
		if (style == 2) {
			vec2 ap = floor(tile * px_per_tile);
			vec3 paper = vec3(0.86, 0.76, 0.56);
			col = mix(paper, PAL[clamp(id, 0, 11)] * 1.45, 0.16);
			col *= 0.9 + 0.16 * fbm(q * 1.3);
			col *= 0.97 + 0.05 * grain;
			float sl = hx + hy;
			col *= clamp(1.0 - sl * 1.4, 0.82, 1.12);
			// Engraver's hatching on the shaded slopes.
			float diag = mod(ap.x - ap.y, 3.0);
			float hatch = step(diag, 0.5) * smoothstep(0.015, 0.09, sl);
			col = mix(col, INK, hatch * 0.42);
			// Ink coastline with a pale strand inside it.
			if (land < 0.53) {
				col = INK;
			} else if (land < 0.575) {
				col = mix(col, vec3(0.93, 0.86, 0.68), 0.55);
			}
		}
	} else {
		float d = clamp(depth / 7.0, 0.0, 1.0);
		vec3 shallow = vec3(0.30, 0.60, 0.64);
		vec3 mid = vec3(0.17, 0.40, 0.56);
		vec3 deep = vec3(0.10, 0.22, 0.40);
		col = mix(shallow, mid, smoothstep(0.0, 0.35, d));
		col = mix(col, deep, smoothstep(0.35, 1.0, d));
		col *= 0.96 + 0.06 * fbm(q * 0.8 + TIME * 0.05);
		// Moving glints, snapped to the pixel grid.
		float wv = sin(q.x * 3.1 + q.y * 8.3 + TIME * 1.3) * sin(q.y * 2.1 - TIME * 0.6 + q.x * 0.4);
		col = mix(col, vec3(0.82, 0.92, 0.95), step(0.93, wv) * 0.35 * smoothstep(0.1, 0.4, d));
		// Surf along the shore.
		float surf = smoothstep(0.38, 0.5, land) * (0.6 + 0.4 * sin(TIME * 1.6 + q.x * 2.0 + q.y));
		col = mix(col, vec3(0.88, 0.94, 0.93), clamp(surf, 0.0, 1.0) * step(0.43, land));
		if (style == 1) {
			col = mix(vec3(0.74, 0.76, 0.68), vec3(0.62, 0.66, 0.62), d);
			// Ripple lines echoing the coastline, as engravers drew them.
			float ring = fract(depth * 0.9);
			col *= 1.0 - step(0.9, ring) * step(depth, 4.0) * 0.18;
		}
		if (style == 2) {
			vec2 ap = floor(tile * px_per_tile);
			vec3 shallow = vec3(0.34, 0.52, 0.54);
			vec3 deepc = vec3(0.14, 0.29, 0.34);
			// Smooth the tile-by-tile depth into soft contours.
			float sd = 0.0;
			for (int i = 0; i < 8; i++) {
				float a = float(i) * 0.785;
				sd += texture(data_l, uv_of(tw + vec2(cos(a), sin(a)) * 1.6)).b * 12.0;
			}
			depth = sd / 8.0;
			col = mix(shallow, deepc, smoothstep(0.0, 2.5, depth));
			col *= 0.94 + 0.1 * fbm(q * 0.3);
			col *= 0.95 + 0.08 * fbm(q * 0.7);
			// Water-lining: pale rings that follow the coast, slowly drifting.
			float ring = fract(depth * 1.5 - TIME * 0.04);
			col = mix(col, vec3(0.66, 0.78, 0.74), step(0.84, ring) * (1.0 - smoothstep(0.8, 3.2, depth)) * 0.55);
			// Sparse horizontal burin strokes in open water.
			float stroke = step(0.75, fract(ap.y / 4.0)) * step(0.62, vnoise(vec2(ap.x * 0.07, ap.y * 0.5)));
			col *= 1.0 - stroke * 0.14 * smoothstep(0.15, 0.6, d);
			col = mix(col, vec3(0.80, 0.88, 0.84), step(0.95, wv) * 0.25 * smoothstep(0.2, 0.5, d));
			// Dark ragged shadow just off the shore.
			col = mix(col, INK, smoothstep(0.42, 0.5, land) * 0.55);
		}
	}

	// Terra incognita: parchment where the map hasn't been scouted.
	if (explored < 0.5) {
		vec3 parch = vec3(0.86, 0.79, 0.63) * (0.92 + 0.1 * fbm(q * 0.6));
		if (style == 0) {
			parch = mix(parch, col * 0.55 + parch * 0.2, 0.0);
		}
		float edge = smoothstep(0.3, 0.5, explored);
		if (style == 2) {
			parch = vec3(0.90, 0.82, 0.64) * (0.93 + 0.09 * fbm(q * 0.45));
			// A scorched band where the known world ends.
			float band = smoothstep(0.12, 0.32, explored) * (1.0 - edge);
			parch = mix(parch, vec3(0.62, 0.47, 0.30), band * 0.55);
		}
		col = mix(parch, col, edge);
	}
	COLOR = vec4(col, 1.0);
}
