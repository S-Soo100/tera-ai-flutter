# Tera AI — Claude Code 행동 규칙

## 프로젝트 개요
파충류 사육자를 위한 올인원 앱. 백색목록 검색, 사육 정보, 모프 유전 계산기, 자진신고 가이드.
- **스택**: Flutter + Riverpod + GoRouter + Hive + easy_localization + Supabase
- **현재 Phase**: P0 (로컬 전용, 인증 없음, 백엔드 없음)
- **기획서**: `docs/spec.md`
- **자진신고 기한**: 2026-06-13 (D-day 기준)

### Supabase 관련 문서
- **DB 스키마 (DDL 원본)**: `docs/supabase-schema.md`
- **연동 현황 (접속 정보/RLS/시드/Flutter 코드 예시)**: `docs/supabase-setup.md`

## Phase 로드맵

| Phase | 범위 | 상태 |
|-------|------|------|
| P0 | 로컬 데이터, 검색/상세/모프계산기/가이드, 3탭 | 현재 (AutoForge 생성) |
| P1 | OnboardingScreen, ProfileScreen(내 사육장), 로컬 알림(D-day 리마인더), en 다국어, Pretendard 폰트 | 예정 |
| P2 | Supabase 도입, 인증(이메일+소셜), 클라우드 동기화, FCM 푸시, 거래 기록 | DB 구축 완료 (`docs/supabase-setup.md`) |

## 아키텍처

```
lib/
├── main.dart                    # 앱 진입점 (Hive init, EasyLocalization, ProviderScope)
├── app.dart                     # MaterialApp.router, 테마, GoRouter
├── core/
│   ├── constants/               # AppConstants (색상, 문자열, D-day 날짜)
│   ├── theme/                   # AppTheme (라이트/다크, Material 3)
│   ├── router/                  # GoRouter 설정, 리다이렉트
│   └── error/                   # AppException 계층
├── features/
│   ├── {feature}/
│   │   ├── data/                # Repository 구현 (로컬 데이터)
│   │   ├── domain/              # 모델 클래스
│   │   └── presentation/        # Screen, Widget, Provider
│   ├── auth/                    # placeholder (P2용)
│   ├── onboarding/              # placeholder (P1용)
│   ├── profile/                 # placeholder (P1용)
│   └── notification/            # placeholder (P2용)
├── shared/
│   ├── widgets/                 # 공통 위젯 (LegalBadge 등)
│   └── providers/               # 공통 프로바이더
└── l10n/ → assets/l10n/ko.json  # easy_localization
```

### 핵심 feature

| feature | 화면 | 데이터 소스 |
|---------|------|------------|
| home | HomeScreen (검색+카테고리 필터) | SpeciesRepository (로컬 18종) |
| species_detail | SpeciesDetailScreen | SpeciesRepository + CareInfo (6종) |
| morph_calc | MorphCalcScreen | MorphRepository (3세트 하드코딩) |
| guide | GuideScreen (D-day + 5단계 아코디언) | GuideRepository (5 GuideStep) |
| splash | SplashScreen (1초 → Home) | — |
| error | ErrorScreen | — |

## 코딩 규칙

### 상태 관리
- **Riverpod만 사용**. setState, ChangeNotifier 금지.
- `ref.watch`는 build 안에서만, `ref.read`는 콜백/이벤트에서.
- Provider는 각 feature의 `presentation/` 폴더에 위치.

### 데이터 접근
- **Repository 패턴 필수**. Widget에서 Hive/데이터 직접 접근 금지.
- P0은 로컬 상수 → P2에서 Repository 구현체만 Supabase로 교체.
- Supabase 테이블/RLS/접속 정보는 `docs/supabase-setup.md` 참조.

