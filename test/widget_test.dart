import 'package:flutter_test/flutter_test.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_security_suite_demo/main.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

void main() {
  test('demoMaterialTheme attaches SecuritySuiteTheme extension', () {
    final themeData = demoMaterialTheme(AppTheme.light());
    expect(themeData.extension<SecuritySuiteTheme>(), isNotNull);
  });
}
