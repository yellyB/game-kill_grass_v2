extends Node2D

signal grass_cut(position: Vector2, value: int)
signal new_chunk_entered(chunk_coord: Vector2i)

@export var chunk_size: float = 400.0
@export var render_distance: int = 3

# Visual rendering with MultiMesh (ONE draw call for all grass!)
var multimesh_instance: MultiMeshInstance2D
var multimesh: MultiMesh

# 황금풀 주변 반짝이 파티클
var sparkle_mm_instance: MultiMeshInstance2D
var sparkle_mm: MultiMesh
const SPARKLES_PER_GOLDEN: int = 3
const SPARKLE_RADIUS: float = 30.0

# Grass data storage (no nodes, just data)
var grass_data: Dictionary = {}  # Key: Vector2i (grid pos), Value: {cut: bool, type: int, regen_time: float}
var loaded_chunks: Dictionary = {}  # Key: Vector2i, Value: Array of grid positions
var visited_chunks: Dictionary = {}  # Key: Vector2i, tracks first-time visits
var _cut_grass: Array = []  # Grid positions of cut grass (for regen optimization)
var _active_timers: Array = []  # Grid positions with active hit/hp_bar timers
var _dirty_chunks: Dictionary = {}  # Chunks needing multimesh rebuild
var _cached_visible: Array = []  # Cached visible grass positions
var _cached_colors: Array = []  # Cached colors
var _cached_golden: Array = []  # Cached golden positions
var _mm_needs_rebuild: bool = true  # Full rebuild flag

# Grid-based positioning (no spacing calculation needed)
var grid_cell_size: float = 115.0  # Base spacing between grass

# 월드별 풀 메시 색상 (base=밑동, tip=끝)
const WORLD_GRASS_TINTS: Array = [
  {"base": Color(0.36, 0.74, 0.36), "tip": Color(0.17, 0.55, 0.21)},  # 월드1: 슬라임 늪
  {"base": Color(0.92, 0.78, 0.5), "tip": Color(0.73, 0.59, 0.35)},   # 월드2: 들판 - 밝은 갈색
  {"base": Color(0.78, 0.82, 0.88), "tip": Color(0.55, 0.58, 0.68)},  # 월드3: 기사의 성벽 - 밝은 회청
  {"base": Color(0.64, 0.7, 0.9), "tip": Color(0.45, 0.51, 0.75)},    # 월드4: 마법의 숲 - 보라 청남색
  {"base": Color(0.48, 0.88, 0.9), "tip": Color(0.29, 0.69, 0.75)},   # 월드5: 수정 호수 - 청록 시안
  {"base": Color(0.72, 0.68, 0.43), "tip": Color(0.53, 0.49, 0.28)},  # 월드6: 고대 유적 - 올리브
  {"base": Color(0.79, 0.52, 0.43), "tip": Color(0.6, 0.33, 0.28)},   # 월드7: 용의 봉우리 - 채도 낮은 빨강
]

# 월드별 풀 타입(0새싹,1잔디,2여린풀,3강한풀,4초강풀,5황금) 인스턴스 색상
# null이면 원본 GrassData.color 사용
const WORLD_GRASS_COLORS: Array = [
  # 월드1: 슬라임 늪
  [Color(0.26, 0.56, 0.2), Color(0.41, 0.68, 0.25), Color(0.56, 0.8, 0.3), Color(0.71, 0.92, 0.35), Color(0.86, 1.0, 0.4), null],
  # 월드2: 들판
  [Color(0.72, 0.62, 0.44), Color(0.84, 0.74, 0.54), Color(0.96, 0.86, 0.64), Color(1.0, 0.98, 0.74), Color(1.0, 1.0, 0.84), null],
  # 월드3: 기사의 성벽
  [Color(0.72, 0.74, 0.78), Color(0.80, 0.82, 0.85), Color(0.88, 0.90, 0.92), Color(0.94, 0.95, 0.96), Color(1.0, 1.0, 1.0), null],
  # 월드4: 마법의 숲
  [Color(0.39, 0.4, 0.64), Color(0.51, 0.52, 0.74), Color(0.63, 0.64, 0.84), Color(0.75, 0.76, 0.94), Color(0.87, 0.88, 1.0), null],
  # 월드5: 수정 호수
  [Color(0.24, 0.58, 0.6), Color(0.36, 0.7, 0.7), Color(0.48, 0.82, 0.8), Color(0.6, 0.94, 0.9), Color(0.72, 1.0, 1.0), null],
  # 월드6: 고대 유적
  [Color(0.56, 0.52, 0.32), Color(0.68, 0.64, 0.42), Color(0.8, 0.76, 0.52), Color(0.92, 0.88, 0.62), Color(1.0, 1.0, 0.72), null],
  # 월드7: 용의 봉우리
  [Color(0.58, 0.38, 0.32), Color(0.7, 0.5, 0.42), Color(0.82, 0.62, 0.52), Color(0.94, 0.74, 0.62), Color(1.0, 0.86, 0.72), null],
]

