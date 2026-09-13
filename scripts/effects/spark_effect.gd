extends Node2D

var particles: Array = []  # [{pos, vel, alpha, lifetime, max_lifetime, length}]
var spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 0.2
const CORE_COLOR: Color = Color(1.0, 0.95, 0.8)
const GLOW_COLOR: Color = Color(1.0, 0.7, 0.2)

func _process(delta: float) -> void:
  spawn_timer -= delta
  if spawn_timer <= 0:
    spawn_timer = SPAWN_INTERVAL + randf() * 0.08
    _spawn_particles(randi_range(1, 2))

  var to_remove: Array = []
  for i in range(particles.size()):
    var p = particles[i]
    p.lifetime -= delta
    p.alpha = p.lifetime / p.max_lifetime
    # Move outward, decelerate
    p.pos += p.vel * delta
    p.vel = p.vel.lerp(Vector2.ZERO, 8.0 * delta)
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
    var speed = randf_range(60.0, 120.0)
    var vel = Vector2(cos(angle), sin(angle)) * speed
    var pos = Vector2(cos(angle), sin(angle)) * randf_range(18.0, 32.0)
    var lifetime = randf_range(0.05, 0.1)
    particles.append({
      "pos": pos,
      "vel": vel,
      "alpha": 1.0,
      "lifetime": lifetime,
      "max_lifetime": lifetime,
      "length": randf_range(4.0, 8.0),
    })

func _draw() -> void:
  for p in particles:
    var dir = p.vel.normalized() if p.vel.length() > 0.1 else Vector2.UP
    var end = p.pos + dir * p.length

    # Glow line
    var glow = GLOW_COLOR
    glow.a = p.alpha * 0.6
    draw_line(p.pos, end, glow, 1.5, true)

    # Core line
    var core = CORE_COLOR
    core.a = p.alpha
    draw_line(p.pos, end, core, 0.7, true)

    # End point
    draw_circle(end, 1.0, core)
