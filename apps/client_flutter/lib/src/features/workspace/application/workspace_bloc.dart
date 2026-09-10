import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/workspace_repository.dart';
import '../data/request_executor.dart';
import '../domain/workspace_models.dart';

import 'workspace_event.dart';
export 'workspace_event.dart';

class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc(
    WorkspaceRepository repository, {
    RequestExecutor? executor,
    WorkspaceState? initialState,
    bool autoBootstrap = true,
  }) : _repository = repository,
       _executor = executor ?? const UnavailableRequestExecutor(),
       super(
         initialState ??
             const WorkspaceState(
               collections: [],
               tabs: [],
               selectedTabId: null,
               isLoading: true,
             ),
       ) {
    // Serialize all storage operations together, including different event types.
    on<WorkspaceStorageEvent>(
      _storageOperation,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<WorkspaceTabSelected>((event, emit) {
      if (state.tabs.any((tab) => tab.id == event.id)) {
        emit(state.copyWith(selectedTabId: event.id));
      }
    });
    on<WorkspaceSectionSelected>(
      (event, emit) => emit(state.copyWith(selectedSection: event.section)),
    );
    on<WorkspaceCollectionSearchChanged>(
      (event, emit) => emit(state.copyWith(collectionSearchQuery: event.query)),
    );
    on<WorkspaceRequestOpened>((event, emit) {
      final isOpen = state.tabs.any((tab) => tab.id == event.request.id);
      emit(
        state.copyWith(
          tabs: isOpen
              ? state.tabs
              : [...state.tabs, RequestTab.fromSaved(event.request)],
          selectedTabId: event.request.id,
        ),
      );
    });
    on<WorkspaceRequestCreated>(_createRequest);
    on<WorkspaceTabClosed>(_closeTab);
    on<WorkspaceMethodChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(method: event.method, isDirty: true),
      ),
    );
    on<WorkspaceRequestTitleChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(title: event.title, isDirty: true),
      ),
    );
    on<WorkspaceUrlChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(url: event.url, isDirty: true),
      ),
    );
    on<WorkspaceBodyChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(body: event.body, isDirty: true),
      ),
    );
    on<WorkspaceBodyFormatChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(bodyFormat: event.format, isDirty: true),
      ),
    );
    on<WorkspaceHeaderPresetAdded>(
      (event, emit) => _updateSelected(emit, (tab) {
        if (tab.headers.any(
          (header) => header.key.toLowerCase() == event.name.toLowerCase(),
        )) {
          return tab;
        }
        return tab.copyWith(
          headers: [
            ...tab.headers,
            RequestKeyValue(
              id: 'preset-${event.name.toLowerCase()}',
              key: event.name,
              value: event.value,
              enabled: event.name != 'Authorization',
            ),
          ],
          isDirty: true,
        );
      }),
    );
    on<WorkspaceKeyValueAdded>(_addKeyValue);
    on<WorkspaceKeyValueChanged>(_updateKeyValue);
    on<WorkspaceKeyValueDeleted>(_deleteKeyValue);
    on<WorkspaceRequestSent>(_sendRequest);
    if (autoBootstrap) add(const WorkspaceBootstrapRequested());
  }

  final WorkspaceRepository _repository;
  final RequestExecutor _executor;

  var _untitledCounter = 0;

  Future<void> _storageOperation(
    WorkspaceStorageEvent event,
    Emitter<WorkspaceState> emit,
  ) async {
    switch (event) {
      case WorkspaceBootstrapRequested():
        await _bootstrap(event, emit);
      case WorkspaceSelected():
        await _selectWorkspace(event, emit);
      case WorkspaceCreateRequested():
        await _createWorkspace(event, emit);
      case CollectionCreateRequested():
        await _createCollection(event, emit);
      case WorkspaceRequestSaveRequested():
        await _saveRequest(event, emit);
    }
  }

  Future<void> _bootstrap(
    WorkspaceBootstrapRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    try {
      final workspaces = await _repository.listWorkspaces();
      if (workspaces.isEmpty) {
        emit(
          state.copyWith(
            workspaces: const [],
            collections: const [],
            isLoading: false,
          ),
        );
        return;
      }
      final selected = workspaces.first;
      final collections = await _repository.listCollections(selected.id);
      final tabs = [
        for (final collection in collections)
          for (final request in collection.requests)
            RequestTab.fromSaved(request),
      ];
      emit(
        state.copyWith(
          workspaces: workspaces,
          selectedWorkspaceId: selected.id,
          collections: collections,
          tabs: tabs,
          selectedTabId: tabs.isEmpty ? null : tabs.first.id,
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось открыть локальное хранилище.',
        ),
      );
    }
  }

  Future<void> _selectWorkspace(
    WorkspaceSelected event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (!state.workspaces.any((workspace) => workspace.id == event.id)) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final collections = await _repository.listCollections(event.id);
      emit(
        state.copyWith(
          selectedWorkspaceId: event.id,
          collections: collections,
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось загрузить collections.',
        ),
      );
    }
  }

  Future<void> _createWorkspace(
    WorkspaceCreateRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (event.name.trim().isEmpty) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final workspace = await _repository.createWorkspace(event.name);
      emit(
        state.copyWith(
          workspaces: [...state.workspaces, workspace],
          selectedWorkspaceId: workspace.id,
          collections: const [],
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось создать workspace.',
        ),
      );
    }
  }

  Future<void> _createCollection(
    CollectionCreateRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null || event.name.trim().isEmpty) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final collection = await _repository.createCollection(
        workspaceId: workspaceId,
        name: event.name,
      );
      emit(
        state.copyWith(
          collections: [...state.collections, collection],
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось создать collection.',
        ),
      );
    }
  }

  Future<void> _saveRequest(
    WorkspaceRequestSaveRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final tab = state.selectedTab;
    if (tab == null ||
        !state.collections.any((item) => item.id == event.collectionId)) {
      return;
    }
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final saved = await _repository.saveRequest(
        collectionId: event.collectionId,
        request: tab,
      );
      final collections = [
        for (final collection in state.collections)
          if (collection.id == event.collectionId)
            RequestCollection(
              id: collection.id,
              name: collection.name,
              requests: [
                for (final request in collection.requests)
                  if (request.id != saved.id) request,
                saved,
              ],
            )
          else
            collection,
      ];
      _updateSelected(emit, (draft) => RequestTab.fromSaved(saved));
      emit(state.copyWith(collections: collections, isLoading: false));
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось сохранить запрос в папку.',
        ),
      );
    }
  }

  void _createRequest(
    WorkspaceRequestCreated event,
    Emitter<WorkspaceState> emit,
  ) {
    _untitledCounter += 1;
    final tab = RequestTab(
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Untitled $_untitledCounter',
      method: HttpMethod.get,
      url: '',
    );
    emit(state.copyWith(tabs: [...state.tabs, tab], selectedTabId: tab.id));
  }

  void _closeTab(WorkspaceTabClosed event, Emitter<WorkspaceState> emit) {
    final index = state.tabs.indexWhere((tab) => tab.id == event.id);
    if (index == -1) return;
    final tabs = [...state.tabs]..removeAt(index);
    final selected = state.selectedTabId == event.id
        ? (tabs.isEmpty ? null : tabs[index.clamp(0, tabs.length - 1)].id)
        : state.selectedTabId;
    emit(state.copyWith(tabs: tabs, selectedTabId: selected));
  }

  void _addKeyValue(
    WorkspaceKeyValueAdded event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(emit, (tab) {
    final values = event.isHeader ? tab.headers : tab.query;
    final prefix = event.isHeader ? 'header' : 'query';
    final next = [
      ...values,
      RequestKeyValue(id: '$prefix-${values.length + 1}'),
    ];
    return event.isHeader
        ? tab.copyWith(headers: next, isDirty: true)
        : tab.copyWith(query: next, isDirty: true);
  });
  void _updateKeyValue(
    WorkspaceKeyValueChanged event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(emit, (tab) {
    final values = event.isHeader ? tab.headers : tab.query;
    final next = [
      for (final entry in values)
        if (entry.id == event.id)
          entry.copyWith(
            key: event.key,
            value: event.value,
            enabled: event.enabled,
          )
        else
          entry,
    ];
    return event.isHeader
        ? tab.copyWith(headers: next, isDirty: true)
        : tab.copyWith(query: next, isDirty: true);
  });

  void _deleteKeyValue(
    WorkspaceKeyValueDeleted event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(emit, (tab) {
    final values = event.isHeader ? tab.headers : tab.query;
    final next = [
      for (final value in values)
        if (value.id != event.id) value,
    ];
    return event.isHeader
        ? tab.copyWith(headers: next, isDirty: true)
        : tab.copyWith(query: next, isDirty: true);
  });
  void _updateSelected(
    Emitter<WorkspaceState> emit,
    RequestTab Function(RequestTab) update,
  ) {
    final id = state.selectedTabId;
    if (id == null) return;
    emit(
      state.copyWith(
        tabs: [
          for (final tab in state.tabs)
            if (tab.id == id) update(tab) else tab,
        ],
      ),
    );
  }

  Future<void> _sendRequest(
    WorkspaceRequestSent event,
    Emitter<WorkspaceState> emit,
  ) async {
    final tab = state.selectedTab;
    if (tab == null || state.isExecuting) return;
    emit(state.copyWith(isExecuting: true));
    final execution = await _executeSafely(tab);
    if (emit.isDone) return;
    emit(
      state.copyWith(
        isExecuting: false,
        execution: state.tabs.any((item) => item.id == tab.id)
            ? execution
            : null,
        history: [
          RequestHistoryEntry(
            id: '${tab.id}-${DateTime.now().microsecondsSinceEpoch}',
            title: tab.title,
            method: tab.method,
            url: tab.url,
            executedAt: DateTime.now(),
            status: execution.status,
            error: execution.error,
          ),
          ...state.history,
        ],
      ),
    );
  }

  Future<RequestExecutionView> _executeSafely(RequestTab tab) async {
    try {
      return await _executor.execute(tab);
    } on Object {
      // A bridge/runtime failure must not strand the Send button in its loading
      // state, and its implementation details may contain sensitive data.
      return RequestExecutionView.error(
        requestId: tab.id,
        error: 'Request execution failed unexpectedly.',
      );
    }
  }
}
