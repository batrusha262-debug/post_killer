import '../domain/workspace_models.dart';

sealed class WorkspaceEvent {
  const WorkspaceEvent();
}

sealed class WorkspaceStorageEvent extends WorkspaceEvent {
  const WorkspaceStorageEvent();
}

final class WorkspaceTabSelected extends WorkspaceEvent {
  const WorkspaceTabSelected(this.id);
  final String id;
}

final class WorkspaceBootstrapRequested extends WorkspaceStorageEvent {
  const WorkspaceBootstrapRequested();
}

final class WorkspaceSelected extends WorkspaceStorageEvent {
  const WorkspaceSelected(this.id);
  final String id;
}

final class WorkspaceCreateRequested extends WorkspaceStorageEvent {
  const WorkspaceCreateRequested(this.name);
  final String name;
}

final class WorkspaceDeleteRequested extends WorkspaceStorageEvent {
  const WorkspaceDeleteRequested(this.id);
  final String id;
}

final class CollectionCreateRequested extends WorkspaceStorageEvent {
  const CollectionCreateRequested(this.name);
  final String name;
}

final class CollectionDeleteRequested extends WorkspaceStorageEvent {
  const CollectionDeleteRequested(this.id);
  final String id;
}

final class WorkspacePostmanImportRequested extends WorkspaceStorageEvent {
  const WorkspacePostmanImportRequested(this.source);
  final String source;
}

final class EnvironmentCreateRequested extends WorkspaceStorageEvent {
  const EnvironmentCreateRequested(this.name);
  final String name;
}

final class EnvironmentDeleteRequested extends WorkspaceStorageEvent {
  const EnvironmentDeleteRequested(this.id);
  final String id;
}

final class EnvironmentVariableSaveRequested extends WorkspaceStorageEvent {
  const EnvironmentVariableSaveRequested({
    required this.environmentId,
    required this.variable,
  });
  final String environmentId;
  final RequestKeyValue variable;
}

final class EnvironmentVariableDeleteRequested extends WorkspaceStorageEvent {
  const EnvironmentVariableDeleteRequested({
    required this.environmentId,
    required this.variableId,
  });
  final String environmentId;
  final String variableId;
}

final class EnvironmentSelected extends WorkspaceEvent {
  const EnvironmentSelected(this.id);
  final String? id;
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

final class WorkspaceRequestTitleChanged extends WorkspaceEvent {
  const WorkspaceRequestTitleChanged(this.title);
  final String title;
}

final class WorkspaceRequestSaveRequested extends WorkspaceStorageEvent {
  const WorkspaceRequestSaveRequested(this.collectionId);
  final String collectionId;
}

final class WorkspaceSavedRequestDeleteRequested extends WorkspaceStorageEvent {
  const WorkspaceSavedRequestDeleteRequested({
    required this.collectionId,
    required this.requestId,
  });
  final String collectionId;
  final String requestId;
}

final class WorkspaceUrlChanged extends WorkspaceEvent {
  const WorkspaceUrlChanged(this.url);
  final String url;
}

final class WorkspaceBodyChanged extends WorkspaceEvent {
  const WorkspaceBodyChanged(this.body);
  final String body;
}

final class WorkspaceBodyFormatChanged extends WorkspaceEvent {
  const WorkspaceBodyFormatChanged(this.format);
  final RequestBodyFormat format;
}

final class WorkspaceBodyFieldAdded extends WorkspaceEvent {
  const WorkspaceBodyFieldAdded();
}

final class WorkspaceBodyFieldChanged extends WorkspaceEvent {
  const WorkspaceBodyFieldChanged({
    required this.id,
    this.key,
    this.value,
    this.enabled,
  });

  final String id;
  final String? key;
  final String? value;
  final bool? enabled;
}

final class WorkspaceBodyFieldDeleted extends WorkspaceEvent {
  const WorkspaceBodyFieldDeleted(this.id);
  final String id;
}

final class WorkspaceAuthChanged extends WorkspaceEvent {
  const WorkspaceAuthChanged(this.auth);
  final RequestAuth auth;
}

final class WorkspaceRequestSent extends WorkspaceEvent {
  const WorkspaceRequestSent();
}

final class WorkspaceRequestCancelled extends WorkspaceEvent {
  const WorkspaceRequestCancelled();
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

final class WorkspaceKeyValueDeleted extends WorkspaceEvent {
  const WorkspaceKeyValueDeleted({required this.id, required this.isHeader});
  final String id;
  final bool isHeader;
}

final class WorkspaceHeaderPresetAdded extends WorkspaceEvent {
  const WorkspaceHeaderPresetAdded(this.name, this.value);
  final String name;
  final String value;
}
