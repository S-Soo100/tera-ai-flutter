import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/motion_clip.dart';
import 'my_cage_providers.dart';
import 'widgets/crecam_detail_top_bar.dart';

/// 세로 재생목록 플레이어 (Figma 668:743, 카메라 탭 재설계 T1).
///
/// 기존 [MotionClipPlayerScreen](가로 전체화면)과 별개다 — 카메라 탭 계열은
/// **세로 고정**(회전 설정을 건드리지 않는다), 흰 바닥 위 16:9 레터박스.
/// GoRouter extra로 재생목록(`List<String>` clip id 순서)을 받고, 없으면
/// (딥링크 등) 단일 클립만 재생한다.
///
/// 이전/다음: 비디오 영역 좌 1/3 탭=이전, 우 1/3=다음, 중앙 1/3=재생/일시정지.
/// 영상이 끝나면 자동으로 다음 클립(마지막이면 정지 상태 유지).
class ClipPlaylistPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlaylistPlayerScreen({
    super.key,
    required this.clipId,
    this.playlist,
  });

  final String clipId;
  final List<String>? playlist;

  /// 테스트용 — 페이지네이션 세그먼트 식별.
  static const paginationKey = Key('crecam_player_pagination');

  @override
  ConsumerState<ClipPlaylistPlayerScreen> createState() =>
      _ClipPlaylistPlayerScreenState();
}

