extends Node2D

signal health_changed(current: int, max_hp: int)

const DroppedItemScene = preload("res://scenes/world/dropped_item.tscn")
const PowerupScene = preload("res://scenes/world/powerup.tscn")
const CoinScene = preload("res://scenes/world/coin.tscn")
const SFX_SLASH = preload("res://resources/sounds/effect/monster_slash.wav")
const SFX_DEATH = preload("res://resources/sounds/effect/monster_death.wav")

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D

static var _texture_cache: Dictionary = {}
var textures: Array[Texture2D] = []

# Configurable via setup()
var sprite_path: String = "res://resources/images/monster/slime/"
var effect_scene_path: String = ""
var effect_node: Node2D = null
# Animation
const FRAME_DURATION: float = 0.18
var frame_timer: float = 0.0
var sequence_index: int = 0
var anim_sequence: Array = [0, 1, 2, 3]
var idle_frame_count: int = 4  # idle 프레임 수 (기본: 4)
var hit_frame_start: int = 4  # 피격 프레임 시작 인덱스 (기본: 4)
var hit_frame_count: int = 1  # 피격 프레임 수 (기본: 1, 고통 프레임만)
var is_hit_animating: bool = false
var hit_anim_timer: float = 0.0
const HIT_FRAME_DURATION: float = 0.18  # 피격 표시 시간
var wander_speed: float = 40.0

# Health (placeholder)
var max_health: int = 1
var health: int = 1
var penalty_min: int = 5
var penalty_max: int = 10
var sprite_scale: float = 0.24
var collision_shape_path: String = ""
var collision_base_scale: float = 0.0
var collision_rotation: float = 0.0
var key_world_index: int = -1  # >= 0 이면 사망 시 해당 월드 열쇠 드롭
var boss_reward: int = 0  # > 0 이면 사망 시 해당 금액 코인 드롭 (클리어 후 보상)
var _cached_player: Node2D = null
var boss_gems: int = 0  # > 0 이면 사망 시 보석 드롭 (초월 보상)
var boss_potion: String = ""  # 비어있지 않으면 사망 시 해당 아이템 드롭
var is_fury_boss: bool = false  # 분노 보스 여부 (사망 시 세션 종료)
var is_boss_entering: bool = false  # 보스 등장 애니메이션 중
var boss_name: String = ""
var sfx_hit: AudioStreamPlayer

func setup(config: Dictionary) -> void:
  sprite_path = config.sprite_path
  max_health = config.max_health
  health = config.max_health
  wander_speed = config.wander_speed
  effect_scene_path = config.get("effect_scene", "")
  penalty_min = config.get("penalty_min", 5)
  penalty_max = config.get("penalty_max", 10)
  sprite_scale = config.get("sprite_scale", 0.24)
  collision_shape_path = config.get("collision_shape", "")
  collision_base_scale = config.get("collision_base_scale", 0.0)
  collision_rotation = config.get("collision_rotation", 0.0)
  idle_frame_count = config.get("idle_frame_count", 4)
  hit_frame_start = config.get("hit_frame_start", 4)
  hit_frame_count = config.get("hit_frame_count", 1)
  # idle 시퀀스: config에 지정되어 있으면 사용, 아니면 순차 재생
  anim_sequence = config.get("anim_sequence", range(idle_frame_count))
  key_world_index = config.get("key_world_index", -1)
  boss_reward = config.get("boss_reward", 0)
  boss_gems = config.get("boss_gems", 0)
  boss_potion = config.get("boss_potion", "")
  is_fury_boss = config.get("is_fury_boss", false)
  boss_name = config.get("boss_name", "")

func _ready() -> void:
  add_to_group("monsters")
  sfx_hit = AudioStreamPlayer.new()
  sfx_hit.stream = SFX_SLASH
  sfx_hit.volume_db = -3.0
  add_child(sfx_hit)
  _load_textures()
  if sprite and not textures.is_empty():
    sprite.texture = textures[0]
    sprite.scale = Vector2(sprite_scale, sprite_scale)
  if shadow and not textures.is_empty():
    shadow.texture = textures[0]
    shadow.scale = Vector2(sprite_scale * 0.67, sprite_scale * 0.25)
  # Load collision shape from .tres resource
  if collision_shape_path != "":
    var shape_res = load(collision_shape_path)
    hit_shape.shape = shape_res.duplicate()
    hit_shape.rotation = collision_rotation
    # Scale collision for bosses: .tres is designed at base sprite_scale
    if collision_base_scale > 0 and abs(sprite_scale - collision_base_scale) > 0.001:
      var s = sprite_scale / collision_base_scale
      hit_shape.scale = Vector2(s, s)
  # Dynamically load effect scene
  if effect_scene_path != "":
    var scene = load(effect_scene_path)
    if scene:
      effect_node = scene.instantiate()
      var effect_scale = sprite_scale / 0.24
      effect_node.scale = Vector2(effect_scale, effect_scale)
      add_child(effect_node)

