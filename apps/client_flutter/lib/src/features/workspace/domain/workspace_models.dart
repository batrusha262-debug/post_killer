const _unchanged = Object();

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

class WorkspaceSummary {
  const WorkspaceSummary({required this.id, required this.name});

  final String id;
  final String name;
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
    required this.requestId,
    required this.status,
    required this.durationMillis,
    required this.headers,
    required this.body,
    required this.error,
  });

  factory RequestExecutionView.response({
    required String requestId,
    required int status,
    required int durationMillis,
    required List<RequestResponseHeader> headers,
    required String body,
  }) => RequestExecutionView._(
    requestId: requestId,
    status: status,
    durationMillis: durationMillis,
    headers: headers,
    body: body,
    error: null,
  );

  factory RequestExecutionView.error({
    required String requestId,
    required String error,
  }) => RequestExecutionView._(
    requestId: requestId,
    status: null,
    durationMillis: null,
    headers: const [],
    body: null,
    error: error,
  );

  final String requestId;
  final int? status;
  final int? durationMillis;
  final List<RequestResponseHeader> headers;
  final String? body;
  final String? error;
}

class RequestResponseHeader {
  const RequestResponseHeader({required this.name, required this.value});

  final String name;
  final String value;
}

class WorkspaceState {
  const WorkspaceState({
    this.workspaces = const [],
    this.selectedWorkspaceId,
    required this.collections,
    required this.tabs,
    required this.selectedTabId,
    this.selectedSection = WorkspaceSection.collections,
    this.collectionSearchQuery = '',
    this.isExecuting = false,
    this.execution,
    this.isLoading = false,
    this.storageError,
  });

  final List<WorkspaceSummary> workspaces;
  final String? selectedWorkspaceId;
  final List<RequestCollection> collections;
  final List<RequestTab> tabs;
  final String? selectedTabId;
  final WorkspaceSection selectedSection;
  final String collectionSearchQuery;
  final bool isExecuting;
  final RequestExecutionView? execution;
  final bool isLoading;
  final String? storageError;

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
        ]
        .where(
          (collection) =>
              collection.name.toLowerCase().contains(query) ||
              collection.requests.isNotEmpty,
        )
        .toList();
  }

  RequestTab? get selectedTab {
    for (final tab in tabs) {
      if (tab.id == selectedTabId) return tab;
    }
    return null;
  }

  /// A completed request belongs to exactly one tab, so switching tabs never
  /// leaks a prior response into the editor currently on screen.
  RequestExecutionView? get selectedExecution =>
      execution?.requestId == selectedTabId ? execution : null;

  WorkspaceState copyWith({
    List<WorkspaceSummary>? workspaces,
    Object? selectedWorkspaceId = _unchanged,
    List<RequestCollection>? collections,
    List<RequestTab>? tabs,
    Object? selectedTabId = _unchanged,
    WorkspaceSection? selectedSection,
    String? collectionSearchQuery,
    bool? isExecuting,
    Object? execution = _unchanged,
    bool? isLoading,
    Object? storageError = _unchanged,
  }) => WorkspaceState(
    workspaces: workspaces ?? this.workspaces,
    selectedWorkspaceId: identical(selectedWorkspaceId, _unchanged)
        ? this.selectedWorkspaceId
        : selectedWorkspaceId as String?,
    collections: collections ?? this.collections,
    tabs: tabs ?? this.tabs,
    selectedTabId: identical(selectedTabId, _unchanged)
        ? this.selectedTabId
        : selectedTabId as String?,
    selectedSection: selectedSection ?? this.selectedSection,
    collectionSearchQuery: collectionSearchQuery ?? this.collectionSearchQuery,
    isExecuting: isExecuting ?? this.isExecuting,
    execution: identical(execution, _unchanged)
        ? this.execution
        : execution as RequestExecutionView?,
    isLoading: isLoading ?? this.isLoading,
    storageError: identical(storageError, _unchanged)
        ? this.storageError
        : storageError as String?,
  );
}
