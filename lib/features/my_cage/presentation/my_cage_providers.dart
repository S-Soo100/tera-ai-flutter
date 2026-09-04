import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/camera_repository.dart';
import '../data/enclosure_repository.dart';
import '../data/clip_repository.dart';
import '../data/favorite_clip_repository.dart';
import '../data/highlight_banner_store.dart';
import '../data/highlight_repository.dart';
import '../data/motion_clip_repository.dart';
import '../data/video_cache_repository.dart';
import '../data/video_export_service.dart';
import '../data/webrtc_signaling_repository.dart';
import '../domain/behavior_inference.dart';
import '../domain/behavior_label.dart';
import '../domain/cage_activity.dart';
import '../domain/clip.dart';
import '../domain/clip_media_url.dart';
import '../domain/favorite_clip.dart';
import '../domain/highlight_group.dart';
import '../domain/motion_clip.dart';
import '../domain/nightly_highlight.dart';
import '../domain/nightly_report.dart';
import '../domain/terra_camera.dart';
import '../domain/enclosure.dart';
import 'highlights_controller.dart';

// ── 내부 인프라 Provider ───────────────────────────────────────────────────────

/// SupabaseClient 싱글톤. auth_providers에 동일 Provider 없으므로 여기서 정의.
final _supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// JWT accessToken 공급자. 매 호출마다 currentSession을 읽어 최신 토큰 반환.
final _tokenProviderProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => Supabase.instance.client.auth.currentSession?.accessToken,
);

// ── Repository Provider ────────────────────────────────────────────────────────

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  return CameraRepository(
    supabase: ref.watch(_supabaseClientProvider),
  );
});

final enclosureRepositoryProvider = Provider<EnclosureRepository>((ref) {
  return EnclosureRepository(
    supabase: ref.watch(_supabaseClientProvider),
  );
});

