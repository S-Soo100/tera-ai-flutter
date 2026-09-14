import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('세로 진입, 명시적 가로 전환, 종료 시 세로 복원 순서를 보장한다', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final controller = PlayerOrientationController();
    await PlayerOrientationController.settled;
    expect(controller.state, false);
    await controller.toggle();
    expect(controller.state, true);
    controller.dispose();
    await PlayerOrientationController.settled;
    final orientations = calls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .map((call) => call.arguments)
        .toList();
    expect(orientations, [
      ['DeviceOrientation.portraitUp'],
      ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      ['DeviceOrientation.portraitUp']
    ]);
    expect(
        calls
            .where((call) =>
                call.method == 'SystemChrome.setEnabledSystemUIOverlays')
            .last
            .arguments,
        ['SystemUiOverlay.top', 'SystemUiOverlay.bottom']);
  });
  test('방향 요청 처리 중 닫아도 마지막 요청은 세로 복원이다', () async {
    final orientations = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations')
        orientations.add(call.arguments);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final controller = PlayerOrientationController();
    controller.toggle();
    controller.dispose();
    await PlayerOrientationController.settled;
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
  });
}