func _load_textures() -> void:
  if _texture_cache.has(sprite_path):
    textures = _texture_cache[sprite_path].duplicate()
    return
  var total = idle_frame_count + hit_frame_count
  for i in range(1, total + 1):
    var path = "%s%d.png" % [sprite_path, i]
    var tex = _load_texture_from_file(path)
    if tex:
      textures.append(tex)
  _texture_cache[sprite_path] = textures.duplicate()

func _load_texture_from_file(res_path: String) -> Texture2D:
  var tex = load(res_path)
  if tex:
    return tex
  return null

func _process(delta: float) -> void:
  if is_boss_entering:
    return

  # Hit animation (overrides idle)
  if is_hit_animating:
    hit_anim_timer += delta
    if hit_anim_timer >= HIT_FRAME_DURATION:
      # 피격 애니메이션 종료, idle 프레임 복귀
      is_hit_animating = false
      hit_anim_timer = 0.0
      var idle_fi = anim_sequence[sequence_index]
      if idle_fi < textures.size():
        sprite.texture = textures[idle_fi]
  else:
    # Idle animation
    frame_timer += delta
    if frame_timer >= FRAME_DURATION:
      frame_timer = 0.0
      _advance_frame()

  # Knockback
  if knockback_velocity.length() > 1.0:
    position += knockback_velocity * delta
    knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
    return

  # Chase player (cached reference)
  if not is_instance_valid(_cached_player):
    _cached_player = get_tree().get_first_node_in_group("player")
  var player = _cached_player
  if player:
    var player_local = get_parent().to_local(player.global_position)
    var dir = (player_local - position).normalized()
    position += dir * wander_speed * delta

func _advance_frame() -> void:
  if textures.is_empty():
    return
  sequence_index = (sequence_index + 1) % anim_sequence.size()
  var frame_index = anim_sequence[sequence_index]
  if frame_index < textures.size():
    sprite.texture = textures[frame_index]

var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 5.0

