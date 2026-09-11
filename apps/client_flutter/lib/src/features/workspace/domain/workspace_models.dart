const _unchanged = Object();

enum HttpMethod { get, post, put, patch, delete, head, options }

enum RequestBodyFormat { json, text, formUrlEncoded, multipart }

enum WorkspaceSection { collections, history, variables }

/// Credentials belong only to an open draft and are never persisted or added
/// to request history.
enum RequestAuthKind { none, basic, bearer, apiKey }

enum ApiKeyPlacement { header, query }

class RequestAuth {
  const RequestAuth({
    this.kind = RequestAuthKind.none,
    this.username = '',
    this.password = '',
    this.token = '',
    this.key = '',
    this.value = '',
    this.placement = ApiKeyPlacement.header,
    this.loginRequestId,
    this.tokenPath = 'access_token',
    this.acquiredToken,
  });

  final RequestAuthKind kind;
  final String username;
  final String password;
  final String token;
  final String key;
  final String value;
  final ApiKeyPlacement placement;

  /// A saved request that is run immediately before this one to obtain a token.
  final String? loginRequestId;

  /// Dot path in the login JSON response, e.g. `data.accessToken`.
  final String tokenPath;

  /// Runtime-only token. It is never saved as part of a request definition.
  final String? acquiredToken;

  bool get isValid => switch (kind) {
    RequestAuthKind.none => true,
    RequestAuthKind.basic => username.trim().isNotEmpty && password.isNotEmpty,
    RequestAuthKind.bearer =>
      token.trim().isNotEmpty || loginRequestId?.trim().isNotEmpty == true,
    RequestAuthKind.apiKey => key.trim().isNotEmpty && value.isNotEmpty,
  };

  RequestAuth copyWith({
    RequestAuthKind? kind,
    String? username,
    String? password,
    String? token,
    String? key,
    String? value,
    ApiKeyPlacement? placement,
    Object? loginRequestId = _unchanged,
    String? tokenPath,
    Object? acquiredToken = _unchanged,
  }) => RequestAuth(
    kind: kind ?? this.kind,
    username: username ?? this.username,
    password: password ?? this.password,
    token: token ?? this.token,
    key: key ?? this.key,
    value: value ?? this.value,
    placement: placement ?? this.placement,
    loginRequestId: identical(loginRequestId, _unchanged)
        ? this.loginRequestId
        : loginRequestId as String?,
    tokenPath: tokenPath ?? this.tokenPath,
    acquiredToken: identical(acquiredToken, _unchanged)
        ? this.acquiredToken
        : acquiredToken as String?,
  );
}

extension HttpMethodLabel on HttpMethod {
  String get label => name.toUpperCase();
}

class SavedRequest {
  const SavedRequest({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
    this.query = const [],
    this.headers = const [],
    this.body = '',
    this.bodyFormat = RequestBodyFormat.json,
    this.bodyFields = const [],
    this.bodyFiles = const [],
  });

  final String id;
  final String name;
  final HttpMethod method;
  final String url;
  final List<RequestKeyValue> query;
  final List<RequestKeyValue> headers;
  final String body;
  final RequestBodyFormat bodyFormat;
  final List<RequestKeyValue> bodyFields;
  final List<MultipartFileReference> bodyFiles;
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
    this.headers = const [
      RequestKeyValue(
        id: 'header-accept',
        key: 'Accept',
        value: 'application/json',
      ),
    ],
    this.body = '',
    this.bodyFormat = RequestBodyFormat.json,
    this.bodyFields = const [],
    this.bodyFiles = const [],
    this.auth = const RequestAuth(),
    this.isDirty = false,
  });

  factory RequestTab.fromSaved(SavedRequest request) => RequestTab(
    id: request.id,
    title: request.name,
    method: request.method,
    url: request.url,
    query: request.query,
    headers: request.headers.isEmpty
        ? const [
            RequestKeyValue(
              id: 'header-accept',
              key: 'Accept',
              value: 'application/json',
            ),
          ]
        : request.headers,
    body: request.body,
    bodyFormat: request.bodyFormat,
    bodyFields: request.bodyFields,
    bodyFiles: request.bodyFiles,
  );

  final String id;
  final String title;
  final HttpMethod method;
  final String url;
  final List<RequestKeyValue> query;
  final List<RequestKeyValue> headers;
  final String body;
  final RequestBodyFormat bodyFormat;
  final List<RequestKeyValue> bodyFields;
  final List<MultipartFileReference> bodyFiles;
  final RequestAuth auth;
  final bool isDirty;

  RequestTab copyWith({
    String? title,
    HttpMethod? method,
    String? url,
    List<RequestKeyValue>? query,
    List<RequestKeyValue>? headers,
    String? body,
    RequestBodyFormat? bodyFormat,
    List<RequestKeyValue>? bodyFields,
    List<MultipartFileReference>? bodyFiles,
    RequestAuth? auth,
    bool? isDirty,
  }) => RequestTab(
    id: id,
    title: title ?? this.title,
    method: method ?? this.method,
    url: url ?? this.url,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    bodyFormat: bodyFormat ?? this.bodyFormat,
    bodyFields: bodyFields ?? this.bodyFields,
    bodyFiles: bodyFiles ?? this.bodyFiles,
    auth: auth ?? this.auth,
    isDirty: isDirty ?? this.isDirty,
  );
}

