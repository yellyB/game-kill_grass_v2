extends Node2D
## 무한 청크 풀 스포너 (MultiMesh 1 draw call). balance/core 수치 사용.
## M0: 거리 기반 베기(물리 바디 없음). 풀 데이터는 Dictionary 관리.

const Balance = preload("res://core/balance_data.gd")
const Skills = preload("res://core/skills.gd")

const CELL := 40.0            # 셀 간격(px)
const RENDER_CHUNKS := 3      # 플레이어 주변 로드 반경(청크)

var _grass: Dictionary = {}   # Vector2i(cell) → {alive, tier, hp, regen_at, pos}
var _mm: MultiMesh
var _mmi: MultiMeshInstance2D
var _rng := RandomNumberGenerator.new()
var _time := 0.0

# 풀 티어별 색상(간이) — 새싹→초강풀→황금
const TIER_COLOR := [
	Color(0.5, 0.85, 0.4), Color(0.35, 0.75, 0.6), Color(0.3, 0.6, 0.6),
	Color(0.25, 0.45, 0.75), Color(0.2, 0.3, 0.6), Color(0.95, 0.8, 0.2),
]

func _ready() -> void:
	_rng.randomize()
	_mmi = MultiMeshInstance2D.new()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(18, 24)
	_mm.mesh = quad
	_mmi.multimesh = _mm
	add_child(_mmi)

## 플레이어 월드 위치 기준 청크 로드/언로드 + 재생 처리
func update_field(player_world_pos: Vector2, dt: float) -> void:
	_time += dt
	var pc := Vector2i(roundi(player_world_pos.x / CELL), roundi(player_world_pos.y / CELL))
	var reach := RENDER_CHUNKS * 10
	# 스폰(주변 셀)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := Vector2i(pc.x + dx, pc.y + dy)
			if not _grass.has(cell):
				_spawn_cell(cell)
	# 재생
	for cell in _grass:
		var g: Dictionary = _grass[cell]
		if not g.alive and _time >= g.regen_at:
			g.alive = true
			g.hp = _tier_hp(g.tier)
	# 언로드(너무 먼 셀 제거 — 메모리)
	var far := reach + 6
	var to_remove := []
	for cell in _grass:
		if absi(cell.x - pc.x) > far or absi(cell.y - pc.y) > far:
			to_remove.append(cell)
	for cell in to_remove:
		_grass.erase(cell)
	_rebuild_multimesh()

func _spawn_cell(cell: Vector2i) -> void:
	# 대칭 랜덤 오프셋(청크 경계 비가시화)
	var h := hash(cell)
	var ox := (float(h & 0xff) / 255.0 - 0.5) * CELL * 0.7
	var oy := (float((h >> 8) & 0xff) / 255.0 - 0.5) * CELL * 0.7
	var tier := _pick_tier()
	_grass[cell] = {
		"alive": true, "tier": tier, "hp": _tier_hp(tier),
		"regen_at": 0.0, "pos": Vector2(cell.x * CELL + ox, cell.y * CELL + oy),
	}

func _pick_tier() -> int:
	var gc := GameManager.get_golden_chance()
	if _rng.randf() < gc:
		return 5  # 황금풀
	var dist: Array = GameManager.get_quality_dist()
	var r := _rng.randf()
	var acc := 0.0
	for k in range(5):
		acc += float(dist[k])
		if r <= acc:
			return k
	return 0

func _tier_hp(tier: int) -> float:
	var base: float = float(Balance.GOLD[0]) if tier == 5 else float(Balance.GRASS[tier][0])
	return base * float(Balance.WORLD_HP_MULT[GameManager.selected_world])

func _tier_value(tier: int) -> int:
	var base: int = Balance.GOLD[1] if tier == 5 else Balance.GRASS[tier][1]
	return int(base * float(Balance.WORLD_REWARD_MULT[GameManager.selected_world]))

func _tier_regen(tier: int) -> float:
	return float(Balance.GOLD[2]) if tier == 5 else float(Balance.GRASS[tier][2])

func _rebuild_multimesh() -> void:
	var alive := []
	for cell in _grass:
		if _grass[cell].alive:
			alive.append(cell)
	_mm.instance_count = alive.size()
	for i in range(alive.size()):
		var g: Dictionary = _grass[alive[i]]
		var gp: Vector2 = g.pos
		_mm.set_instance_transform_2d(i, Transform2D(0.0, gp))
		_mm.set_instance_color(i, TIER_COLOR[g.tier])

## 플레이어 주변 공격: eff_damage로 최대 count개 타격, 처치 시 [{pos, value}] 반환
func attack_around(player_world_pos: Vector2, radius: float, count: int, dmg: float) -> Array:
	var hits := []
	var candidates := []
	for cell in _grass:
		var g: Dictionary = _grass[cell]
		if not g.alive:
			continue
		var gp: Vector2 = g.pos
		var d := gp.distance_to(player_world_pos)
		if d <= radius:
			candidates.append([d, cell])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	var n: int = mini(count, candidates.size())
	for i in range(n):
		var cell: Vector2i = candidates[i][1]
		var g: Dictionary = _grass[cell]
		g.hp -= dmg
		if g.hp <= 0.0:
			g.alive = false
			g.regen_at = _time + _tier_regen(g.tier)
			hits.append({"pos": g.pos, "value": _tier_value(g.tier)})
	return hits
