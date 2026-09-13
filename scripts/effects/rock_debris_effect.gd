extends Node2D

var particles: Array = []  # [{pos, vel, alpha, lifetime, max_lifetime, rect_size, rotation}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.35
const ROCK_COLORS: Array = [
  Color(0.45, 0.38, 0.28),  # grey-brown
  Color(0.45, 0.38, 0.28),  # grey-brown (higher weight)
  Color(0.35, 0.45, 0.25),  # mossy green
]

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.1
    _spawn_particles(randi_range(1, 2))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    p.alpha = p.lifetime / p.max_lifetime
    # Gravity
    p.vel.y += 120.0 * delta
    p.pos += p.vel * delta
    p.rotation += p.vel.x * 0.05 * delta
    if p.lifetime <= 0:
      to_remove.append(i)

  for i in range(to_remove.size() - 1, -1, -1):
    particles.remove_at(to_remove[i])

  queue_redraw()

func burst(intensity: int = 1) -> void:
  _spawn_particles(intensity * 4)

func stop() -> void:
  set_process(false)
  particles.clear()
  queue_redraw()

func _spawn_particles(count: int) -> void:
  for i in count:
    var angle = randf() * TAU
    var speed = randf_range(20.0, 50.0)
    var vel = Vector2(cos(angle) * speed, -randf_range(30.0, 60.0))  # upward launch
    var pos = Vector2(randf_range(-28.0, 28.0), randf_range(-14.0, 14.0))
    var lifetime = randf_range(0.4, 0.7)
    particles.append({
      "pos": pos,
      "vel": vel,
      "alpha": 1.0,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "rect_size": randf_range(2.0, 4.0),
      "rotation": randf() * TAU,
      "color_idx": randi() % ROCK_COLORS.size(),
    })

func _draw() -> void:
  for p in particles:
    var col = ROCK_COLORS[p.color_idx]
    col.a = p.alpha
    var s = p.rect_size
    # Draw rotated rect via transform
    draw_set_transform(p.pos, p.rotation, Vector2.ONE)
    draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), col)
  # Reset transform
  draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
