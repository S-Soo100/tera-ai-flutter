// 카메라 상세 '카메라 초점 가이드'(Figma 1813:8229, 메모 "항상 노출").
// `.tr()`은 번역을 안 띄운 테스트에서 키를 그대로 돌려준다 — 문구 원문은
// ko.json 값으로 따로 고정한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/theme/viva_colors.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/camera_focus_guide.dart';

const _id = 'cam-uuid-1';

class _Repo extends Fake implements CameraRepository {
  @override
  Future<SysHealth> fetchHealth(String cameraUuid) async => SysHealth.empty;
}

class _FakeRenderer extends RTCVideoRenderer {
  @override
  Future<void> initialize() async {}
  @override
  set srcObject(MediaStream? stream) {}
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
}

Text _text(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

void main() {
  test('문구는 Figma 원문 그대로', () {
    final ko = jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(ko['camera_focus_guide_title'], '카메라 초점 가이드');
    expect(ko['camera_focus_guide_1'], '영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요');
    expect(ko['camera_focus_guide_2'],
        '렌즈 돌출 부분을 손으로 잡고 좌우로 천천히 돌리면서, 라이브 화면이 가장 선명해지는 위치를 찾아주세요');
    expect(ko['camera_focus_guide_3'],
        '초점 조정이 필요하면 “카메라 렌즈 초점을 맞춰주세요” 안내 메시지가 표시돼요');
  });

  testWidgets('제목 16/600 회색 + 회색 면 r16 패딩 12 안에 14/500 세 문장(간격 8)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: CameraFocusGuide()))));

    final title = _text(tester, 'camera_focus_guide_title');
    expect(title.style!.fontSize, 16);
    expect(title.style!.fontWeight, FontWeight.w600);
    expect(title.style!.color, VivaColors.labelQuaternary);

    for (final k in [
      'camera_focus_guide_1',
      'camera_focus_guide_2',
      'camera_focus_guide_3'
    ]) {
      final t = _text(tester, k);
      expect(t.style!.fontSize, 14);
      expect(t.style!.fontWeight, FontWeight.w500);
      expect(t.style!.height, 1.5); // 줄높이 21
      expect(t.style!.color, VivaColors.labelSecondary);
    }

    final box = tester.widget<Container>(find.byKey(CameraFocusGuide.boxKey));
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, VivaColors.fillButton);
    expect(deco.borderRadius, BorderRadius.circular(16));
    expect(box.padding, const EdgeInsets.all(12));

    // 제목 → 상자 8, 문장 사이 8, 상자 폭 = 393 − 48.
    final titleBottom =
        tester.getBottomLeft(find.text('camera_focus_guide_title')).dy;
    final boxRect = tester.getRect(find.byKey(CameraFocusGuide.boxKey));
    expect(boxRect.top - titleBottom, 8);
    expect(boxRect.width, tester.view.physicalSize.width /
            tester.view.devicePixelRatio -
        48);
    final gap = tester.getTopLeft(find.text('camera_focus_guide_2')).dy -
        tester.getBottomLeft(find.text('camera_focus_guide_1')).dy;
    expect(gap, 8);
  });

  group('라이브 확대 화면', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          camerasProvider.overrideWith((ref) => Stream.value([
                TerraCamera(
                    id: _id,
                    cameraId: 'p4cam-1',
                    name: '카메라 3',
                    firmwareVer: 'fb2-p4 0.2.0-20260928',
                    isOnline: true,
                    createdAt: DateTime(2026, 9, 8))
              ])),
          cameraRepositoryProvider.overrideWithValue(_Repo()),
          sysHealthProvider(cameraRebootTarget(_id))
              .overrideWith((ref) => const Stream.empty()),
          webrtcLiveControllerProvider.overrideWith((ref, id) => _Fixed(
              ref,
              id,
              WebRtcLiveState(
                  phase: WebRtcLivePhase.streaming,
                  renderer: _FakeRenderer()))),
        ],
        child: const MaterialApp(
            home: Scaffold(body: CameraLiveFullscreenScreen(cameraId: _id))),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('세로에는 전원 줄 아래 24에 가이드가 항상 있다', (tester) async {
      await pump(tester);
      expect(find.byType(CameraFocusGuide), findsOneWidget);
      final powerBottom =
          tester.getBottomLeft(find.text('management_power_on_label')).dy;
      final guideTop = tester.getTopLeft(find.byType(CameraFocusGuide)).dy;
      // 전원 줄(최소 높이 40) 바닥에서 24.
      final rowBottom = tester
          .getBottomLeft(find
              .ancestor(
                  of: find.text('management_power_on_label'),
                  matching: find.byType(ConstrainedBox))
              .first)
          .dy;
      expect(rowBottom, greaterThanOrEqualTo(powerBottom));
      expect(guideTop - rowBottom, 24);
    });

    testWidgets('가로에는 없다', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CameraFocusGuide), findsNothing);
    });
  });
}
