# 이미지 생성 프롬프트 모음

> **피격 프레임 규칙**: 피격 이미지는 **고통 표정(>o<) 1장만** 사용. 놀람 표정(ㅇoㅇ)은 사용하지 않음. 시트에서 5번째 스프라이트가 피격(고통)이며, 파일명은 `5.png`.

## 공통 스프라이트 시트 규칙

모든 몬스터는 아래 동일한 형식을 따릅니다:

- **그리드**: 4x2 (4열 2행), 총 8칸
- **프레임 크기**: 256x256px / **총 이미지**: 1024x512px
- **배경**: 투명 (PNG with alpha)
- **패딩**: 모든 프레임 셀 내 30px 이상 여백, 잘림 없을 것
- **중요**: 캐릭터는 반드시 각 셀 안에 완전히 들어가야 함. 인접 셀로 넘치면 안 됨
- **시점**: Front-facing 3/4 top-down view — 몬스터가 항상 정면(뷰어 방향)을 바라봄
- **스타일**: 2D top-down 3/4 view, thick dark outline, flat cel-shaded colors, chibi proportions, mobile game art
- **VFX 제외**: 발광, 파티클, 연기, 화염 등은 이미지에 넣지 않음

### 시트 프레임 배치 (5개 스프라이트)
| # | 위치 | 용도 | 설명 |
|---|------|------|------|
| 1 | Row1-1 | idle1 기본 | 정면 기본 자세 |
| 2 | Row1-2 | 오른쪽 움직임 | 오른쪽으로 무게 이동 / 변형 |
| 3 | Row1-3 | idle2 | idle1과 살짝 다른 자세 (중간 동작) |
| 4 | Row1-4 | 왼쪽 움직임 | 왼쪽으로 무게 이동 / 변형 |
| 5 | Row2-1 | 피격 고통 | 상체 ~15도 기울임, 고통 표정 (>o<) |
| 6-8 | Row2-2~4 | (빈칸) | |

### 이미지 추출 후 파일 (5개)
시트에서 5개 스프라이트를 그대로 추출 (복사/반전 없음):
| 파일 | 원본 | 용도 |
|------|------|------|
| 1.png | 시트 #1 | idle1 기본 |
| 2.png | 시트 #2 | 오른쪽 움직임 |
| 3.png | 시트 #3 | idle2 (살짝 다른 자세) |
| 4.png | 시트 #4 | 왼쪽 움직임 |
| 5.png | 시트 #5 | 피격 고통 |

### 애니메이션 시퀀스
- idle/걷기: 1 → 2 → 3 → 4 → (반복) = idle1 → 우 → idle2 → 좌
- 피격: 5 → idle 복귀

### 공통 프롬프트 구조 (5개 스프라이트)

> Row 1 (Frames 1-4): 걷기/idle 프레임.
> - Frame 1 (Idle 1): Default pose facing the viewer. Perfectly upright and symmetrical.
> - Frame 2 (Move right): Body shifts/leans to the right. Visible weight transfer or deformation.
> - Frame 3 (Idle 2): Slightly different from Frame 1 — a subtle variation in posture or shape, like a "mid-step" resting state. Still symmetrical and facing the viewer.
> - Frame 4 (Move left): Body shifts/leans to the left. Counterpart of Frame 2 but drawn as its own unique frame (not a digital flip).
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Upper body tilts to one side (~15 degrees) while still facing the viewer. Pained expression: eyes squeezed shut tight (>o< face), mouth open.
> - Frames 6-8: Leave completely empty (transparent).
>
> NOTE: All 5 sprites are unique — no copying or flipping. Each frame is drawn individually.

---

## 슬라임 스프라이트 시트

**슬라임은 공통 규칙과 다르게 5개 스프라이트를 직접 생성합니다 (복사/반전 없음).**

### 시트 프레임 배치 (5개 스프라이트)
| # | 위치 | 용도 | 설명 |
|---|------|------|------|
| 1 | Row1-1 | idle1 기본 | 기본 둥근 돔 형태 |
| 2 | Row1-2 | 오른쪽 꿈틀 | 오른쪽으로 쏠린 찌그러짐 |
| 3 | Row1-3 | idle2 | idle1과 살짝 다른 찌그러짐 (물풍선 출렁) |
| 4 | Row1-4 | 왼쪽 꿈틀 | 왼쪽으로 쏠린 찌그러짐 |
| 5 | Row2-1 | 피격 고통 | ~15도 기울임, 고통 표정 (>o<) |
| 6-8 | Row2-2~4 | (빈칸) | |

