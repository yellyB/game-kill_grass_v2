extends SceneTree
## 헤드리스 시뮬 러너 — core/ 공식 호출. balance_sim.py와 패리티 검증용.
## 실행: godot --headless --script res://sim/run_sim.gd -- <scenario>
## 시나리오: skills(공식 덤프, 파이썬 대조) | (추후 session/full 추가)
const Skills = preload("res://core/skills.gd")
const Balance = preload("res://core/balance_data.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario := "skills"
	if args.size() > 0:
		scenario = args[0]
	match scenario:
		"skills":
			_scn_skills()
		_:
			print("unknown scenario: ", scenario)
	quit()

func _scn_skills() -> void:
	# 파이썬과 동일 포맷으로 스킬 공식 값 덤프 → diff로 패리티 확인
	print("# skill formula dump (core/skills.gd)")
	var ticks := [0, 1, 3, 5, 8, 10, 16, 25, 40]
	for t in ticks:
		var line := "t=%d" % t
		line += " aspd=%.3f" % Skills.attack_speed(t)
		line += " arange=%.1f" % Skills.attack_range(t)
		line += " acount=%d" % Skills.attack_count(t)
		line += " dens=%d" % Skills.density(t)
		line += " apow=%d" % Skills.attack_power(t)
		line += " cc=%.3f" % Skills.crit_chance(t)
		line += " cm=%.3f" % Skills.crit_mult(t)
		line += " gdmg=%.3f" % Skills.goomok_dmg(t)
		line += " move=%.1f" % Skills.move(t)
		line += " sess=%.3f" % Skills.session(t)
		line += " gold=%.4f" % Skills.golden(t)
		line += " magnet=%.2f" % Skills.magnet(t)
		var d: Array = Skills.quality_dist(t)
		line += " qdist=[%.3f,%.3f,%.3f,%.3f,%.3f]" % [d[0], d[1], d[2], d[3], d[4]]
		print(line)
	print("# tick_cost dump")
	for sk in ["attack_power", "grass_density", "attack_count", "golden_chance"]:
		var costs := []
		for t in range(0, mini(Skills.max_ticks(sk), 12)):
			costs.append(Skills.tick_cost(sk, t))
		print("%s: %s" % [sk, str(costs)])
