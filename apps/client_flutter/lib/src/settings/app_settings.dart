import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

enum AppAppearance { system, light, dark, slay }

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}

class AppSettings extends ChangeNotifier {
  AppSettings({this.file});

  final File? file;
  AppAppearance appearance = AppAppearance.system;
  bool compact = false;
  bool reduceMotion = false;
  String? saveError;
  Future<void> _pendingSave = Future.value();

  static Future<AppSettings> loadDesktop() async {
    final env = Platform.environment;
    final base = Platform.isMacOS
        ? '${env['HOME']}/Library/Application Support'
        : Platform.isWindows
        ? env['APPDATA'] ?? env['USERPROFILE'] ?? Directory.current.path
        : env['XDG_CONFIG_HOME'] ?? '${env['HOME']}/.config';
    final settings = AppSettings(
      file: File('$base/post-killer/appearance.json'),
    );
    await settings.load();
    return settings;
  }

  Future<void> load() async {
    if (file == null) return;
    try {
      final data = jsonDecode(await file!.readAsString());
      if (data is! Map<String, dynamic>) return;
      appearance = AppAppearance.values.firstWhere(
        (value) => value.name == data['appearance'],
        orElse: () => AppAppearance.system,
      );
      compact = data['compact'] == true;
      reduceMotion = data['reduceMotion'] == true;
    } on FileSystemException {
      // First launch and unavailable preference files use safe defaults.
    } on FormatException {
      // A damaged preference file must never prevent the workspace opening.
    }
    notifyListeners();
  }

  Future<void> update({
    AppAppearance? appearance,
    bool? compact,
    bool? reduceMotion,
  }) {
    this.appearance = appearance ?? this.appearance;
    this.compact = compact ?? this.compact;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    saveError = null;
    notifyListeners();
    final content = jsonEncode({
      'appearance': this.appearance.name,
      'compact': this.compact,
      'reduceMotion': this.reduceMotion,
    });
    return _pendingSave = _pendingSave.then((_) async {
      if (file == null) return;
      try {
        await file!.parent.create(recursive: true);
        final temporary = File('${file!.path}.tmp');
        await temporary.writeAsString(content, flush: true);
        await temporary.rename(file!.path);
      } on FileSystemException {
        saveError = 'Не удалось сохранить настройки. Изменения действуют до закрытия приложения.';
        notifyListeners();
      }
    });
  }
}
