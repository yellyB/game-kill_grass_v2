extends RefCounted
class_name PowerupData
## 파워업 콘텐츠 데이터 + 조회 헬퍼 (공유 로직). UI(powerup_selection)와 분리 —
## 공유 게임플레이(dropped_item)·플랫폼별 UI(hud/powerup_selection)가 모두 참조. Phase: UI 격리.

const POWERUP_IMAGE_PATH = "res://resources/images/powerup/"

# 파워업(지속, item:false) + 아이템(즉발, item:true) 통합 데이터.
# enabled:false = 3택/드롭 풀에서 제외(밸런스 보류 등). 효과 자체는 game_manager에 배선돼 있음.
# 이미지 없으면 색상 폴백. 상세 설계: docs/powerups.md
const POWERUP_DATA = [
  # ── 공격 (파워업) ──
  {"type": "sharp_blade", "name": "예리한 날", "desc": "공격력 +15%", "color": Color(1.0, 0.5, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_attack_speed", "name": "어택 부스트", "desc": "공격 속도 +12%", "color": Color(1.0, 0.5, 0.2), "image": "어택부스트.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_attack_range", "name": "와이드 스윙", "desc": "공격 범위 +15%", "color": Color(0.3, 0.6, 1.0), "image": "와이드어택.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "timber", "name": "벌목", "desc": "거목·정예 피해 +30%", "color": Color(0.6, 0.4, 0.2), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "chain_reaction", "name": "연쇄 반응", "desc": "풀 처치 시 30% 확률로 인접 풀 즉시 처치", "color": Color(0.9, 0.6, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 치명타 (파워업) ──
  {"type": "pu_crit_chance", "name": "치명 감각", "desc": "치명타 확률 +8%", "color": Color(1.0, 0.2, 0.4), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "pu_crit_damage", "name": "치명 강타", "desc": "치명타 피해 +40%", "color": Color(1.0, 0.2, 0.4), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "critical_reaper", "name": "크리티컬 리퍼", "desc": "치명타 시 범위 내 풀 30% 즉사", "color": Color(0.6, 0.1, 0.3), "image": "크리티컬리퍼.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "execute", "name": "참수", "desc": "체력 20% 이하 풀 즉시 처치", "color": Color(0.7, 0.1, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 수확·경제 (파워업) ──
  {"type": "coin_value", "name": "황금 손길", "desc": "코인 가치 +12%", "color": Color(1.0, 0.85, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "pu_magnet_range", "name": "메가 마그넷", "desc": "수집 범위 +25%", "color": Color(0.2, 1.0, 0.8), "image": "메가마그넷.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "regrow_speed", "name": "비옥한 흙", "desc": "풀 재생 속도 +20%", "color": Color(0.4, 0.8, 0.3), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "coin_leech", "name": "흡혈 수확", "desc": "벤 풀 코인 +8%", "color": Color(0.8, 0.7, 0.2), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "combo_harvest", "name": "콤보 수확", "desc": "연속 처치 10마다 코인 +5% (최대 +50%)", "color": Color(1.0, 0.7, 0.3), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "interest", "name": "이자", "desc": "세션 종료 시 보유 코인 +8%", "color": Color(0.9, 0.8, 0.3), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "overkill", "name": "오버킬 환원", "desc": "처치 초과 데미지만큼 코인 보너스", "color": Color(0.9, 0.5, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 황금풀 (파워업) ──
  {"type": "pu_golden_chance", "name": "황금 씨앗", "desc": "황금풀 등장 확률 +2%", "color": Color(1.0, 0.9, 0.2), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "golden_luck", "name": "골든 럭", "desc": "황금풀 제거 시 30% 확률 커먼 파워업 획득", "color": Color(1.0, 0.85, 0.0), "image": "골든럭.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "midas", "name": "미다스", "desc": "벤 풀이 낮은 확률로 즉석 황금 보상", "color": Color(1.0, 0.8, 0.1), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 기동 (파워업) ──
  {"type": "pu_move_speed", "name": "라이트닝 대시", "desc": "이동 속도 +12%", "color": Color(1.0, 1.0, 0.3), "image": "라이트닝대시.png", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "momentum", "name": "질주 본능", "desc": "이동 중 공격력 +25%", "color": Color(1.0, 0.9, 0.4), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "stun_resist", "name": "굳은 심지", "desc": "거목 스턴 시간 -25% (최대 -75%)", "color": Color(0.6, 0.6, 0.7), "image": "", "stackable": true, "item": false, "weight": 20, "max_stacks": 3, "enabled": true},
  {"type": "thorns", "name": "가시 반격", "desc": "스턴될 때 거목 최대 체력 2% 반사", "color": Color(0.5, 0.7, 0.4), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 시간 (파워업) ──
  {"type": "finale", "name": "막판 스퍼트", "desc": "마지막 10초간 전 스탯 +50%", "color": Color(0.4, 1.0, 0.4), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 도박 (파워업) ──
  {"type": "cursed_scythe", "name": "저주받은 낫", "desc": "코인 +50%, 경험치 -40%", "color": Color(0.6, 0.2, 0.6), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # ── 성장 (파워업) ──
  {"type": "level_burst", "name": "레벨업 충격", "desc": "레벨업 시 주변 풀 즉시 처치", "color": Color(0.7, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "seed_blessing", "name": "씨앗 축복", "desc": "씨앗 획득 시 8초간 전 스탯 +15%", "color": Color(0.5, 0.9, 0.5), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "xp_gain", "name": "떡잎 부적", "desc": "레벨업 게이지 획득량 +20%", "color": Color(0.6, 0.9, 0.6), "image": "", "stackable": true, "item": false, "weight": 20, "enabled": true},
  {"type": "reroll", "name": "리롤 토큰", "desc": "파워업 3택 다시 뽑기 +1", "color": Color(0.5, 0.7, 1.0), "image": "", "stackable": true, "item": false, "weight": 10, "enabled": true},
  {"type": "extra_choice", "name": "안목", "desc": "파워업 선택지 3→4개", "color": Color(0.6, 0.8, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "luck", "name": "행운의 편자", "desc": "레어 이상 등장 확률 증가", "color": Color(0.9, 0.9, 0.4), "image": "", "stackable": true, "item": false, "weight": 4, "enabled": true},
  {"type": "snowball", "name": "눈덩이", "desc": "풀 100개마다 공격력 +2% (세션 내)", "color": Color(0.8, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "compound", "name": "복리 성장", "desc": "레벨업마다 전 스탯 소폭 영구 증가", "color": Color(0.9, 0.7, 1.0), "image": "", "stackable": false, "item": false, "weight": 1, "enabled": true},
  # ── 구 즉발 17종 (§3.10): 전부 레벨업 파워업으로 복귀(item:false). "item:true=슬롯후보" 개념 폐기 ──
  {"type": "gold_rush", "name": "골드 러시", "desc": "10초간 코인 가치 2배", "color": Color(1.0, 0.85, 0.0), "image": "골드러시.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "blackhole", "name": "블랙홀", "desc": "드롭 코인 즉시 흡수", "color": Color(0.2, 0.0, 0.4), "image": "블랙홀.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "golden_bloom", "name": "골든 블룸", "desc": "주변 풀을 황금풀로", "color": Color(1.0, 0.9, 0.2), "image": "골든블룸.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "overdrive", "name": "오버드라이브", "desc": "10초간 공속 2배, 이속 -30%", "color": Color(1.0, 0.3, 0.5), "image": "오버드라이브.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "heavy_blade", "name": "강철 심", "desc": "10초간 공격력 +80%, 공속 -20%", "color": Color(0.7, 0.4, 0.3), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "harvest_madness", "name": "하베스트 매드니스", "desc": "8초간 모든 스탯 대폭 증가", "color": Color(1.0, 0.5, 1.0), "image": "하베스트매드니스.png", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "field_clear", "name": "필드 클리어", "desc": "맵 전체 풀 즉시 클리어", "color": Color(0.3, 1.0, 0.3), "image": "필드클리어.png", "stackable": false, "item": false, "weight": 1, "enabled": true},
  {"type": "extra_time", "name": "엑스트라 타임", "desc": "세션 시간 +5초", "color": Color(0.4, 1.0, 0.4), "image": "엑스트라타임.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "double_or_nothing", "name": "더블 오어 낫싱", "desc": "50% 코인 2배 / 50% 전부 잃음", "color": Color(0.8, 0.2, 0.8), "image": "더블오어더스트.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "all_in", "name": "올인", "desc": "8초간 전 스탯 +80%", "color": Color(0.9, 0.3, 0.5), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "lightning_mow", "name": "번개 벌초", "desc": "랜덤 다수 풀 즉시 처치", "color": Color(0.8, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "time_freeze", "name": "시간 정지", "desc": "타이머 잠깐 정지, 수확 계속", "color": Color(0.6, 0.8, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "fertilizer", "name": "거름 살포", "desc": "짧은 시간 풀 재생·밀도 폭증", "color": Color(0.5, 0.8, 0.3), "image": "", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "golden_rain", "name": "황금비", "desc": "잠깐 코인·황금풀이 쏟아짐", "color": Color(1.0, 0.9, 0.3), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  # 구 보류 3종 활성화(§3.10) — ⚠️ 밸런스 집중 조절 필요(dev-plan 참조):
  #   uproot=거목 무력화 위험(§7-7), instant_level/growth_spurt=레벨업 가속 폭주 위험.
  #   growth_spurt 아이콘=구 몬스터퓨리 재탕(임시, 전용 아트 교체 예정).
  {"type": "growth_spurt", "name": "그로스 스퍼트", "desc": "레벨업 게이지 35% 충전", "color": Color(0.9, 0.6, 0.9), "image": "몬스터퓨리.png", "stackable": false, "item": false, "weight": 10, "enabled": true},
  {"type": "instant_level", "name": "즉시 레벨업", "desc": "즉시 레벨업 1회", "color": Color(0.7, 0.9, 1.0), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
  {"type": "uproot", "name": "뿌리 뽑기", "desc": "거목/정예에 즉시 큰 피해", "color": Color(0.6, 0.4, 0.2), "image": "", "stackable": false, "item": false, "weight": 4, "enabled": true},
]

static func get_powerup_texture(data: Dictionary) -> Texture2D:
  if data.image != "":
    return load(POWERUP_IMAGE_PATH + data.image)
  return null

static func get_powerup_data_by_type(type: String) -> Dictionary:
  for data in POWERUP_DATA:
    if data.type == type:
      return data
  return {}
