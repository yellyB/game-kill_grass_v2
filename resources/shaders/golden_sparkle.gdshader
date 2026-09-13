shader_type canvas_item;

varying vec2 v_world_pos;
varying vec2 v_local_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	v_local_pos = VERTEX;
}

void fragment() {
	// 각 파티클마다 다른 타이밍으로 깜빡임
	float phase = v_world_pos.x * 0.37 + v_world_pos.y * 0.53;
	float blink = sin(TIME * 3.5 + phase) * sin(TIME * 5.1 - phase * 0.7);
	blink = smoothstep(0.1, 0.6, blink);

	// 중심이 밝고 가장자리가 투명한 원형 (VERTEX 기반)
	float dist = length(v_local_pos) / 5.0;
	float circle = 1.0 - smoothstep(0.0, 1.0, dist);

	COLOR = vec4(1.0, 1.0, 0.7, circle * blink);
}