final clipRepositoryProvider = Provider<ClipRepository>((ref) {
  return ClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
    backendUrl: EnvConfig.backendUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

final motionClipRepositoryProvider = Provider<MotionClipRepository>((ref) {
  return MotionClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
    terraApiUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

final webrtcSignalingRepositoryProvider =
    Provider<WebRtcSignalingRepository>((ref) {
  return WebRtcSignalingRepository(
    terraServerUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
    supabase: ref.watch(_supabaseClientProvider),
  );
});

/// WebRTC ICE 설정 (terra-server GET /cameras/webrtc/config) — 세션 캐시.
/// 내용이 사실상 정적(iceServers)이라 라이브 진입마다 왕복하지 않는다.
/// 실패가 캐시되면 컨트롤러의 수동 retry()가 invalidate 후 재시도한다.
final webrtcConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(webrtcSignalingRepositoryProvider).fetchConfig();
});

// ── 공개 FutureProvider ────────────────────────────────────────────────────────

/// 현재 유저의 카메라 전체 목록 (최신순).
///
/// Realtime: `cameras` 테이블 변경(특히 `is_online` UPDATE)을 구독해 카메라가
/// 켜지거나 꺼지면 그리드가 자동 갱신된다. 변경 1건마다 전체 재조회(listAll) —
/// 카메라 수가 적어 비용 무시 가능, RLS는 재조회 쿼리에서 그대로 적용된다.
/// (`cameras`는 supabase_realtime 발행 목록에 포함 — 백엔드 변경 불필요)
final camerasProvider = StreamProvider<List<TerraCamera>>((ref) {
  ref.watch(currentUserProvider
      .select((u) => u?.id)); // 계정 전환 시 재구독+재조회 (이전 계정 카메라 노출 방지)
  final repo = ref.watch(cameraRepositoryProvider);
  final supabase = ref.watch(_supabaseClientProvider);

  final controller = StreamController<List<TerraCamera>>();

  Future<void> reload() async {
    try {
      final list = await repo.listAll();
      if (!controller.isClosed) controller.add(list);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    }
  }

  unawaited(reload()); // 최초 seed

  final channel = supabase.channel('cameras-rt');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'cameras',
        callback: (_) => unawaited(reload()),
      )
      .subscribe();

  ref.onDispose(() {
    // ignore: discarded_futures
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// 단일 카메라 조회. 존재하지 않으면 null.
final cameraProvider =
    FutureProvider.family<TerraCamera?, String>((ref, id) async {
  return ref.watch(cameraRepositoryProvider).getById(id);
});

/// 홈 대시보드 대표 카메라 — 가장 최근 모션이 있는(활성) 카메라. 모션 이력이
/// 전혀 없으면 최신 등록(cameras 목록 첫 번째)로 폴백. 카메라 없으면 null.
/// 카메라 1대면 그 카메라, 여러 대면 카메라당 최근 모션시각 1건씩 조회해 최댓값.
/// ('최신 등록' 대표는 조용한 카메라를 대표로 잡는 문제가 있어 '최근 모션'으로 선정.)
final representativeCameraProvider =
    FutureProvider.autoDispose<TerraCamera?>((ref) async {
  final cameras = await ref.watch(camerasProvider.future);
  if (cameras.isEmpty) return null;
  if (cameras.length == 1) return cameras.first;
  final repo = ref.watch(motionClipRepositoryProvider);
  TerraCamera? best;
  DateTime? bestAt;
  for (final c in cameras) {
    final at = await repo.latestMotionAt(c.id);
    if (at != null && (bestAt == null || at.isAfter(bestAt))) {
      bestAt = at;
      best = c;
    }
  }
  return best ?? cameras.first; // 모션 이력 전무 시 최신 등록 폴백
});

// ── 사육장(enclosure) Provider ─────────────────────────────────────────────────

/// 현재 유저의 사육장 목록 (최신순). 계정 전환 시 재조회(이전 계정 노출 방지 —
/// project_auth_provider_stale_pattern). 생성/수정 후 ref.invalidate로 갱신한다.
final enclosuresProvider = FutureProvider<List<Enclosure>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(enclosureRepositoryProvider).listAll();
});

/// 단일 사육장 조회. 존재하지 않으면 null.
final enclosureProvider =
    FutureProvider.family<Enclosure?, String>((ref, id) async {
  return ref.watch(enclosureRepositoryProvider).getById(id);
});

// ── 시간대별 클립 조회 Provider ────────────────────────────────────────────────

/// family 키: cameraId + 날짜(y-m-d 정규화) + hour(0~23)
typedef ClipsHourKey = ({
  String cameraId,
  DateTime date,
  int hour,
});

/// 선택된 1시간 구간의 클립 목록 (ASC 정렬, 페이징 없음).
final clipsForHourProvider =
    FutureProvider.family<List<Clip>, ClipsHourKey>((ref, key) async {
  final start = DateTime(key.date.year, key.date.month, key.date.day, key.hour);
  final end = start.add(const Duration(hours: 1));
  return ref.watch(clipRepositoryProvider).listInRange(
        cameraId: key.cameraId,
        startedAtGte: start,
        startedAtLt: end,
      );
});

/// family 키: cameraId + 날짜(y-m-d 정규화)
typedef HourCountsKey = ({
  String cameraId,
  DateTime date,
});

/// 해당 날짜의 시간대별 클립 개수 (hour → count, 키 0~23 전체 포함).
final hourCountsProvider =
    FutureProvider.family<Map<int, int>, HourCountsKey>((ref, key) async {
  return ref.watch(clipRepositoryProvider).countByHourForDate(
        cameraId: key.cameraId,
        date: key.date,
      );
});

/// 가장 최근 클립의 startedAt. 초기 진입 시 날짜+시간 자동 점프용.
final latestClipTimeProvider =
    FutureProvider.family<DateTime?, String>((ref, cameraId) async {
  return ref.watch(clipRepositoryProvider).getLatestStartedAt(
        cameraId: cameraId,
      );
});

/// 클립 영상 presigned URL. clip_player_screen이 await + 만료 시 ref.refresh.
final clipFileUrlProvider = FutureProvider.autoDispose
    .family<ClipMediaUrl, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getFileUrl(clipId);
});

/// 클립 썸네일 presigned URL. ClipThumbnail이 watch.
final clipThumbnailUrlProvider = FutureProvider.autoDispose
    .family<ClipMediaUrl, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getThumbnailUrl(clipId);
});

/// 클립 human 라벨 목록. 빈 배열 정상, 에러는 silent fail (섹션 숨김).
final clipLabelsProvider = FutureProvider.autoDispose
    .family<List<BehaviorLabel>, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getLabels(clipId);
});

