import 'package:client_flutter/src/features/workspace/data/postman_collection_importer.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports nested Postman v2 requests and preserves request details', () {
    final collection = PostmanCollectionImport.parse('''
      {"info":{"name":"Example API"},"item":[
        {"name":"Auth","item":[{"name":"Login","request":{
          "method":"POST","url":{"raw":"https://api.test/login?dry=true","query":[{"key":"dry","value":"true"}]},
          "header":[{"key":"Content-Type","value":"application/json"}],
          "body":{"mode":"raw","raw":"{\\"email\\":\\"a@test.dev\\"}","options":{"raw":{"language":"json"}}}
        }}]}
      ]}
    ''');

    expect(collection.name, 'Example API');
    final request = collection.requests.single;
    expect(request.name, 'Auth / Login');
    expect(request.method, HttpMethod.post);
    expect(request.url, 'https://api.test/login');
    expect(request.headers.single.key, 'Content-Type');
    expect(request.query.single.key, 'dry');
    expect(request.bodyFormat, RequestBodyFormat.json);
  });

  test('rejects JSON that is not a Postman collection', () {
    expect(
      () => PostmanCollectionImport.parse('{"openapi":"3.0.0"}'),
      throwsFormatException,
    );
  });
}
