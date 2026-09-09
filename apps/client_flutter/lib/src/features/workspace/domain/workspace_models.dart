enum HttpMethod { get, post, put, patch, delete }

enum WorkspaceSection { collections, history, variables }

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

class RequestExecutionView {
  const RequestExecutionView._({
    required this.status,
    required this.durationMillis,
    required this.body,
    required this.error,
  });

  factory RequestExecutionView.response({
    required int status,
    required int durationMillis,
    required String body,
  }) => RequestExecutionView._(
    status: status,
    durationMillis: durationMillis,
    body: body,
    error: null,
  );

  factory RequestExecutionView.error(String error) => RequestExecutionView._(
    status: null,
    durationMillis: null,
    body: null,
    error: error,
  );

  final int? status;
  final int? durationMillis;
  final String? body;
  final String? error;
}

class WorkspaceState {
  const WorkspaceState({
    required this.collections,
    required this.tabs,
    required this.selectedTabId,
    this.selectedSection = WorkspaceSection.collections,
    this.collectionSearchQuery = '',
    this.isExecuting = false,
    this.execution,
  });

  final List<RequestCollection> collections;
  final List<RequestTab> tabs;
  final String? selectedTabId;
  final WorkspaceSection selectedSection;
  final String collectionSearchQuery;
  final bool isExecuting;
  final RequestExecutionView? execution;

  /// A derived view so searching never replaces the repository-backed source.
  List<RequestCollection> get filteredCollections {
    final query = collectionSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return collections;
    return [
      for (final collection in collections)
        if (collection.name.toLowerCase().contains(query))
          collection
        else
          RequestCollection(
            id: collection.id,
            name: collection.name,
            requests: [
              for (final request in collection.requests)
                if (request.name.toLowerCase().contains(query)) request,
            ],
          ),
    ].where((collection) => collection.requests.isNotEmpty).toList();
  }

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
    WorkspaceSection? selectedSection,
    String? collectionSearchQuery,
    bool? isExecuting,
    RequestExecutionView? execution,
  }) => WorkspaceState(
    collections: collections ?? this.collections,
    tabs: tabs ?? this.tabs,
    selectedTabId: selectedTabId ?? this.selectedTabId,
    selectedSection: selectedSection ?? this.selectedSection,
    collectionSearchQuery: collectionSearchQuery ?? this.collectionSearchQuery,
    isExecuting: isExecuting ?? this.isExecuting,
    execution: execution ?? this.execution,
  );
}