/// 클립 VLM 추론 1건 또는 null. 추론 없으면 null, 에러는 silent fail.
final clipInferenceProvider = FutureProvider.autoDispose
    .family<BehaviorInference?, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getInference(clipId);
});

// ── 모션 클립 (motion_clips, S3) ────────────────────────────────────────────────

/// family 키: cameraId + day(null=전체 기간).
typedef MotionClipsKey = ({String cameraId, DateTime? day});

/// 카메라의 모션 클립 목록 (최신 200개). day 지정 시 그 날만.
///
/// limit 200 명시(리뷰 2026-09-04) — repository 기본 50을 그대로 쓰면 모션이
/// 활발한 날(일 100건대 실측) 하루 그리드가 밤 시간대만 남고 **조용히**
/// 잘린다. 200은 listByCameraInWindow와 같은 상한.
final motionClipsProvider = FutureProvider.autoDispose
    .family<List<MotionClip>, MotionClipsKey>((ref, key) async {
  return ref
      .watch(motionClipRepositoryProvider)
      .listByCamera(key.cameraId, day: key.day, limit: 200);
});

/// 비디오 기록 날짜 필터(null = 전체 기간). autoDispose — 화면 이탈 시 리셋.
final clipDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 비디오 기록 분류 필터(null = 전체). 'unlabeled' = 미분류만. 그 외 = 해당 action.
/// 현재 데이터가 없어 클라이언트 사이드로만 적용된다.
final clipActionFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// 모션 클립 재생 presigned URL. 재생 화면이 await, 만료 시 refresh.
final motionClipUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, clipId) async {
  return ref.watch(motionClipRepositoryProvider).getPlaybackUrl(clipId);
});

/// 단일 모션 클립 메타(즐겨찾기 추가·재생화면 제목용). 없으면 null.
final motionClipProvider =
    FutureProvider.autoDispose.family<MotionClip?, String>((ref, clipId) async {
  return ref.watch(motionClipRepositoryProvider).getById(clipId);
});

/// family 키: cameraId + range. 움직임 시간(초).
typedef MotionActivityKey = ({String cameraId, ActivityRange range});

/// 추정 활동시간(초) — effective activity view 합. view 장애 시 repository가
/// motion_clips 원본 duration 합으로 fail-open한다. 하루 경계는 오전 7시다.
final motionActivityProvider =
    FutureProvider.autoDispose.family<int, MotionActivityKey>((ref, key) async {
  final bounds = activityRangeBounds(key.range, DateTime.now());
  return ref
      .watch(motionClipRepositoryProvider)
      .motionSeconds(key.cameraId, bounds.start, bounds.end);
});

/// 시간대별 추정 활동시간(초) 24개 — 총합과 같은 effective row를 1시간
/// bucket으로 나눈다. 하루 경계는 오전 7시다.
final hourlyActivityProvider = FutureProvider.autoDispose
    .family<List<int>, MotionActivityKey>((ref, key) async {
  final bounds = activityRangeBounds(key.range, DateTime.now());
  return ref
      .watch(motionClipRepositoryProvider)
      .motionSecondsByHour(key.cameraId, bounds.start, bounds.end);
});

// ── 모션 클립 썸네일 (terra-api GET /clips/{id}/thumbnail/url, #1) ───────────────
// 클라 첫프레임 추출 → 서버 presigned 썸네일로 스왑(백엔드 5809a47). R2 실제 썸네일.

/// 모션 클립 썸네일 presigned URL. 없으면(404) null → 카드 아이콘 폴백.
final motionThumbnailProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, clipId) async {
  return ref.watch(motionClipRepositoryProvider).getThumbnailUrl(clipId);
});

// ── 캐시 Repository Provider ───────────────────────────────────────────────────

/// 영상 로컬 캐시 Repository. VideoCacheRepository.init()은 main()에서 선 실행.
final videoCacheRepositoryProvider = Provider<VideoCacheRepository>((ref) {
  return VideoCacheRepository();
});

// ── 즐겨찾기 (로컬, #4) ─────────────────────────────────────────────────────────

final favoriteClipRepositoryProvider = Provider<FavoriteClipRepository>((ref) {
  return FavoriteClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
  );
});

