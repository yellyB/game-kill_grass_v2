extends RefCounted
class_name Palette
## 게임 전체 색상 팔레트 (디자인 토큰) — 공유 컴포넌트.
## 모든 화면(허브/레거시 패널 등)이 여기서 색을 가져다 쓴다. 색을 바꾸려면 여기 한 곳만.
## ★ 플랫폼 분리 원칙: 이건 공유 레이어(scripts/ui). 화면 코드는 각자 분리, 색/위젯만 공유.

# ── 코어 UI ──
const BG_DARK       := Color(0.10, 0.12, 0.14)   # 화면 배경
const PANEL_BG      := Color(0.16, 0.16, 0.22)   # 패널 배경
const PANEL_BORDER  := Color(0.24, 0.24, 0.32)   # 패널 테두리/구분선
const OUTLINE       := Color(0, 0, 0)            # 텍스트 아웃라인
const TEXT          := Color(1, 1, 1)
const TEXT_DIM      := Color(0.6, 0.65, 0.7)

# ── 재화 색 ──
const COIN   := Color(1.0, 0.9, 0.3)    # 코인(황금)
const GEM    := Color(0.95, 0.3, 0.5)   # 보석(핑크)
const TOKEN  := Color(0.4, 0.9, 1.0)    # 정수(시안)
const XP     := Color(1.0, 0.92, 0.5)   # 게임레벨/XP

# ── 상태 색 ──
const AFFORDABLE     := Color(1, 0.9, 0.3)
const NOT_AFFORDABLE := Color(1.0, 0.35, 0.3)
const READY          := Color(1.0, 0.9, 0.3)    # 만충/준비 완료

# ── 스킬 그룹 [무기, 수집, 수확] 노드 색 ──
const GROUP_NODE_COLORS := [
	{ # 무기 — 붉은 계열
		"completed": Color(0.55, 0.2, 0.2),
		"in_progress": Color(0.45, 0.2, 0.22),
		"in_progress_border": Color(0.7, 0.4, 0.35),
		"purchasable": Color(0.22, 0.15, 0.15),
		"purchasable_border": Color(0.45, 0.2, 0.18),
		"locked": Color(0.18, 0.13, 0.13),
		"locked_border": Color(0.4, 0.18, 0.16),
	},
	{ # 수집 — 푸른 계열
		"completed": Color(0.2, 0.35, 0.55),
		"in_progress": Color(0.2, 0.32, 0.48),
		"in_progress_border": Color(0.4, 0.6, 0.8),
		"purchasable": Color(0.15, 0.17, 0.25),
		"purchasable_border": Color(0.18, 0.3, 0.45),
		"locked": Color(0.13, 0.14, 0.2),
		"locked_border": Color(0.16, 0.28, 0.42),
	},
	{ # 수확 — 초록 계열
		"completed": Color(0.2, 0.5, 0.25),
		"in_progress": Color(0.2, 0.4, 0.25),
		"in_progress_border": Color(0.4, 0.65, 0.4),
		"purchasable": Color(0.15, 0.2, 0.15),
		"purchasable_border": Color(0.22, 0.4, 0.18),
		"locked": Color(0.13, 0.17, 0.13),
		"locked_border": Color(0.2, 0.38, 0.16),
	},
]

# ── 스킬 그룹 연결선 색 (충족/미충족) ──
const GROUP_LINE_MET := [
	Color(0.8, 0.35, 0.3, 0.8),     # 무기
	Color(0.3, 0.55, 0.85, 0.8),    # 수집
	Color(0.4, 0.75, 0.35, 0.8),    # 수확
]
const GROUP_LINE_UNMET := [
	Color(0.65, 0.25, 0.25, 0.45),  # 무기
	Color(0.25, 0.45, 0.65, 0.45),  # 수집
	Color(0.35, 0.6, 0.25, 0.45),   # 수확
]
