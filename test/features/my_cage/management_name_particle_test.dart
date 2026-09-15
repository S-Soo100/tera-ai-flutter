import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/management_widgets.dart';

void main() {
  test('topic particle supports Korean and numbered device names', () {
    expect(managementNameHasFinalConsonant('관찰 카메라'), false);
    expect(managementNameHasFinalConsonant('사육장'), true);
    expect(managementNameHasFinalConsonant('크랑이'), false);
    expect(managementNameHasFinalConsonant('사육장 1'), true);
    expect(managementNameHasFinalConsonant('사육장 2'), false);
    expect(managementNameHasFinalConsonant('카메라 0 '), true);
    expect(managementNameHasFinalConsonant('Camera'), isNull);
    expect(managementNameHasFinalConsonant(''), isNull);
  });
}
