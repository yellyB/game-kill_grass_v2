extends Node2D
## 거목 (월드 클리어 게이트). 고체력 대형 나무. 처치 시 월드 클리어.
## 공격 패턴 3종(낙과/뿌리융기/회전덩굴)은 후속 슬라이스 — 현재는 순수 HP 게이트.
## 플레이어 AttackArea(mask 2)가 자식 Area2D(layer 2)를 감지 → take_damage.

var max_hp: float = 900.0
var hp: float = 900.0
var _dead: bool = false
var _base_scale: Vector2 = Vector2.ONE

# 월드별 캐노피 색(테마색 계열)
const WORLD_CANOPY := [
	Color(0.2, 0.55, 0.25),   # 1 슬라임 늪
	Color(0.55, 0.45, 0.2),   # 2 들판
	Color(0.4, 0.5, 0.58),    # 3 성벽
	Color(0.35, 0.25, 0.5),   # 4 마법의 숲
	Color(0.3, 0.7, 0.75),    # 5 수정 호수
	Color(0.5, 0.5, 0.3),     # 6 고대 유적
	Color(0.6, 0.3, 0.25),    # 7 용의 봉우리
]

@onready var visual: Node2D = $Visual
var _hp_fill: Polygon2D
var _hp_bar_w: float = 160.0

# ── 공격 패턴 (경고→고정범위 판정→스턴, 투사체 없음) ──
# 0 낙과 / 1 뿌리 융기 / 2 회전 덩굴 (거목마다 1종 랜덤)
var player: Node2D = null
var _pattern: int = 0
var _phase: int = 0          # 0 대기/쿨다운, 1 경고중
var _phase_t: float = 0.0
var _telegraph: Node2D = null
var _marker_world: Vector2 = Vector2.ZERO
var _vine: Node2D = null
var _vine_angle: float = 0.0
var _vine_cd: float = 0.0

const FALL_RADIUS := 95.0
const FALL_WARN := 1.2
const FALL_COOL := 1.4
const ROOT_RADIUS := 240.0
const ROOT_WARN := 1.3
const ROOT_COOL := 1.7
const VINE_LEN := 430.0
const VINE_HALF := 0.24        # 판정 각도 반폭(rad)
const VINE_ROT := 0.85         # 회전 속도(rad/s)
const WARN_COLOR := Color(0.95, 0.35, 0.2, 0.35)
const STRIKE_COLOR := Color(1.0, 0.5, 0.2, 0.85)

func setup(p_hp: float) -> void:
	max_hp = maxf(1.0, p_hp)
	hp = max_hp

func _ready() -> void:
	add_to_group("goomok")
	_build_visual()
	visual.scale = Vector2.ZERO
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", _base_scale, 0.5)
	player = get_tree().get_first_node_in_group("player")
	_pattern = randi() % 3
	_phase_t = 0.8  # 등장 후 첫 공격까지 여유
	if _pattern == 2:
		_init_vine()

func _process(delta: float) -> void:
	if _dead or not is_instance_valid(player):
		return
	match _pattern:
		0: _proc_fall(delta)
		1: _proc_root(delta)
		2: _proc_vine(delta)

