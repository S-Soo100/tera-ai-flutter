import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/home_set_providers.dart';
import '../my_cage_providers.dart';

/// 사육장 설정 — 현재 세트 카메라의 "화면 뒤집기(180°)" 토글
/// (설치 방향 보정, 회신 2026-09-08).
///
/// 노출 조건: 현재 세트에 카메라가 있고 `capabilities.rotate_180`을 보고한
/// 신 펌웨어일 때만. 구 펌웨어·카메라 없음은 **타일째 숨김** — 계약(회신 §4)
/// 이 "토글 미노출"이고, 기능이 아예 없는 기기라 회색 비활성으로 이유를
/// 밝힐 대상도 아니다(LED dimmable 슬라이더와 같은 문법).
///
/// 쓰기는 REST `PATCH /cameras/{id}` 하나 — 서버가 MQTT 발행·재연결 동기화를
/// 책임지므로 앱은 ack를 기다리지 않는다. 반영은 cameras Realtime UPDATE →
/// [camerasProvider] → [currentSetProvider] 캐스케이드로 돌아온다.
class CameraRotateTile extends ConsumerStatefulWidget {
  const CameraRotateTile({super.key});

  static const tileKey = Key('camera_rotate_tile');

  @override
  ConsumerState<CameraRotateTile> createState() => _CameraRotateTileState();
}

class _CameraRotateTileState extends ConsumerState<CameraRotateTile> {
  bool _busy = false;

  /// 낙관적 표시 — PATCH 응답과 Realtime 반영 사이에 스위치가 되돌아가
  /// 보이지 않게 한다. 서버 값이 따라잡으면 내려놓는다.
  bool? _pending;

  Future<void> _toggle(String cameraUuid, bool next) async {
    setState(() {
      _busy = true;
      _pending = next;
    });
    try {
      await ref.read(cameraRepositoryProvider).setRotate180(cameraUuid, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending = null); // 실패 — 서버 값으로 되돌림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('camera_rotate_failed'.tr(args: ['$e']))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = ref.watch(currentSetProvider).valueOrNull?.camera;
    if (camera == null || !camera.rotate180Capable) {
      return const SizedBox.shrink();
    }
    // 서버 값이 낙관적 표시를 따라잡았으면 정리 (build 중 setState 금지 —
    // 다음 빌드도 같은 값을 그리므로 필드만 내려놓으면 된다).
    if (_pending != null && camera.rotate180 == _pending) _pending = null;

    return SwitchListTile(
      key: CameraRotateTile.tileKey,
      secondary: const Icon(Icons.flip_camera_android_outlined),
      // 카메라명은 부제로 — 제목에 붙이면 긴 이름이 어색하게 꺾인다
      // (2026-09-08 사용성 리뷰 2번).
      title: Text('camera_rotate_title'.tr()),
      // 적용 시점 안내는 회신 §6 권장 문구 그대로 — Bayer 검증 결과로
      // "즉시"가 "재시작 후"로 바뀌어도 문구가 버티게 "잠시 후"로 둔다.
      subtitle: Text('camera_rotate_subtitle'.tr(args: [camera.name])),
      value: _pending ?? camera.rotate180,
      onChanged: _busy ? null : (v) => _toggle(camera.id, v),
    );
  }
}
