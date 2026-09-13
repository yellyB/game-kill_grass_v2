extends Node2D

@export var value: int = 1
@export var magnet_speed: float = 600.0
@export var pickup_delay: float = 0.3

var player: Node2D = null
var can_pickup: bool = false
var is_being_collected: bool = false
var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var boss_drop: bool = false

@onready var visual: Node2D = $Visual

func _ready() -> void:
  add_to_group("coins")

  # Find player
  player = get_tree().get_first_node_in_group("player")

  # Apply color based on value (set_value may be called before add_child)
  update_visual()

  # Spawn animation - pop out
  spawn_animation()

  if boss_drop:
    return  # Visual only, self-destructs via animation

  # Enable pickup after delay
  await get_tree().create_timer(pickup_delay).timeout
  can_pickup = true

func _process(delta: float) -> void:
  if not can_pickup or not player:
    return

  # Convert player position to local coordinate space (WorldRoot)
  var player_local_pos = get_parent().to_local(player.global_position)
  var distance_to_player = position.distance_to(player_local_pos)
  var magnet_range = GameManager.get_magnet_range()

  if distance_to_player < magnet_range or is_being_collected:
    is_being_collected = true
    # Move towards player
    var direction = (player_local_pos - position).normalized()
    var speed = magnet_speed * (1.0 + (magnet_range - min(distance_to_player, magnet_range)) / magnet_range)
    position += direction * speed * delta

    # Pickup when close enough
    if distance_to_player < 30.0:
      collect()

  # Bobbing animation
  if visual:
    visual.position.y = sin(Time.get_ticks_msec() * 0.008) * 3.0

func spawn_animation() -> void:
  if boss_drop:
    _boss_spawn_animation()
    return

  # Random pop direction
  var pop_direction = Vector2(randf_range(-1, 1), randf_range(-1, -0.5)).normalized()
  var pop_distance = randf_range(30, 60)

  var start_pos = position
  var peak_pos = start_pos + pop_direction * pop_distance

  # Scale pop
  if visual:
    visual.scale = Vector2(0.3, 0.3)

  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(self, "position", peak_pos, 0.15).set_ease(Tween.EASE_OUT)
  if visual:
    tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)

  await tween.finished

  if visual:
    var tween2 = create_tween()
    tween2.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)