# ── 원형 경고/판정 시각물 ──
func _make_circle(radius: float, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.color = color
	var pts: PackedVector2Array = []
	for i in 24:
		var a = TAU / 24.0 * i
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	return poly

# ── 패턴 0: 낙과 (플레이어 위치 조준 → 낙하 타격) ──
func _proc_fall(delta: float) -> void:
	_phase_t -= delta
	if _phase_t > 0.0:
		return
	if _phase == 0:
		_marker_world = player.global_position
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
		_telegraph = _make_circle(FALL_RADIUS, WARN_COLOR)
		add_child(_telegraph)
		_telegraph.global_position = _marker_world
		_telegraph.scale = Vector2(0.4, 0.4)
		var tw = create_tween()
		tw.tween_property(_telegraph, "scale", Vector2.ONE, FALL_WARN)
		_phase = 1
		_phase_t = FALL_WARN
	else:
		if player.global_position.distance_to(_marker_world) < FALL_RADIUS:
			player.apply_attack_stun()
		_flash_at(_marker_world, FALL_RADIUS)
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
			_telegraph = null
		_phase = 0
		_phase_t = FALL_COOL

# ── 패턴 1: 뿌리 융기 (거목 주변 원형 경고 → 광역 강타) ──
func _proc_root(delta: float) -> void:
	_phase_t -= delta
	if _phase_t > 0.0:
		return
	if _phase == 0:
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
		_telegraph = _make_circle(ROOT_RADIUS, WARN_COLOR)
		add_child(_telegraph)
		_telegraph.position = Vector2.ZERO
		_telegraph.scale = Vector2(0.5, 0.5)
		var tw = create_tween()
		tw.tween_property(_telegraph, "scale", Vector2.ONE, ROOT_WARN)
		_phase = 1
		_phase_t = ROOT_WARN
	else:
		if player.global_position.distance_to(global_position) < ROOT_RADIUS:
			player.apply_attack_stun()
		_flash_at(global_position, ROOT_RADIUS)
		if _telegraph and is_instance_valid(_telegraph):
			_telegraph.queue_free()
			_telegraph = null
		_phase = 0
		_phase_t = ROOT_COOL

# ── 패턴 2: 회전 덩굴 (등대식 상시 회전, 걸어서 회피) ──
func _init_vine() -> void:
	_vine = Node2D.new()
	add_child(_vine)
	var line = Polygon2D.new()
	line.color = Color(0.4, 0.6, 0.25, 0.7)
	line.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(VINE_LEN, -6), Vector2(VINE_LEN, 6), Vector2(0, 14)
	])
	_vine.add_child(line)

func _proc_vine(delta: float) -> void:
	_vine_angle = wrapf(_vine_angle + VINE_ROT * delta, 0.0, TAU)
	if _vine:
		_vine.rotation = _vine_angle
	_vine_cd -= delta
	if _vine_cd > 0.0:
		return
	var to_player = player.global_position - global_position
	if to_player.length() < VINE_LEN:
		var ang_diff = absf(wrapf(to_player.angle() - _vine_angle, -PI, PI))
		if ang_diff < VINE_HALF:
			player.apply_attack_stun()
			_vine_cd = 0.4

func _flash_at(world_pos: Vector2, radius: float) -> void:
	var flash = _make_circle(radius, STRIKE_COLOR)
	add_child(flash)
	flash.global_position = world_pos
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)

func _build_visual() -> void:
	var w = clampi(GameManager.selected_world, 0, WORLD_CANOPY.size() - 1)
	var canopy_color: Color = WORLD_CANOPY[w]
	# 몸통(트렁크)
	var trunk = Polygon2D.new()
	trunk.color = Color(0.32, 0.22, 0.14)
	trunk.polygon = PackedVector2Array([
		Vector2(-26, 90), Vector2(26, 90), Vector2(16, -40), Vector2(-16, -40)
	])
	visual.add_child(trunk)
	# 캐노피(3겹 원형)
	for layer in 3:
		var canopy = Polygon2D.new()
		canopy.color = canopy_color.lightened(layer * 0.12)
		var r = 120.0 - layer * 22.0
		var cy = -80.0 - layer * 26.0
		var pts: PackedVector2Array = []
		for i in 16:
			var a = TAU / 16.0 * i
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.8 + cy))
		canopy.polygon = pts
		visual.add_child(canopy)
	# HP 바 (캐노피 위)
	var bar_bg = Polygon2D.new()
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.7)
	bar_bg.polygon = _rect(-_hp_bar_w * 0.5, -230, _hp_bar_w, 16)
	visual.add_child(bar_bg)
	_hp_fill = Polygon2D.new()
	_hp_fill.color = Color(0.9, 0.3, 0.3)
	_hp_fill.polygon = _rect(-_hp_bar_w * 0.5, -230, _hp_bar_w, 16)
	visual.add_child(_hp_fill)

func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var frac = clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.polygon = _rect(-_hp_bar_w * 0.5, -230, _hp_bar_w * frac, 16)

func take_damage(dmg: int, _from_pos: Vector2) -> void:
	if _dead:
		return
	hp -= float(dmg)
	_update_hp_bar()
	visual.modulate = Color(1.6, 1.6, 1.6)
	var tw = create_tween()
	tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.12)
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	# 월드 클리어 처리 (다음 월드 해금 + 보석 + 코인 보너스 + 세션 종료 트리거)
	GameManager.clear_current_world()
	var tw = create_tween()
	tw.tween_property(visual, "scale", _base_scale * 1.2, 0.15)
	tw.tween_property(visual, "scale", Vector2.ZERO, 0.35)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
