extends RefCounted
class_name Icons
## 공용 아이콘 레지스트리 (디자인 시스템). 색=Palette, 아이콘=Icons.
## ⚠️ 게임 상태가 아니라 에셋만 모아둔 곳 → 컴포넌트가 참조해도 독립성 안 깨짐(Palette와 동급).

const COIN := preload("res://resources/images/coin.png")
const GEM  := preload("res://resources/images/gem.png")
const LOCK := preload("res://resources/images/icon/lock.png")

# 스킬 아이콘 (skill_type → 텍스처)
const SKILL := {
	"attack_power": preload("res://resources/images/skill/attack_power.png"),
	"attack_speed": preload("res://resources/images/skill/attack_speed.png"),
	"crit_chance": preload("res://resources/images/skill/crit_chance.png"),
	"crit_damage": preload("res://resources/images/skill/crit_damage.png"),
	"monster_damage": preload("res://resources/images/skill/monster_damage.png"),
	"attack_range": preload("res://resources/images/skill/attack_range.png"),
	"attack_count": preload("res://resources/images/skill/attack_count.png"),
	"move_speed": preload("res://resources/images/skill/move_speed.png"),
	"magnet_range": preload("res://resources/images/skill/magnet_range.png"),
	"grass_density": preload("res://resources/images/skill/grass_density.png"),
	"grass_quality": preload("res://resources/images/skill/grass_quality.png"),
	"combo_duration": preload("res://resources/images/skill/chest_chance.png"),
	"elite_chance": preload("res://resources/images/skill/elite_chance.png"),
	"fury_rate": preload("res://resources/images/skill/fury_rate.png"),
	"golden_chance": preload("res://resources/images/skill/golden_chance.png"),
	"golden_reward": preload("res://resources/images/skill/golden_reward.png"),
	"session_time": preload("res://resources/images/skill/session_time.png"),
}

static func skill(skill_type: String) -> Texture2D:
	return SKILL.get(skill_type, null)
