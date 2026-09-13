# 홈·온습도 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Figma 역할별 색과 SVG를 적용하고 정확한 대표 온습도·주간 강조·팬 선택 후 실행을 구현한다.

**Architecture:** 순수 집계/분류 함수는 domain, 날짜·실시간 조합은 Provider, 팬 명령은 기존 cage_control_actions에 둔다. UI는 계산과 직접 기기 명령을 수행하지 않는다.

**Tech Stack:** Flutter, Riverpod, flutter_svg, easy_localization, 기존 telemetry/command Repository.

**Spec:** [승인 설계 §2·3·7·8](2026-09-13-app-design-review.md), [통합 계획](2026-09-14-app-implementation-plan.md).

## Global Constraints

- 통합 계획의 Global Constraints를 모두 적용한다. 과거 평균 연결은 G0의 유효 count 검증 이후 진행한다.
- 대표값 온도 `#C00306`/습도 `#192553`, 막대 최고 온도 `#D61619`/습도 `#2E408C`, 일반 `#626262`/최저 `#B4AEAE`를 서로 다른 역할 토큰으로 둔다.
- 0 센티넬 규칙은 현재 telemetry 계약에 한정한다. 미래 다른 센서에 범용 0℃ 금지 규칙을 만들지 않는다.

## A1: 공통 SVG와 색 역할 적용

**Files — 수정:** `lib/core/theme/glass_palette.dart`, `lib/shared/widgets/{figma_icon,glass_dock}.dart`, `lib/core/router/tab_branches.dart`, `assets/icons/`의 매핑 대상 SVG, 필요 시 `pubspec.yaml`. 생성: `docs/design-audits/2026-09-14-runtime-svg-map.md`.

**책임:** 원본 30개와 실제 소비 노드를 연결한다. 선언·생성자·dark·light·copyWith·lerp의 6곳을 함께 유지한다. 새 토큰은 `envTempValue`, `envHumidValue`, `envTempPeak`, `envHumidPeak`, `envBarNeutral`, `envBarMinimum`, `navSelected`, `navUnselected`로 명시하고 일반 브랜드 primary를 일괄 빨강으로 바꾸지 않는다.

- [ ] 원본 manifest의 node ID/viewBox를 기존 `FigmaIcons`·`kHomeTabIconAssets`와 연결해 source→runtime→consumer 표를 작성한다. fan_on/off 같은 원형 배경 포함 자산은 위젯 배경 중복 여부를 시각 확인한다.
- [ ] 역할 토큰을 추가하고 라이트는 원본 색, 다크는 기존 대응 역할의 가독성을 보존한다. 막대와 대표값 소비는 H1/H2에서 연결한다. 표면 `#F4F4F4`, 헤더 `#FAFAFA`, 선 `#E3E3E3`, 팬 `#228C73`, 냉각 `#636DDB`, LED `#E89E00`는 감사 노드에 해당하는 소비처에 매핑한다.
- [ ] SVG 파생본을 등록한다. 단색 tint용 자산만 currentColor에 맞추고 다색/마스크 자산의 path와 비율을 유지한다. 아직 확보하지 않은 pause·추가 배속·축소·측정 아이콘은 해당 작업 시 원본 노드를 추가 export해 manifest에 기록한다.
- [ ] 독 safe area 포함 높이·활성/비활성 SVG·각 제어 on/off 상태를 Figma와 캡처 비교한다. 단순 스타일을 복제하는 테스트는 추가하지 않는다. `flutter analyze --no-pub` 에러 0 확인 후 `feat: align shared assets with Final Design` 커밋.

## H1: 오늘 실시간 / 과거 일평균

**Files — 생성:** `lib/features/home/domain/env_daily_average.dart`, `test/features/home/env_daily_average_test.dart`. 수정: `lib/features/home/presentation/{env_detail_providers,env_detail_screen}.dart`, `lib/features/my_cage/domain/telemetry_bucket.dart`, `lib/features/my_cage/data/supabase_module_control_repository.dart`(G0 결과에 따른 필드 매핑만), `assets/l10n/ko.json`, `test/features/home/env_detail_screen_test.dart`.

