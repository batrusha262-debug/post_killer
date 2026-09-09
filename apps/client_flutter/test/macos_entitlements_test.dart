import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final filename in [
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    test('$filename permits outgoing network requests', () {
      final file = File('macos/Runner/$filename');
      final contents = file.readAsStringSync();

      expect(
        contents,
        contains(
          RegExp(
            r'<key>com\.apple\.security\.network\.client</key>\s*<true\s*/>',
          ),
        ),
      );
    });
  }
}