func _boss_spawn_animation() -> void:
  var spread_x = randf_range(-280, 280)
  var peak_y = randf_range(-260, -180)
  var start_pos = position

  if visual:
    visual.scale = Vector2(0.75, 0.75)

  # X: linear outward spread
  var tween_x = create_tween()
  tween_x.tween_property(self, "position:x", start_pos.x + spread_x, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

  # Y: parabolic arc (up then down)
  var tween_y = create_tween()
  tween_y.tween_property(self, "position:y", start_pos.y + peak_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween_y.tween_property(self, "position:y", start_pos.y + 80, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

  # Scale pop
  if visual:
    var tween_s = create_tween()
    tween_s.tween_property(visual, "scale", Vector2(1.8, 1.8), 0.15).set_ease(Tween.EASE_OUT)
    tween_s.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.1)

  # Fade out in second half
  var tween_fade = create_tween()
  tween_fade.tween_interval(0.35)
  tween_fade.tween_property(self, "modulate:a", 0.0, 0.35)
  tween_fade.tween_callback(queue_free)

func collect() -> void:
  # Prevent multiple collections
  if is_collected:
    return
  is_collected = true

  # Add money (gold rush doubles coins)
  var actual_value = value * GameManager.get_coin_multiplier()
  GameManager.add_money(actual_value)

  # Accumulate floating text on player
  if player and player.has_method("accumulate_coin_text"):
    player.accumulate_coin_text(actual_value)

  # Collect effect
  if visual:
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(visual, "modulate:a", 0.0, 0.1)
    await tween.finished

  queue_free()

func set_value(new_value: int) -> void:
  value = new_value
  update_visual()

func update_visual() -> void:
  if not visual:
    return

  # Color based on value
  var coin_color: Color
  var shine_color: Color
  if value >= 1000:
    coin_color = Color(0.5, 0.8, 1.0) # Diamond - bright sky blue
    shine_color = Color(0.7, 0.9, 1.0, 0.8)
  elif value >= 500:
    coin_color = Color(1.0, 0.85, 0.0) # Gold - bright yellow
    shine_color = Color(1.0, 1.0, 0.6, 0.7)
  elif value >= 100:
    coin_color = Color(0.75, 0.78, 0.85) # Silver - cool gray-blue
    shine_color = Color(0.9, 0.92, 1.0, 0.6)
  else:
    coin_color = Color(0.85, 0.55, 0.25) # Bronze - bright copper
    shine_color = Color(1.0, 0.75, 0.4, 0.6)

  # 3개 쌓임 조건: 각 등급의 절반 금액 이상 (다이아 제외)
  var is_stacked: bool = false
  if value >= 1000:
    is_stacked = false  # 다이아는 스택 없음
  elif value >= 500:
    is_stacked = value >= 750
  elif value >= 100:
    is_stacked = value >= 300
  else:
    is_stacked = value >= 50

  # 기존 스택 복제본 제거
  for child in visual.get_children():
    if child.name.begins_with("StackCoin"):
      child.queue_free()

  var coin_body = visual.get_node_or_null("CoinBody")
  var coin_shine = visual.get_node_or_null("CoinShine")
  var coin_shadow_arc = visual.get_node_or_null("CoinShadowArc")

  var is_diamond = value >= 1000
  var diamond_polygon = PackedVector2Array([Vector2(-7, -10), Vector2(7, -10), Vector2(12, -3), Vector2(0, 14), Vector2(-12, -3)])

  if coin_body:
    coin_body.color = coin_color
    if is_diamond:
      coin_body.polygon = diamond_polygon
  if coin_shine:
    coin_shine.visible = false
  # Inner shadow arc (9~12 o'clock)
  var shadow_color = Color(coin_color.r * 0.7, coin_color.g * 0.7, coin_color.b * 0.7, 0.6)
  if not coin_shadow_arc:
    coin_shadow_arc = Line2D.new()
    coin_shadow_arc.name = "CoinShadowArc"
    coin_shadow_arc.width = 3.0
    coin_shadow_arc.z_index = 1
    visual.add_child(coin_shadow_arc)
  coin_shadow_arc.default_color = shadow_color
  coin_shadow_arc.visible = not is_diamond
  # Extract 9~12 o'clock vertices from coin polygon and scale inward by 10%
  var arc_points = PackedVector2Array()
  if coin_body:
    var poly = coin_body.polygon
    # 8시(-10,5) → 9시(-10,-5) → (-8,-9) → 12시(-3,-11) → 1시(3,-11): indices 11,0,1,2,3
    for idx in [11, 0, 1, 2, 3]:
      if idx < poly.size():
        arc_points.append(poly[idx] * 0.65)
  coin_shadow_arc.points = arc_points

  # 3개 쌓인 코인: 피라미드 (아래 2개 + 위 1개), 외곽선으로 구분
  if is_stacked and coin_body:
    var edge_color = Color(coin_color.r * 0.4, coin_color.g * 0.4, coin_color.b * 0.4, 0.8)
    # 메인 코인을 위쪽 중앙으로 이동
    coin_body.position = Vector2(0, -8)
    if coin_shadow_arc:
      coin_shadow_arc.position = Vector2(0, -8)
    # 아래 2개 코인 (좌, 우)
    var bottom_offsets = [Vector2(-9, 6), Vector2(9, 6)]
    for i in 2:
      # 코인 몸체
      var stack = Polygon2D.new()
      stack.name = "StackCoin%d" % i
      stack.polygon = coin_body.polygon
      stack.color = coin_color
      stack.position = bottom_offsets[i]
      visual.add_child(stack)
      visual.move_child(stack, 0)
      # 외곽선
      var outline = Line2D.new()
      outline.name = "StackOutline%d" % i
      var pts = coin_body.polygon.duplicate()
      pts.append(pts[0])  # 닫기
      outline.points = pts
      outline.width = 1.2
      outline.default_color = edge_color
      outline.position = bottom_offsets[i]
      visual.add_child(outline)
      visual.move_child(outline, 0)  # 메인 코인 뒤로
    # 메인 코인 외곽선
    var main_outline = Line2D.new()
    main_outline.name = "StackCoin_main_outline"
    var main_pts = coin_body.polygon.duplicate()
    main_pts.append(main_pts[0])
    main_outline.points = main_pts
    main_outline.width = 1.2
    main_outline.default_color = edge_color
    main_outline.position = coin_body.position
    visual.add_child(main_outline)
