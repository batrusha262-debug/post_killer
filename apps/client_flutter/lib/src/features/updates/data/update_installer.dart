import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../domain/update_models.dart';

/// Downloads a verified-release asset locally before handing it to the native
/// platform updater. No browser or second manual download is needed.
abstract interface class UpdateInstaller {
  Future<void> downloadAndInstall(AppUpdate update);
}

class HttpPlatformUpdateInstaller implements UpdateInstaller {
  HttpPlatformUpdateInstaller({http.Client? client})
    : _client = client ?? http.Client();

  static const _channel = MethodChannel('post_killer/update');
  final http.Client _client;

  @override
  Future<void> downloadAndInstall(AppUpdate update) async {
    final extension = _extensionOf(update.assetName);
    final target = File(
      '${Directory.systemTemp.path}/post-killer-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    try {
      final response = await _client
          .send(
            http.Request('GET', update.downloadUri)
              ..headers['User-Agent'] = 'Post-Killer',
          )
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != HttpStatus.ok) {
        throw const UpdateInstallException(
          'Не удалось скачать файл обновления.',
        );
      }
      await response.stream.pipe(target.openWrite());
      if (await target.length() == 0) {
        throw const UpdateInstallException('Получен пустой файл обновления.');
      }
      if (Platform.isWindows) {
        await Process.start(target.path, const [
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
          '/RESTARTAPPLICATIONS',
        ], mode: ProcessStartMode.detached);
        exit(0);
      }
      if (!Platform.isMacOS) {
        throw const UpdateInstallException(
          'Автообновление пока доступно для macOS и Windows.',
        );
      }
      await _channel.invokeMethod<void>('install', {
        'filePath': target.path,
        'assetName': update.assetName,
      });
    } on UpdateInstallException {
      rethrow;
    } on TimeoutException {
      throw const UpdateInstallException(
        'Превышено время загрузки обновления.',
      );
    } on MissingPluginException {
      throw const UpdateInstallException(
        'Автообновление не поддерживается на этой платформе.',
      );
    } on PlatformException catch (error) {
      throw UpdateInstallException(
        error.message ?? 'Не удалось установить обновление.',
      );
    } on Object {
      throw const UpdateInstallException(
        'Не удалось скачать или запустить обновление.',
      );
    }
  }

  static String _extensionOf(String assetName) {
    final dot = assetName.lastIndexOf('.');
    return dot == -1 ? '' : assetName.substring(dot);
  }
}

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);
  final String message;
}
