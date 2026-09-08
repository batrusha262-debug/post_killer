enum HttpMethod { get, post, put, patch, delete }

extension HttpMethodLabel on HttpMethod {
  String get label => name.toUpperCase();
}

class SavedRequest {
  const SavedRequest({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
  });

  final String id;
  final String name;
  final HttpMethod method;
  final String url;
}

class RequestCollection {
  const RequestCollection({
    required this.id,
    required this.name,
    required this.requests,
  });

  final String id;
  final String name;
  final List<SavedRequest> requests;
}

class RequestTab {
  const RequestTab({
    required this.id,
    required this.title,
    required this.method,
    required this.url,
    this.query = const [],
    this.headers = const [],
    this.body = '',
    this.isDirty = false,
  });

  factory RequestTab.fromSaved(SavedRequest request) => RequestTab(
    id: request.id,
    title: request.name,
    method: request.method,
    url: request.url,
  );

  final String id;
  final String title;
  final HttpMethod method;
  final String url;
  final List<RequestKeyValue> query;
  final List<RequestKeyValue> headers;
  final String body;
  final bool isDirty;

  RequestTab copyWith({
    String? title,
    HttpMethod? method,
    String? url,
    List<RequestKeyValue>? query,
    List<RequestKeyValue>? headers,
    String? body,
    bool? isDirty,
  }) => RequestTab(
    id: id,
    title: title ?? this.title,
    method: method ?? this.method,
    url: url ?? this.url,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    isDirty: isDirty ?? this.isDirty,
  );
}

class RequestKeyValue {
  const RequestKeyValue({
    required this.id,
    this.key = '',
    this.value = '',
    this.enabled = true,
  });

  final String id;
  final String key;
  final String value;
  final bool enabled;

  RequestKeyValue copyWith({String? key, String? value, bool? enabled}) =>
      RequestKeyValue(
        id: id,
        key: key ?? this.key,
        value: value ?? this.value,
        enabled: enabled ?? this.enabled,
      );
}

class WorkspaceState {
  const WorkspaceState({
    required this.collections,
    required this.tabs,
    required this.selectedTabId,
  });

  final List<RequestCollection> collections;
  final List<RequestTab> tabs;
  final String? selectedTabId;

  RequestTab? get selectedTab {
    for (final tab in tabs) {
      if (tab.id == selectedTabId) return tab;
    }
    return null;
  }

  WorkspaceState copyWith({
    List<RequestCollection>? collections,
    List<RequestTab>? tabs,
    String? selectedTabId,
  }) => WorkspaceState(
    collections: collections ?? this.collections,
    tabs: tabs ?? this.tabs,
    selectedTabId: selectedTabId ?? this.selectedTabId,
  );
}