### 이미지 추출 후 파일 (5개)
시트에서 5개 스프라이트를 그대로 추출 (복사/반전 없음):
| 파일 | 원본 | 용도 |
|------|------|------|
| 1.png | 시트 #1 | idle1 기본 |
| 2.png | 시트 #2 | 오른쪽 꿈틀 |
| 3.png | 시트 #3 | idle2 (살짝 다른 형태) |
| 4.png | 시트 #4 | 왼쪽 꿈틀 |
| 5.png | 시트 #5 | 피격 고통 |

### 프롬프트

> Sprite sheet of a jelly slime monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A round jelly slime creature with attitude. Medium blue-purple translucent body — glossy and gel-like with a white highlight/reflection spot on top. A few small grass blades poke out of the top of its head like a messy tuft of hair. Two narrowed, half-lidded yellow eyes with black slit pupils — a mean, cynical glare like it's judging you. Small jagged frown mouth showing annoyance. The body is soft and squishy like a water balloon — it deforms and jiggles with every movement. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the slime is looking straight at the viewer.
>
> Row 1 (Frames 1-4): The slime squirms and wriggles like a water balloon being poked. Always facing the viewer:
> - Frame 1 (Idle 1): Default round dome shape at rest. Perfectly symmetrical, sitting on the ground, facing the viewer. Normal height and width.
> - Frame 2 (Squish right): Body deforms to the right like a water balloon leaning — the right side bulges out wider while the left side compresses inward. The whole mass shifts right with a squishy, elastic feel. Eyes and mouth shift slightly right with the body. Grass tuft on top leans right.
> - Frame 3 (Idle 2): Slightly different from Frame 1 — the body is squished a bit wider and shorter, like a water balloon that just settled back down after being jiggled. A subtle "mid-bounce" resting state. Still symmetrical and facing the viewer, but visibly plumper/flatter than Frame 1.
> - Frame 4 (Squish left): Body deforms to the left — the left side bulges out wider while the right side compresses inward. Mirror-like counterpart of Frame 2 but drawn as its own unique frame (not a digital flip). Eyes and mouth shift slightly left. Grass tuft leans left.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Body compresses from impact, tilts to one side (~15 degrees). Pained expression: eyes squeezed shut tight (>o< face), mouth open. More squished and deformed from the hit.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The slime's body should look noticeably different in each frame — it's a soft, jiggly water balloon that constantly changes shape. The deformation should be clearly visible, not subtle. All frames must have identical medium blue-purple colors and art style. The slime ALWAYS faces the viewer in every frame. No VFX — no glow, no particles. Clean solid body only.

---

## 멧돼지 스프라이트 시트

### 프롬프트

> Sprite sheet of an oversized mutant boar monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of moss on its back and shoulders. Two large curved tusks protruding from the mouth. Red angry eyes with heavy brow. Scarred snout. Exaggerated muscular build with legs splayed outward. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the boar is looking straight at the viewer.
>
> Row 1 (Frames 1-4): The boar snorts and shifts its weight like it's about to charge. Always facing the viewer:
> - Frame 1 (Idle 1): Standing still, front-facing. Legs splayed wide, body at normal height. Head level.
> - Frame 2 (Shift right): Weight shifts to the right — right shoulder drops slightly, body leans right. Right legs bend a bit more, left legs straighten. Head tilts slightly right. Like pawing the ground on the right side.
> - Frame 3 (Idle 2): Slightly different from Frame 1 — head lowered a bit, body hunched forward as if snorting. A "ready to charge" stance. Still symmetrical and front-facing.
> - Frame 4 (Shift left): Weight shifts to the left — left shoulder drops slightly, body leans left. Left legs bend more, right legs straighten. Head tilts slightly left. Mirror-counterpart of Frame 2 but drawn uniquely.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Body recoils, tilts to one side (~15 degrees). Eyes squeezed shut tight (>o< face), mouth open showing tusks.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The boar ALWAYS faces the viewer in every frame. Each frame has a visibly different posture. All frames must have identical dark brown fur, moss patches, tusks, and art style. No glow, no dust, no particles. Clean solid body only.