/// 카메라의 즐겨찾기 목록(로컬). add/remove 후 invalidate로 갱신.
final favoriteClipsProvider =
    Provider.autoDispose.family<List<FavoriteClip>, String>((ref, cameraId) {
  return ref.watch(favoriteClipRepositoryProvider).listByCamera(cameraId);
});

/// 특정 클립 즐겨찾기 여부. add/remove 후 invalidate.
final isFavoriteProvider =
    Provider.autoDispose.family<bool, String>((ref, clipId) {
  return ref.watch(favoriteClipRepositoryProvider).isFavorite(clipId);
});

/// 즐겨찾기 클라우드→로컬 동기화(탭 진입 시 1회). 완료 후 목록 invalidate로 갱신.
final favoritesSyncProvider =
    FutureProvider.autoDispose.family<void, String>((ref, cameraId) async {
  ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 전환 시 재동기화
  final favRepo = ref.watch(favoriteClipRepositoryProvider);
  final motionRepo = ref.watch(motionClipRepositoryProvider);
  await favRepo.syncFromCloud(motionRepo);
  // pull로 로컬이 늘었을 수 있으니 목록 갱신
  ref.invalidate(favoriteClipsProvider(cameraId));
});

/// 비디오 기록 탭(false=전체, true=즐겨찾기). autoDispose — 화면 이탈 시 리셋.
final showFavoritesTabProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// ── 저장/공유 서비스 (#2) ───────────────────────────────────────────────────────

final videoExportServiceProvider =
    Provider<VideoExportService>((ref) => VideoExportService());

// ── 어젯밤 리포트 (terra-api, 보기 전용) ──────────────────────────────────────

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository(
    terraApiUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

/// 어젯밤(22~06시) 요약 — 하이라이트(전 카메라) + 활동시간 합. 계정 전환 시 재조회.
final nightlyReportProvider =
    FutureProvider.autoDispose<NightlyReport>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final now = DateTime.now();
  final start = lastNightSince(now);
  final end = lastNightEnd(now);
  List<NightlyHighlight> highlights;
  try {
    final all = await ref.watch(highlightRepositoryProvider).list(since: start);
    highlights = all
        .where((h) =>
            h.clipId.isNotEmpty &&
            !h.startedAt.isBefore(start) &&
            !h.startedAt.isAfter(end))
        .toList();
  } catch (_) {
    highlights = const [];
  }
  final cameras = await ref.watch(camerasProvider.future);
  final motionRepo = ref.watch(motionClipRepositoryProvider);
  final secs = await Future.wait(
    cameras.map((c) => motionRepo.motionSeconds(c.id, start, end)),
  );
  final sec = secs.fold<int>(0, (a, b) => a + b);
  return NightlyReport(activitySeconds: sec, highlights: highlights);
});

// ── 카메라 탭 Camera Home (2026-09-04 재설계 T2) ───────────────────────────────

/// 카메라 탭 라이브 PageView의 현재 인덱스 — 아래 클립 그리드의 기준 카메라.
/// 카메라 목록이 줄어들 수 있으니 소비처는 반드시 clamp해서 쓴다.
///
/// **-1 = 아직 사용자가 고른 적 없음(센티넬).** CameraLiveArea가 첫 데이터
/// 프레임에 **홈이 보고 있는 세트의 카메라** 인덱스로 해석해 저장한다 —
/// 안 그러면 카메라 탭이 항상 목록 첫 카메라(무응답일 수 있음)로 열려
/// "홈에선 보이는데 카메라 탭은 안 보임"으로 읽힌다(2026-09-04 사용자 제보).
/// 해석 로직이 여기 없고 위젯에 있는 이유: currentSetProvider(home)를 이
/// 파일이 import하면 home_set_providers ↔ my_cage_providers 순환이 된다.
final selectedCrecamCameraProvider = StateProvider<int>((ref) => -1);

/// 기간 설정 날짜(자정 정규화). 기본 = 오늘.
///
/// **자정을 넘기면 스스로 리셋한다**(리뷰 2026-09-04) — non-autoDispose +
/// IndexedStack 탭이라 안 그러면 첫 read 시점의 "오늘"이 프로세스 수명 내내
/// 고정돼, 자정 후 그리드가 어제에 갇히고 기간 버튼 라벨이 어제 날짜로
/// 바뀐다(env_detail의 `_todayProvider` 선례). 사용자가 고른 과거 날짜도
/// 자정에 오늘로 돌아온다 — 날짜가 바뀌었는데 어제 선택을 유지하는 것보다
/// 덜 놀랍다.
final crecamDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final timer = Timer(
    today.add(const Duration(days: 1, seconds: 1)).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return today;
});

