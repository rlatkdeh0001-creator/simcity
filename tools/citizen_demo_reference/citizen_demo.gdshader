shader_type canvas_item;
render_mode unshaded;

// No source_color conversion: the reference composes grayscale/tints in PNG
// byte color space. Depth is DATA, never sRGB and never filtered/interpolated.
uniform sampler2D body_color : filter_nearest, repeat_disable;
uniform sampler2D hair_color : filter_nearest, repeat_disable;
uniform sampler2D top_color : filter_nearest, repeat_disable;
uniform sampler2D bottom_color : filter_nearest, repeat_disable;
uniform sampler2D body_depth : filter_nearest, repeat_disable;
uniform sampler2D hair_depth : filter_nearest, repeat_disable;
uniform sampler2D top_depth : filter_nearest, repeat_disable;
uniform sampler2D bottom_depth : filter_nearest, repeat_disable;
uniform vec4 body_tint = vec4(1.0);
uniform vec4 hair_tint = vec4(1.0);
uniform vec4 top_tint = vec4(1.0);
uniform vec4 bottom_tint = vec4(1.0);

float millimetres(vec2 bytes) {
	vec2 exact_bytes = floor(bytes * 255.0 + vec2(0.5));
	return exact_bytes.x + 256.0 * exact_bytes.y;
}

void fragment() {
	// Sprite2D supplies the SAME framed/flipped atlas UV to all eight samplers.
	// Never multiply by the implicit TEXTURE sample (body alpha is not a mask).
	vec4 parts[4];
	parts[0] = texture(body_color, UV) * body_tint;
	parts[1] = texture(hair_color, UV) * hair_tint;
	parts[2] = texture(top_color, UV) * top_tint;
	parts[3] = texture(bottom_color, UV) * bottom_tint;
	float depths[4];
	depths[0] = millimetres(texture(body_depth, UV).rg);
	depths[1] = millimetres(texture(hair_depth, UV).rg);
	depths[2] = millimetres(texture(top_depth, UV).rg);
	depths[3] = millimetres(texture(bottom_depth, UV).rg);
	int indices[4] = int[4](0, 1, 2, 3);
	for (int pass = 0; pass < 3; pass++) {
		for (int j = 0; j < 3; j++) {
			// Descending depths; equal-depth tie matches reverse argsort of
			// source [body,hair,top,bottom]: lower original index is on top.
			if (depths[j] < depths[j+1] || (depths[j] == depths[j+1] && indices[j] < indices[j+1])) {
				float depth_swap = depths[j];
				depths[j] = depths[j+1];
				depths[j+1] = depth_swap;
				vec4 part_swap = parts[j];
				parts[j] = parts[j+1];
				parts[j+1] = part_swap;
				int index_swap = indices[j];
				indices[j] = indices[j+1];
				indices[j+1] = index_swap;
			}
		}
	}
	vec3 premultiplied_rgb = vec3(0.0);
	float alpha = 0.0;
	for (int i = 0; i < 4; i++) {
		float a = depths[i] < 65535.0 ? parts[i].a : 0.0;
		premultiplied_rgb = parts[i].rgb * a + premultiplied_rgb * (1.0 - a);
		alpha = a + alpha * (1.0 - a);
	}
	// blend_mix expects straight alpha; divide only after all four over ops.
	COLOR = vec4(premultiplied_rgb / max(alpha, 0.00000001), alpha);
}
