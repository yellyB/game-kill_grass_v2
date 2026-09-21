extends Node2D
## 정예 식물 (씨앗 공급원). HP = 풀 평균 ×2. 처치 시 씨앗 1개 드롭.
## 플레이어 AttackArea(mask 2)가 자식 Area2D(layer 2)를 감지 → take_damage 호출.

signal died(elite)

const DROPPED_ITEM = preload("res://scenes/world/dropped_item.tscn")

var max_hp: float = 20.0
var hp: float = 20.0
var _dead: bool = false
var _base_scale: Vector2 = Vector2.ONE
var _hp_fill: Polygon2D = null
var _hp_bar_root: Node2D = null
var _hp_bar_timer: float = 0.0
const _HP_BAR_SHOW_TIME: float = 1.5  # 풀과 동일: 마지막 피격 후 유지 시간
const _HP_BAR_W: float = 56.0
const _HP_BAR_Y: float = -52.0

@onready var visual: Node2D = $Visual

func setup(p_hp: float) -> void:
	max_hp = maxf(1.0, p_hp)
	hp = max_hp

func _ready() -> void:
	_build_visual()
	# 팝업 등장 연출
	visual.scale = Vector2.ZERO
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", _base_scale, 0.25)

func _ellipse(cx: float, cy: float, rx: float, ry: float, segs: int = 16) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in segs:
		var a = TAU / segs * i
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts

func _build_visual() -> void:
	# 씨앗 꼬투리(씨방): 짧은 줄기 + 통통한 꼬투리 + 씨앗 알갱이
	var stem = Polygon2D.new()
	stem.color = Color(0.3, 0.5, 0.28)
	stem.polygon = PackedVector2Array([Vector2(-4, 32), Vector2(4, 32), Vector2(2, 6), Vector2(-2, 6)])
	visual.add_child(stem)
	# 꼬투리 본체 (세로 타원)
	var pod = Polygon2D.new()
	pod.color = Color(0.42, 0.62, 0.3)
	pod.polygon = _ellipse(0, -12, 16, 26, 20)
	visual.add_child(pod)
	# 꼬투리 밝은 면(왼쪽 위 반사)
	var pod_hl = Polygon2D.new()
	pod_hl.color = Color(0.56, 0.76, 0.4)
	pod_hl.polygon = _ellipse(-3, -15, 8, 17, 16)
	visual.add_child(pod_hl)
	# 씨앗 알갱이 3개(세로로 담김)
	for i in 3:
		var seed = Polygon2D.new()
		seed.color = Color(0.5, 0.38, 0.2)
		seed.polygon = _ellipse(0, -24 + i * 10, 4.5, 5.5, 10)
		visual.add_child(seed)
	# HP 바 (식물 위) — 풀처럼 피격 시에만 표시
	_hp_bar_root = Node2D.new()
	_hp_bar_root.visible = false
	visual.add_child(_hp_bar_root)
	var bar_bg = Polygon2D.new()
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.7)
	bar_bg.polygon = _rect(-_HP_BAR_W * 0.5, _HP_BAR_Y, _HP_BAR_W, 8)
	_hp_bar_root.add_child(bar_bg)
	_hp_fill = Polygon2D.new()
	_hp_fill.color = Color(0.9, 0.35, 0.3)
	_hp_fill.polygon = _rect(-_HP_BAR_W * 0.5, _HP_BAR_Y, _HP_BAR_W, 8)
	_hp_bar_root.add_child(_hp_fill)

func _process(delta: float) -> void:
	if _hp_bar_timer > 0.0:
		_hp_bar_timer -= delta
		if _hp_bar_timer <= 0.0 and _hp_bar_root:
			_hp_bar_root.visible = false

func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var frac = clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.polygon = _rect(-_HP_BAR_W * 0.5, _HP_BAR_Y, _HP_BAR_W * frac, 8)

func take_damage(dmg: int, _from_pos: Vector2) -> void:
	if _dead:
		return
	hp -= float(dmg)
	# 풀과 동일: 피격 시 바 표시 + 유지 타이머 리셋
	if _hp_bar_root:
		_hp_bar_root.visible = true
	_hp_bar_timer = _HP_BAR_SHOW_TIME
	_update_hp_bar()
	# 피격 플래시
	visual.modulate = Color(2, 2, 2)
	var tw = create_tween()
	tw.tween_property(visual, "modulate", Color(1, 1, 1), 0.12)
	# 살짝 흔들림
	var punch = create_tween()
	punch.tween_property(visual, "scale", _base_scale * 1.15, 0.04)
	punch.tween_property(visual, "scale", _base_scale, 0.08)
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	# 씨앗 드롭 → 플레이어에게 비행
	var player = get_tree().get_first_node_in_group("player")
	var seed_item = DROPPED_ITEM.instantiate()
	seed_item.setup_seed(player)
	get_parent().add_child(seed_item)
	seed_item.global_position = global_position
	# 사망 연출 후 제거
	var tw = create_tween()
	tw.tween_property(visual, "scale", Vector2.ZERO, 0.15)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
