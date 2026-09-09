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
  Future<List<RequestCollection>> listCollections(String workspaceId) async => [
    for (final collection in await rust_api.listCollections(
      workspaceId: workspaceId,
    ))
      RequestCollection(
        id: collection.id,
        name: collection.name,
        requests: const [],
      ),
  ];

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
}
