import '../domain/highlight_publication.dart';
import 'highlight_read_providers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import 'player_view_providers.dart';
import '../domain/clip_playlist_args.dart';
import '../domain/motion_clip_page.dart';
export '../domain/clip_playlist_args.dart';
import 'widgets/clip_filmstrip.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip_playback.dart';
import '../domain/motion_clip.dart';
import '../domain/player_speed.dart';
import 'my_cage_providers.dart';
import 'bookmark_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'widgets/clip_memo_editor.dart';
import 'widgets/clip_toast.dart';
import 'clip_memo_providers.dart';
import 'clip_visibility_providers.dart';
import 'widgets/clip_hide_dialog.dart';

/// 세로 재생목록 플레이어 (Figma 668:743, 카메라 탭 재설계 T1).
///
/// 카메라 탭 계열은 세로로 진입하고 전용 버튼으로 가로/세로를 전환한다.
/// 회전 중 같은 VideoPlayerController와 재생 위치를 유지한다.
/// GoRouter extra로 재생목록(`List<String>` clip id 순서)을 받고, 없으면
/// (딥링크 등) 단일 클립만 재생한다.
///
/// 이전/다음은 스와이프·화살표·중앙 필름스트립, 단일 탭은 조작계 표시,
/// 양쪽 더블탭은 ±10초.
/// 하이라이트만 끝에서 자동으로 다음 클립(마지막이면 정지 상태 유지).
/// 더블탭 ±10초 피드백(초 단위 부호 값). 화면 인스턴스별.
final _seekFeedbackProvider =
    StateProvider.autoDispose.family<int?, Object>((ref, key) => null);

class ClipPlaylistPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlaylistPlayerScreen({
    super.key,
    required this.clipId,
    this.playlist,
    this.playFromSec = const {},
    this.source = ClipPlaybackSource.single,
    this.cameraId,
    this.rangeStart,
    this.rangeEndExclusive,
    this.nextCursor,
    this.hasMore = false,
    this.highlightBatchId,
  });

  final String clipId;
  final ClipPlaybackSource source;
  final String? cameraId, highlightBatchId;
  final DateTime? rangeStart, rangeEndExclusive;
  final MotionClipCursor? nextCursor;
  final bool hasMore;
  final List<String>? playlist;

  /// clip id → 재생 시작점(초). [ClipPlaylistArgs.playFromSec].
  final Map<String, double> playFromSec;

  /// 테스트용 — 페이지네이션 세그먼트 식별.
  static const paginationKey = Key('crecam_player_pagination');

  /// 테스트용 — 이전/다음 화살표와 위치 카운터를 검증한다.
  static const prevArrowKey = Key('crecam_player_prev_arrow');
  static const nextArrowKey = Key('crecam_player_next_arrow');
  static const navigationActionsKey = Key('crecam_player_navigation_actions');
  static const actionPillKey = Key('crecam_player_action_pill');
  static const counterKey = Key('crecam_player_counter');

  /// 테스트용 — "처음부터" 컨트롤(중간 시작 클립에서만 노출).
  static const fromStartKey = Key('crecam_player_from_start');

  @override
  ConsumerState<ClipPlaylistPlayerScreen> createState() =>
      _ClipPlaylistPlayerScreenState();
}

