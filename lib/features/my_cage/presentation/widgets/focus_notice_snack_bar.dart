import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../notification/presentation/focus_notice_providers.dart';
import '../webrtc_live_controller.dart';
import 'management_widgets.dart';

/// 라이브 위 카메라 렌즈 초점 안내 — Figma 1813:8260(카메라 탭), 메모 "홈화면에도
/// 동일하게 적용". 운영자가 **이 카메라([cameraId])에** 보낸 미읽음 안내가 있고
/// (기획 2026-11-11 카메라 단위 — 다른 카메라 라이브에는 안 뜬다) 영상이 보일 때만
/// (`streaming`·`stalled`) 그린다 — 연결 중·실패·시청 제한 화면의 문구와 버튼을
/// 가리지 않는다.
///
/// 막대 어디든 누르면 그 카메라 상세로 가고, 그 카메라 안내만 읽음 처리돼
/// 사라진다(1회성).
/// 배치는 부모 Stack이 `Positioned(top: 12, left: 12, right: 12)`로 한다.
class FocusNoticeSnackBar extends ConsumerWidget {
  const FocusNoticeSnackBar(
      {super.key, required this.cameraId, required this.deviceId});

  /// `cameras.id`(uuid).
  final String cameraId;

  /// 기기 ID(`cameras.camera_id`) — 운영자가 이것으로 지정해도 알아본다.
  final String deviceId;

  static const tapKey = Key('focus_notice_snack_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = (id: cameraId, deviceId: deviceId);
    final visible = ref.watch(focusNoticeVisibleProvider(camera));
    final hasVideo = ref.watch(
        webrtcLiveControllerProvider(cameraId).select((s) => s.phase.hasVideo));
    if (!visible || !hasVideo) return const SizedBox.shrink();

    final glass = context.glass;
    // 16/줄높이 28/자간 −0.32 — 막대 높이 36은 최소(글자를 키우면 늘어난다).
    TextStyle style(FontWeight weight, Color color) =>
        managementStyle(context, weight: weight, color: color)
            .copyWith(height: 28 / 16);
    return Material(
      color: glass.overlay,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: tapKey,
        onTap: () {
          context.push('/crecam/cameras/$cameraId/live');
          dismissFocusNotices(ref, camera);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Expanded(
                child: Text('camera_focus_notice'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style(FontWeight.w500, glass.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text('camera_focus_notice_more'.tr(),
                  style: style(FontWeight.w600, glass.selectionOn)),
            ]),
          ),
        ),
      ),
    );
  }
}
