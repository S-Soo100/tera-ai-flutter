import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Box open 실패 시 1회 reset 후 재open.
/// Why: 어댑터에 신규 필드 추가 후 기존 디스크 데이터의 deserialize 실패를 자동 복구.
/// 호출자는 box 안 데이터가 silent drop 될 수 있음을 알고 써야 함.
Future<Box<T>> openBoxSafely<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e, st) {
    debugPrint('[Hive] Box "$name" open failed → reset: $e\n$st');
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox<T>(name);
  }
}

Future<Box<dynamic>> openUntypedBoxSafely(String name) async {
  try {
    return await Hive.openBox(name);
  } catch (e, st) {
    debugPrint('[Hive] Box "$name" open failed → reset: $e\n$st');
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox(name);
  }
}
