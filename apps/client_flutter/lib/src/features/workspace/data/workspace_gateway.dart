import '../domain/workspace_models.dart';
import '../../../rust/api.dart' as rust_api;

/// Lowest Flutter data-layer boundary. The production implementation will call
/// generated flutter_rust_bridge bindings; it must not expose SQLite or HTTP.
abstract interface class WorkspaceGateway {
  Future<List<WorkspaceSummary>> listWorkspaces();
  Future<WorkspaceSummary> createWorkspace(String name);
  Future<void> deleteWorkspace(String id);
  Future<List<RequestCollection>> listCollections(String workspaceId);
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  });
  Future<void> deleteCollection(String id);
  Future<List<WorkspaceEnvironment>> listEnvironments(String workspaceId);
  Future<WorkspaceEnvironment> createEnvironment({
    required String workspaceId,
    required String name,
  });
  Future<void> deleteEnvironment(String id);
  Future<RequestKeyValue> saveEnvironmentVariable({
    required String environmentId,
    required RequestKeyValue variable,
  });
  Future<void> deleteEnvironmentVariable(String id);
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  });
  Future<void> deleteRequest(String id);
  Future<List<StoredExecutionHistoryRecord>> listExecutionHistory(
    String workspaceId,
  );
  Future<void> saveExecutionHistory(StoredExecutionHistoryRecord record);
  Future<void> clearExecutionHistory(String workspaceId);
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
  Future<void> deleteWorkspace(String id) => rust_api.deleteWorkspace(id: id);

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
  Future<void> deleteCollection(String id) => rust_api.deleteCollection(id: id);

  @override
  Future<List<WorkspaceEnvironment>> listEnvironments(
    String workspaceId,
  ) async {
    final environments = await rust_api.listEnvironments(
      workspaceId: workspaceId,
    );
    return [
      for (final environment in environments)
        WorkspaceEnvironment(
          id: environment.id,
          name: environment.name,
          variables: [
            for (final variable in await rust_api.listEnvironmentVariables(
              environmentId: environment.id,
            ))
              RequestKeyValue(
                id: variable.id,
                key: variable.key,
                value: variable.value,
                enabled: variable.enabled,
              ),
          ],
        ),
    ];
  }

  @override
  Future<WorkspaceEnvironment> createEnvironment({
    required String workspaceId,
    required String name,
  }) async {
    final environment = await rust_api.createEnvironment(
      workspaceId: workspaceId,
      name: name,
    );
    return WorkspaceEnvironment(id: environment.id, name: environment.name);
  }

  @override
  Future<void> deleteEnvironment(String id) =>
      rust_api.deleteEnvironment(id: id);

  @override
  Future<RequestKeyValue> saveEnvironmentVariable({
    required String environmentId,
    required RequestKeyValue variable,
  }) async {
    final saved = await rust_api.saveEnvironmentVariable(
      variable: rust_api.FfiEnvironmentVariable(
        id: variable.id,
        environmentId: environmentId,
        key: variable.key,
        value: variable.value,
        enabled: variable.enabled,
      ),
    );
    return RequestKeyValue(
      id: saved.id,
      key: saved.key,
      value: saved.value,
      enabled: saved.enabled,
    );
  }

  @override
  Future<void> deleteEnvironmentVariable(String id) =>
      rust_api.deleteEnvironmentVariable(id: id);

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

  @override
  Future<void> deleteRequest(String id) => rust_api.deleteRequest(id: id);

  @override
  Future<List<StoredExecutionHistoryRecord>> listExecutionHistory(
    String workspaceId,
  ) async => [
    for (final record in await rust_api.listWorkspaceExecutionHistory(
      workspaceId: workspaceId,
    ))
      _historyRecord(record),
  ];

  @override
  Future<void> saveExecutionHistory(StoredExecutionHistoryRecord record) =>
      rust_api.saveExecutionHistory(
        record: rust_api.FfiExecutionHistoryRecord(
          executionId: record.id,
          requestId: record.requestId,
          executedAtUnixMs: record.executedAt.millisecondsSinceEpoch,
          statusCode: record.status,
          durationMs: record.durationMillis,
          responseSizeBytes: record.responseSizeBytes,
          resultKind: switch (record.result) {
            ExecutionHistoryResult.response =>
              rust_api.FfiExecutionHistoryResultKind.response,
            ExecutionHistoryResult.error =>
              rust_api.FfiExecutionHistoryResultKind.error,
            ExecutionHistoryResult.cancelled =>
              rust_api.FfiExecutionHistoryResultKind.cancelled,
          },
          errorCategory: switch (record.errorCategory) {
            ExecutionHistoryErrorCategory.timeout =>
              rust_api.FfiExecutionHistoryErrorCategory.timeout,
            ExecutionHistoryErrorCategory.dns =>
              rust_api.FfiExecutionHistoryErrorCategory.dns,
            ExecutionHistoryErrorCategory.connection =>
              rust_api.FfiExecutionHistoryErrorCategory.connection,
            ExecutionHistoryErrorCategory.tls =>
              rust_api.FfiExecutionHistoryErrorCategory.tls,
            ExecutionHistoryErrorCategory.proxy =>
              rust_api.FfiExecutionHistoryErrorCategory.proxy,
            ExecutionHistoryErrorCategory.redirect =>
              rust_api.FfiExecutionHistoryErrorCategory.redirect,
            ExecutionHistoryErrorCategory.requestBody =>
              rust_api.FfiExecutionHistoryErrorCategory.requestBody,
            ExecutionHistoryErrorCategory.responseBody =>
              rust_api.FfiExecutionHistoryErrorCategory.responseBody,
            ExecutionHistoryErrorCategory.other =>
              rust_api.FfiExecutionHistoryErrorCategory.other,
            null => null,
          },
        ),
      );

  @override
  Future<void> clearExecutionHistory(String workspaceId) =>
      rust_api.clearWorkspaceExecutionHistory(workspaceId: workspaceId);

  StoredExecutionHistoryRecord _historyRecord(
    rust_api.FfiExecutionHistoryRecord record,
  ) => StoredExecutionHistoryRecord(
    id: record.executionId,
    requestId: record.requestId,
    executedAt: DateTime.fromMillisecondsSinceEpoch(record.executedAtUnixMs),
    status: record.statusCode,
    durationMillis: record.durationMs,
    responseSizeBytes: record.responseSizeBytes,
    result: switch (record.resultKind) {
      rust_api.FfiExecutionHistoryResultKind.response =>
        ExecutionHistoryResult.response,
      rust_api.FfiExecutionHistoryResultKind.error =>
        ExecutionHistoryResult.error,
      rust_api.FfiExecutionHistoryResultKind.cancelled =>
        ExecutionHistoryResult.cancelled,
    },
    errorCategory: switch (record.errorCategory) {
      rust_api.FfiExecutionHistoryErrorCategory.timeout =>
        ExecutionHistoryErrorCategory.timeout,
      rust_api.FfiExecutionHistoryErrorCategory.dns =>
        ExecutionHistoryErrorCategory.dns,
      rust_api.FfiExecutionHistoryErrorCategory.connection =>
        ExecutionHistoryErrorCategory.connection,
      rust_api.FfiExecutionHistoryErrorCategory.tls =>
        ExecutionHistoryErrorCategory.tls,
      rust_api.FfiExecutionHistoryErrorCategory.proxy =>
        ExecutionHistoryErrorCategory.proxy,
      rust_api.FfiExecutionHistoryErrorCategory.redirect =>
        ExecutionHistoryErrorCategory.redirect,
      rust_api.FfiExecutionHistoryErrorCategory.requestBody =>
        ExecutionHistoryErrorCategory.requestBody,
      rust_api.FfiExecutionHistoryErrorCategory.responseBody =>
        ExecutionHistoryErrorCategory.responseBody,
      rust_api.FfiExecutionHistoryErrorCategory.other =>
        ExecutionHistoryErrorCategory.other,
      null => null,
    },
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
    bodyFormat: switch (request.body.kind) {
      rust_api.FfiRequestBodyKind.text => RequestBodyFormat.text,
      rust_api.FfiRequestBodyKind.formUrlEncoded =>
        RequestBodyFormat.formUrlEncoded,
      rust_api.FfiRequestBodyKind.multipart => RequestBodyFormat.multipart,
      _ => RequestBodyFormat.json,
    },
    bodyFields: [
      for (var index = 0; index < request.body.fields.length; index++)
        RequestKeyValue(
          id: 'body-$index',
          key: request.body.fields[index].key,
          value: request.body.fields[index].value,
          enabled: request.body.fields[index].enabled,
        ),
    ],
    bodyFiles: [
      for (final file in request.body.files)
        MultipartFileReference(
          fieldName: file.fieldName,
          path: file.path,
          fileName: file.fileName,
          contentType: file.contentType,
        ),
    ],
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
      HttpMethod.head => rust_api.FfiRequestMethod.head,
      HttpMethod.options => rust_api.FfiRequestMethod.options,
    },
    url: request.url,
    queryParams: _values(request.query),
    headers: _values(request.headers),
    body: rust_api.FfiRequestBody(
      kind: switch (request.bodyFormat) {
        RequestBodyFormat.json when request.body.isEmpty =>
          rust_api.FfiRequestBodyKind.empty,
        RequestBodyFormat.json => rust_api.FfiRequestBodyKind.json,
        RequestBodyFormat.text => rust_api.FfiRequestBodyKind.text,
        RequestBodyFormat.formUrlEncoded =>
          rust_api.FfiRequestBodyKind.formUrlEncoded,
        RequestBodyFormat.multipart => rust_api.FfiRequestBodyKind.multipart,
      },
      content: request.body,
      fields: _values(request.bodyFields),
      files: [
        for (final file in request.bodyFiles)
          rust_api.FfiMultipartFile(
            fieldName: file.fieldName,
            path: file.path,
            fileName: file.fileName,
            contentType: file.contentType,
          ),
      ],
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
        rust_api.FfiRequestMethod.head => HttpMethod.head,
        rust_api.FfiRequestMethod.options => HttpMethod.options,
      };
}
