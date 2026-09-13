extends Node2D

const MonsterScene = preload("res://scenes/world/monster.tscn")
const ChestScene = preload("res://scenes/world/chest.tscn")

const BOSS_NAMES: Array = ["슬라임", "멧돼지", "잔디 기사", "마도사", "수정 사슴", "잔디 골렘", "드래곤"]

const FURY_BOSS_TYPES: Dictionary = {
  0: {
    "type": "slime",
    "sprite_path": "res://resources/images/monster/slime/",
    "max_health": 60,
    "wander_speed": 50,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/lightning_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/slime.tres",
    "collision_base_scale": 0.24,
    "collision_rotation": PI / 2.0,
  },
  1: {
    "type": "boar",
    "sprite_path": "res://resources/images/monster/boar/",
    "max_health": 230,
    "wander_speed": 60,
    "sprite_scale": 1.08,
    "effect_scene": "res://scenes/effects/dust_cloud_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/boar.tres",
    "collision_base_scale": 0.46,
    "collision_rotation": PI / 2.0,
  },
  2: {
    "type": "knight",
    "sprite_path": "res://resources/images/monster/knight/",
    "max_health": 1400,
    "wander_speed": 48,
    "sprite_scale": 0.84,
    "effect_scene": "res://scenes/effects/spark_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/knight.tres",
    "collision_base_scale": 0.36,
  },
  3: {
    "type": "mage",
    "sprite_path": "res://resources/images/monster/mage/",
    "max_health": 5800,
    "wander_speed": 54,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/spore_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/mage.tres",
    "collision_base_scale": 0.24,
  },
  4: {
    "type": "deer",
    "sprite_path": "res://resources/images/monster/deer/",
    "max_health": 31500,
    "wander_speed": 72,
    "sprite_scale": 0.84,
    "effect_scene": "res://scenes/effects/crystal_shimmer_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/deer.tres",
    "collision_base_scale": 0.36,
  },
  5: {
    "type": "golem",
    "sprite_path": "res://resources/images/monster/golem/",
    "max_health": 58000,
    "wander_speed": 40,
    "sprite_scale": 0.96,
    "effect_scene": "res://scenes/effects/rock_debris_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/golem.tres",
    "collision_base_scale": 0.48,
  },
  6: {
    "type": "dragon",
    "sprite_path": "res://resources/images/monster/dragon/",
    "max_health": 145000,
    "wander_speed": 80,
    "sprite_scale": 1.20,
    "effect_scene": "res://scenes/effects/fire_wisp_effect.tscn",
    "penalty_min": 0,
    "penalty_max": 0,
    "spawn_weight": 1,
    "collision_shape": "res://resources/collision/dragon.tres",
    "collision_base_scale": 0.60,
  },
}

# 청크당 상자 스폰 확률 (~10세션에 1개 = 1/(30청크*10세션) ≈ 0.003)
const CHEST_CHUNK_CHANCE: float = 0.0
var fury_boss_alive: bool = false

var player: Node2D = null
var grass_spawner: Node2D = null

func _ready() -> void:
  # Connect chest spawning signal early so initial chunks are included
  grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
  if not grass_spawner:
    grass_spawner = get_parent().get_node_or_null("GrassSpawner")
  if grass_spawner and grass_spawner.has_signal("new_chunk_entered"):
    grass_spawner.new_chunk_entered.connect(_on_new_chunk_entered)
  call_deferred("_find_player")
  GameManager.fury_boss_requested.connect(_on_fury_boss_requested)

func _find_player() -> void:
  player = get_tree().get_first_node_in_group("player")

func _on_new_chunk_entered(chunk_coord: Vector2i) -> void:
  var chest_chance = GameManager.get_chest_spawn_chance()
  if chest_chance <= 0.0 or randf() > chest_chance:
    return
  _spawn_chest_at_chunk(chunk_coord)

