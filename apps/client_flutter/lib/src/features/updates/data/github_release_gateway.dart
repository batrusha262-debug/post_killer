import 'dart:convert';

import 'package:http/http.dart' as http;

class ReleaseAssetPayload {
  const ReleaseAssetPayload({required this.name, required this.downloadUrl});

  final String name;
  final Uri downloadUrl;
}

class LatestReleasePayload {
  const LatestReleasePayload({required this.version, required this.assets});

  final String version;
  final List<ReleaseAssetPayload> assets;
}

abstract interface class GitHubReleaseGateway {
  Future<LatestReleasePayload> fetchLatestRelease();
}

class HttpGitHubReleaseGateway implements GitHubReleaseGateway {
  HttpGitHubReleaseGateway(this._client);

  static final Uri _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/batrusha262-debug/post_killer/releases/latest',
  );

  final http.Client _client;

  @override
  Future<LatestReleasePayload> fetchLatestRelease() async {
    final response = await _client
        .get(
          _latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const UpdateLookupException();
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const UpdateLookupException();
    }
    final tagName = payload['tag_name'];
    final assets = payload['assets'];
    if (tagName is! String || assets is! List) {
      throw const UpdateLookupException();
    }

    return LatestReleasePayload(
      version: tagName,
      assets: [
        for (final asset in assets)
          if (asset case {
            'name': final String name,
            'browser_download_url': final String url,
          })
            ReleaseAssetPayload(name: name, downloadUrl: Uri.parse(url)),
      ],
    );
  }
}

class UpdateLookupException implements Exception {
  const UpdateLookupException();
}
