import '../domain/highlight_publication.dart';
import 'highlight_read_providers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'my_cage_providers.dart';
import 'bookmark_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/crecam_detail_top_bar.dart';

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
class ClipPlaylistPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlaylistPlayerScreen({
    super.key,
    required this.clipId,
    this.playlist,
    this.playFromSec = const {},
    this.source = ClipPlaybackSource.single,
    this.cameraId,
    this.hourStart,
    this.hourEndExclusive,
    this.highlightBatchId,
  });

  final String clipId;
  final ClipPlaybackSource source;
  final String? cameraId, highlightBatchId;
  final DateTime? hourStart, hourEndExclusive;
  final List<String>? playlist;

  /// clip id → 재생 시작점(초). [ClipPlaylistArgs.playFromSec].
  final Map<String, double> playFromSec;

  /// 테스트용 — 페이지네이션 세그먼트 식별.
  static const paginationKey = Key('crecam_player_pagination');

  /// 테스트용 — 이전/다음 화살표와 위치 카운터를 검증한다.
  static const prevArrowKey = Key('crecam_player_prev_arrow');
  static const nextArrowKey = Key('crecam_player_next_arrow');
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
  bool _isPlaying = false;
  bool _autoAdvanced = false; // 클립당 자동 다음 1회 가드

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
    _filmstripSeed = (route: _orientationKey, initialIndex: initialIndex);
    _filmstripController = ScrollController(
      initialScrollOffset: ClipFilmstrip.offsetForIndex(initialIndex),
    );
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_completeHourPlaylist());
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _filmstripController.dispose();
    super.dispose();
  }

  Future<void> _completeHourPlaylist() async {
    final owner = ref.read(currentUserProvider)?.id;
    final cameraId = widget.cameraId;
    final start = widget.hourStart;
    final end = widget.hourEndExclusive;
    if (widget.source != ClipPlaybackSource.hour ||
        owner == null ||
        cameraId == null ||
        start == null ||
        end == null) {
      return;
    }
    if (ref.read(playerPlaylistLoadingProvider(_orientationKey))) return;
    final repository = ref.read(motionClipRepositoryProvider);
    ref.read(playerPlaylistLoadingProvider(_orientationKey).notifier).state =
        true;
    ref.read(playerPlaylistErrorProvider(_orientationKey).notifier).state =
        false;
    MotionClipCursor? cursor;
    final ids = <String>[];
    try {
      do {
        final page = await repository.listPage((
          ownerId: owner,
          cameraId: cameraId,
          range: (start: start, endExclusive: end)
        ), before: cursor);
        if (!mounted || ref.read(currentUserProvider)?.id != owner) return;
        ids.addAll(page.items.map((clip) => clip.id));
        final current = _currentClipId;
        final expanded = {...ids, ..._playlist}.toList(growable: false);
        _playlist = expanded;
        _index = expanded.indexOf(current);
        _setFilmstripPreview(_index);
        _centerFilmstrip(_index, animate: false);
        cursor = page.nextCursor;
        if (!page.hasMore) break;
      } while (cursor != null);
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

  void _seekBy(Duration delta) {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    final v = controller.value;
    var pos = v.position + delta;
    if (pos < Duration.zero) pos = Duration.zero;
    if (pos > v.duration) pos = v.duration;
    unawaited(_seekTo(pos));
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

  void _toggleFavorite(MotionClip? clip) {
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;
    final key = (ownerId: owner, clipId: _currentClipId);
    final state = ref.read(bookmarkControllerProvider(key));
    if (clip == null && !state.desired) return;
    ref
        .read(bookmarkControllerProvider(key).notifier)
        .setDesired(!state.desired);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    ref.watch(playerPlaylistProvider(_playlistSeed));
    ref.watch(playerIndexProvider(_playlistSeed));
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
      return Scaffold(
          backgroundColor: glass.wallpaper,
          body: Stack(fit: StackFit.expand, children: [
            _videoArea(glass, BoxConstraints.tight(MediaQuery.sizeOf(context)),
                fill: true),
            if (controlsVisible)
              SafeArea(
                  child: Column(children: [
                ColoredBox(
                    color: glass.surfaceHeader.withValues(alpha: 0.9),
                    child: _topBar(glass, startedAt)),
                const Spacer(),
                ColoredBox(
                    color: glass.wallpaper.withValues(alpha: 0.85),
                    child: Column(children: [
                      _SeekBar(
                          controller: _initialized ? _controller : null,
                          onSeek: _seekTo),
                      _controlRow(glass),
                      _navigationActions(glass, clip, isFav, showArrows: false),
                      if (_playlist.length > 1) _thumbnailStrip(),
                      if (ref
                          .watch(playerPlaylistErrorProvider(_orientationKey)))
                        _playlistRetry(),
                    ])),
              ])),
          ]));
    }
    return Scaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                          const SizedBox(height: 24),
                        ],
                      )))),
    ]));
  }

  Widget _navigationActions(GlassPalette glass, MotionClip? clip, bool isFav,
          {bool showArrows = true}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (showArrows) ...[
          if (_index > 0)
            _navArrow(
              key: ClipPlaylistPlayerScreen.prevArrowKey,
              asset: FigmaIcons.arrowPrevious,
              tooltip: MaterialLocalizations.of(context).previousPageTooltip,
              onTap: () => _go(-1),
            )
          else
            const SizedBox(width: 44, height: 44),
          const SizedBox(width: 24),
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
                          (ownerId: owner, clipId: _currentClipId)).notifier)
                      .retry(),
                  child: Text('retry'.tr())),
        ]),
        if (showArrows) ...[
          const SizedBox(width: 24),
          if (_index < _playlist.length - 1)
            _navArrow(
              key: ClipPlaylistPlayerScreen.nextArrowKey,
              asset: FigmaIcons.arrowNext,
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
              onTap: () => _go(1),
            )
          else
            const SizedBox(width: 44, height: 44),
        ],
      ]);

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
          dimension: 44,
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
      onPressed: _completeHourPlaylist,
      child: Text('crecam_playlist_retry'.tr()));

  Widget _thumbnailStrip() => Semantics(
        key: ClipPlaylistPlayerScreen.counterKey,
        label:
            '${_index + 1} / ${_playlist.length}${(ref.watch(playerPlaylistLoadingProvider(_orientationKey)) || ref.watch(playerPlaylistErrorProvider(_orientationKey))) ? '+' : ''}',
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

  Widget _controlRow(GlassPalette glass) {
    final speed = ref.watch(playerSpeedProvider(_orientationKey));
    final landscape = ref.watch(playerOrientationProvider(_orientationKey));
    final controller = _controller;
    String time(Duration value) =>
        '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          IconButton(
              key: const Key('player_play_pause'),
              onPressed: _togglePlay,
              icon: _isPlaying
                  ? FigmaIcon.tinted(FigmaIcons.pause,
                      size: 36, color: glass.textPrimary)
                  : FigmaIcon.tinted(FigmaIcons.play,
                      size: 20, color: glass.textPrimary)),
          if (controller != null)
            ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => Text(
                    '${time(value.position)} / ${time(value.duration)}',
                    style:
                        TextStyle(fontSize: 12, color: glass.textSecondary))),
          if (_startedMidway)
            Flexible(
                child: TextButton(
                    key: ClipPlaylistPlayerScreen.fromStartKey,
                    onPressed: _restartFromZero,
                    child: Text('crecam_player_from_start'.tr(),
                        maxLines: 1, overflow: TextOverflow.ellipsis))),
          const Spacer(),
          TextButton(
              key: const Key('player_speed'),
              onPressed: () {
                final next = speed == 1 ? 2.0 : 1.0;
                ref.read(playerSpeedProvider(_orientationKey).notifier).state =
                    next;
                _controller?.setPlaybackSpeed(next);
              },
              child: speed == 2
                  ? FigmaIcon.tinted(FigmaIcons.speed2x,
                      color: glass.textPrimary, size: 24)
                  : Text('1×',
                      style: TextStyle(
                          color: glass.textPrimary,
                          fontWeight: FontWeight.w700))),
          IconButton(
              key: const Key('player_orientation'),
              tooltip:
                  (landscape ? 'player_portrait' : 'player_landscape').tr(),
              onPressed: () => ref
                  .read(playerOrientationProvider(_orientationKey).notifier)
                  .toggle(),
              icon: FigmaIcon.tinted(FigmaIcons.expand,
                  color: glass.textPrimary, size: 36)),
        ]));
  }

  Widget _actionPill(GlassPalette glass, MotionClip? clip, bool isFav) {
    final color = glass.textPrimary;
    Widget action(String asset, String tooltip, VoidCallback? onTap) {
      return SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 24,
          icon: FigmaIcon.tinted(asset,
              color: onTap == null ? glass.textTertiary : color, size: 36),
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
          action(FigmaIcons.download, 'clip_save'.tr(), _busy ? null : _save),
          const SizedBox(width: 8),
          action(FigmaIcons.share, 'clip_share'.tr(), _busy ? null : _share),
          const SizedBox(width: 8),
          action(
              isFav ? FigmaIcons.bookmarkCheck : FigmaIcons.bookmark,
              (isFav ? 'clip_favorite_remove' : 'clip_favorite_add').tr(),
              () => _toggleFavorite(clip)),
        ],
      ),
    );
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
