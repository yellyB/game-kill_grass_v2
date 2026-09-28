#!/usr/bin/env python3
"""UI 패리티 점검 — PC/모바일 화면 요소 누락 검출 (전략 B).

단일 매니페스트(docs/ui_features.json)를 읽어 요소별 scope와 pc/mobile 구현 플래그를
검증한다. 화면 요소를 추가/삭제하면 그 파일 한 줄만 갱신하고 이 스크립트를 돌리면 된다.

규칙:
  scope=both        → pc·mobile 둘 다 true 여야 통과 (한쪽이라도 false면 FAIL)
  scope=pc_only     → pc=true 기대 (mobile=true면 경고)
  scope=mobile_only → mobile=true 기대 (pc=true면 경고)

사용:  python3 sim/ui_parity.py         (표 + 결과, 문제 있으면 종료코드 1)
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "docs", "ui_features.json")

def mark(v):
    return "✓" if v else "✗"

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else MANIFEST
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    feats = data["features"]

    fails, warns = [], []
    # 화면별 그룹 출력
    by_screen = {}
    for key, f in feats.items():
        by_screen.setdefault(f.get("screen", "?"), []).append((key, f))

    print(f"── UI 패리티 점검 ({len(feats)}개 요소) ──")
    print(f"{'요소':<22} {'화면':<9} {'scope':<12} {'PC':<3} {'모바일':<5} 설명")
    print("─" * 78)
    for screen in sorted(by_screen):
        for key, f in sorted(by_screen[screen]):
            scope, pc, mob = f["scope"], bool(f.get("pc")), bool(f.get("mobile"))
            flag = ""
            if scope == "both":
                if not (pc and mob):
                    flag = "  ← 누락!"; fails.append((key, "both인데 한쪽 미구현"))
            elif scope == "pc_only":
                if not pc: flag = "  ← PC 미구현!"; fails.append((key, "pc_only인데 pc=false"))
                if mob: warns.append((key, "pc_only인데 mobile=true"))
            elif scope == "mobile_only":
                if not mob: flag = "  ← 모바일 미구현!"; fails.append((key, "mobile_only인데 mobile=false"))
                if pc: warns.append((key, "mobile_only인데 pc=true"))
            else:
                warns.append((key, f"알 수 없는 scope '{scope}'"))
            print(f"{key:<22} {screen:<9} {scope:<12} {mark(pc):<3} {mark(mob):<5} {f.get('desc','')}{flag}")

    print("─" * 78)
    if warns:
        print(f"\n⚠️  경고 {len(warns)}건:")
        for k, m in warns: print(f"   - {k}: {m}")
    if fails:
        print(f"\n❌ 누락/불일치 {len(fails)}건:")
        for k, m in fails: print(f"   - {k}: {m}")
        print("\n→ 해당 플랫폼 UI에 요소를 구현하고 docs/ui_features.json 플래그를 갱신하세요.")
        sys.exit(1)
    print("\n✅ 통과 — PC/모바일 UI 요소 패리티 이상 없음.")

if __name__ == "__main__":
    main()