**Interface:** `double? weightedDailyMean(Iterable<({double? mean, int validCount})> samples)`. `envDailyAverageProvider`는 현재 날짜의 버킷을 소비해 `({double? temperature, double? humidity})`를 반환한다. 유효 count가 검증되지 않으면 Repository 어댑터를 연결하지 않는다.

- [ ] 아래 불균등 표본/무표본 테스트부터 추가한다. 지표별 count가 다른 fixture도 각각 함수에 입력한다.

```dart
test('표본 수가 다른 버킷을 가중 평균한다', () {
  expect(weightedDailyMean([
    (mean: 20.0, validCount: 1),
    (mean: 30.0, validCount: 3),
    (mean: 0.0, validCount: 100),
  ]), 27.5);
  expect(weightedDailyMean([(mean: null, validCount: 0)]), isNull);
});
```

- [ ] `flutter test test/features/home/env_daily_average_test.dart` 실행: 함수 미정의 또는 잘못된 평균으로 실패를 확인한다.
- [ ] 도메인 함수를 구현한다. null/nonfinite/0 센티넬/음수·0 count를 제외하고 두 지표를 별도 호출한다.

```dart
double? weightedDailyMean(
  Iterable<({double? mean, int validCount})> samples,
) {
  var sum = 0.0;
  var count = 0;
  for (final sample in samples) {
    final value = sample.mean;
    if (value == null || !value.isFinite || value <= 0 ||
        sample.validCount <= 0) continue;
    sum += value * sample.validCount;
    count += sample.validCount;
  }
  return count == 0 ? null : sum / count;
}
```

- [ ] `env_detail_screen`의 `_valueBar`에서 `tempAt(1.0)/humidAt(1.0)` fallback을 제거한다. 오늘은 기존 최신성 판정에 유효한 telemetry만 표시하고 과거는 평균 Provider를 사용한다. 지표별 null은 `--`; 조회 실패는 재시도 상태, 로딩은 높이 유지 skeleton. `실시간`/`일평균` 문구는 l10n 키로 둔다.
- [ ] 기존 `_pump` 테스트 harness에 telemetry·평균 override를 추가한다. 오늘 28℃/60%, 과거 27.5℃/55%, 오늘 stale `--`, 무표본 `--`, 날짜/기기 전환 중 늦은 응답 미노출, 자정 뒤 오늘→과거 전환을 검증한다.
- [ ] `flutter test test/features/home/env_daily_average_test.dart test/features/home/env_detail_screen_test.dart`와 analyze를 통과시킨 후 `fix: show realtime and daily mean environment values` 커밋.

## H2: 주간 최고/일반/최저와 동률

**Files — 생성:** `lib/shared/domain/week_bar_role.dart`, `test/features/shared/week_bar_role_test.dart`. 수정: `lib/features/home/presentation/widgets/week_range_chart.dart`; 재검증: `test/features/shared/week_range_test.dart`.

**Interface:** `enum WeekBarRole { empty, neutral, maximum, minimum }`; `List<WeekBarRole> classifyWeekBars(List<DayMinMax> rows, {required int fractionDigits})`. 일간 평균과 독립이며 `DayMinMax.min/max`만 소비한다.

- [ ] 아래 테스트와 전체 동일/단일 유효/빈 날짜/최고최저 동시 해당 테스트를 추가한다.

```dart
test('동률 최저 요일을 모두 연회색 역할로 분류한다', () {
  final roles = classifyWeekBars([
    DayMinMax(day: DateTime(2026, 9, 7), min: 20, max: 25),
    DayMinMax(day: DateTime(2026, 9, 8), min: 20, max: 26),
    DayMinMax(day: DateTime(2026, 9, 9), min: 22, max: 30),
  ], fractionDigits: 1);
  expect(roles, [WeekBarRole.minimum, WeekBarRole.minimum,
    WeekBarRole.maximum]);
});
```

