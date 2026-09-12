import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/workspace_repository.dart';
import '../data/request_executor.dart';
import '../data/postman_collection_importer.dart';
import '../data/openapi_collection_importer.dart';
import '../domain/workspace_models.dart';

import 'workspace_event.dart';
export 'workspace_event.dart';

class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc(
    WorkspaceRepository repository, {
    RequestExecutor? executor,
    WorkspaceState? initialState,
    bool autoBootstrap = true,
    this.executionTimeout = const Duration(seconds: 35),
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
    on<EnvironmentSelected>(_selectEnvironment);
    on<WorkspaceCollectionSearchChanged>(
      (event, emit) => emit(state.copyWith(collectionSearchQuery: event.query)),
    );
    on<WorkspaceHistorySearchChanged>(
      (event, emit) => emit(state.copyWith(historySearchQuery: event.query)),
    );
    on<WorkspaceHistoryEntryOpened>(_openHistoryEntry);
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
    on<WorkspaceBodyFieldAdded>(_addBodyField);
    on<WorkspaceBodyFieldChanged>(_updateBodyField);
    on<WorkspaceBodyFieldDeleted>(_deleteBodyField);
    on<WorkspaceBodyFileAdded>(_addBodyFile);
    on<WorkspaceBodyFileDeleted>(_deleteBodyFile);
    on<WorkspaceNetworkChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(network: event.network, isDirty: true),
      ),
    );
    on<WorkspaceAuthChanged>(
      (event, emit) => _updateSelected(
        emit,
        (tab) => tab.copyWith(auth: event.auth, isDirty: true),
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
    on<WorkspaceRequestCancelled>(_cancelRequest);
    if (autoBootstrap) add(const WorkspaceBootstrapRequested());
  }

  final WorkspaceRepository _repository;
  final RequestExecutor _executor;
  final Duration executionTimeout;

  var _untitledCounter = 0;
  var _executionGeneration = 0;

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
      case WorkspaceDeleteRequested():
        await _deleteWorkspace(event, emit);
      case CollectionCreateRequested():
        await _createCollection(event, emit);
      case CollectionDeleteRequested():
        await _deleteCollection(event, emit);
      case WorkspacePostmanImportRequested():
        await _importPostmanCollection(event, emit);
      case WorkspaceOpenApiImportRequested():
        await _importOpenApiCollection(event, emit);
      case WorkspaceRequestSaveRequested():
        await _saveRequest(event, emit);
      case WorkspaceSavedRequestDeleteRequested():
        await _deleteSavedRequest(event, emit);
      case EnvironmentCreateRequested():
        await _createEnvironment(event, emit);
      case EnvironmentDeleteRequested():
        await _deleteEnvironment(event, emit);
      case EnvironmentVariableSaveRequested():
        await _saveEnvironmentVariable(event, emit);
      case EnvironmentVariableDeleteRequested():
        await _deleteEnvironmentVariable(event, emit);
      case WorkspaceHistoryClearRequested():
        await _clearHistory(event, emit);
    }
  }

  void _selectEnvironment(
    EnvironmentSelected event,
    Emitter<WorkspaceState> emit,
  ) {
    if (event.id != null &&
        !state.environments.any((item) => item.id == event.id)) {
      return;
    }
    emit(state.copyWith(selectedEnvironmentId: event.id));
  }

  Future<void> _createEnvironment(
    EnvironmentCreateRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null || event.name.trim().isEmpty) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final environment = await _repository.createEnvironment(
        workspaceId: workspaceId,
        name: event.name,
      );
      emit(
        state.copyWith(
          environments: [...state.environments, environment],
          selectedEnvironmentId: environment.id,
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось создать environment.',
        ),
      );
    }
  }

  Future<void> _deleteEnvironment(
    EnvironmentDeleteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (!state.environments.any((item) => item.id == event.id)) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.deleteEnvironment(event.id);
      final environments = [
        for (final environment in state.environments)
          if (environment.id != event.id) environment,
      ];
      emit(
        state.copyWith(
          environments: environments,
          selectedEnvironmentId: state.selectedEnvironmentId == event.id
              ? (environments.isEmpty ? null : environments.first.id)
              : state.selectedEnvironmentId,
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось удалить environment.',
        ),
      );
    }
  }

  Future<void> _saveEnvironmentVariable(
    EnvironmentVariableSaveRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (!state.environments.any((item) => item.id == event.environmentId)) {
      return;
    }
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final variable = await _repository.saveEnvironmentVariable(
        environmentId: event.environmentId,
        variable: event.variable,
      );
      emit(
        state.copyWith(
          environments: [
            for (final environment in state.environments)
              if (environment.id == event.environmentId)
                environment.copyWith(
                  variables: [
                    for (final existing in environment.variables)
                      if (existing.id != variable.id) existing,
                    variable,
                  ],
                )
              else
                environment,
          ],
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось сохранить переменную.',
        ),
      );
    }
  }

  Future<void> _deleteEnvironmentVariable(
    EnvironmentVariableDeleteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.deleteEnvironmentVariable(event.variableId);
      emit(
        state.copyWith(
          environments: [
            for (final environment in state.environments)
              if (environment.id == event.environmentId)
                environment.copyWith(
                  variables: [
                    for (final variable in environment.variables)
                      if (variable.id != event.variableId) variable,
                  ],
                )
              else
                environment,
          ],
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось удалить переменную.',
        ),
      );
    }
  }

  Future<void> _importPostmanCollection(
    WorkspacePostmanImportRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final imported = PostmanCollectionImport.parse(event.source);
      await _saveImportedCollection(imported.name, imported.requests, emit);
    } on FormatException catch (error) {
      emit(state.copyWith(isLoading: false, storageError: error.message));
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось импортировать коллекцию Postman.',
        ),
      );
    }
  }

  Future<void> _importOpenApiCollection(
    WorkspaceOpenApiImportRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      final imported = OpenApiCollectionImport.parse(event.source);
      await _saveImportedCollection(imported.name, imported.requests, emit);
    } on FormatException catch (error) {
      emit(state.copyWith(isLoading: false, storageError: error.message));
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось импортировать коллекцию OpenAPI.',
        ),
      );
    }
  }

  Future<void> _saveImportedCollection(
    String name,
    List<SavedRequest> source,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null) return;
    final collection = await _repository.createCollection(
      workspaceId: workspaceId,
      name: name,
    );
    final requests = <SavedRequest>[];
    for (final request in source) {
      requests.add(
        await _repository.saveRequest(
          collectionId: collection.id,
          request: RequestTab.fromSaved(request),
        ),
      );
    }
    emit(
      state.copyWith(
        collections: [
          ...state.collections,
          RequestCollection(
            id: collection.id,
            name: collection.name,
            requests: requests,
          ),
        ],
        isLoading: false,
      ),
    );
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
      final environments = await _repository.listEnvironments(selected.id);
      final history = await _repository.listExecutionHistory(selected.id);
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
          environments: environments,
          selectedEnvironmentId: environments.isEmpty
              ? null
              : environments.first.id,
          tabs: tabs,
          selectedTabId: tabs.isEmpty ? null : tabs.first.id,
          history: _historyEntries(history, collections),
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
      final environments = await _repository.listEnvironments(event.id);
      final history = await _repository.listExecutionHistory(event.id);
      final tabs = [
        for (final collection in collections)
          for (final request in collection.requests)
            RequestTab.fromSaved(request),
      ];
      emit(
        state.copyWith(
          selectedWorkspaceId: event.id,
          collections: collections,
          environments: environments,
          selectedEnvironmentId: environments.isEmpty
              ? null
              : environments.first.id,
          tabs: tabs,
          selectedTabId: tabs.isEmpty ? null : tabs.first.id,
          history: _historyEntries(history, collections),
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
          environments: const [],
          selectedEnvironmentId: null,
          history: const [],
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

  Future<void> _deleteWorkspace(
    WorkspaceDeleteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (!state.workspaces.any((workspace) => workspace.id == event.id)) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.deleteWorkspace(event.id);
      final workspaces = [
        for (final workspace in state.workspaces)
          if (workspace.id != event.id) workspace,
      ];
      if (workspaces.isEmpty) {
        emit(
          state.copyWith(
            workspaces: const [],
            selectedWorkspaceId: null,
            collections: const [],
            tabs: const [],
            selectedTabId: null,
            isLoading: false,
          ),
        );
        return;
      }
      final selected = workspaces.first;
      final collections = await _repository.listCollections(selected.id);
      final environments = await _repository.listEnvironments(selected.id);
      final history = await _repository.listExecutionHistory(selected.id);
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
          environments: environments,
          selectedEnvironmentId: environments.isEmpty
              ? null
              : environments.first.id,
          tabs: tabs,
          selectedTabId: tabs.isEmpty ? null : tabs.first.id,
          history: _historyEntries(history, collections),
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось удалить workspace.',
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

  Future<void> _deleteCollection(
    CollectionDeleteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final collection = state.collections.where((item) => item.id == event.id);
    if (collection.isEmpty) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.deleteCollection(event.id);
      final requestIds = collection.single.requests
          .map((request) => request.id)
          .toSet();
      final tabs = [
        for (final tab in state.tabs)
          if (!requestIds.contains(tab.id)) tab,
      ];
      emit(
        state.copyWith(
          collections: [
            for (final item in state.collections)
              if (item.id != event.id) item,
          ],
          tabs: tabs,
          history: [
            for (final entry in state.history)
              if (!requestIds.contains(entry.requestId)) entry,
          ],
          selectedTabId: tabs.any((tab) => tab.id == state.selectedTabId)
              ? state.selectedTabId
              : (tabs.isEmpty ? null : tabs.first.id),
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось удалить папку.',
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
      // Saved requests deliberately omit credentials, but saving must not
      // discard the credentials already entered in this open draft.
      _updateSelected(
        emit,
        (draft) => RequestTab.fromSaved(saved).copyWith(auth: draft.auth),
      );
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

  Future<void> _deleteSavedRequest(
    WorkspaceSavedRequestDeleteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    if (!state.collections.any(
      (item) =>
          item.id == event.collectionId &&
          item.requests.any((request) => request.id == event.requestId),
    )) {
      return;
    }
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.deleteRequest(event.requestId);
      final tabs = [
        for (final tab in state.tabs)
          if (tab.id != event.requestId) tab,
      ];
      emit(
        state.copyWith(
          collections: [
            for (final collection in state.collections)
              if (collection.id == event.collectionId)
                RequestCollection(
                  id: collection.id,
                  name: collection.name,
                  requests: [
                    for (final request in collection.requests)
                      if (request.id != event.requestId) request,
                  ],
                )
              else
                collection,
          ],
          tabs: tabs,
          selectedTabId: state.selectedTabId == event.requestId
              ? (tabs.isEmpty ? null : tabs.first.id)
              : state.selectedTabId,
          history: [
            for (final entry in state.history)
              if (entry.requestId != event.requestId) entry,
          ],
          isLoading: false,
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось удалить запрос.',
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

  void _addBodyField(
    WorkspaceBodyFieldAdded event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(
    emit,
    (tab) => tab.copyWith(
      bodyFields: [
        ...tab.bodyFields,
        RequestKeyValue(id: 'body-${tab.bodyFields.length + 1}'),
      ],
      isDirty: true,
    ),
  );

  void _updateBodyField(
    WorkspaceBodyFieldChanged event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(
    emit,
    (tab) => tab.copyWith(
      bodyFields: [
        for (final field in tab.bodyFields)
          if (field.id == event.id)
            field.copyWith(
              key: event.key,
              value: event.value,
              enabled: event.enabled,
            )
          else
            field,
      ],
      isDirty: true,
    ),
  );

  void _deleteBodyField(
    WorkspaceBodyFieldDeleted event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(
    emit,
    (tab) => tab.copyWith(
      bodyFields: [
        for (final field in tab.bodyFields)
          if (field.id != event.id) field,
      ],
      isDirty: true,
    ),
  );

  void _addBodyFile(
    WorkspaceBodyFileAdded event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(
    emit,
    (tab) =>
        tab.copyWith(bodyFiles: [...tab.bodyFiles, event.file], isDirty: true),
  );

  void _deleteBodyFile(
    WorkspaceBodyFileDeleted event,
    Emitter<WorkspaceState> emit,
  ) => _updateSelected(
    emit,
    (tab) => tab.copyWith(
      bodyFiles: [
        for (final file in tab.bodyFiles)
          if (file.path != event.path) file,
      ],
      isDirty: true,
    ),
  );

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
    if (tab == null || state.isExecuting || !tab.auth.isValid) return;
    final generation = ++_executionGeneration;
    emit(state.copyWith(isExecuting: true));
    RequestExecutionView execution;
    final loginRequestId = tab.auth.loginRequestId;
    if (loginRequestId == null || loginRequestId.isEmpty) {
      execution = await _executeSafely(tab);
    } else {
      final login = _findRequest(loginRequestId);
      if (login == null) {
        execution = RequestExecutionView.error(
          requestId: tab.id,
          error: 'Выбранный запрос авторизации больше не существует.',
        );
      } else {
        final loginExecution = await _executeSafely(login);
        final token = _tokenFrom(loginExecution.body, tab.auth.tokenPath);
        if (loginExecution.error != null) {
          execution = RequestExecutionView.error(
            requestId: tab.id,
            error: 'Запрос авторизации не выполнен: ${loginExecution.error}',
          );
        } else if (token == null || token.isEmpty) {
          execution = RequestExecutionView.error(
            requestId: tab.id,
            error:
                'Токен не найден по пути "${tab.auth.tokenPath}" в ответе авторизации.',
          );
        } else {
          _updateSelected(
            emit,
            (current) => current.copyWith(
              auth: current.auth.copyWith(acquiredToken: token),
            ),
          );
          execution = await _executeSafely(
            tab.copyWith(
              auth: tab.auth.copyWith(token: token, acquiredToken: token),
            ),
          );
        }
      }
    }
    // Cancellation immediately releases the UI. A native call may resolve a
    // little later, but its result must never overwrite a newer request.
    if (emit.isDone || generation != _executionGeneration) return;
    final record = _historyRecord(tab, execution);
    if (_isSavedRequest(tab.id)) {
      try {
        await _repository.saveExecutionHistory(record);
      } on Object {
        // A completed HTTP request is still useful even if a non-sensitive
        // audit entry cannot be written. Never replace its response with a
        // storage failure.
      }
    }
    if (emit.isDone || generation != _executionGeneration) return;
    emit(
      state.copyWith(
        isExecuting: false,
        execution: state.tabs.any((item) => item.id == tab.id)
            ? execution
            : null,
        history: _isSavedRequest(tab.id)
            ? [_historyEntry(record, tab), ...state.history]
            : state.history,
      ),
    );
  }

  Future<void> _clearHistory(
    WorkspaceHistoryClearRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null || state.history.isEmpty) return;
    emit(state.copyWith(isLoading: true, storageError: null));
    try {
      await _repository.clearExecutionHistory(workspaceId);
      emit(state.copyWith(history: const [], isLoading: false));
    } on Object {
      emit(
        state.copyWith(
          isLoading: false,
          storageError: 'Не удалось очистить историю запросов.',
        ),
      );
    }
  }

  void _openHistoryEntry(
    WorkspaceHistoryEntryOpened event,
    Emitter<WorkspaceState> emit,
  ) {
    SavedRequest? saved;
    for (final collection in state.collections) {
      for (final request in collection.requests) {
        if (request.id == event.requestId) {
          saved = request;
          break;
        }
      }
      if (saved != null) break;
    }
    if (saved == null) return;
    final isOpen = state.tabs.any((tab) => tab.id == saved!.id);
    emit(
      state.copyWith(
        tabs: isOpen
            ? state.tabs
            : [...state.tabs, RequestTab.fromSaved(saved)],
        selectedTabId: saved.id,
        selectedSection: WorkspaceSection.collections,
      ),
    );
  }

  bool _isSavedRequest(String requestId) => state.collections.any(
    (collection) =>
        collection.requests.any((request) => request.id == requestId),
  );

  StoredExecutionHistoryRecord _historyRecord(
    RequestTab tab,
    RequestExecutionView execution,
  ) {
    final error = execution.error?.toLowerCase() ?? '';
    final category = execution.error == null
        ? null
        : switch (error) {
            _ when error.contains('timeout') || error.contains('превышено') =>
              ExecutionHistoryErrorCategory.timeout,
            _ when error.contains('dns') => ExecutionHistoryErrorCategory.dns,
            _ when error.contains('tls') => ExecutionHistoryErrorCategory.tls,
            _ when error.contains('proxy') =>
              ExecutionHistoryErrorCategory.proxy,
            _ when error.contains('redirect') =>
              ExecutionHistoryErrorCategory.redirect,
            _ when error.contains('response') && error.contains('body') =>
              ExecutionHistoryErrorCategory.responseBody,
            _ when error.contains('body') =>
              ExecutionHistoryErrorCategory.requestBody,
            _ when error.contains('connect') || error.contains('connection') =>
              ExecutionHistoryErrorCategory.connection,
            _ => ExecutionHistoryErrorCategory.other,
          };
    return StoredExecutionHistoryRecord(
      id: '${tab.id}-${DateTime.now().microsecondsSinceEpoch}',
      requestId: tab.id,
      executedAt: DateTime.now(),
      result: execution.error == null
          ? ExecutionHistoryResult.response
          : ExecutionHistoryResult.error,
      status: execution.status,
      durationMillis: execution.durationMillis ?? 0,
      responseSizeBytes:
          execution.bodyBytes?.length ??
          utf8.encode(execution.body ?? '').length,
      errorCategory: category,
    );
  }

  List<RequestHistoryEntry> _historyEntries(
    List<StoredExecutionHistoryRecord> records,
    List<RequestCollection> collections,
  ) {
    final requests = {
      for (final collection in collections)
        for (final request in collection.requests) request.id: request,
    };
    return [
      for (final record in records)
        if (requests[record.requestId] case final request?)
          _historyEntry(record, RequestTab.fromSaved(request)),
    ];
  }

  RequestHistoryEntry _historyEntry(
    StoredExecutionHistoryRecord record,
    RequestTab request,
  ) => RequestHistoryEntry(
    id: record.id,
    requestId: record.requestId,
    title: request.title,
    method: request.method,
    executedAt: record.executedAt,
    result: record.result,
    status: record.status,
    durationMillis: record.durationMillis,
    responseSizeBytes: record.responseSizeBytes,
    errorCategory: record.errorCategory,
  );

  RequestTab? _findRequest(String id) {
    for (final tab in state.tabs) {
      if (tab.id == id) return tab;
    }
    for (final collection in state.collections) {
      for (final request in collection.requests) {
        if (request.id == id) return RequestTab.fromSaved(request);
      }
    }
    return null;
  }

  String? _tokenFrom(String? body, String path) {
    if (body == null) return null;
    try {
      Object? value = jsonDecode(body);
      for (final part in path.replaceFirst(r'$.', '').split('.')) {
        if (value is! Map || !value.containsKey(part)) return null;
        value = value[part];
      }
      return value is String || value is num ? value.toString() : null;
    } on FormatException {
      return path.trim().isEmpty ? body.trim() : null;
    }
  }

  void _cancelRequest(
    WorkspaceRequestCancelled event,
    Emitter<WorkspaceState> emit,
  ) {
    if (!state.isExecuting) return;
    _executionGeneration += 1;
    emit(
      state.copyWith(
        isExecuting: false,
        execution: RequestExecutionView.error(
          requestId: state.selectedTabId ?? '',
          error: 'Request cancelled.',
        ),
      ),
    );
  }

  Future<RequestExecutionView> _executeSafely(RequestTab tab) async {
    try {
      // The Rust transport has its own timeout, but this outer deadline also
      // protects the UI from a stalled native bridge or DNS resolver.
      return await _executor
          .execute(
            tab,
            variables: state.selectedEnvironment?.variables ?? const [],
          )
          .timeout(executionTimeout);
    } on TimeoutException {
      return RequestExecutionView.error(
        requestId: tab.id,
        error:
            'Превышено время ожидания ответа. Проверьте сеть и адрес запроса.',
      );
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
