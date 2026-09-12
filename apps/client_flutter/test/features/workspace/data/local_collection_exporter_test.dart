import 'dart:convert';

import 'package:client_flutter/src/features/workspace/data/local_collection_exporter.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports saved definitions but redacts sensitive values', () {
    final exported = jsonDecode(
      LocalCollectionExporter.encode(
        const RequestCollection(
          id: 'collection',
          name: 'Secure API',
          requests: [
            SavedRequest(
              id: 'request',
              name: 'List',
              method: HttpMethod.get,
              url: 'https://api.example.test/items',
              headers: [
                RequestKeyValue(
                  key: 'Accept',
                  value: 'application/json',
                  id: 'a',
                ),
                RequestKeyValue(
                  key: 'Authorization',
                  value: 'Bearer secret',
                  id: 'b',
                ),
              ],
              query: [
                RequestKeyValue(key: 'page', value: '1', id: 'c'),
                RequestKeyValue(key: 'access_token', value: 'secret', id: 'd'),
              ],
              bodyFormat: RequestBodyFormat.json,
              body: '{"username":"ada","password":"hidden","nested":{"access_token":"also-hidden"}}',
            ),
          ],
        ),
      ),
    ) as Map<String, dynamic>;

    final request =
        (exported['requests'] as List).single as Map<String, dynamic>;
    expect(exported['schema'], 'post-killer.collection/v1');
    expect(request['headers'], [
      {'key': 'Accept', 'value': 'application/json', 'enabled': true},
    ]);
    expect(request['query'], [
      {'key': 'page', 'value': '1', 'enabled': true},
    ]);
    expect(
      jsonDecode(
        (request['body'] as Map<String, dynamic>)['content'] as String,
      ),
      {
        'username': 'ada',
        'password': '<redacted>',
        'nested': {'access_token': '<redacted>'},
      },
    );
  });
}
