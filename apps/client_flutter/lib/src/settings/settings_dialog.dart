import 'package:flutter/material.dart';

import 'app_settings.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => AlertDialog(
      title: const Text('Настройки'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Оформление',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const [
                    (
                      AppAppearance.system,
                      'Системная',
                      Icons.brightness_auto_outlined,
                    ),
                    (AppAppearance.light, 'Светлая', Icons.light_mode_outlined),
                    (AppAppearance.dark, 'Тёмная', Icons.dark_mode_outlined),
                    (AppAppearance.slay, 'Midnight', Icons.auto_awesome),
                  ])
                    ChoiceChip(
                      key: Key('theme-${entry.$1.name}'),
                      avatar: Icon(entry.$3, size: 18),
                      label: Text(entry.$2),
                      selected: settings.appearance == entry.$1,
                      onSelected: (_) => settings.update(appearance: entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                settings.appearance == AppAppearance.slay
                    ? 'Midnight: тёмная рабочая тема с фиолетовым акцентом.'
                    : 'Системная тема следует оформлению устройства.',
              ),
              const SizedBox(height: 20),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Компактный интерфейс'),
                subtitle: const Text(
                  'Меньше отступов в полях и элементах управления',
                ),
                value: settings.compact,
                onChanged: (value) => settings.update(compact: value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Уменьшить анимацию'),
                subtitle: const Text(
                  'Мгновенная смена темы и минимум движения',
                ),
                value: settings.reduceMotion,
                onChanged: (value) => settings.update(reduceMotion: value),
              ),
              if (settings.saveError != null)
                Text(
                  settings.saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}