class _ClipPlaylistPlayerScreenState
    extends ConsumerState<ClipPlaylistPlayerScreen> {
  final _orientationKey = Object();
  HighlightPlaybackTracker _readTracker = HighlightPlaybackTracker();
  String? _readOwner;
  int _seekOperations = 0;
  late final PlayerPlaylistSeed _playlistSeed;
  late final PlayerFilmstripSeed _filmstripSeed;
  late final ScrollController _filmstripController;
  bool _filmstripProgrammatic = false;
  List<String> get _playlist => ref.read(playerPlaylistProvider(_playlistSeed));
  set _playlist(List<String> value) =>
      ref.read(playerPlaylistProvider(_playlistSeed).notifier).state = value;
  int get _index => ref.read(playerIndexProvider(_playlistSeed));
  set _index(int value) =>
      ref.read(playerIndexProvider(_playlistSeed).notifier).state = value;

  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;
  bool _busy = false; // 저장/공유/즐겨찾기 진행 중
  bool _downloading = false; // 기기 저장 진행 중 — 흰 dim + 스피너(1106:3659)
  bool _isPlaying = false;
  bool _autoAdvanced = false; // 클립당 자동 다음 1회 가드
  MotionClipCursor? _nextCursor;
  late bool _hasMore;

  static const _prefetchThreshold = 12;

  /// 현재 클립이 서버 시작점(`play_from_sec`)으로 중간에서 시작했는지 —
  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null) return;
    _seekOperations++;
    try {
      await controller.seekTo(position);
    } finally {
      if (mounted && identical(controller, _controller)) {
        _readTracker.resetPosition(controller.value.position);
      }
      _seekOperations--;
    }
  }

  /// "처음부터" 컨트롤 노출 조건. seek은 클립 로드당 1회만이고, 사용자가
  /// 타임라인을 옮겨도 다시 당기지 않는다.
  bool _startedMidway = false;

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
    _readOwner = ref.read(currentUserProvider)?.id;
    final list = widget.playlist;
    final ids = list == null || list.isEmpty || !list.contains(widget.clipId)
        ? <String>[widget.clipId]
        : List<String>.unmodifiable(list);
    _playlistSeed =
        (route: _orientationKey, ids: ids, index: ids.indexOf(widget.clipId));
    final initialIndex = ids.indexOf(widget.clipId);
    _nextCursor = widget.nextCursor;
    _hasMore = widget.hasMore;
    _filmstripSeed = (route: _orientationKey, initialIndex: initialIndex);
    _filmstripController = ScrollController(
      initialScrollOffset: ClipFilmstrip.offsetForIndex(initialIndex),
    );
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMoreIfNearEnd(initialIndex);
    });
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _filmstripController.dispose();
    super.dispose();
  }

  void _loadMoreIfNearEnd(int index) {
    if (_hasMore && _playlist.length - index <= _prefetchThreshold) {
      unawaited(_loadMoreFeedPlaylist());
    }
  }

  /// 사진 앱처럼 필름스트립 끝에 가까워졌을 때 다음 페이지를 붙인다.
  /// 기간 미선택은 전체 기간, 기간 선택은 그 범위 전체다.
  Future<void> _loadMoreFeedPlaylist() async {
    final owner = ref.read(currentUserProvider)?.id;
    final cameraId = widget.cameraId;
    if (widget.source != ClipPlaybackSource.feed ||
        owner == null ||
        cameraId == null ||
        !_hasMore ||
        _nextCursor == null) {
      return;
    }
    if (ref.read(playerPlaylistLoadingProvider(_orientationKey))) return;
    ref.read(playerPlaylistLoadingProvider(_orientationKey).notifier).state =
        true;
    ref.read(playerPlaylistErrorProvider(_orientationKey).notifier).state =
        false;
    try {
      final query = (
        ownerId: owner,
        cameraId: cameraId,
        range: widget.rangeStart != null && widget.rangeEndExclusive != null
            ? (
                start: widget.rangeStart!,
                endExclusive: widget.rangeEndExclusive!
              )
            : null
      );
      final page = await ref.read(playerFeedPageLoaderProvider(query))(
        _nextCursor,
      );
      if (!mounted || ref.read(currentUserProvider)?.id != owner) return;
      final current = _playlist.isEmpty ? null : _currentClipId;
      final hidden = ref.read(currentClipVisibilityProvider).hiddenIds;
      final expanded = {
        ..._playlist,
        ...page.items.map((clip) => clip.id),
      }.where((id) => !hidden.contains(id)).toList(growable: false);
      _playlist = expanded;
      _index = current == null ? 0 : math.max(0, expanded.indexOf(current));
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _setFilmstripPreview(_index);
      _centerFilmstrip(_index, animate: false);
      if (current == null && expanded.isNotEmpty) unawaited(_load());
    } catch (_) {
      if (mounted) {
        ref.read(playerPlaylistErrorProvider(_orientationKey).notifier).state =
            true;
      }
    } finally {
      if (mounted) {
        ref
            .read(playerPlaylistLoadingProvider(_orientationKey).notifier)
            .state = false;
      }
    }
  }

  Future<String> _presignedUrl(String clipId, {bool refresh = false}) async {
    final cached = _urlCache[clipId];
    final stale =
        cached == null || DateTime.now().difference(cached.issuedAt) > _urlTtl;
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
    _readTracker = HighlightPlaybackTracker();
    final clipId = _currentClipId;
    final old = _controller;
    old?.removeListener(_onTick);
    setState(() {
      _controller = null;
      _initialized = false;
      _error = null;
      _isPlaying = false;
      _startedMidway = false;
    });
    await old?.dispose();

    VideoPlayerController? controller;
    try {
      final owner = ref.read(clipVisibilityAccountProvider);
      if (owner != null) {
        final visibility = ref.read(clipVisibilityProvider(owner).notifier);
        await visibility.ready();
        if (!mounted ||
            seq != _loadSeq ||
            ref.read(clipVisibilityAccountProvider) != owner) {
          return;
        }
        if (visibility.hiddenIds.contains(clipId)) {
          _applyHiddenClips(visibility.hiddenIds);
          return;
        }
      }
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
      // 서버 시작점(하이라이트 play_from_sec)으로 첫 재생 전에 1회 seek —
      // setState(스켈레톤 해제) 전에 당겨 0초 프레임이 튀지 않게 한다.
      final startAt = initialClipSeek(
          widget.playFromSec[clipId], controller.value.duration);
      if (startAt != null) {
        await controller.seekTo(startAt);
        if (!mounted || seq != _loadSeq) {
          await controller.dispose();
          return;
        }
      }
      _readTracker.resetPosition(controller.value.position);
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _initialized = true;
        _startedMidway = startAt != null;
      });
      await controller
          .setPlaybackSpeed(ref.read(playerSpeedProvider(_orientationKey)));
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
    final owner = _readOwner;
    final camera = widget.cameraId;
    final batch = widget.highlightBatchId;
    if (widget.source == ClipPlaybackSource.highlight &&
        owner != null &&
        camera != null &&
        batch != null &&
        ref.read(currentUserProvider)?.id == owner &&
        _readTracker.observe(
            position: v.position,
            playing: playing,
            buffering: v.isBuffering,
            seeking: _seekOperations > 0)) {
      unawaited(ref
          .read(highlightReadProvider(
              (ownerId: owner, cameraId: camera, batchId: batch)).notifier)
          .markRead()
          .catchError((Object _) {}));
    }
    // 영상 끝 → 자동 다음 (마지막 클립이면 정지 상태 유지)
    if (widget.source == ClipPlaybackSource.highlight &&
        !_autoAdvanced &&
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
    _selectClip(next);
  }

  void _selectClip(int next, {bool centerFilmstrip = true}) {
    if (next < 0 || next >= _playlist.length) return;
    _setFilmstripPreview(next);
    _loadMoreIfNearEnd(next);
    if (centerFilmstrip) _centerFilmstrip(next);
    if (next == _index) return;
    _index = next;
    _autoAdvanced = false;
    _load();
  }

  void _setFilmstripPreview(int index) {
    final provider = playerFilmstripPreviewIndexProvider(_filmstripSeed);
    if (ref.read(provider) == index) return;
    ref.read(provider.notifier).state = index;
  }

  Future<void> _centerFilmstrip(int index, {bool animate = true}) async {
    if (!_filmstripController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_centerFilmstrip(index, animate: animate));
      });
      return;
    }
    final target = ClipFilmstrip.offsetForIndex(index)
        .clamp(0.0, _filmstripController.position.maxScrollExtent);
    _filmstripProgrammatic = true;
    try {
      if (animate) {
        await _filmstripController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _filmstripController.jumpTo(target);
      }
    } finally {
      _filmstripProgrammatic = false;
    }
  }

  void _previewFilmstrip(int index) {
    if (_filmstripProgrammatic) return;
    _setFilmstripPreview(index);
    _loadMoreIfNearEnd(index);
  }

  Future<void> _settleFilmstrip(int index) async {
    if (_filmstripProgrammatic) return;
    await _centerFilmstrip(index);
    if (!mounted) return;
    _selectClip(index, centerFilmstrip: false);
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  Timer? _seekFeedbackTimer;

  void _seekBy(Duration delta) {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    final v = controller.value;
    var pos = v.position + delta;
    if (pos < Duration.zero) pos = Duration.zero;
    if (pos > v.duration) pos = v.duration;
    unawaited(_seekTo(pos));
    // Figma 941:1928 Toast_V — 탭한 쪽에 ±10s 칩을 잠깐 띄운다.
    ref.read(_seekFeedbackProvider(_orientationKey).notifier).state =
        delta.inSeconds;
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        ref.read(_seekFeedbackProvider(_orientationKey).notifier).state = null;
      }
    });
  }

  /// "처음부터" — 서버 시작점으로 중간에서 시작한 클립을 0초부터 다시 본다.
  void _restartFromZero() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    unawaited(_seekTo(Duration.zero));
    controller.play();
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
    setState(() {
      _busy = true;
      _downloading = true;
    });
    final clipId = _currentClipId; // 진행 중 클립 전환에도 대상 고정
    final messenger = ScaffoldMessenger.of(context);
    try {
      final src = await _source(clipId);
      await ref.read(videoExportServiceProvider).saveToGallery(
            clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
      if (!mounted) return;
      setState(() => _downloading = false);
      // Figma 1106:3584 — 완료만 토스트. 실패는 아래 별도 스낵바(완료 오인 금지).
      showClipToast(context, text: 'clip_download_done'.tr());
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloading = false;
        });
      }
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

  void _toggleFavorite(MotionClip? clip) {
    toggleClipBookmark(context, ref, _currentClipId, canAdd: clip != null);
  }

  void _editMemo() {
    final owner = ref.read(clipMemoAccountProvider);
    if (owner == null) return;
    showClipMemoEditor(context, key: (ownerId: owner, clipId: _currentClipId));
  }

  void _hideCurrentClip() {
    final owner = ref.read(clipVisibilityAccountProvider);
    if (owner == null || _playlist.isEmpty) return;
    showClipHideDialog(context, ownerId: owner, clipId: _currentClipId);
  }

  void _applyHiddenClips(Set<String> hiddenIds) {
    if (!mounted || _playlist.isEmpty) return;
    final current = _currentClipId;
    final oldIndex = _index;
    final visible = _playlist
        .where((id) => !hiddenIds.contains(id))
        .toList(growable: false);
    if (visible.length == _playlist.length) return;
    _urlCache.removeWhere((id, _) => hiddenIds.contains(id));
    _playlist = visible;
    _index = visible.contains(current)
        ? visible.indexOf(current)
        : math.min(oldIndex, math.max(0, visible.length - 1));
    if (visible.isEmpty) {
      _loadSeq++;
      final controller = _controller;
      controller?.removeListener(_onTick);
      _controller = null;
      _initialized = false;
      _isPlaying = false;
      unawaited(controller?.dispose());
      if (_hasMore) unawaited(_loadMoreFeedPlaylist());
      return;
    }
    _setFilmstripPreview(_index);
    _centerFilmstrip(_index, animate: false);
    _loadMoreIfNearEnd(_index);
    if (current != _currentClipId) {
      _autoAdvanced = false;
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    ref.watch(playerPlaylistProvider(_playlistSeed));
    ref.watch(playerIndexProvider(_playlistSeed));
    final visibility = ref.watch(currentClipVisibilityProvider);
    ref.listen(currentClipVisibilityProvider.select((value) => value.hiddenIds),
        (_, hidden) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _applyHiddenClips(hidden));
    });
    ref.listen(clipVisibilityAccountProvider, (previous, next) {
      if (previous != null && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyHiddenClips(_playlist.toSet());
        });
      }
    });
    if (visibility.loading) {
      return const Scaffold(
          body: Center(
              child: SkeletonLoading(width: double.infinity, height: 224)));
    }
    if (_playlist.isEmpty) {
      return Scaffold(
          body: SafeArea(
              child: Column(children: [
        CrecamDetailTopBar(closeButton: true),
        Expanded(
            child: Center(
                child: ref.watch(playerPlaylistLoadingProvider(_orientationKey))
                    ? const SkeletonLoading(width: double.infinity, height: 224)
                    : Text('clip_hide_empty'.tr()))),
      ])));
    }
    if (visibility.hiddenIds.contains(_currentClipId)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _applyHiddenClips(visibility.hiddenIds));
      return const Scaffold(body: SizedBox.shrink());
    }
    final controlsVisible =
        ref.watch(playerControlsVisibleProvider(_orientationKey));
    final currentId = _currentClipId;
    final clip = ref.watch(motionClipProvider(currentId)).valueOrNull;
    final owner = ref.watch(currentUserProvider)?.id;
    final bookmark = owner == null
        ? null
        : ref.watch(
            bookmarkControllerProvider((ownerId: owner, clipId: currentId)));
    final isFav =
        bookmark?.desired ?? ref.watch(isFavoriteProvider(currentId)) ?? false;
    // 온라인은 clip 메타, 오프라인 즐겨찾기는 로컬 메타에서 시각을 얻는다.
    final startedAt = clip?.startedAt ??
        ref.watch(favoriteClipMetaProvider(currentId))?.startedAt;

    final landscape = ref.watch(playerOrientationProvider(_orientationKey));
    if (landscape) {
      // Figma 941:1928 / 1081:6895 — 영상 위 overlay chrome. 여백 좌우 48·
      // 상 24·하 20은 SafeArea 최소값(노치 기기는 더 큰 쪽을 쓴다).
      return Scaffold(
          backgroundColor: glass.wallpaper,
          body: Stack(fit: StackFit.expand, children: [
            _videoArea(glass, BoxConstraints.tight(MediaQuery.sizeOf(context)),
                fill: true),
            if (controlsVisible) ...[
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 156,
                  child: IgnorePointer(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                        glass.wallpaper.withValues(alpha: 0),
                        glass.wallpaper.withValues(alpha: 0.9),
                      ]))))),
              SafeArea(
                  minimum: const EdgeInsets.fromLTRB(48, 24, 48, 20),
                  child: Stack(children: [
                    Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Center(child: _datePill(glass, startedAt))),
                    Positioned(
                        left: 0,
                        top: 0,
                        child: _circleButton(
                            key: const Key('player_landscape_close'),
                            asset: FigmaIcons.close,
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onTap: () => context.pop())),
                    Positioned(
                        right: 0,
                        top: 0,
                        child: _landscapeActions(glass, clip, isFav)),
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                  height: 16,
                                  child: _SeekBar(
                                      controller:
                                          _initialized ? _controller : null,
                                      onSeek: _seekTo)),
                              const SizedBox(height: 4),
                              _controlRow(glass, padded: false),
                              const SizedBox(height: 4),
                              if (_playlist.length > 1)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: LayoutBuilder(
                                        builder: (context, c) => SizedBox(
                                            width: math.min(510, c.maxWidth),
                                            child: _thumbnailStrip()))),
                              if (ref.watch(
                                  playerPlaylistErrorProvider(_orientationKey)))
                                _playlistRetry(),
                            ])),
                  ])),
            ],
            if (_downloading) const _DownloadOverlay(),
          ]));
    }
    return Scaffold(
        body: Stack(fit: StackFit.expand, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CrecamDetailHeaderArea(child: _topBar(glass, startedAt)),
        Expanded(
            child: SafeArea(
                top: false,
                child: LayoutBuilder(
                    builder: (context, outer) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                                height: math.min(84, outer.maxHeight * 0.13)),
                            _videoArea(glass, outer),
                            SizedBox(
                                height: 16,
                                child: _SeekBar(
                                    onSeek: _seekTo,
                                    controller:
                                        _initialized ? _controller : null)),
                            Visibility(
                                visible: controlsVisible,
                                maintainSize: true,
                                maintainState: true,
                                maintainAnimation: true,
                                child: _controlRow(glass)),
                            const Spacer(),
                            _navigationActions(glass, clip, isFav),
                            if (_playlist.length > 1) ...[
                              const SizedBox(height: 12),
                              _thumbnailStrip()
                            ],
                            if (ref.watch(
                                playerPlaylistErrorProvider(_orientationKey)))
                              _playlistRetry(),
                            // Figma 941:1834 — 스트립 하단 y764, 홈 인디케이터 위 54
                            // (본문 712 기준 7.6%). 작은 화면(320×568)은 비율로
                            // 줄여 11px overflow를 막는다(회귀 2026-09-16).
                            SizedBox(
                                height: math.min(54, outer.maxHeight * 0.076)),
                          ],
                        )))),
      ]),
      if (_downloading) const _DownloadOverlay(),
    ]));
  }

  Widget _navigationActions(GlassPalette glass, MotionClip? clip, bool isFav,
      {bool showArrows = true}) {
    final hasNavigation = showArrows && _playlist.length > 1;
    // Use this row's actual constraints: split views and rotation can narrow
    // its layout independently of the enclosing MediaQuery viewport.
    return LayoutBuilder(builder: (context, constraints) {
      final arrowGap = ((constraints.maxWidth - 312) / 2).clamp(0.0, 24.0);
      return Align(
        alignment: Alignment.center,
        child: Row(
            key: ClipPlaylistPlayerScreen.navigationActionsKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasNavigation) ...[
                if (_index > 0)
                  _navArrow(
                    key: ClipPlaylistPlayerScreen.prevArrowKey,
                    asset: FigmaIcons.arrowPrevious,
                    tooltip:
                        MaterialLocalizations.of(context).previousPageTooltip,
                    onTap: () => _go(-1),
                  )
                else
                  const SizedBox.square(dimension: 48),
                SizedBox(width: arrowGap),
              ],
              Column(mainAxisSize: MainAxisSize.min, children: [
                _actionPill(glass, clip, isFav),
                if (ref.watch(currentUserProvider)?.id case final owner?)
                  if (ref
                          .watch(bookmarkControllerProvider(
                              (ownerId: owner, clipId: _currentClipId)))
                          .error !=
                      null)
                    TextButton(
                        onPressed: () => ref
                            .read(bookmarkControllerProvider(
                                    (ownerId: owner, clipId: _currentClipId))
                                .notifier)
                            .retry(),
                        child: Text('retry'.tr())),
              ]),
              if (hasNavigation) ...[
                SizedBox(width: arrowGap),
                if (_index < _playlist.length - 1)
                  _navArrow(
                    key: ClipPlaylistPlayerScreen.nextArrowKey,
                    asset: FigmaIcons.arrowNext,
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                    onTap: () => _go(1),
                  )
                else
                  const SizedBox.square(dimension: 48),
              ],
            ]),
      );
    });
  }

  Widget _navArrow({
    required Key key,
    required String asset,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: SizedBox.square(
          key: key,
          dimension: 48,
          child: Material(
            color: context.glass.surfaceTint,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: FigmaIcon.tinted(
                  asset,
                  size: 24,
                  color: context.glass.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _playlistRetry() => TextButton(
      onPressed: _loadMoreFeedPlaylist,
      child: Text('crecam_playlist_retry'.tr()));

  Widget _thumbnailStrip() => Semantics(
        key: ClipPlaylistPlayerScreen.counterKey,
        label:
            '${_index + 1} / ${_playlist.length}${(_hasMore || ref.watch(playerPlaylistLoadingProvider(_orientationKey)) || ref.watch(playerPlaylistErrorProvider(_orientationKey))) ? '+' : ''}',
        child: ClipFilmstrip(
          listKey: ClipPlaylistPlayerScreen.paginationKey,
          controller: _filmstripController,
          clipIds: _playlist,
          cameraId: widget.cameraId ?? '',
          previewIndex:
              ref.watch(playerFilmstripPreviewIndexProvider(_filmstripSeed)),
          onPreviewChanged: _previewFilmstrip,
          onSettled: (index) => unawaited(_settleFilmstrip(index)),
          onSelected: _selectClip,
        ),
      );

  Widget _topBar(GlassPalette glass, DateTime? startedAt) {
    // 공용 상단바(마진 12·back 44) + 중앙 2줄(날짜/시각 — Figma 668:743,
    // 행간 19/17px 고정: 기본 행간이면 44를 넘친다. 시뮬 실측 리뷰 이력).
    //
    // 접근성(2026-09-07 A8): 시스템 글자 확대에서 2줄이 44pt 바를 넘치므로
    // 이 바만 스케일을 1.2로 클램프한다(19×1.2 + 17×1.2 = 43.2 < 44).
    // 날짜·시각은 본문이 아니라 크롬이라 클램프가 관례에 맞다.
    return CrecamDetailTopBar(
      closeButton: true,
      trailing: SizedBox.square(
          dimension: 44,
          child: IconButton(
              key: const Key('clip_hide_button'),
              padding: EdgeInsets.zero,
              tooltip: 'clip_hide_action'.tr(),
              onPressed: _hideCurrentClip,
              // 44 프레임 export(글리프 17×19 가운데) — 예약 목록과 같은 파일이라
              // 같은 44로 그린다. 24로 그리면 글리프가 11pt로 쪼그라든다.
              icon: FigmaIcon.tinted(FigmaIcons.trash,
                  size: 44, color: glass.textPrimary))),
      titleWidget: startedAt == null
          ? null
          : MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('yyyy. MM. dd').format(startedAt.toLocal()),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      // Figma 668:764 — Bold + #1E1E1E (2026-09-07 재대조).
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.32, // 16 × -2%
                      height: 19 / 16,
                      color: glass.textPrimary,
                    ),
                  ),
                  Text(
                    formatAmPmTime(startedAt.toLocal()),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      // Figma 668:765 — SemiBold + #545454(배너 날짜와 동일).
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.28, // 14 × -2%
                      height: 17 / 14,
                      color: glass.mediaMeta,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _videoArea(GlassPalette glass, BoxConstraints outer,
      {bool fill = false}) {
    final ar = _initialized ? _controller?.value.aspectRatio ?? 16 / 9 : 16 / 9;
    final ratio = ar.isFinite && ar > 0 ? ar : 16 / 9;
    final height = fill
        ? outer.maxHeight
        : math.min(
            outer.maxWidth / ratio, math.max(80.0, outer.maxHeight - 260));
    return SizedBox(
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 150) _go(velocity < 0 ? 1 : -1);
          },
          child: Stack(fit: StackFit.expand, children: [
            _video(glass),
            if (_initialized)
              Row(children: [
                Expanded(
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final provider =
                              playerControlsVisibleProvider(_orientationKey);
                          ref.read(provider.notifier).state =
                              !ref.read(provider);
                        },
                        onDoubleTap: () =>
                            _seekBy(const Duration(seconds: -10)))),
                Expanded(
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final provider =
                              playerControlsVisibleProvider(_orientationKey);
                          ref.read(provider.notifier).state =
                              !ref.read(provider);
                        },
                        onDoubleTap: () =>
                            _seekBy(const Duration(seconds: 10)))),
              ]),
            if (ref.watch(_seekFeedbackProvider(_orientationKey))
                case final seconds?)
              IgnorePointer(
                  child: Align(
                      alignment: Alignment(seconds < 0 ? -0.5 : 0.5, 0),
                      child: _SeekFeedbackChip(seconds: seconds))),
          ]),
        ));
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
    // cover — 박스 세로가 잘렸을 때(세로 영상이 maxH에 걸림) 가로를 유지한
    // 채 상하만 크롭. 박스 비율 = 영상 비율이면 크롭 없이 정확히 맞는다.
    final size = _controller!.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(_controller!);
    }
    return FittedBox(
      fit: BoxFit.contain,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  /// Figma 941:1834 Frame 144 — 높이 36, 재생 36 + 8 + 시각 14/500,
  /// 우측 2X 36 + 12 + 확대 36. 세로는 좌우 12 안쪽, 가로는 SafeArea 여백 그대로.
  Widget _controlRow(GlassPalette glass, {bool padded = true}) {
    final speed = ref.watch(playerSpeedProvider(_orientationKey));
    final landscape = ref.watch(playerOrientationProvider(_orientationKey));
    final controller = _controller;
    String time(Duration value) =>
        '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: padded ? 12 : 0),
        child: SizedBox(
            height: 36,
            child: Row(children: [
              _iconButton36(
                  key: const Key('player_play_pause'),
                  onTap: _togglePlay,
                  child: FigmaIcon.tinted(
                      _isPlaying ? FigmaIcons.pause : FigmaIcons.play,
                      size: 36,
                      color: glass.textPrimary)),
              const SizedBox(width: 8),
              if (controller != null)
                ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, _) => Text(
                        '${time(value.position)} / ${time(value.duration)}',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            height: 16.70703125 / 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.28,
                            color: glass.textSecondary))),
              if (_startedMidway)
                Flexible(
                    child: TextButton(
                        key: ClipPlaylistPlayerScreen.fromStartKey,
                        onPressed: _restartFromZero,
                        child: Text('crecam_player_from_start'.tr(),
                            maxLines: 1, overflow: TextOverflow.ellipsis))),
              const Spacer(),
              _iconButton36(
                  key: const Key('player_speed'),
                  // 1X → 1.2X → 1.5X → 2X → 1X (Figma 아이콘 시트, 2026-09-21).
                  onTap: () {
                    final next = nextPlayerSpeed(speed);
                    ref
                        .read(playerSpeedProvider(_orientationKey).notifier)
                        .state = next;
                    _controller?.setPlaybackSpeed(next);
                  },
                  child: FigmaIcon.tinted(FigmaIcons.speed(speed),
                      color: glass.textPrimary, size: 36)),
              const SizedBox(width: 12),
              _iconButton36(
                  key: const Key('player_orientation'),
                  tooltip:
                      (landscape ? 'player_portrait' : 'player_landscape').tr(),
                  onTap: () => ref
                      .read(playerOrientationProvider(_orientationKey).notifier)
                      .toggle(),
                  // 세로=zoom_out_map(expand), 가로=zoom_in_map(축소) —
                  // 둘 다 Figma 36 export(941:1834/1928).
                  child: FigmaIcon.tinted(
                      landscape ? FigmaIcons.zoomInMap : FigmaIcons.expand,
                      color: glass.textPrimary,
                      size: 36)),
            ])));
  }

  Widget _iconButton36(
      {required Key key,
      required VoidCallback onTap,
      required Widget child,
      String? tooltip}) {
    final button = SizedBox.square(
        key: key,
        dimension: 36,
        child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child)));
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// 가로 상단 가운데 날짜 알약 (Figma 941:1928 Frame 145 — 130×48 r24).
  Widget _datePill(GlassPalette glass, DateTime? startedAt) {
    if (startedAt == null) return const SizedBox.shrink();
    return Container(
        key: const Key('player_landscape_date'),
        width: 130,
        height: 48,
        decoration: BoxDecoration(
            color: glass.surfaceTint, borderRadius: BorderRadius.circular(24)),
        child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(DateFormat('yyyy. MM. dd').format(startedAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.32,
                      height: 19 / 16,
                      color: glass.textPrimary)),
              const SizedBox(height: 2),
              Text(formatAmPmTime(startedAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.28,
                      height: 17 / 14,
                      color: glass.mediaMeta)),
            ])));
  }

  /// 가로 44 원형 버튼 (Figma Button/Enabled — #F4F4F4 r22, 그림 24).
  Widget _circleButton(
          {required Key key,
          required String asset,
          required String tooltip,
          required VoidCallback onTap}) =>
      Tooltip(
          message: tooltip,
          child: SizedBox.square(
              key: key,
              dimension: 44,
              child: Material(
                  color: context.glass.surfaceTint,
                  shape: const CircleBorder(),
                  child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onTap,
                      child: Center(
                          child: FigmaIcon.tinted(asset,
                              size: 24,
                              color: context.glass.textSecondary))))));

  /// 가로 우상단 알약 (Figma Frame 135 — 276×48 r24): 삭제 44 + 12 +
  /// 다운로드·공유·메모·북마크 44 동작면(간격 8).
  Widget _landscapeActions(GlassPalette glass, MotionClip? clip, bool isFav) {
    return Container(
        key: ClipPlaylistPlayerScreen.actionPillKey,
        width: 276,
        height: 48,
        decoration: BoxDecoration(
            color: glass.surfaceTint, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          const SizedBox(width: 12),
          SizedBox.square(
              dimension: 44,
              child: IconButton(
                  key: const Key('clip_hide_button'),
                  padding: EdgeInsets.zero,
                  tooltip: 'clip_hide_action'.tr(),
                  onPressed: _hideCurrentClip,
                  icon: FigmaIcon.tinted(FigmaIcons.trash,
                      size: 44, color: glass.textPrimary))),
          const SizedBox(width: 12),
          ..._actionButtons(glass, clip, isFav),
        ]));
  }

  /// 다운로드 → 공유 → 메모 → 북마크 (Figma 941:1834 순서), 44 동작면·간격 8.
  List<Widget> _actionButtons(
      GlassPalette glass, MotionClip? clip, bool isFav) {
    final color = glass.textPrimary;
    // [frame]은 그 아이콘의 export 프레임이다. 프레임에 디자인이 정한 여백이
    // 들어 있어서 다른 크기로 그리면 글리프만 확대·축소된다 — 북마크 on은
    // 24 프레임(Figma 1081:4209)이라 36으로 그리면 옆 버튼들보다 1.5배 커진다.
    Widget action(String asset, String tooltip, VoidCallback? onTap,
        {double frame = 36, Color? tint}) {
      return SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 24,
          icon: FigmaIcon.tinted(asset,
              color: onTap == null ? glass.textTertiary : (tint ?? color),
              size: frame),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      );
    }

    return [
      action(FigmaIcons.download, 'clip_save'.tr(), _busy ? null : _save),
      const SizedBox(width: 8),
      action(FigmaIcons.share, 'clip_share'.tr(), _busy ? null : _share),
      const SizedBox(width: 8),
      action(FigmaIcons.memo, 'clip_memo_add'.tr(), _editMemo),
      const SizedBox(width: 8),
      action(
          isFav ? FigmaIcons.bookmarkCheck : FigmaIcons.bookmark,
          (isFav ? 'clip_favorite_remove' : 'clip_favorite_add').tr(),
          () => _toggleFavorite(clip),
          frame: isFav ? 24 : 36,
          // on/off가 둘 다 채워진 리본이라 모양만으로는 구분이 약하다 —
          // 안 한 쪽을 50% 연하게 그린다(2026-09-21 사용자 결정).
          tint: isFav ? null : color.withValues(alpha: .5)),
    ];
  }

  Widget _actionPill(GlassPalette glass, MotionClip? clip, bool isFav) {
    return Container(
      key: ClipPlaylistPlayerScreen.actionPillKey,
      width: 216,
      height: 48,
      decoration: BoxDecoration(
        color: glass.surfaceTint,
        borderRadius: BorderRadius.circular(24),
      ),
      // Figma 941:1834 — 좌우 패딩 8, 44pt 동작면 사이 간격 8.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _actionButtons(glass, clip, isFav),
      ),
    );
  }
}

