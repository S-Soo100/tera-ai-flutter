// 라이브 뷰 phase별 화면(2026-09-23 기획 §5). EasyLocalization을 띄우지 않아
// `.tr()`은 키를 그대로 돌려준다 — 문구가 아니라 **어느 키를 쓰는지**를 본다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/webrtc_live_view.dart';

const _cam = 'cam-1';

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
  int retries = 0;
  @override
  Future<void> retry() async => retries++;
}

Future<_Fixed> _pump(WidgetTester tester, WebRtcLiveState s) async {
  late _Fixed c;
  await tester.pumpWidget(
    // 반복 호출마다 새 scope — 같은 scope면 provider가 재생성되지 않는다.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        webrtcLiveControllerProvider(_cam)
            .overrideWith((ref) => c = _Fixed(ref, _cam, s)),
      ],
      child: const MaterialApp(
        home: SizedBox(
            width: 320, height: 180, child: WebRtcLiveView(cameraUuid: _cam)),
      ),
    ),
  );
  // shimmer는 무한 애니메이션 — pumpAndSettle 금지.
  await tester.pump();
  return c;
}

void main() {
  testWidgets('연결 단계 셋은 모두 "라이브 연결 중" 하나로 보인다', (tester) async {
    for (final p in [
      WebRtcLivePhase.connectingConfig,
      WebRtcLivePhase.offering,
      WebRtcLivePhase.connectingIce,
    ]) {
      await _pump(tester, WebRtcLiveState(phase: p));
      expect(find.text('crecam_live_connecting'), findsOneWidget,
          reason: p.name);
      expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
    }
  });

  testWidgets('첫 프레임 대기는 "영상을 불러오고 있어요"', (tester) async {
    await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.waitingVideo));
    expect(find.text('crecam_live_loading_video'), findsOneWidget);
  });

  testWidgets('recovering은 자동 복구 문구만, 버튼 없음', (tester) async {
    await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.recovering));
    expect(find.text('crecam_live_recovering'), findsOneWidget);
    expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
  });

  testWidgets('failed는 사유 + 다시 연결 버튼, 누르면 retry 한 번', (tester) async {
    final c = await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.failed,
            errorKey: 'crecam_live_error_camera_offline'));
    expect(find.text('crecam_live_error_camera_offline'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(WebRtcLiveView.retryButtonKey),
        matching: find.byType(OutlinedButton)));
    await tester.pump();
    expect(c.retries, 1);
  });

  test('영상 위 알약 — stalled 우선, 그다음 statsUnknown, 정상은 없음', () {
    expect(
        WebRtcLiveView.pillKeyFor(const WebRtcLiveState(
            phase: WebRtcLivePhase.stalled, statsUnknown: true)),
        'crecam_live_stalled');
    expect(
        WebRtcLiveView.pillKeyFor(const WebRtcLiveState(
            phase: WebRtcLivePhase.streaming, statsUnknown: true)),
        'crecam_live_stats_unknown');
    expect(
        WebRtcLiveView.pillKeyFor(
            const WebRtcLiveState(phase: WebRtcLivePhase.streaming)),
        isNull);
  });
}