/// 하이라이트 최신 도착 시각 — [highlightGroupsProvider]에서 파생(리뷰
/// 2026-09-04: 같은 API를 limit만 다르게 2회 치던 것을 1회로, 에러를
/// null("아직 없어요")로 뭉개던 것을 에러로 전파).
final latestHighlightAtProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  final groups = await ref.watch(highlightGroupsProvider.future);
  return groups.isEmpty ? null : groups.first.to;
});

/// 전체 즐겨찾기(favoritedAt desc — repository가 정렬). 엔트리 카드 최신
/// 시각 + 북마크 상세(T3)가 쓴다. non-autoDispose이므로 currentUser id
/// select-watch 필수(project_auth_provider_stale_pattern).
final allFavoriteClipsProvider =
    FutureProvider<List<FavoriteClip>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(favoriteClipRepositoryProvider).listAll();
});

// ── 하이라이트 상세 (2026-09-04 재설계 T4) ─────────────────────────────────────

/// 하이라이트 묶음(최근 30일, 72시간 창 그룹핑 — [groupHighlights]).
/// 그룹·그룹 내 항목 모두 최신부터. 에러는 화면이 retry로 처리(삼키지 않음).
final highlightGroupsProvider =
    FutureProvider.autoDispose<List<HighlightGroup>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id)); // 계정 격리
  // ⚠️ limit 서버 상한 100 — 200을 넘기면 422(2026-09-04 실측, FastAPI le=100).
  final list = await ref.watch(highlightRepositoryProvider).list(
        since: DateTime.now().subtract(const Duration(days: 30)),
        limit: 100,
      );
  return groupHighlights(list.where((h) => h.clipId.isNotEmpty).toList());
});

/// 도착 배너 dismiss 저장소(Hive `app_settings`).
final highlightBannerStoreProvider = Provider<HighlightBannerStore>(
  (_) => const HiveHighlightBannerStore(),
);

/// 마지막으로 dismiss한 그룹 key(from ISO). null = dismiss 이력 없음.
/// 하이라이트 상세의 도착 배너가 watch — 최신 그룹 key와 같으면 숨긴다.
final highlightBannerDismissedProvider =
    NotifierProvider<HighlightBannerDismissedNotifier, String?>(
        HighlightBannerDismissedNotifier.new);

class HighlightBannerDismissedNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(highlightBannerStoreProvider).load();

  Future<void> dismiss(String groupKey) async {
    state = groupKey;
    await ref.read(highlightBannerStoreProvider).save(groupKey);
  }
}

/// 시간(정각) 묶음 — 그룹·그룹 내 클립 모두 최신부터(내림차순).
typedef CrecamHourGroup = ({DateTime hour, List<MotionClip> clips});

/// 카메라 탭 시간대별 클립 그룹 — (현재 라이브 카메라, 기간 설정 날짜) 기준.
/// 카메라가 없으면 빈 목록.
final crecamHourGroupsProvider =
    FutureProvider.autoDispose<List<CrecamHourGroup>>((ref) async {
  final cameras = await ref.watch(camerasProvider.future);
  if (cameras.isEmpty) return const [];
  final index =
      ref.watch(selectedCrecamCameraProvider).clamp(0, cameras.length - 1);
  final day = ref.watch(crecamDayProvider);
  final clips = await ref.watch(
    motionClipsProvider((cameraId: cameras[index].id, day: day)).future,
  );

  final byHour = <DateTime, List<MotionClip>>{};
  for (final clip in clips) {
    final t = clip.startedAt.toLocal();
    final hour = DateTime(t.year, t.month, t.day, t.hour);
    byHour.putIfAbsent(hour, () => <MotionClip>[]).add(clip);
  }
  final groups = byHour.entries
      .map<CrecamHourGroup>(
        (e) => (
          hour: e.key,
          clips: e.value..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
        ),
      )
      .toList()
    ..sort((a, b) => b.hour.compareTo(a.hour));
  return groups;
});
