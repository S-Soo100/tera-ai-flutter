# 비바나트 디자인 시스템 (HTML)

> **claude.ai/design 프로젝트**: `비바나트 디자인 시스템` (id `1e774824-a30a-4350-a00f-b042424a7d4d`)
> **생성일**: 2026-08-08

## 이게 뭔가

Figma `Asset` 섹션 규격 + 이번 시각 방향에서 나온 패턴을 **HTML 카드**로 구현한 것이다.
`DesignSync`로 claude.ai/design에 올려 브라우저에서 한눈에 보고 검토한다.

| 그룹 | 카드 |
|---|---|
| Foundations | 컬러 · 타이포그래피 · 밤 띠 규칙 |
| Components | **ScreenHeader** · **AccountAvatar** · **StatusBadge** · **LiveSurface** · **EmptyState** · Button · Chip · Tag · Toast · Tabs |
| Patterns | Readout · Night Chart · **StatRow** · Control Tile |

각 카드 하단에 대응 Flutter 파일과 **적용 여부(✅)** 를 적는다.

## ⚠️ 진실이 둘이라는 것

**이 HTML은 Flutter 앱이 아니다.** 여기서 확정한 값을 Flutter로 옮기는 단계가 반드시 필요하고,
그 사이에서 어긋날 수 있다. 그 간극을 줄이려고 **각 카드 하단에 Flutter 매핑을 적어 뒀다**
(`Flutter · lib/...` 줄). 값을 바꾸면 **HTML과 Dart 양쪽을 함께** 고쳐야 한다.

토큰의 원 출처는 여전히 Figma다 — `docs/figma-final-design-transcript.md` §4.
이 HTML은 Figma 값을 **바꾸지 않고 옮겨 담기만** 한다.

## 갱신 방법

```bash
python3 sync-tokens.py      # 토큰을 전 카드에 주입 (필수)
```

그다음 `DesignSync` → `finalize_plan` → `write_files`로 claude.ai/design에 올린다.
로컬 미리보기는 `python3 -m http.server` 후 `index.html`.

**`_tokens.css`는 카드마다 인라인으로 복사돼 들어간다**(카드가 개별 렌더되므로).
토큰을 바꾸면 전 카드를 다시 써야 하는데 손으로 하면 반드시 빠뜨린다 —
실제로 `--warn-bg` 추가가 8장에 누락됐다. 그래서 `sync-tokens.py`가 있다.

## ⚠️ 드리프트가 실제로 일어난다

C안(HTML 우선)의 비용이다. 2026-08-09 최신화에서 발견된 것:

- **StatRow가 균등 분할로 그려져 있었다** — Flutter는 이미 자연 폭 + 가로 스크롤이었다.
  HTML만 보고 구현했으면 옆 칸 침범 버그를 그대로 재현했을 것이다
- 4개 카드가 *"지금 앱은 ~다"* 로 **이미 고쳐진 문제**를 현재형으로 서술하고 있었다
- `night-band-rule.html`이 로컬 `patterns/`, 원격 `foundations/`로 **경로가 갈려 있었다**

**Flutter를 고치면 같은 커밋에서 카드도 고친다.** 미루면 카드가 거짓말을 시작한다.

## 카드에 적힌 미해결 항목

- **Tabs 라벨 불일치** — Figma `사육장 | 크레캠` vs 기획안 `사육장 제어 | 타임라인`
- **Button hover·pressed 상태** 미정의
- **Toast 에러·경고 변형** 미정의
- **Tag 6종 vs 서브컬러 5종** — 수목성·합법이 파랑 공유
- **Readout** — 최고/최저 라벨 없음, 좌우 비대칭
- **Night Chart** — Y축 없음(통계 탭에는 필요)
- **다크 팔레트 전체** — Figma 미제공. `brandNavyDark #768ad6`은 앱 도출값
