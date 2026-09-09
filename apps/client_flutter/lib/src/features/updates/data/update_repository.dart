import 'dart:io';

import '../domain/update_models.dart';
import 'github_release_gateway.dart';

abstract interface class UpdateRepository {
  Future<UpdateCheckResult> checkForUpdate();
}

class GitHubUpdateRepository implements UpdateRepository {
  GitHubUpdateRepository({
    required GitHubReleaseGateway gateway,
    required String currentVersion,
    UpdatePlatform? platform,
  }) : this._(gateway, currentVersion, platform ?? _currentPlatform());

  GitHubUpdateRepository._(this._gateway, this._currentVersion, this._platform);

  final GitHubReleaseGateway _gateway;
  final String _currentVersion;
  final UpdatePlatform _platform;

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    final release = await _gateway.fetchLatestRelease();
    if (!isNewerStableVersion(release.version, _currentVersion)) {
      return const UpdateIsCurrent();
    }
    final asset = release.assets
        .where((asset) => _matchesPlatform(asset.name))
        .firstOrNull;
    if (asset == null) throw const UpdateLookupException();
    return UpdateIsAvailable(
      AppUpdate(
        version: release.version,
        downloadUri: asset.downloadUrl,
        assetName: asset.name,
      ),
    );
  }

  bool _matchesPlatform(String assetName) => switch (_platform) {
    UpdatePlatform.macos => assetName.endsWith('-macos.dmg'),
    UpdatePlatform.windows => assetName.endsWith('-windows-setup.exe'),
    UpdatePlatform.linux =>
      assetName.endsWith('_amd64.deb') ||
          assetName.endsWith('-linux-x86_64.AppImage'),
  };

  static UpdatePlatform _currentPlatform() =>
      switch (Platform.operatingSystem) {
        'macos' => UpdatePlatform.macos,
        'windows' => UpdatePlatform.windows,
        'linux' => UpdatePlatform.linux,
        _ => throw UnsupportedError(
          'Updates are available only on desktop platforms.',
        ),
      };
}