func _spawn_chest_at_chunk(chunk_coord: Vector2i) -> void:
  var chunk_size = 400.0
  if grass_spawner:
    chunk_size = grass_spawner.chunk_size
  var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
  var pos = chunk_origin + Vector2(randf() * chunk_size, randf() * chunk_size)

  var chest = ChestScene.instantiate()
  chest.position = pos
  get_parent().add_child(chest)

# 보스 처치 보상 (클리어 후 반복 플레이 시 코인 보상, 고정값)
const BOSS_CLEAR_REWARDS: Array = [50, 700, 3000, 15000, 50000, 140000, 350000]

const LAST_WORLD_POTION: String = "황금 왕관"

func _is_world_cleared(world: int) -> bool:
  return GameManager.is_world_cleared(world)

func _on_fury_boss_requested() -> void:
  if fury_boss_alive:
    return
  var world = GameManager.selected_world
  if not FURY_BOSS_TYPES.has(world):
    return
  var config = FURY_BOSS_TYPES[world].duplicate()
  config["is_fury_boss"] = true
  config["boss_name"] = BOSS_NAMES[world] if world < BOSS_NAMES.size() else ""
  var is_last = world + 1 >= GameManager.WORLD_UNLOCK_COSTS.size()
  if _is_world_cleared(world):
    # 이미 클리어한 월드: 코인 보상 (초월 배율 적용)
    var reward = BOSS_CLEAR_REWARDS[world] if world < BOSS_CLEAR_REWARDS.size() else 0
    var strength = GameManager.get_world_strength_level(world)
    if strength > 0:
      var mult = GameManager.STRENGTH_MULTIPLIERS[clampi(strength, 0, GameManager.STRENGTH_MULTIPLIERS.size() - 1)]
      reward = int(reward * mult)
    config["boss_reward"] = reward
    # 초월 보상: 미수집 초월 레벨의 보석만 드롭 (레벨당 1회)
    if strength > 0 and not GameManager.has_collected_gems(world, strength):
      config["boss_gems"] = strength
  elif is_last:
    # 마지막 월드 첫 클리어: 황금 왕관 드롭
    config["boss_potion"] = LAST_WORLD_POTION
  elif world + 1 < GameManager.WORLD_UNLOCK_COSTS.size():
    # 첫 클리어: 다음 월드 열쇠 드롭
    config["key_world_index"] = world + 1
  var monster = MonsterScene.instantiate()
  monster.setup(config)
  # 보스 위치: 플레이어 위쪽 (화면 상단 ~20% 지점)
  var player_local = get_parent().to_local(player.global_position) if player else Vector2.ZERO
  var viewport_size = get_viewport().get_visible_rect().size
  var boss_y_offset = -viewport_size.y * 0.3  # 플레이어 위쪽으로 화면 30%
  monster.position = player_local + Vector2(0, boss_y_offset)
  # 씬 추가 전에 보스 등장 상태 설정 (움직임 방지)
  monster.is_boss_entering = true
  monster.visible = false
  fury_boss_alive = true
  GameManager.fury_boss_alive = true
  monster.tree_exited.connect(func():
    fury_boss_alive = false
    GameManager.fury_boss_alive = false
  )
  get_parent().add_child(monster)
  # 1초 멈춤 + 보스 등장 애니메이션
  _play_boss_entrance(monster)

func _play_boss_entrance(monster: Node2D) -> void:
  get_tree().paused = true
  monster.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
  # 게이지 애니메이션 완료 대기
  await GameManager.fury_gauge_dismissed
  # 보스 등장 애니메이션 (0.6초)
  monster.visible = true
  monster.play_boss_entrance()
  await get_tree().create_timer(0.6).timeout
  # 1초 멈춤 후 게임 재개
  await get_tree().create_timer(1.0).timeout
  monster.is_boss_entering = false
  monster.process_mode = Node.PROCESS_MODE_INHERIT
  get_tree().paused = false
  monster.queue_redraw()
