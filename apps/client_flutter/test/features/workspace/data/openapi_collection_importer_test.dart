import 'package:client_flutter/src/features/workspace/data/openapi_collection_importer.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports OpenAPI YAML without downloading refs or running requests', () {
    const source = '''
openapi: 3.1.0
info:
  title: Pet service
servers:
  - url: https://api.example.test/{version}
    variables:
      version:
        default: v1
paths:
  /pets/{petId}:
    parameters:
      - name: petId
        in: path
        schema:
          default: 42
    get:
      summary: Get pet
      parameters:
        - name: include
          in: query
          schema:
            default: owner
        - name: X-Trace
          in: header
          example: trace-1
    post:
      operationId: createPet
      requestBody:
        content:
          application/json:
            example:
              name: Miso
''';

    final imported = OpenApiCollectionImport.parse(source);

    expect(imported.name, 'Pet service');
    expect(imported.requests, hasLength(2));
    final get = imported.requests.first;
    expect(get.method, HttpMethod.get);
    expect(get.url, 'https://api.example.test/v1/pets/42');
    expect(get.query.single.key, 'include');
    expect(get.query.single.value, 'owner');
    expect(get.headers.single.key, 'X-Trace');
    final post = imported.requests.last;
    expect(post.name, 'createPet');
    expect(post.body, '{"name":"Miso"}');
    expect(post.headers.last.value, 'application/json');
  });

  test('rejects OpenAPI 2 documents', () {
    expect(
      () => OpenApiCollectionImport.parse('{"swagger":"2.0","paths":{}}'),
      throwsFormatException,
    );
  });
}
