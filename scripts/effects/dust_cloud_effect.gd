extends Node2D

var particles: Array = []  # [{pos, radius, alpha, lifetime, max_lifetime, grow_rate}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.25
const BASE_COLOR: Color = Color(0.65, 0.55, 0.35, 0.5)

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.1
    _spawn_particles(randi_range(2, 3))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    var t = 1.0 - (p.lifetime / p.max_lifetime)
    p.radius = lerpf(3.0, p.grow_rate, t)
    p.alpha = lerpf(0.5, 0.0, t)
    p.pos.y -= 8.0 * delta  # drift upward slowly
    if p.lifetime <= 0:
      to_remove.append(i)

  for i in range(to_remove.size() - 1, -1, -1):
    particles.remove_at(to_remove[i])

  queue_redraw()

func burst(intensity: int = 1) -> void:
  _spawn_particles(intensity * 3)

func stop() -> void:
  set_process(false)
  particles.clear()
  queue_redraw()

func _spawn_particles(count: int) -> void:
  for i in count:
    var angle = randf() * TAU
    var dist = randf_range(10.0, 34.0)
    var pos = Vector2(cos(angle) * dist, 26.0 + randf_range(-5.0, 5.0))  # lower area
    var lifetime = randf_range(0.3, 0.5)
    particles.append({
      "pos": pos,
      "radius": 5.0,
      "alpha": 0.5,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "grow_rate": randf_range(16.0, 24.0),
    })

func _draw() -> void:
  for p in particles:
    var col = BASE_COLOR
    col.a = p.alpha
    draw_circle(p.pos, p.radius, col)