const GRID_SIDE: int = 15  # 15x15 = 225 slots per chunk
const BASE_GRASS_PER_CHUNK: int = 1  # Lv.0 starting count

func get_grass_per_chunk() -> int:
  return mini(GameManager.get_grass_density_value(), GRID_SIDE * GRID_SIDE)

var player: Node2D = null
var player_attack_area: Area2D = null
var _has_active_hp_bars: bool = false

func _ready() -> void:
  setup_multimesh()
  setup_sparkle_multimesh()
  call_deferred("find_player")
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.golden_bloom_requested.connect(_on_golden_bloom)
  GameManager.field_clear_requested.connect(_on_field_clear)
  GameManager.blackhole_requested.connect(_on_blackhole)

func setup_multimesh() -> void:
  # Create MultiMesh for efficient grass rendering
  multimesh = MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_2D
  multimesh.use_colors = true
  multimesh.mesh = create_grass_mesh()
  multimesh.instance_count = 0

  multimesh_instance = MultiMeshInstance2D.new()
  multimesh_instance.multimesh = multimesh

  # Apply grass sway shader (GPU-based animation - zero CPU cost!)
  var grass_shader = load("res://resources/shaders/grass_sway.gdshader")
  if grass_shader:
    var shader_mat = ShaderMaterial.new()
    shader_mat.shader = grass_shader
    multimesh_instance.material = shader_mat

  add_child(multimesh_instance)

func setup_sparkle_multimesh() -> void:
  sparkle_mm = MultiMesh.new()
  sparkle_mm.transform_format = MultiMesh.TRANSFORM_2D
  sparkle_mm.use_colors = true
  sparkle_mm.mesh = create_sparkle_mesh()
  sparkle_mm.instance_count = 0

  sparkle_mm_instance = MultiMeshInstance2D.new()
  sparkle_mm_instance.multimesh = sparkle_mm

  var sparkle_shader = load("res://resources/shaders/golden_sparkle.gdshader")
  if sparkle_shader:
    var mat = ShaderMaterial.new()
    mat.shader = sparkle_shader
    sparkle_mm_instance.material = mat

  add_child(sparkle_mm_instance)

func create_sparkle_mesh() -> ArrayMesh:
  var mesh = ArrayMesh.new()
  var s = 5.0  # 반짝이 크기
  var vertices = PackedVector2Array([
    Vector2(-s, -s), Vector2(s, -s), Vector2(s, s),
    Vector2(-s, -s), Vector2(s, s), Vector2(-s, s),
  ])
  var colors = PackedColorArray([
    Color.WHITE, Color.WHITE, Color.WHITE,
    Color.WHITE, Color.WHITE, Color.WHITE,
  ])
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_COLOR] = colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return mesh

func create_grass_mesh() -> ArrayMesh:
  # Simple triangle mesh for grass blade
  var mesh = ArrayMesh.new()
  var vertices = PackedVector2Array([
    Vector2(-6, 0),
    Vector2(6, 0),
    Vector2(0, -50)
  ])
  var world = GameManager.selected_world
  var tint = WORLD_GRASS_TINTS[world] if world < WORLD_GRASS_TINTS.size() else WORLD_GRASS_TINTS[0]
  var colors = PackedColorArray([
    tint.base,
    tint.base,
    tint.tip,
  ])
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_COLOR] = colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return mesh

func find_player() -> void:
  player = get_tree().get_first_node_in_group("player")
  if player:
    player_attack_area = player.get_node_or_null("AttackArea")
    update_chunks()

