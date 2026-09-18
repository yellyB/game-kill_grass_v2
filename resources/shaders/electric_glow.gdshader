shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 3.0;
uniform float pulse_speed : hint_range(0.5, 8.0) = 4.0;
uniform float flicker_speed : hint_range(5.0, 40.0) = 20.0;
uniform float outline_width : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Sample neighbors to detect edges and create outer glow
	float neighbor_alpha = 0.0;
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * outline_width;
			neighbor_alpha += texture(TEXTURE, UV + offset).a;
		}
	}
	neighbor_alpha /= 25.0;

	// Pulsing + flicker
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
	float flicker = 0.6 + 0.4 * sin(TIME * flicker_speed + UV.x * 30.0 + UV.y * 20.0);
	float electric = pulse * flicker;

	if (tex.a > 0.1) {
		// Inner body: tint with electric blue + bright highlights
		COLOR = tex;
		float edge = 1.0 - smoothstep(0.2, 0.8, tex.a);
		float glow = edge * electric * glow_intensity;
		COLOR.rgb = mix(tex.rgb, glow_color.rgb, glow * 0.5);
		COLOR.rgb += glow_color.rgb * glow * 0.3;
		// Overall electric tint
		COLOR.rgb += glow_color.rgb * electric * 0.15;
	} else if (neighbor_alpha > 0.05) {
		// Outer glow: visible halo around the sprite
		float outer = neighbor_alpha * electric * glow_intensity * 0.8;
		COLOR = vec4(glow_color.rgb, outer * 0.6);
	} else {
		COLOR = tex;
	}
}
