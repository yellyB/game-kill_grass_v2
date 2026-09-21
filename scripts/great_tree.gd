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

func setup(p_hp: float) -> void:
	max_hp = maxf(1.0, p_hp)
	hp = max_hp

func _ready() -> void:
	_build_visual()
	visual.scale = Vector2.ZERO
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", _base_scale, 0.5)

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
