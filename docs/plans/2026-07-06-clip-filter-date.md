# 비디오 기록 — 분류 필터 + 날짜 + 태그 (S3b) Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 승인 후 flutter-dev가 task별 구현(GATE 4). Steps use checkbox (`- [ ]`).

**Goal:** 크레캠 비디오 기록에 ① 상단 **분류 필터**(default 전체) ② 카드 **분류 태그**(없으면 "미분류") ③ **날짜 선택(달력)**을 추가한다. 마이그레이션 없음(옵션 B) — 날짜는 실동작, 분류는 프레임만(현재 데이터 0 → 전부 "미분류").

**Architecture:** `motion_clips`엔 분류 컬럼이 없으므로 `MotionClip.action`은 지금 항상 `null`(미분류). **날짜 필터는 서버**(`started_at` 하루 범위), **분류 필터는 클라이언트**(받은 목록을 `action`으로 거름 — 전부 null이라 지금은 전체=미분류만 유효). 분류 저장소가 생기면 `MotionClip.fromJson`의 action 파싱 **한 줄**만 바꾸면 필터·태그가 자동 작동한다(단일 연결점).

**Tech Stack:** Flutter · Riverpod · supabase_flutter · easy_localization · Material showDatePicker

**범위 밖:** 분류 저장소(테이블/컬럼) 생성 — 백엔드 VLM 파이프라인 확정 시. 서버측 action 필터(저장소 생긴 뒤). 페이지네이션.

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `lib/features/my_cage/domain/motion_clip.dart` | Modify | `action` 필드(String?, 지금 null) 추가 |
| `lib/features/my_cage/domain/clip_action.dart` | Create | 행동 목록 상수 + i18n 키 helper |
| `lib/features/my_cage/data/motion_clip_repository.dart` | Modify | `listByCamera`에 `day` 파라미터(started_at 범위) |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | `motionClipsProvider` 키에 day 추가 + 필터 state provider 2개 |
| `lib/features/my_cage/presentation/widgets/motion_clip_card.dart` | Modify | action 태그(AppTag, 없으면 미분류) |
| `lib/features/my_cage/presentation/camera_detail_screen.dart` | Modify | `_VideoLogSection`에 필터 바(분류+날짜) + 클라 필터 + `_motionClipsProvider` 키 반영 |
| `assets/l10n/ko.json` | Modify | 행동 8종·미분류·필터/날짜 문자열 |

**테스트 전략:** S1/S3 관례 — `MotionClip.fromJson`(action 포함) 순수 테스트만 갱신, 나머지는 analyze + 통합검증.

---

## Task 1: MotionClip.action + clip_action 상수

**Files:** Modify `motion_clip.dart` · Create `clip_action.dart` · Modify `test/features/my_cage/motion_clip_test.dart`

- [ ] **Step 1: clip_action.dart 생성**

`lib/features/my_cage/domain/clip_action.dart`:
```dart
/// motion_clips 행동 분류 카테고리. behavior 라벨링 enum과 동일 값 재사용.
/// 실제 분류는 백엔드 VLM이 채운다(현재 앱 데이터 0 → 전부 미분류).
const List<String> kClipActions = [
  'moving',
  'shedding',
  'eating_paste',
  'eating_prey',
  'drinking',
  'hand_feeding',
  'defecating',
  'unseen',
];

/// action 코드 → i18n 키. `'clip_action_$action'`. 알 수 없는 값은 그대로.
String clipActionKey(String action) => 'clip_action_$action';
```

- [ ] **Step 2: MotionClip.action 추가**

`motion_clip.dart`의 필드에 `action` 추가. 최종 형태:
```dart
class MotionClip {
  final String id;
  final String cameraId;
  final DateTime startedAt;
  final double durationSec;
  final double? motionScore;
  final String? thumbnailKey;
  final String? action; // 행동 분류. null = 미분류. (motion_clips엔 아직 없음)

  const MotionClip({
    required this.id,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    this.motionScore,
    this.thumbnailKey,
    this.action,
  });

  factory MotionClip.fromJson(Map<String, dynamic> j) {
    return MotionClip(
      id: j['id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      startedAt: j['started_at'] != null
          ? DateTime.tryParse(j['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationSec: (j['duration_sec'] as num?)?.toDouble() ?? 0,
      motionScore: (j['motion_score'] as num?)?.toDouble(),
      thumbnailKey: j['thumbnail_key'] as String?,
      // 후속 연결점: 분류 저장소 생기면 여기만 교체.
      // 예) motion_clip_labels 조인 시: (j['motion_clip_labels'] as List?)?.isNotEmpty == true
      //        ? (j['motion_clip_labels'] as List).first['action'] as String? : null
      action: j['action'] as String?,
    );
  }
}
```

