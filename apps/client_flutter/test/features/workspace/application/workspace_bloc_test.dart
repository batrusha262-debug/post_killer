import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:client_flutter/src/features/workspace/application/workspace_bloc.dart';
import 'package:client_flutter/src/features/workspace/data/workspace_repository.dart';
import 'package:client_flutter/src/features/workspace/data/request_executor.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = SavedRequest(
    id: 'injected-request',
    name: 'Injected request',
    method: HttpMethod.get,
    url: 'https://example.test',
  );

  WorkspaceBloc buildBloc({RequestExecutor? executor}) => WorkspaceBloc(
    const _FakeWorkspaceRepository(request),
    executor: executor,
    autoBootstrap: false,
    initialState: WorkspaceState(
      workspaces: const [WorkspaceSummary(id: 'workspace', name: 'Workspace')],
      selectedWorkspaceId: 'workspace',
      collections: [
        RequestCollection(
          id: 'injected',
          name: 'Injected',
          requests: const [request],
        ),
      ],
      tabs: [RequestTab.fromSaved(request)],
      selectedTabId: request.id,
    ),
  );

  test('nullable state can be cleared and matching empty collections remain visible', () {
    final state = WorkspaceState(
      collections: const [
        RequestCollection(id: 'empty', name: 'Empty', requests: []),
      ],
      tabs: const [],
      selectedTabId: 'old',
      storageError: 'old failure',
      collectionSearchQuery: 'empty',
    );
    expect(state.copyWith(selectedTabId: null).selectedTabId, isNull);
    expect(state.copyWith(storageError: null).storageError, isNull);
    expect(state.copyWith().storageError, 'old failure');
    expect(state.filteredCollections.single.id, 'empty');
  });

  test(
    'closing a tab preserves in-flight execution and ignores its late result',
    () async {
      final executor = _DelayedExecutor();
      final bloc = buildBloc(executor: executor);
      bloc.add(const WorkspaceRequestSent());
      await executor.started.future;
      final closed = bloc.stream.firstWhere((state) => state.tabs.isEmpty);
      bloc.add(const WorkspaceTabClosed('injected-request'));
      await closed;
      expect(bloc.state.isExecuting, isTrue);
      final finished = bloc.stream.firstWhere((state) => !state.isExecuting);
      executor.result.complete(
        RequestExecutionView.error(requestId: request.id, error: 'late'),
      );
      await finished;
      expect(bloc.state.execution, isNull);
      await bloc.close();
    },
  );

  test(
    'workspace selection waits for collection creation across event types',
    () async {
      final repository = _DelayedRepository(request);
      final bloc = WorkspaceBloc(
        repository,
        autoBootstrap: false,
        initialState: const WorkspaceState(
          workspaces: [
            WorkspaceSummary(id: 'a', name: 'A'),
            WorkspaceSummary(id: 'b', name: 'B'),
          ],
          selectedWorkspaceId: 'a',
          collections: [],
          tabs: [],
          selectedTabId: null,
        ),
      );
      bloc.add(const CollectionCreateRequested('Created in A'));
      await repository.started.future;
      bloc.add(const WorkspaceSelected('b'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.selections, isEmpty);
      final selected = bloc.stream.firstWhere(
        (state) => state.selectedWorkspaceId == 'b' && !state.isLoading,
      );
      repository.result.complete(
        const RequestCollection(
          id: 'created',
          name: 'Created in A',
          requests: [],
        ),
      );
      await selected;
      expect(repository.selections, ['b']);
      expect(
        bloc.state.collections.any((collection) => collection.id == 'created'),
        isFalse,
      );
      await bloc.close();
    },
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'header presets add one row and preserve an existing user value',
    build: buildBloc,
    act: (bloc) => bloc
      ..add(
        const WorkspaceHeaderPresetAdded('Content-Type', 'application/json'),
      )
      ..add(const WorkspaceHeaderPresetAdded('content-type', 'text/plain')),
    verify: (bloc) {
      expect(
        bloc.state.selectedTab!.headers
            .where((header) => header.key.toLowerCase() == 'content-type')
            .single
            .value,
        'application/json',
      );
      expect(
        bloc.state.selectedTab!.headers.any(
          (header) =>
              header.key == 'Accept' && header.value == 'application/json',
        ),
        isTrue,
      );
    },
  );

  test('an execution result is visible only in its owning tab', () {
    final execution = RequestExecutionView.response(
      requestId: request.id,
      status: 200,
      durationMillis: 1,
      headers: const [],
      body: '{}',
    );
    final state = WorkspaceState(
      collections: const [],
      tabs: const [
        RequestTab(
          id: 'injected-request',
          title: 'First',
          method: HttpMethod.get,
          url: 'https://example.test',
        ),
        RequestTab(
          id: 'other-request',
          title: 'Second',
          method: HttpMethod.get,
          url: 'https://example.test/other',
        ),
      ],
      selectedTabId: 'other-request',
      execution: execution,
    );

    expect(state.selectedExecution, isNull);
  });

  blocTest<WorkspaceBloc, WorkspaceState>(
    'turns a user event into an immutable dirty draft state',
    build: buildBloc,
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
    build: buildBloc,
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
    'creates a persisted collection for the selected workspace',
    build: buildBloc,
    act: (bloc) => bloc.add(const CollectionCreateRequested('Backend')),
    expect: () => [
      isA<WorkspaceState>().having(
        (state) => state.isLoading,
        'creating',
        true,
      ),
      isA<WorkspaceState>()
          .having((state) => state.isLoading, 'finished', false)
          .having(
            (state) => state.collections.last.name,
            'new collection name',
            'Backend',
          ),
    ],
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'switches the active workspace section from a typed navigation event',
    build: buildBloc,
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
    build: buildBloc,
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

  blocTest<WorkspaceBloc, WorkspaceState>(
    'runs Send through the execution port and exposes its response state',
    build: () => buildBloc(executor: const _FakeRequestExecutor()),
    act: (bloc) => bloc.add(const WorkspaceRequestSent()),
    expect: () => [
      isA<WorkspaceState>().having(
        (state) => state.isExecuting,
        'loading',
        true,
      ),
      isA<WorkspaceState>()
          .having((state) => state.isExecuting, 'loading finished', false)
          .having((state) => state.execution?.status, 'status', 200)
          .having((state) => state.execution?.body, 'body', '{"ok":true}'),
    ],
  );

  blocTest<WorkspaceBloc, WorkspaceState>(
    'recovers from a bridge exception without leaving Send disabled',
    build: () => buildBloc(executor: const _ThrowingRequestExecutor()),
    act: (bloc) => bloc.add(const WorkspaceRequestSent()),
    expect: () => [
      isA<WorkspaceState>().having(
        (state) => state.isExecuting,
        'loading',
        true,
      ),
      isA<WorkspaceState>()
          .having((state) => state.isExecuting, 'loading finished', false)
          .having(
            (state) => state.execution?.error,
            'safe error',
            'Request execution failed unexpectedly.',
          ),
    ],
  );
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  const _FakeWorkspaceRepository(this.request);
  final SavedRequest request;
  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => const [
    WorkspaceSummary(id: 'workspace', name: 'Workspace'),
  ];

  @override
  Future<List<RequestCollection>> listCollections(String workspaceId) async => [
    RequestCollection(id: 'injected', name: 'Injected', requests: [request]),
  ];

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async =>
      WorkspaceSummary(id: 'created-workspace', name: name);

  @override
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  }) async => RequestCollection(
    id: 'created-collection',
    name: name,
    requests: const [],
  );
}

