import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../notification/domain/app_notification.dart';
import '../../../notification/presentation/live_notice_providers.dart';
import '../webrtc_live_controller.dart';
import 'management_widgets.dart';

/// 막대에 쓸 문구 키 — 행의 `title`이 아니라 앱 문구로 그린다(서버 문구·구 행에
/// 흔들리지 않게).
String liveNoticeTextKey(String kind) => switch (kind) {
      cameraWeakSignalNotificationKind => 'camera_weak_signal_notice',
      _ => 'camera_focus_notice',
    };

/// 막대를 누르면 갈 곳.
/// - 초점: 그 카메라 세로 확대 라이브(Figma 1813:8265 "카메라 상세 화면으로 이동").
/// - 신호 약함: ⏳ 기획 확인 중(2026-11-16). 임시로 그 카메라 **기기 상세** —
///   Wi-Fi 약함 안내·[Wi-Fi 바꾸기]·[카메라 재시작]이 있는 곳(기획 D2 추천안).
String liveNoticeTapPath(String kind, String cameraId) => switch (kind) {
      cameraWeakSignalNotificationKind => '/devices/camera/$cameraId',
      _ => '/crecam/cameras/$cameraId/live',
    };

/// 라이브 위 카메라 단위 안내 막대 — 렌즈 초점 Figma 1813:8260(카메라 탭)·
/// 네트워크 신호 약함 Figma 1877:15097(홈). 두 막대는 같은 컴포넌트다(면 #F4F4F4
/// r8·테두리·그림자 없음, 345×36, 좌우 16, 문구 16 Medium #3C3C3C·줄높이 28·자간
/// −0.32, "더보기" 16 SemiBold #C00306).
///
/// **이 카메라([cameraId])에** 안 읽은 안내가 있고 영상이 보일 때만
/// (`streaming`·`stalled`) 그린다 — 연결 중·실패·시청 제한 화면의 문구와 버튼을
/// 가리지 않는다. 같은 카메라에 둘 다 있으면 [liveNoticeKinds] 순서로 하나만.
///
/// 막대 어디든 누르면 [liveNoticeTapPath]로 가고, 그 카메라의 그 종류 안내만
/// 읽음 처리돼 사라진다.
/// 배치는 부모 Stack이 `Positioned(top: 12, left: 12, right: 12)`로 한다.
class LiveNoticeBar extends ConsumerWidget {
  const LiveNoticeBar(
      {super.key, required this.cameraId, required this.deviceId});

  /// `cameras.id`(uuid).
  final String cameraId;

  /// 기기 ID(`cameras.camera_id`) — 운영자가 이것으로 지정해도 알아본다.
  final String deviceId;

  static const tapKey = Key('live_notice_bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = (id: cameraId, deviceId: deviceId);
    final kind = ref.watch(liveNoticeKindProvider(camera));
    final hasVideo = ref.watch(
        webrtcLiveControllerProvider(cameraId).select((s) => s.phase.hasVideo));
    if (kind == null || !hasVideo) return const SizedBox.shrink();

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
          context.push(liveNoticeTapPath(kind, cameraId));
          dismissLiveNotices(ref, camera, kind);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Expanded(
                child: Text(liveNoticeTextKey(kind).tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style(FontWeight.w500, glass.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text('live_notice_more'.tr(),
                  style: style(FontWeight.w600, glass.selectionOn)),
            ]),
          ),
        ),
      ),
    );
  }
}
