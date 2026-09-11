import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../domain/workspace_models.dart';

/// Offline OpenAPI 3.0/3.1 reader. It accepts JSON and YAML but never resolves
/// remote `$ref` values, downloads specifications, or executes an operation.
class OpenApiCollectionImport {
  const OpenApiCollectionImport({required this.name, required this.requests});

  final String name;
  final List<SavedRequest> requests;

  factory OpenApiCollectionImport.parse(String source) {
    final document = loadYaml(source);
    if (document is! Map || document['openapi'] is! String) {
      throw const FormatException('Это не OpenAPI 3.0/3.1 specification.');
    }
    final version = document['openapi'] as String;
    if (!version.startsWith('3.0') && !version.startsWith('3.1')) {
      throw const FormatException('Поддерживается только OpenAPI 3.0 или 3.1.');
    }
    final paths = document['paths'];
    if (paths is! Map) {
      throw const FormatException('В OpenAPI specification отсутствует paths.');
    }
    final title = _text((document['info'] as Map?)?['title']);
    final baseUrl = _serverUrl(document['servers']);
    final requests = <SavedRequest>[];
    var index = 0;

    for (final pathEntry in paths.entries) {
      if (pathEntry.key is! String || pathEntry.value is! Map) continue;
      final path = pathEntry.key as String;
      final pathItem = pathEntry.value as Map;
      for (final operationEntry in pathItem.entries) {
        if (operationEntry.key is! String || operationEntry.value is! Map) {
          continue;
        }
        final method = _method(operationEntry.key as String);
        if (method == null) continue;
        final operation = operationEntry.value as Map;
        index += 1;
        requests.add(
          _request(
            id: 'openapi-${DateTime.now().microsecondsSinceEpoch}-$index',
            method: method,
            path: path,
            baseUrl: baseUrl,
            pathParameters: pathItem['parameters'],
            operation: operation,
          ),
        );
      }
    }
    if (requests.isEmpty) {
      throw const FormatException(
        'В OpenAPI specification нет HTTP operations.',
      );
    }
    return OpenApiCollectionImport(
      name: title.isEmpty ? 'Imported OpenAPI collection' : title,
      requests: requests,
    );
  }

  static SavedRequest _request({
    required String id,
    required HttpMethod method,
    required String path,
    required String baseUrl,
    required Object? pathParameters,
    required Map operation,
  }) {
    var resolvedPath = path;
    final query = <RequestKeyValue>[];
    final headers = <RequestKeyValue>[];
    final parameters = [
      if (pathParameters is List) ...pathParameters,
      if (operation['parameters'] is List) ...(operation['parameters'] as List),
    ];
    for (var index = 0; index < parameters.length; index++) {
      final parameter = parameters[index];
      if (parameter is! Map) continue;
      final name = _text(parameter['name']);
      final location = _text(parameter['in']);
      if (name.isEmpty || location.isEmpty) continue;
      final value = _parameterValue(parameter);
      switch (location) {
        case 'path':
          resolvedPath = resolvedPath.replaceAll('{$name}', value);
        case 'query':
          query.add(
            RequestKeyValue(id: 'query-$index-$name', key: name, value: value),
          );
        case 'header':
          headers.add(
            RequestKeyValue(id: 'header-$index-$name', key: name, value: value),
          );
      }
    }
    final body = _body(operation['requestBody']);
    final title = _text(operation['summary']).isNotEmpty
        ? _text(operation['summary'])
        : (_text(operation['operationId']).isNotEmpty
              ? _text(operation['operationId'])
              : '${method.label} $path');
    return SavedRequest(
      id: id,
      name: title,
      method: method,
      url: '$baseUrl$resolvedPath',
      query: query,
      headers: body.contentType == null
          ? headers
          : [
              ...headers,
              RequestKeyValue(
                id: 'header-content-type',
                key: 'Content-Type',
                value: body.contentType!,
              ),
            ],
      body: body.content,
      bodyFormat: body.format,
    );
  }

  static ({String content, RequestBodyFormat format, String? contentType})
  _body(Object? source) {
    if (source is! Map || source['content'] is! Map) {
      return (content: '', format: RequestBodyFormat.json, contentType: null);
    }
    final content = source['content'] as Map;
    final json = content['application/json'];
    if (json is Map) {
      final example = _example(json);
      return (
        content: example == null ? '{}' : jsonEncode(example),
        format: RequestBodyFormat.json,
        contentType: 'application/json',
      );
    }
    final text = content['text/plain'];
    if (text is Map) {
      final example = _example(text);
      return (
        content: example?.toString() ?? '',
        format: RequestBodyFormat.text,
        contentType: 'text/plain',
      );
    }
    return (content: '', format: RequestBodyFormat.json, contentType: null);
  }

  static Object? _example(Map media) {
    if (media.containsKey('example')) return media['example'];
    final examples = media['examples'];
    if (examples is Map) {
      for (final example in examples.values) {
        if (example is Map && example.containsKey('value')) {
          return example['value'];
        }
      }
    }
    final schema = media['schema'];
    return schema is Map && schema.containsKey('default')
        ? schema['default']
        : null;
  }

  static String _parameterValue(Map parameter) {
    if (parameter.containsKey('example')) {
      return parameter['example'].toString();
    }
    final schema = parameter['schema'];
    if (schema is Map && schema.containsKey('default')) {
      return schema['default'].toString();
    }
    return '{{${_text(parameter['name'])}}}';
  }

  static String _serverUrl(Object? source) {
    if (source is! List || source.isEmpty || source.first is! Map) {
      return '{{baseUrl}}';
    }
    final server = source.first as Map;
    var url = _text(server['url']);
    final variables = server['variables'];
    if (variables is Map) {
      for (final variable in variables.entries) {
        if (variable.key is! String || variable.value is! Map) continue;
        final value = _text((variable.value as Map)['default']);
        url = url.replaceAll(
          '{${variable.key}}',
          value.isEmpty ? '{{${variable.key}}}' : value,
        );
      }
    }
    return url.isEmpty ? '{{baseUrl}}' : url.replaceAll(RegExp(r'/$'), '');
  }

  static HttpMethod? _method(String value) => switch (value.toUpperCase()) {
    'GET' => HttpMethod.get,
    'POST' => HttpMethod.post,
    'PUT' => HttpMethod.put,
    'PATCH' => HttpMethod.patch,
    'DELETE' => HttpMethod.delete,
    'HEAD' => HttpMethod.head,
    'OPTIONS' => HttpMethod.options,
    _ => null,
  };

  static String _text(Object? value) => value is String ? value.trim() : '';
}