/// 더블탭 ±10초 피드백 칩 (Figma 941:1928 Toast_V — 77×34 r24 #1E1E1E,
/// 안쪽 8, 문구 14/600 #FAFAFA + 4 + fast_forward 26). 되감기는 같은
/// 글리프를 좌우 반전해 문구 앞에 둔다(원본에 fast_rewind export 없음).
class _SeekFeedbackChip extends StatelessWidget {
  const _SeekFeedbackChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final forward = seconds > 0;
    final label = Text('${forward ? '+' : '-'}${seconds.abs()}s',
        style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            height: 16.70703125 / 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.28,
            color: glass.buttonForeground));
    final glyph = Transform.flip(
        flipX: !forward,
        child: FigmaIcon.tinted(FigmaIcons.fastForward,
            size: 26, color: glass.buttonForeground));
    return Container(
        key: const Key('player_seek_feedback'),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: glass.textPrimary, borderRadius: BorderRadius.circular(24)),
        // alignment를 주면 Container가 가로로 늘어나 Align 위치가 무의미해진다.
        child: Center(
            widthFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (forward) ...[
                label,
                const SizedBox(width: 4),
                glyph
              ] else ...[
                glyph,
                const SizedBox(width: 4),
                label
              ],
            ])));
  }
}

/// 시크바 — 컨트롤러를 직접 listen해 position을 따라간다(VideoControls 패턴).
/// [controller]가 null이면(로딩/에러) 비활성 트랙만 그린다.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller, required this.onSeek});
  final Future<void> Function(Duration) onSeek;

  final VideoPlayerController? controller;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// 트랙을 탭/드래그로 조작 중인지 — 원형 커서(썸)는 이때만 그린다.
  /// 재생 중 상시 노출하지 않는다(사용자 지시 2026-09-12, 전 플레이어 공통
  /// 규칙 — VideoControls도 동일).
  bool _interacting = false;

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
        thumbShape: _interacting
            ? const RoundSliderThumbShape(enabledThumbRadius: 6)
            : SliderComponentShape.noThumb,
        activeTrackColor: glass.envTempPeak,
        // 연회색 트랙 — #E1E3E4 (T2에서 outline 토큰으로 정착)
        inactiveTrackColor: glass.outline,
        disabledActiveTrackColor: glass.outline,
        disabledInactiveTrackColor: glass.outline,
        thumbColor: glass.envTempPeak,
      ),
      child: Slider(
        value: _value(),
        onChangeStart: widget.controller == null
            ? null
            : (_) => setState(() => _interacting = true),
        onChangeEnd: widget.controller == null
            ? null
            : (_) => setState(() => _interacting = false),
        onChanged: widget.controller == null
            ? null
            : (val) {
                final ctrl = widget.controller!;
                final dur = ctrl.value.duration.inMilliseconds;
                if (dur > 0) {
                  unawaited(widget
                      .onSeek(Duration(milliseconds: (val * dur).round())));
                }
              },
      ),
    );
  }
}

