# Tera AI 디자인 시스템

## 개요

앱 전체에서 일관된 UI를 유지하기 위한 디자인 토큰과 공유 위젯 정의.

---

## 1. 디자인 토큰 (`lib/core/theme/app_styles.dart`)

### 간격 (Spacing)

| 토큰 | 값 | 용도 |
|------|-----|------|
| `spacing4` | 4px | 인라인 요소 간격 |
| `spacing8` | 8px | 카드 내부 작은 간격 |
| `spacing12` | 12px | 섹션 헤더 하단 간격 |
| `spacing16` | 16px | 페이지 패딩, 섹션 간격 |
| `spacing24` | 24px | 섹션 간 큰 간격 |
| `spacing32` | 32px | 페이지 상단/하단 여백 |
| `pagePadding` | `EdgeInsets.all(16)` | 페이지 기본 패딩 |

### Radius

| 토큰 | 값 | 용도 |
|------|-----|------|
| `cardRadius` | 16px | Card 기본 radius |
| `chipRadius` | 8px | 태그 칩 radius |

### 태그 색상 (`tagColor`)

| 태그 | 색상 | Hex |
|------|------|-----|
| 입문 | Green 800 | `#2E7D32` |
| 인기 | Deep Orange 900 | `#E65100` |
| 야행성 | Deep Purple 800 | `#4527A0` |
| 수목성 | Cyan 800 | `#00838F` |
| 합법 | Blue 800 | `#1565C0` |
| 상세 정보 | Green 800 | `#2E7D32` |
| 기본값 | Blue Grey 600 | `#546E7A` |

새 태그 추가 시 `AppStyles.tagColor()` switch문에 케이스 추가.

### 상태 색상

| 상태 | 변수 | Hex | 용도 |
|------|------|-----|------|
| 급여 | `feedingColor` | `#2E7D32` | 이벤트 타임라인 |
| 탈피 | `sheddingColor` | `#E65100` | 이벤트 타임라인 |
| 체중 | `weightColor` | `#1565C0` | 이벤트 타임라인 |
| 건강 | `healthColor` | `#C62828` | 이벤트 타임라인 |
| 메모 | `noteColor` | `#546E7A` | 이벤트 타임라인 |

### 타이포그래피

| 스타일 | 메서드 | 기반 | 변형 |
|--------|--------|------|------|
| 섹션 타이틀 | `sectionTitle(context)` | `titleLarge` | `bold` |
| 서브섹션 타이틀 | `subsectionTitle(context)` | `titleMedium` | `w600` |

---

## 2. 공유 위젯

### `AppTag` (`lib/shared/widgets/app_tag.dart`)

태그 라벨을 색상 배경 칩으로 표시.

```dart
// 기본 (태그명에 따라 자동 색상)
AppTag(label: '입문')

// 커스텀 색상
AppTag(label: '특별', color: Colors.purple)
```

- 배경: `tagColor`의 12% alpha
- 글씨: `tagColor` 원색, 11px, w600
- radius: `chipRadius` (8px)

### `SectionHeader` (`lib/shared/widgets/section_header.dart`)

섹션 제목 + 선택적 우측 액션.

```dart
// 기본
SectionHeader(title: '사육 가이드')

// 우측 액션 포함
SectionHeader(
  title: '내 개체',
  trailing: TextButton(onPressed: ..., child: Text('더보기')),
)
```

- 하단 간격: `spacing12` (12px)
- 타이틀 스타일: `sectionTitle` (titleLarge + bold)

### `SkeletonLoading` (`lib/shared/widgets/skeleton_loading.dart`)

로딩 상태용 스켈레톤 UI. `shimmer` 패키지 기반.

```dart
// 단일 스켈레톤
SkeletonLoading(width: 100, height: 20)

// 카드 스켈레톤
SkeletonCard(height: 120)

// 리스트 타일 스켈레톤
SkeletonListTile()

// 페이지 전체 스켈레톤
SkeletonPageLoading()

// 리스트 스켈레톤
SkeletonListLoading(itemCount: 5)
```

> **규칙**: `CircularProgressIndicator` 사용 금지. 모든 로딩 상태는 스켈레톤 UI 사용.

---

## 3. 테마 (`lib/core/theme/app_theme.dart`)

### 색상

- Primary: `#2E7D32` (Green 800) — `ColorScheme.fromSeed`
- Secondary: `#FF8F00` (Amber 800)
- 테마 모드: `ThemeMode.system` (시스템 설정 따름)

### 폰트

- **Pretendard** (4 weights: Regular, Medium, SemiBold, Bold)
- 정의: `pubspec.yaml` fonts 섹션
- 적용: `AppTheme._buildTextTheme()`에서 전체 TextTheme에 일괄 적용

---

## 4. 사용 규칙

### DO

- 간격은 `AppStyles.spacingN` 사용
- 태그 표시는 `AppTag` 위젯 사용
- 섹션 제목은 `SectionHeader` 위젯 사용
- 로딩 상태는 `Skeleton*` 위젯 사용
- 새 태그 색상은 `AppStyles.tagColor()`에 추가

### DON'T

- 하드코딩 색상 (`Color(0xFF...)`) 직접 사용 금지
- `CircularProgressIndicator` 사용 금지
- 섹션 제목 스타일 인라인 정의 금지
- `Chip` 위젯 대신 `AppTag` 사용

---

## 5. 향후 계획

| 단계 | 내용 | 시기 |
|------|------|------|
| 현재 | Static `AppStyles` + 공유 위젯 | 지금 |
| 다음 | `ThemeExtension` 전환 (다크모드 토큰 분리) | 다크모드 커스텀 필요 시 |
| 미정 | Figma → Dart 코드 생성 | 디자이너 합류 시 |
