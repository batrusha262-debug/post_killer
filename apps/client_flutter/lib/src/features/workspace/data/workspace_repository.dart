import '../domain/workspace_models.dart';
import 'workspace_gateway.dart';

/// Data boundary for the workspace feature. The FFI-backed implementation will
/// replace [InMemoryWorkspaceRepository] without changing the view model.
abstract interface class WorkspaceRepository {
  WorkspaceState loadInitialWorkspace();
}

class GatewayWorkspaceRepository implements WorkspaceRepository {
  const GatewayWorkspaceRepository(this._gateway);

  final WorkspaceGateway _gateway;

  @override
  WorkspaceState loadInitialWorkspace() => _gateway.loadWorkspace();
}
