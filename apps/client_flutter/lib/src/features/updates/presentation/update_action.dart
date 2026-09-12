import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/update_bloc.dart';
import '../data/update_installer.dart';
import '../domain/update_models.dart';

class UpdateAction extends StatefulWidget {
  const UpdateAction({super.key, this.installer});

  final UpdateInstaller? installer;

  @override
  State<UpdateAction> createState() => _UpdateActionState();
}

class _UpdateActionState extends State<UpdateAction> {
  late final UpdateInstaller _installer =
      widget.installer ?? HttpPlatformUpdateInstaller();
  bool _isInstalling = false;
  var _automaticCheckInProgress = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UpdateBloc>().add(const UpdateCheckRequested());
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<UpdateBloc, UpdateState>(
    listener: (context, state) {
      switch (state) {
        case UpdateCurrent():
          if (!_automaticCheckInProgress) {
            _showMessage(context, 'Установлена последняя версия.');
          }
        case UpdateCheckFailed(:final message):
          if (!_automaticCheckInProgress) _showFailure(context, message);
        case UpdateAvailable(:final update):
          _showDownloadDialog(context, update);
        case UpdateIdle() || UpdateChecking():
          break;
      }
    },
    builder: (context, state) {
      final label = state is UpdateAvailable
          ? 'Доступна версия ${state.update.version}'
          : 'Проверить обновления';
      return Semantics(
        button: true,
        label: label,
        child: IconButton(
          key: const Key('check-updates-button'),
          tooltip: label,
          onPressed: state is UpdateChecking || _isInstalling
              ? null
              : () {
                  if (state case UpdateAvailable(:final update)) {
                    _showDownloadDialog(context, update);
                  } else {
                    _automaticCheckInProgress = false;
                    context.read<UpdateBloc>().add(
                      const UpdateCheckRequested(),
                    );
                  }
                },
          icon: state is UpdateChecking || _isInstalling
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  state is UpdateAvailable
                      ? Icons.system_update_alt
                      : Icons.system_update_outlined,
                ),
        ),
      );
    },
  );

  void _showMessage(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _showFailure(BuildContext context, String message) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Проверка обновлений'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openUrl(
                  context,
                  Uri.parse(
                    'https://github.com/batrusha262-debug/post_killer/releases',
                  ),
                );
              },
              child: const Text('Открыть релизы'),
            ),
          ],
        ),
      );

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showMessage(context, 'Не удалось открыть браузер.');
      }
    } on Object {
      if (context.mounted) _showMessage(context, 'Не удалось открыть браузер.');
    }
  }

  Future<void> _showDownloadDialog(
    BuildContext context,
    AppUpdate update,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Доступна ${update.version}'),
      content: Text(
        'Версия ${update.version} будет скачана из GitHub Releases и установлена '
        'поверх текущей версии. Приложение перезапустится автоматически.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            setState(() => _isInstalling = true);
            try {
              await _installer.downloadAndInstall(update);
            } on UpdateInstallException catch (error) {
              if (context.mounted) _showMessage(context, error.message);
            } finally {
              if (context.mounted) setState(() => _isInstalling = false);
            }
          },
          child: const Text('Скачать и установить'),
        ),
      ],
    ),
  );
}