func _on_upgrade_purchased(upgrade_type: String, _level: int) -> void:
  if upgrade_type == "grass_density":
    grass_data.clear()
    loaded_chunks.clear()
    _cut_grass.clear()
    _active_timers.clear()
    _mm_needs_rebuild = true
    update_chunks()

func _process(delta: float) -> void:
  if not player:
    return

  _has_active_hp_bars = false
  update_chunks()
  process_regen(delta)
  update_multimesh()
  queue_redraw()

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
  return Vector2i(floori(world_pos.x / chunk_size), floori(world_pos.y / chunk_size))

func update_chunks() -> void:
  var relative_player_pos = player.global_position - global_position
  var player_chunk = get_chunk_coord(relative_player_pos)
  var chunks_to_keep: Dictionary = {}

  for x in range(-render_distance, render_distance + 1):
    for y in range(-render_distance, render_distance + 1):
      var chunk_coord = Vector2i(player_chunk.x + x, player_chunk.y + y)
      chunks_to_keep[chunk_coord] = true
      if not loaded_chunks.has(chunk_coord):
        var is_new = not visited_chunks.has(chunk_coord)
        load_chunk(chunk_coord)
        if is_new:
          visited_chunks[chunk_coord] = true
          new_chunk_entered.emit(chunk_coord)

  # Unload distant chunks
  for chunk_coord in loaded_chunks.keys():
    if not chunks_to_keep.has(chunk_coord):
      unload_chunk(chunk_coord)

func load_chunk(chunk_coord: Vector2i) -> void:
  if loaded_chunks.has(chunk_coord):
    return

  var positions: Array[Vector2i] = []
  var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)

  var grass_count = get_grass_per_chunk()
  var cell_size = chunk_size / float(GRID_SIDE)

  var rng = RandomNumberGenerator.new()
  rng.seed = hash(chunk_coord)

  # Build all grid slots with randomized positions, then pick N
  var all_slots: Array = []
  for gx in GRID_SIDE:
    for gy in GRID_SIDE:
      var offset_x = rng.randf_range(-cell_size * 0.4, cell_size * 0.4)
      var offset_y = rng.randf_range(-cell_size * 0.4, cell_size * 0.4)
      var world_x = chunk_origin.x + gx * cell_size + cell_size * 0.5 + offset_x
      var world_y = chunk_origin.y + gy * cell_size + cell_size * 0.5 + offset_y
      all_slots.append(Vector2i(int(world_x), int(world_y)))

  # Shuffle with same seed so level-up adds new slots without moving existing ones
  var shuffle_rng = RandomNumberGenerator.new()
  shuffle_rng.seed = hash(chunk_coord) + 1
  for i in range(all_slots.size() - 1, 0, -1):
    var j = shuffle_rng.randi_range(0, i)
    var tmp = all_slots[i]
    all_slots[i] = all_slots[j]
    all_slots[j] = tmp

  # Activate first N slots
  for i in mini(grass_count, all_slots.size()):
      var grid_pos = all_slots[i]

      if not grass_data.has(grid_pos):
        var gd = GameManager.get_random_grass_data()
        var base_regen = gd.regen_time if gd else 5.0
        var hp_mult = GameManager.get_world_grass_hp_mult()
        var rw_mult = GameManager.get_world_grass_reward_mult()
        var scaled_hp = int(round((gd.max_health if gd else 1) * hp_mult))
        var scaled_value = int(round((randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1) * rw_mult))
        grass_data[grid_pos] = {
          "cut": false,
          "type": get_grass_type_index(gd),
          "health": scaled_hp,
          "max_health": scaled_hp,
          "regen_time": GameManager.get_grass_regen_time(base_regen),
          "regen_timer": 0.0,
          "value": scaled_value
        }
        positions.append(grid_pos)

  loaded_chunks[chunk_coord] = positions
  _mm_needs_rebuild = true

func unload_chunk(chunk_coord: Vector2i) -> void:
  if not loaded_chunks.has(chunk_coord):
    return

  var positions = loaded_chunks[chunk_coord]
  for grid_pos in positions:
    grass_data.erase(grid_pos)
    _cut_grass.erase(grid_pos)
    _active_timers.erase(grid_pos)

  loaded_chunks.erase(chunk_coord)
  _mm_needs_rebuild = true

