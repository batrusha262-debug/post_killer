import 'package:client_flutter/src/features/updates/data/github_release_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('private or unpublished release gives an actionable error', () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    addTearDown(client.close);
    await expectLater(
      HttpGitHubReleaseGateway(client).fetchLatestRelease(),
      throwsA(
        isA<UpdateLookupException>().having(
          (error) => error.message,
          'message',
          contains('входа в GitHub'),
        ),
      ),
    );
  });
  test('rate limit gives an actionable error', () async {
    final client = MockClient((_) async => http.Response('{}', 403));
    addTearDown(client.close);
    await expectLater(
      HttpGitHubReleaseGateway(client).fetchLatestRelease(),
      throwsA(
        isA<UpdateLookupException>().having(
          (error) => error.message,
          'message',
          contains('ограничил'),
        ),
      ),
    );
  });
}
