import '../domain/workspace_models.dart';
import 'workspace_gateway.dart';

/// Repository boundary for persisted workspace data.
abstract interface class WorkspaceRepository {
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

class GatewayWorkspaceRepository implements WorkspaceRepository {
  const GatewayWorkspaceRepository(this._gateway);

  final WorkspaceGateway _gateway;

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() => _gateway.listWorkspaces();

  @override
  Future<WorkspaceSummary> createWorkspace(String name) =>
      _gateway.createWorkspace(name);

  @override
  Future<void> deleteWorkspace(String id) => _gateway.deleteWorkspace(id);

  @override
  Future<List<RequestCollection>> listCollections(String workspaceId) =>
      _gateway.listCollections(workspaceId);

  @override
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  }) => _gateway.createCollection(workspaceId: workspaceId, name: name);

  @override
  Future<void> deleteCollection(String id) => _gateway.deleteCollection(id);

  @override
  Future<List<WorkspaceEnvironment>> listEnvironments(String workspaceId) =>
      _gateway.listEnvironments(workspaceId);

  @override
  Future<WorkspaceEnvironment> createEnvironment({
    required String workspaceId,
    required String name,
  }) => _gateway.createEnvironment(workspaceId: workspaceId, name: name);

  @override
  Future<void> deleteEnvironment(String id) => _gateway.deleteEnvironment(id);

  @override
  Future<RequestKeyValue> saveEnvironmentVariable({
    required String environmentId,
    required RequestKeyValue variable,
  }) => _gateway.saveEnvironmentVariable(
    environmentId: environmentId,
    variable: variable,
  );

  @override
  Future<void> deleteEnvironmentVariable(String id) =>
      _gateway.deleteEnvironmentVariable(id);

  @override
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  }) => _gateway.saveRequest(collectionId: collectionId, request: request);

  @override
  Future<void> deleteRequest(String id) => _gateway.deleteRequest(id);

  @override
  Future<List<StoredExecutionHistoryRecord>> listExecutionHistory(
    String workspaceId,
  ) => _gateway.listExecutionHistory(workspaceId);

  @override
  Future<void> saveExecutionHistory(StoredExecutionHistoryRecord record) =>
      _gateway.saveExecutionHistory(record);

  @override
  Future<void> clearExecutionHistory(String workspaceId) =>
      _gateway.clearExecutionHistory(workspaceId);
}