func get_grass_type_index(gd: GrassData) -> int:
  if not gd:
    return 0
  for i in GameManager.grass_data_list.size():
    if GameManager.grass_data_list[i] == gd:
      return i
  return 0

func _mark_grass_cut(grid_pos: Vector2i) -> void:
  if grid_pos not in _cut_grass:
    _cut_grass.append(grid_pos)
  _mark_chunk_dirty(grid_pos)

func _mark_chunk_dirty(grid_pos: Vector2i) -> void:
  var chunk = get_chunk_coord(Vector2(grid_pos.x, grid_pos.y))
  _dirty_chunks[chunk] = true

func _add_active_timer(grid_pos: Vector2i) -> void:
  if grid_pos not in _active_timers:
    _active_timers.append(grid_pos)

func process_regen(delta: float) -> void:
  # Process active timers (hit flash, hp bar)
  var i = _active_timers.size() - 1
  while i >= 0:
    var grid_pos = _active_timers[i]
    if not grass_data.has(grid_pos):
      _active_timers.remove_at(i)
      i -= 1
      continue
    var data = grass_data[grid_pos]
    var still_active = false
    if data.has("crit_timer") and data.crit_timer > 0:
      data.crit_timer -= delta
      if data.crit_timer <= 0 and data.get("pending_particles", false):
        _spawn_instant_kill_particles(Vector2(grid_pos.x, grid_pos.y))
        data.pending_particles = false
      still_active = true
      _mark_chunk_dirty(grid_pos)
    if data.has("hit_timer") and data.hit_timer > 0:
      data.hit_timer -= delta
      if data.hit_timer <= 0 and data.get("pending_particles", false):
        _spawn_instant_kill_particles(Vector2(grid_pos.x, grid_pos.y))
        data.pending_particles = false
      still_active = true
      _mark_chunk_dirty(grid_pos)
    if data.has("hp_bar_timer") and data.hp_bar_timer > 0:
      data.hp_bar_timer -= delta
      _has_active_hp_bars = true
      still_active = true
    if not still_active:
      _active_timers.remove_at(i)
    i -= 1

  # Process cut grass regen
  i = _cut_grass.size() - 1
  while i >= 0:
    var grid_pos = _cut_grass[i]
    if not grass_data.has(grid_pos):
      _cut_grass.remove_at(i)
      i -= 1
      continue
    var data = grass_data[grid_pos]
    if not data.cut:
      _cut_grass.remove_at(i)
      i -= 1
      continue
    data.regen_timer += delta
    if data.regen_timer >= data.regen_time:
      var gd = GameManager.get_random_grass_data()
      var base_regen = gd.regen_time if gd else 5.0
      var hp_mult = GameManager.get_world_grass_hp_mult()
      var rw_mult = GameManager.get_world_grass_reward_mult()
      var scaled_hp = int(round((gd.max_health if gd else 1) * hp_mult))
      data.cut = false
      data.type = get_grass_type_index(gd)
      data.health = scaled_hp
      data.max_health = scaled_hp
      data.regen_time = GameManager.get_grass_regen_time(base_regen)
      data.regen_timer = 0.0
      data.value = int(round((randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1) * rw_mult))
      _cut_grass.remove_at(i)
      _mark_chunk_dirty(grid_pos)
    i -= 1


func _get_grass_color(grass_type: int) -> Color:
  # 황금풀(5): 월드 무관 샛노란색 + alpha 마커(셰이더 반짝이용)
  if grass_type == 5:
    return Color(1.0, 0.95, 0.1, 0.5)
  var world = GameManager.selected_world
  if world < WORLD_GRASS_COLORS.size() and WORLD_GRASS_COLORS[world] != null:
    var world_colors = WORLD_GRASS_COLORS[world]
    if grass_type < world_colors.size() and world_colors[grass_type] != null:
      return world_colors[grass_type]
  # 월드 오버라이드 없으면 GrassData 원본 사용
  var gd = GameManager.grass_data_list[grass_type] if grass_type < GameManager.grass_data_list.size() else null
  return gd.color if gd else Color(0.3, 0.7, 0.3)