/// 기기 저장 진행 화면 (Figma 1106:3659) — 흰 dim이 화면 전체 입력을 막고,
/// 가운데 62 원호 스피너 + 12 + '영상 다운로드 중' 18/600 #3C3C3C.
/// 실제 진행률은 제공되지 않으므로 퍼센트를 꾸미지 않는다. 진행 중에는 닫기까지
/// 가려진다(짧은 저장이며 취소 계약이 없다).
class _DownloadOverlay extends StatelessWidget {
  const _DownloadOverlay();

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Positioned.fill(
      key: const Key('player_download_overlay'),
      child: AbsorbPointer(
        child: ColoredBox(
          color: glass.wallpaper.withValues(alpha: 0.8),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SpinnerArc(size: 62, color: glass.textSecondary),
              const SizedBox(height: 12),
              Text('clip_download_progress'.tr(),
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      height: 28 / 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.36,
                      color: glass.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 원본 progress_activity 글리프(3/4 원호)를 도는 커스텀 스피너. Material
/// CircularProgressIndicator를 쓰지 않는다(프로젝트 금지) — 디자인이 지정한
/// 그림을 그대로 그린다.
class _SpinnerArc extends StatefulWidget {
  const _SpinnerArc({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<_SpinnerArc> createState() => _SpinnerArcState();
}

class _SpinnerArcState extends State<_SpinnerArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _turn,
        child: CustomPaint(
          key: const Key('player_download_spinner'),
          size: Size.square(widget.size),
          painter: _ArcPainter(color: widget.color),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 10;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 1.5,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
