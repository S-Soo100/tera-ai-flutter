import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/camera_repository.dart';
import '../data/enclosure_repository.dart';
import '../data/clip_repository.dart';
import '../data/favorite_clip_repository.dart';
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

/// 카메라별 가장 최근 클립 1건 (크레캠 그리드 썸네일 포스터용). 없으면 null.
final latestClipProvider =
    FutureProvider.autoDispose.family<Clip?, String>((ref, cameraId) async {
  final page = await ref
      .watch(clipRepositoryProvider)
      .listPage(cameraId: cameraId, limit: 1);
  return page.items.isEmpty ? null : page.items.first;
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

/// 카메라의 모션 클립 목록 (최신 50개). day 지정 시 그 날만.
final motionClipsProvider = FutureProvider.autoDispose
    .family<List<MotionClip>, MotionClipsKey>((ref, key) async {
  return ref
      .watch(motionClipRepositoryProvider)
      .listByCamera(key.cameraId, day: key.day);
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