---

## 잔디 기사 스프라이트 시트

### 프롬프트

> Sprite sheet of a grass knight monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark, battle-worn with scratches. Small weeds sprouting from gaps in the armor. T-shaped helmet visor with dim red eyes barely visible in the dark interior. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the knight is looking straight at the viewer.
>
> SWORD RULE (applies to ALL 6 frames — no exceptions): The knight's RIGHT hand (viewer's right side) is GRIPPING a sharpened grass blade sword. The sword looks like a giant serrated leaf with a short wooden hilt. The hand is clearly wrapped around the hilt — fingers visible on the grip. The sword is raised diagonally upward at about 45 degrees, pointing to the upper-right, held near shoulder/head height. This exact sword-in-hand pose must appear in EVERY frame. The sword is never absent, never floating, never on the ground — always gripped in the right hand at 45 degrees.
>
> Row 1 (Frames 1-4): The knight marches forward with a walking cycle. The sword stays raised at 45 degrees in all frames. Always facing the viewer:
> - Frame 1 (Idle 1): Standing upright, facing the viewer. Both legs aligned and even (not mid-step). Left arm (viewer's left, the non-sword arm) rests at the side. A neutral standing pose, ready to march.
> - Frame 2 (Walk A): Mid-stride pose. The LEFT arm (non-sword arm) swings BACKWARD (away from the viewer, so it appears shorter/smaller due to perspective). The LEFT leg (same side as the swinging arm) steps FORWARD (toward the viewer, appearing longer/larger). The RIGHT leg steps BACKWARD (appearing shorter/smaller). The body has a slight forward lean from the stride. Sword stays raised at 45 degrees in the right hand.
> - Frame 3 (Idle 2): Similar to Frame 1 but slightly different — knees bent a bit more, body settled slightly lower, as if between steps. Both legs aligned and even. Left arm at side. A "mid-march rest" pose. Still symmetrical and front-facing. Sword raised at 45 degrees.
> - Frame 4 (Walk B): The OPPOSITE of Frame 2. The LEFT arm swings FORWARD (toward the viewer, appearing longer/larger). The RIGHT leg steps FORWARD (toward the viewer, appearing longer/larger). The LEFT leg steps BACKWARD (appearing shorter/smaller). The body has a slight forward lean. Sword stays raised at 45 degrees in the right hand. This is the mirror stride of Frame 2.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Upper body tilts to one side (~15 degrees). Helmet visor dents, the T-shaped opening distorts (>o< pained look). Sword droops slightly but still held up.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The knight ALWAYS faces the viewer in every frame. The sword is ALWAYS raised at ~45 degrees in the right hand — never down, never horizontal. Walking frames must show clear arm/leg opposition (opposite arm and leg move together). All frames must have identical green leaf armor, bark textures, and art style. No glow, no particles, no sword trails. Clean solid body only.

---

## 마도사 스프라이트 시트

### 프롬프트

> Sprite sheet of a mushroom mage monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A mushroom mage creature from a dark magical forest. Large spotted mushroom cap in deep purple and dark teal. Thin wispy body in tattered dark robes. Holds a twisted wooden staff with a forked tip in left hand. Two narrow pale green eyes peer out from the shadowy underside of the mushroom cap — scheming and cold. No visible mouth, just darkness under the cap. Floating pose with robes hanging down. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the mage is looking straight at the viewer.
>
> Row 1 (Frames 1-4): The mage floats and drifts eerily, swaying side to side. Always facing the viewer:
> - Frame 1 (Idle 1): Default floating pose, mushroom cap level, robes hanging straight down. Centered, facing the viewer. Hovering at normal height.
> - Frame 2 (Drift right): Body and mushroom cap drift to the right — the whole form leans right as if carried by an invisible breeze. Staff angles right, robes trail to the left. Mushroom cap tilts slightly right.
> - Frame 3 (Idle 2): Slightly different from Frame 1 — hovering a bit higher, mushroom cap bobbing up. Robes hang a bit shorter/tighter. A "floating upward" mid-hover state. Still symmetrical and front-facing.
> - Frame 4 (Drift left): Body and mushroom cap drift to the left. Staff angles left, robes trail to the right. Counterpart of Frame 2 but drawn uniquely.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Mushroom cap tilts to one side (~15 degrees). Eyes squeezed shut tight (>o< face), small mouth visible. Staff droops. Body crumples.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The mage ALWAYS faces the viewer in every frame. Each frame has a visibly different posture/height. All frames must have identical purple-teal mushroom cap, robe texture, staff design, and art style. No glow, no particles, no orbs, no spores. Clean solid body only.

---

## 수정 사슴 스프라이트 시트

### 프롬프트

> Sprite sheet of a crystal deer monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A graceful deer made of pale blue-white crystal. Slim, elegant body — narrow torso with a slender waist, NOT round or chubby. Long graceful legs (noticeably longer than the body is wide) ending in pointed crystal hooves. The legs give the deer a tall, elegant silhouette. Long neck extending upward. Narrow, elongated face with a pointed snout — distinctly deer-shaped, NOT dog-like or cat-like. Tall crystal shard antlers branching out symmetrically like a real deer's rack. Cold, piercing cyan eyes placed on the SIDES of the narrow face (not front-facing dog eyes). Faceted crystalline surface with sharp angular planes. Semi-transparent body with a faint inner glow (drawn as lighter center, not actual glow effect). Thick dark outline. Flat cel-shaded colors, mobile game art style.
>
> CAMERA ANGLE: The camera looks DOWN from DIRECTLY ABOVE at a slight angle — like looking at a toy on a table from above. NOT a side view. NOT a 3/4 profile. The deer is looking STRAIGHT UP at the camera, so the viewer sees the deer's face head-on. This is a FRONT-FACING TOP-DOWN view.
>
> CRITICAL SYMMETRY RULE (MOST IMPORTANT — READ CAREFULLY): The deer's body must be PERFECTLY BILATERALLY SYMMETRICAL in Frames 1 and 3. Draw an imaginary vertical line down the exact center of each frame — the LEFT side and RIGHT side of the deer must be MIRROR IMAGES of each other. Specifically:
> - The nose/snout points STRAIGHT UP (toward top of frame), not angled left or right
> - Left eye and right eye are the EXACT same size, shape, and distance from center
> - Left antler and right antler are EXACT mirror copies
> - Left front leg and right front leg are in the SAME position
> - Left back leg and right back leg are in the SAME position
> - The head does NOT turn to the left. The head does NOT turn to the right. It faces DEAD CENTER.
> - If you drew a line from the nose to the tail, that line must be PERFECTLY VERTICAL on the image.
> - COMMON MISTAKE TO AVOID: Do NOT draw the deer's head slightly turned to one side. This is WRONG. The face must be 100% symmetrical.
>
> Row 1 (Frames 1-4): The deer walks with a proud, elegant stride — head held high, shifting weight side to side. Always perfectly front-facing:
> - Frame 1 (Idle 1): Standing upright on all four legs, perfectly front-facing. Legs straight, hooves on the ground. Head held high, antlers proud. A regal, elegant resting pose.
> - Frame 2 (Step right): Weight shifts to the right — body leans slightly right, right legs planted firmly, left legs lift slightly off the ground. Head tilts just a touch to the right. Antlers sway right. Like a deer mid-stride leaning into a right step.
> - Frame 3 (Idle 2): Similar to Frame 1 but slightly different — head lowered a bit as if nodding, body settled slightly lower. A "between steps" resting pose. Still symmetrical and front-facing.
> - Frame 4 (Step left): Weight shifts to the left — body leans slightly left, left legs planted firmly, right legs lift slightly off the ground. Head tilts just a touch to the left. Antlers sway left. Counterpart of Frame 2 but drawn uniquely.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Body flinches, tilts to one side (~15 degrees). Eyes squeezed shut (>o< face). Crystal facets appear slightly cracked. Antlers droop.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The deer ALWAYS faces the viewer in every frame. Each frame has a visibly different posture. All frames must have identical pale blue-white crystal colors, facet patterns, antler shapes, and art style. No glow, no rainbow, no particles. Clean solid body with facet patterns only.

---

## 잔디 골렘 스프라이트 시트

### 프롬프트

> Sprite sheet of a grass golem monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A massive golem made of ancient stone and compacted earth. Dense green grass covers parts of the body like patches of fur, with exposed cracked stone and dirt. A dark purple core socket in the chest (flat dark color, no glow). Heavy boulder fists wrapped in roots. Deep-set eye sockets with dim orange points of light. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the golem is looking straight at the viewer.
>
> Row 1 (Frames 1-4): The golem lumbers with heavy, ground-shaking steps. Always facing the viewer:
> - Frame 1 (Idle 1): Standing upright, neutral pose. Fists at sides. Legs apart, weight centered. Facing the viewer.
> - Frame 2 (Stomp right): Body shifts heavily to the right — right fist raised slightly, left fist hangs lower. Right shoulder hunches up. The whole massive frame leans right as if taking a heavy step.
> - Frame 3 (Idle 2): Slightly different from Frame 1 — body hunched forward, fists raised a bit higher, as if winding up. A "between stomps" heavy stance. Still symmetrical and front-facing.
> - Frame 4 (Stomp left): Body shifts heavily to the left — left fist raised slightly, right fist hangs lower. Left shoulder hunches up. Counterpart of Frame 2 but drawn uniquely.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Upper body tilts to one side (~15 degrees). Eyes narrowed tight (>o< expression). Fists drop. Cracks appear on the stone surface.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The golem ALWAYS faces the viewer in every frame. Each frame has a visibly different posture. All frames must have identical green grass coverage, stone patches, purple core, and art style. No glow, no particles, no flying debris. Clean solid body only.

---

## 드래곤 스프라이트 시트

### 프롬프트

> Sprite sheet of a smoke dragon monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A terrifying elder dragon radiating primal dread. Massive dark gray-black scaled body covered in deep orange-red crack patterns like molten lava veins splitting through cooled volcanic rock. Huge jagged horns — twisted and asymmetrical, scarred from countless battles. Large tattered wings with torn, shredded membrane showing holes and rips. Menacing orange-red eyes with vertical slit pupils, heavy scarred brow ridge casting shadow over the eyes. Wide jaw with exposed fangs even when mouth is closed — lower teeth jutting upward. Thick muscular neck with armored scale plates. Clawed forelimbs gripping the ground. Thick dark outline. Chibi proportions but still intimidating, flat cel-shaded colors, mobile game art style. Front-facing 3/4 top-down view — the dragon is staring down the viewer with predatory intensity.
>
> Row 1 (Frames 1-4): The dragon goes from sitting still to launching into flight toward the viewer. Always facing the viewer:
> - Frame 1 (Sitting): Crouched low on the ground, wings folded tight against the body. Claws gripping the ground. Head low, eyes glaring forward. A menacing, coiled resting pose — like a predator waiting to strike.
> - Frame 2 (Rising): Body lifting off the ground — wings beginning to spread open wide. Claws leaving the ground, legs tucking underneath. Head rising, jaw opening. The moment of takeoff.
> - Frame 3 (Airborne): Fully airborne, wings spread wide and angled forward. Body tilted toward the viewer as if diving/swooping forward. Claws extended forward ready to grab. Head thrust forward, mouth open with fangs bared. An aggressive flying charge pose.
> - Frame 4 (Gliding): Still airborne but wings pulled back into a streamlined glide. Body leaning forward with momentum. Claws still extended. A sleek, fast flight pose — slightly different wing angle from Frame 3. Still front-facing.
>
> Row 2 (Frame 5, then empty):
> - Frame 5 (Hit — pain): Upper body tilts to one side (~15 degrees). Eyes squeezed shut (>o< face), mouth open showing teeth. Wings crumple inward. Orange cracks on body drawn thicker.
> - Frames 6-8: Leave completely empty (transparent).
>
> Important: The dragon ALWAYS faces the viewer in every frame. Each frame has a visibly different posture — clear progression from sitting to flying. All frames must have identical dark gray-black body, orange-red crack patterns, horn shapes, wing design, and art style. No smoke, no fire, no glow effects, no particles. Clean solid body only.

---

## 플레이어 캐릭터 스프라이트 시트

### 설정
- 그리드: 6x2 (6열 2행)
- 프레임 크기: 128x128px
- 총 이미지 크기: 768x256px
- 배경: 투명 (PNG with alpha)

### 프레임 구성
| # | 위치 | 용도 | 설명 |
|---|------|------|------|
| 1 | Row1-1 | idle | 정면 기본 자세 |
| 2 | Row1-2 | walk_a | 정면 걷기 A |
| 3 | Row1-3 | walk_b | 정면 걷기 B |
| 4 | Row1-4 | attack1 | 정면 공격1 (팔 옆으로) |
| 5 | Row1-5 | attack2 | 정면 공격2 (팔 위로) |
| 6 | Row1-6 | hit | 정면 피격 |
| 7 | Row2-1 | idle_back | 뒷모습 기본 자세 |
| 8 | Row2-2 | walk_a_back | 뒷모습 걷기 A |
| 9 | Row2-3 | walk_b_back | 뒷모습 걷기 B |
| 10 | Row2-4 | attack1_back | 뒷모습 공격1 |
| 11 | Row2-5 | attack2_back | 뒷모습 공격2 |
| 12 | Row2-6 | hit_back | 뒷모습 피격 |

### 좌우반전
- 각 프레임을 좌우반전하여 `_flip` 버전 생성 (총 24장)

### 프롬프트

> 2D top-down cartoon sprite sheet for a mobile idle game. Small simple character (128x128 pixels per frame). Clean illustration with thick black outlines and flat coloring. Minimal detail — the character will appear very small in-game.
>
> NOT pixel art. Smooth lines, simple flat colors, minimal shading.
>
> Character design: A very simple small boy seen from DIRECTLY ABOVE at a top-down perspective. Green cap (plain solid color, no details). White T-shirt (plain). Lower body is ALL ONE solid brown color — shorts and shoes are the same brown with no distinction. Simple round head, two small black dot eyes ONLY — NO mouth, NO nose, NO other facial features. Both hands EMPTY. Extremely minimal design.
>
> CRITICAL: ALL frames must face STRAIGHT at the camera (front) or STRAIGHT away (back). The character must NEVER turn to the side. No side profiles, no 3/4 angles.
>
> IMPORTANT PERSPECTIVE RULE FOR WALK FRAMES: Limbs moving FORWARD (toward camera) should appear LONGER and LARGER. Limbs moving BACKWARD (away from camera) should appear SHORTER and SMALLER — foreshortened to create depth.
>
> Arrange all frames on a transparent background. Each cell exactly 128x128 pixels.
>
> Row 1 — Front-facing, looking straight at camera (6 frames, left to right):
> 1. Idle: Standing still facing camera, feet together, both arms resting at sides
> 2. Walk A: Right foot forward (drawn LONGER/BIGGER) + left foot back (drawn SHORTER/SMALLER) + left arm forward (LONGER) + right arm back (SHORTER). Head and torso face straight at camera.
> 3. Walk B: Left foot forward (drawn LONGER/BIGGER) + right foot back (drawn SHORTER/SMALLER) + right arm forward (LONGER) + left arm back (SHORTER). Exact opposite of Walk A.
> 4. Attack 1: Character's RIGHT arm (viewer's right side) is extended straight out to the RIGHT side, horizontal, as if reaching out to the right. Left arm stays at side. Body faces camera.
> 5. Attack 2: Character's RIGHT arm (viewer's right side) is raised DIAGONALLY UP to the upper-right, pointing to about 1-2 o'clock direction. Left arm stays at side. Body faces camera.
> 6. Hit: Body and upper torso TILTED/LEANING to one side (viewer's left), as if knocked sideways by an impact. Eyes shut (two short lines). Feet stay planted but torso is clearly angled off-center.
>
> Row 2 — Back-facing, looking straight away from camera (6 frames, same order):
> 1-6: Exact same poses as Row 1 but showing the character's back. Back of green cap, back of white shirt, brown lower half. NO face visible. All arm/leg positions match Row 1 from rear view.
>
> Total: 12 frames, 2 rows x 6 columns. Each cell 128x128 pixels. Transparent background. Thick black outline, flat colors, extremely minimal detail. Every single frame faces DIRECTLY forward or DIRECTLY backward.