class RequestHistoryEntry {
  const RequestHistoryEntry({
    required this.id,
    required this.requestId,
    required this.title,
    required this.method,
    required this.executedAt,
    required this.result,
    this.status,
    required this.durationMillis,
    required this.responseSizeBytes,
    this.errorCategory,
  });

  final String id;
  final String requestId;
  final String title;
  final HttpMethod method;
  final DateTime executedAt;
  final ExecutionHistoryResult result;
  final int? status;
  final int durationMillis;
  final int responseSizeBytes;
  final ExecutionHistoryErrorCategory? errorCategory;
}

/// Explicit local attachment reference used only for multipart execution.
/// The path is never copied into execution history or collection exports.
class MultipartFileReference {
  const MultipartFileReference({
    required this.fieldName,
    required this.path,
    this.fileName,
    this.contentType,
  });

  final String fieldName;
  final String path;
  final String? fileName;
  final String? contentType;
}

enum ExecutionHistoryResult { response, error, cancelled }

enum ExecutionHistoryErrorCategory {
  timeout,
  dns,
  connection,
  tls,
  proxy,
  redirect,
  requestBody,
  responseBody,
  other,
}

/// Record that crosses the repository boundary. It intentionally contains no
/// request URL, payload, header, cookie, credential or raw error message.
class StoredExecutionHistoryRecord {
  const StoredExecutionHistoryRecord({
    required this.id,
    required this.requestId,
    required this.executedAt,
    required this.result,
    this.status,
    required this.durationMillis,
    required this.responseSizeBytes,
    this.errorCategory,
  });

  final String id;
  final String requestId;
  final DateTime executedAt;
  final ExecutionHistoryResult result;
  final int? status;
  final int durationMillis;
  final int responseSizeBytes;
  final ExecutionHistoryErrorCategory? errorCategory;
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

/// A named local variable set. Secret storage will be introduced behind this
/// model later; values are never copied to request history.
class WorkspaceEnvironment {
  const WorkspaceEnvironment({
    required this.id,
    required this.name,
    this.variables = const [],
  });

  final String id;
  final String name;
  final List<RequestKeyValue> variables;

  WorkspaceEnvironment copyWith({
    String? name,
    List<RequestKeyValue>? variables,
  }) => WorkspaceEnvironment(
    id: id,
    name: name ?? this.name,
    variables: variables ?? this.variables,
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
    this.historySearchQuery = '',
    this.isExecuting = false,
    this.execution,
    this.isLoading = false,
    this.storageError,
    this.history = const [],
    this.environments = const [],
    this.selectedEnvironmentId,
  });

  final List<WorkspaceSummary> workspaces;
  final String? selectedWorkspaceId;
  final List<RequestCollection> collections;
  final List<RequestTab> tabs;
  final String? selectedTabId;
  final WorkspaceSection selectedSection;
  final String collectionSearchQuery;
  final String historySearchQuery;
  final bool isExecuting;
  final RequestExecutionView? execution;
  final bool isLoading;
  final String? storageError;
  final List<RequestHistoryEntry> history;
  final List<WorkspaceEnvironment> environments;
  final String? selectedEnvironmentId;

  WorkspaceEnvironment? get selectedEnvironment {
    for (final environment in environments) {
      if (environment.id == selectedEnvironmentId) return environment;
    }
    return null;
  }

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

  List<RequestHistoryEntry> get filteredHistory {
    final query = historySearchQuery.trim().toLowerCase();
    if (query.isEmpty) return history;
    return [
      for (final entry in history)
        if ('${entry.method.label} ${entry.title}'.toLowerCase().contains(
          query,
        ))
          entry,
    ];
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
    String? historySearchQuery,
    bool? isExecuting,
    Object? execution = _unchanged,
    bool? isLoading,
    Object? storageError = _unchanged,
    List<RequestHistoryEntry>? history,
    List<WorkspaceEnvironment>? environments,
    Object? selectedEnvironmentId = _unchanged,
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
    historySearchQuery: historySearchQuery ?? this.historySearchQuery,
    isExecuting: isExecuting ?? this.isExecuting,
    execution: identical(execution, _unchanged)
        ? this.execution
        : execution as RequestExecutionView?,
    isLoading: isLoading ?? this.isLoading,
    storageError: identical(storageError, _unchanged)
        ? this.storageError
        : storageError as String?,
    history: history ?? this.history,
    environments: environments ?? this.environments,
    selectedEnvironmentId: identical(selectedEnvironmentId, _unchanged)
        ? this.selectedEnvironmentId
        : selectedEnvironmentId as String?,
  );
}
