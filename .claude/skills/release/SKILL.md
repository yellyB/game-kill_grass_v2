---
name: release
description: dev 브랜치를 main으로 머지하고 릴리즈 태그를 생성하는 릴리즈 워크플로우. 사용자가 머지, 릴리즈, main 머지, 배포 등을 요청할 때 사용.
disable-model-invocation: true
---

## dev → main 릴리즈 절차

아래 단계를 **순서대로** 진행한다. 각 단계에서 사용자 확인을 받은 뒤 다음으로 넘어간다.

### 1단계: 이전 버전 확인

```bash
git tag --sort=-creatordate | head -1
```

최신 태그를 찾아 이전 버전이 무엇인지 알려준다.

### 2단계: 변경점 정리

이전 태그 이후의 커밋을 확인한다:

```bash
git log <이전태그>..dev --oneline
```

- 개발 내부 변경(CLAUDE.md 수정 등)은 제외
- **유저가 체감할 수 있는 변경점**만 구체적으로 정리
- 릴리즈 노트 형식으로 보여준다
- **일반 사용자(비개발자)가 이해할 수 있는 표현**을 사용한다
  - 전문 용어(콜리전, 파티클, 스프라이트 등) 대신 직관적인 표현 사용
  - 예: "콜리전 수정" → "피격 범위가 보이는 크기와 맞지 않던 문제 수정"
  - 예: "파티클 추가" → "빨간 구슬이 게이지로 날아가는 연출 추가"

### 3단계: 사용자 확인 및 버전 질문

정리한 변경점을 보여주고 다음을 질문한다:
- 릴리즈 노트 내용이 맞는지 확인
- 새 버전코드 (정수, 예: 14)
- 새 버전이름 (x.y.z, 예: 1.0.3)

### 4단계: 머지 + 태그 + 푸시

사용자가 승인하면 아래를 수행한다:

1. `export_presets.cfg`의 `version/code`와 `version/name` 업데이트
2. 변경사항 커밋 (dev 브랜치에서)
3. `git push origin dev`
4. `git checkout main && git merge dev`
5. `git tag -a "v{버전코드}-{버전이름}" -m "{버전코드} ({버전이름})"`
6. `git push origin main && git push origin "v{버전코드}-{버전이름}"`
7. `git checkout dev` (dev 브랜치로 복귀)