- [ ] **Step 3: 테스트에 action 케이스 추가**

`test/features/my_cage/motion_clip_test.dart`의 '완전한 JSON' 테스트에 `'action': 'moving'` 추가 + 검증 `expect(c.action, 'moving');`, '필수 누락' 테스트에 `expect(c.action, isNull);` 추가.

- [ ] **Step 4: 테스트 + analyze**

Run: `flutter test test/features/my_cage/motion_clip_test.dart`
Expected: PASS.
Run: `flutter analyze lib/features/my_cage/domain/motion_clip.dart lib/features/my_cage/domain/clip_action.dart`
Expected: No issues.

- [ ] **Step 5: 커밋**
```bash
git add lib/features/my_cage/domain/motion_clip.dart lib/features/my_cage/domain/clip_action.dart test/features/my_cage/motion_clip_test.dart
git commit -m "feat(my_cage): MotionClip.action + 행동 카테고리 상수 (S3b)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Repository 날짜 필터 + Provider

**Files:** Modify `motion_clip_repository.dart` · Modify `my_cage_providers.dart`

- [ ] **Step 1: listByCamera에 day 파라미터**

`motion_clip_repository.dart`의 `listByCamera`를 교체:
```dart
  /// 카메라의 모션 클립 목록 (최신순). [day]가 주어지면 그 날(로컬 00:00~24:00)로
  /// started_at 범위 필터. RLS로 본인 카메라 것만.
  Future<List<MotionClip>> listByCamera(String cameraId,
      {int limit = 50, DateTime? day}) async {
    var q = _supabase.from('motion_clips').select().eq('camera_id', cameraId);
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      q = q
          .gte('started_at', start.toUtc().toIso8601String())
          .lt('started_at', end.toUtc().toIso8601String());
    }
    final rows =
        await q.order('started_at', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => MotionClip.fromJson(r as Map<String, dynamic>))
        .toList();
  }
```
> `var q`는 PostgrestFilterBuilder 체이닝을 위해 타입 추론에 맡긴다(`.eq` 이후 `.gte`/`.lt`/`.order`/`.limit` 순차). clip_repository.dart의 listPage와 동일 패턴이므로 타입 이슈 시 그쪽 참고.

- [ ] **Step 2: Provider 키 변경 + 필터 state**

`my_cage_providers.dart`의 `motionClipsProvider`를 교체(키에 day 추가):
```dart
/// family 키: cameraId + day(null=전체 기간).
typedef MotionClipsKey = ({String cameraId, DateTime? day});

/// 카메라의 모션 클립 목록 (최신 50개). day 지정 시 그 날만.
final motionClipsProvider = FutureProvider.autoDispose
    .family<List<MotionClip>, MotionClipsKey>((ref, key) async {
  return ref
      .watch(motionClipRepositoryProvider)
      .listByCamera(key.cameraId, day: key.day);
});
```
그리고 필터 상태 provider 2개를 그 아래 추가:
```dart
/// 비디오 기록 날짜 필터(null = 전체 기간). autoDispose — 화면 이탈 시 리셋.
final clipDayFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

