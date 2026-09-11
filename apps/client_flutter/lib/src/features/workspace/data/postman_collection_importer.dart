import 'dart:convert';

import '../domain/workspace_models.dart';

/// A deliberately small, tolerant reader for the Postman Collection v2 format.
/// It keeps imported data local and preserves the request details that can be
/// represented by the current editor.
class PostmanCollectionImport {
  const PostmanCollectionImport({required this.name, required this.requests});

  final String name;
  final List<SavedRequest> requests;

  factory PostmanCollectionImport.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['item'] is! List) {
      throw const FormatException('Это не коллекция Postman v2.');
    }
    final info = decoded['info'];
    final name =
        info is Map &&
            info['name'] is String &&
            (info['name'] as String).trim().isNotEmpty
        ? (info['name'] as String).trim()
        : 'Imported Postman collection';
    final requests = <SavedRequest>[];
    var index = 0;

    void visit(List<dynamic> items, [String prefix = '']) {
      for (final item in items) {
        if (item is! Map) continue;
        final itemName =
            item['name'] is String && (item['name'] as String).trim().isNotEmpty
            ? (item['name'] as String).trim()
            : 'Untitled request';
        final childItems = item['item'];
        if (childItems is List) {
          visit(childItems, '$prefix$itemName / ');
          continue;
        }
        final request = item['request'];
        if (request is! Map) continue;
        index += 1;
        requests.add(
          _requestFromPostman(
            request: request.cast<String, dynamic>(),
            id: 'postman-${DateTime.now().microsecondsSinceEpoch}-$index',
            name: '$prefix$itemName',
          ),
        );
      }
    }

    visit(decoded['item'] as List<dynamic>);
    if (requests.isEmpty) {
      throw const FormatException('В этой коллекции не найдено HTTP-запросов.');
    }
    return PostmanCollectionImport(name: name, requests: requests);
  }

  static SavedRequest _requestFromPostman({
    required Map<String, dynamic> request,
    required String id,
    required String name,
  }) {
    final url = _url(request['url']);
    final headers = _keyValues(request['header'], 'header');
    final body = request['body'] is Map
        ? (request['body'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final raw = body['raw'] is String ? body['raw'] as String : '';
    final isJson =
        body['options'] is Map &&
        ((body['options'] as Map)['raw'] is Map) &&
        (((body['options'] as Map)['raw'] as Map)['language'] == 'json');
    return SavedRequest(
      id: id,
      name: name,
      method: _method(request['method']),
      url: url.url,
      query: url.query,
      headers: headers,
      body: raw,
      bodyFormat:
          isJson ||
              headers.any(
                (header) =>
                    header.key.toLowerCase() == 'content-type' &&
                    header.value.toLowerCase().contains('json'),
              )
          ? RequestBodyFormat.json
          : RequestBodyFormat.text,
    );
  }

  static HttpMethod _method(Object? value) =>
      switch ((value as String? ?? 'GET').toUpperCase()) {
        'POST' => HttpMethod.post,
        'PUT' => HttpMethod.put,
        'PATCH' => HttpMethod.patch,
        'DELETE' => HttpMethod.delete,
        _ => HttpMethod.get,
      };

  static ({String url, List<RequestKeyValue> query}) _url(Object? source) {
    if (source is String) {
      final uri = Uri.tryParse(source);
      return (
        // Query entries are handed to the transport separately. Removing them
        // here prevents an imported `?page=1` from being sent twice.
        url: uri == null || !uri.hasQuery ? source : _withoutQuery(source),
        query: uri == null
            ? const []
            : [
                for (final entry in uri.queryParameters.entries)
                  RequestKeyValue(
                    id: 'query-${entry.key}-${entry.value}',
                    key: entry.key,
                    value: entry.value,
                  ),
              ],
      );
    }
    if (source is! Map) return (url: '', query: const []);
    final raw = source['raw'];
    final query = _keyValues(source['query'], 'query');
    if (raw is String && raw.isNotEmpty) {
      final uri = Uri.tryParse(raw);
      return (
        url: uri == null || !uri.hasQuery ? raw : _withoutQuery(raw),
        query: query.isEmpty && uri != null
            ? [
                for (final entry in uri.queryParameters.entries)
                  RequestKeyValue(
                    id: 'query-${entry.key}-${entry.value}',
                    key: entry.key,
                    value: entry.value,
                  ),
              ]
            : query,
      );
    }
    final protocol = source['protocol'] is String
        ? '${source['protocol']}://'
        : '';
    final host = source['host'] is List
        ? (source['host'] as List).join('.')
        : '';
    final path = source['path'] is List
        ? (source['path'] as List).join('/')
        : '';
    return (url: '$protocol$host${path.isEmpty ? '' : '/$path'}', query: query);
  }

  static String _withoutQuery(String url) {
    final queryStart = url.indexOf('?');
    if (queryStart == -1) return url;
    final fragmentStart = url.indexOf('#', queryStart);
    return fragmentStart == -1
        ? url.substring(0, queryStart)
        : '${url.substring(0, queryStart)}${url.substring(fragmentStart)}';
  }

  static List<RequestKeyValue> _keyValues(Object? source, String prefix) {
    if (source is! List) return const [];
    return [
      for (var index = 0; index < source.length; index++)
        if (source[index] is Map)
          RequestKeyValue(
            id: '$prefix-$index',
            key: (source[index] as Map)['key'] as String? ?? '',
            value: (source[index] as Map)['value']?.toString() ?? '',
            enabled: (source[index] as Map)['disabled'] != true,
          ),
    ];
  }
}
