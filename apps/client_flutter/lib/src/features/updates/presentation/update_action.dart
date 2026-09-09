import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/update_bloc.dart';
import '../domain/update_models.dart';

class UpdateAction extends StatelessWidget {
  const UpdateAction({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<UpdateBloc, UpdateState>(
    listener: (context, state) {
      switch (state) {
        case UpdateCurrent():
          _showMessage(context, 'Установлена последняя версия.');
        case UpdateCheckFailed():
          _showMessage(
            context,
            'Не удалось проверить обновления. Попробуйте позже.',
          );
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
          onPressed: state is UpdateChecking
              ? null
              : () {
                  if (state case UpdateAvailable(:final update)) {
                    _showDownloadDialog(context, update);
                  } else {
                    context.read<UpdateBloc>().add(
                      const UpdateCheckRequested(),
                    );
                  }
                },
          icon: state is UpdateChecking
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

  static void _showMessage(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  static Future<void> _showDownloadDialog(
    BuildContext context,
    AppUpdate update,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Доступна ${update.version}'),
      content: Text(
        'Будет открыт официальный файл ${update.assetName} из GitHub Releases. '
        'После загрузки установите его обычным способом с заменой старого приложения.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final launched = await launchUrl(
              update.downloadUri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched && context.mounted) {
              _showMessage(context, 'Не удалось открыть загрузку в браузере.');
            }
          },
          child: const Text('Скачать'),
        ),
      ],
    ),
  );
}
