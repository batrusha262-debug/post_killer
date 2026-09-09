import 'package:bloc_test/bloc_test.dart';
import 'package:client_flutter/src/features/workspace/application/workspace_bloc.dart';
import 'package:client_flutter/src/features/workspace/data/workspace_repository.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = SavedRequest(
    id: 'injected-request',
    name: 'Injected request',
    method: HttpMethod.get,
    url: 'https://example.test',
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'turns a user event into an immutable dirty draft state',
    build: () => WorkspaceBloc(const _FakeWorkspaceRepository(request)),
    act: (bloc) => bloc.add(const WorkspaceUrlChanged('https://changed.test')),
    expect: () => [
      isA<WorkspaceState>()
          .having(
            (state) => state.selectedTab?.url,
            'selected URL',
            'https://changed.test',
          )
          .having((state) => state.selectedTab?.isDirty, 'dirty', true),
    ],
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'creates a tab only in response to an explicit event',
    build: () => WorkspaceBloc(const _FakeWorkspaceRepository(request)),
    act: (bloc) => bloc.add(const WorkspaceRequestCreated()),
    expect: () => [
      isA<WorkspaceState>().having(
        (state) => state.selectedTab?.title,
        'tab title',
        'Untitled 1',
      ),
    ],
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'switches the active workspace section from a typed navigation event',
    build: () => WorkspaceBloc(const _FakeWorkspaceRepository(request)),
    act: (bloc) =>
        bloc.add(const WorkspaceSectionSelected(WorkspaceSection.history)),
    expect: () => [
      isA<WorkspaceState>().having(
        (state) => state.selectedSection,
        'selected section',
        WorkspaceSection.history,
      ),
    ],
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'filters a derived collection view without replacing source collections',
    build: () => WorkspaceBloc(const _FakeWorkspaceRepository(request)),
    act: (bloc) => bloc.add(const WorkspaceCollectionSearchChanged('injected')),
    expect: () => [
      isA<WorkspaceState>()
          .having((state) => state.collections.length, 'source collections', 1)
          .having(
            (state) => state.filteredCollections.single.requests.single.name,
            'filtered request',
            'Injected request',
          ),
    ],
  );
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  const _FakeWorkspaceRepository(this.request);
  final SavedRequest request;
  @override
  WorkspaceState loadInitialWorkspace() => WorkspaceState(
    collections: [
      RequestCollection(id: 'injected', name: 'Injected', requests: [request]),
    ],
    tabs: [RequestTab.fromSaved(request)],
    selectedTabId: request.id,
  );
}
