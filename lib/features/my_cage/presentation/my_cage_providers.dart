import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../data/camera_repository.dart';
import '../data/clip_repository.dart';
import '../data/video_cache_repository.dart';
import '../domain/behavior_inference.dart';
import '../domain/behavior_label.dart';
import '../domain/camera.dart';
import '../domain/clip.dart';
import '../domain/clip_media_url.dart';

// ── 내부 인프라 Provider ───────────────────────────────────────────────────────

/// SupabaseClient 싱글톤. auth_providers에 동일 Provider 없으므로 여기서 정의.
final _supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// JWT accessToken 공급자. 매 호출마다 currentSession을 읽어 최신 토큰 반환.
final _tokenProviderProvider = Provider<Future<String?> Function()>(
  (ref) => () async =>
      Supabase.instance.client.auth.currentSession?.accessToken,
);

// ── Repository Provider ────────────────────────────────────────────────────────

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  return CameraRepository(
    supabase: ref.watch(_supabaseClientProvider),
    backendUrl: EnvConfig.backendUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

final clipRepositoryProvider = Provider<ClipRepository>((ref) {
  return ClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
    backendUrl: EnvConfig.backendUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});

// ── 공개 FutureProvider ────────────────────────────────────────────────────────

/// 현재 유저의 카메라 전체 목록 (최신순).
final camerasProvider = FutureProvider<List<Camera>>((ref) async {
  return ref.watch(cameraRepositoryProvider).listAll();
});

/// 특정 펫에 연결된 카메라 목록.
final petCamerasProvider =
    FutureProvider.family<List<Camera>, String>((ref, petId) async {
  return ref.watch(cameraRepositoryProvider).listByPet(petId);
});

/// 단일 카메라 조회. 존재하지 않으면 null.
final cameraProvider =
    FutureProvider.family<Camera?, String>((ref, id) async {
  return ref.watch(cameraRepositoryProvider).getById(id);
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
  final start =
      DateTime(key.date.year, key.date.month, key.date.day, key.hour);
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
final clipFileUrlProvider =
    FutureProvider.autoDispose.family<ClipMediaUrl, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getFileUrl(clipId);
});

/// 클립 썸네일 presigned URL. ClipThumbnail이 watch.
final clipThumbnailUrlProvider =
    FutureProvider.autoDispose.family<ClipMediaUrl, String>((ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getThumbnailUrl(clipId);
});

/// 클립 human 라벨 목록. 빈 배열 정상, 에러는 silent fail (섹션 숨김).
final clipLabelsProvider =
    FutureProvider.autoDispose.family<List<BehaviorLabel>, String>(
        (ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getLabels(clipId);
});

/// 클립 VLM 추론 1건 또는 null. 추론 없으면 null, 에러는 silent fail.
final clipInferenceProvider =
    FutureProvider.autoDispose.family<BehaviorInference?, String>(
        (ref, clipId) async {
  return ref.watch(clipRepositoryProvider).getInference(clipId);
});

// ── 캐시 Repository Provider ───────────────────────────────────────────────────

/// 영상 로컬 캐시 Repository. VideoCacheRepository.init()은 main()에서 선 실행.
final videoCacheRepositoryProvider = Provider<VideoCacheRepository>((ref) {
  return VideoCacheRepository();
});
