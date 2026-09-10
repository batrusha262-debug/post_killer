import 'dart:io';

import 'package:client_flutter/src/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('post-killer-settings-');
    file = File('${directory.path}/appearance.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'preferences survive restart and rapid updates preserve latest values',
    () async {
      final settings = AppSettings(file: file);
      final first = settings.update(appearance: AppAppearance.dark);
      final second = settings.update(
        appearance: AppAppearance.slay,
        compact: true,
        reduceMotion: true,
      );
      await Future.wait([first, second]);
      final restored = AppSettings(file: file);
      await restored.load();
      expect(restored.appearance, AppAppearance.slay);
      expect(restored.compact, isTrue);
      expect(restored.reduceMotion, isTrue);
      settings.dispose();
      restored.dispose();
    },
  );

  test('missing, invalid and unknown settings use safe defaults', () async {
    for (final content in [
      null,
      '{broken',
      '[]',
      '{"appearance":"future","compact":"yes"}',
    ]) {
      if (content != null) await file.writeAsString(content);
      final settings = AppSettings(file: file);
      await settings.load();
      expect(settings.appearance, AppAppearance.system);
      expect(settings.compact, isFalse);
      settings.dispose();
    }
  });

  test('save failure keeps session preference and reports it', () async {
    await file.create();
    final settings = AppSettings(file: File('${file.path}/invalid.json'));
    await settings.update(appearance: AppAppearance.dark);
    expect(settings.appearance, AppAppearance.dark);
    expect(settings.saveError, isNotNull);
    settings.dispose();
  });
}
