import 'dart:io';
import 'dart:ffi';

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
    MacOSArchitecture? macosArchitecture,
  }) : this._(
         gateway,
         currentVersion,
         platform ?? _currentPlatform(),
         macosArchitecture,
       );

  GitHubUpdateRepository._(
    this._gateway,
    this._currentVersion,
    this._platform,
    MacOSArchitecture? macosArchitecture,
  ) : _macosArchitecture = macosArchitecture;

  final GitHubReleaseGateway _gateway;
  final String _currentVersion;
  final UpdatePlatform _platform;
  final MacOSArchitecture? _macosArchitecture;

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
    UpdatePlatform.macos => assetName.endsWith(
      '-macos-${(_macosArchitecture ?? _currentMacOSArchitecture()).assetSuffix}.dmg',
    ),
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

  static MacOSArchitecture
  _currentMacOSArchitecture() => switch (Abi.current()) {
    Abi.macosArm64 => MacOSArchitecture.arm64,
    Abi.macosX64 => MacOSArchitecture.x86_64,
    final architecture => throw UnsupportedError(
      'Updates are unavailable for unsupported macOS architecture: $architecture.',
    ),
  };
}
