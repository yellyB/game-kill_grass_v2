shader_type canvas_item;

// Sway parameters
uniform float sway_speed : hint_range(0.5, 10.0) = 5.0;
uniform float sway_amount : hint_range(0.0, 0.3) = 0.12;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.7;

varying vec2 v_world_pos;

void vertex() {
	// Get world position for phase variation (so grass doesn't sway in sync)
	v_world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;

	// Phase based on world position - creates wave-like wind effect
	float phase = v_world_pos.x * 0.02 + v_world_pos.y * 0.01;

	// Sway amount increases toward the top of the grass (VERTEX.y is negative for top)
	float height_factor = clamp(-VERTEX.y / 50.0, 0.0, 1.0);

	// Multiple sine waves for more natural movement
	float sway = sin(TIME * sway_speed + phase) * sway_amount;
	sway += sin(TIME * sway_speed * 1.7 + phase * 1.3) * sway_amount * 0.5;
	sway *= wind_strength;

	// Apply sway only to upper parts of grass
	VERTEX.x += sway * height_factor * 50.0;
}

void fragment() {
	// Alpha 마커로 상태 판별 (instance color alpha)
	// 0.05 = 크리티컬 플래시, 0.25 = 피격 플래시, 0.5 = 황금풀, 1.0 = 일반

	if (COLOR.a < 0.1) {
		// 크리티컬: 밝은 노란색
		COLOR.rgb = vec3(1.0, 0.9, 0.2);
	} else if (COLOR.a < 0.35) {
		// 피격 플래시: 밝은 흰색
		COLOR.rgb = vec3(1.0, 1.0, 1.0);
	} else if (COLOR.a < 0.6) {
		// 황금풀: tint 무시하고 샛노란색으로 강제 지정
		float height = UV.y;  // 0(상단) ~ 1(하단)
		vec3 gold_tip = vec3(1.0, 0.85, 0.05);
		vec3 gold_base = vec3(0.85, 0.7, 0.02);
		COLOR.rgb = mix(gold_tip, gold_base, height);

		// 반짝이 효과
		float sparkle1 = sin(TIME * 4.0 + v_world_pos.x * 0.2 + v_world_pos.y * 0.15);
		float sparkle2 = sin(TIME * 6.0 - v_world_pos.x * 0.1 + v_world_pos.y * 0.25);
		float sparkle = sparkle1 * sparkle2;
		sparkle = smoothstep(0.4, 0.8, sparkle);
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 1.0, 0.7), sparkle * 0.7);
	}
	COLOR.a = 1.0;
}
