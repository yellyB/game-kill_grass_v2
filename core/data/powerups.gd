extends RefCounted
## 파워업(지속) 33 + 아이템(즉발) 17 = 50종 데이터. balance_sim.py PU + powerups.md 포팅.
## effect 키: dmg/iv/R/v/val/D=스택당 승수 | vadd/cc/cm/gc=스택당 가산 | 플래그(문자열 true)
## kind: "powerup"(레벨업 3택) | "item"(컨테이너/상점→슬롯→발동)

# [type, ko이름, rarity, weight, max_stacks, kind, effect]
const LIST := [
	# ── 공격 ──
	["sharp_blade", "예리한 날", "common", 20, 5, "powerup", {"dmg": 1.15}],
	["pu_attack_speed", "어택 부스트", "common", 20, 5, "powerup", {"iv": 0.892857}],  # 1/1.12
	["pu_attack_range", "와이드 스윙", "common", 20, 5, "powerup", {"R": 1.15}],
	["timber", "벌목", "uncommon", 10, 5, "powerup", {"goomok": 1.30}],
	["chain_reaction", "연쇄 반응", "rare", 4, 1, "powerup", {"cap": 1.30}],
	# ── 치명 ──
	["pu_crit_chance", "치명 감각", "uncommon", 10, 5, "powerup", {"cc": 0.08}],
	["pu_crit_damage", "치명 강타", "uncommon", 10, 5, "powerup", {"cm": 0.40}],
	["critical_reaper", "크리티컬 리퍼", "uncommon", 10, 1, "powerup", {"reaper": 0.30}],
	["execute", "참수", "rare", 4, 1, "powerup", {"execute": 0.20}],
	# ── 수확·경제 ──
	["coin_value", "황금 손길", "common", 20, 5, "powerup", {"val": 1.12}],
	["pu_magnet_range", "메가 마그넷", "common", 20, 5, "powerup", {"magnet": 1.25}],
	["regrow_speed", "비옥한 흙", "common", 20, 5, "powerup", {"regrow": 1.20}],
	["coin_leech", "흡혈 수확", "common", 20, 5, "powerup", {"val": 1.08}],
	["combo_harvest", "콤보 수확", "rare", 4, 1, "powerup", {"val": 1.25}],
	["interest", "이자", "uncommon", 10, 5, "powerup", {"val": 1.08}],
	["overkill", "오버킬 환원", "rare", 4, 1, "powerup", {"overkill": 1.0}],
	# ── 황금 ──
	["pu_golden_chance", "황금 씨앗", "uncommon", 10, 5, "powerup", {"gc": 0.02}],
	["golden_luck", "골든 럭", "uncommon", 10, 1, "powerup", {"golden_luck": 0.30}],
	["midas", "미다스", "rare", 4, 1, "powerup", {"val": 1.05}],
	# ── 기동 ──
	["pu_move_speed", "라이트닝 대시", "common", 20, 5, "powerup", {"v": 1.12}],
	["momentum", "질주 본능", "uncommon", 10, 1, "powerup", {"dmg": 1.25}],
	["stun_resist", "굳은 심지", "common", 20, 5, "powerup", {"stun_resist": 0.25}],
	["thorns", "가시 반격", "rare", 4, 1, "powerup", {"thorns": 0.02}],
	# ── 시간 ──
	["finale", "막판 스퍼트", "rare", 4, 1, "powerup", {"finale": 0.50}],
	# ── 도박 ──
	["cursed_scythe", "저주받은 낫", "rare", 4, 1, "powerup", {"val": 1.50, "xp": 0.60}],
	# ── 성장 ──
	["level_burst", "레벨업 충격", "uncommon", 10, 1, "powerup", {"level_burst": 1.0}],
	["seed_blessing", "씨앗 축복", "uncommon", 10, 1, "powerup", {"seed_blessing": 0.15}],
	["xp_gain", "떡잎 부적", "common", 20, 5, "powerup", {"xp": 1.20}],
	["reroll", "리롤 토큰", "uncommon", 10, 3, "powerup", {"reroll": 1}],
	["extra_choice", "안목", "rare", 4, 1, "powerup", {"extra_choice": 1}],
	["luck", "행운의 편자", "rare", 4, 1, "powerup", {"luck": 1}],
	["snowball", "눈덩이", "rare", 4, 1, "powerup", {"snowball": 0.02}],
	["compound", "복리 성장", "epic", 1, 1, "powerup", {"compound": 0.03}],

	# ── 아이템(즉발) 17 ──
	["gold_rush", "골드 러시", "uncommon", 10, 1, "item", {"active_coin2x": 10.0}],
	["blackhole", "블랙홀", "uncommon", 10, 1, "item", {"blackhole": 1.0}],
	["golden_bloom", "골든 블룸", "uncommon", 10, 1, "item", {"golden_bloom": 1.0}],
	["overdrive", "오버드라이브", "uncommon", 10, 1, "item", {"active_aspd2x": 10.0}],
	["heavy_blade", "강철 심", "uncommon", 10, 1, "item", {"active_pow80": 10.0}],
	["harvest_madness", "하베스트 매드니스", "rare", 4, 1, "item", {"active_allstat": 8.0}],
	["field_clear", "필드 클리어", "epic", 1, 1, "item", {"field_clear": 1.0}],
	["growth_spurt", "그로스 스퍼트", "uncommon", 10, 1, "item", {"gauge35": 1.0}],
	["extra_time", "엑스트라 타임", "uncommon", 10, 1, "item", {"add_time": 5.0}],
	["double_or_nothing", "더블 오어 낫싱", "uncommon", 10, 1, "item", {"gamble": 1.0}],
	["all_in", "올인", "rare", 4, 1, "item", {"active_allin": 8.0}],
	["uproot", "뿌리 뽑기", "rare", 4, 1, "item", {"uproot": 0.5}],
	["lightning_mow", "번개 벌초", "uncommon", 10, 1, "item", {"lightning_mow": 1.0}],
	["time_freeze", "시간 정지", "rare", 4, 1, "item", {"time_freeze": 5.0}],
	["fertilizer", "거름 살포", "uncommon", 10, 1, "item", {"fertilizer": 8.0}],
	["instant_level", "즉시 레벨업", "rare", 4, 1, "item", {"instant_level": 1.0}],
	["golden_rain", "황금비", "rare", 4, 1, "item", {"golden_rain": 1.0}],
]

static func by_type(t: String) -> Dictionary:
	for e in LIST:
		if e[0] == t:
			return {"type": e[0], "name": e[1], "rarity": e[2], "weight": e[3], "max_stacks": e[4], "kind": e[5], "effect": e[6]}
	return {}

static func powerups() -> Array:  # 지속형만(레벨업 3택 풀)
	var out := []
	for e in LIST:
		if e[5] == "powerup":
			out.append(e[0])
	return out

static func items() -> Array:  # 즉발형만
	var out := []
	for e in LIST:
		if e[5] == "item":
			out.append(e[0])
	return out
