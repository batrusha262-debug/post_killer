import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/workspace_repository.dart';
import '../data/request_executor.dart';
import '../domain/workspace_models.dart';

sealed class WorkspaceEvent {
  const WorkspaceEvent();
}

final class WorkspaceTabSelected extends WorkspaceEvent {
  const WorkspaceTabSelected(this.id);
  final String id;
}

final class WorkspaceSectionSelected extends WorkspaceEvent {
  const WorkspaceSectionSelected(this.section);
  final WorkspaceSection section;
}

final class WorkspaceCollectionSearchChanged extends WorkspaceEvent {
  const WorkspaceCollectionSearchChanged(this.query);
  final String query;
}

final class WorkspaceRequestOpened extends WorkspaceEvent {
  const WorkspaceRequestOpened(this.request);
  final SavedRequest request;
}

final class WorkspaceRequestCreated extends WorkspaceEvent {
  const WorkspaceRequestCreated();
}

final class WorkspaceTabClosed extends WorkspaceEvent {
  const WorkspaceTabClosed(this.id);
  final String id;
}

final class WorkspaceMethodChanged extends WorkspaceEvent {
  const WorkspaceMethodChanged(this.method);
  final HttpMethod method;
}

final class WorkspaceUrlChanged extends WorkspaceEvent {
  const WorkspaceUrlChanged(this.url);
  final String url;
}

final class WorkspaceBodyChanged extends WorkspaceEvent {
  const WorkspaceBodyChanged(this.body);
  final String body;
}

final class WorkspaceRequestSent extends WorkspaceEvent {
  const WorkspaceRequestSent();
}

final class WorkspaceKeyValueAdded extends WorkspaceEvent {
  const WorkspaceKeyValueAdded({required this.isHeader});
  final bool isHeader;
}

final class WorkspaceKeyValueChanged extends WorkspaceEvent {
  const WorkspaceKeyValueChanged({
    required this.id,
    required this.isHeader,
    this.key,
    this.value,
    this.enabled,
  });
  final String id;
  final bool isHeader;
  final String? key;
  final String? value;
  final bool? enabled;
}

class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc(WorkspaceRepository repository, {RequestExecutor? executor})
    : _executor = executor ?? const UnavailableRequestExecutor(),
      super(repository.loadInitialWorkspace()) {
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
    on<WorkspaceKeyValueAdded>(_addKeyValue);
    on<WorkspaceKeyValueChanged>(_updateKeyValue);
    on<WorkspaceRequestSent>(_sendRequest);
  }

  final RequestExecutor _executor;

  var _untitledCounter = 0;

  void _createRequest(
    WorkspaceRequestCreated event,
    Emitter<WorkspaceState> emit,
  ) {
    _untitledCounter += 1;
    final tab = RequestTab(
      id: 'local-untitled-$_untitledCounter',
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
    emit(
      WorkspaceState(
        collections: state.collections,
        tabs: tabs,
        selectedTabId: selected,
        selectedSection: state.selectedSection,
        collectionSearchQuery: state.collectionSearchQuery,
      ),
    );
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
    final execution = await _executor.execute(tab);
    emit(state.copyWith(isExecuting: false, execution: execution));
  }
}