class _FakeRequestExecutor implements RequestExecutor {
  const _FakeRequestExecutor();

  @override
  Future<RequestExecutionView> execute(RequestTab request) async =>
      RequestExecutionView.response(
        requestId: request.id,
        status: 200,
        durationMillis: 1,
        headers: const [
          RequestResponseHeader(
            name: 'content-type',
            value: 'application/json',
          ),
        ],
        body: '{"ok":true}',
      );
}

class _ThrowingRequestExecutor implements RequestExecutor {
  const _ThrowingRequestExecutor();

  @override
  Future<RequestExecutionView> execute(RequestTab request) =>
      Future<RequestExecutionView>.error(StateError('native bridge failed'));
}

class _DelayedExecutor implements RequestExecutor {
  final started = Completer<void>();
  final result = Completer<RequestExecutionView>();
  @override
  Future<RequestExecutionView> execute(RequestTab request) {
    started.complete();
    return result.future;
  }
}

class _DelayedRepository extends _FakeWorkspaceRepository {
  _DelayedRepository(super.request);
  final started = Completer<void>();
  final result = Completer<RequestCollection>();
  final selections = <String>[];
  @override
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  }) {
    started.complete();
    return result.future;
  }

  @override
  Future<List<RequestCollection>> listCollections(String workspaceId) {
    selections.add(workspaceId);
    return super.listCollections(workspaceId);
  }
}