/// 비디오 기록 분류 필터(null = 전체). 'unlabeled' = 미분류만. 그 외 = 해당 action.
/// 현재 데이터가 없어 클라이언트 사이드로만 적용된다.
final clipActionFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);
```

- [ ] **Step 3: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart`
```bash
git add lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart
git commit -m "feat(my_cage): 모션 클립 날짜 필터 + 분류/날짜 필터 state (S3b)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 카드 태그 + ko.json

**Files:** Modify `motion_clip_card.dart` · Modify `ko.json`

- [ ] **Step 1: ko.json 키 추가**

`ko.json`의 `camera_detail_clips_empty`(현재 있음) 아래 등 적당한 위치에 추가:
```json
  "clip_action_all": "전체",
  "clip_action_unlabeled": "미분류",
  "clip_action_moving": "이동",
  "clip_action_shedding": "탈피",
  "clip_action_eating_paste": "이유식",
  "clip_action_eating_prey": "먹이",
  "clip_action_drinking": "음수",
  "clip_action_hand_feeding": "핸드피딩",
  "clip_action_defecating": "배변",
  "clip_action_unseen": "미확인",
  "clip_filter_date_all": "전체 기간",
```
JSON 유효성: `python3 -c "import json; json.load(open('assets/l10n/ko.json')); print('OK')"`

- [ ] **Step 2: MotionClipCard에 태그**

`motion_clip_card.dart`의 하단 Row(시간/길이)에서, 시간 `Expanded` 다음·길이 앞에 action 태그를 넣는다. import `../../domain/clip_action.dart`, `../../../../shared/widgets/app_tag.dart` 추가. 하단 Row를 교체:
```dart
              child: Row(
                children: [
                  Expanded(
                    child: Text(timeLabel,
                        style: theme.textTheme.bodySmall),
                  ),
                  AppTag(
                    label: clip.action == null
                        ? 'clip_action_unlabeled'.tr()
                        : clipActionKey(clip.action!).tr(),
                    color: clip.action == null
                        ? cs.outline
                        : cs.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    durationLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
```
> `AppTag(label, color?)`, `cs = theme.colorScheme`는 이미 이 파일에 있음. 태그가 길이와 겹치면 시간 Expanded가 흡수한다.

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/my_cage/presentation/widgets/motion_clip_card.dart`
> 커밋은 Task 4와 함께(카드 태그는 필터 바와 한 기능 단위).

---

## Task 4: _VideoLogSection 필터 바 (분류 + 날짜) + 클라 필터

**Files:** Modify `camera_detail_screen.dart`

- [ ] **Step 1: _motionClipsProvider 키 반영**

`camera_detail_screen.dart`의 로컬 별칭 `_motionClipsProvider`(현재 `family<List<MotionClip>, String>`)를 삭제하고, `_VideoLogSection`이 `motionClipsProvider`를 직접 day 키로 watch하도록 바꾼다(아래 Step 2에 포함). import에 `../domain/clip_action.dart` 추가.

- [ ] **Step 2: _VideoLogSection.build 교체**

`_VideoLogSection.build`에서 `clipsAsync` watch와 본문을 교체한다. 필터 바(분류 드롭다운 + 날짜 버튼)를 제목 아래·목록 위에 넣고, 받은 목록을 분류로 클라 필터한다:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(clipDayFilterProvider);
    final actionFilter = ref.watch(clipActionFilterProvider);
    final clipsAsync =
        ref.watch(motionClipsProvider((cameraId: cameraId, day: day)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'crecam_detail_video_log'.tr(),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _FilterBar(cameraId: cameraId),
        const SizedBox(height: 12),
        if (kShowVerifyClip) ...[
          _VerifyClipsSection(ref: ref),
          const SizedBox(height: 12),
        ],
        clipsAsync.when(
          loading: () => _buildSkeletonList(),
          error: (e, _) => _buildError(context, ref),
          data: (clips) {
            // 분류 클라 필터: null=전체, 'unlabeled'=미분류(action null), 그 외=action 일치.
            final filtered = actionFilter == null
                ? clips
                : clips.where((c) => actionFilter == 'unlabeled'
                    ? c.action == null
                    : c.action == actionFilter).toList();
            if (filtered.isEmpty) return _buildEmptyAction(context);
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: filtered
                  .map((c) => MotionClipCard(
                        clip: c,
                        onTap: () =>
                            context.push('/crecam/motion-clips/${c.id}'),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
```

- [ ] **Step 3: _FilterBar 위젯 추가**

`_VideoLogSection` 클래스 아래에 추가:
```dart
/// 비디오 기록 필터 바 — 분류 드롭다운 + 날짜 선택.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.cameraId});
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(clipDayFilterProvider);
    final actionFilter = ref.watch(clipActionFilterProvider);

    final dayLabel = day == null
        ? 'clip_filter_date_all'.tr()
        : DateFormat('yyyy.MM.dd').format(day);

    return Row(
      children: [
        // 분류 드롭다운
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: actionFilter,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text('clip_action_all'.tr())),
              DropdownMenuItem(
                  value: 'unlabeled',
                  child: Text('clip_action_unlabeled'.tr())),
              ...kClipActions.map((a) => DropdownMenuItem(
                  value: a, child: Text(clipActionKey(a).tr()))),
            ],
            onChanged: (v) =>
                ref.read(clipActionFilterProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        // 날짜 선택
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(dayLabel),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ref.read(clipDayFilterProvider.notifier).state = picked;
            }
          },
        ),
        if (day != null)
          IconButton(
            tooltip: 'clip_filter_date_all'.tr(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                ref.read(clipDayFilterProvider.notifier).state = null,
          ),
      ],
    );
  }
}
```
> `DateFormat`은 이 파일에서 이미 import(intl via easy_localization). `ConsumerWidget`/`ref` 사용. `DropdownButtonFormField`의 nullable value는 정상 동작.

- [ ] **Step 4: 전체 analyze + 회귀 테스트**

Run: `flutter analyze`
Expected: 신규/수정 파일 이슈 0(에러 0). `_motionClipsProvider` 삭제로 인한 미사용 정리 확인.
Run: `flutter test`
Expected: 전부 PASS.

- [ ] **Step 5: 커밋 (Task 3+4)**
```bash
git add lib/features/my_cage/presentation/widgets/motion_clip_card.dart \
        lib/features/my_cage/presentation/camera_detail_screen.dart \
        assets/l10n/ko.json
git commit -m "feat(my_cage): 비디오 기록 분류 필터+태그+날짜 달력 (S3b, 마이그레이션 없음)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (push 전)
- **버전 bump**: feature → `0.9.0+18` → `0.10.0+19`.
- **검증(S5)**: P4 Cam 상세 비디오 기록 → 분류 드롭다운(전부 미분류만 결과)·날짜 선택 시 그 날 클립만·카드에 "미분류" 태그.
- **후속 단일 연결점**: 분류 저장소 확정 시 `MotionClip.fromJson`의 `action` 파싱만 교체(+필요 시 repo select에 조인) → 필터/태그 자동 작동.

---

## Self-Review

**1. 커버리지:** ① 필터(분류 드롭다운, default 전체=null) → Task 4 `_FilterBar` · ② 태그(없으면 미분류) → Task 3 카드 · ③ 날짜 달력 → Task 4 showDatePicker + Task 2 서버 필터. 3개 다 있음.

**2. Placeholder 스캔:** 실제 코드만. "미분류 껍데기"는 의도된 스코프(옵션 B) — 데이터 부재를 코드가 정상 처리(action null → 미분류).

**3. 타입 일관성:**
- `MotionClip.action`(String?) — Task 1 정의 = Task 3 카드(`clip.action`) = Task 4 필터(`c.action`) 일치.
- `MotionClipsKey = ({String cameraId, DateTime? day})` — Task 2 정의 = Task 4 watch(`(cameraId: cameraId, day: day)`) 일치.
- `clipDayFilterProvider`(DateTime?)·`clipActionFilterProvider`(String?) — Task 2 정의 = Task 4 read/watch 일치.
- `kClipActions`·`clipActionKey` — Task 1 정의 = Task 3/4 소비 일치.
- `listByCamera(cameraId, {limit, day})` — Task 2 정의 = provider 호출 일치.

**주의(구현자):**
- `_motionClipsProvider` 로컬 별칭 삭제 → `_VideoLogSection`이 `motionClipsProvider` 직접 사용. 다른 참조 없는지 확인(camera_detail 내 유일 사용처).
- 필터 state는 autoDispose라 화면 이탈 시 리셋(카메라 전환 간 필터 누수 없음).
- 날짜 필터는 서버(정확), 분류 필터는 클라(현재 데이터 0이라 무의미하지만 프레임). 저장소 생기면 분류도 서버로 옮길 수 있으나 이번 범위 밖.
