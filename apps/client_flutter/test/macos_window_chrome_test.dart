import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS starts spaciously with an application-integrated title bar', () {
    final xib = File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync();
    final window = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();

    expect(xib, contains('width="1440" height="900"'));
    expect(window, contains('minSize = NSSize(width: 1180, height: 700)'));
    expect(window, contains('styleMask.insert(.fullSizeContentView)'));
    expect(window, contains('titlebarAppearsTransparent = true'));
  });
}
