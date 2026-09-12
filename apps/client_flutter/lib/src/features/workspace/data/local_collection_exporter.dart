import 'dart:convert';

import '../domain/workspace_models.dart';

/// Versioned interchange format for a local collection. It serializes saved
/// request definitions only; runtime responses, history, environments and
/// draft-only authentication never enter the export.
class LocalCollectionExporter {
  const LocalCollectionExporter._();

  static String encode(RequestCollection collection) =>
      const JsonEncoder.withIndent('  ').convert({
        'schema': 'post-killer.collection/v1',
        'name': collection.name,
        'requests': [
          for (final request in collection.requests) _request(request),
        ],
      });

  static Map<String, Object?> _request(SavedRequest request) => {
    'id': request.id,
    'name': request.name,
    'method': request.method.label,
    'url': request.url,
    'query': _values(request.query),
    // User-entered Authorization/cookie/API-key headers are omitted rather
    // than copied into a portable file. Auth editor values are draft-only.
    'headers': _values(
      request.headers.where((value) => !_sensitive(value.key)),
    ),
    'body': {
      'format': request.bodyFormat.name,
      'content': _redactBody(request.body, request.bodyFormat),
      'fields': _values(request.bodyFields),
    },
  };

  static List<Map<String, Object>> _values(Iterable<RequestKeyValue> values) =>
      [
        for (final value in values)
          if (!_sensitive(value.key))
            {'key': value.key, 'value': value.value, 'enabled': value.enabled},
      ];

  static bool _sensitive(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'authorization' ||
        normalized == 'cookie' ||
        normalized == 'set-cookie' ||
        normalized == 'x-api-key' ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('api_key') ||
        normalized.contains('api-key') ||
        normalized.contains('apikey') ||
        normalized.contains('credential');
  }

  /// JSON request bodies frequently contain a password or token field. Keep
  /// the shape of the example while replacing known credential values before a
  /// portable collection file is written. Unstructured text is left unchanged
  /// because it has no reliable key/value boundary to redact safely.
  static String _redactBody(String content, RequestBodyFormat format) {
    if (content.isEmpty || format != RequestBodyFormat.json) return content;
    try {
      return jsonEncode(_redactJson(jsonDecode(content)));
    } on FormatException {
      return content;
    }
  }

  static Object? _redactJson(Object? value, {String? key}) {
    if (key != null && _sensitive(key)) return '<redacted>';
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _redactJson(
            entry.value,
            key: entry.key.toString(),
          ),
      };
    }
    if (value is List) {
      return [for (final item in value) _redactJson(item)];
    }
    return value;
  }
}
