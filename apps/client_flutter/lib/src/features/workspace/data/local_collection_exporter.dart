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
      'content': request.body,
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
        normalized.contains('password');
  }
}