func update_multimesh() -> void:
  if not _mm_needs_rebuild and _dirty_chunks.is_empty():
    return

  var visible_grass: Array = []
  var colors_list: Array = []
  var scales_list: Array = []
  var golden_positions: Array = []

  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut:
      # 크리 플래시: alpha 0.05 + 확대
      if data.get("crit_timer", 0.0) > 0:
        var world_pos = Vector2(grid_pos.x, grid_pos.y)
        visible_grass.append(world_pos)
        colors_list.append(Color(1.0, 1.0, 1.0, 0.05))
        var progress = 1.0 - (data.crit_timer / 0.2)
        scales_list.append(1.0 + progress * 0.8)
      # 비크리 즉사 플래시: alpha 0.25 (흰색)
      elif data.get("hit_timer", 0.0) > 0:
        var world_pos = Vector2(grid_pos.x, grid_pos.y)
        visible_grass.append(world_pos)
        colors_list.append(Color(1.0, 1.0, 1.0, 0.25))
        scales_list.append(1.0)
      continue

    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    visible_grass.append(world_pos)

    if data.has("crit_timer") and data.crit_timer > 0:
      # 크리티컬 플래시: alpha 0.05 마커 + 확대
      colors_list.append(Color(1.0, 1.0, 1.0, 0.05))
      var progress = 1.0 - (data.crit_timer / 0.2)
      scales_list.append(1.0 + progress * 0.8)
    elif data.has("hit_timer") and data.hit_timer > 0:
      # 피격 플래시: alpha 0.25 마커 → 셰이더에서 흰색 강제
      # 황금풀은 alpha 0.5 유지 (셰이더 황금색 경로)
      var flash_alpha = 0.5 if data.type == 5 else 0.25
      colors_list.append(Color(1.0, 1.0, 1.0, flash_alpha))
      scales_list.append(1.0)
    else:
      colors_list.append(_get_grass_color(data.type))
      scales_list.append(1.0)

    if data.type == 5:
      golden_positions.append(world_pos)

  multimesh.instance_count = visible_grass.size()

  for i in visible_grass.size():
    var t = Transform2D()
    var s = scales_list[i]
    if s != 1.0:
      t = t.scaled(Vector2(s, s))
    t.origin = visible_grass[i]
    multimesh.set_instance_transform_2d(i, t)
    multimesh.set_instance_color(i, colors_list[i])

  update_sparkles(golden_positions)
  _dirty_chunks.clear()
  _mm_needs_rebuild = false

func update_sparkles(golden_positions: Array) -> void:
  var total = golden_positions.size() * SPARKLES_PER_GOLDEN
  sparkle_mm.instance_count = total
  var idx = 0
  for gpos in golden_positions:
    # 위치 기반 시드로 안정적인 랜덤 오프셋
    var seed_val = hash(Vector2i(int(gpos.x), int(gpos.y)))
    for j in SPARKLES_PER_GOLDEN:
      var angle = fmod(float(seed_val + j * 2654435761) / 2147483647.0, 1.0) * TAU
      var dist = fmod(float(seed_val + j * 1013904223) / 2147483647.0, 1.0) * SPARKLE_RADIUS + 10.0
      var offset = Vector2(cos(angle) * dist, sin(angle) * dist - 20.0)
      var t = Transform2D()
      t.origin = gpos + offset
      sparkle_mm.set_instance_transform_2d(idx, t)
      sparkle_mm.set_instance_color(idx, Color(1.0, 1.0, 0.7, 1.0))
      idx += 1

# Locked targets: attack same grass until dead or out of range
var locked_targets: Array = []  # Array of Vector2i (grid positions)