func play_boss_entrance() -> void:
  is_boss_entering = true
  # 스프라이트를 위로 올려놓고 떨어뜨리기
  var drop_height = -600.0
  sprite.position.y = drop_height
  if shadow:
    shadow.modulate.a = 0.1
    shadow.scale = Vector2(sprite_scale * 0.2, sprite_scale * 0.08)
  # 히트박스 비활성화 (착지까지)
  hit_area.set_deferred("monitoring", false)
  hit_area.set_deferred("monitorable", false)

  # 등장부터 착지 직후까지 진동 (0.6초 낙하 + 0.4초 여운)
  GameManager.vibrate(1000)

  # 떨어지는 애니메이션
  var tween = create_tween()
  tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.set_parallel(true)
  tween.tween_property(sprite, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  if shadow:
    tween.tween_property(shadow, "scale", Vector2(sprite_scale * 0.67, sprite_scale * 0.25), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(shadow, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

  await tween.finished

  # 착지: 카메라 흔들림
  var camera = get_tree().get_first_node_in_group("camera")
  if camera and camera.has_method("shake"):
    camera.shake(0.8)

  # 히트박스 활성화 (행동 시작은 spawner가 is_boss_entering을 해제)
  hit_area.set_deferred("monitoring", true)
  hit_area.set_deferred("monitorable", true)

func take_damage(amount: int, from_global_pos: Variant = null) -> void:
  if is_dead or is_boss_entering:
    return
  health -= amount
  if GameManager.sfx_enabled:
    sfx_hit.play()
  # Knockback away from attacker
  if from_global_pos is Vector2:
    var knock_dir = (global_position - from_global_pos).normalized()
    knockback_velocity = knock_dir * GameManager.get_monster_knockback_strength()
  # Hit flash
  sprite.modulate = Color(1, 0.3, 0.3)
  var tween = create_tween()
  tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
  # Hit sprite animation — 피격(고통) 이미지 표시
  if hit_frame_start >= 0 and hit_frame_start < textures.size():
    is_hit_animating = true
    hit_anim_timer = 0.0
    sprite.texture = textures[hit_frame_start]
  # Effect burst on hit
  if effect_node and effect_node.has_method("burst"):
    effect_node.burst(2)
  health_changed.emit(health, max_health)
  if is_fury_boss:
    queue_redraw()
  if health <= 0:
    die()

func die() -> void:
  is_dead = true
  remove_from_group("monsters")
  set_process(false)

  # Play death sound (on root so it persists after queue_free)
  if GameManager.sfx_enabled:
    var sfx = AudioStreamPlayer.new()
    sfx.stream = SFX_DEATH
    sfx.volume_db = -3.0
    get_tree().root.add_child(sfx)
    sfx.play()
    sfx.finished.connect(sfx.queue_free)

  # Effect burst on death
  if effect_node and effect_node.has_method("burst"):
    effect_node.burst(3)

  # Death effect: slight expand → shake + fade out
  sprite.modulate = Color(1.5, 1.5, 1.5, 1)  # Brief flash

  # Phase 1: Slightly expand (0.1s)
  var tween = create_tween()
  tween.set_parallel(true)
  var death_scale = sprite_scale * 1.33
  tween.tween_property(sprite, "scale", Vector2(death_scale, death_scale), 0.1).set_ease(Tween.EASE_OUT)
  tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.08)
  await tween.finished

  # Phase 2: Shake + fade out (0.35s)
  var tween2 = create_tween()
  tween2.set_parallel(true)
  tween2.tween_property(sprite, "modulate:a", 0.0, 0.35)
  if shadow:
    tween2.tween_property(shadow, "modulate:a", 0.0, 0.25)

  # Shake effect
  var shake_tween = create_tween()
  for i in 5:
    var offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
    shake_tween.tween_property(sprite, "position", offset, 0.035)
    shake_tween.tween_property(sprite, "position", Vector2.ZERO, 0.035)

  # Stop effect
  if effect_node and effect_node.has_method("stop"):
    effect_node.stop()

  await tween2.finished

  if key_world_index >= 0:
    _drop_key()
  elif boss_potion != "":
    _drop_potion()
  elif boss_reward > 0 or boss_gems > 0:
    _drop_boss_reward()
  elif is_fury_boss:
    # 분노 보스: 드롭 없이 세션 종료
    GameManager.boss_key_collected.emit(-1)
  else:
    # 30% chance to drop a powerup
    if randf() < 0.3:
      var powerup = PowerupScene.instantiate()
      powerup.position = position
      get_parent().add_child(powerup)

  queue_free()

func _drop_boss_reward() -> void:
  if boss_reward > 0:
    GameManager.session_boss_reward = boss_reward
    GameManager.add_money(boss_reward)
    # Spawn 7 visual-only coins that spray upward in arcs
    var coin_count = 7
    for i in coin_count:
      var coin = CoinScene.instantiate()
      coin.position = position
      coin.boss_drop = true
      get_parent().add_child(coin)

  # 보석 드롭 (초월 보상)
  if boss_gems > 0:
    if not is_instance_valid(_cached_player):
      _cached_player = get_tree().get_first_node_in_group("player")
    var player = _cached_player
    if player:
      for i in boss_gems:
        var item = DroppedItemScene.instantiate()
        item.setup_gem(player, GameManager.selected_world, boss_gems)
        item.position = position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
        get_parent().add_child(item)

  # 1s delay for spray animation, then end session
  get_tree().create_timer(1.0).timeout.connect(func():
    GameManager.boss_key_collected.emit(-1)
  )

func _drop_potion() -> void:
  if not is_instance_valid(_cached_player):
    _cached_player = get_tree().get_first_node_in_group("player")
  var player = _cached_player
  if not player:
    return
  var item = DroppedItemScene.instantiate()
  item.setup_potion(boss_potion, player)
  item.ends_session = true
  item.position = position
  get_parent().add_child(item)

func _drop_key() -> void:
  if not is_instance_valid(_cached_player):
    _cached_player = get_tree().get_first_node_in_group("player")
  var player = _cached_player
  if not player:
    return
  var item = DroppedItemScene.instantiate()
  item.setup_key(key_world_index, player)
  item.ends_session = true
  item.position = position
  get_parent().add_child(item)

func _draw() -> void:
  if not is_fury_boss or is_dead or is_boss_entering:
    return

  # 스프라이트 위에 체력바 위치 계산
  var tex_h = 0.0
  if sprite and sprite.texture:
    tex_h = sprite.texture.get_height() * sprite_scale / 2.0
  var bar_width = 140.0
  var bar_height = 10.0
  var bar_y = -(tex_h + 20)
  var bar_x = -bar_width / 2.0

  # 배경 (어두운)
  draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2), Color(0, 0, 0, 0.7))
  # 체력 fill (빨간색)
  var fill_ratio = clampf(float(health) / float(max_health), 0.0, 1.0) if max_health > 0 else 0.0
  if fill_ratio > 0:
    draw_rect(Rect2(bar_x, bar_y, bar_width * fill_ratio, bar_height), Color(0.85, 0.15, 0.1))

  # 보스 이름 (체력바 위)
  if boss_name != "":
    var font = ThemeDB.fallback_font
    var font_size = 24
    var text_size = font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var text_pos = Vector2(-text_size.x / 2.0, bar_y - 8)
    draw_string_outline(font, text_pos, boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0))
    draw_string(font, text_pos, boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.9, 0.85))