### UI/테마
- **디자인 시스템**: `docs/design-system.md` — 토큰, 공유 위젯, 사용 규칙 정의
- **하드코딩 색상 금지**. `AppTheme` 또는 `Theme.of(context)` 사용.
- **하드코딩 문자열 금지**. `assets/l10n/ko.json`에 키 추가 후 `.tr()` 사용.
- Primary: #2E7D32 (Green 800), Secondary: #FF8F00 (Amber 800)
- 폰트: Pretendard (Regular/Medium/SemiBold/Bold)
- 간격: `AppStyles.spacingN` 토큰 사용, 태그: `AppTag` 위젯, 섹션 제목: `SectionHeader` 위젯

### 라우팅
- GoRouter 사용. 경로는 `core/router/app_router.dart`에서 중앙 관리.
- 새 화면 추가 시 라우터에 등록 필수.

### 다국어
- `easy_localization` + `assets/l10n/ko.json`.
- 새 문자열 추가 순서: ko.json에 키 추가 → 코드에서 `'key'.tr()`.

## CAOF (Claude Agent Orchestration Framework)

이 프로젝트는 CAOF를 따른다. 원본: `/Users/baek/ideaBank/frameworks/claude-agent-orchestration.md`

### 역할 매핑
- **Designer**: 메인 Claude (opus) -- 분석, 설계, Phase 전환 판단
- **Implementer**: flutter-dev (sonnet) -- Dart 코드 구현, 버그 수정

### 사용자 안내 규칙
작업 요청 시, 메인 Claude는 **트랙 판단 결과를 먼저 알려준다**:
```
CAOF 트랙: [Trivial / Standard / Critical]
이유: [1줄 근거]
-> [어떤 에이전트가 어떤 순서로 작동하는지]
```
사용자가 "CAOF 끄기"라고 하면 해당 세션에서 비활성화.

### 트랙 분류

| 트랙 | 기준 | 파이프라인 |
|------|------|-----------|
| Trivial | 상수 수정, 스타일 변경, 텍스트 수정 | flutter-dev 직행 |
| Standard | 기존 feature 수정, 새 위젯, Provider 추가 | Designer 분석 -> flutter-dev |
| Critical | 새 feature, Phase 전환, 외부 패키지 도입 | 풀 GATE |

**판단 기준은 줄 수가 아니라 "실패 시 되돌리기 비용"이다.**
상세 라우팅 트리: `.claude/rules/tera-ai-caof.md`

### 에이전트 폭주 방지

**대규모 변경 처리:**
- 변경 파일 10개+ -> 한 번에 전부 읽지 않는다
- overview(git diff --stat) -> 기능별 그룹핑 -> 그룹별 순차 처리

**실패 제한:**
- 에이전트 스폰 재시도: **3회**
- 빌드/수정 루프: **3회**
- 3회 실패 시 즉시 중단 + 사용자에게 보고

### 실패 에스컬레이션
```
1회 실패: flutter-dev 원인 분석 후 재시도
2회 실패: Designer(메인 Claude) 원인 재분석 -> 다른 접근법
3회 실패: 즉시 중단 + 사용자에게 보고 + 범위 축소 또는 대안 제시
```
"빨리 해", "바로 구현해"는 GATE 스킵 승인이 아니다. "N단계 스킵 승인"만 허용.

## 빌드/검증

```bash
flutter analyze          # 정적 분석 (에러 0 유지)
flutter build apk --debug  # Android 빌드 확인
flutter test             # 테스트 실행
```

- 코드 수정 후 `flutter analyze` 에러 0 확인 필수.
- `flutter build`는 Claude Code 안에서 직접 실행 가능 (리소스 경합 낮음, Unity와 다름).

## 금지 사항
- placeholder feature(auth, onboarding, profile, notification)를 P0에서 구현하지 않기
- dio로 실제 API 호출하지 않기 (P0은 로컬 전용)
- flutter_secure_storage 실제 사용하지 않기 (P2 대비 의존성만 포함)
- 새 패키지 추가 시 사용자 승인 없이 pubspec.yaml 수정하지 않기
- **CircularProgressIndicator 사용 금지** — 로딩 상태는 항상 `shimmer` 패키지의 스켈레톤 UI를 사용할 것