# Called by player to attack grass in range
func attack_grass_in_area(center: Vector2, radius: float) -> Dictionary:
  var total_value = 0
  var hit_count = 0
  var total_max_health = 0
  var attacked_positions: Array = []
  var base_damage = WeaponManager.get_weapon_damage()
  var is_crit = randf() < GameManager.get_crit_chance()
  var damage = base_damage
  if is_crit:
    damage = roundi(base_damage * GameManager.get_crit_damage_mult())
  var max_targets = GameManager.get_attack_count()

  # Remove invalid locked targets (cut, out of range, unloaded)
  locked_targets = locked_targets.filter(func(grid_pos):
    if not grass_data.has(grid_pos):
      return false
    var data = grass_data[grid_pos]
    if data.cut:
      return false
    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    return center.distance_to(world_pos) <= radius
  )

  # Fill empty slots with new targets from nearby chunks
  if locked_targets.size() < max_targets:
    var candidates: Array = []
    var min_chunk = get_chunk_coord(center - Vector2(radius, radius))
    var max_chunk = get_chunk_coord(center + Vector2(radius, radius))
    for cx in range(min_chunk.x, max_chunk.x + 1):
      for cy in range(min_chunk.y, max_chunk.y + 1):
        var chunk_coord = Vector2i(cx, cy)
        if not loaded_chunks.has(chunk_coord):
          continue
        for grid_pos in loaded_chunks[chunk_coord]:
          if grid_pos in locked_targets:
            continue
          if not grass_data.has(grid_pos):
            continue
          var data = grass_data[grid_pos]
          if data.cut:
            continue
          var world_pos = Vector2(grid_pos.x, grid_pos.y)
          if center.distance_to(world_pos) <= radius:
            candidates.append(grid_pos)
    candidates.shuffle()
    var needed = mini(max_targets - locked_targets.size(), candidates.size())
    for i in needed:
      locked_targets.append(candidates[i])

  # Attack locked targets
  for i in locked_targets.size():
    var grid_pos = locked_targets[i]
    var data = grass_data[grid_pos]
    hit_count += 1
    var hp_before = data.health
    data.health -= damage
    if is_crit:
      data.crit_timer = 0.2
    else:
      data.hit_timer = 0.1
    _add_active_timer(grid_pos)
    if data.health > 0:
      data.hp_bar_timer = 1.5
      _add_active_timer(grid_pos)
    if data.health <= 0:
      var is_instant_kill = (hp_before == data.max_health)
      if is_instant_kill:
        data.pending_particles = true
        if not is_crit:
          data.hit_timer = 0.15
      data.cut = true
      data.regen_timer = 0.0
      _mark_grass_cut(grid_pos)
      total_value += data.value
      total_max_health += GameManager.grass_data_list[data.type].max_health
      attacked_positions.append(Vector2(grid_pos.x, grid_pos.y))
      if data.type == 5 and GameManager.session_buff_golden_luck:
        GameManager.golden_grass_cut.emit()

  # Critical hit + 크리티컬 리퍼 파워업: 범위 내 풀 30% 즉사
  if is_crit and hit_count > 0 and GameManager.session_buff_critical_reaper:
    var crit_kills = _crit_kill_percent(center, radius, 0.3, locked_targets)
    for ck in crit_kills:
      total_value += ck.value
      total_max_health += GameManager.grass_data_list[ck.type].max_health
      attacked_positions.append(Vector2(ck.grid_pos.x, ck.grid_pos.y))

  # Spawn coins for cut grass (GrassData.drop_chance / guaranteed_drop)
  for pos in attacked_positions:
    var grid_pos = Vector2i(int(pos.x), int(pos.y))
    if grass_data.has(grid_pos):
      var gd = GameManager.grass_data_list[grass_data[grid_pos].type]
      if gd.guaranteed_drop or randf() < GameManager.get_grass_drop_chance():
        var coin_value = grass_data[grid_pos].value
        # 황금풀(type 5)에 보상 배율 적용
        if grass_data[grid_pos].type == 5:
          coin_value = roundi(coin_value * GameManager.get_golden_reward_mult())
        spawn_coin(pos, coin_value)

  return {"value": total_value, "hit": hit_count > 0, "fury": total_max_health, "crit": is_crit and hit_count > 0}

func spawn_coin(pos: Vector2, value: int) -> void:
  var CoinScene = preload("res://scenes/world/coin.tscn")
  var coin = CoinScene.instantiate()
  coin.position = pos
  var final_value = int(round(value * GameManager.get_grass_reward_multiplier()))
  coin.set_value(max(1, final_value))
  get_parent().add_child(coin)