- [ ] `flutter test test/features/shared/week_bar_role_test.dart`로 미구현 실패를 확인한다.
- [ ] 화면 표시 정밀도로 비교값을 정규화한다. 유효 요일이 1개 이하 또는 모든 범위가 같으면 neutral, 그 외 주간 max 일치→maximum, 주간 min 일치→minimum, 나머지 neutral 순서로 분류한다. 부분 데이터는 존재하는 유효 끝점만 비교하고 빈 행은 empty로 둔다.
- [ ] `peakIndex` 단일 비교를 역할 리스트로 바꾸고 A1 색 토큰으로 연결한다. 요일 7칸·기존 max/min 숫자·빈 막대 정책을 유지하고 최저 헤더 색도 원본에 맞춘다.
- [ ] `flutter test test/features/shared/week_bar_role_test.dart test/features/shared/week_range_test.dart test/features/home/env_detail_screen_test.dart`와 analyze를 확인하고 Figma `945:3428` 비교 후 `fix: distinguish weekly minimum bars and ties` 커밋.

## H3: 팬 선택→시작, 일정 라벨

**Files — 생성:** `lib/features/home/presentation/widgets/fan_duration_sheet.dart`, `test/features/home/fan_duration_sheet_test.dart`. 수정: `lib/features/home/presentation/cage_control_actions.dart`, 필요 시 `lib/features/home/presentation/widgets/cage_control_grid.dart`, `test/features/home/cage_control_grid_test.dart`, `assets/l10n/ko.json`.

**Interface:** 시트 반환은 기존 `(FanTimerDuration?,)?` 의미를 유지한다: 바깥 null=취소, `(null,)`=계속 켜기, `(duration,)`=선택 시간. 선택 상태는 Riverpod autoDispose이며 시작 콜백의 중복 실행을 막는다.

- [ ] 시트 테스트에 옵션 선택까지 명령/결과 확정 0회, 시작 클릭 후 선택 결과 1회, 닫기 null을 검증한다. 기존 grid harness에는 명령 Repository fake를 넣어 아래 명령 수 기준을 검증한다.

```text
꺼진 팬 탭 → 30분 선택 → 뒤로가기: fan_on 0건
꺼진 팬 탭 → 30분 선택 → 시작 두 번: fan_on 1건, duration_ms=1800000
켜진 팬 탭: fan_off 1건
시트 표시 중 선택 기기 변경/오프라인 → 시작: fan_on 0건, 대상/오프라인 안내
```

- [ ] `flutter test test/features/home/cage_control_grid_test.dart test/features/home/fan_duration_sheet_test.dart` 실행: 기존 즉시 시작 경로에서 명령 수 테스트 실패를 확인한다.
- [ ] 꺼짐 `handleFanTap`은 시트를 연다. 선택 버튼은 선택 상태만 바꾸고 시작 버튼만 `Navigator.pop(context, (selectedDuration,))`을 호출한다. 시작 결과를 받은 actions에서 원래 deviceId·online·mounted를 재확인하고 기존 `_startFan`을 1회 실행한다.
- [ ] 직전 선택을 초기 제안으로 읽되 자동 실행하지 않는다. `_startFan`의 타이머/ACK/알림 처리를 유지하고 시트에서 API를 호출하지 않는다. on→off 동작도 기존 actions 경로를 유지한다. `home_routine_settings`를 `일정`으로 변경한다.
- [ ] 위 테스트와 `flutter test test/features/home/fan_timer_duration_test.dart test/fan_timer_notification_plan_test.dart`/analyze를 확인한다. 실제 기기에서 취소 무명령·시작 ACK·자동 OFF를 별도 확인 후 `feat: choose fan duration before starting` 커밋.
