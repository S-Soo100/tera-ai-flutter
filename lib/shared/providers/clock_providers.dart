import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 1초 tick. autoDispose라 구독하는 화면을 떠나면 타이머가 멈춘다. 제어 타일의
/// 카운트다운 부제([CageControlGrid])와 라이브 쉼 카운트다운이 쓴다.
final secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