func _crit_kill_percent(center: Vector2, radius: float, percent: float, exclude: Array) -> Array:
  var candidates: Array = []
  var min_chunk = get_chunk_coord(center - Vector2(radius, radius))
  var max_chunk = get_chunk_coord(center + Vector2(radius, radius))
  for cx in range(min_chunk.x, max_chunk.x + 1):
    for cy in range(min_chunk.y, max_chunk.y + 1):
      var chunk_coord = Vector2i(cx, cy)
      if not loaded_chunks.has(chunk_coord):
        continue
      for grid_pos in loaded_chunks[chunk_coord]:
        if grid_pos in exclude:
          continue
        if not grass_data.has(grid_pos):
          continue
        var data = grass_data[grid_pos]
        if data.cut:
          continue
        var world_pos = Vector2(grid_pos.x, grid_pos.y)
        if center.distance_to(world_pos) <= radius:
          candidates.append(grid_pos)
  var kill_count = maxi(1, int(candidates.size() * percent))
  candidates.shuffle()
  var results: Array = []
  for i in mini(kill_count, candidates.size()):
    var grid_pos = candidates[i]
    var data = grass_data[grid_pos]
    data.crit_timer = 0.2
    data.pending_particles = true
    _add_active_timer(grid_pos)
    data.cut = true
    data.regen_timer = 0.0
    _mark_grass_cut(grid_pos)
    results.append({"grid_pos": grid_pos, "value": data.value, "type": data.type})
  return results


func _spawn_instant_kill_particles(world_pos: Vector2) -> void:
  var particles = CPUParticles2D.new()
  particles.position = world_pos
  particles.emitting = true
  particles.one_shot = true
  particles.amount = 8
  particles.lifetime = 0.4
  particles.explosiveness = 1.0
  particles.direction = Vector2(0, -1)
  particles.spread = 45.0
  particles.initial_velocity_min = 80.0
  particles.initial_velocity_max = 150.0
  particles.gravity = Vector2(0, 300)
  particles.scale_amount_min = 4.0
  particles.scale_amount_max = 7.0
  particles.color = Color(1.0, 0.9, 0.2)
  particles.finished.connect(particles.queue_free)
  add_child(particles)


func _on_golden_bloom() -> void:
  if not player:
    return
  var center = player.global_position - global_position
  var bloom_radius = GameManager.base_magnet_range
  var golden_data = GameManager.grass_data_list[5]
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut or data.type == 5:
      continue
    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    if center.distance_to(world_pos) <= bloom_radius:
      data.type = 5
      data.health = golden_data.max_health
      data.max_health = golden_data.max_health
      data.value = randi_range(golden_data.min_drop_value, golden_data.max_drop_value)
      _mark_chunk_dirty(grid_pos)

func _on_field_clear() -> void:
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut:
      continue
    data.cut = true
    data.regen_timer = 0.0
    _mark_grass_cut(grid_pos)
    var pos = Vector2(grid_pos.x, grid_pos.y)
    if data.type == 5 or randf() < GameManager.get_grass_drop_chance():
      spawn_coin(pos, data.value)

func _on_blackhole() -> void:
  var coins = get_tree().get_nodes_in_group("coins")
  for coin in coins:
    if is_instance_valid(coin) and not coin.is_collected:
      coin.is_being_collected = true

func _draw() -> void:
  # Draw chunk boundaries (debug only)
  if GameManager.debug_mode:
    for chunk_coord in loaded_chunks:
      var origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
      var rect = Rect2(origin, Vector2(chunk_size, chunk_size))
      draw_rect(rect, Color(1.0, 1.0, 1.0, 0.15), false, 2.0)

  if not _has_active_hp_bars:
    return
  var bar_width: float = 60.0
  var bar_height: float = 9.0
  var y_offset: float = -45.0
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut:
      continue
    if not data.has("hp_bar_timer") or data.hp_bar_timer <= 0:
      continue
    if data.health >= data.max_health:
      continue
    var hp_ratio: float = clampf(float(data.health) / float(data.max_health), 0.0, 1.0)
    var alpha: float = 1.0
    if data.hp_bar_timer < 0.5:
      alpha = data.hp_bar_timer / 0.5
    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    var bar_pos = world_pos + Vector2(-bar_width * 0.5, y_offset)
    # Background
    var bg_color = Color(0.2, 0.2, 0.2, alpha * 0.8)
    draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), bg_color)
    # Fill — green to red based on health
    var fill_color = Color(1.0 - hp_ratio, hp_ratio, 0.0, alpha)
    var fill_width = bar_width * hp_ratio
    if fill_width > 0:
      draw_rect(Rect2(bar_pos, Vector2(fill_width, bar_height)), fill_color)
