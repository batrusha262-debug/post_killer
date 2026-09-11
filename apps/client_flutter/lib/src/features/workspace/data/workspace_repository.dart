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
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  });
  Future<void> deleteRequest(String id);
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
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  }) => _gateway.saveRequest(collectionId: collectionId, request: request);

  @override
  Future<void> deleteRequest(String id) => _gateway.deleteRequest(id);
}
