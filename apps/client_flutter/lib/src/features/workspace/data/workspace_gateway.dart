import '../domain/workspace_models.dart';

/// Lowest Flutter data-layer boundary. The production implementation will call
/// generated flutter_rust_bridge bindings; it must not expose SQLite or HTTP.
abstract interface class WorkspaceGateway {
  WorkspaceState loadWorkspace();
}

class InMemoryWorkspaceGateway implements WorkspaceGateway {
  const InMemoryWorkspaceGateway();

  @override
  WorkspaceState loadWorkspace() {
    const health = SavedRequest(
      id: 'health-check',
      name: 'Health check',
      method: HttpMethod.get,
      url: 'https://api.example.com/health',
    );
    const createUser = SavedRequest(
      id: 'create-user',
      name: 'Create user',
      method: HttpMethod.post,
      url: 'https://api.example.com/users',
    );
    return WorkspaceState(
      collections: const [
        RequestCollection(
          id: 'starter',
          name: 'Getting started',
          requests: [health, createUser],
        ),
      ],
      tabs: [RequestTab.fromSaved(health), RequestTab.fromSaved(createUser)],
      selectedTabId: health.id,
    );
  }
}
