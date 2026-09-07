import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/widgets/skeleton_loading.dart';
import 'community_providers.dart';

/// 커뮤니티 게시물 재생 — 전체화면 가로 전용(클립 재생 결정 §6-B와 동일).
/// 저장·공유·즐겨찾기 없음(타인 소유 영상). 닫기만.
class CommunityPlayerScreen extends ConsumerStatefulWidget {
  const CommunityPlayerScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<CommunityPlayerScreen> createState() =>
      _CommunityPlayerScreenState();
}

class _CommunityPlayerScreenState extends ConsumerState<CommunityPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _initialized = false;

  /// 나갈 때 되돌릴 상태바 스타일 — MotionClipPlayerScreen과 같은 함정.
  /// 어노테이션이 사라지면 Flutter는 마지막 값을 유지하므로 직접 되돌린다.
  SystemUiOverlayStyle? _restoreOverlayStyle;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 앱 테마 기준 — 라이트 테마면 어두운 아이콘(.dark)이 맞다.
    _restoreOverlayStyle = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }

  Future<void> _init() async {
    try {
      final repo = ref.read(communityRepositoryProvider);
      final post = await repo.getPost(widget.postId);
      if (post == null) throw StateError('post not found');
      final url = await repo.signedVideoUrl(post.videoPath);
      // hoist — initialize 실패 시에도 dispose 가능하게 (controller leak 교훈)
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      try {
        await controller.initialize();
      } catch (e) {
        await controller.dispose();
        _controller = null;
        rethrow;
      }
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // 되돌리지 않으면 이 화면을 닫은 뒤에도 앱 전체가 가로로 남는다.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // edgeToEdge로 돌리면 iOS에서 상태바가 가려진 채 남는 경우가 있다 —
    // manual + 전체 오버레이로 명시 복원(MotionClipPlayerScreen 실기기 교훈).
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    if (_restoreOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Center(
            child: _error != null
                ? Text('community_play_error'.tr(),
                    style: const TextStyle(color: Colors.white70))
                : _initialized && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    // 계획서의 Shimmer+SizedBox.expand는 칠할 것이 없어
                    // 아무것도 안 그린다 — 재생 화면 선례의 스켈레톤을 쓴다.
                    : const AspectRatio(
                        aspectRatio: 16 / 9,
                        child: SkeletonLoading(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0),
                      ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
