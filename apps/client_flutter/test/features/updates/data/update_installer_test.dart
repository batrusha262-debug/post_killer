import 'package:client_flutter/src/features/updates/data/update_installer.dart';
import 'package:client_flutter/src/features/updates/domain/update_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('rejects an empty downloaded update before installation', () async {
    final client = MockClient((_) async => http.Response('', 200));
    addTearDown(client.close);
    final installer = HttpPlatformUpdateInstaller(client: client);

    await expectLater(
      installer.downloadAndInstall(
        AppUpdate(
          version: 'v0.2.8',
          assetName: 'Post-Killer-0.2.8-macos.dmg',
          downloadUri: Uri.parse('https://example.test/update.dmg'),
        ),
      ),
      throwsA(
        isA<UpdateInstallException>().having(
          (error) => error.message,
          'message',
          contains('пустой'),
        ),
      ),
    );
  });
}
