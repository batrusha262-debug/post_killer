enum UpdatePlatform { macos, windows, linux }

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUri,
    required this.assetName,
  });

  final String version;
  final Uri downloadUri;
  final String assetName;
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateIsCurrent extends UpdateCheckResult {
  const UpdateIsCurrent();
}

class UpdateIsAvailable extends UpdateCheckResult {
  const UpdateIsAvailable(this.update);
  final AppUpdate update;
}

/// Compares stable `major.minor.patch` release tags such as `v0.1.7`.
/// Unknown/prerelease tags are intentionally not offered as an update.
bool isNewerStableVersion(String candidate, String current) {
  List<int>? parse(String version) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  final candidateParts = parse(candidate);
  final currentParts = parse(current);
  if (candidateParts == null || currentParts == null) return false;
  for (var index = 0; index < candidateParts.length; index += 1) {
    if (candidateParts[index] != currentParts[index]) {
      return candidateParts[index] > currentParts[index];
    }
  }
  return false;
}
