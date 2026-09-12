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

  test('imports urlencoded fields and HEAD requests', () {
    final collection = PostmanCollectionImport.parse('''
      {"info":{"name":"OAuth"},"item":[{
        "name":"Get token","request":{
          "method":"HEAD","url":"https://api.example.test/token",
          "body":{"mode":"urlencoded","urlencoded":[
            {"key":"grant_type","value":"client_credentials"}
          ]}
        }
      }]}
    ''');

    final request = collection.requests.single;
    expect(request.method, HttpMethod.head);
    expect(request.bodyFormat, RequestBodyFormat.formUrlEncoded);
    expect(request.bodyFields.single.key, 'grant_type');
    expect(request.bodyFields.single.value, 'client_credentials');
  });

  test(
    'imports Postman multipart text and local file references separately',
    () {
      final collection = PostmanCollectionImport.parse('''
      {"info":{"name":"Upload"},"item":[{
        "name":"Attach report","request":{
          "method":"POST","url":"https://api.example.test/upload",
          "body":{"mode":"formdata","formdata":[
            {"key":"title","value":"September report","type":"text"},
            {"key":"attachment","type":"file","src":"/tmp/report.pdf","contentType":"application/pdf"}
          ]}
        }
      }]}
    ''');

      final request = collection.requests.single;
      expect(request.bodyFormat, RequestBodyFormat.multipart);
      expect(request.bodyFields, hasLength(1));
      expect(request.bodyFields.single.key, 'title');
      expect(request.bodyFiles, hasLength(1));
      expect(request.bodyFiles.single.fieldName, 'attachment');
      expect(request.bodyFiles.single.path, '/tmp/report.pdf');
      expect(request.bodyFiles.single.fileName, 'report.pdf');
      expect(request.bodyFiles.single.contentType, 'application/pdf');
    },
  );

  test('skips unfinished Postman drafts without blocking valid requests', () {
    final collection = PostmanCollectionImport.parse('''
      {"info":{"name":"FAQ"},"item":[
        {"name":"New Request","request":{"method":"GET","header":[]}},
        {"name":"FAQ PDF","request":{"method":"GET","url":{
          "raw":"http://localhost:3000/home/v1/faq/pdf?rowID=2",
          "query":[{"key":"rowID","value":"2"}]}}},
        {"name":"Another draft","request":{"method":"POST"}}
      ]}
    ''');

    expect(collection.name, 'FAQ');
    expect(collection.requests, hasLength(1));
    expect(
      collection.requests.single.url,
      'http://localhost:3000/home/v1/faq/pdf',
    );
    expect(collection.requests.single.query.single.value, '2');
  });
}
