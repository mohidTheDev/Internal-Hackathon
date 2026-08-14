shader_type canvas_item;

// 1. CHANGED: filter_linear_mipmap to filter_nearest for crisp pixel art
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float shift_strength : hint_range(0.0, 1.0) = 0.0; 

uniform float wave_frequency = 15.0; 
uniform float wave_amplitude = 0.015; 
uniform bool use_own_texture = false;
uniform bool invert_colors = false;

// 2. ADDED: Controls how "blocky" the distortion is. 
// A value of 4.0 means the wave shifts in chunks of 4 pixels.
uniform float pixel_chunk_size = 4.0; 

void fragment() {
	if (use_own_texture) {
		vec4 tex_color = texture(TEXTURE, UV);
		if (invert_colors) {
			tex_color.rgb = vec3(1.0) - tex_color.rgb;
			tex_color.a *= 0.5;
		}
		COLOR = tex_color;
	} else {
		vec2 uv = SCREEN_UV;

		// Calculate how many "chunks" fit on the screen using the built-in SCREEN_PIXEL_SIZE
		vec2 screen_resolution = 1.0 / SCREEN_PIXEL_SIZE;
		float grid_y = screen_resolution.y / pixel_chunk_size;

		// Snap the Y coordinate to our chunky grid just for the sine wave math
		float snapped_y = floor(uv.y * grid_y) / grid_y;

		uv.x += sin(snapped_y * wave_frequency + TIME * 20.0) * wave_amplitude * shift_strength;

		vec4 screen_color = texture(screen_texture, uv);

		vec3 shifted_color = vec3(
			screen_color.b * 1.2,
			screen_color.r * 0.4,
			screen_color.g * 0.8
		);

		COLOR.rgb = mix(screen_color.rgb, shifted_color, shift_strength);
	}
}