class _ClipPlaylistPlayerScreenState
    extends ConsumerState<ClipPlaylistPlayerScreen> {
  late final List<String> _playlist;
  int _index = 0;

  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;
  bool _busy = false; // 저장/공유/즐겨찾기 진행 중
  bool _isPlaying = false;
  bool _autoAdvanced = false; // 클립당 자동 다음 1회 가드

  /// 컨트롤러 교체 경합 가드 — 빠르게 이전/다음을 누르면 늦게 끝난 옛
  /// initialize()가 새 컨트롤러를 덮어쓸 수 있다. 시퀀스가 다르면 버린다.
  int _loadSeq = 0;

  /// presign URL 캐시(클립별, 발급 시각 포함) — 같은 클립의 저장/공유/
  /// 즐겨찾기가 재발급 없이 쓴다. **TTL을 넘기면 버린다**(리뷰 2026-09-04):
  /// 서버 presign TTL은 1시간(backend-reply 2026-08-31 §presigned GET) —
  /// 만료 URL을 계속 쓰면 저장/공유가 재시도해도 영구 실패한다.
  final Map<String, ({String url, DateTime issuedAt})> _urlCache = {};

  /// 서버 TTL(1h)보다 여유 있게 짧은 로컬 만료.
  static const _urlTtl = Duration(minutes: 50);

  String get _currentClipId => _playlist[_index];

  @override
  void initState() {
    super.initState();
    final list = widget.playlist;
    if (list == null || list.isEmpty || !list.contains(widget.clipId)) {
      // extra 없음(딥링크) 또는 목록에 현재 클립이 없으면 단일 재생.
      _playlist = [widget.clipId];
    } else {
      _playlist = List.unmodifiable(list);
      _index = list.indexOf(widget.clipId);
    }
    _load();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<String> _presignedUrl(String clipId, {bool refresh = false}) async {
    final cached = _urlCache[clipId];
    final stale = cached == null ||
        DateTime.now().difference(cached.issuedAt) > _urlTtl;
    if (refresh || stale) {
      _urlCache.remove(clipId);
      // provider도 무효화해야 한다 — non-refresh stale 경로에서도 provider
      // 캐시(autoDispose지만 이 화면이 살아 있는 동안 유지)가 옛 URL을 준다.
      ref.invalidate(motionClipUrlProvider(clipId));
      final url = await ref.read(motionClipUrlProvider(clipId).future);
      _urlCache[clipId] = (url: url, issuedAt: DateTime.now());
      return url;
    }
    return cached.url;
  }

  Future<void> _load({bool isRetry = false}) async {
    final seq = ++_loadSeq;
    final clipId = _currentClipId;
    final old = _controller;
    old?.removeListener(_onTick);
    setState(() {
      _controller = null;
      _initialized = false;
      _error = null;
      _isPlaying = false;
    });
    await old?.dispose();

    VideoPlayerController? controller;
    try {
      // 즐겨찾기(로컬 파일) 우선 — 오프라인 재생 가능
      final localFile =
          ref.read(favoriteClipRepositoryProvider).getLocalFile(clipId);
      if (localFile != null) {
        controller = VideoPlayerController.file(localFile);
      } else {
        final url = await _presignedUrl(clipId, refresh: isRetry);
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await controller.initialize();
      if (!mounted || seq != _loadSeq) {
        // 화면 이탈/클립 전환 뒤 늦게 도착 — 반드시 dispose(네이티브 누수 방지)
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      controller.play();
      // 다음 클립 메타 선읽기 — 전환 직후 상단바 날짜가 비고 북마크 버튼이
      // 잠시 무력화되는 공백을 줄인다(리뷰 2026-09-04). keepAliveFor 유예
      // 캐시가 받아두고, 실패는 무시(전환 시 어차피 다시 읽는다).
      if (_index + 1 < _playlist.length) {
        unawaited(ref
            .read(motionClipProvider(_playlist[_index + 1]).future)
            .then<MotionClip?>((c) => c, onError: (_) => null));
      }
    } catch (e) {
      await controller?.dispose();
      if (!mounted || seq != _loadSeq) return;
      if (!isRetry) {
        await _load(isRetry: true);
        return;
      }
      setState(() => _error = e.toString());
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final v = controller.value;
    final playing = v.isPlaying;
    // 영상 끝 → 자동 다음 (마지막 클립이면 정지 상태 유지)
    if (!_autoAdvanced &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        !playing &&
        v.position >= v.duration) {
      _autoAdvanced = true;
      if (_index < _playlist.length - 1) {
        _go(1);
        return;
      }
    }
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _playlist.length) return;
    setState(() => _index = next);
    _autoAdvanced = false;
    _load();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  void _seekBy(Duration delta) {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    final v = controller.value;
    var pos = v.position + delta;
    if (pos < Duration.zero) pos = Duration.zero;
    if (pos > v.duration) pos = v.duration;
    controller.seekTo(pos);
  }

  /// 로컬 파일 있으면 그걸, 없으면 presigned URL을 확보해 저장/공유에 넘긴다.
  Future<({File? file, String? url})> _source(String clipId) async {
    final f = ref.read(favoriteClipRepositoryProvider).getLocalFile(clipId);
    if (f != null) return (file: f, url: null);
    final url = await _presignedUrl(clipId);
    return (file: null, url: url);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final clipId = _currentClipId; // 진행 중 클립 전환에도 대상 고정
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('clip_saving'.tr())));
    try {
      final src = await _source(clipId);
      await ref.read(videoExportServiceProvider).saveToGallery(
            clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
      messenger
          .showSnackBar(SnackBar(content: Text('clip_saved_to_gallery'.tr())));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final clipId = _currentClipId;
    try {
      final src = await _source(clipId);
      await ref.read(videoExportServiceProvider).share(
            clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
    } catch (_) {
      // 공유 취소/실패는 조용히 무시
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(MotionClip? clip) async {
    if (_busy) return;
    setState(() => _busy = true);
    final clipId = _currentClipId;
    final repo = ref.read(favoriteClipRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (repo.isFavorite(clipId)) {
        final cameraId = await repo.remove(clipId);
        if (!mounted) return;
        ref.invalidate(isFavoriteProvider(clipId));
        if (cameraId != null) ref.invalidate(favoriteClipsProvider(cameraId));
        // non-autoDispose 전역 목록 — 안 깨우면 북마크 상세·엔트리 카드가
        // 삭제된 항목을 계속 그린다(리뷰 2026-09-04).
        ref.invalidate(allFavoriteClipsProvider);
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_removed'.tr())));
      } else {
        if (clip == null) return; // 오프라인 등 메타 없음 → 추가 불가
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_saving'.tr())));
        final url = await _presignedUrl(clipId);
        await repo.add(clip, url);
        if (!mounted) return;
        ref.invalidate(isFavoriteProvider(clipId));
        ref.invalidate(favoriteClipsProvider(clip.cameraId));
        ref.invalidate(allFavoriteClipsProvider);
        messenger
            .showSnackBar(SnackBar(content: Text('clip_favorite_added'.tr())));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final currentId = _currentClipId;
    final clip = ref.watch(motionClipProvider(currentId)).valueOrNull;
    final isFav = ref.watch(isFavoriteProvider(currentId));
    // 온라인은 clip 메타, 오프라인 즐겨찾기는 로컬 메타에서 시각을 얻는다.
    final startedAt = clip?.startedAt ??
        ref
            .watch(favoriteClipRepositoryProvider)
            .getMeta(currentId)
            ?.startedAt;

    final showPagination = _playlist.length > 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(glass, startedAt),
            // Figma 668:743 수직 리듬: 상단바(4238) → 52 → 페이지네이션(4290,
            // h4) → 28 → 영상(4322). 페이지네이션이 숨겨져도 자리를 예약해
            // 영상 위치가 재생목록 유무에 흔들리지 않게 한다.
            const SizedBox(height: 52),
            SizedBox(
              height: 4,
              child: showPagination
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _pagination(glass),
                    )
                  : null,
            ),
            const SizedBox(height: 28),
            _videoArea(glass),
            // 시크 트랙 중심 = 영상끝 +32 (4546→4578). Slider 내부 높이 48의
            // 중심이 +24이므로 갭 8.
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SeekBar(controller: _initialized ? _controller : null),
            ),
            // 컨트롤 상단 = 트랙 +20 (4578→4598) — Slider 하반부 24가 이미
            // 그만큼을 차지하므로 추가 갭 없음.
            _controlRow(glass),
            const Spacer(),
            Center(child: _actionPill(glass, clip, isFav)),
            // Figma 프레임 하단(4984)에서 필 하단(4922)까지 62 — safe area
            // (~34) 위 28.
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _topBar(GlassPalette glass, DateTime? startedAt) {
    // 공용 상단바(마진 12·back 44) + 중앙 2줄(날짜/시각 — Figma 668:743,
    // 행간 19/17px 고정: 기본 행간이면 44를 넘친다. 시뮬 실측 리뷰 이력).
    return CrecamDetailTopBar(
      titleWidget: startedAt == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('yyyy. MM. dd').format(startedAt.toLocal()),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.32, // 16 × -2%
                    height: 19 / 16,
                    color: glass.textSecondary,
                  ),
                ),
                Text(
                  formatAmPmTime(startedAt.toLocal()),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.28, // 14 × -2%
                    height: 17 / 14,
                    color: glass.textTertiary,
                  ),
                ),
              ],
            ),
    );
  }


  Widget _pagination(GlassPalette glass) {
    // 10개 초과면 세그먼트가 실오라기가 된다 — 같은 자리(높이 4)에 연속
    // 진행 바로 위치를 말한다(리뷰 2026-09-04: 기존 "그냥 숨김"은 하루치
    // 재생목록이 쉽게 10개를 넘어 실사용 기본 경로가 무표시였다).
    if (_playlist.length > 10) {
      return ClipRRect(
        key: ClipPlaylistPlayerScreen.paginationKey,
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (_index + 1) / _playlist.length,
          minHeight: 4,
          backgroundColor: glass.outline,
          valueColor: AlwaysStoppedAnimation(glass.textPrimary),
        ),
      );
    }
    return Row(
      key: ClipPlaylistPlayerScreen.paginationKey,
      children: [
        for (var i = 0; i < _playlist.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                // 비활성 = #E1E3E4 (T2에서 outline 토큰으로 정착)
                color: i == _index ? glass.textPrimary : glass.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _videoArea(GlassPalette glass) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: _video(glass))),
          // 좌 1/3=이전 · 중앙 1/3=재생/일시정지 · 우 1/3=다음
          if (_initialized)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(-1),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(1),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _video(GlassPalette glass) {
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text('error_generic'.tr(),
              style: TextStyle(fontSize: 14, color: glass.textSecondary)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _load(isRetry: true),
            child: Text('retry'.tr()),
          ),
        ],
      );
    }
    if (!_initialized || _controller == null) {
      return const SkeletonLoading(
          width: double.infinity, height: double.infinity, borderRadius: 0);
    }
    final ar = _controller!.value.aspectRatio;
    return AspectRatio(
      aspectRatio: ar.isFinite && ar > 0 ? ar : 16 / 9,
      child: VideoPlayer(_controller!),
    );
  }

  Widget _controlRow(GlassPalette glass) {
    final color = glass.textPrimary;
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.24, // 12 × -2%
      color: color,
    );
    // 라벨은 한 줄 고정 + ellipsis — 번역이 길어져도 로우가 넘치지 않게.
    Widget seekButton(IconData icon, String label, VoidCallback onTap) {
      return Flexible(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              Text(label,
                  style: labelStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seekButton(Icons.fast_rewind, 'crecam_player_rew10'.tr(),
            () => _seekBy(const Duration(seconds: -10))),
        const SizedBox(width: 46),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
              size: 44, color: color),
        ),
        const SizedBox(width: 46),
        seekButton(Icons.fast_forward, 'crecam_player_ffw10'.tr(),
            () => _seekBy(const Duration(seconds: 10))),
      ],
    );
  }

  Widget _actionPill(GlassPalette glass, MotionClip? clip, bool isFav) {
    final color = glass.textPrimary;
    Widget action(IconData icon, String tooltip, VoidCallback? onTap) {
      return SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 24,
          icon: Icon(icon, color: onTap == null ? glass.textTertiary : color),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      );
    }

    return Container(
      width: 172,
      height: 48,
      decoration: BoxDecoration(
        color: glass.surfaceTint,
        borderRadius: BorderRadius.circular(24),
      ),
      // Figma 668:766 — 좌우 패딩 12, 아이콘 간 갭 20 (2187/2243/2299).
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          action(
            isFav ? Icons.bookmark : Icons.bookmark_border,
            'clip_favorite_add'.tr(),
            _busy ? null : () => _toggleFavorite(clip),
          ),
          const SizedBox(width: 20),
          action(Icons.ios_share, 'clip_share'.tr(), _busy ? null : _share),
          const SizedBox(width: 20),
          action(Icons.download_outlined, 'clip_save'.tr(),
              _busy ? null : _save),
        ],
      ),
    );
  }
}

/// 시크바 — 컨트롤러를 직접 listen해 position을 따라간다(VideoControls 패턴).
/// [controller]가 null이면(로딩/에러) 비활성 트랙만 그린다.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller});

  final VideoPlayerController? controller;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onUpdate);
      widget.controller?.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  double _value() {
    final v = widget.controller?.value;
    if (v == null) return 0;
    final dur = v.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (v.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: glass.textPrimary,
        // 연회색 트랙 — #E1E3E4 (T2에서 outline 토큰으로 정착)
        inactiveTrackColor: glass.outline,
        disabledActiveTrackColor: glass.outline,
        disabledInactiveTrackColor: glass.outline,
        thumbColor: glass.textPrimary,
      ),
      child: Slider(
        value: _value(),
        onChanged: widget.controller == null
            ? null
            : (val) {
                final ctrl = widget.controller!;
                final dur = ctrl.value.duration.inMilliseconds;
                if (dur > 0) {
                  ctrl.seekTo(Duration(milliseconds: (val * dur).round()));
                }
              },
      ),
    );
  }
}
