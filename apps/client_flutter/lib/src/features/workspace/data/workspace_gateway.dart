import '../domain/workspace_models.dart';
import '../../../rust/api.dart' as rust_api;

/// Lowest Flutter data-layer boundary. The production implementation will call
/// generated flutter_rust_bridge bindings; it must not expose SQLite or HTTP.
abstract interface class WorkspaceGateway {
  Future<List<WorkspaceSummary>> listWorkspaces();
  Future<WorkspaceSummary> createWorkspace(String name);
  Future<List<RequestCollection>> listCollections(String workspaceId);
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  });
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  });
}

class FrbWorkspaceGateway implements WorkspaceGateway {
  const FrbWorkspaceGateway();

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => [
    for (final workspace in await rust_api.listWorkspaces())
      WorkspaceSummary(id: workspace.id, name: workspace.name),
  ];

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async {
    final workspace = await rust_api.createWorkspace(name: name);
    return WorkspaceSummary(id: workspace.id, name: workspace.name);
  }

  @override
  Future<List<RequestCollection>> listCollections(String workspaceId) async {
    final collections = await rust_api.listCollections(
      workspaceId: workspaceId,
    );
    return [
      for (final collection in collections)
        RequestCollection(
          id: collection.id,
          name: collection.name,
          requests: [
            for (final saved in await rust_api.listRequests(
              collectionId: collection.id,
            ))
              _savedRequest(saved.request),
          ],
        ),
    ];
  }

  @override
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  }) async {
    final collection = await rust_api.createCollection(
      workspaceId: workspaceId,
      name: name,
    );
    return RequestCollection(
      id: collection.id,
      name: collection.name,
      requests: const [],
    );
  }

  @override
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  }) async => _savedRequest(
    (await rust_api.saveRequest(
      collectionId: collectionId,
      request: _ffiRequest(request),
    )).request,
  );

  SavedRequest _savedRequest(rust_api.FfiRequest request) => SavedRequest(
    id: request.id,
    name: request.name,
    method: _methodFromFfi(request.method),
    url: request.url,
    query: [
      for (var index = 0; index < request.queryParams.length; index++)
        RequestKeyValue(
          id: 'query-$index',
          key: request.queryParams[index].key,
          value: request.queryParams[index].value,
          enabled: request.queryParams[index].enabled,
        ),
    ],
    headers: [
      for (var index = 0; index < request.headers.length; index++)
        RequestKeyValue(
          id: 'header-$index',
          key: request.headers[index].key,
          value: request.headers[index].value,
          enabled: request.headers[index].enabled,
        ),
    ],
    body: request.body.content,
    bodyFormat: request.body.kind == rust_api.FfiRequestBodyKind.text
        ? RequestBodyFormat.text
        : RequestBodyFormat.json,
  );

  rust_api.FfiRequest _ffiRequest(RequestTab request) => rust_api.FfiRequest(
    id: request.id,
    name: request.title,
    method: switch (request.method) {
      HttpMethod.get => rust_api.FfiRequestMethod.get_,
      HttpMethod.post => rust_api.FfiRequestMethod.post,
      HttpMethod.put => rust_api.FfiRequestMethod.put,
      HttpMethod.patch => rust_api.FfiRequestMethod.patch,
      HttpMethod.delete => rust_api.FfiRequestMethod.delete,
    },
    url: request.url,
    queryParams: _values(request.query),
    headers: _values(request.headers),
    body: rust_api.FfiRequestBody(
      kind: request.body.isEmpty
          ? rust_api.FfiRequestBodyKind.empty
          : request.bodyFormat == RequestBodyFormat.json
          ? rust_api.FfiRequestBodyKind.json
          : rust_api.FfiRequestBodyKind.text,
      content: request.body,
      fields: const [],
    ),
    auth: const rust_api.FfiRequestAuth(
      kind: rust_api.FfiRequestAuthKind.none,
      username: '',
      password: '',
      token: '',
      key: '',
      value: '',
      placement: rust_api.FfiApiKeyPlacement.header,
    ),
  );

  List<rust_api.FfiKeyValue> _values(List<RequestKeyValue> values) => [
    for (final value in values)
      rust_api.FfiKeyValue(
        key: value.key,
        value: value.value,
        enabled: value.enabled,
      ),
  ];

  HttpMethod _methodFromFfi(rust_api.FfiRequestMethod method) =>
      switch (method) {
        rust_api.FfiRequestMethod.get_ => HttpMethod.get,
        rust_api.FfiRequestMethod.post => HttpMethod.post,
        rust_api.FfiRequestMethod.put => HttpMethod.put,
        rust_api.FfiRequestMethod.patch => HttpMethod.patch,
        rust_api.FfiRequestMethod.delete => HttpMethod.delete,
        _ => HttpMethod.get,
      };
}
