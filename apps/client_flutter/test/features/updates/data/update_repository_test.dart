import 'package:client_flutter/src/features/updates/data/github_release_gateway.dart';
import 'package:client_flutter/src/features/updates/data/update_repository.dart';
import 'package:client_flutter/src/features/updates/domain/update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selects only the package matching the current desktop platform',
    () async {
      final repository = GitHubUpdateRepository(
        gateway: _FakeGateway(),
        currentVersion: '0.1.6',
        platform: UpdatePlatform.windows,
      );

      final result = await repository.checkForUpdate();

      expect(result, isA<UpdateIsAvailable>());
      expect(
        (result as UpdateIsAvailable).update.assetName,
        'Post-Killer-0.1.7-windows-setup.exe',
      );
    },
  );

  test('does not offer a release that is not newer', () async {
    final repository = GitHubUpdateRepository(
      gateway: _FakeGateway(version: 'v0.1.6'),
      currentVersion: '0.1.6',
      platform: UpdatePlatform.macos,
    );

    expect(await repository.checkForUpdate(), isA<UpdateIsCurrent>());
  });
}

class _FakeGateway implements GitHubReleaseGateway {
  _FakeGateway({this.version = 'v0.1.7'});
  final String version;

  @override
  Future<LatestReleasePayload> fetchLatestRelease() async =>
      LatestReleasePayload(
        version: version,
        assets: [
          ReleaseAssetPayload(
            name: 'Post-Killer-0.1.7-macos.dmg',
            downloadUrl: Uri.parse('https://example.test/macos.dmg'),
          ),
          ReleaseAssetPayload(
            name: 'Post-Killer-0.1.7-windows-setup.exe',
            downloadUrl: Uri.parse('https://example.test/windows.exe'),
          ),
        ],
      );
}
